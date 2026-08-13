# cloture-session

Un plugin Claude Code qui rend le `/clear` gratuit. L'idée tient en une phrase : **si une
information ne vit que dans la conversation, elle n'existe pas.**

Il installe et maintient une convention de documentation dans ton projet, pour que le dépôt seul
suffise à reprendre le travail. Tu clears quand tu veux, la session suivante repart au bon endroit
sans que tu réexpliques quoi que ce soit.

Il marche sur n'importe quel type de projet. Application, librairie, infra, data, contenu,
monorepo, ou un projet sans une ligne de code.

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

Par cette voie les slash commands ne suivent pas, elles n'existent qu'en installation plugin. Les
trois modes restent accessibles en les demandant en français.

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

La clôture fait six choses dans l'ordre. Elle cadre le périmètre, audite l'état réel sans faire
confiance aux docs existantes, resynchronise les trois piliers, met à jour les fiches des modules
touchés, déplace vers `archives/` ce qui est devenu faux, et bloque tant que le test
« prêt pour /clear » ne passe pas.

Elle ne commite jamais sans qu'on le lui demande.

## Les scripts, utilisables seuls

```bash
CS=skills/cloture-session                # ou ~/.claude/skills/cloture-session
bash $CS/scripts/ctx-init.sh --dry-run   # voir ce qui serait créé
bash $CS/scripts/ctx-init.sh             # créer, sans jamais écraser un fichier existant
bash $CS/scripts/ctx-audit.sh            # rapport de dérive entre la doc et le dépôt
bash $CS/scripts/ctx-audit.sh --strict   # sortie non nulle s'il reste une alerte, pour la CI
```

L'audit fait dix contrôles : kit manquant, **niveaux imbriqués d'un monorepo**, dates qui traînent,
fiches périmées ou marquées obsolètes, fiches dont la portée a bougé, fiches absentes de l'index,
modules sans doc, liens relatifs morts, archives sans en-tête ou hors index, marqueurs laissés dans
le code, et une heuristique légère sur les secrets en clair.

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
