; Each trial copies the seed and applies one mutation.
; Without a seed the schedule is deterministic. With a seed it is xorshift64.
; Crashes are kept once per signal. The first crash stops the run unless
; the caller asked to continue.

%include "constants.inc"

section .text
extern mem_copy
extern apply_mutation
extern execute_target
extern crash_save
extern crash_name
extern minimize_input
global fuzz_campaign

; fuzz_campaign - run one campaign.
; IN:  rdi pointer to the campaign record:
;        +0  target path
;        +8  seed bytes
;        +16 length
;        +24 scratch
;        +32 output path (file, or directory when continuing)
;        +40 timeout milliseconds
;        +48 iterations
;        +56 stop on crash (1 or 0)
;        +64 RNG seed (0 selects the deterministic schedule)
;        +72 path buffer for crash filenames
;        +80 signal mask, updated in place
;        +88 work buffer used to minimize a crash
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
    mov r8, [rdi + 64]
    mov r9, [rdi + 72]
    mov r10, [rdi + 80]
    mov r11, [rdi + 88]
    mov rbp, rdi
    test rcx, rcx
    jz .bad

    sub rsp, 112
    mov qword [rsp], 0
    mov [rsp + 8], rcx
    mov [rsp + 16], rax
    mov [rsp + 24], rdx
    mov qword [rsp + 32], 0
    mov qword [rsp + 40], 0
    mov [rsp + 48], r10
    mov [rsp + 56], r8
    mov [rsp + 72], r9
    mov [rsp + 80], r11
    mov [rsp + 88], rbp

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
    lea rcx, [rsp + 56]
    call apply_mutation
    test rax, rax
    jnz .bad_stack

.run:
    mov rdi, rbx
    mov rsi, r14
    mov rdx, r13
    mov rcx, [rsp + 16]
    lea r8, [rsp + 64]
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
    mov eax, [rsp + 64]
    and eax, 0x7f
    cmp qword [rsp + 24], 0
    jne .save_file
    cmp eax, 63
    ja .save_named
    mov cl, al
    mov r11, 1
    shl r11, cl
    test [rsp + 48], r11
    jnz .after_save
    or [rsp + 48], r11
.save_named:
    mov rdi, r15
    mov esi, eax
    mov rdx, [rsp]
    mov rcx, [rsp + 72]
    mov r8, 512
    call crash_name
    test rax, rax
    jnz .bad_stack
    mov rdi, [rsp + 72]
    jmp .write_crash

.save_file:
    mov rdi, r15
.write_crash:
    mov [rsp + 96], rdi
    mov eax, [rsp + 64]
    and eax, 0x7f
    mov rdi, rbx
    mov rsi, r14
    mov rdx, r13
    mov rcx, [rsp + 16]
    mov r8d, eax
    mov r9, [rsp + 80]
    call minimize_input
    mov rdx, rax
    mov rdi, [rsp + 96]
    mov rsi, r14
    call crash_save
    test rax, rax
    jnz .bad_stack
    inc qword [rsp + 40]
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
    mov rdi, [rsp + 88]
    mov rcx, [rsp + 48]
    mov [rdi + 80], rcx
    add rsp, 112
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
