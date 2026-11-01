; Add a signed byte to one buffer byte, wrapping modulo 256.

section .text
global arithmetic_apply

; arithmetic_apply - add cl to one byte.
; IN:  rdi buffer, rsi length, rdx byte index, rcx delta (low 8 bits)
; OUT: rax 0 on success, 1 when the index is outside the buffer
arithmetic_apply:
    test rsi, rsi
    jz .reject
    cmp rdx, rsi
    jae .reject
    add byte [rdi + rdx], cl
    xor eax, eax
    ret
.reject:
    mov eax, 1
    ret
