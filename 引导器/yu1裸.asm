    .intel_syntax noprefix
    .code64
    .section .text
    .globl _start
_start:
    mov rax, rdi
    add al, 64
    mov dx, 0x3F8
    out dx, al
    cli
    hlt
    jmp _start
