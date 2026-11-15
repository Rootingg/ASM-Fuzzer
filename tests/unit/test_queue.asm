; Replacement keeps the seed and prefers a higher novelty score.
; A queued input whose edges are already covered is removed.

%include "syscalls.inc"
%include "macros.inc"

section .data
scores: dq 0, 1, 4, 2, 9, 3, 8, 7

section .text
extern queue_slot
extern queue_test_reset
extern queue_test_bit
extern queue_test_has
extern queue_cull
extern queue_used
global _start

_start:
    lea rdi, [rel scores]
    mov rsi, 8
    mov rdx, 5
    call queue_slot
    cmp rax, 1
    jne .fail

    lea rdi, [rel scores]
    mov rsi, 8
    mov rdx, 1
    call queue_slot
    cmp rax, -1
    jne .fail

    lea rdi, [rel scores]
    mov rsi, 3
    mov rdx, 100
    call queue_slot
    cmp rax, 3
    jne .fail

    call queue_test_reset
    xor edi, edi
    mov rsi, 0
    call queue_test_bit
    mov rdi, 1
    mov rsi, 0
    call queue_test_bit
    mov rdi, 2
    mov rsi, 0
    call queue_test_bit
    mov rdi, 2
    mov rsi, 1
    call queue_test_bit
    call queue_cull
    cmp rax, 2
    jne .fail
    mov rdi, 1
    mov rsi, 1
    call queue_test_has
    cmp rax, 1
    jne .fail
    mov rdi, [rel queue_used]
    cmp rdi, 2
    jne .fail

    EXIT 0
.fail:
    EXIT 1
