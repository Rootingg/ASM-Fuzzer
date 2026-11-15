# Release v1.0.0

Le tag `v1.0.0` est sur `main`, au merge de la pull request #18. Le workflow Release a publié l'artefact. `develop` contient ce merge.

Une release suivante suit le même ordre : branche `release/*` depuis `develop`, pull request vers `main`, tag annoté sur le commit de `main`, puis synchronisation vers `develop`. Les checks `build`, `test`, `lint` et `security` doivent être verts. Le squash et le rebase restent désactivés.

## Ordre suivi pour v1.0.0

Les pull requests se mergent par merge commit, dans cet ordre, chacune dans sa base :

1. https://github.com/Rootingg/ASM-Fuzzer/pull/13 vers `develop`
2. https://github.com/Rootingg/ASM-Fuzzer/pull/14
3. https://github.com/Rootingg/ASM-Fuzzer/pull/15
4. https://github.com/Rootingg/ASM-Fuzzer/pull/16
5. https://github.com/Rootingg/ASM-Fuzzer/pull/17

Ensuite, depuis `develop` à jour :

```bash
git switch develop
git pull
git switch -c release/v1.0.0
```

Sur cette branche, déplacer le contenu de `## [Unreleased]` vers `## [1.0.0] - 2026-11-11` dans `CHANGELOG.md`, ouvrir la PR vers `main`, et la merger quand les quatre checks sont verts. Le tag annoté se pose sur le commit de `main` :

```bash
git switch main
git pull
git tag -a v1.0.0 -m "ASM-Fuzzer 1.0.0"
git push origin v1.0.0
```

Puis synchroniser `main` vers `develop` par une pull request. Si GitHub supprime `release/v1.0.0` dès le merge vers `main`, cette synchronisation part de `main`.

Le workflow Release construit et publie l'artefact au push du tag. Il ne pose pas le tag lui-même.
