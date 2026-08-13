#!/usr/bin/env bash
#
# ctx-audit.sh : rapport de derive entre la documentation et la realite.
#
# Le script signale, il ne corrige rien et il ne juge pas. A toi de trancher.
# Usage :
#   bash ctx-audit.sh [--root <chemin>] [--peremption <jours>] [--strict]
#
# --strict : sortie en code 1 s'il reste au moins une alerte (utile en CI).
#
# set -f : sans ca, une portee du genre `src/auth/**` serait developpee par le shell
# au moment de la lire, et on comparerait des fichiers au lieu du motif.
set -euf

ROOT=""
PEREMPTION=120
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)       ROOT="${2:-}"; shift 2 ;;
    --peremption) PEREMPTION="${2:-120}"; shift 2 ;;
    --strict)     STRICT=1; shift ;;
    -h|--help)    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

APPEL="$(pwd)"
RACINE_DEDUITE=0
if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  RACINE_DEDUITE=1
fi
ROOT="$(cd "$ROOT" && pwd)"
cd "$ROOT"

TODAY="$(date +%F)"
ALERTES=0
alerte() { printf '  [!] %s\n' "$1"; ALERTES=$((ALERTES + 1)); }
ok()     { printf '  [ok] %s\n' "$1"; }
info()   { printf '  ... %s\n' "$1"; }

to_epoch() {
  date -d "$1" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || echo ""
}
jours_depuis() { # <AAAA-MM-JJ> -> nombre de jours, vide si date illisible
  local e n
  e="$(to_epoch "$1")"; [ -n "$e" ] || { echo ""; return; }
  n="$(to_epoch "$TODAY")"; [ -n "$n" ] || { echo ""; return; }
  echo $(( (n - e) / 86400 ))
}

# fichiers markdown de doc, hors archives et hors dependances
docs_md() {
  find . -name '*.md' \
    -not -path './archives/*' -not -path './.git/*' \
    -not -path './node_modules/*' -not -path './vendor/*' \
    -not -path './.venv/*' -not -path './dist/*' -not -path './build/*' \
    2>/dev/null | sed 's|^\./||' | sort
}

echo "=============================================="
echo " Audit de contexte : $(basename "$ROOT")"
echo " $TODAY"
echo "=============================================="

# --- 1. presence du kit -------------------------------------------------------
echo
echo "1. Kit de contexte"
for f in CODEMAP.md TODOS.md CHANGELOG.md; do
  if [ -f "$f" ]; then ok "$f"; else alerte "$f manquant"; fi
done
[ -f CLAUDE.md ] && ok "CLAUDE.md" || info "CLAUDE.md absent, les regles du projet n'ont pas de support"
# Vestige d'une convention a quatre piliers. Le contenu a un proprietaire ailleurs
# maintenant, le laisser en place cree deux sources de verite.
[ -f MEMORY.md ] && alerte "MEMORY.md present, la convention n'a plus de pilier memoire. Repartir son contenu : decisions vers docs/decisions/, pieges vers la fiche du module ou les zones sensibles du CODEMAP, preferences vers CLAUDE.md"
[ -d docs ]     && ok "docs/"     || alerte "docs/ manquant"
[ -d archives ] && ok "archives/" || alerte "archives/ manquant"
[ -f docs/README.md ]     || { [ -d docs ]     && alerte "docs/README.md manquant, l'index est obligatoire"; }
[ -f archives/README.md ] || { [ -d archives ] && alerte "archives/README.md manquant, l'index est obligatoire"; }

PROFIL="$(grep -m1 '^profil:' CODEMAP.md 2>/dev/null | sed 's/^profil: *//' || true)"
[ -n "$PROFIL" ] && info "profil declare : $PROFIL" \
                 || info "aucun bloc contexte:convention dans CODEMAP.md, chemins par defaut"

# Sans --root, la racine se deduit de git, donc appeler le script depuis un
# sous-projet audite le PARENT et pas le sous-projet. Silencieux et couteux.
if [ "$RACINE_DEDUITE" -eq 1 ] && [ "$APPEL" != "$ROOT" ]; then
  alerte "appele depuis ${APPEL#"$ROOT"/}, mais c'est $ROOT qui est audite. La racine est deduite de git. Pour auditer le sous-projet : ctx-audit.sh --root ${APPEL#"$ROOT"/}"
fi

# --- 1b. niveaux imbriques ----------------------------------------------------
# Un monorepo ou un projet a sous-projets porte plusieurs kits. Chacun est un
# niveau autonome, a auditer et a cloturer separement. Le parent pointe vers eux,
# il ne les absorbe pas.
echo
echo "1b. Niveaux imbriques"
# Un vrai kit porte les trois piliers. Un CODEMAP.md seul est soit un gabarit, soit
# un fichier qui porte le meme nom par hasard. Et un gabarit contient des
# emplacements a remplir de la forme {{...}}, ce qui le distingue a coup sur.
NIVEAUX=""
for c in $(find . -mindepth 2 -name CODEMAP.md \
             -not -path './.git/*' -not -path './archives/*' \
             -not -path './node_modules/*' -not -path './dist/*' 2>/dev/null | sort); do
  d="${c%/CODEMAP.md}"; d="${d#./}"
  [ -f "$d/TODOS.md" ] && [ -f "$d/CHANGELOG.md" ] || continue
  grep -q '{{' "$c" 2>/dev/null && continue
  NIVEAUX="$NIVEAUX $d"
done
if [ -n "$NIVEAUX" ]; then
  for n in $NIVEAUX; do
    alerte "$n porte son propre kit, c'est un niveau a auditer et a cloturer a part : ctx-audit.sh --root $n"
    grep -q "$n" CODEMAP.md 2>/dev/null \
      || alerte "$n n'est cite nulle part dans le CODEMAP de la racine, le parent doit pointer vers lui"
  done
else
  ok "aucun kit imbrique, un seul niveau a tenir"
fi

# --- 2. fraicheur -------------------------------------------------------------
echo
echo "2. Fraicheur"
CL_DATE="$(grep -m1 -oE '^## *\[?[0-9]{4}-[0-9]{2}-[0-9]{2}' CHANGELOG.md 2>/dev/null \
           | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)"
if [ -n "$CL_DATE" ]; then
  d="$(jours_depuis "$CL_DATE")"
  if [ -n "$d" ] && [ "$d" -gt 30 ]; then
    alerte "derniere entree CHANGELOG le $CL_DATE, soit $d jours"
  else
    ok "derniere entree CHANGELOG le $CL_DATE"
  fi
else
  alerte "aucune entree datee dans CHANGELOG.md (format attendu : ## AAAA-MM-JJ)"
fi

CM_DATE="$(grep -m1 -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' CODEMAP.md 2>/dev/null || true)"
[ -n "$CM_DATE" ] && info "CODEMAP date du $CM_DATE" || alerte "CODEMAP.md sans date de mise a jour"

if [ -f TODOS.md ]; then
  if grep -q 'la reprise' TODOS.md; then
    TD_DATE="$(grep -m1 -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' TODOS.md || true)"
    d="$(jours_depuis "${TD_DATE:-}")"
    if [ -n "$d" ] && [ "$d" -gt 14 ]; then
      alerte "bloc Etat a la reprise date du $TD_DATE, soit $d jours"
    else
      ok "bloc Etat a la reprise present (${TD_DATE:-sans date})"
    fi
  else
    alerte "TODOS.md n'a pas de bloc 'Etat a la reprise', un /clear perdrait le fil"
  fi
fi

# --- 3. perimetre modifie -----------------------------------------------------
echo
echo "3. Perimetre modifie depuis la derniere entree CHANGELOG"
MODIFS="$( { git status --porcelain -uall 2>/dev/null | sed 's/^...//' ;
             if [ -n "$CL_DATE" ]; then
               git log --since="$CL_DATE" --name-only --pretty=format: 2>/dev/null
             else
               git log -20 --name-only --pretty=format: 2>/dev/null
             fi ; } | grep -v '^$' | sort -u || true)"
NB_MODIFS="$(printf '%s\n' "$MODIFS" | grep -c . || true)"
if [ "${NB_MODIFS:-0}" -eq 0 ]; then
  ok "rien de modifie"
else
  info "$NB_MODIFS fichier(s) touche(s)"
  printf '%s\n' "$MODIFS" | head -15 | sed 's/^/       /'
  [ "$NB_MODIFS" -gt 15 ] && printf '       ... et %s de plus\n' "$((NB_MODIFS - 15))"
fi

# --- 4. etat des fiches docs/ -------------------------------------------------
echo
echo "4. Fiches docs/"
if [ -d docs ]; then
  NB_FICHES=0
  for f in $(find docs -name '*.md' -not -name 'README.md' 2>/dev/null | sort); do
    NB_FICHES=$((NB_FICHES + 1))
    entete="$(head -6 "$f" | grep -m1 'Statut' || true)"
    if [ -z "$entete" ]; then
      alerte "$f : pas d'en-tete de statut"
      continue
    fi
    case "$entete" in
      *"🔴"*) alerte "$f : marquee obsolete, a deplacer vers archives/ maintenant" ;;
      *"🟡"*) alerte "$f : marquee a verifier" ;;
    esac
    vdate="$(printf '%s' "$entete" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)"
    if [ -z "$vdate" ]; then
      alerte "$f : en-tete sans date de verification"
    else
      d="$(jours_depuis "$vdate")"
      [ -n "$d" ] && [ "$d" -gt "$PEREMPTION" ] \
        && alerte "$f : verifiee il y a $d jours (seuil $PEREMPTION)"
    fi
    # la portee recoupe-t-elle un fichier modifie ?
    portee="$(head -8 "$f" | grep -m1 'Port' || true)"
    if [ -n "$portee" ] && [ "${NB_MODIFS:-0}" -gt 0 ]; then
      for p in $(printf '%s' "$portee" | grep -oE '`[^`]+`' | tr -d '`'); do
        prefixe="${p%%\**}"
        prefixe="${prefixe%/}"
        [ -n "$prefixe" ] || continue
        if printf '%s\n' "$MODIFS" | grep -q "^$prefixe"; then
          alerte "$f : sa portee ($p) a bouge, relire la fiche"
          break
        fi
      done
    fi
    # indexee ?
    base="$(basename "$f")"
    if [ -f docs/README.md ] && ! grep -q "$base" docs/README.md; then
      alerte "$f : absente de l'index docs/README.md"
    fi
  done
  [ "$NB_FICHES" -eq 0 ] && info "aucune fiche pour l'instant" \
                         || info "$NB_FICHES fiche(s) examinee(s)"
fi

# --- 5. modules sans fiche ----------------------------------------------------
echo
echo "5. Modules sans fiche"
SRC=""
for d in src lib app packages internal cmd; do [ -d "$d" ] && SRC="$SRC $d"; done
if [ -n "$SRC" ]; then
  trouve=0
  for base in $SRC; do
    for m in $(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
      nom="$(basename "$m")"
      case "$nom" in .*|__pycache__|node_modules|test|tests) continue ;; esac
      # Un sous-projet qui porte son propre kit n'est pas un module du parent. Lui
      # reclamer une fiche ici pousserait a dupliquer sa doc, ce que la convention
      # interdit. Il est signale en section 1b comme niveau a part.
      [ -f "$m/CODEMAP.md" ] && continue
      if [ ! -f "docs/modules/$nom.md" ]; then
        info "$m : pas de fiche docs/modules/$nom.md"
        trouve=$((trouve + 1))
      fi
    done
  done
  [ "$trouve" -eq 0 ] && ok "chaque module de premier niveau a sa fiche"
  [ "$trouve" -gt 0 ] && info "toutes ne meritent pas une fiche, voir references/DOCS-SYSTEM.md"
else
  info "pas de repertoire source standard detecte"
fi

# --- 6. liens relatifs morts --------------------------------------------------
echo
echo "6. Liens morts"
morts=0
for f in $(docs_md); do
  dir="$(dirname "$f")"
  # awk retire les blocs de code, sinon les liens d'exemple d'une doc comptent comme morts
  for lien in $(awk '/^```/{dans=!dans; next} !dans' "$f" 2>/dev/null \
                | grep -oE '\]\([^)#][^)]*\)' | sed 's/^](//; s/)$//' || true); do
    # on ignore l'externe et les emplacements a remplir des gabarits
    case "$lien" in http*|mailto:*|'#'*|*'<'*|*'{{'*) continue ;; esac
    cible="${lien%%#*}"
    [ -n "$cible" ] || continue
    if [ ! -e "$dir/$cible" ] && [ ! -e "$cible" ]; then
      alerte "$f : lien mort vers $cible"
      morts=$((morts + 1))
    fi
  done
done
[ "$morts" -eq 0 ] && ok "aucun lien relatif casse"

# --- 7. coherence des archives ------------------------------------------------
echo
echo "7. Archives"
if [ -d archives ]; then
  nb=0
  for f in $(find archives -name '*.md' -not -name 'README.md' 2>/dev/null | sort); do
    nb=$((nb + 1))
    head -5 "$f" | grep -q 'ARCHIV' || alerte "$f : pas d'en-tete ARCHIVE"
    if [ -f archives/README.md ] && ! grep -q "$(basename "$f")" archives/README.md; then
      alerte "$f : absent de l'index archives/README.md"
    fi
  done
  [ "$nb" -eq 0 ] && info "archives vides" || info "$nb element(s) archive(s)"
fi

# --- 8. marqueurs laisses dans le code ----------------------------------------
echo
echo "8. Marqueurs dans le code"
MARQ="$(grep -rIn --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=archives \
        --exclude-dir=.venv --exclude-dir=dist --exclude-dir=build \
        -E '(TODO|FIXME|HACK|XXX)[:( ]' . 2>/dev/null | grep -vc '^$' || true)"
if [ "${MARQ:-0}" -gt 0 ]; then
  info "${MARQ} marqueur(s) TODO/FIXME/HACK. Ceux qui comptent doivent etre dans TODOS.md"
else
  ok "aucun marqueur"
fi

# --- 9. secrets, heuristique legere -------------------------------------------
echo
echo "9. Secrets"
SUSPECT="$(git grep -InE '(api[_-]?key|secret|token|password|passwd)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_/+-]{16,}' \
           -- . 2>/dev/null | grep -v -E '(\.example|\.sample|templates/|references/)' || true)"
if [ -n "$SUSPECT" ]; then
  alerte "valeurs qui ressemblent a des secrets dans des fichiers trackes :"
  printf '%s\n' "$SUSPECT" | head -5 | sed 's/^/       /'
else
  ok "rien de suspect dans les fichiers trackes"
fi

# --- bilan --------------------------------------------------------------------
echo
echo "=============================================="
if [ "$ALERTES" -eq 0 ]; then
  echo " Aucune alerte. La doc et le depot sont d'accord."
else
  echo " $ALERTES alerte(s). Chacune se termine soit par une correction,"
  echo " soit par un deplacement vers archives/. Aucune ne reste ouverte."
fi
echo "=============================================="

[ "$STRICT" -eq 1 ] && [ "$ALERTES" -gt 0 ] && exit 1
exit 0
