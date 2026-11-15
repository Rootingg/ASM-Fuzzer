; Emits the same edge many times, then one different edge.
; The duplicate identifier must count once, and the flood must not stall the parent.

default rel

%include "syscalls.inc"
%include "macros.inc"
%include "coverage.inc"

section .text
global _start

_start:
    mov ecx, 3000
.again:
    COV 7
    dec ecx
    jnz .again
    COV 9
    EXIT 0
