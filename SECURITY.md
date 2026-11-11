# Sécurité

## Signaler une vulnérabilité du fuzzer

Une faille dans ASM-Fuzzer lui-même (exécution, chargement du corpus, écriture des crashs, workflows) se signale en privé :

https://github.com/Rootingg/ASM-Fuzzer/security/advisories/new

Ne publie pas de preuve de concept dans une issue, une pull request ou un commit public. Indique la version ou le commit, le scénario et l'impact. Une réponse est visée sous 7 jours.

Les alertes Dependabot, le secret scanning et le signalement privé sont activés quand le plan GitHub du dépôt le permet.

## Ce que ce canal ne couvre pas

Un crash trouvé dans un programme tiers appartient à l'éditeur de ce programme. Conserve l'entrée qui le provoque localement. Ne la commite pas si elle contient des données personnelles, des secrets, ou si l'exécutable n'a pas une provenance autorisée.

## Exécution

Le fuzzer lance la cible avec `execve`, sans passer par un shell. Avant cet appel, l'enfant refuse le root, pose `no_new_privs`, vide ses capacités, tente des namespaces utilisateur, montage, PID et réseau, réduit la racine à une copie de la cible, puis applique un filtre seccomp. Si le noyau refuse une de ces étapes, stderr le dit et la cible tourne quand même.

La CI n'exécute que des cibles assemblées depuis ce dépôt, avec un délai mural et des limites de CPU, de mémoire et de taille de fichier. Un runner hébergé par GitHub n'est pas l'endroit où lancer un binaire non fiable.

Le modèle de menace est décrit dans [docs/threat-model.md](docs/threat-model.md).
