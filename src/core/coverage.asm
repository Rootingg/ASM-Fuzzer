; 16-bit edge ids. Two different program edges that share a number are one edge.
; The bitmaps are fixed: a noisy target cannot grow this process.

%include "syscalls.inc"
%include "constants.inc"

section .bss
seen_bits: resb EDGE_BYTES
run_bits: resb EDGE_BYTES

section .data
global coverage_total
global coverage_last_new
coverage_total: dq 0
coverage_last_new: dq 0
drain_budget: dq 0

section .text
global coverage_reset
global coverage_drain
global coverage_commit
global coverage_finish
global coverage_export
global bitset_clear
global bitset_subset
global bitset_or_into

; coverage_reset - drop this execution's marks. The campaign bitmap stays.
coverage_reset:
    push rdi
    lea rdi, [rel run_bits]
    mov rcx, EDGE_BYTES
    xor eax, eax
    rep stosb
    mov qword [rel coverage_last_new], 0
    mov qword [rel drain_budget], DRAIN_BUDGET
    pop rdi
    ret

; coverage_note - record one id for this execution.
; IN:  edi id
coverage_note:
    cmp edi, EDGE_BITS
    jae .ignore
    mov eax, edi
    shr eax, 3
    mov ecx, edi
    and ecx, 7
    mov dl, 1
    shl dl, cl
    lea r8, [rel run_bits]
    test byte [r8 + rax], dl
    jnz .ignore
    or byte [r8 + rax], dl
    lea r8, [rel seen_bits]
    test byte [r8 + rax], dl
    jnz .ignore
    inc qword [rel coverage_last_new]
.ignore:
    ret

; coverage_drain - read a bounded number of ids from a non-blocking pipe.
; IN:  edi file descriptor, or negative when coverage is disabled
; OUT: rax ids consumed, including ones past the note budget
coverage_drain:
    push rbx
    push rbp
    mov ebx, edi
    xor ebp, ebp
    cmp ebx, 0
    jl .done
.loop:
    cmp ebp, DRAIN_CHUNK
    jae .done
    sub rsp, 16
    mov eax, SYS_read
    mov edi, ebx
    mov rsi, rsp
    mov edx, 2
    syscall
    cmp rax, 2
    jne .stop
    movzx edi, word [rsp]
    cmp qword [rel drain_budget], 0
    je .consume
    dec qword [rel drain_budget]
    call coverage_note
.consume:
    add rsp, 16
    inc ebp
    jmp .loop
.stop:
    add rsp, 16
.done:
    mov rax, rbp
    pop rbp
    pop rbx
    ret

; coverage_finish - empty the pipe up to a fixed cap, then publish the run.
; IN:  edi file descriptor, or negative
; OUT: rax new edges in this execution
coverage_finish:
    push rbx
    push r12
    mov ebx, edi
    mov r12d, 16
.more:
    mov edi, ebx
    call coverage_drain
    test rax, rax
    jz .publish
    cmp rax, DRAIN_CHUNK
    jb .publish
    dec r12d
    jnz .more
.publish:
    call coverage_commit
    pop r12
    pop rbx
    ret

; coverage_commit - fold this run into the campaign bitmap.
; OUT: rax number of edges seen for the first time
coverage_commit:
    push rbx
    push r12
    push r13
    xor ebx, ebx
    lea r12, [rel run_bits]
    lea r13, [rel seen_bits]
.scan:
    mov al, [r12 + rbx]
    mov dl, [r13 + rbx]
    mov cl, dl
    not cl
    and cl, al
    jz .next
    or byte [r13 + rbx], al
    call popcount_byte
    add [rel coverage_total], rax
.next:
    inc rbx
    cmp rbx, EDGE_BYTES
    jb .scan
    mov rax, [rel coverage_last_new]
    pop r13
    pop r12
    pop rbx
    ret

; popcount_byte - count bits in cl.
; OUT: rax count
popcount_byte:
    movzx eax, cl
    mov edx, eax
    shr edx, 1
    and edx, 0x55
    sub eax, edx
    mov edx, eax
    shr edx, 2
    and eax, 0x33
    and edx, 0x33
    add eax, edx
    mov edx, eax
    shr edx, 4
    add eax, edx
    and eax, 0x0f
    ret

; coverage_export - copy this execution's bitmap.
; IN:  rdi destination, EDGE_BYTES long
coverage_export:
    push rsi
    push rdi
    lea rsi, [rel run_bits]
    mov rcx, EDGE_BYTES
    rep movsb
    pop rdi
    pop rsi
    ret

; bitset_clear - zero EDGE_BYTES at rdi.
bitset_clear:
    push rdi
    mov rcx, EDGE_BYTES
    xor eax, eax
    rep stosb
    pop rdi
    ret

; bitset_subset - report whether every bit of rdi is set in rsi.
; OUT: rax 1 when rdi is a subset of rsi
bitset_subset:
    push rbx
    mov rcx, EDGE_BYTES / 8
.word:
    mov rax, [rdi]
    mov rbx, [rsi]
    not rbx
    and rax, rbx
    jnz .no
    add rdi, 8
    add rsi, 8
    dec rcx
    jnz .word
    mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

; bitset_or_into - OR rsi into rdi.
bitset_or_into:
    mov rcx, EDGE_BYTES / 8
.word:
    mov rax, [rsi]
    or [rdi], rax
    add rdi, 8
    add rsi, 8
    dec rcx
    jnz .word
    ret
