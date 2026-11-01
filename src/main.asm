; asm-fuzzer TARGET CORPUS CRASH_PATH
; Exit 0 when the campaign stays clean, 2 when a crash file is written, 1 on error.

default rel

%include "constants.inc"
%include "syscalls.inc"
%include "macros.inc"

section .bss
input_buf: resb MAX_INPUT
scratch_buf: resb MAX_INPUT

section .rodata
msg_usage: db "usage: asm-fuzzer TARGET CORPUS CRASH_PATH", 10
msg_usage_len equ $ - msg_usage
msg_clean: db "clean", 10
msg_clean_len equ $ - msg_clean
msg_crash: db "crash", 10
msg_crash_len equ $ - msg_crash
msg_error: db "error", 10
msg_error_len equ $ - msg_error

section .text
extern corpus_load
extern fuzz_campaign
global _start

_start:
    mov rax, [rsp]
    cmp rax, 4
    jne .usage

    mov rdi, [rsp + 24]
    lea rsi, [rel input_buf]
    mov rdx, MAX_INPUT
    call corpus_load
    cmp rax, 0
    js .error
    mov rbx, rax

    mov rdi, [rsp + 16]
    lea rsi, [rel input_buf]
    mov rdx, rbx
    lea rcx, [rel scratch_buf]
    mov r8, [rsp + 32]
    call fuzz_campaign
    cmp rax, EXIT_CRASH
    je .crash
    cmp rax, 0
    jne .error

    mov rdi, 1
    lea rsi, [rel msg_clean]
    mov rdx, msg_clean_len
    call write_out
    EXIT EXIT_OK

.crash:
    mov rdi, 1
    lea rsi, [rel msg_crash]
    mov rdx, msg_crash_len
    call write_out
    EXIT EXIT_CRASH

.usage:
    mov rdi, 2
    lea rsi, [rel msg_usage]
    mov rdx, msg_usage_len
    call write_out
    EXIT EXIT_ERROR

.error:
    mov rdi, 2
    lea rsi, [rel msg_error]
    mov rdx, msg_error_len
    call write_out
    EXIT EXIT_ERROR

; write_out - write one short diagnostic.
; IN:  rdi fd, rsi buffer, rdx length
write_out:
    mov rax, SYS_write
    syscall
    ret
