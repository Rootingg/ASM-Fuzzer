; xorshift64. A zero state is rejected by the caller because it never changes.

section .text
global prng_next

; prng_next - advance a 64-bit state.
; IN:  rdi pointer to the state
; OUT: rax new state
prng_next:
    mov rax, [rdi]
    mov rcx, rax
    shl rax, 13
    xor rax, rcx
    mov rcx, rax
    shr rax, 7
    xor rax, rcx
    mov rcx, rax
    shl rax, 17
    xor rax, rcx
    mov [rdi], rax
    ret
