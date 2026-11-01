# Git Flow

Deux branches permanentes :

| Branche | Rôle | Protection |
| --- | --- | --- |
| `main` | Versions stables | Maximale |
| `develop` | Intégration | Forte |
| `feature/*` | Nouvelles fonctionnalités | CI obligatoire avant intégration, force-push bloqué |
| `fix/*` | Corrections en développement | CI obligatoire avant intégration, force-push bloqué |
| `release/*` | Préparation d'une version | Suppression et force-push bloqués |
| `hotfix/*` | Correction urgente de production | Suppression et force-push bloqués |

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

## Rulesets

Les règles sont actives, sans acteur autorisé à les contourner.

`main` et `develop` :

- suppression interdite ;
- force-push interdit ;
- pull request obligatoire, sans approbation humaine tant qu'un seul mainteneur ne peut pas approuver sa propre PR ;
- checks `build`, `test`, `lint` et `security` obligatoires ;
- conversations de review résolues ;
- approbations périmées écartées.

`main` exige en plus que la branche soit à jour avec sa base.

`feature/*` et `fix/*` interdisent le force-push et laissent la suppression, pour que GitHub puisse effacer la branche après le merge.

`release/*` et `hotfix/*` interdisent le force-push et la suppression. Il faut synchroniser vers `develop` avant de supprimer la branche à la main. La suppression automatique échoue sur ces branches, et le merge vers `main` reste valable.

## Volontairement reporté

- Commits signés : à activer quand GPG ou SSH est en place pour la personne qui commite.
- Merge queue : inutile tant que l'intégration se fait par merge commit et qu'une seule personne intègre.
- Approbations obligatoires : 1 sur `develop` et 2 sur `main` dès qu'un second mainteneur existe. `CODEOWNERS` désigne déjà `@Rootingg`, sans review obligatoire.

## Version

Un tag annoté `v0.1.0` se pose sur le commit de `main` qui contient la release, après le merge de `release/*`. Le workflow Release ne fait que builder, tester et publier l'artefact.
