# PROFILS-PROJETS : adapter la convention à n'importe quel projet

> La convention est la même partout, c'est son remplissage qui change. Ce qui varie d'un projet
> à l'autre : ce qu'on appelle « module », ce qu'on appelle « feature » et ce qu'il faut
> vérifier pour savoir si la doc dit vrai. Le reste (3 piliers, `docs/`, `archives/`) ne bouge pas.

## Détecter le profil

Sans bloc `contexte:convention` dans `CODEMAP.md`, tu déduis depuis les fichiers présents.

| Indices | Profil |
|---|---|
| `package.json` avec `src/` et un framework web, `manage.py`, `main.go`, `Program.cs` | **app** |
| `pyproject.toml` sans point d'entrée, `lib/`, un `index.ts` exporté, `Cargo.toml` en lib | **lib** |
| `terraform/`, `ansible/`, `k8s/`, `docker-compose.yml`, scripts de provisioning | **infra** |
| `notebooks/`, `data/`, `models/`, `dvc.yaml`, `train.py` | **data** |
| `content/`, `posts/`, `_drafts/`, une majorité de `.md`, pas de build applicatif | **contenu** |
| `packages/`, `apps/`, `pnpm-workspace.yaml`, `turbo.json`, `go.work` | **monorepo** |
| `.claude/skills/`, `SKILL.md`, `commands/`, `plugin.json` | **outillage-agent** |
| Aucun code, juste des documents, des procédures, du suivi | **non-technique** |

Plusieurs profils peuvent cohabiter. Prends le dominant, note les autres dans le bloc
`contexte:convention`. En cas de doute, demande à l'utilisateur au lieu de deviner.

---

## app, application ou service

| | |
|---|---|
| **Module** | une couche ou un domaine : `auth`, `billing`, `api/orders`, `workers/mailer` |
| **Feature** | un parcours utilisateur de bout en bout : inscription, checkout, export |
| **CODEMAP insiste sur** | points d'entrée (routes, handlers, jobs), flux d'une requête, schéma de données, variables d'environnement requises |
| **À vérifier en clôture** | le service démarre, les tests passent, les migrations sont appliquées, les routes documentées existent encore, les variables d'env citées sont toujours lues par le code |
| **`docs/ops/`** | déploiement, rollback, migration, runbook d'incident |

## lib, bibliothèque, SDK, package

| | |
|---|---|
| **Module** | un sous-ensemble de l'API publique |
| **Feature** | un cas d'usage côté consommateur, du genre « utiliser le client en mode streaming » |
| **CODEMAP insiste sur** | la surface publique, ce qui est exporté, les limites de compatibilité, la matrice de versions supportées, les points d'extension |
| **À vérifier en clôture** | les exemples de la doc compilent et tournent encore, la version publiée correspond au CHANGELOG, aucune rupture non signalée |
| **Spécifique** | le CHANGELOG est un livrable public. Format Keep a Changelog plus SemVer, et les ruptures sont annoncées noir sur blanc |

## infra, infrastructure, ops, plateforme

| | |
|---|---|
| **Module** | un composant déployé : réseau, base, file, passerelle, CI |
| **Feature** | une capacité opérationnelle : sauvegarde, restauration, montée en charge, accès |
| **CODEMAP insiste sur** | l'inventaire des ressources réelles (nom, environnement, propriétaire), la topologie, les dépendances entre composants, l'emplacement des secrets et jamais leur valeur |
| **À vérifier en clôture** | que la ressource décrite existe vraiment. C'est le profil où la doc dérive le plus vite, parce que l'état vit en dehors du dépôt. Tu interroges la source d'autorité (état du provisioning, console, API), pas la doc |
| **`docs/ops/`** | le cœur du profil. Chaque procédure doit être rejouable à froid, avec ses prérequis et ses pièges |
| **Rollback** | non négociable dans chaque entrée de CHANGELOG |

## data, ML, analytics

| | |
|---|---|
| **Module** | une étape de pipeline : ingestion, nettoyage, features, entraînement, évaluation |
| **Feature** | une question métier à laquelle le pipeline répond, ou un modèle servi |
| **CODEMAP insiste sur** | le lignage (source, transformation, sortie), le schéma des jeux de données, l'emplacement des artefacts et des poids, le jeu de données de référence |
| **À vérifier en clôture** | le pipeline rejoue de bout en bout, les métriques citées correspondent au dernier run, la version de données ou de modèle référencée existe |
| **Savoirs durables typiques** | pourquoi cette métrique et pourquoi ces exclusions, en ADR. Biais connus des données et seuils choisis, dans la fiche `docs/` de l'étape concernée |
| **Spécifique** | date et versionne les résultats. Un chiffre sans date de run est un chiffre faux |

## contenu, éditorial, marketing, créatif

| | |
|---|---|
| **Module** | une rubrique, un format, un canal |
| **Feature** | une série, une campagne, un livrable récurrent |
| **CODEMAP insiste sur** | où vivent les sources, le pipeline de publication, les gabarits, les règles de ton et de nommage |
| **À vérifier en clôture** | ce qui est marqué publié l'est vraiment, les liens externes répondent, les gabarits cités existent |
| **Savoirs durables typiques** | positionnement et ton dans `CLAUDE.md`, ce qui a marché ou raté et pourquoi en ADR, contraintes de plateforme dans le CODEMAP |
| **Spécifique** | `archives/` sert beaucoup ici. Versions périmées d'un message, angles abandonnés. Ça garde une valeur de référence, mais ça ne doit plus circuler |

## monorepo, plusieurs unités autonomes

| | |
|---|---|
| **Structure** | chaque package ou app porte son propre kit, du genre `packages/api/CODEMAP.md` |
| **Racine** | un CODEMAP qui liste et pointe, jamais qui recopie. Un CHANGELOG des changements transverses. Un TODOS des sujets globaux |
| **Règle d'or** | n'absorbe jamais la doc d'un sous-projet dans la racine, elle divergera en quelques sessions |
| **À vérifier en clôture** | que tous les niveaux touchés sont mis à jour, pas seulement le cwd. Une session partie d'un package modifie très souvent la racine (config partagée, CI, dépendances) |
| **`docs/` partagé** | à la racine pour le transverse (architecture d'ensemble, ADR globaux), dans le package pour le local |

## outillage-agent, skills, plugins, commandes

| | |
|---|---|
| **Module** | un skill, une commande, un script |
| **Feature** | un flux de travail complet couvert par l'outil |
| **CODEMAP insiste sur** | quel fichier est chargé quand, les déclencheurs, la portée (user ou projet), les dépendances entre outils |
| **À vérifier en clôture** | le skill se déclenche bien sur les cas visés, les chemins relatifs cités depuis le skill résolvent, les scripts sont exécutables |
| **Spécifique** | c'est l'outil qui documente, il doit s'appliquer sa propre convention. Le dépôt du skill porte son propre kit |

## non-technique, projet sans code

| | |
|---|---|
| **Module** | un domaine ou un chantier |
| **Feature** | un livrable |
| **CODEMAP** | carte des documents, qui décide quoi, où vivent les sources de vérité externes |
| **À vérifier en clôture** | les documents cités existent et sont à jour, les échéances sont exactes, les décisions notées correspondent au dernier arbitrage |
| **Spécifique** | `docs/decisions/` porte l'essentiel du projet, chaque arbitrage et la position des parties prenantes valent un ADR. Le CHANGELOG remplace un compte-rendu de réunion |

---

## Adapter sans casser

Tu as trois libertés, à déclarer dans le bloc `contexte:convention`.

**Renommer.** Un projet peut appeler `documentation/` son `docs/`, ou `HISTORIQUE.md` son
CHANGELOG. Ce sont les rôles qui comptent, pas les noms.

**Fusionner.** Sur un très petit projet, TODOS peut vivre en section de CODEMAP, et les décisions
en une section plutôt qu'en ADR séparés. Dès qu'une section dépasse une page, tu la sors. La
fusion est une commodité de départ, pas une cible.

**Étendre.** Tu peux ajouter un pilier propre au domaine, un `INVENTAIRE.md` en infra, un
`CALENDRIER.md` en contenu. Un pilier ajouté doit répondre à une question qu'aucun autre ne
couvre, sinon c'est de la duplication.

Ce qu'on ne touche jamais, quel que soit le profil : le bloc « État à la reprise », l'obligation
d'archiver au lieu de supprimer, l'interdiction de lire `archives/` comme source de vérité, et
le fait qu'aucune affirmation connue-fausse ne survit à une clôture.

---

## Outillage

Le skill ne dépend d'aucun outil externe. Il marche avec `git`, un shell et des fichiers. Si des
outils supplémentaires sont branchés dans la session, ils accélèrent, ils ne conditionnent rien.

**Recherche web et documentation** (Hub MCP, `WebSearch`, `WebFetch`, Context7). Utile pour
vérifier qu'une procédure documentée correspond encore à la version courante d'un outil tiers,
ou pour dater une dépréciation avant d'archiver une fiche.

**Outils de projet** (gestionnaire de tâches, CI, cloud). Utiles en phase d'audit, pour confronter
la doc à l'état réel.

Aucune étape de la clôture ne doit échouer faute d'un de ces outils. S'ils ne sont pas là, tu
vérifies à la main et tu le notes.
