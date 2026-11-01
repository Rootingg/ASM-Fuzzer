; Invert every bit of one byte.

section .text
global byteflip_apply

; byteflip_apply - XOR one byte with 0xFF.
; IN:  rdi buffer, rsi length, rdx byte index
; OUT: rax 0 on success, 1 when the index is outside the buffer
byteflip_apply:
    test rsi, rsi
    jz .reject
    cmp rdx, rsi
    jae .reject
    xor byte [rdi + rdx], 0xff
    xor eax, eax
    ret
.reject:
    mov eax, 1
    ret
