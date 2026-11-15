; Persist the exact input that made a target fault.

%include "syscalls.inc"

section .text
extern sys_openat_cwd
extern sys_close
extern write_all
global crash_save

; crash_save - create or replace a crash file with the mutated input.
; IN:  rdi path, rsi buffer, rdx length
; OUT: rax 0, or -1
crash_save:
    push rbx
    push r12
    push r13
    mov r12, rsi
    mov r13, rdx
    mov rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, MODE_644
    call sys_openat_cwd
    cmp rax, 0
    js .fail
    mov ebx, eax
    mov edi, ebx
    mov rsi, r12
    mov rdx, r13
    call write_all
    mov r12, rax
    mov edi, ebx
    call sys_close
    cmp r12, 0
    jne .fail
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret
