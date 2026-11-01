; Burns CPU until the parent kills it. Used to prove the wall-clock timeout.

section .text
global _start

_start:
.spin:
    jmp .spin
