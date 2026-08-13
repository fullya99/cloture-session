# DOCS-SYSTEM : organisation de `docs/`

> `docs/` est la seule zone où la connaissance longue a le droit de vivre. Sa valeur tient à
> une propriété unique : **tout ce qui s'y trouve est vrai**. Dès qu'on tolère une fiche
> périmée, le lecteur doit tout revérifier, et la zone entière perd son intérêt.

## Arborescence

```
docs/
├── README.md              # index, la seule porte d'entrée
├── modules/               # comment marche une brique technique
│   └── <module>.md
├── features/              # comment marche une capacité vue de l'utilisateur
│   └── <feature>.md
├── ops/                   # procédures rejouables (setup, deploy, migration, incident)
│   └── <procedure>.md
└── decisions/             # ADR, pourquoi on a tranché comme ça
    └── ADR-0001-<slug>.md
```

Les quatre sous-répertoires ne sont pas décoratifs, ils correspondent à quatre questions
différentes. Une fiche qui hésite entre deux, c'est souvent deux fiches.

| Répertoire | Question | Se périme quand |
|---|---|---|
| `modules/` | Comment cette brique fonctionne-t-elle ? | le code change |
| `features/` | Que fait le produit, de bout en bout ? | le comportement change |
| `ops/` | Comment je refais cette opération ? | l'outillage ou l'infra change |
| `decisions/` | Pourquoi ce choix ? | jamais, on supersède au lieu de réécrire |

Sur un petit projet, `modules/` et `features/` peuvent rester à plat dans `docs/`. Tu crées la
structure quand le volume la justifie, tu ne l'anticipes pas.

---

## Qu'est-ce qui mérite une fiche

Documenter tout fait autant de dégâts que ne rien documenter. Le bruit rend le vrai illisible,
et une fiche qu'on ne maintient pas finit par mentir.

**Une fiche est justifiée si au moins un de ces cas est vrai :**

- plusieurs fichiers coopèrent pour rendre le service, et la logique n'est lisible dans aucun,
- une API ou un contrat est consommé ailleurs dans le projet,
- il existe un invariant non évident dans le code, du genre « l'ordre des appels compte » ou
  « ce cache doit être invalidé avant »,
- ça a été difficile à faire marcher, et ce qui a coûté du temps une fois en coûtera deux,
- une opération doit être rejouable par quelqu'un d'autre, ou par toi dans six mois,
- une décision structurante a été prise entre plusieurs options crédibles.

**Une fiche n'est pas justifiée** si le code est auto-explicatif, si le contenu paraphrase les
signatures, si la brique est triviale ou jetable, ou si l'information a déjà sa place dans un
pilier.

Le test qui tranche : retirer cette fiche coûterait-il du temps à quelqu'un ? Si non, elle n'a
pas à exister.

---

## En-tête de statut, obligatoire

Chaque fiche commence par ce bloc. C'est lui qui permet à un lecteur, humain ou agent, de savoir
en une ligne s'il peut faire confiance au contenu. Et c'est lui que `ctx-audit.sh` lit pour
détecter les fiches qui dérivent.

```markdown
> **Statut** : ✅ à jour, vérifié le 2026-08-13
> **Type** : module
> **Portée** : `src/auth/**`, `src/middleware/session.ts`
> **Voir aussi** : `docs/features/connexion.md`, `docs/decisions/ADR-0003-sessions.md`
```

| Statut | Sens | Suite |
|---|---|---|
| `✅ à jour` | vérifié contre le code à la date indiquée | rien à faire |
| `🟡 à vérifier` | le périmètre a bougé, la fiche n'a pas été relue | à traiter à la prochaine clôture |
| `🔴 obsolète` | contenu faux ou sujet disparu | direction `archives/`, à la clôture en cours |

Un `🔴` ne survit pas à une clôture. Un `🟡` qui traîne sur deux clôtures est soit vérifié soit
archivé, pas laissé en suspens.

Le champ `Portée` liste les chemins que la fiche décrit. C'est ce qui rend la maintenance
mécanique. Quand la session touche `src/auth/`, tu sais immédiatement quelles fiches relire.

---

## L'index `docs/README.md`

Une fiche non indexée est une fiche invisible. Personne ne la lira, donc personne ne la
corrigera. L'index se met à jour dans le même mouvement que la fiche.

```markdown
| Fiche | Type | Portée | Statut | Vérifié le |
|---|---|---|---|---|
| [auth](modules/auth.md) | module | `src/auth/**` | ✅ | 2026-08-13 |
| [connexion](features/connexion.md) | feature | parcours login | 🟡 | 2026-06-02 |
```

L'index porte aussi une section « Archivé récemment » qui pointe vers `archives/README.md`. Le
lecteur qui cherche une fiche disparue doit trouver où elle est partie sans avoir à fouiller.

---

## Écrire une fiche

Commence par la conclusion. Un lecteur qui s'arrête après trois lignes doit déjà avoir
l'essentiel.

Reste court. Un gros document n'est jamais mis à jour, donc il ment. Une fiche qui dépasse
200 lignes se scinde.

Ne paraphrase pas le code. Le code dit quoi, la fiche dit pourquoi, comment ça s'articule, et
ce qui casse si on y touche.

Cite des chemins réels et cliquables comme `src/auth/session.ts:42`, pas des descriptions vagues.

Mets les pièges avant les détails. La section « à savoir » fait gagner plus de temps que la
description exhaustive.

Aucun secret. Tu indiques où se trouve une clé, jamais sa valeur.

Les gabarits sont dans `templates/docs/` : `module.md`, `feature.md`, `procedure.md`, `ADR.md`.

---

## ADR, les décisions

Un ADR capture une décision structurante : contexte, options envisagées, choix retenu,
conséquences.

Numérotation monotone, jamais réutilisée, du genre `ADR-0007-choix-file-attente.md`.

Statuts possibles : `Proposé`, puis `Accepté`, puis `Superseded par ADR-00NN` ou `Déprécié`.

**Un ADR accepté ne se réécrit pas.** Si la décision change, tu écris un nouvel ADR qui supersède
l'ancien, et tu marques l'ancien. C'est ce qui permet de comprendre plus tard combien de temps
une décision a gouverné le projet.

Conséquence directe, **les ADR supersédés ne partent pas en `archives/`**. Ils restent en place,
marqués. Leur valeur vient justement d'avoir été vrais à une époque. C'est la seule exception à
la règle d'archivage.

Un ADR tient sur une page. Le matériel de support va ailleurs, en lien.

Ce qui mérite un ADR : ce qui est coûteux à inverser, ce qui a fait l'objet d'un vrai arbitrage,
ce qui surprendra un lecteur futur. Pas les choix évidents, pas ceux qu'on annule en dix minutes.

---

## Maintenance à la clôture

Pour chaque zone touchée par la session :

1. Liste les fiches dont la `Portée` recoupe les fichiers modifiés. `ctx-audit.sh` le fait pour toi.
2. Chaque fiche recoupée est **relue**, pas seulement redatée. Redater sans relire, c'est la
   façon la plus rapide de transformer `docs/` en piège.
3. Corrige, puis passe en `✅ à jour, vérifié le <aujourd'hui>`. Si le sujet a disparu, direction
   `archives/`.
4. Crée les fiches manquantes pour ce qui remplit un des critères plus haut.
5. Remets `docs/README.md` en cohérence.
