; One mutation per trial, applied to a fresh copy of the seed.
; A zero RNG state selects the deterministic schedule. Any other state
; selects bitflip, byteflip, or arithmetic from xorshift64.

section .rodata
deltas: db 1, 0xff, 16, 0xf0

section .text
extern bitflip_apply
extern byteflip_apply
extern arithmetic_apply
extern prng_next
global apply_mutation

; apply_mutation - mutate one buffer in place.
; IN:  rdi buffer, rsi length, rdx trial index, rcx pointer to RNG state (or 0)
; OUT: rax 0 on success, 1 when the length is zero or an index is rejected
apply_mutation:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rsi, rsi
    jz .reject
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    test r14, r14
    jz .deterministic
    cmp qword [r14], 0
    jz .deterministic

    mov rdi, r14
    call prng_next
    xor edx, edx
    mov ecx, 3
    div rcx
    mov r13, rdx
    mov rdi, r14
    call prng_next
    cmp r13, 0
    jne .random_byte
    mov rcx, r12
    shl rcx, 3
    xor edx, edx
    div rcx
    mov rdi, rbx
    mov rsi, r12
    call bitflip_apply
    jmp .leave

.random_byte:
    xor edx, edx
    div r12
    mov r15, rdx
    mov rdi, r14
    call prng_next
    xor edx, edx
    mov ecx, 4
    div rcx
    lea rcx, [rel deltas]
    movzx rcx, byte [rcx + rdx]
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r15
    cmp r13, 1
    jne .random_arith
    call byteflip_apply
    jmp .leave
.random_arith:
    call arithmetic_apply
    jmp .leave

.deterministic:
    mov rax, r12
    shl rax, 3
    cmp r13, rax
    jae .extra
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call bitflip_apply
    jmp .leave

.extra:
    sub r13, rax
    mov rax, r13
    xor edx, edx
    mov ecx, 3
    div rcx
    mov r13, rdx
    xor edx, edx
    div r12
    mov rdi, rbx
    mov rsi, r12
    cmp r13, 0
    jne .det_arith
    call byteflip_apply
    jmp .leave
.det_arith:
    mov rcx, 1
    cmp r13, 1
    je .det_add
    mov rcx, -1
.det_add:
    call arithmetic_apply
    jmp .leave

.reject:
    mov eax, 1
.leave:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
