    .intel_syntax noprefix
    .code64
    .section .text
    .globl _start
_start:
    lea rsi, [rip + m1]
    call 打
    ret
打:
    mov dx, 0x3F8
.l: movzx eax, byte ptr [rsi]
    test al, al
    jz .d
    out dx, al
    inc rsi
    jmp .l
.d: ret
m1: .asciz "[yu1] 阳轨沉睡于 0x200000，等待内核唤醒\n"
