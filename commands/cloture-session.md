---
description: Clôture de session avant un /clear. Synchronise les 3 piliers, documente les modules touchés, archive tout ce qui est obsolète ou faux.
argument-hint: [note libre sur ce qui a été fait, optionnel]
---

Note de session, si elle est fournie : $ARGUMENTS

Lance le skill **cloture-session** en **mode CLÔTURE**.

Lis d'abord `SKILL.md` du skill, puis applique les phases 0 à 6 dans l'ordre. Charge le skill
`style-redaction` avant d'écrire la moindre ligne, et les références seulement quand tu en as
besoin, en particulier `references/ARCHIVAGE.md` au moment de la phase 4.

Le script d'audit de la phase 1 vit dans le skill, pas dans le projet courant. Résous son chemin
avant de l'appeler :

```bash
SKILL="$(for d in "$CLAUDE_PLUGIN_ROOT/skills/cloture-session" \
  ".claude/skills/cloture-session" "$HOME/.claude/skills/cloture-session" \
  $(find "$HOME/.claude/plugins" -maxdepth 7 -type d -path '*/skills/cloture-session' 2>/dev/null); do
  [ -f "$d/scripts/ctx-audit.sh" ] && echo "$d" && break
done)"
bash "$SKILL/scripts/ctx-audit.sh"
```

Si `$SKILL` ressort vide, le skill n'est pas installé là où tu le crois. Tu fais l'audit à la
main et tu le signales, tu n'appelles pas un chemin qui n'existe pas.

Rappels qui coûtent cher si tu les oublies :

- Tu calibres l'effort sur la taille de la session, mais le scan d'obsolescence de la phase 4
  se fait dans tous les cas.
- Tu vérifies l'état réel avant d'écrire. La doc existante n'est pas une source fiable, c'est
  justement ce que tu es en train d'auditer.
- Tu mets à jour tous les niveaux touchés, pas seulement le répertoire courant.
- Tu ne commites rien sans qu'on te le demande.

Si le projet n'a pas encore le kit de contexte, fais INIT puis CLÔTURE dans la foulée, sans
poser la question.
