; Flip a single bit. The index is counted from bit 0 of the first byte.

section .text
global bitflip_apply

; bitflip_apply - invert one bit in a buffer.
; IN:  rdi buffer, rsi length, rdx bit index
; OUT: rax 0 on success, 1 when the index is outside the buffer
bitflip_apply:
    test rsi, rsi
    jz .reject
    mov rax, rdx
    shr rax, 3
    cmp rax, rsi
    jae .reject
    mov rcx, rdx
    and rcx, 7
    mov r8b, 1
    shl r8b, cl
    xor byte [rdi + rax], r8b
    xor eax, eax
    ret
.reject:
    mov eax, 1
    ret
