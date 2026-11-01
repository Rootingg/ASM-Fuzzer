# Architecture

ASM-Fuzzer est un binaire statique, sans libc. Chaque module est une unité NASM liée par `ld`.

```text
main
  corpus_load        lit une entrée, tronquée à 131072 octets
  corpus             un fichier ou un répertoire de graines, trié
  fuzz_campaign      une mutation par essai, puis l'exécution
  minimize_input     préfixe le plus court, puis suppression d'octets
    mem_copy
    apply_mutation   bitflip, byteflip ou arithmétique
    execute_target   pipe non bloquant, fork, execve, timeout, wait4
    classify_wait_status
    crash_save       une entrée par signal
```

## Campagne

Chaque essai recopie le corpus et applique une seule mutation. Sans `--seed`, l'essai `n` inverse le bit `n` tant que ce bit existe, puis enchaîne byteflip et des pas arithmétiques `+1` / `-1`. Avec `--seed`, un xorshift64 choisit le mutateur, l'index et le pas. La même graine refait la même série.

`--input` peut être un fichier ou un répertoire. Les fichiers réguliers du répertoire sont triés par nom et chacun reçoit la campagne. Le masque de signaux est commun à toutes les graines.

Avant d'écrire un crash, le fuzzer cherche le plus court préfixe qui reproduit le même signal, puis retire jusqu'à 32 octets inutiles. `--stop-on-crash` est le défaut : le premier fault minimisé est écrit dans le fichier `--output` et les graines suivantes ne sont pas lancées. `--no-stop-on-crash` traite `--output` comme un répertoire déjà créé et y écrit `sig<signal>-<essai>`, une fois par signal. Le statut `wait4` ne donne pas d'adresse de faute, donc la déduplication s'arrête au numéro de signal.

La sortie compte les exécutions, y compris celles de la minimisation, et le débit en exécutions par seconde.

Le nombre d'essais est `--iterations`, y compris au-delà du voisinage des bits du corpus. La valeur par défaut reste 64.

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
