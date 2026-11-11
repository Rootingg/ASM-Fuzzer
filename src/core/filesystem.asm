; Hide the host filesystem behind a tmpfs that contains only the target binary.
; The mount namespace must already be private. Failure keeps the host view.

%include "syscalls.inc"

%define FS_MNT     4
%define MS_NOSUID  2
%define MS_NODEV   4
%define MNT_DETACH 2
%define MODE_755   493
%define COPY_CHUNK 4096

section .rodata
tmpfs_src: db "tmpfs", 0
tmpfs_opts: db "mode=755,size=8388608", 0
path_root: db "/", 0
path_dot: db ".", 0
path_exec: db "/target", 0
base0: db "/mnt", 0
base1: db "/run", 0
base2: db "/dev/shm", 0
base3: db "/var/tmp", 0
base4: db "/tmp", 0
jail0: db "/mnt/jail", 0
jail1: db "/run/jail", 0
jail2: db "/dev/shm/jail", 0
jail3: db "/var/tmp/jail", 0
jail4: db "/tmp/jail", 0
file0: db "/mnt/jail/target", 0
file1: db "/run/jail/target", 0
file2: db "/dev/shm/jail/target", 0
file3: db "/var/tmp/jail/target", 0
file4: db "/tmp/jail/target", 0
msg_hidden: db "filesystem hidden", 10
msg_hidden_len equ $ - msg_hidden
msg_host: db "filesystem host", 10
msg_host_len equ $ - msg_host

section .data
fs_seen: db 0

section .text
global filesystem_enter
global filesystem_report
extern ns_mode
extern ns_write_fd

; filesystem_enter - switch to a one-file root, or keep the host view.
; IN:  rdi target path
; OUT: rax path that execve must use
filesystem_enter:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, -1
    mov r14, -1
    xor ebx, ebx
    xor r15, r15
    test byte [rel ns_mode], FS_MNT
    jz .host

    mov eax, SYS_openat
    mov rsi, rdi
    mov edi, AT_FDCWD
    xor edx, edx
    xor r10, r10
    syscall
    test rax, rax
    js .host
    mov r13, rax

    call mount_scratch
    test rax, rax
    js .host
    or ebx, 1
    call path_jail
    mov rdi, rsi
    call mkdir_path
    test rax, rax
    js .undo
    call path_jail
    call mount_tmpfs
    test rax, rax
    js .undo
    or ebx, 2
    call path_file
    mov rdi, rsi
    call create_file
    test rax, rax
    js .undo
    mov r14, rax
    mov edi, r14d
    mov esi, MODE_755
    mov eax, SYS_fchmod
    syscall
    sub rsp, COPY_CHUNK
    call copy_binary
    mov r8, rax
    add rsp, COPY_CHUNK
    test r8, r8
    js .undo
    call close_pair
    call path_jail
    mov rdi, rsi
    mov eax, SYS_chdir
    syscall
    test rax, rax
    js .undo
    or ebx, 4
    lea rdi, [rel path_dot]
    lea rsi, [rel path_dot]
    mov eax, SYS_pivot_root
    syscall
    test rax, rax
    jns .detach
    lea rdi, [rel path_dot]
    mov eax, SYS_chroot
    syscall
    test rax, rax
    jns .hidden
    jmp .undo

.detach:
    lea rdi, [rel path_dot]
    mov esi, MNT_DETACH
    mov eax, SYS_umount2
    syscall
    test rax, rax
    js .undo
.hidden:
    lea rdi, [rel path_root]
    mov eax, SYS_chdir
    syscall
    mov edi, 1
    call note_fs
    lea rax, [rel path_exec]
    jmp .leave

.undo:
    call undo_mounts
.host:
    call close_pair
    xor edi, edi
    call note_fs
    mov rax, r12
.leave:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; filesystem_report - print the filesystem mode once per campaign.
; IN:  edi 0 for the host view, 1 when the root was replaced
filesystem_report:
    cmp byte [rel fs_seen], 0
    jne .done
    mov byte [rel fs_seen], 1
    lea rsi, [rel msg_host]
    mov edx, msg_host_len
    test edi, edi
    jz .write
    lea rsi, [rel msg_hidden]
    mov edx, msg_hidden_len
.write:
    mov eax, SYS_write
    mov edi, 2
    syscall
.done:
    ret

; mount_scratch - mount a private tmpfs on the first usable base.
; IN:  r15 zero. OUT: rax 0 and r15 index, or rax -1
mount_scratch:
    xor r15, r15
.try:
    call path_base
    call mount_tmpfs
    test rax, rax
    jns .ok
    inc r15
    cmp r15, 5
    jl .try
    mov rax, -1
    ret
.ok:
    xor eax, eax
    ret

; mount_tmpfs - mount a nosuid, nodev tmpfs.
; IN:  rsi path. OUT: rax 0, or a negative errno
mount_tmpfs:
    mov eax, SYS_mount
    lea rdi, [rel tmpfs_src]
    lea rdx, [rel tmpfs_src]
    mov r10d, MS_NOSUID | MS_NODEV
    lea r8, [rel tmpfs_opts]
    syscall
    ret

; mkdir_path - create one directory, mode 0755.
; IN:  rdi path. OUT: rax 0, or a negative errno
mkdir_path:
    mov eax, SYS_mkdirat
    mov rsi, rdi
    mov edi, AT_FDCWD
    mov edx, MODE_755
    syscall
    ret

; create_file - create an empty writable file.
; IN:  rdi path. OUT: rax fd, or a negative errno
create_file:
    mov eax, SYS_openat
    mov rsi, rdi
    mov edi, AT_FDCWD
    mov edx, O_WRONLY | O_CREAT | O_TRUNC
    mov r10d, MODE_755
    syscall
    ret

; copy_binary - copy the open source fd into the destination fd.
; IN:  r13 source, r14 destination, rsp buffer of COPY_CHUNK bytes
; OUT: rax 0, or -1. r15 is preserved.
copy_binary:
    mov eax, SYS_read
    mov edi, r13d
    lea rsi, [rsp + 8]
    mov edx, COPY_CHUNK
    syscall
    cmp rax, 0
    jl .bad
    je .done
    mov r8, rax
    lea r9, [rsp + 8]
.write:
    mov eax, SYS_write
    mov edi, r14d
    mov rsi, r9
    mov rdx, r8
    syscall
    test rax, rax
    jle .bad
    add r9, rax
    sub r8, rax
    jnz .write
    jmp copy_binary
.done:
    xor eax, eax
    ret
.bad:
    mov rax, -1
    ret

; undo_mounts - return to the host view after a failed switch.
; IN:  ebx flags (1 scratch, 2 jail, 4 cwd is the jail), r15 base index
undo_mounts:
    test ebx, 4
    jz .jail
    lea rdi, [rel path_root]
    mov eax, SYS_chdir
    syscall
.jail:
    test ebx, 2
    jz .scratch
    call path_jail
    mov rdi, rsi
    mov esi, MNT_DETACH
    mov eax, SYS_umount2
    syscall
.scratch:
    test ebx, 1
    jz .done
    call path_base
    mov rdi, rsi
    mov esi, MNT_DETACH
    mov eax, SYS_umount2
    syscall
.done:
    ret

; close_pair - close the binary fds if they are still open.
close_pair:
    cmp r13, 0
    jl .dest
    mov edi, r13d
    mov eax, SYS_close
    syscall
    mov r13, -1
.dest:
    cmp r14, 0
    jl .done
    mov edi, r14d
    mov eax, SYS_close
    syscall
    mov r14, -1
.done:
    ret

; note_fs - send the filesystem result to the parent.
; IN:  edi 0 host, 1 hidden
note_fs:
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

; path_base, path_jail, path_file - select the path for r15.
; OUT: rsi path
path_base:
    lea rsi, [rel base0]
    test r15, r15
    jz .done
    lea rsi, [rel base1]
    cmp r15, 1
    je .done
    lea rsi, [rel base2]
    cmp r15, 2
    je .done
    lea rsi, [rel base3]
    cmp r15, 3
    je .done
    lea rsi, [rel base4]
.done:
    ret

path_jail:
    lea rsi, [rel jail0]
    test r15, r15
    jz .done
    lea rsi, [rel jail1]
    cmp r15, 1
    je .done
    lea rsi, [rel jail2]
    cmp r15, 2
    je .done
    lea rsi, [rel jail3]
    cmp r15, 3
    je .done
    lea rsi, [rel jail4]
.done:
    ret

path_file:
    lea rsi, [rel file0]
    test r15, r15
    jz .done
    lea rsi, [rel file1]
    cmp r15, 1
    je .done
    lea rsi, [rel file2]
    cmp r15, 2
    je .done
    lea rsi, [rel file3]
    cmp r15, 3
    je .done
    lea rsi, [rel file4]
.done:
    ret
