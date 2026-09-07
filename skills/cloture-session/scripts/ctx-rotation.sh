#!/usr/bin/env bash
#
# ctx-rotation.sh : fait tourner un journal. Garde les N entrees les plus recentes
# dans le fichier, deplace les autres dans archives/<journal>/AAAA-MM.md, un
# fichier par mois, et pose une ligne d'index dans archives/README.md.
#
# Une entree ancienne n'est pas fausse, elle est froide. archives/ est le seul
# endroit que la convention ne lit jamais en reprise, c'est la propriete qu'on veut.
#
# Usage :
#   bash ctx-rotation.sh [--root <chemin>] [--fichier <journal.md>] [--garder <N>] [--dry-run]
#
# --fichier : CHANGELOG.md par defaut. Tout markdown a entrees `## ... AAAA-MM-JJ`.
# --garder  : nombre d'entrees conservees, 30 par defaut. Les N premieres du
#             fichier, donc les plus recentes si le journal est range du plus
#             recent au plus ancien, ce que la convention impose.
# --dry-run : annonce ce qui bougerait, n'ecrit rien.
#
# Idempotent : relance sur un fichier deja tourne, il ne trouve rien a deplacer.
set -eu

ROOT=""
FICHIER="CHANGELOG.md"
GARDER=30
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)    ROOT="${2:-}"; shift 2 ;;
    --fichier) FICHIER="${2:-}"; shift 2 ;;
    --garder)  GARDER="${2:-30}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
ROOT="$(cd "$ROOT" && pwd)"
cd "$ROOT"

[ -f "$FICHIER" ] || { echo "Journal introuvable : $FICHIER" >&2; exit 1; }
case "$GARDER" in ''|*[!0-9]*) echo "--garder attend un entier" >&2; exit 2 ;; esac

TODAY="$(date +%F)"
SLUG="$(basename "$FICHIER" .md | tr '[:upper:]' '[:lower:]')"
DEST_DIR="archives/$SLUG"
SENTINELLE='<!-- fin de l'"'"'en-tête -->'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- decoupe ------------------------------------------------------------------
# Une entree commence a un titre de niveau 2 qui porte une date, hors bloc de
# code. Ce qui precede la premiere entree est le preambule. Un titre sans date au
# milieu du journal appartient a l'entree en cours. La ligne de rotation d'une
# passe precedente est retiree, elle se regenere.
awk -v dir="$TMP" '
  BEGIN { fence = 0; n = 0; pre = dir "/preambule" }
  /^```/ { fence = !fence }
  !fence && /^## .*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
    n++
    cur = sprintf("%s/%04d", dir, n)
    match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)
    print n, substr($0, RSTART, RLENGTH) >> (dir "/manifeste")
  }
  {
    if (n == 0) { if ($0 !~ /^> Entrées antérieures au /) print >> pre }
    else print >> cur
  }
' "$FICHIER"

TOTAL=0
[ -f "$TMP/manifeste" ] && TOTAL="$(wc -l < "$TMP/manifeste" | tr -d ' ')"

echo "Rotation de $FICHIER"
echo "  entrees datees : $TOTAL, a garder : $GARDER"
if [ "$TOTAL" -le "$GARDER" ]; then
  echo "  rien a deplacer."
  exit 0
fi
A_DEPLACER=$((TOTAL - GARDER))
echo "  a deplacer : $A_DEPLACER, vers $DEST_DIR/AAAA-MM.md"
[ "$DRY" -eq 1 ] && echo "  mode simulation, rien ne sera ecrit"
echo

# --- regroupement par mois ----------------------------------------------------
MOIS="$(awk -v g="$GARDER" '$1 > g { print substr($2, 1, 7) }' "$TMP/manifeste" | awk '!vu[$0]++')"
CREES=""
for m in $MOIS; do
  dest="$DEST_DIR/$m.md"
  bloc="$TMP/bloc-$m"
  : > "$bloc"
  nb=0
  for i in $(awk -v g="$GARDER" -v m="$m" '$1 > g && substr($2, 1, 7) == m { print $1 }' "$TMP/manifeste"); do
    cat "$TMP/$(printf '%04d' "$i")" >> "$bloc"
    nb=$((nb + 1))
  done
  if [ -f "$dest" ]; then
    printf '  ~ %-40s %s entree(s) ajoutee(s) en tete\n' "$dest" "$nb"
  else
    printf '  + %-40s %s entree(s), fichier cree\n' "$dest" "$nb"
  fi
  [ "$DRY" -eq 1 ] && continue
  mkdir -p "$DEST_DIR"
  if [ -f "$dest" ]; then
    # en-tete conserve, entrees neuves d'abord, puis les anciennes
    { sed -n "1,/^$SENTINELLE\$/p" "$dest"; echo; cat "$bloc"; sed "1,/^$SENTINELLE\$/d" "$dest"; } > "$TMP/dest"
  else
    {
      echo "> ⚠️ **ARCHIVÉ**, entrées de \`$FICHIER\` déplacées par rotation le $TODAY, gardées pour l'historique."
      echo "> **Origine** : \`$FICHIER\`"
      echo "> **Mois** : $m"
      echo "> **Ne pas utiliser comme source de vérité.** L'état courant est dans les piliers de la racine."
      echo "$SENTINELLE"
      echo
      cat "$bloc"
    } > "$TMP/dest"
    CREES="$CREES $dest"
  fi
  mv "$TMP/dest" "$dest"
done

# --- reecriture du journal ----------------------------------------------------
PLUS_ANCIENNE_GARDEE="$(awk -v g="$GARDER" '$1 == g { print $2 }' "$TMP/manifeste")"
if [ "$DRY" -eq 0 ]; then
  {
    printf '%s\n' "$(cat "$TMP/preambule")"
    echo
    echo "> Entrées antérieures au $PLUS_ANCIENNE_GARDEE : \`$DEST_DIR/\`, une par mois, jamais lues en reprise."
    echo
    i=1
    while [ "$i" -le "$GARDER" ]; do
      cat "$TMP/$(printf '%04d' "$i")"
      i=$((i + 1))
    done
  } > "$TMP/journal"
  mv "$TMP/journal" "$FICHIER"
fi
echo
echo "  $FICHIER garde $GARDER entrees, la plus ancienne du $PLUS_ANCIENNE_GARDEE."

# --- index des archives -------------------------------------------------------
# Une ligne par fichier de mois, posee a sa creation. Un fichier deja indexe ne
# recoit pas de seconde ligne.
if [ -n "$CREES" ]; then
  if [ -f archives/README.md ] && grep -q '^|---|' archives/README.md; then
    for dest in $CREES; do
      grep -q "$dest" archives/README.md && continue
      ligne="| $TODAY | \`$FICHIER\` | \`$dest\` | rotation du journal, entrées du mois $(basename "$dest" .md) | \`$FICHIER\` |"
      awk -v l="$ligne" 'BEGIN{fait=0} { print } /^\|---\|/ && !fait { print l; fait=1 }' archives/README.md > "$TMP/readme"
      mv "$TMP/readme" archives/README.md
      echo "  index : ligne ajoutee dans archives/README.md pour $dest"
    done
  else
    echo "  index : archives/README.md absent ou sans table, ajouter a la main une ligne par fichier cree :"
    for dest in $CREES; do echo "          $dest"; done
  fi
fi

echo
echo "Rien n'est commite. Verifie avec git status, puis git add les fichiers touches."
