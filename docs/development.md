# Développement

## Build

```bash
sudo apt-get install -y nasm binutils make
make clean
make test
```

Les objets et les binaires vont dans `build/`, qui n'est pas versionné. Pour lancer les binaires depuis un système de fichiers monté `noexec` :

```bash
make BUILD=/tmp/asm-fuzzer-build test
```

## Convention assembleur

- Syntaxe NASM, format ELF64.
- Les fonctions du projet suivent l'ABI System V : arguments dans `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`, retour dans `rax`. L'appelant peut considérer `rcx` et `r11` comme détruits au même titre que les autres registres volatils.
- Les syscalls Linux ne suivent pas cette convention. Le noyau lit les arguments dans `rdi`, `rsi`, `rdx`, `r10`, `r8`, `r9`. Le quatrième argument est `r10`, pas `rcx` : le syscall écrase `rcx` et `r11`. Les wrappers de `src/utils/syscalls.asm` font cette translation.
- Instructions en minuscules, indentation de 4 espaces, commentaires en anglais.
- `-w+all -w+error` est actif. Un warning casse `make lint` et le build. Si NASM connait `reloc-rel-dword`, cet avertissement est désactivé : les versions récentes le lèvent sur chaque `call` vers un autre objet, alors que cette relocalisation PC-relative est le mode normal d'ELF64. Le NASM d'Ubuntu 24.04 ignore ce nom.

## Ajouter un mutateur

1. Créer `src/mutators/<nom>.asm` avec une fonction globale et un échec explicite si l'index sort du buffer.
2. Ajouter un cas dans `tests/unit/test_mutators.asm`.
3. Ne le brancher dans `src/core/engine.asm` qu'une fois le test déterministe vert.

## Ajouter un test de crash

La campagne d'intégration dans `tests/integration/campaign.sh` doit garder trois propriétés :

- une entrée connue fait fault la cible de démonstration ;
- une entrée qui ne fault pas n'est pas signalée ;
- le fichier écrit par le fuzzer rejoue le même fault.

Les graines sont produites dans un répertoire temporaire. `BRSH` devient `CRSH` en inversant le bit 0. `hello` ne peut pas devenir `CRSH` avec un seul bitflip, ce qui sert de contrôle négatif.

## Ce qui ne va pas en CI

Pas de binaire téléchargé, pas de corpus réel, pas de `curl` envoyé dans un shell. Une nouvelle cible de test doit être une source du dépôt, bornée en temps et en ressources.
