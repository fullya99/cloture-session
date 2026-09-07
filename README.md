# cloture-session

Un plugin Claude Code qui rend le `/clear` gratuit. L'idée tient en une phrase : **si une
information ne vit que dans la conversation, elle n'existe pas.**

Il installe et maintient une convention de documentation dans ton projet, pour que le dépôt seul
suffise à reprendre le travail. Tu clears quand tu veux, la session suivante repart au bon endroit
sans que tu réexpliques quoi que ce soit.

Il marche sur n'importe quel type de projet. Application, librairie, infra, data, contenu,
monorepo, ou un projet sans une ligne de code.

## Ce que fait la 4.0.0

Une doc vraie mais trop longue est une doc perdue. Sur un projet réel de 979 fichiers, après 83
clôtures en 17 jours, le bloc censé se lire en premier à la reprise faisait 2 579 lignes. Le
CHANGELOG faisait 8 283 lignes et 148 entrées. Rien dans la convention ne poussait à retirer,
tout poussait à ajouter.

La 4.0.0 pose le budget comme second invariant, au même rang que le vrai. Cinq réponses.

- **Un budget par surface**, mesuré par `ctx-audit.sh --budget`. Chaque fichier a une taille
  cible, un seuil d'alerte et un seuil de blocage. Une clôture n'est pas finie tant qu'un fichier
  dépasse son seuil de blocage.
- **Un bloc de reprise réécrit**, jamais édité, et borné à 40 lignes. Ce qui en sort a un
  propriétaire : un événement va au CHANGELOG, un piège dans une fiche, une tâche dans TODOS.
- **Un journal qui tourne.** `ctx-rotation.sh` déplace les entrées anciennes du CHANGELOG vers
  `archives/`, groupées par mois. Elles restent lisibles, elles ne coûtent plus rien à la reprise.
- **Des cartes de zone** sur les codebases moyennes et grosses. Un répertoire qui le mérite reçoit
  son propre `CODEMAP.md`, et au besoin un `CLAUDE.md` de zone que Claude Code charge tout seul
  quand on y travaille.
- **Un chemin vers les archives.** La convention ne lit jamais `archives/` en reprise, et
  `ctx-archeo.sh` est la façon d'y aller quand on cherche pourquoi une chose est faite comme ça.
  Il rend la provenance avant l'extrait, distingue une entrée froide d'un document faux, et borne
  sa sortie. Sans lui, l'interdiction de lire les archives reviendrait à perdre ce qu'on prétend
  garder.

| Surface | Cible |
|---|---|
| `CLAUDE.md` racine | 100 lignes |
| `CODEMAP.md` racine | 250 lignes |
| bloc « État à la reprise » | 40 lignes |
| `CHANGELOG.md` | 30 entrées |
| fiche `docs/` | 200 lignes |

## Installation

```
/plugin marketplace add fullya99/cloture-session
/plugin install cloture-session@cloture-session
```

Ou à la main, sans passer par le marketplace. On copie le dossier du skill, pas celui du dépôt :

```bash
mkdir -p ~/.claude/skills
cp -r skills/cloture-session ~/.claude/skills/
```

Sur Codex d'OpenAI, même dossier, autre chemin de scan :

```bash
cp -r skills/cloture-session .agents/skills/      # portée dépôt
cp -r skills/cloture-session ~/.agents/skills/    # portée utilisateur
```

Par ces deux voies les slash commands `/cloture`, `/reprise-session` et `/init-contexte` ne
suivent pas, elles n'existent qu'en installation plugin chez Claude Code. Le skill se déclenche
quand même sur une demande en français, dans les trois modes.

## Se greffer sur un projet existant

Sur un dépôt qui a déjà de la doc, poser des gabarits vides à côté créerait deux sources de
vérité dès le premier jour. `ctx-init.sh` détecte donc le terrain avant d'écrire, l'annonce dans
son rapport, et ne touche jamais un fichier existant.

| Ce que le projet a déjà | Ce que le skill en fait |
|---|---|
| Un `docs/`, `doc/` ou `documentation/` | Adopté, déclaré dans le bloc de convention |
| Un `adr/` déjà présent | Devient la destination des décisions |
| Un `AGENTS.md` sans `CLAUDE.md` | Devient le porteur des règles du projet |
| Une autre convention d'agent (`GEMINI.md`, `.cursorrules`, `memory-bank`...) | Signalée comme seconde source de vérité, à trancher |
| Un `MEMORY.md` d'une version antérieure de la convention | Son contenu est à répartir, l'audit rappelle où |

Si la structure existante ne suit pas celle de la convention (`modules/`, `features/`, `ops/`,
`decisions/`), les sous-répertoires ne sont pas recréés en dessous, la structure en place fait
foi.

Sur un gros projet déjà documenté, la greffe reste une clôture ordinaire : on pose le kit, on
mesure, on range.

## Claude web, et pourquoi c'est de peu d'intérêt ici

Le skill s'y installe, l'archive est sur la
[dernière release](https://github.com/fullya99/cloture-session/releases/latest). Réglages →
Capacités → Skills → Add Skill → Upload skill, avec **Code execution and file creation** activé.

Mais dis-le-toi franchement : ce skill sert à tenir la doc d'un dépôt à jour, et sur Claude web il
n'y a pas de dépôt. Pas de `git status`, pas tes fichiers, sauf ce que tu uploades. La convention se
chargera et Claude saura de quoi tu parles, les scripts n'auront rien à auditer. Utile comme
référence, pas comme outil.

Les slash commands ne suivent pas non plus, Claude Chat n'a pas de surface d'installation de plugin.

## Ce qu'il installe dans ton projet

Trois fichiers à la racine, plus `CLAUDE.md`. Chacun répond à une question, et à une seule.

| Fichier | Question |
|---|---|
| `CODEMAP.md` | Où ça se trouve, et qu'est-ce qui touche quoi ? |
| `TODOS.md` | Qu'est-ce que je fais maintenant ? |
| `CHANGELOG.md` | Qu'est-ce qui a changé, et comment revenir en arrière ? |
| `CLAUDE.md` | Qu'est-ce qui est vrai tout le temps ? |

Puis deux répertoires. `docs/` porte une fiche par module et par feature qui compte, et ne contient
que du vrai. `archives/` absorbe tout le reste, avec un en-tête qui dit la date, l'origine, la
raison et le remplaçant. Rien n'est supprimé en douce, et `archives/` n'est jamais relu comme source
de vérité.

C'est cette séparation qui empêche la doc de pourrir. Une doc dont on sait qu'elle est vraie se lit
en confiance après n'importe quel `/clear`.

## Les commandes

| Commande | Quand |
|---|---|
| `/init-contexte` | Une fois, pour installer la convention dans un projet |
| `/cloture` | En fin de session, avant un `/clear` |
| `/reprise-session` | Après un `/clear`, pour retrouver le fil en dix lignes |

Claude Code préfixe les commandes d'un plugin par son nom, donc ça s'écrit
`/cloture-session:cloture` si tu tapes le nom complet. La commande ne s'appelle pas comme le skill
exprès : une commande qui porte le nom d'un skill le masque, et le skill ne se déclenche plus tout
seul.

La clôture fait sept choses dans l'ordre. Elle cadre le périmètre et mesure le budget, audite
l'état réel sans faire confiance aux docs existantes, resynchronise les trois piliers, met à jour
les fiches des modules touchés, déplace vers `archives/` ce qui est devenu faux, tient le budget
de chaque fichier au-dessus de son seuil, et bloque tant que le test « prêt pour /clear » ne
passe pas.

Elle ne commite jamais sans qu'on le lui demande.

## Les scripts, utilisables seuls

```bash
CS=skills/cloture-session                    # ou ~/.claude/skills/cloture-session
bash $CS/scripts/ctx-init.sh --dry-run       # voir ce qui serait créé
bash $CS/scripts/ctx-init.sh                 # créer, sans jamais écraser un fichier existant
bash $CS/scripts/ctx-init.sh --zone src/api  # poser la carte d'une zone
bash $CS/scripts/ctx-audit.sh                # rapport de dérive entre la doc et le dépôt
bash $CS/scripts/ctx-audit.sh --budget       # mesurer le budget de chaque surface
bash $CS/scripts/ctx-audit.sh --strict       # sortie non nulle s'il reste une alerte, pour la CI
bash $CS/scripts/ctx-rotation.sh --dry-run   # voir ce que la rotation du CHANGELOG déplacerait
bash $CS/scripts/ctx-rotation.sh             # déplacer les entrées froides vers archives/
bash $CS/scripts/ctx-archive.sh --verifier <chemin>       # les liens vivants qui bloqueraient l'archivage
bash $CS/scripts/ctx-archive.sh <chemin> --raison "..."   # déplace, en-tête, index, vérifie
bash $CS/scripts/ctx-archeo.sh <motif>                    # cherche dans archives/, provenance avant extrait
bash $CS/scripts/ctx-archeo.sh --liste                    # inventaire de ce qui est archivé
bash $CS/scripts/ctx-archeo.sh --fichier <chemin>         # provenance d'une archive précise
```

L'audit fait dix contrôles : kit manquant, **niveaux imbriqués d'un monorepo**, dates qui traînent,
fiches périmées ou marquées obsolètes, fiches dont la portée a bougé, fiches absentes de l'index,
modules sans doc, liens relatifs morts, archives sans en-tête ou hors index, marqueurs laissés dans
le code, et une heuristique légère sur les secrets en clair. `--budget` ajoute la mesure des
seuils de taille.

**Plusieurs projets dans un dépôt.** Le script audite un niveau à la fois, `--root <chemin>` choisit
lequel. Sans lui la racine se déduit de git, donc lancé depuis un sous-projet il audite le dépôt
entier et il te le dit. Sa section « Niveaux imbriqués » liste les dossiers en dessous qui portent
leur propre kit, avec la commande pour chacun. Un sous-projet se clôture séparément, le parent pointe
vers lui et ne recopie pas sa doc.

Bash et git suffisent. Aucune dépendance à installer, aucun serveur MCP requis.

## Ce qu'il ne fait pas

Il ne résume pas ta session. Le but n'est pas de raconter ce qui s'est passé, c'est de rendre le
dépôt exact.

Il n'écrit pas ce que git enregistre déjà. Pas de recopie de l'historique, pas de description de la
structure du code que le code porte lui-même.

Il ne devine pas. Ce qu'il ne peut pas déduire du projet, il le demande, parce qu'une carte fausse
est pire que pas de carte.

Il ne commite pas, ne pousse pas, et ne touche pas à une branche sans qu'on le lui demande.

## Le plugin compagnon

`style-redaction` porte la règle d'écriture en français appliquée à tout ce qui sort d'ici. Il
s'installe séparément et n'est pas obligatoire, `cloture-session` applique une version minimale de
la règle s'il est absent.

```
/plugin marketplace add fullya99/style-redaction
/plugin install style-redaction@style-redaction
```
