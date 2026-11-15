; Small syscall helpers. SYS_* names come from syscalls.inc.

%macro EXIT 1
    mov rax, SYS_exit
    mov rdi, %1
    syscall
%endmacro
