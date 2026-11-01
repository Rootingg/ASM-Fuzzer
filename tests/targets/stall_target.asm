; Blocks in pause and never reads stdin.
; A seed larger than the pipe must not stall the parent in write.

%include "syscalls.inc"

section .text
global _start

_start:
.hang:
    mov rax, SYS_pause
    syscall
    jmp .hang
