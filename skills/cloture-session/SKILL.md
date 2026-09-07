---
name: cloture-session
description: "Clôture de session avant un /clear, et maintenance de la documentation vivante d'un projet, quel que soit son type ou sa taille. Synchronise les 3 piliers CODEMAP.md, TODOS.md, CHANGELOG.md, met à jour les fiches docs/ des modules et features touchés, déplace vers archives/ tout ce qui est devenu faux, périmé ou remplacé, et tient chaque fichier dans son budget de contexte : bloc de reprise réécrit et borné, journal qui tourne, carte découpée par zone quand la codebase est grosse, CLAUDE.md sans état ni récit. Se déclenche sur : clôture ou fin de session, mise au propre, \"avant de clear\", \"range le projet\", \"documente ce qu'on a fait\", \"archive ce qui est obsolète\", \"la doc gonfle\", \"le CODEMAP déborde\", \"TODOS est trop long\", budget de contexte, scinder la doc par zone, faire tourner le changelog, doc vivante, CODEMAP, TODOS, CHANGELOG, /cloture. Couvre aussi l'installation de la convention dans un projet neuf (/init-contexte) et la reprise après un /clear (/reprise-session)."
version: 4.0.0
author: fullya99
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [documentation, session, housekeeping, changelog, codemap, context-budget]
---

# Gestion de contexte : clôture, reprise, convention, budget

> **Le contrat** : à tout instant, le dépôt seul doit suffire. Repartir sur un contexte neuf,
> `/clear` chez Claude Code, ne doit jamais coûter une information. Si une info ne vit que dans
> la conversation, elle n'existe pas. Et le dépôt doit rester lisible : une doc vraie mais trop
> longue pour être lue est une doc perdue.

Ce skill implémente une convention de documentation vivante avec archivage et budget, conçue pour
se greffer sur n'importe quel type de projet : code applicatif, librairie, infra, data, contenu,
monorepo, ou même un projet sans une ligne de code. De dix fichiers à plusieurs milliers.

**Avant d'écrire quoi que ce soit**, charge le skill **`style-redaction`**. Il porte la règle de
rédaction, et elle s'applique à tout ce que tu produis ici, sans exception. S'il n'est pas
installé, le minimum tient en une ligne : ton direct, aucun tiret cadratin, aucun point-virgule,
aucune tournure qui sent le texte généré, et la langue de la prose est celle du projet.

---

## Le socle en 30 secondes

Trois fichiers à la racine, plus `CLAUDE.md`. C'est le kit de démarrage à froid. Chacun répond
à une question, et à une seule, et chacun a une taille cible.

| Fichier | Question | Contenu | Se lit | Cible |
|---|---|---|---|---|
| **CODEMAP.md** | Où ça se trouve, et qu'est-ce qui touche quoi ? | Carte : arborescence commentée, modules, points d'entrée, flux, dépendances, commandes, zones sensibles, zones | En premier, par sections | 250 lignes |
| **TODOS.md** | Qu'est-ce que je fais maintenant ? | Bloc d'état de reprise en tête, travail en cours, prochaines étapes, dette, blocages | Le bloc d'abord, toujours | bloc 40 lignes, fichier 150 |
| **CHANGELOG.md** | Qu'est-ce qui a changé, et comment revenir en arrière ? | Entrées datées, plus récent en haut : quoi, pourquoi, rollback | 2 ou 3 entrées | 30 entrées, il tourne |
| **CLAUDE.md** | Qu'est-ce qui est vrai tout le temps ? | Règles du projet, préférences durables, contraintes d'accès. Chargé à chaque session, donc court, ni état ni récit | Automatiquement | 100 lignes |

Il n'y a pas de fichier de mémoire. Chaque type de savoir a un propriétaire unique, et c'est ce
qui empêche la duplication : les décisions vont dans `docs/decisions/`, les pièges d'un module
dans sa fiche `docs/` ou dans la carte de sa zone, les préférences durables dans `CLAUDE.md`, les
faits externes datés dans `docs/veille/` ou au CHANGELOG. Le détail est dans
`references/CONVENTION.md`.

Deux répertoires pour la profondeur.

| Répertoire | Rôle |
|---|---|
| **`docs/`** | Une fiche par module et par feature qui compte, plus les procédures et les décisions. Seule zone où la connaissance longue a le droit de vivre. Tout y est daté et statué. |
| **`archives/`** | Cimetière tracé. Ce qui est obsolète, faux ou remplacé y est déplacé, jamais supprimé en douce, avec un en-tête qui dit la date, l'origine, la raison, le remplaçant. Les entrées froides des journaux y tournent aussi. **Jamais lu comme source de vérité, jamais chargé en reprise.** Pour y aller quand on cherche pourquoi une chose est faite comme ça : `bash "$SKILL/scripts/ctx-archeo.sh" <motif>`. |

Et sur une codebase moyenne ou grosse, **des zones**. Une zone est un répertoire qui porte sa
propre carte, `<zone>/CODEMAP.md`, et au besoin ses propres règles, `<zone>/CLAUDE.md`, que Claude
Code charge tout seul quand un fichier de la zone est lu. L'état et le journal restent uniques à la
racine. Le CODEMAP racine liste les zones et pointe. Détail dans `references/ZONES.md`.

Deux règles font tenir l'ensemble. **`docs/` ne contient que du vrai, `archives/` absorbe tout le
reste.** Et **chaque surface tient dans son budget**, sinon ce qui déborde descend d'un étage :
d'un pilier vers une fiche ou une zone, d'un journal vers `archives/`. Les seuils sont dans
`references/BUDGET.md`, et `ctx-audit.sh` les mesure.

Le seuil est un détecteur, pas la règle. Le critère de découpe est sémantique, un fichier répond
à une question, c'est ce que disent Diátaxis et DITA qui ne fixent aucune longueur maximale : le
nombre dit d'aller regarder, ce qu'on trouve dit quel geste prendre.

---

## Router : quel mode ?

| Situation | Mode | Aller à |
|---|---|---|
| Fin de session, avant un `/clear`, mise au propre, `/cloture` | **CLÔTURE** | [Mode CLÔTURE](#mode-clôture) |
| La doc a gonflé, le contexte coûte cher, sans autre travail à documenter | **CLÔTURE**, phases 0, 1, 5 et 6 seulement | [Phase 5](#phase-5-tenir-le-budget) |
| Début de session, après un `/clear`, « où on en était », `/reprise-session` | **REPRISE** | [Mode REPRISE](#mode-reprise) |
| Le projet n'a pas le kit, ou pas en entier, `/init-contexte` | **INIT** | [Mode INIT](#mode-init) |

Si le projet n'a pas le kit et qu'on te demande une clôture, fais INIT puis CLÔTURE dans la
foulée, sans demander. La clôture a besoin du support pour écrire quelque part.

**Adaptation au projet** : avant tout mode, lis le bloc `<!-- contexte:convention -->` en tête
de `CODEMAP.md` s'il existe. Il déclare les chemins réels, le profil et la taille du projet. Sinon,
détecte le profil avec `references/PROFILS-PROJETS.md`, la taille se mesure en fichiers.

---

## Résoudre `$SKILL`, une fois par session

Les scripts vivent dans le skill, pas dans le projet. Tu travailles depuis le projet, donc
`scripts/ctx-audit.sh` tout court ne résout pas. Résous-le une fois, avant le premier appel :

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
[ -n "$SKILL" ] || echo "skill introuvable, fais les etapes a la main sans le script"
```

L'ordre est voulu, plugin puis portée projet puis portée utilisateur puis copies de plugin, et
chaque candidat a une raison d'être là. Le pourquoi est dans `references/RESOLUTION.md`, à lire
seulement si la boucle rend vide sur une machine où le skill est pourtant installé.

---

## Mode INIT

Installer la convention sans rien écraser. Le terrain n'est jamais le même projet nu deux fois,
le script le détecte et l'annonce avant d'écrire. Le premier geste dépend de ce qu'il trouve.

| Cas | Ce que tu trouves | Ce que ça veut dire | Le premier geste |
|---|---|---|---|
| Projet neuf | Rien, ou presque rien | Rien à greffer | Le kit se pose, tu remplis depuis le code réel |
| Doc rangée autrement | `doc/`, `documentation/`, `adr/` | Une doc existe, pas aux chemins attendus | Le script l'adopte et déclare les vrais chemins dans `contexte:convention`, il ne pose pas de gabarits vides à côté. Chaque document existant reçoit un propriétaire dans la convention, ce qui est faux part par `ctx-archive.sh` |
| Porteur des règles déjà là | `AGENTS.md` sans `CLAUDE.md` | `AGENTS.md` est déjà le porteur des règles | Le script y écrit. Si un `CLAUDE.md` naît ensuite, une ligne `@AGENTS.md` en tête le raccorde, sinon deux sources divergent en silence |
| Convention d'agent concurrente | `memory-bank/`, `.clinerules`, `.cursor/rules`, `GEMINI.md` | Deux sources de vérité | Une seule question, qui fait foi. Celle qui perd est archivée avec sa raison, jamais supprimée |
| Version antérieure de cette convention | `MEMORY.md` | Un seul fichier de mémoire, ancien format | Le contenu se répartit chez les propriétaires : décisions en ADR, pièges dans la fiche du module, préférences dans les règles, environnement dans le CODEMAP |
| Gros projet déjà documenté | Documentation abondante, déjà obèse | La greffe est une clôture, pas une installation | Pose le kit, mesure, va directement en [Phase 5](#phase-5-tenir-le-budget) |

```bash
bash "$SKILL/scripts/ctx-init.sh"            # crée ce qui manque, n'écrase jamais l'existant
bash "$SKILL/scripts/ctx-init.sh" --dry-run  # montre ce qui serait créé
```

Le script pose les gabarits, détecte le profil et mesure la taille du projet, sans jamais toucher
un fichier existant. Le vrai travail commence après, parce qu'un gabarit vide ne sert à personne.
Sur un gros projet déjà obèse, ce travail s'arrête au kit posé et à la mesure, va directement à la
phase 5 du mode CLÔTURE plutôt que de suivre la liste ci-dessous.

1. **Lis le projet avant d'écrire.** Arborescence, points d'entrée, `package.json` ou
   `pyproject.toml` ou `Makefile`, la CI, le README, les derniers commits. Ne remplis jamais
   le CODEMAP à partir d'une supposition.
2. **CODEMAP.md** : la carte réelle. Modules avec leur rôle en une ligne, points d'entrée, flux
   principal, dépendances externes, commandes qui marchent vraiment. Le bloc `contexte:convention`
   en tête est rempli par le script, vérifie-le.
3. **Si le projet est grand**, plus de 600 fichiers, le CODEMAP racine naît comme un index. Chaque
   répertoire de code qui compte reçoit sa carte dès maintenant, et ses pièges vont dedans :

   ```bash
   bash "$SKILL/scripts/ctx-audit.sh" --budget          # liste les zones candidates
   bash "$SKILL/scripts/ctx-init.sh" --zone src/<dir>   # pose la carte, --with-claude pour les règles
   ```

   Le critère de découpe est dans `references/ZONES.md`. Sur un projet moyen, tu crées une zone
   seulement là où le CODEMAP racine déborde. Sur un petit, aucune.
4. **TODOS.md** : l'état réel. Ce qui est en cours, ce qui est cassé, la dette visible.
5. **CHANGELOG.md** : une entrée d'amorçage. Tu ne réécris pas l'histoire passée du projet.
6. **`docs/`** : crée les fiches des modules qui **méritent** une fiche, et un ADR pour les
   décisions déjà prises et visibles quand elles engagent la suite. Le critère est dans
   `references/DOCS-SYSTEM.md`. Pas de fiche vide, pas de fiche pour tout. Ce que tu ne peux pas
   déduire, demande-le plutôt que de l'inventer.
7. Colle le bloc de `templates/CLAUDE-snippet.md` dans le `CLAUDE.md` du projet, crée-le s'il
   n'existe pas. C'est ce qui fait que les sessions suivantes respectent la convention sans
   qu'on ait à le redire à chaque fois.

Le détail de chaque fichier est dans `references/CONVENTION.md`.

---

## Mode CLÔTURE

Le but n'est pas de résumer la session. Le but est de rendre le dépôt complet, exact et lisible,
pour qu'une session neuve, sans cette conversation, reprenne au bon endroit sans payer un contexte
qu'elle n'utilisera pas.

Question à te reposer à chaque phase :

> Un lecteur à froid, avec seulement le bloc de reprise, le CODEMAP, CLAUDE.md et les fiches de sa
> zone, comprend-il l'état réel et sait-il quoi faire ensuite ? Et combien ça lui coûte à lire ?

### Phase 0. Cadrer et mesurer

```bash
git status -s && git diff --stat && git log --oneline -10
bash "$SKILL/scripts/ctx-audit.sh" --budget
```

1. **Périmètre.** Ce qui a changé, y compris hors git : fichiers non trackés, ressources
   externes créées (service, base, DNS, clé), effets de bord système.
2. **Niveaux.** Une session démarrée dans un sous-répertoire touche souvent au-dessus : racine
   du monorepo, config partagée, `~/.claude`. Et une session peut avoir traversé plusieurs projets
   sans rapport. Repère **tous** les niveaux qui ont leur propre kit, chacun devra être mis à jour.
   La section 1b de l'audit les liste, avec les zones.

   Un dossier qui porte les trois piliers est un niveau **autonome**. Il se clôture séparément, le
   parent pointe vers lui et ne l'absorbe pas. Un dossier qui ne porte qu'un `CODEMAP.md` est une
   **zone**, elle se met à jour dans cette clôture. Ne documente jamais que le cwd.
3. **Budget.** La section 10 de l'audit dit ce qui déborde. Note-le, la phase 5 le traite. Un
   blocage ne se reporte pas.
4. **Proportionnalité.** Calibre l'effort, mais ne saute rien.
   - Petite session (un ou deux fichiers, aucune structure touchée) : CHANGELOG en entrée
     courte, TODOS, **le scan d'obsolescence de la phase 4 et la mesure de la phase 5, toujours**.
   - Session conséquente (nouveau module, refactor, infra, dépendance) : toutes les phases.
5. Annonce le plan en une ligne, dis quels fichiers tu vas toucher, puis exécute sans redemander.

### Phase 1. Auditer le réel, sans faire confiance aux docs

```bash
bash "$SKILL/scripts/ctx-audit.sh"                      # le niveau courant
bash "$SKILL/scripts/ctx-audit.sh" --root packages/api  # un niveau imbriqué
```

**Une passe par niveau touché**, repéré en phase 0, pas une seule à la racine. Le script audite un
niveau à la fois. Sans `--root` il déduit la racine de git, donc lancé depuis un sous-projet il
audite le dépôt entier et pas le sous-projet. Il te le dit quand ça arrive.

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
| **CHANGELOG.md** | Ajoute en haut `## AAAA-MM-JJ, titre`. Trois choses : **quoi** (factuel), **pourquoi**, **rollback** (comment défaire). **25 lignes au plus.** Un gros lot reste court ici et pointe vers `docs/`. |
| **CODEMAP.md** | Reflète la nouvelle structure : module ajouté, supprimé ou renommé, point d'entrée déplacé, dépendance ajoutée, commande changée. **Retire ce qui n'existe plus.** Un piège va dans la carte de sa zone ou la fiche de son module, aux zones sensibles racine seulement s'il n'a ni l'un ni l'autre. Mets à jour la date, et la carte de chaque zone touchée. |
| **TODOS.md** | Coche le fait puis **supprime-le**, supprime l'obsolète, ajoute les tâches et dettes découvertes. Puis **réécris le bloc « État à la reprise » en tête**, depuis l'état courant, jamais en éditant le bloc précédent. |

**Le bloc de reprise tient en 40 lignes**, quatre champs. Ce que tu en retires n'est pas une
suppression silencieuse, à condition de classer avant de retirer : un événement est déjà au
CHANGELOG, un piège va dans la carte de sa zone ou la fiche de son module, une tâche dans la liste
avec son ancrage, une décision en ADR, une piste écartée et son pourquoi dans l'ADR ou la fiche. Le
récit, l'insistance et les majuscules ne se gardent pas. Une affirmation que tu n'as pas vérifiée
porte « à vérifier ». Rien de ce qui est dans TODOS ne raconte une session : pas de section « ce que
cette session a produit », c'est du CHANGELOG.

Les faits durables appris cette session ne vont pas dans un pilier, ils vont chez leur
propriétaire. Une décision et son pourquoi, un ADR dans `docs/decisions/`. Un piège de module,
sa fiche `docs/` ou la carte de sa zone. Une préférence exprimée par l'utilisateur, `CLAUDE.md`, et
seulement si elle est vraie à chaque instant. Une contrainte d'environnement, le CODEMAP. Le test
tient en une question, **qui est propriétaire de cette phrase ?**, et si tu ne sais pas répondre
c'est presque toujours qu'elle n'a pas à être écrite.

N'écris pas ce que le dépôt enregistre déjà, structure du code ou historique git. Le détail est
dans `references/CONVENTION.md`.

**Multi-niveaux** : applique ce tableau à chaque niveau touché repéré en phase 0. Un sous-projet
a sa propre doc vivante, le parent **pointe** vers elle, il ne l'absorbe pas.

### Phase 3. Documenter les modules et features dans `docs/`

Pour chaque module ou feature touché sérieusement cette session :

- la fiche existe, tu la **corriges** et tu repasses l'en-tête à `✅ à jour, vérifié le AAAA-MM-JJ`,
- elle n'existe pas et le sujet **mérite** une fiche, tu la crées depuis `templates/docs/`,
- elle existe mais le sujet a disparu, direction `archives/` en phase 4,
- elle dépasse 250 lignes, elle se scinde en deux sujets, ou son récit part en `archives/`.

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

- **Fichier obsolète** : le critère porte sur les références entrantes, pas sur une impression.
  Pour chaque référence, est-elle opérative, quelqu'un a besoin du document pour agir maintenant,
  ou est-ce du contexte historique. Un lien markdown vivant est opératif, il bloque.

  ```bash
  bash "$SKILL/scripts/ctx-archive.sh" --verifier <chemin>
  bash "$SKILL/scripts/ctx-archive.sh" <chemin> --raison "..." --remplace-par "..."
  ```
- **Section fausse dans un fichier encore utile** : tu **corriges sur place**, tu ne déplaces
  pas le fichier, et tu notes le correctif au CHANGELOG.
- **Règle durable devenue fausse** dans `CLAUDE.md` : suppression pure. Une règle erronée est
  pire qu'une règle absente, et `archives/` n'est pas une poubelle à erreurs ponctuelles. Si sa
  disparition compte, elle laisse une ligne au CHANGELOG.
- **Référence morte** (lien, chemin, ressource supprimée) : corrige ou retire.

Un pilier ne s'archive pas, le script le refuse. Une section fausse dans un pilier se corrige
sur place, comme n'importe quel autre fichier encore utile.

Règle d'or, à la fin de cette phase aucune affirmation connue-fausse ne subsiste dans les
piliers, dans `CLAUDE.md`, ni dans `docs/`. Et aucune suppression silencieuse.

### Phase 5. Tenir le budget

```bash
bash "$SKILL/scripts/ctx-audit.sh" --budget
```

Chaque ligne en `[!]` se traite maintenant, ou reçoit une tâche datée dans TODOS, une seule fois.
Une alerte qui revient à la clôture suivante est un blocage. Chaque ligne en `[!!]` se traite
maintenant, la clôture n'est pas finie avant. Les seuils et le pourquoi sont dans
`references/BUDGET.md`, les gestes tiennent dans ce tableau.

| Ce qui déborde | Le geste |
|---|---|
| bloc de reprise | réécrire depuis l'état courant, classer ce qui sort (phase 2) |
| TODOS.md | supprimer les cases cochées, déplacer les sections de session au CHANGELOG, dégraisser les tâches sans ancrage |
| CHANGELOG.md, ou tout journal à entrées datées | `bash "$SKILL/scripts/ctx-rotation.sh" --fichier <journal>`, puis raccourcir les entrées de plus de 25 lignes en sortant le détail vers une fiche |
| CODEMAP.md racine | créer les zones candidates avec `ctx-init.sh --zone`, y descendre leurs zones sensibles et leurs commandes, laisser un pointeur dans la table « Zones » |
| CLAUDE.md | lancer le skill `clawd-audit-md` s'il est installé. Sinon la procédure courte de `references/BUDGET.md` : l'état va dans TODOS, le récit dans la fiche, la règle de zone dans `<zone>/CLAUDE.md` ou `.claude/rules/<zone>.md`, et chaque ligne restante passe le test « la retirer ferait-il faire une erreur ? » |
| une fiche `docs/` | scinder en deux sujets, ou sortir vers `archives/` le récit qui ne sert plus à décider |
| une carte de zone | scinder la zone en deux |

La rotation se lance en `--dry-run` d'abord, tu lis ce qu'elle annonce, puis pour de vrai. Elle
n'archive pas du faux, elle range du froid : les entrées gardent leur valeur, elles ne coûtent
plus rien à la reprise.

Sur une grande codebase, ce travail se découpe par zone entre sous-agents, un par zone, avec le
chemin exact et le critère de fin. Le principal garde la réécriture du bloc de reprise et toute
décision d'archivage. Ce qui est vrai partout reste à la racine, jamais seulement dans une zone.

### Phase 6. Test « prêt pour un contexte neuf »

Checklist bloquante, version détaillée dans `references/HANDOFF.md`.

- [ ] **Chaque niveau touché** a eu sa passe complète, et chaque zone touchée sa carte à jour.
- [ ] Les 3 piliers reflètent l'état réel vérifié en phase 1, sans se contredire entre eux.
- [ ] Le bloc « État à la reprise » de TODOS.md permet de reprendre sans cette conversation, et
      il tient en 40 lignes.
- [ ] Tout travail en cours non terminé a une tâche explicite, sinon il est perdu au redémarrage.
- [ ] Chaque module ou feature touché a une fiche `docs/` à jour et indexée.
- [ ] Ce qui est obsolète est dans `archives/`, avec en-tête et ligne d'index.
- [ ] `ctx-audit.sh --budget` ne rend aucun `[!!]`, et chaque `[!]` a son geste ou sa tâche.
- [ ] Chaque zone est citée dans le CODEMAP racine, et `CLAUDE.md` ne porte ni état ni récit.
- [ ] Aucun secret dans un fichier tracké. `git status` conforme à l'intention.
- [ ] Relecture croisée : ouvre TODOS et CODEMAP, vérifie qu'ils racontent la même histoire.

### Phase 7. Compte-rendu, puis commit si on te le demande

Sortie en texte simple, jamais d'artifact.

```
**Clôture de session, AAAA-MM-JJ**

Fait cette session : [1 à 3 lignes factuelles]

Piliers : CHANGELOG ✓ · CODEMAP ✓ · TODOS ✓
docs/ : +[N] fiche(s), ~[N] mise(s) à jour, +[N] ADR
archives/ : [N] élément(s), [liste courte avec la raison] ou « rien à archiver »
Budget : [ce qui a été réduit, tourné ou découpé, avec les tailles avant et après] ou « tout tient »
CLAUDE.md : [ce qui a bougé, ou « inchangé »]
Niveaux mis à jour : [cwd] · [zones touchées] · [parent si touché]
Reste à faire : [2 ou 3 items clés, pointeur vers TODOS.md]

Prêt pour un contexte neuf ✅
```

**Commit** : jamais sans demande explicite. Tu proposes, tu attends. Si on te le demande,
seulement les fichiers trackés, message clair sur le quoi et le pourquoi, branche de travail
désignée.

---

## Mode REPRISE

Après un redémarrage à froid, `/clear` chez Claude Code, ou en début de session sur un projet
que tu ne connais pas. Tu reconstruis le contexte utile en lisant dans cet ordre, et tu ne lis
jamais un pilier en entier : la reprise doit coûter peu, sinon elle annule le bénéfice du
redémarrage.

1. `CLAUDE.md` s'il existe, il est déjà chargé chez Claude Code.
2. Le bloc « État à la reprise », et rien d'autre de `TODOS.md` :

   ```bash
   awk '/^## /{n++} n<=1' TODOS.md
   ```
3. Le plan de `CODEMAP.md`, puis la seule section utile, puis la carte de la zone concernée :

   ```bash
   grep -n '^## ' CODEMAP.md
   ```
4. Les 2 ou 3 dernières entrées de `CHANGELOG.md`, pas tout l'historique :

   ```bash
   awk '/^## /{n++} n<=3' CHANGELOG.md
   ```
5. Les fiches `docs/` des seuls modules concernés par la tâche à venir, et l'ADR correspondant
   si tu t'apprêtes à revenir sur un choix déjà tranché.
6. `git log --oneline -10` et `git status -s`, pour vérifier que le dépôt correspond à ce que
   la doc raconte.

**Ne lis pas `archives/`** en reprise. C'est du faux ou du froid par construction. On n'y va que
sur demande explicite d'archéologie. Dans ce cas, `bash "$SKILL/scripts/ctx-archeo.sh" <motif>`,
jamais un `grep` nu : le grep rend une ligne sans son en-tête, et tu prends alors du froid pour
du courant.

Restitue ensuite en dix lignes maximum : où on en est, ce qui est en cours, la prochaine étape,
les pièges à connaître. Signale tout de suite les incohérences entre la doc et le dépôt, et un
pilier qui déborde. C'est le symptôme d'une clôture bâclée, et ça se corrige avant de coder, pas
après.

---

## Invariants, jamais négociables

- ❌ **Aucune suppression silencieuse.** Ce qui est obsolète part dans `archives/` avec sa raison.
- ❌ **Aucune affirmation connue-fausse laissée « pour plus tard »** dans les docs ou les piliers.
- ❌ **Aucune doc écrite depuis une supposition.** Tu vérifies l'état réel avant d'écrire.
- ❌ **Aucun `archives/` lu en reprise.** Toute fouille passe par `ctx-archeo.sh`, qui rend la
  provenance avec l'extrait.
- ❌ **Aucun travail en cours sans tâche écrite** avant un redémarrage à froid.
- ❌ **Aucun fichier au-dessus de son seuil de blocage** à la fin d'une clôture. Ce qui déborde
  descend d'un étage, il ne s'efface pas.
- ❌ **Aucun journal de session dans TODOS, aucun état ni récit dans `CLAUDE.md`.**
- ❌ **Aucun commit ou push non demandé.** Aucun secret dans un fichier tracké.
- ❌ **Aucune cérémonie disproportionnée**, mais le scan d'obsolescence et la mesure se font toujours.
- ❌ **Aucun texte qui sent le généré.** Voir le skill `style-redaction`.

---

## Références, à charger seulement au besoin

| Fichier | Quand le lire |
|---|---|
| skill `style-redaction` | **Avant toute rédaction.** Règle de style, tics à bannir, fautes volontaires |
| `references/CONVENTION.md` | Spécification des 3 piliers : structure, format, ce qui y va et ce qui n'y va pas, et où va le reste |
| `references/BUDGET.md` | Les seuils, leur pourquoi, le geste par fichier qui déborde, la procédure `CLAUDE.md` sans `clawd-audit-md`, le découpage entre sous-agents |
| `references/ZONES.md` | Quand un répertoire mérite sa carte, ce qu'elle porte, ce qui reste à la racine, ce que chaque lecteur charge |
| `references/DOCS-SYSTEM.md` | Organisation de `docs/`, critère « mérite une fiche », en-têtes de statut, index, ADR |
| `references/ARCHIVAGE.md` | Arbre de décision archiver ou corriger ou supprimer, en-tête, chemins, index, rotation des journaux |
| `references/PROFILS-PROJETS.md` | Adapter la convention au type de projet (app, lib, infra, data, contenu, monorepo) |
| `references/HANDOFF.md` | Test « prêt pour un contexte neuf » détaillé, anti-patterns de passation |
| `references/RESOLUTION.md` | Pourquoi la boucle `$SKILL` cherche là où elle cherche, et dans cet ordre |
| `templates/` | Gabarits des piliers, des cartes et règles de zone, des fiches `docs/`, des index, du bloc `CLAUDE.md` |
| `$SKILL/scripts/ctx-init.sh` | Scaffolder la convention ou une zone, sans rien écraser |
| `$SKILL/scripts/ctx-audit.sh` | Rapport de dérive entre la doc et la réalité, et mesure du budget avec `--budget` |
| `$SKILL/scripts/ctx-rotation.sh` | Faire tourner un journal vers `archives/`, `--dry-run` d'abord |
| `$SKILL/scripts/ctx-archive.sh` | Archiver un document en une passe : références entrantes, déplacement, en-tête, liens, index, vérification |
| `$SKILL/scripts/ctx-archeo.sh` | Le seul chemin sanctionné pour fouiller `archives/`, provenance avant extrait, sortie bornée |
