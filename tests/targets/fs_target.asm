; Report whether the host root is still visible.
; /etc/passwd exists on the host and is absent from the reduced root.

%include "syscalls.inc"

section .rodata
path_passwd: db "/etc/passwd", 0
msg_open: db "fs-open", 10
msg_open_len equ $ - msg_open
msg_blocked: db "fs-blocked", 10
msg_blocked_len equ $ - msg_blocked

section .text
global _start

_start:
    mov eax, SYS_openat
    mov edi, AT_FDCWD
    lea rsi, [rel path_passwd]
    xor edx, edx
    xor r10, r10
    syscall
    test rax, rax
    js .blocked
    mov edi, eax
    mov eax, SYS_close
    syscall
    lea rsi, [rel msg_open]
    mov edx, msg_open_len
    jmp .write

.blocked:
    lea rsi, [rel msg_blocked]
    mov edx, msg_blocked_len

.write:
    mov eax, SYS_write
    mov edi, 2
    syscall
    mov eax, SYS_exit
    xor edi, edi
    syscall
