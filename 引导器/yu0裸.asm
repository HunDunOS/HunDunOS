    .intel_syntax noprefix
    .code64
    .section .text
    .globl _start
_start:
    lea rsi, [rip + m1]
    call 打
    # 阴轨：地基已由固件铺好，这里只宣告 + 停住等内核
停:
    cli
    hlt
    jmp 停
打:
    mov dx, 0x3F8
.l: movzx eax, byte ptr [rsi]
    test al, al
    jz .d
    out dx, al
    inc rsi
    jmp .l
.d: ret
m1: .asciz "\n[yu0] 阴轨基座就位 · Long Mode OK · 页表由固件已建\n"
