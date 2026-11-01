# Contribuer

Le travail arrive sur `develop` par une pull request courte. `main` reste la ligne des versions stables.

## Branches

| Branche | Usage |
| --- | --- |
| `feature/*` | Nouvelle fonctionnalité, depuis `develop` |
| `fix/*` | Correction en cours de développement, depuis `develop` |
| `release/*` | Préparation d'une version, depuis `develop`, vers `main` puis retour vers `develop` |
| `hotfix/*` | Correction urgente, depuis `main`, vers `main` puis vers `develop` |

```bash
git switch develop
git pull
git switch -c feature/nom-court
```

Le détail des fusions et de la protection des branches est dans [docs/git-workflow.md](docs/git-workflow.md).

## Commits

[Conventional Commits](https://www.conventionalcommits.org/) :

| Type | Exemple |
| --- | --- |
| Feature | `feat(mutator): implement bitflip mutations` |
| Fix | `fix(executor): handle interrupted syscalls` |
| Test | `test(crash): verify SIGSEGV detection` |
| Refactor | `refactor(core): simplify buffer handling` |
| Documentation | `docs: document fuzzing architecture` |
| CI | `ci: add NASM build validation` |

## Avant la pull request

```bash
make test
make lint
make security
```

La PR vise `develop`, sauf pour une release ou un hotfix qui vise `main`. Un merge commit est le mode de fusion du dépôt : le squash et le rebase sont désactivés, parce qu'ils effacent l'historique des branches Git Flow.

Tant qu'il n'y a qu'un mainteneur, GitHub ne permet pas d'approuver sa propre PR. Les checks `build`, `test`, `lint` et `security` sont obligatoires. Une approbation humaine sera exigée quand un second mainteneur pourra reviewer.

## Cibles

Les tests n'exécutent que des cibles assemblées depuis `tests/targets/`. N'ajoute pas un binaire de provenance inconnue, ni dans le dépôt ni dans la CI.
