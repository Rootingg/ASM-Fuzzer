# Feuille de route

La v0.1.0 n'est pas encore taguée. `main` ne reçoit une version que par `release/*`, une fois les critères de la ligne atteints.

## v0.1.0 — Bootstrap stable

Rendre l'exécution mesurable et sûre avant d'élargir les mutations.

- Délai en temps réel, distinct du temps CPU.
- Écritures non bloquantes, sans zombie.
- Résultats séparés : `clean`, `crash`, `timeout`, `error`.
- Rejeu du fichier de crash sur la cible de démonstration.

## v0.2.0 — Moteur de mutation

Présent sur `develop`. Le tag attend une branche `release/*`.

- Bitflip, byteflip et arithmétique sont branchés dans la campagne.
- `--iterations` dépasse le voisinage des premiers bits.
- `--seed` rejoue une série xorshift64.
- `--no-stop-on-crash` conserve une entrée par signal.
- `--stop-on-crash` reste le défaut.

## v0.3.0 — Corpus

Présent sur `develop`. Le tag attend une branche `release/*`.

- Un répertoire passé à `--input` fournit plusieurs graines, dans l'ordre des noms.
- Chaque crash est réduit au plus court préfixe, puis à des octets retirés.
- `execs` et `rate` comptent les exécutions par seconde.

## v0.4.0 — Guidé par la couverture

Présent sur `develop`. Le tag attend une branche `release/*`.

- Les cibles instrumentées marquent des arêtes sur le descripteur 3.
- Une entrée qui ouvre une arête nouvelle est reprise comme base des mutations suivantes.
- `edges` compte les arêtes distinctes. Les cibles non instrumentées restent inchangées.

## v1.0.0 — Première version mature

Isolation par namespace ou conteneur, système de fichiers restreint, retrait des privilèges, éventuellement seccomp. Tests de régression, documentation utilisateur, benchmarks et releases reproductibles.

Les `RLIMIT_*` du bootstrap ne sont pas cette isolation. Une cible non fiable ne doit pas être lancée sur un runner GitHub.
