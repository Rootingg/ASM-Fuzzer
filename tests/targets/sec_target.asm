; Uses only syscalls on the allowlist.

%include "syscalls.inc"

section .rodata
msg_alive: db "seccomp-alive", 10
msg_alive_len equ $ - msg_alive

section .text
global _start

_start:
    mov eax, SYS_write
    mov edi, 2
    lea rsi, [rel msg_alive]
    mov edx, msg_alive_len
    syscall
    mov eax, SYS_exit
    xor edi, edi
    syscall
