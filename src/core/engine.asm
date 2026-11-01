; Bootstrap campaign: each trial flips one bit of a fresh copy of the seed.
; Trials are independent, so a saved crash is the exact input that faulted.

%include "constants.inc"

section .text
extern mem_copy
extern bitflip_apply
extern execute_target
extern wait_status_is_crash
extern crash_save
global fuzz_campaign

; fuzz_campaign - search a bounded bitflip neighbourhood of one seed.
; IN:  rdi target path, rsi seed, rdx length, rcx scratch, r8 crash path
; OUT: rax 0 when no fault is found, 2 when a crash file was written, -1 on error
fuzz_campaign:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8

    test r13, r13
    jz .clean

    mov rbp, r13
    shl rbp, 3
    cmp rbp, CAMPAIGN_MAX_BITS
    jbe .bits_ready
    mov rbp, CAMPAIGN_MAX_BITS
.bits_ready:
    xor eax, eax
    push rax
.loop:
    mov rax, [rsp]
    cmp rax, rbp
    jae .clean_stack

    mov rdi, r14
    mov rsi, r12
    mov rdx, r13
    call mem_copy

    mov rdi, r14
    mov rsi, r13
    mov rdx, [rsp]
    call bitflip_apply
    test rax, rax
    jnz .error_stack

    sub rsp, 16
    mov rdi, rbx
    mov rsi, r14
    mov rdx, r13
    mov rcx, rsp
    call execute_target
    mov r11d, [rsp]
    add rsp, 16
    cmp rax, 0
    js .error_stack

    mov edi, r11d
    call wait_status_is_crash
    test rax, rax
    jnz .crash

    inc qword [rsp]
    jmp .loop

.crash:
    mov rdi, r15
    mov rsi, r14
    mov rdx, r13
    call crash_save
    test rax, rax
    js .error_stack
    add rsp, 8
    mov eax, EXIT_CRASH
    jmp .leave

.clean_stack:
    add rsp, 8
.clean:
    xor eax, eax
    jmp .leave

.error_stack:
    add rsp, 8
    mov rax, -1
.leave:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
