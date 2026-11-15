; Controlled target with two distinct faults.
; The first byte selects the fault: 1 is SIGILL, 2 is SIGSEGV.
; Any other input exits 0.

default rel

%include "syscalls.inc"
%include "macros.inc"

section .bss
input: resb 8

section .text
global _start

_start:
    mov rax, SYS_read
    xor edi, edi
    lea rsi, [rel input]
    mov edx, 8
    syscall
    cmp rax, 1
    jl .ok
    cmp byte [rel input], 1
    je .illegal
    cmp byte [rel input], 2
    je .fault
.ok:
    EXIT 0
.illegal:
    ud2
.fault:
    xor eax, eax
    mov eax, [rax]
    EXIT 1
