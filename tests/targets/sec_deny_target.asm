; socket is not on the allowlist. An installed filter kills this program.
; Without a filter, the call returns and the program says so.

%include "syscalls.inc"

section .rodata
msg_open: db "seccomp-open", 10
msg_open_len equ $ - msg_open

section .text
global _start

_start:
    mov eax, SYS_socket
    xor edi, edi
    xor esi, esi
    xor edx, edx
    syscall
    mov eax, SYS_write
    mov edi, 2
    lea rsi, [rel msg_open]
    mov edx, msg_open_len
    syscall
    mov eax, SYS_exit
    xor edi, edi
    syscall
