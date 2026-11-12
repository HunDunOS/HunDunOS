    .intel_syntax noprefix
    .code64
    .section .text
    .globl _start
_start:
    lea rsi, [rip + m1]
    call 打
    mov rsp, 0x70000
    xor rbp, rbp
    mov dx, 0x3F8
    mov al, 74
    out dx, al
    mov r15, 0x2A0040
    mov rbx, r15
    mov ecx, 12
.h1:
    rol rbx, 4
    mov al, bl
    and al, 15
    add al, 48
    cmp al, 58
    jb .h2
    add al, 7
.h2:
    out dx, al
    dec ecx
    jnz .h1
    mov rax, r15
    test rax, rax
    jz .挂
    jmp rax
.挂:
    cli
    hlt
    jmp .挂
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
