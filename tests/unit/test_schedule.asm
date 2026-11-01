; Deterministic schedule and the first xorshift64 step.

%include "syscalls.inc"
%include "macros.inc"

section .bss
buf: resb 1
state: resq 1

section .text
extern apply_mutation
extern prng_next
global _start

_start:
    mov byte [rel buf], 0
    lea rdi, [rel buf]
    mov rsi, 1
    xor edx, edx
    xor ecx, ecx
    call apply_mutation
    test rax, rax
    jnz .fail
    cmp byte [rel buf], 0x01
    jne .fail

    mov byte [rel buf], 0
    lea rdi, [rel buf]
    mov rsi, 1
    mov rdx, 1
    xor ecx, ecx
    call apply_mutation
    test rax, rax
    jnz .fail
    cmp byte [rel buf], 0x02
    jne .fail

    mov byte [rel buf], 0
    lea rdi, [rel buf]
    mov rsi, 1
    mov rdx, 8
    xor ecx, ecx
    call apply_mutation
    test rax, rax
    jnz .fail
    cmp byte [rel buf], 0xff
    jne .fail

    mov byte [rel buf], 0
    lea rdi, [rel buf]
    mov rsi, 1
    mov rdx, 9
    xor ecx, ecx
    call apply_mutation
    test rax, rax
    jnz .fail
    cmp byte [rel buf], 0x01
    jne .fail

    mov byte [rel buf], 0
    lea rdi, [rel buf]
    mov rsi, 1
    mov rdx, 10
    xor ecx, ecx
    call apply_mutation
    test rax, rax
    jnz .fail
    cmp byte [rel buf], 0xff
    jne .fail

    mov qword [rel state], 1
    lea rdi, [rel state]
    call prng_next
    mov rcx, 0x40822041
    cmp rax, rcx
    jne .fail
    lea rdi, [rel state]
    call prng_next
    mov rcx, 0x100041060c011441
    cmp rax, rcx
    jne .fail

    mov qword [rel state], 1
    mov byte [rel buf], 0
    lea rdi, [rel buf]
    mov rsi, 1
    xor edx, edx
    lea rcx, [rel state]
    call apply_mutation
    test rax, rax
    jnz .fail
    cmp byte [rel buf], 0x02
    jne .fail

    EXIT 0
.fail:
    EXIT 1
