; Put the target in user, mount, PID, and network namespaces when the kernel allows it.
; no_new_privs is applied later: it would make CLONE_NEWUSER fail with EPERM.
; If the first unshare is refused, the target still runs and the mode is reported.

%include "syscalls.inc"

%define CLONE_NEWNS   0x00020000
%define CLONE_NEWPID  0x20000000
%define CLONE_NEWNET  0x40000000
%define CLONE_NEWUSER 0x10000000
%define MS_REC        0x4000
%define MS_PRIVATE    0x40000
%define NS_USER       1
%define NS_NET        2
%define NS_MNT        4
%define NS_PID        8
%define NS_FULL       15

section .rodata
msg_full: db "namespaces full", 10
msg_full_len equ $ - msg_full
msg_partial: db "namespaces partial", 10
msg_partial_len equ $ - msg_partial
msg_none: db "namespaces none", 10
msg_none_len equ $ - msg_none
path_setgroups: db "/proc/self/setgroups", 0
path_uid: db "/proc/self/uid_map", 0
path_gid: db "/proc/self/gid_map", 0
text_deny: db "deny", 10
root_path: db "/", 0

section .data
global ns_write_fd
ns_write_fd: dd -1
ns_seen: db 0
ns_mode: db 0

section .text
global namespace_enter
global namespace_announce
global ns_mode
extern filesystem_report

; namespace_enter - isolate the caller, or report that isolation is unavailable.
; OUT: rax 0 in the process that must exec. The PID-namespace waiter does not return.
namespace_enter:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov eax, SYS_geteuid
    syscall
    mov r12, rax
    mov eax, SYS_getegid
    syscall
    mov r13, rax

    mov eax, SYS_unshare
    mov rdi, CLONE_NEWUSER | CLONE_NEWNS | CLONE_NEWNET
    syscall
    test rax, rax
    jns .created
    xor ebx, ebx
    call report_mode
    xor eax, eax
    jmp .leave

.created:
    mov ebx, NS_USER | NS_NET | NS_MNT
    mov rdi, r12
    mov rsi, r13
    call write_id_maps
    test rax, rax
    js .broken
    call make_mounts_private
    test rax, rax
    jns .pid
    and ebx, ~NS_MNT

.pid:
    mov eax, SYS_unshare
    mov edi, CLONE_NEWPID
    syscall
    test rax, rax
    js .report
    or ebx, NS_PID
    call report_mode
    mov eax, SYS_fork
    syscall
    test rax, rax
    js .broken
    jnz .wait_target
    xor eax, eax
    jmp .leave

.report:
    call report_mode
    xor eax, eax
.leave:
    mov [rel ns_mode], bl
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.wait_target:
    mov r14, rax
    mov eax, SYS_wait4
    mov rdi, r14
    sub rsp, 16
    mov rsi, rsp
    xor edx, edx
    xor r10, r10
    syscall
    mov eax, [rsp]
    add rsp, 16
    mov r12d, eax
    and eax, 0x7f
    jz .forward_exit
    cmp eax, 0x7f
    je .forward_exit
    mov r13d, eax
    mov eax, SYS_getpid
    syscall
    mov edi, eax
    mov esi, r13d
    mov eax, SYS_kill
    syscall
    mov edi, r13d
    add edi, 128
    mov eax, SYS_exit
    syscall

.forward_exit:
    mov eax, r12d
    shr eax, 8
    and eax, 0xff
    mov edi, eax
    mov eax, SYS_exit
    syscall

.broken:
    mov edi, 127
    mov eax, SYS_exit
    syscall

; report_mode - send one mode byte to the parent.
; IN:  ebx mode bits. 0 means no namespace was created.
report_mode:
    mov edi, [rel ns_write_fd]
    cmp edi, 0
    jl .done
    sub rsp, 16
    mov [rsp], bl
    mov eax, SYS_write
    mov rsi, rsp
    mov edx, 1
    syscall
    add rsp, 16
.done:
    ret

; namespace_announce - print the mode once for the whole campaign.
; IN:  edi read end of the status pipe, or -1
namespace_announce:
    cmp edi, 0
    jl .done
    push rbx
    sub rsp, 16
    mov eax, SYS_read
    mov rsi, rsp
    mov edx, 2
    syscall
    cmp rax, 1
    jl .leave
    mov qword [rsp + 8], rax
    cmp byte [rel ns_seen], 0
    jne .fs_byte
    mov byte [rel ns_seen], 1
    movzx ebx, byte [rsp]
    lea rsi, [rel msg_none]
    mov edx, msg_none_len
    test ebx, ebx
    jz .write
    lea rsi, [rel msg_partial]
    mov edx, msg_partial_len
    cmp ebx, NS_FULL
    jne .write
    lea rsi, [rel msg_full]
    mov edx, msg_full_len
.write:
    call write_stderr
.fs_byte:
    cmp qword [rsp + 8], 2
    jl .leave
    movzx edi, byte [rsp + 1]
    call filesystem_report
.leave:
    add rsp, 16
    pop rbx
.done:
    ret

; write_id_maps - map the caller's ids into the new user namespace.
; IN:  rdi uid, rsi gid
; OUT: rax 0, or -1
write_id_maps:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    lea rdi, [rel path_setgroups]
    lea rsi, [rel text_deny]
    mov edx, 5
    call write_file
    test rax, rax
    js .fail
    sub rsp, 64
    mov rdi, r12
    mov rsi, rsp
    call format_id_map
    mov rdx, rax
    lea rdi, [rel path_uid]
    mov rsi, rsp
    call write_file
    mov rbx, rax
    mov rdi, r13
    mov rsi, rsp
    call format_id_map
    mov rdx, rax
    lea rdi, [rel path_gid]
    mov rsi, rsp
    call write_file
    mov r12, rax
    add rsp, 64
    test rbx, rbx
    js .fail
    test r12, r12
    js .fail
    xor eax, eax
    jmp .leave
.fail:
    mov rax, -1
.leave:
    pop r13
    pop r12
    pop rbx
    ret

; format_id_map - write "id id 1\n".
; IN:  rdi id, rsi destination
; OUT: rax length
format_id_map:
    push rbx
    push r12
    mov r12, rsi
    mov rax, rdi
    lea rcx, [rsi + 16]
    mov byte [rcx], 0
.digits:
    xor edx, edx
    mov ebx, 10
    div rbx
    add dl, "0"
    dec rcx
    mov [rcx], dl
    test rax, rax
    jnz .digits
    mov rbx, rcx
    mov rdi, r12
.copy1:
    mov al, [rbx]
    mov [rdi], al
    inc rdi
    inc rbx
    cmp al, 0
    jne .copy1
    dec rdi
    mov byte [rdi], " "
    inc rdi
    mov rbx, rcx
.copy2:
    mov al, [rbx]
    mov [rdi], al
    inc rdi
    inc rbx
    cmp al, 0
    jne .copy2
    dec rdi
    mov byte [rdi], " "
    mov byte [rdi + 1], "1"
    mov byte [rdi + 2], 10
    add rdi, 3
    mov rax, rdi
    sub rax, r12
    pop r12
    pop rbx
    ret

; make_mounts_private - stop mount changes from propagating to the parent.
; OUT: rax 0, or a negative errno
make_mounts_private:
    mov eax, SYS_mount
    xor edi, edi
    lea rsi, [rel root_path]
    xor edx, edx
    mov r10d, MS_REC | MS_PRIVATE
    xor r8, r8
    syscall
    ret

; write_file - overwrite a file with one buffer.
; IN:  rdi path, rsi bytes, rdx length
; OUT: rax 0, or -1
write_file:
    push rbx
    push r12
    push r13
    mov r12, rsi
    mov r13, rdx
    mov eax, SYS_openat
    mov rsi, rdi
    mov edi, AT_FDCWD
    mov edx, O_WRONLY
    xor r10, r10
    syscall
    test rax, rax
    js .fail
    mov ebx, eax
    mov eax, SYS_write
    mov edi, ebx
    mov rsi, r12
    mov rdx, r13
    syscall
    mov r12, rax
    mov eax, SYS_close
    mov edi, ebx
    syscall
    test r12, r12
    js .fail
    xor eax, eax
    jmp .leave
.fail:
    mov rax, -1
.leave:
    pop r13
    pop r12
    pop rbx
    ret

; write_stderr - write one fixed message.
; IN:  rsi bytes, rdx length
write_stderr:
    push rax
    push rdi
    mov eax, SYS_write
    mov edi, 2
    syscall
    pop rdi
    pop rax
    ret
