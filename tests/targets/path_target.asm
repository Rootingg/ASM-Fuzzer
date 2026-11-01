; Two-step path. Bit 0 of the input opens edge 2.
; Mutating that interesting byte again can set bit 1 and open edge 3.
; Edge 1 is the entry, taken by every input.

default rel

%include "syscalls.inc"
%include "macros.inc"
%include "coverage.inc"

section .bss
input: resb 1

section .text
global _start

_start:
    mov rax, SYS_read
    xor edi, edi
    lea rsi, [rel input]
    mov edx, 1
    syscall
    mov bl, 0
    cmp rax, 1
    jl .mark
    mov bl, [rel input]
.mark:
    COV 1
    test bl, 1
    jz .high
    COV 2
.high:
    cmp bl, 3
    jne .done
    COV 3
.done:
    EXIT 0
