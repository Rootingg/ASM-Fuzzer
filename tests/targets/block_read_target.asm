; Reads stdin, then blocks in pause once the pipe reaches EOF.
; The pause uses no CPU, so RLIMIT_CPU does not stop it.

default rel

%include "syscalls.inc"

section .bss
buf: resb 1

section .text
global _start

_start:
.read:
    mov rax, SYS_read
    xor edi, edi
    lea rsi, [rel buf]
    mov edx, 1
    syscall
    cmp rax, 0
    jg .read
.hang:
    mov rax, SYS_pause
    syscall
    jmp .hang
