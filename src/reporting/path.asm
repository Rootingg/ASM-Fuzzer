; Build crash filenames inside an existing directory: sig<signal>-<trial>.

default rel

section .rodata
prefix: db "sig", 0

section .text
global crash_name

; crash_name - write a NUL-terminated path.
; IN:  rdi directory, rsi signal, rdx trial, rcx destination, r8 capacity
; OUT: rax 0, or -1 when the path does not fit
crash_name:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rcx
    lea r13, [rcx + r8]
    mov rbx, rdi
    mov r14, rsi
    mov r15, rdx

.copy_dir:
    mov al, [rbx]
    test al, al
    jz .maybe_slash
    cmp r12, r13
    jae .overflow
    mov [r12], al
    inc r12
    inc rbx
    jmp .copy_dir

.maybe_slash:
    cmp r12, rcx
    je .prefix
    cmp byte [r12 - 1], "/"
    je .prefix
    cmp r12, r13
    jae .overflow
    mov byte [r12], "/"
    inc r12

.prefix:
    lea rbx, [rel prefix]
.copy_prefix:
    mov al, [rbx]
    test al, al
    jz .signal
    cmp r12, r13
    jae .overflow
    mov [r12], al
    inc r12
    inc rbx
    jmp .copy_prefix

.signal:
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call append_u64
    test rax, rax
    jz .overflow
    mov r12, rax
    cmp r12, r13
    jae .overflow
    mov byte [r12], "-"
    inc r12
    mov rdi, r12
    mov rsi, r13
    mov rdx, r15
    call append_u64
    test rax, rax
    jz .overflow
    mov r12, rax
    cmp r12, r13
    jae .overflow
    mov byte [r12], 0
    xor eax, eax
    jmp .leave

.overflow:
    mov rax, -1
.leave:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; append_u64 - write an unsigned decimal value.
; IN:  rdi cursor, rsi end, rdx value
; OUT: rax new cursor, or 0 on overflow
append_u64:
    push rbx
    sub rsp, 32
    mov rbx, rdi
    mov r8, rsi
    mov rax, rdx
    lea rcx, [rsp + 32]
.digits:
    xor edx, edx
    mov r9, 10
    div r9
    add dl, "0"
    dec rcx
    mov [rcx], dl
    test rax, rax
    jnz .digits
.copy:
    cmp rbx, r8
    jae .bad
    mov al, [rcx]
    mov [rbx], al
    inc rbx
    inc rcx
    lea r9, [rsp + 32]
    cmp rcx, r9
    jb .copy
    mov rax, rbx
    jmp .done
.bad:
    xor eax, eax
.done:
    add rsp, 32
    pop rbx
    ret
