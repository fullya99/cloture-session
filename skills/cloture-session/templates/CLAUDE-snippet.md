<!--
Bloc à coller dans le CLAUDE.md (ou AGENTS.md) du projet, à la fin.
Crée le fichier s'il n'existe pas. Adapte les chemins si le projet en utilise d'autres.
Garde-le court : CLAUDE.md est chargé à chaque session, c'est la surface la plus coûteuse.
-->

## Convention de contexte

Ce projet est documenté pour qu'un `/clear` ne coûte jamais d'information. Le dépôt est la
source de vérité, pas la conversation.

**À lire en début de session, dans cet ordre**

1. `TODOS.md`, le bloc « État à la reprise » d'abord. C'est le point d'ancrage.
2. `CODEMAP.md`, pour localiser ce qu'on va toucher, et ses zones sensibles pour les pièges.
3. `CHANGELOG.md`, les 2 ou 3 dernières entrées seulement.
4. Les fiches `docs/` des seuls modules concernés par la tâche. `docs/README.md` est l'index.
   `docs/decisions/` porte les choix déjà tranchés et leur pourquoi.

**Ne jamais lire `archives/`.** C'est du contenu périmé par construction, gardé pour
l'historique. On n'y va que sur demande explicite.

**En fin de session, avant tout `/clear`** : lancer `/cloture-session`. Ça resynchronise les
3 piliers, met à jour les fiches `docs/` des modules touchés et déplace vers `archives/` tout
ce qui est devenu faux ou obsolète.

**Les règles qui tiennent l'ensemble**

- Aucune suppression silencieuse. Ce qui est obsolète va dans `archives/`, avec sa raison.
- Aucune affirmation connue-fausse laissée dans les docs ou dans les piliers.
- Une règle durable devenue fausse est supprimée tout de suite, elle n'est pas archivée.
- Un savoir a un propriétaire et un seul : décision en ADR, piège dans la fiche du module,
  préférence durable ici, contrainte d'environnement dans le CODEMAP.
- Aucun travail en cours sans une tâche écrite dans `TODOS.md`.
- Jamais de secret dans un fichier tracké. On dit où est la clé, pas ce qu'elle vaut.

**Style de rédaction** : français, ton direct. Pas de tiret cadratin, pas de point-virgule, pas
de tournure qui sent le texte généré. La règle complète est dans le skill `style-redaction`, à
charger avant d'écrire un document.
