# Architecture

ASM-Fuzzer est un binaire statique, sans libc. Chaque module est une unité NASM liée par `ld`.

```text
main
  corpus_load        lit une entrée, tronquée à 131072 octets
  fuzz_campaign      essaie des voisins à un bit
    mem_copy
    bitflip_apply
    execute_target   pipe non bloquant, fork, execve, timeout, wait4
    classify_wait_status
    crash_save       écrit l'entrée exacte qui a fauté
```

## Campagne

Le bootstrap ne pile pas les mutations. L'essai `n` recopie le corpus puis inverse le bit `n`. Le premier fault arrête la campagne. Le fichier écrit est donc rejouable tel quel. Le nombre d'essais est plafonné à 64 bits pour garder la CI courte. Les mutateurs byteflip et arithmétique sont testés unitairement et ne sont pas encore branchés dans la campagne.

## Exécution

`execute_target` crée un tube dont la capacité est ramenée à 4 096 octets, fork, puis dans l'enfant :

1. place l'enfant dans son propre groupe de processus ;
2. branche le côté lecture sur l'entrée standard ;
3. pose `RLIMIT_CPU` à 5 secondes, `RLIMIT_AS` à 64 Mio et `RLIMIT_FSIZE` à 1 Mio ;
4. appelle `execve` avec un `argv` à un élément et un environnement vide.

Le parent ne dépend pas de la taille du tube. Il écrit en `O_NONBLOCK`, surveille le temps monotone, et ferme le côté écriture seulement quand toute l'entrée a été acceptée. `SIGPIPE` est ignoré pour qu'une cible qui se termine tôt renvoie `EPIPE`. Si l'écriture rendrait `EAGAIN`, le parent attend avec `poll` au lieu de bloquer. Un pidfd, quand le noyau le fournit, réveille le parent dès que l'enfant se termine.

Le délai par défaut est une seconde de temps réel (`--timeout`). À l'échéance, le parent envoie `SIGKILL` au groupe puis au processus, puis `wait4` récupère l'enfant. Aucun chemin d'erreur après le `fork` ne laisse un zombie.

| Résultat | Signification | Code |
| --- | --- | --- |
| `clean` | L'enfant s'est terminé sans fault | 0 |
| `crash` | `SIGILL`, `SIGTRAP`, `SIGABRT`, `SIGBUS`, `SIGFPE`, `SIGSEGV` | 2 |
| `timeout` | Échéance murale, `SIGKILL` ou `SIGXCPU` | 3 |
| `error` | Le lancement a échoué, ou l'enfant s'est terminé avec le code 127 | 1 |

`RLIMIT_CPU` reste un filet. Une cible bloquée dans `read` ou `pause` ne consomme presque pas de CPU : seul le délai mural l'arrête. Ces limites ne sont pas une sandbox. L'isolation par namespace et seccomp est prévue pour une version ultérieure, voir [roadmap.md](roadmap.md).

## Cible de démonstration

`tests/targets/demo_target.asm` lit l'entrée standard. Si les quatre premiers octets sont `CRSH`, elle déréférence l'adresse nulle. Toute autre entrée se termine avec le code 0. Le fuzzer ne connaît pas ce magic : il l'observe par le statut de `wait4`.
