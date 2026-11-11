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

Pas encore. L'isolation se découpe, et `main` ne reçoit une release qu'une fois l'ensemble évalué.

- `feature/privilege-isolation` : `no_new_privs`, capacités vidées, refus du root, descripteurs hérités fermés.
- `feature/namespace-isolation` : espaces utilisateur, montage, PID et réseau. Présent sur cette branche. Le repli est `namespaces none` ou `namespaces partial` sur stderr.
- `feature/filesystem-isolation` : racine réduite à la copie de la cible. Présent sur cette branche. Le repli est `filesystem host`.
- `feature/seccomp-policy` : liste d'appels autorisés. Présent sur cette branche. Le repli est `seccomp none`. Un appel refusé meurt par `SIGSYS`.

`no_new_privs` seul n'est pas un bac à sable. Les sous-processus et les descripteurs se jugent avec les étapes suivantes. Une cible non fiable ne doit pas être lancée sur un runner GitHub.
