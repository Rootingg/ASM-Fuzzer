# ASM-Fuzzer

Fuzzer binaire natif x86-64 pour Linux, écrit en assembleur NASM et en appels système. Il couvre les mutations, la détection de crash, le corpus et des cas de test reproductibles.

Le dépôt suit Git Flow. `develop` intègre le travail en cours. `main` ne reçoit une version que par une branche `release/*` ou `hotfix/*`.

## État

Bootstrap. La campagne actuelle repart du corpus à chaque essai et inverse un seul bit. La cible est lancée avec `execve`, sans shell, avec des limites de CPU, de mémoire et de taille de fichier. Seule la cible de démonstration du dépôt est exécutée en CI.

## Prérequis

Linux x86-64, NASM, GNU binutils et GNU make. Sous Windows, le build se fait dans WSL.

```bash
sudo apt-get update
sudo apt-get install -y nasm binutils make
make test
```

`make all` produit `build/asm-fuzzer`.

```bash
./build/asm-fuzzer ./build/demo-target corpus.bin crashes/latest.bin
```

```bash
./build/asm-fuzzer --target ./build/demo-target --input seed.bin \
    --output crashes --timeout 1000 --iterations 1000 --seed 1 --no-stop-on-crash
```

Le programme écrit `clean`, `crash`, `timeout` ou `error`, puis `execs` et `rate`. Il se termine avec le code 0, 2, 3 ou 1. `--input` accepte un fichier ou un répertoire de graines. `--stop-on-crash` est le défaut : la première faute minimisée est écrite dans le fichier `--output` et la campagne s'arrête. Sans cet arrêt, `--output` est un répertoire et chaque signal n'y est enregistré qu'une fois. La feuille de route est dans [docs/roadmap.md](docs/roadmap.md).

## Vérifications

| Commande | Rôle |
| --- | --- |
| `make all` | Compile et lie le fuzzer |
| `make test` | Unités, oracle de crash, timeouts, mutations reproductibles |
| `make lint` | NASM en warnings-as-errors, fins de ligne, espaces |
| `make security` | Secrets, actions épinglées, permissions des workflows |

## Disposition

```text
src/core        moteur, exécution, classification des signaux
src/mutators    bitflip, byteflip, arithmétique
src/corpus      lecture d'une entrée
src/reporting   écriture du fichier de crash
src/utils       syscalls et mémoire
include         constantes, numéros d'appels, macros
tests           unités, campagne, cible de démonstration
```

## Workflow

Les branches, les pull requests et les règles de protection sont décrites dans [docs/git-workflow.md](docs/git-workflow.md). La contribution se fait selon [CONTRIBUTING.md](CONTRIBUTING.md).

## Sécurité

Les vulnérabilités du fuzzer se signalent en privé. Voir [SECURITY.md](SECURITY.md). Ne lance pas un exécutable inconnu sur un runner GitHub.
