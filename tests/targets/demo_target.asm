; Controlled demo target used by the integration tests.
default rel
; It faults only when the first four stdin bytes are "CRSH".
; Any other input, including a short read, exits 0.

%include "syscalls.inc"
%include "macros.inc"

section .bss
input: resb 64

section .text
global _start

_start:
    mov rax, SYS_read
    xor edi, edi
    lea rsi, [rel input]
    mov edx, 64
    syscall
    cmp rax, 4
    jl .ok
    cmp dword [input], 0x48535243
    jne .ok
    xor eax, eax
    mov eax, [rax]
.ok:
    EXIT 0
