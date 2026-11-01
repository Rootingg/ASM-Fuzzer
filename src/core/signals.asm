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

; classify_wait_status - map a wait4 status onto a campaign result.
; IN:  rdi raw status
; OUT: rax EXIT_OK, EXIT_CRASH, EXIT_TIMEOUT, or EXIT_ERROR
global classify_wait_status
classify_wait_status:
    mov eax, edi
    and eax, 0x7f
    cmp eax, 0
    je .exited
    cmp eax, 0x7f
    je .error
    cmp eax, SIGKILL
    je .timeout
    cmp eax, SIGXCPU
    je .timeout
    cmp eax, SIGILL
    je .crash
    cmp eax, SIGTRAP
    je .crash
    cmp eax, SIGABRT
    je .crash
    cmp eax, SIGBUS
    je .crash
    cmp eax, SIGFPE
    je .crash
    cmp eax, SIGSEGV
    je .crash
.error:
    mov eax, EXIT_ERROR
    ret
.timeout:
    mov eax, EXIT_TIMEOUT
    ret
.crash:
    mov eax, EXIT_CRASH
    ret
.exited:
    mov eax, edi
    shr eax, 8
    and eax, 0xff
    cmp eax, 127
    je .error
    mov eax, EXIT_OK
    ret
