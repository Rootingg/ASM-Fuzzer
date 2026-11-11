# Release v1.0.0

Le code et l'évaluation locale sont prêts. Le tag attend que GitHub Actions accepte de démarrer.

## Ce qui bloque

Les rulesets exigent `build`, `test`, `lint` et `security` avant un merge vers `develop` ou `main`. Tant que le compte affiche « locked due to a billing issue », ces jobs ne démarrent pas. Rien ne se merge, et `v1.0.0` ne se pose pas. La page à regarder est https://github.com/settings/billing.

## Ordre, une fois les jobs verts

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
