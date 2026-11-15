; Refuse to fuzz as root, drop capabilities, and lock the child with no_new_privs.
; Namespaces, a private filesystem, and seccomp are separate steps.

%include "constants.inc"
%include "syscalls.inc"

section .text
global privilege_blocked
global privilege_guard
global privilege_lock_child
global close_inherited

; privilege_blocked - report whether these ids must not run the fuzzer.
; IN:  rdi uid, rsi euid, rdx gid, rcx egid
; OUT: rax 1 when any id is root
privilege_blocked:
    test rdi, rdi
    jz .yes
    test rsi, rsi
    jz .yes
    test rdx, rdx
    jz .yes
    test rcx, rcx
    jz .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

; privilege_guard - refuse root and drop capabilities in the fuzzer.
; no_new_privs stays off here. The child sets it after creating namespaces,
; because that flag makes CLONE_NEWUSER fail.
; OUT: rax 0, or -1
privilege_guard:
    push rbx
    push r12
    push r13
    mov eax, SYS_getuid
    syscall
    mov rbx, rax
    mov eax, SYS_geteuid
    syscall
    mov r12, rax
    mov eax, SYS_getgid
    syscall
    mov r13, rax
    mov eax, SYS_getegid
    syscall
    mov rcx, rax
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call privilege_blocked
    test rax, rax
    jnz .deny
    call drop_capabilities
    test rax, rax
    js .deny
    xor eax, eax
    jmp .leave
.deny:
    mov rax, -1
.leave:
    pop r13
    pop r12
    pop rbx
    ret

; privilege_lock_child - drop privileges in the process image that calls execve.
; Inherited descriptors stay open so the caller can still report, then close them.
; OUT: rax 0, or -1
privilege_lock_child:
    call set_no_new_privs
    test rax, rax
    js .fail
    call drop_capabilities
    test rax, rax
    js .fail
    xor eax, eax
    ret
.fail:
    mov rax, -1
    ret

; set_no_new_privs - exec of a setuid file must not raise privileges.
; OUT: rax 0, or a negative errno
set_no_new_privs:
    mov eax, SYS_prctl
    mov edi, PR_SET_NO_NEW_PRIVS
    mov esi, 1
    xor edx, edx
    xor r10, r10
    xor r8, r8
    syscall
    ret

; drop_capabilities - clear the effective, permitted, and inheritable sets.
; OUT: rax 0, or a negative errno
drop_capabilities:
    sub rsp, 48
    xor eax, eax
    mov [rsp], rax
    mov [rsp + 8], rax
    mov [rsp + 16], rax
    mov [rsp + 24], rax
    mov dword [rsp], CAP_VERSION_3
    mov dword [rsp + 4], 0
    mov eax, SYS_capset
    mov rdi, rsp
    lea rsi, [rsp + 8]
    syscall
    test rax, rax
    jns .ok
    mov dword [rsp], CAP_VERSION_1
    mov eax, SYS_capset
    mov rdi, rsp
    lea rsi, [rsp + 8]
    syscall
.ok:
    add rsp, 48
    ret

; close_inherited - close every descriptor above the coverage pipe.
; OUT: rax 0, or a negative errno
close_inherited:
    push rbx
    mov eax, SYS_close_range
    mov edi, COV_FD + 1
    mov esi, -1
    xor edx, edx
    syscall
    test rax, rax
    jns .ok
    cmp rax, ENOSYS
    jne .fail
    mov ebx, COV_FD + 1
.loop:
    cmp ebx, 256
    jae .ok
    mov eax, SYS_close
    mov edi, ebx
    syscall
    inc ebx
    jmp .loop
.ok:
    xor eax, eax
    jmp .leave
.fail:
.leave:
    pop rbx
    ret
