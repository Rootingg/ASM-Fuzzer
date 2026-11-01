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
cfg_seed: resq 1
path_buf: resb 512
work_buf: resb MAX_INPUT
seed_names: resb MAX_SEEDS * SEED_NAME
signal_mask: resq 1
start_ms: resq 1
aggregate: resq 1

section .rodata
msg_usage: db "usage: asm-fuzzer TARGET CORPUS OUTPUT", 10
           db "       asm-fuzzer --target PATH --input PATH --output PATH", 10
           db "                  [--timeout MS] [--iterations N] [--seed N]", 10
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
msg_execs: db "execs ", 0
msg_execs_len equ $ - msg_execs - 1
msg_rate: db "rate ", 0
msg_rate_len equ $ - msg_rate - 1
msg_nl: db 10
opt_target: db "--target", 0
opt_input: db "--input", 0
opt_output: db "--output", 0
opt_timeout: db "--timeout", 0
opt_iterations: db "--iterations", 0
opt_seed: db "--seed", 0
opt_stop: db "--stop-on-crash", 0
opt_nostop: db "--no-stop-on-crash", 0

section .text
extern corpus_load
extern corpus_open_dir
extern corpus_collect
extern join_path
extern fuzz_campaign
extern sys_close
extern sys_monotonic_ms
extern exec_count
global _start

_start:
    mov rbx, [rsp]
    lea r12, [rsp + 8]
    mov qword [rel cfg_timeout], DEFAULT_TIMEOUT_MS
    mov qword [rel cfg_iterations], CAMPAIGN_MAX_BITS
    mov qword [rel cfg_stop], 1
    mov qword [rel cfg_seed], 0
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
    jnz .try_seed
    call take_value
    test rax, rax
    jz .usage
    mov rdi, rax
    call parse_u64
    cmp rax, 0
    jle .usage
    mov [rel cfg_iterations], rax
    jmp .next_flag
.try_seed:
    mov rdi, [r12 + r13*8]
    lea rsi, [rel opt_seed]
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
    mov [rel cfg_seed], rax
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

    call sys_monotonic_ms
    mov [rel start_ms], rax
    call dispatch_inputs
    mov r15, rax
    cmp r15, EXIT_CRASH
    je .crash
    cmp r15, EXIT_TIMEOUT
    je .timeout
    cmp r15, EXIT_OK
    jne .error

    mov rdi, 1
    lea rsi, [rel msg_clean]
    mov rdx, msg_clean_len
    call write_out
    call emit_stats
    EXIT EXIT_OK

.crash:
    mov rdi, 1
    lea rsi, [rel msg_crash]
    mov rdx, msg_crash_len
    call write_out
    call emit_stats
    EXIT EXIT_CRASH

.timeout:
    mov rdi, 1
    lea rsi, [rel msg_timeout]
    mov rdx, msg_timeout_len
    call write_out
    call emit_stats
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
    call emit_stats
    EXIT EXIT_ERROR

; dispatch_inputs - run every seed file, or the single input file.
; OUT: rax campaign result
dispatch_inputs:
    push rbx
    push r12
    push r13
    mov qword [rel signal_mask], 0
    mov qword [rel aggregate], EXIT_OK
    mov rdi, [rel cfg_input]
    call corpus_open_dir
    cmp rax, 0
    jge .directory
    cmp rax, ENOTDIR
    jne .fail
    mov rdi, [rel cfg_input]
    lea rsi, [rel input_buf]
    mov rdx, MAX_INPUT
    call corpus_load
    cmp rax, 0
    js .fail
    mov rbx, rax
    call one_campaign
    jmp .leave

.directory:
    mov ebx, eax
    mov edi, ebx
    lea rsi, [rel seed_names]
    mov rdx, MAX_SEEDS
    mov rcx, SEED_NAME
    call corpus_collect
    mov r12, rax
    mov edi, ebx
    call sys_close
    cmp r12, 0
    jle .fail
    xor r13, r13
.seed_loop:
    cmp r13, r12
    jae .done
    mov rdi, [rel cfg_input]
    mov rax, r13
    imul rax, SEED_NAME
    lea rsi, [rel seed_names]
    add rsi, rax
    lea rdx, [rel path_buf]
    mov rcx, 512
    call join_path
    test rax, rax
    jnz .fail
    lea rdi, [rel path_buf]
    lea rsi, [rel input_buf]
    mov rdx, MAX_INPUT
    call corpus_load
    cmp rax, 0
    js .fail
    mov rbx, rax
    call one_campaign
    cmp rax, 0
    jl .fail
    cmp rax, EXIT_CRASH
    jne .next_seed
    cmp qword [rel cfg_stop], 0
    jne .done
.next_seed:
    inc r13
    jmp .seed_loop
.done:
    mov rax, [rel aggregate]
    jmp .leave
.fail:
    mov rax, -1
.leave:
    pop r13
    pop r12
    pop rbx
    ret

; one_campaign - fuzz the buffer currently loaded.
; IN:  rbx length
; OUT: rax campaign result, aggregate updated
one_campaign:
    sub rsp, 96
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
    mov rax, [rel cfg_seed]
    mov [rsp + 64], rax
    lea rax, [rel path_buf]
    mov [rsp + 72], rax
    mov rax, [rel signal_mask]
    mov [rsp + 80], rax
    lea rax, [rel work_buf]
    mov [rsp + 88], rax
    mov rdi, rsp
    call fuzz_campaign
    mov rcx, [rsp + 80]
    mov [rel signal_mask], rcx
    add rsp, 96
    cmp rax, EXIT_CRASH
    jne .check_timeout
    mov qword [rel aggregate], EXIT_CRASH
    ret
.check_timeout:
    cmp rax, EXIT_TIMEOUT
    jne .check_ok
    cmp qword [rel aggregate], EXIT_CRASH
    je .keep
    mov qword [rel aggregate], EXIT_TIMEOUT
.keep:
    ret
.check_ok:
    ret

; emit_stats - print the execution count and the wall-clock rate.
emit_stats:
    mov rdi, 1
    lea rsi, [rel msg_execs]
    mov rdx, msg_execs_len
    call write_out
    mov rdi, [rel exec_count]
    call print_u64
    mov rdi, 1
    lea rsi, [rel msg_nl]
    mov rdx, 1
    call write_out
    mov rdi, 1
    lea rsi, [rel msg_rate]
    mov rdx, msg_rate_len
    call write_out
    call current_rate
    mov rdi, rax
    call print_u64
    mov rdi, 1
    lea rsi, [rel msg_nl]
    mov rdx, 1
    call write_out
    ret

; current_rate - executions per second, or 0 when the clock did not advance.
; OUT: rax rate
current_rate:
    call sys_monotonic_ms
    cmp rax, 0
    jl .zero
    sub rax, [rel start_ms]
    jbe .zero
    mov rcx, rax
    mov rax, [rel exec_count]
    mov r8, 1000
    mul r8
    test rdx, rdx
    jnz .zero
    div rcx
    ret
.zero:
    xor eax, eax
    ret

; print_u64 - write an unsigned decimal value to stdout.
; IN:  rdi value
print_u64:
    push rbx
    sub rsp, 32
    mov rax, rdi
    lea rcx, [rsp + 32]
.digits:
    xor edx, edx
    mov r8, 10
    div r8
    add dl, "0"
    dec rcx
    mov [rcx], dl
    test rax, rax
    jnz .digits
    lea rbx, [rsp + 32]
    sub rbx, rcx
    mov rdi, 1
    mov rsi, rcx
    mov rdx, rbx
    call write_out
    add rsp, 32
    pop rbx
    ret

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
