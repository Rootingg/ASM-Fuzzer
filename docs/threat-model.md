# Modèle de menace

## Actifs

- Le code du fuzzer et les workflows qui le construisent.
- Les entrées de corpus et les fichiers de crash, qui peuvent contenir des données copiées depuis une cible.
- Les secrets du dépôt GitHub.

## Périmètre

Le fuzzer est un outil local. Il exécute une cible choisie par l'opérateur. Cette cible est hostile par définition : elle peut boucler, écrire sur le disque ou lire l'entrée standard. Les limites posées dans l'enfant réduisent l'impact, elles ne remplacent pas un bac à sable.

## Hypothèses

- L'opérateur a le droit de lancer la cible sur la machine où tourne le fuzzer.
- La CI n'exécute que des cibles compilées depuis les sources du dépôt : `demo-target`, `spin-target`, `stall-target` et `block-read-target`.
- Les runners GitHub hébergés ne reçoivent pas de binaire tiers.
- Un crash d'une cible tierce n'est pas une vulnérabilité d'ASM-Fuzzer.

## Ce que le bootstrap traite

| Menace | Mesure |
| --- | --- |
| Cible qui consomme le CPU ou la mémoire | `RLIMIT_CPU`, `RLIMIT_AS`, `RLIMIT_FSIZE` |
| Élévation via un binaire setuid | `no_new_privs`, capacités vidées, refus si uid ou gid root |
| Descripteur hérité par la cible | fermeture de tout descripteur supérieur au canal de couverture |
| Cible bloquée sans consommer de CPU | Délai mural, `SIGKILL` du groupe, résultat `timeout` |
| Parent bloqué sur un tube plein | Écriture non bloquante et `poll` |
| Injection de shell via le chemin ou l'entrée | `execve` direct, arguments séparés |
| Faux crash sur un timeout | `SIGKILL` et `SIGXCPU` sont des timeouts, pas des crashs |
| Lecture du disque de l'hôte | racine réduite à la copie de la cible, sinon repli explicite |
| Appel système hors liste | filtre seccomp, mort par `SIGSYS` comptée comme un crash |
| Secret commité ou action non épinglée | Job `security` |
| Fuite d'un crash sensible | `crashes/` est ignoré par Git |

## Hors périmètre actuel

Les namespaces sont tentés avant `execve`, puis le filtre seccomp. Quand le noyau refuse l'un des deux, la cible tourne quand même et stderr le dit. `tests/integration/validate.sh` rejoue un crash, compare les arêtes, et vérifie qu'aucun processus cible ne reste. L'exécution d'un corpus non maîtrisé reste hors CI.
