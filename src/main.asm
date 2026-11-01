; asm-fuzzer TARGET CORPUS OUTPUT
; asm-fuzzer --target PATH --input PATH --output PATH [--timeout MS]
;             [--iterations N] [--stop-on-crash|--no-stop-on-crash]
; Exit 0 clean, 2 crash, 3 timeout, 1 error.

default rel

%include "constants.inc"
%include "syscalls.inc"
%include "macros.inc"

section .bss
input_buf: resb MAX_INPUT
scratch_buf: resb MAX_INPUT
cfg_target: resq 1
cfg_input: resq 1
cfg_output: resq 1
cfg_timeout: resq 1
cfg_iterations: resq 1
cfg_stop: resq 1

section .rodata
msg_usage: db "usage: asm-fuzzer TARGET CORPUS OUTPUT", 10
           db "       asm-fuzzer --target PATH --input PATH --output PATH", 10
           db "                  [--timeout MS] [--iterations N]", 10
           db "                  [--stop-on-crash|--no-stop-on-crash]", 10
msg_usage_len equ $ - msg_usage
msg_clean: db "clean", 10
msg_clean_len equ $ - msg_clean
msg_crash: db "crash", 10
msg_crash_len equ $ - msg_crash
msg_timeout: db "timeout", 10
msg_timeout_len equ $ - msg_timeout
msg_error: db "error", 10
msg_error_len equ $ - msg_error
opt_target: db "--target", 0
opt_input: db "--input", 0
opt_output: db "--output", 0
opt_timeout: db "--timeout", 0
opt_iterations: db "--iterations", 0
opt_stop: db "--stop-on-crash", 0
opt_nostop: db "--no-stop-on-crash", 0

section .text
extern corpus_load
extern fuzz_campaign
global _start

_start:
    mov rbx, [rsp]
    lea r12, [rsp + 8]
    mov qword [rel cfg_timeout], DEFAULT_TIMEOUT_MS
    mov qword [rel cfg_iterations], CAMPAIGN_MAX_BITS
    mov qword [rel cfg_stop], 1
    mov qword [rel cfg_target], 0
    mov qword [rel cfg_input], 0
    mov qword [rel cfg_output], 0

    cmp rbx, 4
    jne .parse
    mov rdi, [r12 + 8]
    cmp byte [rdi], "-"
    je .parse
    mov [rel cfg_target], rdi
    mov rax, [r12 + 16]
    mov [rel cfg_input], rax
    mov rax, [r12 + 24]
    mov [rel cfg_output], rax
    jmp .ready

.parse:
    mov r13, 1
.next_flag:
    cmp r13, rbx
    jae .ready
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_target]
    call str_eq
    test rax, rax
    jnz .try_input
    call take_value
    test rax, rax
    jz .usage
    mov [rel cfg_target], rax
    jmp .next_flag
.try_input:
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_input]
    call str_eq
    test rax, rax
    jnz .try_output
    call take_value
    test rax, rax
    jz .usage
    mov [rel cfg_input], rax
    jmp .next_flag
.try_output:
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_output]
    call str_eq
    test rax, rax
    jnz .try_timeout
    call take_value
    test rax, rax
    jz .usage
    mov [rel cfg_output], rax
    jmp .next_flag
.try_timeout:
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_timeout]
    call str_eq
    test rax, rax
    jnz .try_iterations
    call take_value
    test rax, rax
    jz .usage
    mov rdi, rax
    call parse_u64
    cmp rax, 0
    jle .usage
    mov [rel cfg_timeout], rax
    jmp .next_flag
.try_iterations:
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_iterations]
    call str_eq
    test rax, rax
    jnz .try_stop
    call take_value
    test rax, rax
    jz .usage
    mov rdi, rax
    call parse_u64
    cmp rax, 0
    jle .usage
    mov [rel cfg_iterations], rax
    jmp .next_flag
.try_stop:
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_stop]
    call str_eq
    test rax, rax
    jnz .try_nostop
    mov qword [rel cfg_stop], 1
    inc r13
    jmp .next_flag
.try_nostop:
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_nostop]
    call str_eq
    test rax, rax
    jnz .usage
    mov qword [rel cfg_stop], 0
    inc r13
    jmp .next_flag

.ready:
    mov rax, [rel cfg_target]
    test rax, rax
    jz .usage
    mov rax, [rel cfg_input]
    test rax, rax
    jz .usage
    mov rax, [rel cfg_output]
    test rax, rax
    jz .usage

    mov rdi, [rel cfg_input]
    lea rsi, [rel input_buf]
    mov rdx, MAX_INPUT
    call corpus_load
    cmp rax, 0
    js .error
    mov rbx, rax

    sub rsp, 64
    mov rax, [rel cfg_target]
    mov [rsp], rax
    lea rax, [rel input_buf]
    mov [rsp + 8], rax
    mov [rsp + 16], rbx
    lea rax, [rel scratch_buf]
    mov [rsp + 24], rax
    mov rax, [rel cfg_output]
    mov [rsp + 32], rax
    mov rax, [rel cfg_timeout]
    mov [rsp + 40], rax
    mov rax, [rel cfg_iterations]
    mov [rsp + 48], rax
    mov rax, [rel cfg_stop]
    mov [rsp + 56], rax
    mov rdi, rsp
    call fuzz_campaign
    add rsp, 64

    cmp rax, EXIT_CRASH
    je .crash
    cmp rax, EXIT_TIMEOUT
    je .timeout
    cmp rax, EXIT_OK
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

.timeout:
    mov rdi, 1
    lea rsi, [rel msg_timeout]
    mov rdx, msg_timeout_len
    call write_out
    EXIT EXIT_TIMEOUT

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

; take_value - consume the next argv string.
; IN:  r12 argv, r13 current index, rbx argc
; OUT: rax value pointer, r13 advanced past the value
take_value:
    inc r13
    cmp r13, rbx
    jae .missing
    mov rax, [r12 + r13*8]
    inc r13
    ret
.missing:
    xor eax, eax
    ret

; str_eq - compare two C strings.
; IN:  rdi left, rsi right
; OUT: rax 0 when equal, 1 otherwise
str_eq:
    push rdi
    push rsi
.cmp:
    mov al, [rdi]
    mov cl, [rsi]
    cmp al, cl
    jne .differ
    test al, al
    jz .same
    inc rdi
    inc rsi
    jmp .cmp
.same:
    xor eax, eax
    jmp .done
.differ:
    mov eax, 1
.done:
    pop rsi
    pop rdi
    ret

; parse_u64 - parse an unsigned decimal string.
; IN:  rdi text
; OUT: rax value, or -1
parse_u64:
    xor eax, eax
    cmp byte [rdi], 0
    je .bad
.digit:
    movzx rcx, byte [rdi]
    test rcx, rcx
    jz .parsed
    sub rcx, "0"
    cmp rcx, 9
    ja .bad
    cmp rax, 100000000
    ja .bad
    imul rax, rax, 10
    add rax, rcx
    inc rdi
    jmp .digit
.parsed:
    ret
.bad:
    mov rax, -1
    ret

; write_out - write one short diagnostic.
; IN:  rdi fd, rsi buffer, rdx length
write_out:
    mov rax, SYS_write
    syscall
    ret
