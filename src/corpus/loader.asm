; Load one corpus file into a caller-provided buffer.

%include "syscalls.inc"

section .text
extern sys_openat_cwd
extern sys_close
extern read_all
global corpus_load

; corpus_load - read a file, stopping at capacity.
; IN:  rdi path, rsi buffer, rdx capacity
; OUT: rax bytes stored, or -1
corpus_load:
    push rbx
    push r12
    push r13
    mov r12, rsi
    mov r13, rdx
    xor esi, esi
    xor edx, edx
    call sys_openat_cwd
    cmp rax, 0
    js .fail
    mov ebx, eax
    mov edi, ebx
    mov rsi, r12
    mov rdx, r13
    call read_all
    mov r12, rax
    mov edi, ebx
    call sys_close
    cmp r12, 0
    js .fail
    mov rax, r12
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
