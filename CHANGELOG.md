# Changelog

Le format est inspiré de Keep a Changelog. Les versions suivent Semantic Versioning et sont posées par des tags `v0.1.0`, `v0.2.0`, `v1.0.0`.

## [Unreleased]

### Added

- Évaluation de bout en bout : rejeu du crash, débit, couverture contre une cible aveugle, et absence de processus laissé derrière.
- Filtre seccomp sur la cible : les appels hors liste meurent par `SIGSYS`, avec un repli explicite si le noyau refuse le filtre.
- Racine réduite à la copie de la cible quand le namespace de montage est disponible, avec un repli explicite.
- Namespaces utilisateur, montage, PID et réseau pour la cible, avec un repli explicite s'ils sont refusés.
- Les identifiants d'arêtes identiques se confondent, le tube de couverture est borné, et la file remplace l'entrée la moins nouvelle.
- Refus d'une exécution root, `no_new_privs`, capacités vidées, et fermeture des descripteurs hérités par la cible.
- Couverture par arêtes : les entrées qui ouvrent un chemin nouveau alimentent les mutations suivantes.
- Corpus en répertoire, minimisation des crashs, et débit `execs` / `rate`.
- Campagne à trois mutateurs, graine `--seed` reproductible, et un fichier de crash par signal.
- Délai mural configurable, écriture non bloquante vers la cible, et résultats `clean`, `crash`, `timeout`, `error`.
- Structure Git Flow et workflows CI : build, test, lint, security.
- Squelette NASM : campagne bitflip, exécution sans shell, écriture d'un crash reproductible.
- Cible de démonstration contrôlée et tests d'oracle.
