; Corpus queue of interesting inputs.
; Slot 0 is the original seed and is never replaced.
; A full queue first drops an entry whose edges are already covered,
; then replaces the lowest novelty score when the new input is strictly better.

%include "constants.inc"

section .bss
queue_len: resq COVER_QUEUE
queue_score: resq COVER_QUEUE
queue_data: resb COVER_QUEUE * COVER_KEEP
queue_edges: resb COVER_QUEUE * EDGE_BYTES
union_bits: resb EDGE_BYTES

section .data
global queue_used
queue_used: dq 0

section .text
extern mem_copy
extern coverage_export
extern bitset_clear
extern bitset_subset
extern bitset_or_into
global queue_reset
global queue_seed
global queue_base
global queue_admit
global queue_slot
global queue_cull
global queue_test_reset
global queue_test_bit
global queue_test_has

; queue_reset - empty the queue for a new campaign.
queue_reset:
    mov qword [rel queue_used], 0
    ret

; queue_seed - keep the original input in slot 0.
; IN:  rdi bytes, rsi length
queue_seed:
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    cmp r13, COVER_KEEP
    ja .skip
    test r13, r13
    jz .skip
    lea rdi, [rel queue_data]
    mov rsi, r12
    mov rdx, r13
    call mem_copy
    mov [rel queue_len], r13
    mov qword [rel queue_score], 0
    lea rdi, [rel queue_edges]
    call bitset_clear
    mov qword [rel queue_used], 1
.skip:
    pop r13
    pop r12
    ret

; queue_base - select the input a trial mutates.
; IN:  rdi trial index
; OUT: rax length, rdx bytes. rax is -1 when the queue is empty.
queue_base:
    mov rcx, [rel queue_used]
    test rcx, rcx
    jz .empty
    mov rax, rdi
    xor edx, edx
    div rcx
    mov rcx, rdx
    imul rdx, COVER_KEEP
    lea rax, [rel queue_data]
    add rax, rdx
    mov rdx, rax
    lea rax, [rel queue_len]
    mov rax, [rax + rcx*8]
    ret
.empty:
    mov rax, -1
    ret

; queue_admit - keep an input that discovered new edges.
; IN:  rdi bytes, rsi length, rdx novelty
; OUT: rax 1 when stored, 0 when rejected
queue_admit:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    test r14, r14
    jz .reject
    test r13, r13
    jz .reject
    cmp r13, COVER_KEEP
    ja .reject
    call queue_cull
    lea rdi, [rel queue_score]
    mov rsi, [rel queue_used]
    mov rdx, r14
    call queue_slot
    cmp rax, 0
    jl .reject
    mov rbx, rax
    mov rcx, rax
    imul rcx, COVER_KEEP
    lea rdi, [rel queue_data]
    add rdi, rcx
    mov rsi, r12
    mov rdx, r13
    call mem_copy
    lea rax, [rel queue_len]
    mov [rax + rbx*8], r13
    lea rax, [rel queue_score]
    mov [rax + rbx*8], r14
    mov rax, rbx
    imul rax, EDGE_BYTES
    lea rdi, [rel queue_edges]
    add rdi, rax
    call coverage_export
    cmp rbx, [rel queue_used]
    jne .stored
    inc qword [rel queue_used]
.stored:
    mov eax, 1
    jmp .leave
.reject:
    xor eax, eax
.leave:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; queue_slot - choose where a new input goes.
; IN:  rdi scores, rsi used, rdx new score
; OUT: rax slot, or -1 when the new score is not better than every replaceable slot
queue_slot:
    cmp rsi, COVER_QUEUE
    jae .full
    mov rax, rsi
    ret
.full:
    cmp rsi, 1
    jbe .reject
    mov rcx, 1
    mov r8, 1
    mov r9, [rdi + 8]
.find:
    cmp rcx, rsi
    jae .decide
    mov rax, [rdi + rcx*8]
    cmp rax, r9
    jae .next
    mov r9, rax
    mov r8, rcx
.next:
    inc rcx
    jmp .find
.decide:
    cmp rdx, r9
    jbe .reject
    mov rax, r8
    ret
.reject:
    mov rax, -1
    ret

; queue_cull - drop a non-seed entry whose edges are covered by the others.
; OUT: rax queue length after the pass
queue_cull:
    push rbx
    push r12
    mov rbx, 1
.scan:
    cmp rbx, [rel queue_used]
    jae .done
    lea rdi, [rel union_bits]
    call bitset_clear
    xor r12, r12
.union:
    cmp r12, [rel queue_used]
    jae .check
    cmp r12, rbx
    je .union_next
    mov rax, r12
    imul rax, EDGE_BYTES
    lea rsi, [rel queue_edges]
    add rsi, rax
    lea rdi, [rel union_bits]
    call bitset_or_into
.union_next:
    inc r12
    jmp .union
.check:
    mov rax, rbx
    imul rax, EDGE_BYTES
    lea rdi, [rel queue_edges]
    add rdi, rax
    lea rsi, [rel union_bits]
    call bitset_subset
    test rax, rax
    jz .keep
    mov rdi, rbx
    call queue_remove
    jmp .scan
.keep:
    inc rbx
    jmp .scan
.done:
    mov rax, [rel queue_used]
    pop r12
    pop rbx
    ret

; queue_remove - slide every slot after rdi down by one.
queue_remove:
    push rbx
    push r12
    mov rbx, rdi
.slide:
    mov rax, [rel queue_used]
    dec rax
    cmp rbx, rax
    jae .shrink
    mov r12, rbx
    inc r12
    mov rax, r12
    imul rax, COVER_KEEP
    lea rsi, [rel queue_data]
    add rsi, rax
    mov rax, rbx
    imul rax, COVER_KEEP
    lea rdi, [rel queue_data]
    add rdi, rax
    mov rdx, COVER_KEEP
    call mem_copy
    lea r8, [rel queue_len]
    mov rax, [r8 + r12*8]
    mov [r8 + rbx*8], rax
    lea r8, [rel queue_score]
    mov rax, [r8 + r12*8]
    mov [r8 + rbx*8], rax
    mov rax, r12
    imul rax, EDGE_BYTES
    lea rsi, [rel queue_edges]
    add rsi, rax
    mov rax, rbx
    imul rax, EDGE_BYTES
    lea rdi, [rel queue_edges]
    add rdi, rax
    mov rdx, EDGE_BYTES
    call mem_copy
    inc rbx
    jmp .slide
.shrink:
    dec qword [rel queue_used]
    pop r12
    pop rbx
    ret

; queue_test_reset - start a three-slot queue for the cull test.
queue_test_reset:
    push rbx
    mov qword [rel queue_used], 3
    xor ebx, ebx
.clear:
    cmp rbx, 3
    jae .scores
    mov rax, rbx
    imul rax, EDGE_BYTES
    lea rdi, [rel queue_edges]
    add rdi, rax
    call bitset_clear
    lea r8, [rel queue_len]
    mov qword [r8 + rbx*8], 1
    lea r8, [rel queue_score]
    mov qword [r8 + rbx*8], 1
    inc rbx
    jmp .clear
.scores:
    pop rbx
    ret

; queue_test_bit - set one edge on a slot.
; IN:  rdi slot, rsi bit
queue_test_bit:
    mov rax, rdi
    imul rax, EDGE_BYTES
    lea rdi, [rel queue_edges]
    add rdi, rax
    mov eax, esi
    shr eax, 3
    mov ecx, esi
    and ecx, 7
    mov dl, 1
    shl dl, cl
    or byte [rdi + rax], dl
    ret

; queue_test_has - report whether a slot has a bit.
; IN:  rdi slot, rsi bit
; OUT: rax 1 when set
queue_test_has:
    mov rax, rdi
    imul rax, EDGE_BYTES
    lea rdi, [rel queue_edges]
    add rdi, rax
    mov eax, esi
    shr eax, 3
    mov ecx, esi
    and ecx, 7
    mov dl, 1
    shl dl, cl
    test byte [rdi + rax], dl
    jz .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret
