; Linux x86-64 syscall numbers and openat flags. Arguments use the
; kernel convention: rdi, rsi, rdx, r10, r8, r9.

%define SYS_read 0
%define SYS_write 1
%define SYS_close 3
%define SYS_rt_sigaction 13
%define SYS_pipe 22
%define SYS_dup2 33
%define SYS_fork 57
%define SYS_execve 59
%define SYS_exit 60
%define SYS_wait4 61
%define SYS_setrlimit 160
%define SYS_openat 257

%define AT_FDCWD -100
%define O_RDONLY 0
%define O_WRONLY 1
%define O_CREAT 64
%define O_TRUNC 512

; 0644
%define MODE_644 420

; Kernel sigaction takes an 8-byte signal set on x86-64.
%define SIGSET_SIZE 8
%define SIG_IGN 1
%define SIGPIPE 13
