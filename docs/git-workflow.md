# Git Flow

Deux branches permanentes :

| Branche | Rôle | Protection |
| --- | --- | --- |
| `main` | Versions stables | Maximale |
| `develop` | Intégration | Forte |
| `feature/*` | Nouvelles fonctionnalités | CI obligatoire avant intégration, force-push bloqué |
| `fix/*` | Corrections en développement | CI obligatoire avant intégration, force-push bloqué |
| `release/*` | Préparation d'une version | Force-push bloqué, suppression autorisée après les merges |
| `hotfix/*` | Correction urgente de production | Force-push bloqué, suppression autorisée après les merges |

```text
feature/*  -->  PR  -->  develop
                           |
                           v
                      release/*
                           |
                           +--> PR --> main      (tag v0.1.0)
                           |
                           +--> PR --> develop   (synchronisation)
```

Les hotfixes partent de `main`, puis reviennent dans `main` et dans `develop`.

## Fusions

| Réglage | Valeur |
| --- | --- |
| Merge commits | Activé |
| Squash | Désactivé |
| Rebase | Désactivé |
| Suppression automatique de la branche source | Activée |
| Auto-merge | Activé |
| Branche par défaut | `develop` |

Le merge commit conserve la branche de fonctionnalité dans l'historique. L'historique linéaire est incompatible avec ce choix : il n'est pas exigé.

## Rulesets actifs

Ce qui suit est la configuration réellement appliquée par les rulesets GitHub du dépôt, pas seulement une convention. Un changement de document sans mise à jour du ruleset ne protège rien. On vérifie l'état dans Settings → Rules → Rulesets, ou avec l'API `GET /repos/Rootingg/ASM-Fuzzer/rulesets`.

Les quatre rulesets sont actifs et n'ont aucun acteur autorisé à les contourner.

`main` et `develop` :

- suppression interdite ;
- force-push interdit ;
- pull request obligatoire, sans approbation humaine tant qu'un seul mainteneur ne peut pas approuver sa propre PR ;
- checks `build`, `test`, `lint` et `security` obligatoires ;
- conversations de review résolues ;
- approbations périmées écartées ;
- seule la méthode merge est acceptée.

`main` exige en plus que la branche soit à jour avec sa base avant la fusion. `develop` ne l'exige pas.

`feature/*` et `fix/*` interdisent le force-push et laissent la suppression, pour que GitHub puisse effacer la branche après le merge.

`release/*` et `hotfix/*` interdisent le force-push et autorisent la suppression. L'ordre de travail est : merger vers `main`, synchroniser vers `develop`, puis supprimer la branche. Si la suppression automatique efface `release/*` dès le merge vers `main`, la synchronisation se fait par une PR de `main` vers `develop`. Il n'y a pas besoin de désactiver une règle pour effacer la branche.

## Volontairement reporté

- Commits signés : à activer quand GPG ou SSH est en place pour la personne qui commite.
- Merge queue : inutile tant que l'intégration se fait par merge commit et qu'une seule personne intègre.
- Approbations obligatoires : 1 sur `develop` et 2 sur `main` dès qu'un second mainteneur existe. `CODEOWNERS` désigne déjà `@Rootingg`, sans review obligatoire.

## Version

Un tag annoté `v0.1.0` se pose sur le commit de `main` qui contient la release, après le merge de `release/*`. Le workflow Release ne fait que builder, tester et publier l'artefact.
