---
description: Reprise après un /clear. Reconstruit le contexte depuis le dépôt et dit où on en était, sans recharger la moitié du projet.
argument-hint: [ce sur quoi tu veux travailler, optionnel]
---

Intention pour cette session, si elle est précisée : $ARGUMENTS

Lance le skill **cloture-session** en **mode REPRISE**.

Ordre de lecture, tu ne le changes pas :

1. `CLAUDE.md` s'il existe, pour les règles et les préférences durables.
2. `TODOS.md`, le bloc « État à la reprise » en premier.
3. `CODEMAP.md`, pour localiser ce que tu vas toucher, et ses zones sensibles pour les pièges.
4. `CHANGELOG.md`, les 2 ou 3 dernières entrées, pas plus.
5. Les fiches `docs/` des seuls modules concernés par l'intention ci-dessus, et l'ADR
   correspondant si tu t'apprêtes à revenir sur un choix déjà tranché.
6. `git log --oneline -10` et `git status -s`.

Tu ne lis pas `archives/`. C'est périmé par construction.

Ensuite, restitue en dix lignes maximum : où on en est, ce qui est en cours, la prochaine étape
concrète, les pièges à connaître. Si tu trouves une incohérence entre la doc et le dépôt,
signale-la tout de suite et corrige-la avant de commencer à coder.
