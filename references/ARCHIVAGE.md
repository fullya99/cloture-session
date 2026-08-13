# ARCHIVAGE : la règle qui garde la doc propre

> Une doc ne pourrit pas parce qu'on écrit trop peu. Elle pourrit parce qu'on laisse vivre le
> faux à côté du vrai. `archives/` existe pour qu'on puisse retirer sans hésiter. Le contenu
> obsolète est déplacé, jamais détruit, donc l'archiver ne coûte rien.

## Les deux invariants

**Aucune suppression silencieuse.** Ce qui a compté a le droit d'être retrouvé, avec la date et
la raison de sa mise à l'écart.

**`archives/` n'est jamais une source de vérité.** On ne le lit pas en reprise, on ne le cite pas
depuis une fiche vivante, on ne s'en sert pas pour répondre à une question sur l'état actuel.
Uniquement sur demande explicite d'archéologie.

Les deux règles se tiennent. C'est parce qu'on n'y lit jamais rien qu'on peut y jeter généreusement.

---

## Arbre de décision

À appliquer sur tout contenu suspect : fiche, procédure, script, plan, proposition, règle durable.

```
Le contenu est-il faux, périmé ou remplacé ?
├── NON → tu ne touches à rien.
└── OUI
    ├── Est-ce un FICHIER entier devenu inutile ou faux ?
    │   ├── OUI → ARCHIVER (git mv, en-tête, ligne d'index)
    │   └── NON → c'est une SECTION d'un fichier encore utile
    │             → CORRIGER SUR PLACE, noter au CHANGELOG.
    │               On n'archive pas un fichier vivant pour une section fausse.
    ├── Est-ce une RÈGLE DURABLE (entrée de CLAUDE.md) ?
    │   └── → SUPPRIMER. Pas d'archivage.
    │         Une règle fausse est pire qu'absente. Sa trace va au CHANGELOG si utile.
    ├── Est-ce un ADR supersédé ?
    │   └── → RESTE EN PLACE, statut « Superseded par ADR-00NN ».
    │         Seule exception à l'archivage, un ADR vaut par son historicité.
    ├── Est-ce une TÂCHE faite ou abandonnée (TODOS.md) ?
    │   └── → SUPPRIMER de TODOS. Le fait accompli vit au CHANGELOG.
    └── Est-ce une RÉFÉRENCE morte (lien, chemin, ressource supprimée) ?
        └── → CORRIGER si un remplaçant existe, sinon RETIRER en le disant.
```

Ce que tu ne fais jamais : laisser un `TODO: cette section est fausse` dans une doc vivante,
garder « au cas où », commenter au lieu de déplacer, supprimer un fichier documentaire sans trace.

---

## Où va le fichier archivé

```
archives/<AAAA-MM>/<chemin d'origine complet>
```

| Origine | Destination |
|---|---|
| `docs/modules/auth-legacy.md` | `archives/2026-08/docs/modules/auth-legacy.md` |
| `scripts/deploy-v1.sh` | `archives/2026-08/scripts/deploy-v1.sh` |
| `docs/ops/migration-mongo.md` | `archives/2026-08/docs/ops/migration-mongo.md` |

Pourquoi ce schéma. Le bucket daté évite les collisions quand un même chemin est archivé
plusieurs fois dans la vie du projet. Le chemin d'origine préservé rend la provenance lisible
sans avoir à ouvrir le fichier.

Utilise toujours `git mv`, pas un copier suivi d'un supprimer. L'historique du fichier reste suivi.

---

## En-tête d'archive, obligatoire

Inséré tout en haut du fichier déplacé, avant son titre.

```markdown
> ⚠️ **ARCHIVÉ le 2026-08-13**, document non maintenu, gardé pour l'historique.
> **Origine** : `docs/modules/auth-legacy.md`
> **Raison** : le flux de session par cookie a été remplacé par OAuth. La procédure décrite
> ne marche plus depuis la refonte du 2026-08-13.
> **Remplacé par** : `docs/modules/auth.md` (ou « aucun remplaçant, la brique n'existe plus »)
> **Ne pas utiliser comme source de vérité.**
```

Trois règles de forme.

Les chemins sont notés depuis la racine du dépôt, en `code`, jamais en lien relatif. Un fichier
déplacé casse tous ses liens relatifs, et un lien mort dans une archive, c'est un piège de plus.

La raison est explicite et vérifiable. « Obsolète » ne renseigne personne. « Remplacé par X suite
à la refonte du <date> » permet de décider si l'archive a encore un intérêt.

Si la fiche est archivée sans remplaçant, dis-le. C'est une information en soi.

---

## L'index `archives/README.md`

Sans index, `archives/` devient un débarras que personne ne fouille, et le contenu archivé est
perdu pour de bon. Autant l'avoir supprimé.

```markdown
| Archivé le | Origine | Emplacement | Raison | Remplacé par |
|---|---|---|---|---|
| 2026-08-13 | `docs/modules/auth-legacy.md` | `archives/2026-08/docs/modules/auth-legacy.md` | remplacé par OAuth | `docs/modules/auth.md` |
```

Plus récent en haut. Une ligne par élément, ajoutée dans le même mouvement que le déplacement.
Un fichier présent dans `archives/` mais absent de l'index est un défaut, `ctx-audit.sh` le signale.

---

## Ce qui n'a rien à faire dans `archives/`

`archives/` documente l'histoire de la connaissance du projet, pas ses déchets.

- ❌ du code mort, git le conserve déjà, tu le supprimes et c'est tout,
- ❌ des dépendances, builds, caches, exports volumineux, ce n'est pas de la doc,
- ❌ des secrets même expirés, ça se révoque, ça ne s'archive pas,
- ❌ des brouillons jamais publiés, ils n'ont jamais fait autorité, il n'y a rien à tracer,
- ❌ des règles durables devenues fausses, voir l'arbre de décision.

Règle simple : tu archives ce qui a été considéré comme vrai et ne l'est plus.

---

## Purge des archives

Les archives se relisent une fois par an environ, ou quand le répertoire devient volumineux.

Une archive dont plus rien ne dépend, et dont le sujet a totalement disparu, peut être supprimée
pour de bon. Git en garde l'histoire.

La ligne d'index correspondante reste, avec la mention `supprimé le AAAA-MM-JJ`. L'index est la
seule chose qui ne se purge jamais.

Aucune purge automatique. C'est une décision explicite, jamais un effet de bord d'une clôture.
