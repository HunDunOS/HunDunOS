    .intel_syntax noprefix
    .section .text
    .globl efi_main

FNV:
    mov r12, 0xcbf29ce484222325
    mov rdx, 0x100000001b3
1:
    movzx rax, byte ptr [rsi]
    xor r12, rax
    imul r12, rdx
    inc rsi
    dec rcx
    jnz 1b
    ret

.macro 装轨 lba, 卦, 槽, 纹槽
    mov rcx, [rip + _bio]
    mov rax, [rcx + 8]
    mov rdx, [rax + 8]
    mov r8, \lba
    mov r9, 512
    lea rax, [rip + 块缓冲]
    mov [rsp + 0x20], rax
    mov rax, [rip + _bio]
    call qword ptr [rax + 24]

    mov rax, [rip + 块缓冲]
    mov rcx, 0x31564E55444E5548
    cmp rax, rcx
    jne .道标错

    lea rsi, [rip + 块缓冲]
    mov ecx, 56
    call FNV
    mov rax, [rip + 块缓冲 + 56]
    cmp rax, r12
    jne .道标错

    mov rax, [rip + 块缓冲 + 8]
    cmp rax, \卦
    jne .道标错

    mov r14, [rip + 块缓冲 + 16]
    mov r13, [rip + 块缓冲 + 24]
    test r13, r13
    jz .道标错

    lea rax, [r13 + 64 + 4095]
    shr rax, 12
    mov [rip + 申请页], rax
    mov [rip + 申请址], r14
    mov rcx, 2
    mov rdx, 1
    mov r8, rax
    lea r9, [rip + 申请址]
    mov rax, [rbx + 96]
    call qword ptr [rax + 40]
    test rax, rax
    jz 88f
    mov rcx, 0
    mov rdx, 1
    mov r8, [rip + 申请页]
    lea r9, [rip + 申请址]
    mov rax, [rbx + 96]
    call qword ptr [rax + 40]
    test rax, rax
    jnz .道标错
88:
    mov r14, [rip + 申请址]

    lea rax, [r13 + 64 + 511]
    shr rax, 9
    shl rax, 9
    mov [rip + 读字节], rax

    mov rcx, [rip + _bio]
    mov rax, [rcx + 8]
    mov rdx, [rax + 8]
    mov r8, \lba
    mov r9, [rip + 读字节]
    mov rax, r14
    mov [rsp + 0x20], rax
    mov rax, [rip + _bio]
    call qword ptr [rax + 24]

    lea rsi, [r14 + 64]
    mov rcx, r13
    call FNV
    lea rax, [r14 + 32]
    mov rax, [rax]
    cmp rax, r12
    jne .指纹错

    mov qword ptr [\纹槽], 1

    lea rsi, [rip + 报_印语]
    call 报串
    mov r8, r12
    call 报十六
    lea rsi, [rip + 报_OK]
    call 报串

    lea rax, [r14 + 40]
    mov rax, [rax]
    add rax, r14
    add rax, 64
    mov [rip + \槽], rax

.endm

efi_main:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x40

    mov rbx, rdx
    mov [rip + _img], rcx
    mov [rip + _sys], rdx
    mov qword ptr [0x7060], 0
    mov qword ptr [0x7070], 0
    mov qword ptr [0x7078], 0
    lea rsi, [rip + 报_头]
    call 报串
    mov qword ptr [0x7000], 0
    mov qword ptr [0x7008], 0
    mov qword ptr [0x7010], 0
    mov qword ptr [0x7018], 0
    mov qword ptr [0x7020], 0
    mov qword ptr [0x7028], 0
    mov qword ptr [0x7030], 0
    mov qword ptr [0x7038], 0
    mov qword ptr [0x7040], 0
    mov qword ptr [0x7048], 0

    lea rcx, [rip + GOP_GUID]
    xor rdx, rdx
    lea r8, [rip + _efi_gop]
    mov rax, [rbx + 96]
    call qword ptr [rax + 320]
    test rax, rax
    jnz .挂
    mov rax, [rip + _efi_gop]
    test rax, rax
    jz .挂
    mov r12, [rax + 24]
    mov rax, [r12 + 24]
    mov [rip + _efi_fb], rax
    mov rax, [r12 + 8]
    mov ecx, [rax + 4]
    mov [rip + _efi_w], rcx
    mov ecx, [rax + 8]
    mov [rip + _efi_h], rcx
    mov ecx, [rax + 32]
    mov [rip + _efi_pitch], rcx

    lea rsi, [rip + 报_屏]
    call 报串
    mov r8, [rip + _efi_fb]
    call 报十六
    lea rsi, [rip + 报_w]
    call 报串
    mov r8, [rip + _efi_w]
    call 报十六
    lea rsi, [rip + 报_h]
    call 报串
    mov r8, [rip + _efi_h]
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串

    call _gfx_screen


    push rbx
    call _win_demo
    pop rbx

    mov rax, [rip + _efi_h]
    xor rdx, rdx
    mov rcx, 400
    div rcx
    test rax, rax
    jnz 77f
    mov rax, 1
77:
    mov [rip + _efi_scale], rax

    mov ecx, [rax + 12]
    mov [rip + _efi_fmt], rcx
    mov r14, rax
    mov ecx, [r14 + 16]
    mov [rip + _mask_r], rcx
    mov ecx, [r14 + 20]
    mov [rip + _mask_g], rcx
    mov ecx, [r14 + 24]
    mov [rip + _mask_b], rcx

    mov rax, [rip + _mask_r]
    call 算移位
    mov [rip + _sh_r], rax
    mov rax, [rip + _mask_g]
    call 算移位
    mov [rip + _sh_g], rax
    mov rax, [rip + _mask_b]
    call 算移位
    mov [rip + _sh_b], rax

    mov rcx, [rip + _img]
    lea rdx, [rip + LI_GUID]
    lea r8, [rip + _li]
    mov rax, [rbx + 96]
    call qword ptr [rax + 152]
    test rax, rax
    jnz .没块设备
    mov rax, [rip + _li]
    test rax, rax
    jz .没块设备
    mov rcx, [rax + 24]
    lea rdx, [rip + BIO_GUID]
    lea r8, [rip + _bio]
    mov rax, [rbx + 96]
    call qword ptr [rax + 152]
    test rax, rax
    jnz .没块设备
    mov rax, [rip + _bio]
    test rax, rax
    jz .没块设备
    lea rsi, [rip + 报_块]
    call 报串

    lea rsi, [rip + 报_阴]
    call 报串


    mov dx, 0x3F8
    mov al, 49
    out dx, al
    装轨 60000, 0, 阴入口, 0x7018
    mov dx, 0x3F8
    mov al, 50
    out dx, al

    lea rsi, [rip + 报_阳]
    call 报串
    装轨 60100, 63, 阳入口, 0x7020

    mov dx, 0x3F8
    mov al, 65
    out dx, al
    装轨 60200, 21, 合入口, 0x7048
    mov dx, 0x3F8
    mov al, 67
    out dx, al
    mov rax, [rip + 合入口]
    mov [0x7080], rax


    lea rsi, [rip + 报_跳]
    call 报串

    mov qword ptr [rip + map大小], 0x80000
    lea rcx, [rip + map大小]
    lea rdx, [rip + map缓冲]
    lea r8, [rip + map钥匙]
    lea r9, [rip + 描述大小]
    lea rax, [rip + 描述版本]
    mov [rsp + 0x20], rax
    mov rax, [rbx + 96]
    call qword ptr [rax + 56]

    mov rcx, [rip + _img]
    mov rdx, [rip + map钥匙]
    mov rax, [rbx + 96]
    call qword ptr [rax + 232]

    mov rax, [rip + 阴入口]
    test rax, rax
    jz .挂
    jmp rax

.道标错:
    lea rsi, [rip + 报_坏]
    call 报串
    jmp .挂
.指纹错:
    lea rsi, [rip + 报_坏]
    call 报串
    jmp .挂
.没块设备:
    lea rsi, [rip + 报_无]
    call 报串
.挂:
    jmp .挂

刷新:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x20
    add rsp, 0x20
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

算移位:
    test rax, rax
    jz 3f
    xor rcx, rcx
1:
    test rax, 1
    jnz 2f
    shr rax, 1
    inc rcx
    jmp 1b
2:
    mov rax, rcx
    ret
3:
    xor eax, eax
    ret

AP过程:
    mov rax, 1
    lock xadd qword ptr [0x7078], rax
    inc rax
    mov rcx, rax
    shl rcx, 13
    mov rsp, 0x80000
    add rsp, rcx
    mov rdi, rax
.wait0:
    cmp qword ptr [0x7060], 0
    je .wait0
.hang:
    cli
    hlt
    jmp .hang

报串:
    push rcx
    push rdx
    push rsi
    push rdi
    lea rdi, [rip + 宽缓]
1:
    movzx eax, byte ptr [rsi]
    test al, al
    jz 2f
    mov word ptr [rdi], ax
    add rdi, 2
    inc rsi
    jmp 1b
2:
    mov word ptr [rdi], 0
    mov rcx, [rbx + 64]
    lea rdx, [rip + 宽缓]
    call qword ptr [rcx + 8]
    call 停
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    ret

停:
    push rcx
    push rdx
    mov rcx, 45000
    mov rax, [rbx + 96]
    call qword ptr [rax + 248]
    pop rdx
    pop rcx
    ret

报十六:
    push rcx
    push rdx
    push r8
    push r9
    mov ecx, 16
    mov r9, r8
1:
    rol r9, 4
    mov rax, r9
    and al, 15
    add al, '0'
    cmp al, 58
    jb 2f
    add al, 7
2:
    mov byte ptr [rip + 单字], al
    mov byte ptr [rip + 单字 + 1], 0
    push rcx
    push r9
    mov rcx, [rbx + 64]
    lea rdx, [rip + 单字]
    call qword ptr [rcx + 8]
    pop r9
    pop rcx
    dec ecx
    jnz 1b
    pop r9
    pop r8
    pop rdx
    pop rcx
    ret

    .section .data
    .align 16
GOP_GUID:
    .byte 0xde, 0xa9, 0x42, 0x90, 0xdc, 0x23, 0x38, 0x4a
    .byte 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a
LI_GUID:
    .byte 0xa1, 0x31, 0x1b, 0x5b, 0x62, 0x95, 0xd2, 0x11
    .byte 0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
MP_GUID:
    .byte 0x05, 0xa6, 0xdd, 0x3f, 0x6e, 0xa7, 0x46, 0x4f
    .byte 0xad, 0x29, 0x12, 0xf4, 0x53, 0x1b, 0x3d, 0x08
BIO_GUID:
    .byte 0x21, 0x5b, 0x4e, 0x96, 0x59, 0x64, 0xd2, 0x11
    .byte 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b

报_头:   .asciz "\r\n\r\nHunDunOS  -  XBP boot\r\n\r\n"
报_屏:   .asciz "[ ok ] GOP     fb=0x"
报_w:    .asciz "  w=0x"
报_h:    .asciz "  h=0x"
报_块:   .asciz "[ ok ] BLOCKIO ready\r\n"
报_换行: .asciz "\r\n"
厂0:    .long 0
厂1:    .long 0
厂2:    .long 0
        .long 0
温:     .quad 0
报_厂:   .asciz "[ ok ] cpu  "
报_无温: .asciz "[ -- ] temp 无传感器\r\n"
报_温:   .asciz "[ ok ] temp TjMax-0x"
报_核:   .asciz "[ ok ] cores 0x"
报_启:   .asciz "  enabled 0x"
报_AP:   .asciz "[ .. ] all AP on stage\r\n"
报_AP1:  .asciz "AP "
报_阴:   .asciz "[ ok ] yin  LBA 60000 hash 0x"
报_阳:   .asciz "[ ok ] yang LBA 60100 hash 0x"
报_印语: .asciz ""
报_OK:   .asciz "\r\n"
报_坏:   .asciz "\r\n[XBP] SEAL/HASH MISMATCH - refused\r\n"
报_无:   .asciz "\r\n[XBP] no block device\r\n"
报_跳:   .asciz "[ ok ] ExitBootServices\r\n[ .. ] ignite yu0\r\n"

    .align 8
    .globl _efi_gop
_efi_gop:   .quad 0
    .globl _efi_fb
_efi_fb:    .quad 0
    .globl _efi_w
_efi_w:     .quad 0
    .globl _efi_h
_efi_h:     .quad 0
    .globl _efi_pitch
_efi_pitch: .quad 0
    .globl _efi_scale
_efi_scale: .quad 1
    .globl 单字
单字:       .quad 0
_li:        .quad 0
_bio:       .quad 0
_img:       .quad 0
    .globl _mp
_mp:        .quad 0
    .globl _sys
_sys:       .quad 0
_cores:     .quad 0
_enabled:   .quad 0
申请址:     .quad 0
map大小:    .quad 0
map钥匙:    .quad 0
描述大小:   .quad 0
描述版本:   .quad 0
阴入口:     .quad 0
    .globl _efi_fmt
_efi_fmt:   .quad 0
    .globl _mask_r
_mask_r:    .quad 0
    .globl _mask_g
_mask_g:    .quad 0
    .globl _mask_b
_mask_b:    .quad 0
    .globl _sh_r
_sh_r:      .quad 0
    .globl _sh_g
_sh_g:      .quad 0
    .globl _sh_b
_sh_b:      .quad 0
申请页:     .quad 0
读字节:     .quad 0
阳入口:     .quad 0
合入口:     .quad 0

    .section .bss
    .align 16
宽缓:       .space 256
块缓冲:     .space 1024
map缓冲:    .space 0x80000
