; Run one target with the candidate input on standard input.
; The parent writes without blocking, watches a wall-clock deadline, and always
; reaps the child. A full pipe or a target stopped in read cannot stall the fuzzer.
; The target is started with execve. No shell is involved.

%include "constants.inc"
%include "syscalls.inc"

section .data
global exec_count
exec_count: dq 0

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
extern sys_write
extern sys_fcntl
extern sys_kill
extern sys_setpgid
extern sys_pidfd_open
extern sys_poll
extern sys_monotonic_ms
extern sys_nanosleep_ms
extern classify_wait_status
extern coverage_reset
extern coverage_drain
extern coverage_finish
extern privilege_lock_child
extern namespace_enter
extern namespace_announce
extern filesystem_enter
extern seccomp_apply
extern close_inherited
extern ns_write_fd
global execute_target

; execute_target - execute a program once.
; IN:  rdi path, rsi input, rdx length, rcx timeout in milliseconds
;      r8 pointer to a 32-bit wait status, or 0
; OUT: rax EXIT_OK, EXIT_CRASH, EXIT_TIMEOUT, EXIT_ERROR, or -1
execute_target:
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
    test r14, r14
    jnz .have_timeout
    mov r14, DEFAULT_TIMEOUT_MS
.have_timeout:
    sub rsp, 96
    mov [rsp + 72], r8
    mov dword [rsp], -1
    mov dword [rsp + 4], -1
    mov dword [rsp + 12], -1
    mov dword [rsp + 80], -1
    mov dword [rsp + 84], -1
    mov dword [rsp + 88], -1
    mov dword [rsp + 92], -1
    call coverage_reset

    mov rdi, rsp
    call sys_pipe
    test rax, rax
    js .fail
    lea rdi, [rsp + 80]
    call sys_pipe
    test rax, rax
    jns .have_cov
    mov dword [rsp + 80], -1
    mov dword [rsp + 84], -1
.have_cov:
    lea rdi, [rsp + 88]
    call sys_pipe
    test rax, rax
    jns .have_ns
    mov dword [rsp + 88], -1
    mov dword [rsp + 92], -1
.have_ns:
    mov eax, [rsp + 92]
    mov [rel ns_write_fd], eax

    call sys_fork
    cmp rax, 0
    js .fail
    je .child

    mov r15, rax
    mov dword [rel ns_write_fd], -1
    mov edi, [rsp + 92]
    cmp edi, 0
    jl .ns_write_closed
    call sys_close
    mov dword [rsp + 92], -1
.ns_write_closed:
    inc qword [rel exec_count]
    mov edi, [rsp]
    call sys_close
    mov dword [rsp], -1

    mov rdi, r15
    mov rsi, r15
    call sys_setpgid
    call sys_ignore_sigpipe

    mov edi, [rsp + 4]
    mov esi, F_SETPIPE_SZ
    mov rdx, PIPE_CAPACITY
    call sys_fcntl

    mov edi, [rsp + 4]
    mov esi, F_GETFL
    xor edx, edx
    call sys_fcntl
    cmp rax, 0
    jl .kill_fail
    mov edx, eax
    or edx, O_NONBLOCK
    mov edi, [rsp + 4]
    mov esi, F_SETFL
    call sys_fcntl
    cmp rax, 0
    jl .kill_fail

    mov rdi, r15
    xor esi, esi
    call sys_pidfd_open
    mov [rsp + 12], eax

    mov edi, [rsp + 84]
    cmp edi, 0
    jl .cov_ready
    call sys_close
    mov dword [rsp + 84], -1
    mov edi, [rsp + 80]
    mov esi, F_GETFL
    xor edx, edx
    call sys_fcntl
    cmp rax, 0
    jl .cov_ready
    mov edx, eax
    or edx, O_NONBLOCK
    mov edi, [rsp + 80]
    mov esi, F_SETFL
    call sys_fcntl
.cov_ready:

    call sys_monotonic_ms
    cmp rax, 0
    jl .kill_fail
    add rax, r14
    mov [rsp + 24], rax
    mov qword [rsp + 16], 0

.supervise:
    mov edi, [rsp + 80]
    call coverage_drain
    mov rax, [rsp + 16]
    cmp rax, r13
    jae .finish_write
    mov edi, [rsp + 4]
    cmp edi, 0
    jl .finish_write
    lea rsi, [r12 + rax]
    mov rdx, r13
    sub rdx, rax
    call sys_write
    cmp rax, 0
    jg .advanced
    cmp rax, EINTR
    je .supervise
    cmp rax, EAGAIN
    je .wait_child
    jmp .finish_write

.advanced:
    add [rsp + 16], rax
    jmp .supervise

.finish_write:
    mov rax, [rsp + 16]
    cmp rax, r13
    jb .wait_child
    mov edi, [rsp + 4]
    cmp edi, 0
    jl .wait_child
    call sys_close
    mov dword [rsp + 4], -1

.wait_child:
    mov rdi, r15
    lea rsi, [rsp + 8]
    mov edx, WNOHANG
    call sys_wait4
    cmp rax, 0
    jg .classify
    cmp rax, EINTR
    je .wait_child
    cmp rax, 0
    jl .kill_fail

    call sys_monotonic_ms
    cmp rax, 0
    jl .kill_fail
    cmp rax, [rsp + 24]
    jae .timed_out

    mov rcx, [rsp + 24]
    sub rcx, rax
    cmp rcx, 50
    jbe .slice_ready
    mov rcx, 50
.slice_ready:
    xor esi, esi
    mov edi, [rsp + 4]
    cmp edi, 0
    jl .add_pidfd
    mov [rsp + 32], edi
    mov word [rsp + 36], POLLOUT
    mov word [rsp + 38], 0
    inc esi
.add_pidfd:
    mov edi, [rsp + 12]
    cmp edi, 0
    jl .wait_ready
    mov eax, esi
    shl eax, 3
    mov [rsp + 32 + rax], edi
    mov word [rsp + 36 + rax], POLLIN
    mov word [rsp + 38 + rax], 0
    inc esi
.wait_ready:
    test esi, esi
    jz .sleep_slice
    lea rdi, [rsp + 32]
    mov rdx, rcx
    call sys_poll
    jmp .supervise

.sleep_slice:
    mov rdi, rcx
    call sys_nanosleep_ms
    jmp .supervise

.classify:
    mov edi, [rsp + 80]
    call coverage_finish
    mov r11, [rsp + 72]
    test r11, r11
    jz .classify_call
    mov eax, [rsp + 8]
    mov [r11], eax
.classify_call:
    mov edi, [rsp + 8]
    call classify_wait_status
    jmp .cleanup

.timed_out:
    mov rdi, r15
    neg rdi
    mov esi, SIGKILL
    call sys_kill
    mov rdi, r15
    mov esi, SIGKILL
    call sys_kill
.reap_timeout:
    mov rdi, r15
    lea rsi, [rsp + 8]
    xor edx, edx
    call sys_wait4
    cmp rax, EINTR
    je .reap_timeout
    mov edi, [rsp + 80]
    call coverage_finish
    mov r11, [rsp + 72]
    test r11, r11
    jz .timeout_code
    mov eax, [rsp + 8]
    mov [r11], eax
.timeout_code:
    mov eax, EXIT_TIMEOUT
    jmp .cleanup

.kill_fail:
    mov rdi, r15
    neg rdi
    mov esi, SIGKILL
    call sys_kill
    mov rdi, r15
    mov esi, SIGKILL
    call sys_kill
.reap_fail:
    mov rdi, r15
    lea rsi, [rsp + 8]
    xor edx, edx
    call sys_wait4
    cmp rax, EINTR
    je .reap_fail
.fail:
    mov r11, [rsp + 72]
    test r11, r11
    jz .fail_code
    mov dword [r11], 0
.fail_code:
    mov rax, -1
    jmp .cleanup

.child:
    xor edi, edi
    xor esi, esi
    call sys_setpgid
    call namespace_enter
    mov rdi, rbx
    call filesystem_enter
    mov rbx, rax
    mov edi, [rsp + 4]
    call sys_close
    mov edi, [rsp]
    xor esi, esi
    call sys_dup2
    cmp rax, 0
    jl .child_fail
    mov edi, [rsp]
    test edi, edi
    jz .cov_child
    call sys_close

.cov_child:
    mov edi, [rsp + 84]
    cmp edi, 0
    jl .limits
    mov esi, COV_FD
    call sys_dup2
    cmp rax, 0
    jl .cov_close
    mov edi, COV_FD
    mov esi, F_GETFL
    xor edx, edx
    call sys_fcntl
    cmp rax, 0
    jl .cov_close
    mov edx, eax
    or edx, O_NONBLOCK
    mov edi, COV_FD
    mov esi, F_SETFL
    call sys_fcntl
.cov_close:
    mov edi, [rsp + 80]
    cmp edi, 0
    jl .cov_close_write
    call sys_close
.cov_close_write:
    mov edi, [rsp + 84]
    cmp edi, COV_FD
    je .limits
    cmp edi, 0
    jl .limits
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

    call privilege_lock_child
    test rax, rax
    js .child_fail
    call seccomp_apply
    call close_inherited
    test rax, rax
    js .child_fail

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

.cleanup:
    mov rbp, rax
    mov edi, [rsp + 4]
    cmp edi, 0
    jl .close_read
    call sys_close
.close_read:
    mov edi, [rsp]
    cmp edi, 0
    jl .close_pidfd
    call sys_close
.close_pidfd:
    mov edi, [rsp + 12]
    cmp edi, 0
    jl .close_cov_read
    call sys_close
.close_cov_read:
    mov edi, [rsp + 80]
    cmp edi, 0
    jl .close_cov_write
    call sys_close
.close_cov_write:
    mov edi, [rsp + 84]
    cmp edi, 0
    jl .close_ns_write
    call sys_close
.close_ns_write:
    mov edi, [rsp + 92]
    cmp edi, 0
    jl .announce_ns
    call sys_close
.announce_ns:
    mov edi, [rsp + 88]
    call namespace_announce
    mov edi, [rsp + 88]
    cmp edi, 0
    jl .restore
    call sys_close
.restore:
    mov rax, rbp
    add rsp, 96
.leave:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
