; Linux x86-64 syscall numbers and openat flags. Arguments use the
; kernel convention: rdi, rsi, rdx, r10, r8, r9.

%define SYS_read 0
%define SYS_write 1
%define SYS_close 3
%define SYS_poll 7
%define SYS_rt_sigaction 13
%define SYS_nanosleep 35
%define SYS_pipe 22
%define SYS_dup2 33
%define SYS_pause 34
%define SYS_fork 57
%define SYS_execve 59
%define SYS_exit 60
%define SYS_wait4 61
%define SYS_kill 62
%define SYS_fcntl 72
%define SYS_setpgid 109
%define SYS_setrlimit 160
%define SYS_clock_gettime 228
%define SYS_openat 257
%define SYS_pidfd_open 434

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

%define CLOCK_MONOTONIC 1
%define F_GETFL 3
%define F_SETFL 4
%define F_SETPIPE_SZ 1031
%define O_NONBLOCK 2048
%define POLLIN 0x001
%define POLLOUT 0x004
%define WNOHANG 1

%define EINTR -4
%define EAGAIN -11
%define EPIPE -32
