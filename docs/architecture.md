# Architecture

ASM-Fuzzer est un binaire statique, sans libc. Chaque module est une unité NASM liée par `ld`.

```text
main
  corpus_load        lit une entrée, tronquée à 4096 octets
  fuzz_campaign      essaie des voisins à un bit
    mem_copy
    bitflip_apply
    execute_target   pipe, fork, execve, wait4
    wait_status_is_crash
    crash_save       écrit l'entrée exacte qui a fauté
```

## Campagne

Le bootstrap ne pile pas les mutations. L'essai `n` recopie le corpus puis inverse le bit `n`. Le premier fault arrête la campagne. Le fichier écrit est donc rejouable tel quel. Le nombre d'essais est plafonné à 64 bits pour garder la CI courte. Les mutateurs byteflip et arithmétique sont testés unitairement et ne sont pas encore branchés dans la campagne.

## Exécution

`execute_target` crée un tube, fork, puis dans l'enfant :

1. branche le côté lecture sur l'entrée standard ;
2. pose `RLIMIT_CPU` à 1 seconde, `RLIMIT_AS` à 64 Mio et `RLIMIT_FSIZE` à 1 Mio ;
3. appelle `execve` avec un `argv` à un élément et un environnement vide.

Le parent écrit l'entrée, ferme le tube et attend. `SIGPIPE` est ignoré dans le parent pour qu'une cible qui n'a pas tout lu renvoie `EPIPE` au lieu de tuer le fuzzer. `EINTR` est rejoué sur les lectures et écritures.

Un fault est `SIGILL`, `SIGTRAP`, `SIGABRT`, `SIGBUS`, `SIGFPE` ou `SIGSEGV`, y compris avec le bit de core dump. `SIGKILL` et `SIGXCPU` sont des limites, pas des crashs.

## Cible de démonstration

`tests/targets/demo_target.asm` lit l'entrée standard. Si les quatre premiers octets sont `CRSH`, elle déréférence l'adresse nulle. Toute autre entrée se termine avec le code 0. Le fuzzer ne connaît pas ce magic : il l'observe par le statut de `wait4`.
