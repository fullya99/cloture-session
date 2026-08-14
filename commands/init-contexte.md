---
description: Installe la convention de contexte dans le projet courant. Crée les 3 piliers, docs/ et archives/, puis les remplit depuis le projet réel.
argument-hint: [profil du projet, optionnel : app, lib, infra, data, contenu, monorepo]
---

Profil imposé, si l'utilisateur en donne un : $ARGUMENTS

Lance le skill **cloture-session** en **mode INIT**.

```bash
ANCETRES="$(d="$PWD"; while [ "$d" != "/" ]; do echo "$d/.agents/skills/cloture-session"; d="$(dirname "$d")"; done)"

SKILL="$(for d in "$CLAUDE_PLUGIN_ROOT/skills/cloture-session" \
  ".claude/skills/cloture-session" $ANCETRES \
  "$HOME/.claude/skills/cloture-session" \
  "$HOME/.codex/skills/cloture-session" "$HOME/.agents/skills/cloture-session" \
  $(find "$HOME/.claude/plugins/cache" -maxdepth 5 -type d -path '*/skills/cloture-session' 2>/dev/null | sort -r) \
  $(find "$HOME/.claude/plugins/marketplaces" -maxdepth 5 -type d -path '*/skills/cloture-session' 2>/dev/null); do
  [ -f "$d/scripts/ctx-audit.sh" ] && echo "$d" && break
done)"
bash "$SKILL/scripts/ctx-init.sh" --dry-run     # d'abord voir ce qui serait créé
bash "$SKILL/scripts/ctx-init.sh"               # puis créer, rien d'existant n'est écrasé
```

L'ordre couvre l'installation en plugin, puis la portée projet chez Claude Code et chez Codex,
puis leur portée utilisateur, puis les copies de plugin de Claude Code.

Tu es dans le projet à équiper, pas dans le skill, donc un chemin relatif du genre
`scripts/ctx-init.sh` ne résout pas.

Le script pose les gabarits, et c'est tout. Le travail commence après, parce qu'un gabarit vide
ne sert à personne.

Explore le projet **avant** d'écrire quoi que ce soit : arborescence, points d'entrée, fichier
de build, CI, README, derniers commits. Puis remplis CODEMAP avec la carte réelle, TODOS avec
l'état réel, et crée les fiches `docs/` des modules qui le méritent (le critère est dans
`references/DOCS-SYSTEM.md`). Les choix déjà pris et visibles dans le projet, qui engagent la
suite, deviennent des ADR dans `docs/decisions/`. Ce qui doit être vrai à chaque instant va dans
`CLAUDE.md`, et rien d'autre.

Ce que tu ne peux pas déduire du projet, demande-le. Ne l'invente jamais, une carte fausse est
pire que pas de carte du tout.

Termine en montrant à l'utilisateur ce qui a été créé, et ce qu'il reste à compléter à la main.
