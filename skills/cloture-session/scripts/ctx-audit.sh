#!/usr/bin/env bash
#
# ctx-audit.sh : rapport de derive entre la documentation et la realite, et
# mesure du budget de contexte.
#
# Le script signale, il ne corrige rien et il ne juge pas. A toi de trancher.
# Usage :
#   bash ctx-audit.sh [--root <chemin>] [--peremption <jours>] [--strict] [--budget]
#
# --budget : ne lance que la section 10, la mesure du budget. Rapide, pour la
#            phase de cloture qui ne veut que les tailles.
# --strict : sortie en code 1 s'il reste au moins une alerte (utile en CI).
#
# set -f : sans ca, une portee du genre `src/auth/**` serait developpee par le shell
# au moment de la lire, et on comparerait des fichiers au lieu du motif.
set -euf

ROOT=""
PEREMPTION=120
STRICT=0
BUDGET_SEUL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)       ROOT="${2:-}"; shift 2 ;;
    --peremption) PEREMPTION="${2:-120}"; shift 2 ;;
    --strict)     STRICT=1; shift ;;
    --budget)     BUDGET_SEUL=1; shift ;;
    -h|--help)    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
BLOCAGES=0
alerte()  { printf '  [!] %s\n' "$1"; ALERTES=$((ALERTES + 1)); }
blocage() { printf '  [!!] %s\n' "$1"; ALERTES=$((ALERTES + 1)); BLOCAGES=$((BLOCAGES + 1)); }
ok()      { printf '  [ok] %s\n' "$1"; }
info()    { printf '  ... %s\n' "$1"; }

to_epoch() {
  date -d "$1" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || echo ""
}
jours_depuis() { # <AAAA-MM-JJ> -> nombre de jours, vide si date illisible
  local e n
  e="$(to_epoch "$1")"; [ -n "$e" ] || { echo ""; return; }
  n="$(to_epoch "$TODAY")"; [ -n "$n" ] || { echo ""; return; }
  echo $(( (n - e) / 86400 ))
}
lignes() { wc -l < "$1" | tr -d ' '; }
octets() { wc -c < "$1" | tr -d ' '; }

# mesure generique : <fichier> <libelle> <alerte> <blocage> [<seuil en octets>]
mesure() {
  fmes="$1"; lmes="$2"; ames="$3"; bmes="$4"; omes="${5:-0}"
  [ -f "$fmes" ] || return 0
  nmes="$(lignes "$fmes")"; qmes="$(octets "$fmes")"
  if [ "$nmes" -gt "$bmes" ]; then
    blocage "$lmes : $nmes lignes, seuil de blocage $bmes"
  elif [ "$omes" -gt 0 ] && [ "$qmes" -gt "$omes" ]; then
    blocage "$lmes : $qmes caracteres, seuil de blocage $omes"
  elif [ "$nmes" -gt "$ames" ]; then
    alerte "$lmes : $nmes lignes, seuil d'alerte $ames"
  else
    ok "$lmes : $nmes lignes"
  fi
}

# Profondeur de titres. GitLab est le seul guide a publier une regle chiffree de
# decoupe : au-dela de cinq niveaux, ce sont plusieurs sujets, pas un seul.
profondeur_titres() { # <fichier> -> niveau max
  awk 'BEGIN{fence=0; max=0}
       /^```/{fence=!fence; next}
       !fence && /^#+ /{ n=index($0, " ") - 1; if (n > max) max = n }
       END{print max+0}' "$1" 2>/dev/null || echo 0
}

# Repertoires qui ne comptent jamais, ni dans la doc, ni dans la taille du projet.
EXCLUS='-not -path ./.git/* -not -path ./archives/* -not -path */node_modules/* -not -path */vendor/* -not -path */.venv/* -not -path */venv/* -not -path */dist/* -not -path */build/* -not -path */target/* -not -path */.next/* -not -path */__pycache__/* -not -path */.cache/*'

# fichiers markdown de doc, hors archives et hors dependances
docs_md() {
  # shellcheck disable=SC2086
  find . -name '*.md' $EXCLUS 2>/dev/null | sed 's|^\./||' | sort
}

# Un journal est un markdown a entrees datees en titre de niveau 2.
nb_entrees_datees() { # <fichier> -> nombre de `## ...AAAA-MM-JJ`
  grep -cE '^## .*[0-9]{4}-[0-9]{2}-[0-9]{2}' "$1" 2>/dev/null || true
}

# Longueur du bloc « Etat a la reprise » : du titre qui contient « reprise » au
# prochain titre de niveau 2.
bloc_reprise_lignes() { # <TODOS.md> -> nombre de lignes, 0 si absent
  awk 'BEGIN{n=0; dans=0}
       /^## /{ if (dans) exit; if (tolower($0) ~ /reprise/) dans=1 }
       dans{n++}
       END{print n}' "$1" 2>/dev/null || echo 0
}

# Section la plus longue d'un markdown, en lignes, avec son titre.
section_max() { # <fichier> -> "N titre"
  awk '/^## /{ if (t != "") print n, t; t=$0; n=0 } { n++ } END{ if (t != "") print n, t }' "$1" 2>/dev/null \
    | sort -rn | head -1
}

# Entree la plus longue d'un journal, en lignes.
entree_max() { # <fichier> -> "N titre"
  awk '/^## .*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/{ if (t != "") print n, t; t=$0; n=0 } { n++ } END{ if (t != "") print n, t }' "$1" 2>/dev/null \
    | sort -rn | head -1
}

echo "=============================================="
echo " Audit de contexte : $(basename "$ROOT")"
echo " $TODAY"
echo "=============================================="

PROFIL="$(grep -m1 '^profil:' CODEMAP.md 2>/dev/null | sed 's/^profil: *//' || true)"
TAILLE_DECLAREE="$(grep -m1 '^taille:' CODEMAP.md 2>/dev/null | sed 's/^taille: *//' || true)"

# Les zones : un CODEMAP.md seul dans un sous-repertoire, sans TODOS ni
# CHANGELOG a cote. Un niveau autonome porte les trois piliers.
NIVEAUX=""
ZONES=""
for c in $(find . -mindepth 2 -name CODEMAP.md $EXCLUS 2>/dev/null | sort); do
  d="${c%/CODEMAP.md}"; d="${d#./}"
  grep -q '{{' "$c" 2>/dev/null && continue
  if [ -f "$d/TODOS.md" ] && [ -f "$d/CHANGELOG.md" ]; then
    NIVEAUX="$NIVEAUX $d"
  else
    ZONES="$ZONES $d"
  fi
done

if [ "$BUDGET_SEUL" -eq 0 ]; then

# --- 0. le terrain ------------------------------------------------------------
# Ce que le projet porte deja. Un projet neuf n'a rien, un projet existant a
# souvent une doc rangee autrement, et parfois une autre convention d'agent qui
# ferait une seconde source de verite. On se greffe sur l'existant, on ne pose
# pas des gabarits vides a cote.
echo
echo "0. Le terrain"

KIT_COMPLET=1
for f in CODEMAP.md TODOS.md CHANGELOG.md; do
  [ -f "$f" ] || KIT_COMPLET=0
done

# Documentation deja presente, hors kit
DOC_DIRS=""
for d in docs doc documentation wiki .claude/docs notes; do
  [ -d "$d" ] && DOC_DIRS="$DOC_DIRS $d"
done
ADR_DIRS=""
for d in adr docs/adr doc/adr docs/decisions docs/architecture/decisions; do
  [ -d "$d" ] && ADR_DIRS="$ADR_DIRS $d"
done
RACINE_MD="$(find . -maxdepth 1 -name '*.md' 2>/dev/null | sed 's|^\./||' \
  | grep -vE '^(CODEMAP|TODOS|CHANGELOG|CLAUDE|AGENTS|README|MEMORY)\.md$' | sort || true)"

[ -n "$DOC_DIRS" ] && info "documentation existante :$DOC_DIRS"
[ -n "$ADR_DIRS" ] && info "decisions existantes :$ADR_DIRS"
if [ -n "$RACINE_MD" ]; then
  info "markdown a la racine, hors kit : $(printf '%s ' $RACINE_MD)"
  [ "$KIT_COMPLET" -eq 0 ] && info "  chacun a un proprietaire dans la convention, voir references/PROFILS-PROJETS.md"
fi

# Conventions d'agent concurrentes. Deux sources de verite divergent toujours,
# et rien ne le signale au moment ou ça arrive.
CONCUR=""
for c in AGENTS.md GEMINI.md .cursorrules .clinerules .windsurfrules CONVENTIONS.md \
         .github/copilot-instructions.md .cursor/rules memory-bank .roo; do
  [ -e "$c" ] && CONCUR="$CONCUR $c"
done
if [ -n "$CONCUR" ]; then
  for c in $CONCUR; do
    case "$c" in
      AGENTS.md)
        if [ -f CLAUDE.md ]; then
          alerte "AGENTS.md et CLAUDE.md coexistent. Claude Code ne lit pas AGENTS.md, Codex ne lit pas CLAUDE.md. Sans raccord, deux sources divergent en silence. Le raccord est une ligne @AGENTS.md en tete du CLAUDE.md, ou un lien symbolique"
        else
          info "AGENTS.md present, c'est le porteur des regles ici. La convention s'y greffe au lieu de creer un CLAUDE.md"
        fi ;;
      memory-bank|.roo)
        alerte "$c present, c'est une convention de memoire d'agent concurrente. Elle porte le meme savoir que les piliers, et deux copies divergent. Choisir laquelle fait foi et archiver l'autre" ;;
      *)
        info "$c present, autre convention d'agent. Verifier qu'elle ne redit pas les piliers" ;;
    esac
  done
fi

# Convention anterieure de ce skill
if [ -f CODEMAP.md ] && ! grep -q '^taille:' CODEMAP.md 2>/dev/null \
   && grep -q 'contexte:convention' CODEMAP.md 2>/dev/null; then
  alerte "le bloc contexte:convention n'a pas de ligne taille:, il vient d'une version anterieure du skill. L'ajouter, la section 10 dit laquelle"
fi

if [ "$KIT_COMPLET" -eq 1 ] && [ -z "$CONCUR" ]; then
  ok "un seul porteur de convention, rien qui concurrence les piliers"
elif [ "$KIT_COMPLET" -eq 0 ]; then
  info "le kit est incomplet, voir la section 1. Le mode INIT se greffe sur ce qui existe"
fi

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

[ -n "$PROFIL" ] && info "profil declare : $PROFIL" \
                 || info "aucun bloc contexte:convention dans CODEMAP.md, chemins par defaut"

# Sans --root, la racine se deduit de git, donc appeler le script depuis un
# sous-projet audite le PARENT et pas le sous-projet. Silencieux et couteux.
if [ "$RACINE_DEDUITE" -eq 1 ] && [ "$APPEL" != "$ROOT" ]; then
  alerte "appele depuis ${APPEL#"$ROOT"/}, mais c'est $ROOT qui est audite. La racine est deduite de git. Pour auditer le sous-projet : ctx-audit.sh --root ${APPEL#"$ROOT"/}"
fi

# --- 1b. niveaux imbriques et zones -------------------------------------------
# Un monorepo porte plusieurs kits, chacun est un niveau autonome a cloturer a
# part. Une zone ne porte qu'une carte, l'etat et le journal restent a la racine.
# Dans les deux cas le parent pointe, il n'absorbe pas.
echo
echo "1b. Niveaux imbriques et zones"
if [ -n "$NIVEAUX" ]; then
  for n in $NIVEAUX; do
    alerte "$n porte son propre kit, c'est un niveau a auditer et a cloturer a part : ctx-audit.sh --root $n"
    grep -q "$n" CODEMAP.md 2>/dev/null \
      || alerte "$n n'est cite nulle part dans le CODEMAP de la racine, le parent doit pointer vers lui"
  done
else
  ok "aucun kit imbrique, un seul niveau a tenir"
fi
if [ -n "$ZONES" ]; then
  for z in $ZONES; do
    info "zone : $z ($(lignes "$z/CODEMAP.md") lignes de carte$([ -f "$z/CLAUDE.md" ] && printf ', CLAUDE.md de %s lignes' "$(lignes "$z/CLAUDE.md")"))"
    grep -q "$z" CODEMAP.md 2>/dev/null \
      || alerte "la zone $z n'est pas citee dans le CODEMAP de la racine, il doit pointer vers elle"
  done
else
  info "aucune zone, le CODEMAP de la racine porte toute la carte"
fi
# Un CLAUDE.md de sous-repertoire sans carte a cote : il se charge quand on touche
# un fichier du sous-arbre, mais rien ne dit ou est la carte de cette zone.
for c in $(find . -mindepth 2 -name CLAUDE.md $EXCLUS -not -path './.claude/*' 2>/dev/null | sort); do
  d="${c%/CLAUDE.md}"; d="${d#./}"
  [ -f "$d/CODEMAP.md" ] || info "$d porte un CLAUDE.md sans CODEMAP.md, une zone sans carte"
done

# --- 2. fraicheur -------------------------------------------------------------
echo
echo "2. Fraicheur"
CL_DATE="$(grep -m1 -oE '^## *\[?[^]]*\]? *[0-9]{4}-[0-9]{2}-[0-9]{2}' CHANGELOG.md 2>/dev/null \
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
  if grep -qi 'la reprise' TODOS.md; then
    TD_DATE="$(grep -m1 -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' TODOS.md || true)"
    d="$(jours_depuis "${TD_DATE:-}")"
    if [ -n "$d" ] && [ "$d" -gt 14 ]; then
      alerte "bloc Etat a la reprise date du $TD_DATE, soit $d jours"
    else
      ok "bloc Etat a la reprise present (${TD_DATE:-sans date})"
    fi
  else
    alerte "TODOS.md n'a pas de bloc 'Etat a la reprise', un redemarrage a froid perdrait le fil"
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
    # la portee recoupe-t-elle un fichier modifie ? Une fiche verifiee aujourd'hui
    # a deja ete relue, la signaler ferait du bruit a chaque cloture. Et un ADR ne
    # se redate jamais, il se supersede, donc sa portee n'a pas a etre surveillee.
    case "$f" in *fecisions/*|*decisions/*|*/adr/*) portee="" ;; *) portee="$(head -8 "$f" | grep -m1 'Port' || true)" ;; esac
    if [ -n "$portee" ] && [ "${NB_MODIFS:-0}" -gt 0 ] && [ "${vdate:-}" != "$TODAY" ]; then
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
for d in src lib app packages apps internal cmd services; do [ -d "$d" ] && SRC="$SRC $d"; done
if [ -n "$SRC" ]; then
  trouve=0
  for base in $SRC; do
    for m in $(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
      nom="$(basename "$m")"
      case "$nom" in .*|__pycache__|node_modules|test|tests) continue ;; esac
      # Un sous-projet qui porte son propre kit n'est pas un module du parent. Lui
      # reclamer une fiche ici pousserait a dupliquer sa doc, ce que la convention
      # interdit. Il est signale en section 1b comme niveau a part. Une zone qui
      # porte sa carte est deja documentee par elle.
      [ -f "$m/CODEMAP.md" ] && continue
      if [ ! -f "docs/modules/$nom.md" ]; then
        info "$m : pas de fiche docs/modules/$nom.md"
        trouve=$((trouve + 1))
      fi
    done
  done
  [ "$trouve" -eq 0 ] && ok "chaque module de premier niveau a sa fiche ou sa carte de zone"
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
    else
      # Un lien qui resout DANS les archives est un defaut d'un autre genre : le
      # lien marche, et il envoie le lecteur vers du faux ou du froid. La
      # convention l'interdit, et rien ne le voyait.
      case "$cible" in
        */archives/*|archives/*)
          alerte "$f : lie vers l'archive $cible. Une fiche vivante ne cite pas une archive, retirer le lien ou le reformuler en prose"
          morts=$((morts + 1)) ;;
      esac
    fi
  done
done
[ "$morts" -eq 0 ] && ok "aucun lien relatif casse"

# --- 7. coherence des archives ------------------------------------------------
# Quatre defauts eprouves sur un depot d'essai, aucun n'etait vu avant :
# l'index cherche par nom de base, un remplacant qui ne resout plus, un archive
# recree en vivant au meme chemin, et l'index lui-meme jamais mesure ni relu.
echo
echo "7. Archives"
if [ -d archives ]; then
  nb=0
  for f in $(find archives -name '*.md' -not -name 'README.md' 2>/dev/null | sort); do
    nb=$((nb + 1))
    head -6 "$f" | grep -q 'ARCHIV' || alerte "$f : pas d'en-tete ARCHIVE"
    # Index cherche par CHEMIN COMPLET. Par nom de base, un nom present dans la
    # colonne « Remplace par » d'une autre ligne suffisait a passer.
    if [ -f archives/README.md ] && ! grep -qF "$f" archives/README.md; then
      alerte "$f : absent de l'index archives/README.md"
    fi
    entete="$(head -8 "$f")"
    # Le remplacant resout-il encore ? C'est le champ qui fait la valeur de
    # l'en-tete, et il pourrit sans bruit.
    rempl="$(printf '%s' "$entete" | grep -m1 'Remplac' || true)"
    if [ -n "$rempl" ]; then
      for cible in $(printf '%s' "$rempl" | grep -oE '`[^`]+`' | tr -d '`'); do
        case "$cible" in *' '*|*aucun*|*'<'*|*'{{'*|'') continue ;; esac
        # Un chemin porte un / et ne finit pas par un /. « SKILL.md » ou
        # « references/ » nomment une partie d'un paquet, pas un fichier du depot.
        case "$cible" in */) continue ;; esac
        case "$cible" in */*) : ;; *) continue ;; esac
        [ -e "$cible" ] || alerte "$f : son remplacant $cible n'existe plus"
      done
    fi
    # Un vivant au meme chemin que l'origine : deux verites en face, dont une
    # marquee fausse.
    orig="$(printf '%s' "$entete" | grep -m1 'Origine' | grep -oE '`[^`]+`' | tr -d '`' || true)"
    rotation=0
    printf '%s' "$entete" | grep -q 'rotation' && rotation=1
    if [ -n "$orig" ] && [ -e "$orig" ] && [ "$rotation" -eq 0 ]; then
      alerte "$f : $orig existe aussi en vivant. Un archive recree au meme chemin laisse deux verites en face"
    fi
    # Taille d'un fichier d'archive. Les bots d'archivage de Wikipedia plafonnent
    # une page a 200 Ko, pour la meme raison : au-dela on ne fouille plus, on subit.
    n="$(lignes "$f")"
    [ "$n" -gt 1500 ] && alerte "$f : $n lignes. Au-dela de 1500 une archive se coupe, par mois ou par sujet"
  done
  # L'index est le SEUL fichier des archives qu'on lit vraiment, en archeologie.
  # Il n'etait ni mesure ni relu, et il a porte une affirmation fausse 25 jours.
  if [ -f archives/README.md ]; then
    mesure archives/README.md "index archives/README.md" 250 400
    for p in $(grep -oE '`[^`]+`' archives/README.md 2>/dev/null | tr -d '`' | sort -u); do
      # Les emplacements a remplir des gabarits ne sont pas des chemins.
      case "$p" in *'<'*|*'{{'*|*'>'*) continue ;; esac
      case "$p" in archives/*) [ -e "$p" ] || alerte "index des archives : $p n'existe pas" ;; esac
    done
  fi
  [ "$nb" -eq 0 ] && info "archives vides" || info "$nb element(s) archive(s)"
  info "pour y chercher quelque chose : ctx-archeo.sh <motif>, jamais un grep nu"
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

fi # fin des sections 1 a 9, sautees par --budget

# --- 10. budget de contexte ---------------------------------------------------
# Une doc vraie mais trop longue pour etre lue est une doc perdue. Chaque surface
# a une cible, un seuil d'alerte et un seuil de blocage. Les chiffres sont ceux de
# references/BUDGET.md, ils se changent la-bas et ici en meme temps.
echo
echo "10. Budget de contexte"

# taille du projet, en fichiers
# shellcheck disable=SC2086
NB_FICHIERS="$(find . -type f $EXCLUS 2>/dev/null | wc -l | tr -d ' ')"
if   [ "$NB_FICHIERS" -lt 150 ]; then TAILLE=petite
elif [ "$NB_FICHIERS" -le 600 ]; then TAILLE=moyenne
else TAILLE=grande; fi
info "taille : $TAILLE, $NB_FICHIERS fichiers hors dependances"
if [ -z "$TAILLE_DECLAREE" ]; then
  info "le bloc contexte:convention ne declare pas de taille, ajouter « taille: $TAILLE »"
elif [ "$TAILLE_DECLAREE" != "$TAILLE" ]; then
  alerte "le bloc contexte:convention dit « taille: $TAILLE_DECLAREE », le projet est $TAILLE"
fi

# CLAUDE.md de la racine : ni etat, ni recit. Un fichier qui porte beaucoup de
# dates a absorbe de l'histoire, et l'histoire a un autre proprietaire.
if [ -f CLAUDE.md ]; then
  mesure CLAUDE.md "CLAUDE.md" 150 200 40000
  nd="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' CLAUDE.md | wc -l | tr -d ' ')"
  [ "$nd" -gt 8 ] && alerte "CLAUDE.md porte $nd dates, un etat ou un recit s'y est glisse. L'etat va dans TODOS, l'histoire au CHANGELOG"
  grep -qiE '^\*\*(etat|état)|^#+ .*(etat|état)' CLAUDE.md \
    && alerte "CLAUDE.md porte un paragraphe d'etat. Il appartient au bloc de reprise de TODOS.md"
fi

# CODEMAP de la racine, et sa section la plus lourde
if [ -f CODEMAP.md ]; then
  mesure CODEMAP.md "CODEMAP.md" 300 400
  sm="$(section_max CODEMAP.md)"
  [ -n "$sm" ] && [ "${sm%% *}" -gt 60 ] \
    && info "section la plus lourde du CODEMAP : ${sm#* }, ${sm%% *} lignes. Au-dessus de 60, elle appelle une zone ou une fiche"
fi

# TODOS : le fichier, le bloc de reprise, et ce qui n'a rien a y faire
if [ -f TODOS.md ]; then
  mesure TODOS.md "TODOS.md" 200 300
  nb="$(bloc_reprise_lignes TODOS.md)"
  if   [ "$nb" -gt 80 ]; then blocage "bloc Etat a la reprise : $nb lignes, seuil de blocage 80. Il se reecrit depuis l'etat courant, il ne s'empile pas"
  elif [ "$nb" -gt 50 ]; then alerte "bloc Etat a la reprise : $nb lignes, seuil d'alerte 50"
  elif [ "$nb" -gt 0 ];  then ok "bloc Etat a la reprise : $nb lignes"; fi
  nc="$(grep -c '^- \[x\]' TODOS.md || true)"
  [ "${nc:-0}" -gt 0 ] && alerte "TODOS.md garde $nc tache(s) cochee(s). Une tache faite se supprime, le fait vit au CHANGELOG"
  ns="$(grep -ciE '^## .*(session|séance|seance)' TODOS.md || true)"
  [ "${ns:-0}" -gt 0 ] && alerte "TODOS.md porte $ns section(s) de compte-rendu de session. C'est du CHANGELOG, TODOS ne garde que le futur"
fi

# CHANGELOG et tout autre journal : nombre d'entrees, longueur, entree la plus longue
journal() { # <fichier> <libelle>
  local f="$1" lib="$2" ne n em
  [ -f "$f" ] || return 0
  ne="$(nb_entrees_datees "$f")"; n="$(lignes "$f")"
  if   [ "${ne:-0}" -ge 60 ] || [ "$n" -gt 1500 ]; then
    blocage "$lib : $ne entrees, $n lignes. Seuil de blocage 60 entrees ou 1500 lignes. Faire tourner : ctx-rotation.sh --fichier $f"
  elif [ "${ne:-0}" -ge 40 ] || [ "$n" -gt 1000 ]; then
    alerte "$lib : $ne entrees, $n lignes. Seuil d'alerte 40 entrees ou 1000 lignes. Faire tourner : ctx-rotation.sh --fichier $f"
  else
    ok "$lib : $ne entrees, $n lignes"
  fi
  # Le plafond de 25 lignes par entree vaut A L'ECRITURE. Un journal est
  # append-only, on ne reecrit pas le passe, donc une vieille entree trop longue
  # est une information et pas une alerte. Seules les trois plus recentes sont
  # encore les nôtres a corriger.
  em="$(awk '/^## .*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/{ if (t != "") { print n, t; if (++k == 3) exit } t=$0; n=0 } { n++ }
             END{ if (t != "" && k < 3) print n, t }' "$f" 2>/dev/null | sort -rn | head -1)"
  if [ -n "$em" ] && [ "${em%% *}" -gt 40 ]; then
    alerte "$lib : entree recente de ${em%% *} lignes (${em#* }). Une entree tient en 25 lignes, le detail va dans une fiche"
  else
    ev="$(entree_max "$f")"
    [ -n "$ev" ] && [ "${ev%% *}" -gt 40 ] \
      && info "$lib : la plus longue entree du journal fait ${ev%% *} lignes, mais elle est ancienne. Un journal ne se reecrit pas, le plafond de 25 lignes vaut a l'ecriture"
  fi
}
journal CHANGELOG.md "CHANGELOG.md"
JOURNAUX=""
for f in $(docs_md); do
  case "$f" in CHANGELOG.md|TODOS.md|CODEMAP.md|CLAUDE.md) continue ;; esac
  ne="$(nb_entrees_datees "$f")"
  [ "${ne:-0}" -ge 10 ] || continue
  JOURNAUX="$JOURNAUX $f"
  journal "$f" "journal $f"
done

# fiches docs/ trop longues. Un journal a deja ete mesure comme journal, sa
# reponse est la rotation et pas la scission.
if [ -d docs ]; then
  for f in $(find docs -name '*.md' -not -name 'README.md' 2>/dev/null | sort); do
    case " $JOURNAUX " in *" $f "*) continue ;; esac
    n="$(lignes "$f")"
    if   [ "$n" -gt 300 ]; then blocage "$f : $n lignes, seuil de blocage 300. Scinder en deux sujets"
    elif [ "$n" -gt 250 ]; then alerte "$f : $n lignes, seuil d'alerte 250"; fi
  done
fi

# Profondeur de titres. Un fichier a cinq niveaux ou plus porte plusieurs sujets,
# c'est la seule regle de decoupe chiffree qu'un guide de style publie. Signale
# seulement au-dela de la cible, sinon c'est du bruit.
for f in $(docs_md); do
  n="$(lignes "$f")"
  [ "$n" -gt 150 ] || continue
  d="$(profondeur_titres "$f")"
  [ "$d" -ge 5 ] && info "$f : $d niveaux de titres sur $n lignes. Au-dela de quatre, ce sont souvent plusieurs sujets a scinder"
done

# zones existantes
for z in $ZONES; do
  mesure "$z/CODEMAP.md" "carte de zone $z" 200 250
  [ -f "$z/CLAUDE.md" ] && mesure "$z/CLAUDE.md" "CLAUDE.md de zone $z" 40 60
done
for c in $(find . -mindepth 2 -name CLAUDE.md $EXCLUS -not -path './.claude/*' 2>/dev/null | sort); do
  d="${c%/CLAUDE.md}"; d="${d#./}"
  [ -f "$d/CODEMAP.md" ] || mesure "$c" "CLAUDE.md de zone $d" 40 60
done

# zones candidates : un repertoire de code de 25 fichiers ou plus, sans carte.
# Simple information tant que le CODEMAP de la racine tient son budget ou que le
# projet est petit, alerte des qu'il deborde sur un projet moyen ou grand, parce
# que c'est la sortie naturelle de ce qui deborde.
CM_LIGNES=0; [ -f CODEMAP.md ] && CM_LIGNES="$(lignes CODEMAP.md)"
BASES=""
for d in src lib app packages apps internal cmd services; do [ -d "$d" ] && BASES="$BASES $d"; done
[ -n "$BASES" ] || BASES="."
candidats=0
for base in $BASES; do
  for m in $(find "$base" -mindepth 1 -maxdepth 1 -type d $EXCLUS 2>/dev/null | sort); do
    nom="${m#./}"
    case "$(basename "$nom")" in .*|docs|archives|tests|test|scripts|node_modules|__pycache__) continue ;; esac
    [ -f "$nom/CODEMAP.md" ] && continue
    # shellcheck disable=SC2086
    nf="$(find "$nom" -type f $EXCLUS 2>/dev/null | wc -l | tr -d ' ')"
    [ "$nf" -ge 25 ] || continue
    mentions="$(grep -c "$(basename "$nom")" CODEMAP.md 2>/dev/null || true)"
    candidats=$((candidats + 1))
    if [ "$TAILLE" != petite ] && { [ "$CM_LIGNES" -gt 300 ] || [ "$TAILLE" = grande ]; }; then
      alerte "zone candidate : $nom, $nf fichiers, cite ${mentions:-0} fois dans le CODEMAP. Lui donner sa carte : ctx-init.sh --zone $nom"
    else
      info "zone possible : $nom, $nf fichiers, cite ${mentions:-0} fois dans le CODEMAP"
    fi
  done
done
[ "$candidats" -eq 0 ] && [ -n "$ZONES" ] && ok "chaque repertoire de code assez gros porte sa carte"

# --- bilan --------------------------------------------------------------------
echo
echo "=============================================="
if [ "$ALERTES" -eq 0 ]; then
  echo " Aucune alerte. La doc et le depot sont d'accord, et tout tient dans son budget."
else
  echo " $ALERTES alerte(s), dont $BLOCAGES blocage(s). Chacune se termine par une correction,"
  echo " un deplacement vers archives/, ou une rotation. Un blocage ne se reporte pas."
fi
echo "=============================================="

[ "$STRICT" -eq 1 ] && [ "$ALERTES" -gt 0 ] && exit 1
exit 0
