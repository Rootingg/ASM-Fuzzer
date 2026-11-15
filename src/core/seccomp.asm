; Allow the syscalls the in-repo targets use, and kill any other with SIGSYS.
; no_new_privs is already set. If the kernel rejects the filter, the target still runs.

%include "syscalls.inc"

%define BPF_LDW  0x20
%define BPF_JEQ  0x15
%define BPF_RET  0x06
%define AUDIT_ARCH_X86_64 0xC000003E
%define SECCOMP_RET_KILL_PROCESS 0x80000000
%define SECCOMP_RET_ALLOW 0x7fff0000
%define SECCOMP_SET_MODE_FILTER 1

%macro BPF 4
    dw %1
    db %2
    db %3
    dd %4
%endmacro

section .rodata
; Offsets are from the next instruction. The allow return sits after the default kill.
filter:
    BPF BPF_LDW, 0, 0, 4
    BPF BPF_JEQ, 1, 0, AUDIT_ARCH_X86_64
    BPF BPF_RET, 0, 0, SECCOMP_RET_KILL_PROCESS
    BPF BPF_LDW, 0, 0, 0
    BPF BPF_JEQ, 14, 0, SYS_read
    BPF BPF_JEQ, 13, 0, SYS_write
    BPF BPF_JEQ, 12, 0, SYS_close
    BPF BPF_JEQ, 11, 0, SYS_rt_sigreturn
    BPF BPF_JEQ, 10, 0, SYS_pause
    BPF BPF_JEQ, 9, 0, SYS_getpid
    BPF BPF_JEQ, 8, 0, SYS_execve
    BPF BPF_JEQ, 7, 0, SYS_exit
    BPF BPF_JEQ, 6, 0, SYS_fcntl
    BPF BPF_JEQ, 5, 0, SYS_capget
    BPF BPF_JEQ, 4, 0, SYS_prctl
    BPF BPF_JEQ, 3, 0, SYS_openat
    BPF BPF_JEQ, 2, 0, SYS_exit_group
    BPF BPF_JEQ, 1, 0, SYS_close_range
    BPF BPF_RET, 0, 0, SECCOMP_RET_KILL_PROCESS
    BPF BPF_RET, 0, 0, SECCOMP_RET_ALLOW
filter_end:
filter_len equ (filter_end - filter) / 8

%if filter_end - filter != 20 * 8
%error "seccomp filter is not packed"
%endif

msg_on: db "seccomp on", 10
msg_on_len equ $ - msg_on
msg_none: db "seccomp none", 10
msg_none_len equ $ - msg_none

section .data
seccomp_seen: db 0

section .text
global seccomp_apply
global seccomp_report
extern ns_write_fd

; seccomp_apply - install the allowlist. The caller still execs either way.
; OUT: rax 0
seccomp_apply:
    sub rsp, 16
    mov word [rsp], filter_len
    lea rax, [rel filter]
    mov [rsp + 8], rax
    mov eax, SYS_seccomp
    mov edi, SECCOMP_SET_MODE_FILTER
    xor esi, esi
    mov rdx, rsp
    syscall
    add rsp, 16
    xor edi, edi
    test rax, rax
    js .note
    mov edi, 1
.note:
    call note_seccomp
    xor eax, eax
    ret

; seccomp_report - print the seccomp mode once per campaign.
; IN:  edi 0 when the filter was not installed, 1 when it was
seccomp_report:
    cmp byte [rel seccomp_seen], 0
    jne .done
    mov byte [rel seccomp_seen], 1
    lea rsi, [rel msg_none]
    mov edx, msg_none_len
    test edi, edi
    jz .write
    lea rsi, [rel msg_on]
    mov edx, msg_on_len
.write:
    mov eax, SYS_write
    mov edi, 2
    syscall
.done:
    ret

; note_seccomp - send one mode byte and close the status pipe.
; IN:  edi 0 none, 1 on
note_seccomp:
    mov eax, edi
    mov edi, [rel ns_write_fd]
    cmp edi, 0
    jl .done
    sub rsp, 16
    mov [rsp], al
    mov rsi, rsp
    mov edx, 1
    mov eax, SYS_write
    syscall
    add rsp, 16
    mov edi, [rel ns_write_fd]
    mov eax, SYS_close
    syscall
    mov dword [rel ns_write_fd], -1
.done:
    ret
