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
%define SYS_rt_sigreturn 15
%define SYS_socket 41
%define SYS_exit_group 231
%define SYS_seccomp 317
%define SYS_unshare 272
%define SYS_mount 165
%define SYS_fork 57
%define SYS_execve 59
%define SYS_exit 60
%define SYS_wait4 61
%define SYS_kill 62
%define SYS_fcntl 72
%define SYS_getpid 39
%define SYS_getuid 102
%define SYS_getgid 104
%define SYS_geteuid 107
%define SYS_getegid 108
%define SYS_setpgid 109
%define SYS_capget 125
%define SYS_capset 126
%define SYS_prctl 157
%define SYS_close_range 436
%define SYS_chdir 80
%define SYS_fchmod 91
%define SYS_pivot_root 155
%define SYS_chroot 161
%define SYS_umount2 166
%define SYS_setrlimit 160
%define SYS_mkdirat 258
%define SYS_clock_gettime 228
%define SYS_getdents64 217
%define SYS_openat 257
%define SYS_newfstatat 262
%define SYS_pidfd_open 434

%define AT_FDCWD -100
%define O_RDONLY 0
%define O_DIRECTORY 0x10000
%define ENOTDIR -20
%define ENOSYS -38
%define PR_SET_NO_NEW_PRIVS 38
%define CAP_VERSION_3 0x20080522
%define CAP_VERSION_1 0x19980330
%define DT_UNKNOWN 0
%define DT_REG 8
%define S_IFMT 0xF000
%define S_IFREG 0x8000
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
