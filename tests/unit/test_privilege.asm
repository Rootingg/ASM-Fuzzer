; Root ids are refused. An unprivileged user is allowed.

%include "syscalls.inc"
%include "macros.inc"

section .text
extern privilege_blocked
global _start

_start:
    mov rdi, 1000
    mov rsi, 1000
    mov rdx, 1000
    mov rcx, 1000
    call privilege_blocked
    test rax, rax
    jnz .fail

    xor edi, edi
    mov rsi, 1000
    mov rdx, 1000
    mov rcx, 1000
    call privilege_blocked
    cmp rax, 1
    jne .fail

    mov rdi, 1000
    xor esi, esi
    mov rdx, 1000
    mov rcx, 1000
    call privilege_blocked
    cmp rax, 1
    jne .fail

    mov rdi, 1000
    mov rsi, 1000
    xor edx, edx
    mov rcx, 1000
    call privilege_blocked
    cmp rax, 1
    jne .fail

    mov rdi, 1000
    mov rsi, 1000
    mov rdx, 1000
    xor ecx, ecx
    call privilege_blocked
    cmp rax, 1
    jne .fail

    EXIT 0
.fail:
    EXIT 1
