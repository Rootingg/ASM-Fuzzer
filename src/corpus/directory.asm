; List regular files in a corpus directory. Names are sorted for a stable run.

%include "constants.inc"
%include "syscalls.inc"

section .text
extern sys_openat_cwd
extern sys_close
global corpus_open_dir
global corpus_collect
global join_path

; corpus_open_dir - open a directory.
; IN:  rdi path
; OUT: rax file descriptor, or a negative errno (ENOTDIR when the path is a file)
corpus_open_dir:
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    call sys_openat_cwd
    ret

; corpus_collect - read and sort regular file names.
; IN:  rdi directory fd, rsi name storage, rdx maximum names, rcx stride
; OUT: rax name count, or -1
corpus_collect:
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
    xor r15, r15
    sub rsp, 4352

.read_dir:
    mov rax, SYS_getdents64
    mov rdi, rbx
    lea rsi, [rsp + 256]
    mov rdx, 4096
    syscall
    cmp rax, 0
    je .sort
    jl .read_error
    mov [rsp], rax
    xor ebp, ebp
.next_entry:
    cmp rbp, [rsp]
    jae .read_dir
    movzx rcx, word [rsp + 256 + rbp + 16]
    test rcx, rcx
    jz .sort
    movzx edx, byte [rsp + 256 + rbp + 18]
    lea rdi, [rsp + 256 + rbp + 19]
    cmp edx, DT_REG
    je .consider
    cmp edx, DT_UNKNOWN
    jne .skip_entry
    call is_regular
    test rax, rax
    jz .skip_entry
    lea rdi, [rsp + 256 + rbp + 19]
.consider:
    call copy_name
    cmp rax, 0
    jl .fail
    add r15, rax
.skip_entry:
    movzx rcx, word [rsp + 256 + rbp + 16]
    add rbp, rcx
    jmp .next_entry

.read_error:
    cmp rax, EINTR
    je .read_dir
    jmp .fail

.sort:
    mov rdi, r12
    mov rsi, r15
    mov rdx, r14
    call sort_names
    mov rax, r15
    jmp .leave
.fail:
    mov rax, -1
.leave:
    add rsp, 4352
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; copy_name - append one directory entry when it is a real file.
; IN:  rdi name, r12 base, r13 max, r14 stride, r15 count
; OUT: rax 1 when stored, 0 when ignored, -1 when the table is full or the name is too long
copy_name:
    cmp byte [rdi], "."
    jne .store
    cmp byte [rdi + 1], 0
    je .ignore
    cmp byte [rdi + 1], "."
    jne .store
    cmp byte [rdi + 2], 0
    je .ignore
.store:
    cmp r15, r13
    jae .full
    mov rax, r15
    imul rax, r14
    add rax, r12
    xor rcx, rcx
.copy:
    mov dl, [rdi + rcx]
    mov [rax + rcx], dl
    test dl, dl
    jz .stored
    inc rcx
    cmp rcx, SEED_NAME - 1
    jb .copy
    jmp .full
.stored:
    mov eax, 1
    ret
.ignore:
    xor eax, eax
    ret
.full:
    mov rax, -1
    ret

; is_regular - stat a DT_UNKNOWN name against the open directory.
; IN:  rdi name, rbx directory fd
; OUT: rax 1 when the entry is a regular file
is_regular:
    sub rsp, 160
    mov rsi, rdi
    mov rdi, rbx
    mov rdx, rsp
    xor r10, r10
    mov rax, SYS_newfstatat
    syscall
    test rax, rax
    jnz .not_regular
    mov eax, [rsp + 24]
    and eax, S_IFMT
    cmp eax, S_IFREG
    jne .not_regular
    mov eax, 1
    jmp .stat_leave
.not_regular:
    xor eax, eax
.stat_leave:
    add rsp, 160
    ret

; sort_names - insertion sort, unsigned byte order.
; IN:  rdi base, rsi count, rdx stride
sort_names:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov rbx, 1
.outer:
    cmp rbx, r13
    jae .sorted
    mov r15, rbx
.inner:
    test r15, r15
    jz .outer_next
    mov rax, r15
    dec rax
    imul rax, r14
    lea rdi, [r12 + rax]
    lea rsi, [rdi + r14]
    call name_less
    test rax, rax
    jz .outer_next
    mov rax, r15
    dec rax
    imul rax, r14
    lea rdi, [r12 + rax]
    lea rsi, [rdi + r14]
    mov rdx, r14
    call swap_names
    dec r15
    jmp .inner
.outer_next:
    inc rbx
    jmp .outer
.sorted:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; name_less - report whether the second name is less than the first.
; IN:  rdi previous, rsi current
; OUT: rax 1 when current must move before previous
name_less:
.cmp:
    mov al, [rsi]
    mov cl, [rdi]
    cmp al, cl
    jb .yes
    ja .no
    test al, al
    jz .no
    inc rdi
    inc rsi
    jmp .cmp
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; swap_names - exchange two stride-sized records.
; IN:  rdi left, rsi right, rdx stride
swap_names:
    test rdx, rdx
    jz .done
.swap:
    mov al, [rdi]
    mov cl, [rsi]
    mov [rdi], cl
    mov [rsi], al
    inc rdi
    inc rsi
    dec rdx
    jnz .swap
.done:
    ret

; join_path - write directory + "/" + name.
; IN:  rdi directory, rsi name, rdx destination, rcx capacity
; OUT: rax 0, or -1
global join_path
join_path:
    push rbx
    push r12
    mov r12, rdx
    mov rbx, rdx
    add rbx, rcx
.copy_dir:
    mov al, [rdi]
    test al, al
    jz .slash
    cmp r12, rbx
    jae .overflow
    mov [r12], al
    inc r12
    inc rdi
    jmp .copy_dir
.slash:
    cmp r12, rdx
    je .copy_name
    cmp byte [r12 - 1], "/"
    je .copy_name
    cmp r12, rbx
    jae .overflow
    mov byte [r12], "/"
    inc r12
.copy_name:
    mov al, [rsi]
    cmp r12, rbx
    jae .overflow
    mov [r12], al
    inc r12
    test al, al
    jz .joined
    inc rsi
    jmp .copy_name
.joined:
    xor eax, eax
    jmp .leave
.overflow:
    mov rax, -1
.leave:
    pop r12
    pop rbx
    ret
