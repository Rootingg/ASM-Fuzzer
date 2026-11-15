# Cours filmé — ASM-Fuzzer

Narration à lire telle quelle. Les plans disent quoi montrer. Durée parlée : environ 16 minutes.
Les sous-titres sont dans [sous-titres.srt](sous-titres.srt).

La démo locale déjà vérifiée affiche `crash`, `execs 7`, puis un rejeu qui meurt par `SIGSEGV` (code 139). stderr : `namespaces full`, `filesystem hidden`, `seccomp on`.

## 00:00 — Le projet

**À l'écran.** https://github.com/Rootingg/ASM-Fuzzer sans `/tree/main`. La branche affichée est `develop`.

ASM-Fuzzer est un fuzzer black-box pour Linux x86-64. Il est écrit en NASM, sans libc. Chaque étape passe par un appel système : lire la graine, la muter, lancer la cible avec `execve`, lire le statut de `wait4`, écrire le crash.

Les fuzzers habituels, AFL++ ou libFuzzer, sont de gros programmes en C++. Ici le but est de voir le mécanisme. Le dépôt est public. `develop` est la branche par défaut, celle du travail intégré. `main` porte le tag `v1.0.0`.

**À l'écran.** Le schéma Mermaid en haut du README.

Une campagne part d'une graine, applique une seule mutation, lance la cible, puis classe le résultat : `clean`, `crash`, `timeout` ou `error`. Un crash est minimisé, puis écrit dans un fichier.

## 02:00 — L'arbre et le flux

**À l'écran.** `docs/architecture.md`, le premier schéma.

`src/main.asm` lit la ligne de commande et appelle `fuzz_campaign`. Le moteur, dans `src/core/engine.asm`, recopie la graine et appelle `apply_mutation`. L'exécuteur, `src/core/executor.asm`, crée un tube non bloquant, fait `fork`, puis `execve`. Au retour, `classify_wait_status` lit le mot de `wait4`.

Les codes sont dans `include/constants.inc`. Zéro, c'est `clean`. Un, `error`. Deux, `crash`. Trois, `timeout`. Le délai mural par défaut est une seconde. Le CPU de la cible est plafonné à 5 secondes, l'adresse à 64 Mio, les fichiers à 1 Mio. Ce plafond CPU ne suffit pas : une cible bloquée dans `read` ne consomme pas de CPU. Seul le délai mural l'arrête, par `SIGKILL` sur le groupe de processus.

## 04:30 — Les mutations

**À l'écran.** `src/mutators/schedule.asm`, le label `.deterministic`.

Sans `--seed`, l'essai numéro n inverse le bit numéro n, tant qu'il reste des bits. Après, le résidu modulo 3 choisit byteflip, plus un, ou moins un. Avec `--seed`, un xorshift64 choisit le mutateur, l'index et le pas. `--seed 0` est refusé : un état nul ne change plus.

La graine de la démo est `BRSH`. Le premier essai inverse le bit de poids faible du B. B vaut 0x42, C vaut 0x43. Le mot devient `CRSH`.

## 06:30 — La cible et le crash

**À l'écran.** `tests/targets/demo_target.asm`, la comparaison `0x48535243`.

La cible lit l'entrée standard. Si les quatre premiers octets sont `CRSH`, elle lit l'adresse zéro. En little-endian, ces quatre lettres sont le mot 0x48535243. Toute autre entrée se termine par zéro. Le fuzzer ne contient pas ce mot. Il ne fait que regarder si le processus est mort d'un signal.

`SIGSEGV` est un crash. `SIGSYS` aussi : c'est la mort seccomp. `SIGKILL` et `SIGXCPU` sont des timeouts. Le code 127 est une erreur de lancement, pas un crash.

## 08:00 — Corpus, couverture, minimisation

**À l'écran.** `include/constants.inc`, les constantes `COVER_QUEUE`, `EDGE_BITS`, `MINIMIZE_ATTEMPTS`.

`--input` peut être un répertoire. Les fichiers réguliers sont triés par nom. Avant d'écrire un crash, le moteur cherche le plus court préfixe qui refait le même signal, puis retire jusqu'à 32 octets. `--stop-on-crash` est le défaut. Sans lui, `--output` est un répertoire et chaque signal n'est gardé qu'une fois. Deux crashs du même signal ne font qu'une entrée : `wait4` ne donne pas l'adresse de la faute.

Une cible instrumentée écrit un identifiant de 16 bits sur le descripteur 3. Huit entrées de 64 octets sont gardées. L'emplacement zéro est la graine. Deux arêtes du même numéro n'en font qu'une. Une cible sans instrumentation, comme la démo, laisse `edges` à zéro. C'est normal.

## 10:30 — L'isolement

**À l'écran.** Le second schéma de `docs/architecture.md`.

Dans l'enfant, avant `execve` : namespaces, puis racine réduite, puis `no_new_privs` et capacités vidées, puis seccomp. `no_new_privs` est posé après les namespaces, sinon `CLONE_NEWUSER` échoue.

En local, stderr dit `namespaces full`, `filesystem hidden`, `seccomp on`. La cible est le PID 1 et n'ouvre plus `/etc/passwd`. Sur un runner GitHub, le noyau refuse souvent le namespace utilisateur. Le premier essai sort alors en 127 et la campagne le relance. stderr dit `namespaces none` et `filesystem host`. `seccomp on` peut rester.

La liste autorise `read`, `write`, `openat`, `execve`, `exit`, et les appels des cibles du dépôt. `mmap` et `brk` n'y sont pas. Un binaire C habituel meurt par `SIGSYS`.

## 13:00 — La démo

**À l'écran.** Un terminal dans WSL, dépôt monté, binaires dans `/tmp/asm-fuzzer-build` si le disque est `noexec`.

```bash
printf 'BRSH' > seed.bin
./build/asm-fuzzer --target ./build/demo-target --input seed.bin \
    --output crash.bin --iterations 64
./build/demo-target < crash.bin
```

Le premier processus affiche `crash`, `execs 7`, un débit, `edges 0`, et se termine avec le code 2. Le 7 compte la découverte et la minimisation. Le second processus meurt par `SIGSEGV`. Le shell affiche le code 139, c'est-à-dire 128 plus 11.

**À l'écran.** `git log --oneline origin/main -1` et le tag `v1.0.0`. Puis `.github/workflows/ci.yml` : les jobs s'appellent `build`, `test`, `lint`, `security`.

La CI ne lance que des cibles assemblées dans ce dépôt. Pas de binaire tiers.

## 15:30 — Ce que cette version ne fait pas

Le bac à sable recule si le noyau refuse les namespaces. `execve` et `openat` restent autorisés. La déduplication s'arrête au signal. La file de couverture est petite. Ce sont les limites écrites dans `docs/threat-model.md`, pas des oublis.

Le dépôt est fini pour la v1.0.0. La suite, si elle existe, serait une v1.1.
