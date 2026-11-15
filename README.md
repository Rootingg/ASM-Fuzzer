# ASM-Fuzzer

Fuzzer black-box x86-64 pour Linux, écrit en NASM, sans libc. Il lance la cible avec `execve`, sans shell. Les mutations sont bitflip, byteflip et arithmétique. Un corpus peut être un fichier ou un répertoire. Les crashs sont minimisés. Une cible qui écrit des arêtes sur le descripteur 3 oriente les essais suivants.

Le dépôt suit Git Flow. `develop` intègre le travail. `main` ne reçoit une version que par `release/*` ou `hotfix/*`. Aucun tag n'est posé tant que la pile ouverte n'est pas mergée. La procédure est dans [docs/release.md](docs/release.md).

## Prérequis

Linux x86-64, NASM, GNU binutils et GNU make. Sous Windows, le build se fait dans WSL. Si le dépôt est sur un volume `noexec`, les binaires vont dans `/tmp`.

```bash
sudo apt-get update
sudo apt-get install -y nasm binutils make
make BUILD=/tmp/asm-fuzzer-build test
```

`make all` produit `build/asm-fuzzer`.

```bash
./build/asm-fuzzer ./build/demo-target corpus.bin crashes/latest.bin
```

```bash
./build/asm-fuzzer --target ./build/demo-target --input seed.bin \
    --output crashes --timeout 1000 --iterations 1000 --seed 1 --no-stop-on-crash
```

La sortie est un mot d'état, puis `execs`, `rate` et `edges`. Les codes sont 0 (`clean`), 2 (`crash`), 3 (`timeout`) et 1 (`error`). `--stop-on-crash` est le défaut : la première faute minimisée est écrite dans `--output` et la campagne s'arrête. Sans cet arrêt, `--output` est un répertoire et chaque signal n'y est enregistré qu'une fois. `--seed 0` est refusé.

Sur stderr, une campagne annonce son isolement, une fois : `namespaces full`, `partial` ou `none` ; `filesystem hidden` ou `host` ; `seccomp on` ou `none`. Un repli laisse la cible tourner. La feuille de route est dans [docs/roadmap.md](docs/roadmap.md).

## Vérifications

| Commande | Rôle |
| --- | --- |
| `make all` | Compile et lie le fuzzer |
| `make test` | Unités, campagnes, isolement, évaluation de release |
| `make lint` | NASM en warnings-as-errors, fins de ligne, espaces |
| `make security` | Secrets, actions épinglées, permissions des workflows |

## Disposition

```text
src/core        campagne, exécution, couverture, file, privilèges, namespaces, fichiers, seccomp
src/mutators    bitflip, byteflip, arithmétique, ordonnancement
src/corpus      fichier, répertoire, minimisation
src/reporting   crash et chemins
src/utils       syscalls, mémoire, générateur
include         constantes, appels, couverture
tests           unités et campagnes sur les cibles du dépôt
```

## Workflow

Les branches, les pull requests et les règles de protection sont décrites dans [docs/git-workflow.md](docs/git-workflow.md). La contribution se fait selon [CONTRIBUTING.md](CONTRIBUTING.md).

## Sécurité

Les vulnérabilités du fuzzer se signalent en privé. Voir [SECURITY.md](SECURITY.md). Ne lance pas un exécutable inconnu sur un runner GitHub.
