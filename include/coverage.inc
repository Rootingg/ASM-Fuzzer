; Lightweight edge mark. The fuzzer maps this descriptor to a pipe.
; The identifier is 16 bits. Reusing a number merges two edges into one.
; A closed or missing descriptor is ignored, so the target still runs alone.

%define COV_FD 3

%macro COV 1
    push rax
    push rcx
    push rdx
    push rdi
    push rsi
    push r11
    sub rsp, 16
    mov word [rsp], %1
    mov eax, SYS_write
    mov edi, COV_FD
    mov rsi, rsp
    mov edx, 2
    syscall
    add rsp, 16
    pop r11
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rax
%endmacro
