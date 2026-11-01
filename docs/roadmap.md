# Feuille de route

La v0.1.0 n'est pas encore taguée. `main` ne reçoit une version que par `release/*`, une fois les critères de la ligne atteints.

## v0.1.0 — Bootstrap stable

Rendre l'exécution mesurable et sûre avant d'élargir les mutations.

- Délai en temps réel, distinct du temps CPU.
- Écritures non bloquantes, sans zombie.
- Résultats séparés : `clean`, `crash`, `timeout`, `error`.
- Rejeu du fichier de crash sur la cible de démonstration.

## v0.2.0 — Moteur de mutation

- Brancher bitflip, byteflip et l'arithmétique dans la campagne.
- Itérations au-delà du voisinage des 64 premiers bits.
- Graine pseudo-aléatoire reproductible avec `--seed`.
- Continuer après un crash, sauvegarder plusieurs entrées, dédupliquer par signal.
- `--stop-on-crash` reste disponible.

## v0.3.0 — Corpus

- Plusieurs graines.
- Minimiser les entrées qui fautent.
- Compter les exécutions par seconde.

## v0.4.0 — Guidé par la couverture

Instrumentation légère, ou un autre signal de couverture, pour favoriser les mutations qui ouvrent un chemin nouveau.

## v1.0.0 — Première version mature

Isolation par namespace ou conteneur, système de fichiers restreint, retrait des privilèges, éventuellement seccomp. Tests de régression, documentation utilisateur, benchmarks et releases reproductibles.

Les `RLIMIT_*` du bootstrap ne sont pas cette isolation. Une cible non fiable ne doit pas être lancée sur un runner GitHub.
