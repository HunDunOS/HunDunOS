    .intel_syntax noprefix
    .code64
    .section .text.head, "ax"
    .globl _start
_start:
    mov rsp, 0x1F0000
    xor rbp, rbp
    call fn_zx
.停:
    cli
    hlt
    jmp .停
