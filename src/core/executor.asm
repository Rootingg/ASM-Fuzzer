; Run one target with the candidate input on standard input.
; The target is started with execve. No shell is involved.
; CPU time, address space, and file size are limited in the child.

%include "constants.inc"
%include "syscalls.inc"

section .text
extern sys_pipe
extern sys_fork
extern sys_close
extern sys_dup2
extern sys_wait4
extern sys_execve
extern sys_setrlimit
extern sys_ignore_sigpipe
extern sys_exit
extern write_all
global execute_target

; execute_target - execute a program once.
; IN:  rdi path, rsi input, rdx length, rcx pointer to a 32-bit wait status
; OUT: rax 0 and *rcx = wait status, or rax -1 when the run could not be started
execute_target:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r15, rcx

    sub rsp, 16
    mov rdi, rsp
    call sys_pipe
    test rax, rax
    js .fail

    call sys_fork
    cmp rax, 0
    js .fail_close_both
    je .child

    mov r14, rax
    mov edi, [rsp]
    call sys_close
    call sys_ignore_sigpipe

    mov edi, [rsp + 4]
    mov rsi, r12
    mov rdx, r13
    call write_all
    mov r12, rax

    mov edi, [rsp + 4]
    call sys_close

    mov rdi, r14
    lea rsi, [rsp + 8]
    xor edx, edx
    call sys_wait4
    test rax, rax
    js .fail
    cmp r12, 0
    jne .fail

    mov eax, [rsp + 8]
    mov [r15], eax
    xor eax, eax
    add rsp, 16
    jmp .leave

.child:
    mov edi, [rsp + 4]
    call sys_close
    mov edi, [rsp]
    xor esi, esi
    call sys_dup2
    test rax, rax
    js .child_fail
    mov edi, [rsp]
    test edi, edi
    jz .limits
    call sys_close

.limits:
    sub rsp, 16
    mov qword [rsp], TARGET_CPU_SECONDS
    mov qword [rsp + 8], TARGET_CPU_SECONDS
    mov edi, RLIMIT_CPU
    mov rsi, rsp
    call sys_setrlimit
    mov qword [rsp], TARGET_ADDRESS_SPACE
    mov qword [rsp + 8], TARGET_ADDRESS_SPACE
    mov edi, RLIMIT_AS
    mov rsi, rsp
    call sys_setrlimit
    mov qword [rsp], TARGET_FILE_SIZE
    mov qword [rsp + 8], TARGET_FILE_SIZE
    mov edi, RLIMIT_FSIZE
    mov rsi, rsp
    call sys_setrlimit
    add rsp, 16

    sub rsp, 24
    mov [rsp], rbx
    mov qword [rsp + 8], 0
    mov qword [rsp + 16], 0
    mov rdi, rbx
    mov rsi, rsp
    lea rdx, [rsp + 16]
    call sys_execve

.child_fail:
    mov edi, 127
    call sys_exit

.fail_close_both:
    mov edi, [rsp]
    call sys_close
    mov edi, [rsp + 4]
    call sys_close
.fail:
    mov rax, -1
    add rsp, 16
.leave:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
