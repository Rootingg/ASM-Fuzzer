; Shared sizes and exit statuses for the fuzzer and its tests.

%define MAX_INPUT 4096
%define CAMPAIGN_MAX_BITS 64

%define EXIT_OK 0
%define EXIT_ERROR 1
%define EXIT_CRASH 2

%define SIGILL  4
%define SIGTRAP 5
%define SIGABRT 6
%define SIGBUS  7
%define SIGFPE  8
%define SIGKILL 9
%define SIGSEGV 11
%define SIGXCPU 24

%define RLIMIT_CPU 0
%define RLIMIT_FSIZE 1
%define RLIMIT_AS 9

; One second of CPU and 64 MiB of address space for a child target.
%define TARGET_CPU_SECONDS 1
%define TARGET_ADDRESS_SPACE 67108864
%define TARGET_FILE_SIZE 1048576
