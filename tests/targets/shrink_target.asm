; SIGSEGV when any input byte is 0xA5. Extra bytes do not matter.
; Used to check that a crashing input is minimized.

default rel

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
    mov rcx, rax
    test rcx, rcx
    jz .ok
    lea rsi, [rel input]
.scan:
    cmp byte [rsi], 0xa5
    je .fault
    inc rsi
    dec rcx
    jnz .scan
.ok:
    EXIT 0
.fault:
    xor eax, eax
    mov eax, [rax]
    EXIT 1
