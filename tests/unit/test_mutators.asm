; Deterministic checks for the three mutators.

default rel

%include "syscalls.inc"
%include "macros.inc"

section .bss
buf: resb 4

section .text
extern bitflip_apply
extern byteflip_apply
extern arithmetic_apply
global _start

_start:
    mov byte [buf], 0x00
    lea rdi, [rel buf]
    mov rsi, 1
    mov rdx, 3
    call bitflip_apply
    test rax, rax
    jnz .fail
    cmp byte [buf], 0x08
    jne .fail

    lea rdi, [rel buf]
    mov rsi, 1
    mov rdx, 3
    call bitflip_apply
    test rax, rax
    jnz .fail
    cmp byte [buf], 0x00
    jne .fail

    mov byte [buf], 0x11
    lea rdi, [rel buf]
    mov rsi, 1
    mov rdx, 8
    call bitflip_apply
    cmp rax, 1
    jne .fail
    cmp byte [buf], 0x11
    jne .fail

    mov byte [buf], 0x0f
    lea rdi, [rel buf]
    mov rsi, 1
    xor edx, edx
    call byteflip_apply
    test rax, rax
    jnz .fail
    cmp byte [buf], 0xf0
    jne .fail

    mov byte [buf], 0x10
    lea rdi, [rel buf]
    mov rsi, 1
    xor edx, edx
    mov rcx, 1
    call arithmetic_apply
    test rax, rax
    jnz .fail
    cmp byte [buf], 0x11
    jne .fail

    mov byte [buf], 0xff
    lea rdi, [rel buf]
    mov rsi, 1
    xor edx, edx
    mov rcx, 1
    call arithmetic_apply
    test rax, rax
    jnz .fail
    cmp byte [buf], 0x00
    jne .fail

    mov byte [buf], 0x00
    lea rdi, [rel buf]
    mov rsi, 1
    xor edx, edx
    mov rcx, -1
    call arithmetic_apply
    test rax, rax
    jnz .fail
    cmp byte [buf], 0xff
    jne .fail

    lea rdi, [rel buf]
    xor esi, esi
    xor edx, edx
    call byteflip_apply
    cmp rax, 1
    jne .fail

    EXIT 0
.fail:
    EXIT 1
