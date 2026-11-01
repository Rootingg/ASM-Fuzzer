# Sécurité

## Signaler une vulnérabilité du fuzzer

Une faille dans ASM-Fuzzer lui-même (exécution, chargement du corpus, écriture des crashs, workflows) se signale en privé :

https://github.com/Rootingg/ASM-Fuzzer/security/advisories/new

Ne publie pas de preuve de concept dans une issue, une pull request ou un commit public. Indique la version ou le commit, le scénario et l'impact. Une réponse est visée sous 7 jours.

Les alertes Dependabot, le secret scanning et le signalement privé sont activés quand le plan GitHub du dépôt le permet.

## Ce que ce canal ne couvre pas

Un crash trouvé dans un programme tiers appartient à l'éditeur de ce programme. Conserve l'entrée qui le provoque localement. Ne la commite pas si elle contient des données personnelles, des secrets, ou si l'exécutable n'a pas une provenance autorisée.

## Exécution

Le fuzzer lance la cible avec `execve`, sans passer par un shell. La CI n'a le droit de lancer que la cible de démonstration du dépôt, avec des limites de temps et de ressources. Un runner hébergé par GitHub n'est pas un bac à sable pour un binaire non fiable.

Le modèle de menace est décrit dans [docs/threat-model.md](docs/threat-model.md).
