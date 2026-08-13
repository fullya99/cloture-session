---
name: cloture-session
description: Clôture de session avant un /clear, et maintenance de la documentation vivante d'un projet, quel que soit son type. Synchronise les 3 piliers CODEMAP.md, TODOS.md, CHANGELOG.md, met à jour les fiches docs/ des modules et features touchés, et déplace vers archives/ tout ce qui est devenu faux, périmé ou remplacé, pour qu'une session neuve reprenne le travail sans perdre une information. Se déclenche sur : clôture ou fin de session, mise au propre, "avant de clear", "range le projet", "documente ce qu'on a fait", "archive ce qui est obsolète", doc vivante, CODEMAP, TODOS, CHANGELOG, /cloture. Couvre aussi l'installation de la convention dans un projet neuf (/init-contexte) et la reprise après un /clear (/reprise-session).
---

# Gestion de contexte : clôture, reprise, convention

> **Le contrat** : à tout instant, le dépôt seul doit suffire. Un `/clear` ne doit jamais
> coûter une information. Si une info ne vit que dans la conversation, elle n'existe pas.

Ce skill implémente une convention de documentation vivante avec archivage, conçue pour se
greffer sur n'importe quel type de projet : code applicatif, librairie, infra, data, contenu,
monorepo, ou même un projet sans une ligne de code.

**Avant d'écrire quoi que ce soit**, charge le skill **`style-redaction`**. Il porte la règle de
rédaction, et elle s'applique à tout ce que tu produis ici, sans exception. S'il n'est pas
installé, le minimum tient en une ligne : français, ton direct, aucun tiret cadratin, aucun
point-virgule, aucune tournure qui sent le texte généré.

---

## Le socle en 30 secondes

Trois fichiers à la racine, plus `CLAUDE.md`. C'est le kit de démarrage à froid. Chacun répond
à une question, et à une seule.

| Fichier | Question | Contenu | Se lit |
|---|---|---|---|
| **CODEMAP.md** | Où ça se trouve, et qu'est-ce qui touche quoi ? | Carte structurelle : arborescence commentée, modules, points d'entrée, flux, dépendances, commandes, zones sensibles | En premier, toujours |
| **TODOS.md** | Qu'est-ce que je fais maintenant ? | Bloc d'état de reprise en tête, travail en cours, prochaines étapes, dette, blocages | En premier, toujours |
| **CHANGELOG.md** | Qu'est-ce qui a changé, et comment revenir en arrière ? | Entrées datées, plus récent en haut : quoi, pourquoi, rollback | À la demande |
| **CLAUDE.md** | Qu'est-ce qui est vrai tout le temps ? | Règles du projet, préférences durables, contraintes d'accès. Chargé à chaque session, donc court | Automatiquement |

Il n'y a pas de fichier de mémoire. Chaque type de savoir a un propriétaire unique, et c'est ce
qui empêche la duplication : les décisions vont dans `docs/decisions/`, les pièges d'un module
dans sa fiche `docs/` ou dans les zones sensibles du CODEMAP, les préférences durables dans
`CLAUDE.md`, les faits externes datés dans `docs/veille/` ou au CHANGELOG. Le détail est dans
`references/CONVENTION.md`.

Deux répertoires pour la profondeur.

| Répertoire | Rôle |
|---|---|
| **`docs/`** | Une fiche par module et par feature qui compte, plus les procédures et les décisions. Seule zone où la connaissance longue a le droit de vivre. Tout y est daté et statué. |
| **`archives/`** | Cimetière tracé. Ce qui est obsolète, faux ou remplacé y est déplacé, jamais supprimé en douce, avec un en-tête qui dit la date, l'origine, la raison, le remplaçant. **Jamais lu comme source de vérité.** |

La règle qui fait tenir l'ensemble : **`docs/` ne contient que du vrai, `archives/` absorbe
tout le reste**. C'est ça qui empêche la doc de pourrir et qui permet de la lire en confiance
après n'importe quel `/clear`.

---

## Router : quel mode ?

| Situation | Mode | Aller à |
|---|---|---|
| Fin de session, avant un `/clear`, mise au propre, `/cloture` | **CLÔTURE** | [Mode CLÔTURE](#mode-clôture) |
| Début de session, après un `/clear`, « où on en était », `/reprise-session` | **REPRISE** | [Mode REPRISE](#mode-reprise) |
| Le projet n'a pas le kit, ou pas en entier, `/init-contexte` | **INIT** | [Mode INIT](#mode-init) |

Si le projet n'a pas le kit et qu'on te demande une clôture, fais INIT puis CLÔTURE dans la
foulée, sans demander. La clôture a besoin du support pour écrire quelque part.

**Adaptation au projet** : avant tout mode, lis le bloc `<!-- contexte:convention -->` en tête
de `CODEMAP.md` s'il existe. Il déclare les chemins réels et le profil du projet. Sinon, détecte
le profil avec `references/PROFILS-PROJETS.md`.

---

## Mode INIT

Installer la convention sans rien écraser.

```bash
bash "$SKILL/scripts/ctx-init.sh"            # crée ce qui manque, n'écrase jamais l'existant
bash "$SKILL/scripts/ctx-init.sh" --dry-run  # montre ce qui serait créé
```

`$SKILL` est le répertoire de ce skill, celui d'où tu viens de lire ce fichier. Tu travailles
depuis le projet à équiper, pas depuis le skill, donc les chemins relatifs du genre
`scripts/ctx-init.sh` ne résolvent pas. Résous-le une fois en début de mode :

```bash
SKILL="$(for d in "$CLAUDE_PLUGIN_ROOT/skills/cloture-session" \
  ".claude/skills/cloture-session" "$HOME/.claude/skills/cloture-session" \
  $(find "$HOME/.claude/plugins/cache" -maxdepth 5 -type d -path '*/skills/cloture-session' 2>/dev/null | sort -r) \
  $(find "$HOME/.claude/plugins/marketplaces" -maxdepth 5 -type d -path '*/skills/cloture-session' 2>/dev/null); do
  [ -f "$d/scripts/ctx-audit.sh" ] && echo "$d" && break
done)"
[ -n "$SKILL" ] || echo "skill introuvable, fais les etapes a la main sans le script"
```

L'ordre est voulu. `CLAUDE_PLUGIN_ROOT` d'abord quand le skill tourne comme plugin, puis
l'installation projet, puis l'installation user, puis les plugins installés.

Un plugin installé existe en deux copies. `cache/<marketplace>/<plugin>/<version>/` porte la version
réellement installée, `marketplaces/<marketplace>/` porte la pointe de `master` du dépôt. On cherche
le cache d'abord, et le `sort -r` prend la version la plus haute quand plusieurs sont en cache. Sans
cet ordre, un `find` unique renvoie les deux et prend celle que le parcours donne en premier, ce qui
choisit au hasard dès que le dépôt a avancé au-delà de la version installée.

Le test porte sur la présence de `scripts/ctx-audit.sh`, ce qui écarte au passage les répertoires
homonymes.

Le script pose les gabarits. Le vrai travail commence après, parce qu'un gabarit vide ne sert
à personne.

1. **Lis le projet avant d'écrire.** Arborescence, points d'entrée, `package.json` ou
   `pyproject.toml` ou `Makefile`, la CI, le README, les derniers commits. Ne remplis jamais
   le CODEMAP à partir d'une supposition.
2. **CODEMAP.md** : la carte réelle. Modules avec leur rôle en une ligne, points d'entrée, flux
   principal, dépendances externes, commandes qui marchent vraiment. Renseigne le bloc
   `contexte:convention` en tête.
3. **TODOS.md** : l'état réel. Ce qui est en cours, ce qui est cassé, la dette visible.
4. **CHANGELOG.md** : une entrée d'amorçage. Tu ne réécris pas l'histoire passée du projet.
5. **`docs/`** : crée les fiches des modules qui **méritent** une fiche, et un ADR pour les
   décisions déjà prises et visibles (choix de stack, conventions implicites) quand elles
   engagent la suite. Le critère est dans `references/DOCS-SYSTEM.md`. Pas de fiche vide, pas de
   fiche pour tout. Ce que tu ne peux pas déduire, demande-le plutôt que de l'inventer.
6. Colle le bloc de `templates/CLAUDE-snippet.md` dans le `CLAUDE.md` du projet, crée-le s'il
   n'existe pas. C'est ce qui fait que les sessions suivantes respectent la convention sans
   qu'on ait à le redire à chaque fois.

Le détail de chaque fichier est dans `references/CONVENTION.md`.

---

## Mode CLÔTURE

Le but n'est pas de résumer la session. Le but est de rendre le dépôt complet et exact, pour
qu'une session neuve, sans cette conversation, reprenne au bon endroit.

Question à te reposer à chaque phase :

> Un lecteur à froid, avec seulement CODEMAP, TODOS, CHANGELOG, CLAUDE.md et `docs/`, comprend-il
> l'état réel et sait-il quoi faire ensuite ?

### Phase 0. Cadrer

```bash
git status -s && git diff --stat && git log --oneline -10
```

1. **Périmètre.** Ce qui a changé, y compris hors git : fichiers non trackés, ressources
   externes créées (service, base, DNS, clé), effets de bord système.
2. **Niveaux.** Une session démarrée dans un sous-répertoire touche souvent au-dessus : racine
   du monorepo, config partagée, `~/.claude`. Repère tous les niveaux qui ont leur propre kit,
   chacun devra être mis à jour. Ne documente jamais que le cwd.
3. **Proportionnalité.** Calibre l'effort, mais ne saute rien.
   - Petite session (un ou deux fichiers, aucune structure touchée) : CHANGELOG en entrée
     courte, TODOS et **le scan d'obsolescence de la phase 4, toujours**.
   - Session conséquente (nouveau module, refactor, infra, dépendance) : toutes les phases.
4. Annonce le plan en une ligne, dis quels fichiers tu vas toucher, puis exécute sans redemander.

### Phase 1. Auditer le réel, sans faire confiance aux docs

```bash
bash "$SKILL/scripts/ctx-audit.sh"   # dérive, fiches périmées, liens morts, modules non documentés, archives non indexées
```

Le script s'exécute sur le projet courant quel que soit l'endroit d'où tu l'appelles. Si `$SKILL`
n'est pas encore résolu, voir le mode INIT plus haut.

Le script signale, il ne juge pas. À toi de vérifier sur le terrain ce que la session a touché :
le service tourne-t-il vraiment, la ressource existe-t-elle, le test passe-t-il, le chemin cité
dans la doc existe-t-il encore.

Note chaque écart sous la forme « la doc dit X, la réalité est Y ». Chaque écart aura une issue
et une seule : corrigé en phase 2 ou 3, ou archivé en phase 4. Aucun écart ne reste ouvert.

Si des outils de recherche sont branchés dans la session (Hub MCP, `WebSearch`, Context7), ils
servent ici à vérifier qu'une procédure documentée correspond encore à la version courante d'un
outil tiers. Aucune étape ne doit échouer faute de ces outils. Sans eux, tu vérifies à la main
et tu le notes.

### Phase 2. Synchroniser les 3 piliers

| Pilier | Ce que tu y fais |
|---|---|
| **CHANGELOG.md** | Ajoute en haut `## AAAA-MM-JJ, titre`. Trois choses : **quoi** (factuel), **pourquoi**, **rollback** (comment défaire). Un gros lot reste court ici et pointe vers `docs/`. |
| **CODEMAP.md** | Reflète la nouvelle structure : module ajouté, supprimé ou renommé, point d'entrée déplacé, dépendance ajoutée, commande changée. **Retire ce qui n'existe plus.** Ajoute les pièges sans module aux zones sensibles. Mets à jour la date. |
| **TODOS.md** | Coche le fait, **supprime** l'obsolète, ajoute les tâches et dettes découvertes. Puis **réécris le bloc « État à la reprise » en tête**, c'est lui qui sera lu en premier après le `/clear`. |

Les faits durables appris cette session ne vont pas dans un pilier, ils vont chez leur
propriétaire. Une décision et son pourquoi, un ADR dans `docs/decisions/`. Un piège de module,
sa fiche `docs/`. Une préférence exprimée par l'utilisateur, `CLAUDE.md`. Une contrainte
d'environnement, le CODEMAP. Le test tient en une question, **qui est propriétaire de cette
phrase ?**, et si tu ne sais pas répondre c'est presque toujours qu'elle n'a pas à être écrite.

N'écris pas ce que le dépôt enregistre déjà, structure du code ou historique git. Le détail est
dans `references/CONVENTION.md`.

**Multi-niveaux** : applique ce tableau à chaque niveau touché repéré en phase 0. Un sous-projet
a sa propre doc vivante, le parent **pointe** vers elle, il ne l'absorbe pas.

### Phase 3. Documenter les modules et features dans `docs/`

Pour chaque module ou feature touché sérieusement cette session :

- la fiche existe, tu la **corriges** et tu repasses l'en-tête à `✅ à jour, vérifié le AAAA-MM-JJ`,
- elle n'existe pas et le sujet **mérite** une fiche, tu la crées depuis `templates/docs/`,
- elle existe mais le sujet a disparu, direction `archives/` en phase 4.

Le critère « mérite une fiche », détaillé dans `references/DOCS-SYSTEM.md`, tient en un test.
Au moins un de ces cas doit être vrai : plusieurs fichiers coopèrent, une API est consommée
ailleurs, un invariant n'est pas évident dans le code, ça a été difficile à faire marcher, une
procédure doit être rejouable, une décision structurante a été prise.

Mets `docs/README.md` à jour dans le même mouvement. Une fiche non indexée est une fiche que
personne ne lira, donc que personne ne corrigera.

### Phase 4. Purger l'obsolète vers `archives/`. Phase clé, jamais sautée

Passe en revue les fiches, procédures, scripts, plans et propositions abandonnées, à la
recherche de ce qui est faux, périmé ou remplacé. L'arbre de décision complet, le format
d'en-tête et les chemins sont dans `references/ARCHIVAGE.md`.

En résumé :

- **Fichier obsolète** : `git mv` vers `archives/AAAA-MM/<chemin d'origine>`, en-tête `ARCHIVÉ`
  avec date, origine, raison, remplaçant, plus une ligne dans `archives/README.md`.
- **Section fausse dans un fichier encore utile** : tu **corriges sur place**, tu ne déplaces
  pas le fichier, et tu notes le correctif au CHANGELOG.
- **Règle durable devenue fausse** dans `CLAUDE.md` : suppression pure. Une règle erronée est
  pire qu'une règle absente, et `archives/` n'est pas une poubelle à erreurs ponctuelles. Si sa
  disparition compte, elle laisse une ligne au CHANGELOG.
- **Référence morte** (lien, chemin, ressource supprimée) : corrige ou retire.

Règle d'or, à la fin de cette phase aucune affirmation connue-fausse ne subsiste dans les
piliers, dans `CLAUDE.md`, ni dans `docs/`. Et aucune suppression silencieuse.

### Phase 5. Test « prêt pour /clear »

Checklist bloquante, version détaillée dans `references/HANDOFF.md`.

- [ ] Les 3 piliers reflètent l'état réel vérifié en phase 1, sans se contredire entre eux.
- [ ] Le bloc « État à la reprise » de TODOS.md permet de reprendre sans cette conversation.
- [ ] Tout travail en cours non terminé a une tâche explicite, sinon il est perdu au `/clear`.
- [ ] Chaque module ou feature touché a une fiche `docs/` à jour et indexée.
- [ ] Ce qui est obsolète est dans `archives/`, avec en-tête et ligne d'index.
- [ ] Aucun secret dans un fichier tracké. `git status` conforme à l'intention.
- [ ] Relecture croisée : ouvre TODOS et CODEMAP, vérifie qu'ils racontent la même histoire.

### Phase 6. Compte-rendu, puis commit si on te le demande

Sortie en texte simple, jamais d'artifact.

```
**Clôture de session, AAAA-MM-JJ**

Fait cette session : [1 à 3 lignes factuelles]

Piliers : CHANGELOG ✓ · CODEMAP ✓ · TODOS ✓
docs/ : +[N] fiche(s), ~[N] mise(s) à jour, +[N] ADR
archives/ : [N] élément(s), [liste courte avec la raison] ou « rien à archiver »
CLAUDE.md : [ce qui a bougé, ou « inchangé »]
Niveaux mis à jour : [cwd] · [parent si touché] · [~/.claude si touché]
Reste à faire : [2 ou 3 items clés, pointeur vers TODOS.md]

Prêt pour /clear ✅
```

**Commit** : jamais sans demande explicite. Tu proposes, tu attends. Si on te le demande,
seulement les fichiers trackés, message clair sur le quoi et le pourquoi, branche de travail
désignée.

---

## Mode REPRISE

Après un `/clear`, ou en début de session sur un projet que tu ne connais pas. Tu reconstruis
le contexte utile en lisant dans cet ordre.

1. `CLAUDE.md` s'il existe, pour les règles du projet et les préférences durables.
2. `TODOS.md`, **le bloc « État à la reprise » d'abord**. C'est le point d'ancrage.
3. `CODEMAP.md`, pour localiser ce que tu vas toucher, et ses zones sensibles pour les pièges
   que tu ne veux pas re-découvrir à tes dépens.
4. `CHANGELOG.md`, **les 2 ou 3 dernières entrées seulement**, pas tout l'historique.
5. Les fiches `docs/` des seuls modules concernés par la tâche à venir, et l'ADR correspondant
   si tu t'apprêtes à revenir sur un choix déjà tranché.
6. `git log --oneline -10` et `git status -s`, pour vérifier que le dépôt correspond à ce que
   la doc raconte.

**Ne lis pas `archives/`** en reprise. C'est du faux par construction. On n'y va que sur demande
explicite d'archéologie.

Restitue ensuite en dix lignes maximum : où on en est, ce qui est en cours, la prochaine étape,
les pièges à connaître. Signale tout de suite les incohérences entre la doc et le dépôt. C'est
le symptôme d'une clôture bâclée, et ça se corrige avant de coder, pas après.

---

## Invariants, jamais négociables

- ❌ **Aucune suppression silencieuse.** Ce qui est obsolète part dans `archives/` avec sa raison.
- ❌ **Aucune affirmation connue-fausse laissée « pour plus tard »** dans les docs ou les piliers.
- ❌ **Aucune doc écrite depuis une supposition.** Tu vérifies l'état réel avant d'écrire.
- ❌ **Aucun `archives/` lu comme source de vérité.**
- ❌ **Aucun travail en cours sans tâche écrite** avant un `/clear`.
- ❌ **Aucun commit ou push non demandé.** Aucun secret dans un fichier tracké.
- ❌ **Aucune cérémonie disproportionnée**, mais le scan d'obsolescence se fait toujours.
- ❌ **Aucun texte qui sent le généré.** Voir le skill `style-redaction`.

---

## Références, à charger seulement au besoin

| Fichier | Quand le lire |
|---|---|
| skill `style-redaction` | **Avant toute rédaction.** Règle de style, tics à bannir, fautes volontaires |
| `references/CONVENTION.md` | Spécification des 3 piliers : structure, format, ce qui y va et ce qui n'y va pas, et où va le reste |
| `references/DOCS-SYSTEM.md` | Organisation de `docs/`, critère « mérite une fiche », en-têtes de statut, index, ADR |
| `references/ARCHIVAGE.md` | Arbre de décision archiver ou corriger ou supprimer, format d'en-tête, chemins, index |
| `references/PROFILS-PROJETS.md` | Adapter la convention au type de projet (app, lib, infra, data, contenu, monorepo) |
| `references/HANDOFF.md` | Test « prêt pour /clear » détaillé, anti-patterns de passation |
| `templates/` | Gabarits des piliers, des fiches `docs/`, des index, du bloc `CLAUDE.md` |
| `$SKILL/scripts/ctx-init.sh` | Scaffolder la convention, sans rien écraser |
| `$SKILL/scripts/ctx-audit.sh` | Rapport de dérive entre la doc et la réalité |
