; Thin Linux syscall wrappers shared by the loader, executor, and crash writer.

%include "syscalls.inc"

section .text
global sys_openat_cwd
global sys_close
global sys_pipe
global sys_fork
global sys_dup2
global sys_wait4
global sys_execve
global sys_setrlimit
global sys_ignore_sigpipe
global sys_exit
global read_all
global write_all

; sys_openat_cwd - open a path relative to the current directory.
; IN:  rdi path, rsi flags, rdx mode
; OUT: rax file descriptor, or a negative errno
sys_openat_cwd:
    mov r10, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, AT_FDCWD
    mov rax, SYS_openat
    syscall
    ret

; sys_close - close a file descriptor.
; IN:  rdi fd
; OUT: rax 0, or a negative errno
sys_close:
    mov rax, SYS_close
    syscall
    ret

; sys_pipe - create a pipe.
; IN:  rdi pointer to two 32-bit file descriptors
; OUT: rax 0, or a negative errno
sys_pipe:
    mov rax, SYS_pipe
    syscall
    ret

; sys_fork - duplicate the process.
; OUT: rax 0 in the child, child pid in the parent, or a negative errno
sys_fork:
    mov rax, SYS_fork
    syscall
    ret

; sys_dup2 - duplicate a file descriptor.
; IN:  rdi old fd, rsi new fd
; OUT: rax new fd, or a negative errno
sys_dup2:
    mov rax, SYS_dup2
    syscall
    ret

; sys_wait4 - wait for a child to terminate.
; IN:  rdi pid, rsi status pointer, rdx options
; OUT: rax child pid, or a negative errno
sys_wait4:
    xor r10, r10
    mov rax, SYS_wait4
    syscall
    ret

; sys_execve - replace the process image. Does not return on success.
; IN:  rdi path, rsi argv, rdx envp
; OUT: rax negative errno
sys_execve:
    mov rax, SYS_execve
    syscall
    ret

; sys_setrlimit - set a resource limit.
; IN:  rdi resource, rsi pointer to two 64-bit values (soft, hard)
; OUT: rax 0, or a negative errno
sys_setrlimit:
    mov rax, SYS_setrlimit
    syscall
    ret

; sys_ignore_sigpipe - ignore SIGPIPE so a closed pipe returns EPIPE.
; OUT: rax 0, or a negative errno
sys_ignore_sigpipe:
    sub rsp, 32
    mov qword [rsp], SIG_IGN
    mov qword [rsp + 8], 0
    mov qword [rsp + 16], 0
    mov qword [rsp + 24], 0
    mov rax, SYS_rt_sigaction
    mov rdi, SIGPIPE
    mov rsi, rsp
    xor rdx, rdx
    mov r10, SIGSET_SIZE
    syscall
    add rsp, 32
    ret

; sys_exit - terminate this process. Does not return.
; IN:  rdi status
sys_exit:
    mov rax, SYS_exit
    syscall
    hlt

; read_all - read until EOF, a short count, or the buffer is full.
; IN:  rdi fd, rsi buffer, rdx capacity
; OUT: rax bytes read, or -1
read_all:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, edi
    mov r12, rsi
    mov r13, rdx
    xor r14, r14
.loop:
    cmp r14, r13
    jae .done
    mov rax, SYS_read
    mov edi, ebx
    mov rsi, r12
    mov rdx, r13
    sub rdx, r14
    syscall
    cmp rax, 0
    je .done
    js .check
    add r12, rax
    add r14, rax
    jmp .loop
.check:
    cmp rax, -4
    je .loop
    jmp .err
.done:
    mov rax, r14
    jmp .leave
.err:
    mov rax, -1
.leave:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; write_all - write the full buffer.
; IN:  rdi fd, rsi buffer, rdx length
; OUT: rax 0, or -1
write_all:
    push rbx
    push r12
    push r13
    mov ebx, edi
    mov r12, rsi
    mov r13, rdx
.loop:
    test r13, r13
    jz .ok
    mov rax, SYS_write
    mov edi, ebx
    mov rsi, r12
    mov rdx, r13
    syscall
    cmp rax, 0
    je .err
    js .check
    add r12, rax
    sub r13, rax
    jmp .loop
.check:
    cmp rax, -4
    je .loop
    jmp .err
.ok:
    xor eax, eax
    jmp .leave
.err:
    mov rax, -1
.leave:
    pop r13
    pop r12
    pop rbx
    ret
