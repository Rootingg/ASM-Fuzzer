; Shrink a crashing input without changing its signal.
; The shortest reproducing prefix is kept, then up to MINIMIZE_ATTEMPTS
; single bytes are removed.

%include "constants.inc"

section .text
extern execute_target
extern mem_copy
global minimize_input

; minimize_input - reduce a buffer that already crashes.
; IN:  rdi target, rsi buffer, rdx length, rcx timeout, r8 signal, r9 work buffer
; OUT: rax reduced length
minimize_input:
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
    sub rsp, 16
    mov [rsp], r9
    test r13, r13
    jz .done

    xor ebp, ebp
.prefix:
    cmp rbp, r13
    jae .delete
    mov rax, rbp
    add rax, r13
    shr rax, 1
    cmp rax, r13
    jae .delete
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    mov rcx, r14
    mov r8, r15
    mov [rsp + 8], rax
    call reproduces
    mov rdx, [rsp + 8]
    test rax, rax
    jz .prefix_miss
    mov r13, rdx
    jmp .prefix
.prefix_miss:
    lea rbp, [rdx + 1]
    jmp .prefix

.delete:
    xor ebp, ebp
    mov qword [rsp + 8], 0
.delete_loop:
    cmp rbp, r13
    jae .done
    cmp qword [rsp + 8], MINIMIZE_ATTEMPTS
    jae .done
    inc qword [rsp + 8]
    mov rdi, [rsp]
    mov rsi, r12
    mov rdx, r13
    call mem_copy
    mov rcx, rbp
.shift:
    mov rax, r13
    dec rax
    cmp rcx, rax
    jae .shifted
    mov al, [r12 + rcx + 1]
    mov [r12 + rcx], al
    inc rcx
    jmp .shift
.shifted:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    dec rdx
    mov rcx, r14
    mov r8, r15
    call reproduces
    test rax, rax
    jz .restore
    dec r13
    jmp .delete_loop
.restore:
    mov rdi, r12
    mov rsi, [rsp]
    mov rdx, r13
    call mem_copy
    inc rbp
    jmp .delete_loop

.done:
    mov rax, r13
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; reproduces - execute a prefix and compare its signal.
; IN:  rdi target, rsi buffer, rdx length, rcx timeout, r8 signal
; OUT: rax 1 when the same signal is raised
reproduces:
    push r12
    sub rsp, 16
    mov r12, r8
    lea r8, [rsp]
    call execute_target
    cmp rax, EXIT_CRASH
    jne .no
    mov eax, [rsp]
    and eax, 0x7f
    cmp rax, r12
    jne .no
    mov eax, 1
    jmp .leave
.no:
    xor eax, eax
.leave:
    add rsp, 16
    pop r12
    ret
