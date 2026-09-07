---
description: Clôture de session avant un /clear. Synchronise les 3 piliers, documente les modules touchés, archive tout ce qui est obsolète ou faux, et remet chaque fichier dans son budget.
argument-hint: [note libre sur ce qui a été fait, optionnel]
---

Note de session, si elle est fournie : $ARGUMENTS

Lance le skill **cloture-session** en **mode CLÔTURE**.

Lis d'abord `SKILL.md` du skill, puis applique les phases 0 à 7 dans l'ordre. Charge le skill
`style-redaction` avant d'écrire la moindre ligne, et les références seulement quand tu en as
besoin, en particulier `references/ARCHIVAGE.md` au moment de la phase 4.

Le script d'audit de la phase 1 vit dans le skill, pas dans le projet courant. Résous son chemin
avant de l'appeler :

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
bash "$SKILL/scripts/ctx-audit.sh"
bash "$SKILL/scripts/ctx-audit.sh" --budget
```

La mesure du budget se fait deux fois, en phase 0 pour cadrer et en phase 5 pour vérifier ce qui
reste. Un `[!!]` ne se reporte pas d'une clôture à l'autre.

L'ordre couvre l'installation en plugin, puis la portée projet chez Claude Code et chez Codex,
puis leur portée utilisateur, puis les copies de plugin de Claude Code.

`cache/` passe avant `marketplaces/` : le premier porte la version installée, le second la pointe
de `master` du dépôt. Les deux copient le même plugin, elles divergent dès que le dépôt avance.

Si `$SKILL` ressort vide, le skill n'est pas installé là où tu le crois. Tu fais l'audit à la
main et tu le signales, tu n'appelles pas un chemin qui n'existe pas.

Rappels qui coûtent cher si tu les oublies :

- Tu calibres l'effort sur la taille de la session, mais le scan d'obsolescence de la phase 4
  se fait dans tous les cas.
- Tu vérifies l'état réel avant d'écrire. La doc existante n'est pas une source fiable, c'est
  justement ce que tu es en train d'auditer.
- Tu mets à jour tous les niveaux touchés, pas seulement le répertoire courant.
- Le bloc de reprise se réécrit depuis l'état courant, 40 lignes, et ce que tu en retires a un
  propriétaire.
- Un journal qui déborde se fait tourner avec `ctx-rotation.sh`, en `--dry-run` d'abord, il ne se
  résume pas.
- Un document obsolète s'archive avec `bash "$SKILL/scripts/ctx-archive.sh"`, jamais un `git mv`
  à la main : la ligne d'index et la vérification finale sautent, et c'est justement l'étape
  qu'on oublie.
- Tu ne commites rien sans qu'on te le demande.

Si le projet n'a pas encore le kit de contexte, fais INIT puis CLÔTURE dans la foulée, sans
poser la question.
