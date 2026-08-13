# CONVENTION : spécification des 3 piliers

> Référence détaillée. Le résumé opérationnel est dans `SKILL.md`.
> Tout ce que tu écris ici suit la règle du skill `style-redaction`.

## Le principe : une question par fichier

Si la doc pourrit, c'est rarement parce qu'on écrit trop peu. C'est parce qu'on demande à un
seul fichier de faire plusieurs métiers. Il devient un mur d'exceptions que plus personne ne
lit, donc que plus personne ne met à jour.

La convention répartit la connaissance selon la question à laquelle elle répond, et selon sa
durée de vie.

| Surface | Question | Durée de vie | Chargement |
|---|---|---|---|
| `CLAUDE.md` ou `AGENTS.md` | Comment on travaille ici ? | Très stable | Toujours, automatique |
| `CODEMAP.md` | Où ça se trouve ? | Stable, évolue avec la structure | À la reprise |
| `TODOS.md` | Quoi maintenant ? | Volatile | À la reprise |
| `CHANGELOG.md` | Qu'est-ce qui a changé ? | Append-only | 2 ou 3 entrées à la reprise |
| `docs/` | Comment ça marche en détail ? | Longue, mais datée | À la demande, ciblé |
| `archives/` | Qu'est-ce qui était vrai avant ? | Figée | Jamais, sauf archéologie |

Corollaire : ne mets jamais la même information dans deux surfaces. Une info dupliquée est une
info qui va diverger. Tu mets un pointeur, pas une copie.

Il n'y a **pas de fichier de mémoire** dans cette convention, et ce n'est pas un oubli. Un
fichier dont la définition est « ce que le code ne dit pas » se remplit de tout, et recopie ce
que les autres surfaces portent déjà. Chaque savoir a donc un propriétaire unique.

| Ce que tu as appris | Où ça va |
|---|---|
| Décision et son pourquoi | `docs/decisions/ADR-NNNN-*.md` |
| Piège d'un module | La fiche `docs/modules/<module>.md` de ce module |
| Piège sans module identifiable | `CODEMAP.md`, section zones sensibles |
| Préférence durable de l'utilisateur | `CLAUDE.md` |
| Contrainte d'environnement, accès, outil disponible | `CODEMAP.md`, section dépendances |
| Fait externe daté et périssable | `docs/veille/`, ou une entrée de `CHANGELOG.md` |

Le test à l'écriture tient en une question : **qui est propriétaire de cette phrase ?** Si tu ne
sais pas répondre, c'est presque toujours qu'elle n'a pas besoin d'être écrite.

Attention à un homonyme. Claude Code tient sa propre mémoire automatique dans un fichier nommé
`MEMORY.md`, sous `~/.claude/projects/<projet>/memory/`. Il est local à la machine, il ne survit
ni à un clone ni à un changement de poste, et il ne fait pas partie de cette convention. Ne le
commite pas, ne recopie rien depuis ou vers lui. Le dépôt fait autorité.

---

## Emplacement et adaptation

Le bloc en tête de `CODEMAP.md` déclare les chemins réels du projet. Ça rend la convention
auto-descriptive. Un projet qui utilise `documentation/` au lieu de `docs/` le déclare, et
tout le reste suit.

```html
<!-- contexte:convention
profil: app
piliers: CODEMAP.md, TODOS.md, CHANGELOG.md
docs: docs/
archives: archives/
langue: fr
-->
```

Sans ce bloc, on suppose les chemins par défaut ci-dessus.

**Multi-niveaux** : chaque unité autonome (racine, package d'un monorepo, sous-projet) a son
propre kit. Le parent ne recopie pas le contenu des enfants, il les liste et pointe vers eux.
Une session qui touche plusieurs niveaux les met tous à jour.

---

## CODEMAP.md, la carte

**Rôle** : trouver le bon fichier en une lecture, et comprendre ce qui casse quand on le
modifie. Ce fichier n'est ni une doc d'API ni un tutoriel.

**Ce qu'on y met**

1. Le bloc `contexte:convention`, profil et chemins.
2. **Une phrase** qui dit ce que fait le projet. Un lecteur qui ne connaît rien doit pouvoir
   décider en dix secondes s'il est au bon endroit.
3. **Arborescence commentée.** Les répertoires qui comptent, une ligne de rôle chacun. Pas de
   sortie brute de `tree`. Tu cites ce qui porte du sens, tu omets le bruit (dépendances,
   builds, caches).
4. **Modules.** Un tableau avec le nom, le chemin, le rôle en une ligne et la fiche `docs/`
   si elle existe.
5. **Points d'entrée.** Par où le code démarre vraiment : main, serveur, CLI, handler, cron,
   worker. C'est ce qu'on cherche en premier et qu'on trouve le moins vite.
6. **Flux principal.** Le chemin nominal d'une requête ou d'un traitement, en trois à six
   étapes, avec les fichiers traversés. Rien ne remplace ça pour un lecteur à froid.
7. **Dépendances externes.** Services, API, bases, files, comptes. Tout ce dont le projet a
   besoin pour tourner. **Jamais de secret** : tu dis où est la clé, pas ce qu'elle vaut.
8. **Commandes.** Install, run, test, lint, build, deploy. Les vraies, celles que tu as testées.
9. **Zones sensibles.** Code généré à ne pas éditer, fichiers à ne toucher qu'avec précaution,
   conventions non évidentes.
10. La date de dernière mise à jour.

**Ce qui n'y va pas** : l'historique (CHANGELOG), les tâches (TODOS), le pourquoi des décisions
(`docs/decisions/`), les détails d'implémentation (`docs/modules/`).

**Longueur visée** : entre 100 et 250 lignes. Au-delà, c'est le signe qu'une partie du contenu
doit descendre dans `docs/`.

---

## TODOS.md, l'état de reprise

**Rôle** : c'est le fichier qui rend le `/clear` sans danger. Il porte à la fois ce qu'il reste
à faire, et où on en était exactement.

**Structure imposée**

```markdown
# TODOS, <projet>

## 🔄 État à la reprise, AAAA-MM-JJ
**Où on en est** : <2 à 4 lignes factuelles, ce qui marche, ce qui est en place>
**En cours** : <la tâche entamée et pas finie, avec les fichiers concernés, ou « rien »>
**Prochaine étape** : <la toute prochaine action concrète, pas un objectif vague>
**À savoir avant de toucher** : <pièges, état instable, travail à moitié appliqué>

## 🔴 Bloqué
- [ ] <tâche>, bloquée par <quoi>, à débloquer en <comment>

## 🎯 Prochaines étapes
- [ ] <tâche actionnable, verbe à l'infinitif, avec le fichier ou la zone>

## 🧹 Dette et améliorations
- [ ] <ce qu'on sait imparfait, avec l'impact, pas juste « refactorer »>

## 💡 Idées non engagées
- <ce qu'on ne fera peut-être jamais, à purger sans état d'âme>
```

**Les règles**

Le bloc « État à la reprise » est **réécrit** à chaque clôture, jamais empilé. C'est un état,
pas un journal.

Une tâche cochée n'est pas archivée, elle est **supprimée**. Sa trace est au CHANGELOG. TODOS
ne garde que le futur.

Toute tâche mentionne un point d'ancrage : un fichier, un module, une commande. « Améliorer les
perfs » ne sert à rien après un `/clear`. « Réduire les N+1 dans `repo/orders.py:list_orders` »
se reprend tout de suite.

Rien d'entamé ne doit rester hors de ce fichier avant un `/clear`.

---

## Les savoirs durables, et où ils atterrissent

Ce sont les faits qu'aucune lecture du dépôt ne permet de retrouver. Ils n'ont pas de pilier à
eux, chacun rejoint la surface qui le porte déjà. C'est ce qui rend la non-duplication
vérifiable au lieu d'être une intention.

### Une décision, avec son pourquoi

Direction `docs/decisions/`, un ADR par décision, gabarit dans `templates/docs/ADR.md`. Contexte,
options envisagées, décision, conséquences, et ce qui devrait la faire reconsidérer. Cette
dernière section est celle qui rend l'ADR utile deux ans plus tard.

Un ADR accepté **ne se réécrit jamais** et ne s'archive pas. Quand la décision change, un
nouvel ADR le supersède et l'ancien reçoit une ligne de statut en tête qui pointe vers le
nouveau. On garde la trace du raisonnement, y compris quand il s'est révélé faux.

### Un piège

S'il appartient à un module, il va dans la fiche `docs/` de ce module, section pièges. Sinon,
dans `CODEMAP.md`, section zones sensibles. Un piège s'écrit comme un symptôme suivi de sa
cause, pas comme une consigne. « L'API renvoie 200 avec l'erreur dans le corps » se retient,
« attention aux erreurs de l'API » ne sert à rien.

### Une préférence de l'utilisateur

Direction `CLAUDE.md`, qui est le fichier fait pour ça et qui se charge tout seul. Style
demandé, conventions imposées, ce qu'il ne veut pas qu'on fasse. `CLAUDE.md` se paie à chaque
session, donc il reste court et ne contient que du permanent.

### Une contrainte d'environnement ou d'accès

Direction `CODEMAP.md`, section dépendances externes. Quel service, quel compte, quelle région,
où vit la clé. **Jamais la valeur d'un secret**, on dit où elle est, pas ce qu'elle vaut.

### Un fait externe daté

Une limite constatée chez un tiers, un ticket amont, l'état d'un écosystème à un instant. Ça va
dans `docs/veille/` avec sa date, ou dans une entrée de `CHANGELOG.md` si c'est ce qui explique
un changement. Ce contenu est périssable par nature, il se relit ou s'archive, il ne se garde
pas indéfiniment.

### Les règles communes

Dates absolues uniquement. « La semaine dernière » devient faux dès le lendemain.

Un fait porte son **pourquoi**, pas seulement son quoi. Sans le pourquoi, on ne saura pas plus
tard s'il tient encore.

Une règle durable devenue fausse est **supprimée tout de suite**, pas archivée. Elle est pire
qu'une règle absente, et `archives/` n'est pas une poubelle à erreurs ponctuelles. Si sa
disparition mérite une trace, elle va au CHANGELOG. Les ADR font exception, ils se supersèdent.

Si tu hésites entre deux propriétaires, choisis celui qui sera relu par quelqu'un qui travaille
sur le sujet. Un fait rangé là où personne ne le cherche ne vaut pas mieux qu'un fait absent.

---

## CHANGELOG.md, le journal

**Rôle** : répondre à « qu'est-ce qui a changé, quand, pourquoi et comment on revient en
arrière ». C'est la seule surface append-only de la convention.

**Format**

```markdown
## 2026-08-13, titre court et factuel

**Quoi** : ce qui a changé, concrètement. Fichiers, comportements, ressources.
**Pourquoi** : le besoin ou le problème derrière.
**Rollback** : comment défaire. Commit à révoquer, config à restaurer, migration inverse.
**Voir aussi** : `docs/...`, ADR, ticket.
```

**Les règles**

Plus récent en haut. Une entrée par session utile, pas une par commit.

Le rollback n'est pas optionnel dès qu'un changement touche une donnée, un déploiement, une
dépendance ou une configuration. C'est ce qui sauve la session suivante.

Tu ne réécris jamais le passé. Une entrée erronée se corrige par une nouvelle entrée qui la
mentionne, pas par une édition silencieuse.

Une entrée volumineuse reste courte ici et pointe vers `docs/`, ou vers `changes/<date>-<slug>.md`
si le projet a ce répertoire.

Si le projet publie des versions, tu peux adopter la structure Keep a Changelog
(`## [1.4.0] 2026-08-13`, avec des sections Ajouté, Modifié, Corrigé, Retiré). La règle
quoi, pourquoi, rollback reste applicable dans chaque section.

---

## Ce qui vit dans CLAUDE.md, et pas ici

`CLAUDE.md` est chargé automatiquement à chaque session. C'est la surface la plus coûteuse en
contexte. Tu y mets uniquement ce qui doit être vrai à chaque instant : commandes à utiliser,
interdits durs, préférences durables de l'utilisateur, style, et le pointeur vers la convention
de contexte.

Le reste vit ailleurs et se charge à la demande. La carte dans CODEMAP, l'état dans TODOS,
l'historique dans CHANGELOG, les décisions dans `docs/decisions/`, le détail dans `docs/`.

C'est `CLAUDE.md` qui absorbe le plus facilement ce qui n'a pas de propriétaire évident, et
c'est le risque à surveiller. Une règle qui n'est pas vraie à chaque instant n'a rien à y faire.
Relis-le à chaque clôture avec cette question en tête, et coupe. Le bloc à coller est dans
`templates/CLAUDE-snippet.md`.
