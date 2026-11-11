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
- Un même identifiant de 16 bits compte pour une seule arête. La file de huit entrées garde la graine, retire une entrée déjà couverte, puis remplace le plus faible score de nouveauté.

## v1.0.0 — Première version mature

Le code de l'isolation et l'évaluation sont sur cette branche. `main` ne reçoit le tag `v1.0.0` que par une PR `release/*`, après intégration dans `develop`.

- `feature/privilege-isolation` : `no_new_privs`, capacités vidées, refus du root, descripteurs hérités fermés. Déjà sur `develop`.
- `feature/namespace-isolation` : espaces utilisateur, montage, PID et réseau. Le repli est `namespaces none` ou `namespaces partial`.
- `feature/filesystem-isolation` : racine réduite à la copie de la cible. Le repli est `filesystem host`.
- `feature/seccomp-policy` : liste d'appels autorisés. Le repli est `seccomp none`. Un appel refusé meurt par `SIGSYS`.
- Évaluation : `tests/integration/validate.sh`. Rejeu du crash, débit, arêtes contre une cible aveugle, absence de processus restant, durée et mémoire bornées. Passage local : 256 essais en 379 ms, 701 exec/s, 3 arêtes contre 0, pic 60 Kio, `namespaces full`, `filesystem hidden`, `seccomp on`.

Une cible non fiable ne doit pas être lancée sur un runner GitHub.
