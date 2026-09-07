---
description: Reprise après un /clear. Reconstruit le contexte depuis le dépôt et dit où on en était, sans recharger la moitié du projet.
argument-hint: [ce sur quoi tu veux travailler, optionnel]
---

Intention pour cette session, si elle est précisée : $ARGUMENTS

Lance le skill **cloture-session** en **mode REPRISE**.

Ordre de lecture, tu ne le changes pas :

1. `CLAUDE.md` s'il existe, pour les règles et les préférences durables.
2. Le bloc « État à la reprise » de `TODOS.md`, et rien d'autre du fichier :

   ```bash
   awk '/^## /{n++} n<=1' TODOS.md
   ```
3. Le plan de `CODEMAP.md`, puis la seule section utile, puis la carte de la zone concernée si
   elle existe :

   ```bash
   grep -n '^## ' CODEMAP.md
   ```
4. Les 3 dernières entrées de `CHANGELOG.md`, pas tout l'historique :

   ```bash
   awk '/^## /{n++} n<=3' CHANGELOG.md
   ```
5. Les fiches `docs/` des seuls modules concernés par l'intention ci-dessus, et l'ADR
   correspondant si tu t'apprêtes à revenir sur un choix déjà tranché.
6. `git log --oneline -10` et `git status -s`.

Tu ne lis jamais un pilier en entier. Si l'un d'eux déborde malgré tout, tu le signales dans ta
restitution.

Tu ne lis pas `archives/`. C'est faux ou froid par construction. Sur demande explicite
d'archéologie, le skill porte `scripts/ctx-archeo.sh`, qui rend la provenance avant l'extrait et
borne sa sortie. Son chemin se résout comme dans `/cloture`, la boucle est dans le `SKILL.md`.
Jamais un `grep` nu sur les archives : il rend une ligne sans son en-tête, donc on prend une entrée
froide pour une vérité courante.

Ensuite, restitue en dix lignes maximum : où on en est, ce qui est en cours, la prochaine étape
concrète, les pièges à connaître. Si tu trouves une incohérence entre la doc et le dépôt,
signale-la tout de suite et corrige-la avant de commencer à coder.
