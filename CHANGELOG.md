# Changelog

Le format est inspiré de Keep a Changelog. Les versions suivent Semantic Versioning et sont posées par des tags `v0.1.0`, `v0.2.0`, `v1.0.0`.

## [Unreleased]

### Added

- Couverture par arêtes : les entrées qui ouvrent un chemin nouveau alimentent les mutations suivantes.
- Corpus en répertoire, minimisation des crashs, et débit `execs` / `rate`.
- Campagne à trois mutateurs, graine `--seed` reproductible, et un fichier de crash par signal.
- Délai mural configurable, écriture non bloquante vers la cible, et résultats `clean`, `crash`, `timeout`, `error`.
- Structure Git Flow et workflows CI : build, test, lint, security.
- Squelette NASM : campagne bitflip, exécution sans shell, écriture d'un crash reproductible.
- Cible de démonstration contrôlée et tests d'oracle.
