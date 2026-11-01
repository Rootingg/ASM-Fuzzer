; Confirms the fuzzer locked this process before exec.
; no_new_privs is set, capabilities are empty, and fd 4 was not inherited.
; Failure raises SIGILL so the campaign cannot report a clean run.

default rel

%include "constants.inc"
%include "syscalls.inc"
%include "macros.inc"

section .bss
header: resb 8
caps: resb 32

section .text
global _start

_start:
    mov eax, SYS_prctl
    mov edi, 39
    xor esi, esi
    xor edx, edx
    xor r10, r10
    xor r8, r8
    syscall
    cmp rax, 1
    jne .bad

    mov dword [rel header], 0x20080522
    mov dword [rel header + 4], 0
    mov eax, SYS_capget
    lea rdi, [rel header]
    lea rsi, [rel caps]
    syscall
    test rax, rax
    js .bad
    lea rsi, [rel caps]
    mov ecx, 6
.scan:
    cmp dword [rsi], 0
    jne .bad
    add rsi, 4
    dec ecx
    jnz .scan

    mov eax, SYS_fcntl
    mov edi, 4
    mov esi, 1
    xor edx, edx
    syscall
    test rax, rax
    jns .bad

    mov eax, SYS_fcntl
    mov edi, COV_FD
    mov esi, 1
    xor edx, edx
    syscall
    test rax, rax
    js .bad

    EXIT 0
.bad:
    ud2
