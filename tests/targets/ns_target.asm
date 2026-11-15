; Report the PID seen by the executed target.
; PID 1 means this process is init of a new PID namespace.

%include "syscalls.inc"
%include "macros.inc"

section .rodata
prefix: db "observed-pid ", 0
prefix_len equ $ - prefix - 1

section .text
global _start

_start:
    mov eax, SYS_write
    mov edi, 2
    lea rsi, [rel prefix]
    mov edx, prefix_len
    syscall
    mov eax, SYS_getpid
    syscall
    mov rdi, rax
    call write_pid
    mov eax, SYS_write
    mov edi, 2
    lea rsi, [rel nl]
    mov edx, 1
    syscall
    EXIT 0

nl: db 10

; write_pid - write rdi in decimal to stderr.
write_pid:
    sub rsp, 32
    mov rax, rdi
    lea rcx, [rsp + 32]
.digits:
    xor edx, edx
    mov ebx, 10
    div rbx
    add dl, "0"
    dec rcx
    mov [rcx], dl
    test rax, rax
    jnz .digits
    lea rbx, [rsp + 32]
    sub rbx, rcx
    mov eax, SYS_write
    mov edi, 2
    mov rsi, rcx
    mov rdx, rbx
    syscall
    add rsp, 32
    ret
