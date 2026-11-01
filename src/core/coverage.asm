; Edge bitmap shared by one fuzzer process.
; Instrumented targets write 16-bit ids to the coverage pipe.

%include "syscalls.inc"

%define EDGE_MAX 256

section .bss
seen: resb EDGE_MAX
run_seen: resb EDGE_MAX

section .data
global coverage_total
global coverage_last_new
coverage_total: dq 0
coverage_last_new: dq 0

section .text
global coverage_reset
global coverage_drain
global coverage_commit

; coverage_reset - forget the edges observed by the previous execution.
coverage_reset:
    push rdi
    lea rdi, [rel run_seen]
    mov rcx, EDGE_MAX
    xor eax, eax
    rep stosb
    mov qword [rel coverage_last_new], 0
    pop rdi
    ret

; coverage_note - record one edge id for this execution.
; IN:  edi id
coverage_note:
    cmp edi, EDGE_MAX
    jae .ignore
    lea rax, [rel run_seen]
    cmp byte [rax + rdi], 0
    jne .ignore
    mov byte [rax + rdi], 1
    lea rax, [rel seen]
    cmp byte [rax + rdi], 0
    jne .ignore
    inc qword [rel coverage_last_new]
.ignore:
    ret

; coverage_drain - read edge ids available on a non-blocking descriptor.
; IN:  edi file descriptor, or negative when coverage is disabled
coverage_drain:
    push rbx
    mov ebx, edi
    cmp ebx, 0
    jl .done
.loop:
    sub rsp, 16
    mov eax, SYS_read
    mov edi, ebx
    mov rsi, rsp
    mov edx, 2
    syscall
    cmp rax, 2
    jne .stop
    movzx edi, word [rsp]
    call coverage_note
    add rsp, 16
    jmp .loop
.stop:
    add rsp, 16
.done:
    pop rbx
    ret

; coverage_commit - publish this execution's new edges.
; OUT: rax number of edges seen for the first time
coverage_commit:
    push rbx
    push r12
    push r13
    xor ebx, ebx
    lea r12, [rel run_seen]
    lea r13, [rel seen]
.scan:
    cmp byte [r12 + rbx], 0
    je .next
    cmp byte [r13 + rbx], 0
    jne .next
    mov byte [r13 + rbx], 1
    inc qword [rel coverage_total]
.next:
    inc rbx
    cmp rbx, EDGE_MAX
    jb .scan
    mov rax, [rel coverage_last_new]
    pop r13
    pop r12
    pop rbx
    ret
