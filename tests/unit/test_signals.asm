; Checks the crash classifier against raw wait statuses.

%include "constants.inc"
%include "syscalls.inc"
%include "macros.inc"

section .text
extern wait_status_is_crash
global _start

_start:
    mov edi, SIGSEGV
    call wait_status_is_crash
    cmp eax, 1
    jne .fail

    mov edi, SIGSEGV | 0x80
    call wait_status_is_crash
    cmp eax, 1
    jne .fail

    mov edi, SIGILL
    call wait_status_is_crash
    cmp eax, 1
    jne .fail

    xor edi, edi
    call wait_status_is_crash
    test eax, eax
    jnz .fail

    mov edi, 0x100
    call wait_status_is_crash
    test eax, eax
    jnz .fail

    mov edi, SIGKILL
    call wait_status_is_crash
    test eax, eax
    jnz .fail

    mov edi, SIGXCPU
    call wait_status_is_crash
    test eax, eax
    jnz .fail

    EXIT 0
.fail:
    EXIT 1
