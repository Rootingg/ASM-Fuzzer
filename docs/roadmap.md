# Feuille de route

`v1.0.0` est le premier tag, posé sur `main`. Les lignes v0.1 à v0.4 n'ont pas de tag séparé : elles sont dans cette version. L'ordre suivi est dans [release.md](release.md).

## v0.1.0 — Bootstrap stable

Rendre l'exécution mesurable et sûre avant d'élargir les mutations.

- Délai en temps réel, distinct du temps CPU.
- Écritures non bloquantes, sans zombie.
- Résultats séparés : `clean`, `crash`, `timeout`, `error`.
- Rejeu du fichier de crash sur la cible de démonstration.

## v0.2.0 — Moteur de mutation

Livré dans `v1.0.0`.

- Bitflip, byteflip et arithmétique sont branchés dans la campagne.
- `--iterations` dépasse le voisinage des premiers bits.
- `--seed` rejoue une série xorshift64.
- `--no-stop-on-crash` conserve une entrée par signal.
- `--stop-on-crash` reste le défaut.

## v0.3.0 — Corpus

Livré dans `v1.0.0`.

- Un répertoire passé à `--input` fournit plusieurs graines, dans l'ordre des noms.
- Chaque crash est réduit au plus court préfixe, puis à des octets retirés.
- `execs` et `rate` comptent les exécutions par seconde.

## v0.4.0 — Guidé par la couverture

Livré dans `v1.0.0`.

- Les cibles instrumentées marquent des arêtes sur le descripteur 3.
- Une entrée qui ouvre une arête nouvelle est reprise comme base des mutations suivantes.
- `edges` compte les arêtes distinctes. Les cibles non instrumentées restent inchangées.
- Un même identifiant de 16 bits compte pour une seule arête. La file de huit entrées garde la graine, retire une entrée déjà couverte, puis remplace le plus faible score de nouveauté.

## v1.0.0 — Première version mature

Taguée sur `main`.

- Privilèges : `no_new_privs`, capacités vidées, refus du root, descripteurs hérités fermés.
- Namespaces utilisateur, montage, PID et réseau, avec repli `namespaces none` ou `namespaces partial`.
- Racine réduite à la copie de la cible, avec repli `filesystem host`.
- Filtre seccomp, avec repli `seccomp none`. Un appel refusé meurt par `SIGSYS`.
- Évaluation : `tests/integration/validate.sh`.

Les limites de cette version sont dans [threat-model.md](threat-model.md). Une cible non fiable ne doit pas être lancée sur un runner GitHub.
