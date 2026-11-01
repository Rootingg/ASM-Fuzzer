; Classify a raw wait4 status word.
; A fault is a crash. Resource-limit signals such as SIGKILL and SIGXCPU are not.

%include "constants.inc"

section .text
global wait_status_is_crash

; wait_status_is_crash - report whether a child died from a fault signal.
; IN:  rdi raw status returned through wait4
; OUT: rax 1 for SIGILL, SIGTRAP, SIGABRT, SIGBUS, SIGFPE, or SIGSEGV, else 0
wait_status_is_crash:
    mov eax, edi
    and eax, 0x7f
    cmp eax, 0x7f
    je .no
    cmp eax, SIGILL
    je .yes
    cmp eax, SIGTRAP
    je .yes
    cmp eax, SIGABRT
    je .yes
    cmp eax, SIGBUS
    je .yes
    cmp eax, SIGFPE
    je .yes
    cmp eax, SIGSEGV
    je .yes
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret
