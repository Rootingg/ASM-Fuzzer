; Byte buffer helpers. Overlapping ranges are not supported.

section .text
global mem_copy
global mem_fill
global mem_cmp

; mem_copy - copy rdx bytes from rsi to rdi.
; IN:  rdi destination, rsi source, rdx length
mem_copy:
    mov rcx, rdx
    cld
    rep movsb
    ret

; mem_fill - fill rdx bytes at rdi with the low byte of rsi.
; IN:  rdi destination, rsi value, rdx length
mem_fill:
    mov rax, rsi
    mov rcx, rdx
    cld
    rep stosb
    ret

; mem_cmp - compare two buffers.
; IN:  rdi left, rsi right, rdx length
; OUT: rax 0 when equal, 1 otherwise
mem_cmp:
    test rdx, rdx
    jz .equal
    mov rcx, rdx
.loop:
    mov al, [rdi]
    cmp al, [rsi]
    jne .differ
    inc rdi
    inc rsi
    dec rcx
    jnz .loop
.equal:
    xor eax, eax
    ret
.differ:
    mov eax, 1
    ret
