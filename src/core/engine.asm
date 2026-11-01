; Each trial flips one bit of a fresh copy of the seed.
; A timeout is not a crash. The first crash is saved, and the run stops there
; unless the caller asked to continue.

%include "constants.inc"

section .text
extern mem_copy
extern bitflip_apply
extern execute_target
extern crash_save
global fuzz_campaign

; fuzz_campaign - search a bounded bitflip neighbourhood of one seed.
; IN:  rdi pointer to the campaign record:
;        +0  target path
;        +8  seed
;        +16 length
;        +24 scratch
;        +32 crash path
;        +40 timeout milliseconds
;        +48 iterations
;        +56 stop on crash (1 or 0)
; OUT: rax EXIT_OK, EXIT_CRASH, EXIT_TIMEOUT, or -1
fuzz_campaign:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    mov rbx, [rdi]
    mov r12, [rdi + 8]
    mov r13, [rdi + 16]
    mov r14, [rdi + 24]
    mov r15, [rdi + 32]
    mov rax, [rdi + 40]
    mov rcx, [rdi + 48]
    mov rdx, [rdi + 56]
    test rcx, rcx
    jz .bad

    sub rsp, 48
    mov qword [rsp], 0
    mov [rsp + 16], rax
    mov [rsp + 24], rdx
    mov qword [rsp + 32], 0
    mov qword [rsp + 40], 0

    test r13, r13
    jz .use_iterations
    mov rax, r13
    shl rax, 3
    cmp rax, rcx
    jbe .store_trials
    mov rax, rcx
    jmp .store_trials
.use_iterations:
    mov rax, rcx
.store_trials:
    mov [rsp + 8], rax

.loop:
    mov rax, [rsp]
    cmp rax, [rsp + 8]
    jae .finish

    test r13, r13
    jz .run
    mov rdi, r14
    mov rsi, r12
    mov rdx, r13
    call mem_copy
    mov rdi, r14
    mov rsi, r13
    mov rdx, [rsp]
    call bitflip_apply
    test rax, rax
    jnz .bad_stack

.run:
    mov rdi, rbx
    mov rsi, r14
    mov rdx, r13
    mov rcx, [rsp + 16]
    call execute_target
    cmp rax, EXIT_CRASH
    je .on_crash
    cmp rax, EXIT_TIMEOUT
    je .on_timeout
    cmp rax, 0
    jl .bad_stack
    jmp .next

.on_timeout:
    mov qword [rsp + 32], 1
    jmp .next

.on_crash:
    cmp qword [rsp + 40], 0
    jne .after_save
    mov rdi, r15
    mov rsi, r14
    mov rdx, r13
    call crash_save
    test rax, rax
    jnz .bad_stack
    mov qword [rsp + 40], 1
.after_save:
    cmp qword [rsp + 24], 0
    je .next
    mov eax, EXIT_CRASH
    jmp .leave_stack

.next:
    inc qword [rsp]
    jmp .loop

.finish:
    mov eax, EXIT_OK
    cmp qword [rsp + 32], 0
    je .prefer_crash
    mov eax, EXIT_TIMEOUT
.prefer_crash:
    cmp qword [rsp + 40], 0
    je .leave_stack
    mov eax, EXIT_CRASH
    jmp .leave_stack

.bad_stack:
    mov rax, -1
.leave_stack:
    add rsp, 48
    jmp .leave
.bad:
    mov rax, -1
.leave:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
