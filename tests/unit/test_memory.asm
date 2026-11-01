; Checks for copy, fill, and compare.

default rel

%include "syscalls.inc"
%include "macros.inc"

section .data
left: db "abcd"
right: db "abcd"
other: db "abXd"

section .bss
dest: resb 4

section .text
extern mem_copy
extern mem_fill
extern mem_cmp
global _start

_start:
    lea rdi, [rel dest]
    lea rsi, [rel left]
    mov rdx, 4
    call mem_copy
    lea rdi, [rel dest]
    lea rsi, [rel left]
    mov rdx, 4
    call mem_cmp
    test rax, rax
    jnz .fail

    lea rdi, [rel left]
    lea rsi, [rel other]
    mov rdx, 4
    call mem_cmp
    cmp rax, 1
    jne .fail

    lea rdi, [rel dest]
    mov rsi, 0xab
    mov rdx, 4
    call mem_fill
    cmp byte [dest], 0xab
    jne .fail
    cmp byte [dest + 3], 0xab
    jne .fail

    lea rdi, [rel left]
    lea rsi, [rel right]
    xor edx, edx
    call mem_cmp
    test rax, rax
    jnz .fail

    EXIT 0
.fail:
    EXIT 1
