#!/usr/bin/env bash
#
# ctx-init.sh : installe la convention de contexte dans un projet.
#
# Non destructif. Un fichier qui existe deja n'est JAMAIS touche.
# Usage :
#   bash ctx-init.sh [--root <chemin>] [--profil <profil>] [--dry-run] [--with-claude]
#
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TPL="$SKILL_DIR/templates"

ROOT=""
PROFIL=""
DRY=0
WITH_CLAUDE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)        ROOT="${2:-}"; shift 2 ;;
    --profil)      PROFIL="${2:-}"; shift 2 ;;
    --dry-run)     DRY=1; shift ;;
    --with-claude) WITH_CLAUDE=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
[ -d "$ROOT" ] || { echo "Racine introuvable : $ROOT" >&2; exit 1; }
ROOT="$(cd "$ROOT" && pwd)"

DATE="$(date +%F)"
PROJECT_NAME="$(basename "$ROOT")"

# --- detection du profil ------------------------------------------------------
detect_profil() {
  local r="$1"
  if [ -f "$r/pnpm-workspace.yaml" ] || [ -f "$r/turbo.json" ] || [ -f "$r/go.work" ] \
     || [ -d "$r/packages" ] || [ -d "$r/apps" ]; then
    echo monorepo; return
  fi
  if [ -f "$r/SKILL.md" ] || [ -d "$r/.claude/skills" ] || [ -f "$r/plugin.json" ]; then
    echo outillage-agent; return
  fi
  if [ -d "$r/terraform" ] || [ -d "$r/ansible" ] || [ -d "$r/k8s" ] \
     || ls "$r"/*.tf >/dev/null 2>&1; then
    echo infra; return
  fi
  if [ -d "$r/notebooks" ] || [ -d "$r/models" ] || [ -f "$r/dvc.yaml" ]; then
    echo data; return
  fi
  if [ -f "$r/package.json" ] || [ -f "$r/pyproject.toml" ] || [ -f "$r/go.mod" ] \
     || [ -f "$r/Cargo.toml" ] || [ -f "$r/manage.py" ] || [ -f "$r/pom.xml" ]; then
    echo app; return
  fi
  if [ -d "$r/content" ] || [ -d "$r/posts" ]; then
    echo contenu; return
  fi
  echo non-technique
}

[ -n "$PROFIL" ] || PROFIL="$(detect_profil "$ROOT")"

# --- helpers ------------------------------------------------------------------
CREATED=0
SKIPPED=0

render() { # <source> <destination>
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    printf '  = %-24s deja present, non touche\n' "${dst#$ROOT/}"
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  printf '  + %-24s cree\n' "${dst#$ROOT/}"
  CREATED=$((CREATED + 1))
  [ "$DRY" -eq 1 ] && return
  mkdir -p "$(dirname "$dst")"
  sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      -e "s|{{DATE}}|$DATE|g" \
      -e "s|{{PROFIL}}|$PROFIL|g" \
      "$src" > "$dst"
}

mkdirp() { # <chemin>
  if [ -d "$1" ]; then return; fi
  printf '  + %-24s cree\n' "${1#$ROOT/}/"
  CREATED=$((CREATED + 1))
  [ "$DRY" -eq 1 ] && return
  mkdir -p "$1"
}

# --- execution ----------------------------------------------------------------
echo "Convention de contexte"
echo "  racine  : $ROOT"
echo "  projet  : $PROJECT_NAME"
echo "  profil  : $PROFIL"
[ "$DRY" -eq 1 ] && echo "  mode    : simulation, rien ne sera ecrit"
echo

echo "Piliers"
render "$TPL/CODEMAP.md"   "$ROOT/CODEMAP.md"
render "$TPL/TODOS.md"     "$ROOT/TODOS.md"
render "$TPL/CHANGELOG.md" "$ROOT/CHANGELOG.md"

echo
echo "Documentation"
mkdirp "$ROOT/docs/modules"
mkdirp "$ROOT/docs/features"
mkdirp "$ROOT/docs/ops"
mkdirp "$ROOT/docs/decisions"
render "$TPL/docs/README.md" "$ROOT/docs/README.md"

echo
echo "Archives"
render "$TPL/archives/README.md" "$ROOT/archives/README.md"

echo
echo "Regles projet"
if [ -f "$ROOT/CLAUDE.md" ]; then
  if grep -q "Convention de contexte" "$ROOT/CLAUDE.md" 2>/dev/null; then
    echo "  = CLAUDE.md               contient deja la convention"
  elif [ "$WITH_CLAUDE" -eq 1 ]; then
    echo "  ~ CLAUDE.md               bloc de convention ajoute a la fin"
    if [ "$DRY" -eq 0 ]; then
      printf '\n' >> "$ROOT/CLAUDE.md"
      sed '/^<!--$/,/^-->$/d' "$TPL/CLAUDE-snippet.md" >> "$ROOT/CLAUDE.md"
    fi
  else
    echo "  ! CLAUDE.md existe mais ne mentionne pas la convention."
    echo "    Relance avec --with-claude, ou colle a la main le bloc de :"
    echo "    $TPL/CLAUDE-snippet.md"
  fi
else
  printf '  + %-24s cree\n' "CLAUDE.md"
  CREATED=$((CREATED + 1))
  if [ "$DRY" -eq 0 ]; then
    {
      echo "# CLAUDE.md, $PROJECT_NAME"
      echo
      sed '/^<!--$/,/^-->$/d' "$TPL/CLAUDE-snippet.md"
    } > "$ROOT/CLAUDE.md"
  fi
fi

echo
echo "Bilan : $CREATED cree(s), $SKIPPED conserve(s)."
cat <<EOF

A faire maintenant, les gabarits sont vides et ne servent a rien en l'etat :
  1. Lire le projet (arborescence, points d'entree, build, CI) avant d'ecrire.
  2. Remplir CODEMAP.md avec la carte reelle.
  3. Remplir TODOS.md avec l'etat reel, puis le bloc "Etat a la reprise".
  4. Creer les fiches docs/ des modules qui le meritent, et un ADR dans docs/decisions/
     pour les choix deja pris qui engagent la suite. Le critere est dans
     $SKILL_DIR/references/DOCS-SYSTEM.md
  5. Mettre dans CLAUDE.md ce qui doit etre vrai a chaque instant, et rien d'autre.

Verifier la derive a tout moment : bash $SCRIPT_DIR/ctx-audit.sh
EOF
