    .intel_syntax noprefix
    .section .text
    .globl efi_main

FNV:
    mov r8, 0xcbf29ce484222325
    mov r9, 0x100000001b3
    test rcx, rcx
    jz 2f
1:
    movzx rax, byte ptr [rsi]
    xor r8, rax
    imul r8, r9
    inc rsi
    dec rcx
    jnz 1b
2:
    mov rax, r8
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
    mov r13, rax
    mov rax, [rip + 块缓冲 + 56]
    cmp rax, r13
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
    # ★ 指定地址分配失败 → 直接报出来，不回退
    #   回退到任意地址会让模块代码的 rip 相对寻址全错（比崩溃更难查）
    lea rsi, [rip + 报_装败]
    call 报串
    mov r8, [rip + 申请页]
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串
    jmp .道标错
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
    push rax
    lea rax, [r14 + 32]
    mov rax, [rax]
    pop rdx
    cmp rax, rdx
    jne .指纹错

    mov qword ptr [\纹槽], 1

    lea rsi, [rip + 报_印语]
    call 报串
    mov r8, rdx
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


    # ★ 临时停用：_win_demo 里 _gfx_fill 的参数栈偏移错 4 个 qword，
    #    x 取到颜色 0x3FD0C0 → 写到 fb+4MB 外 → #PF。象测自己会画，先跳过它。
    # push rbx
    # call _win_demo
    # pop rbx

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

    # ================= PCI 扫卡：找真网卡 =================
    lea rsi, [rip + 报_PCI]
    call 报串
    xor r12, r12
.扫总:
    cmp r12, 4
    jae .扫完
    xor r13, r13
.扫设:
    cmp r13, 32
    jae .下总
    mov eax, 0x80000000
    mov ecx, r12d
    shl ecx, 16
    or eax, ecx
    mov ecx, r13d
    shl ecx, 11
    or eax, ecx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    cmp eax, 0xFFFFFFFF
    je .下设
    mov r14d, eax
    mov eax, 0x80000000
    mov ecx, r12d
    shl ecx, 16
    or eax, ecx
    mov ecx, r13d
    shl ecx, 11
    or eax, ecx
    add eax, 8
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    shr eax, 24
    cmp eax, 2
    jne .下设
    lea rsi, [rip + 报_网]
    call 报串
    mov r8d, r14d
    and r8, 0xFFFF
    call 报十六
    mov al, 58
    call 报字节
    mov r8d, r14d
    shr r8, 16
    and r8, 0xFFFF
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串
.下设:
    inc r13
    jmp .扫设
.下总:
    inc r12
    jmp .扫总
.扫完:


    # ================= 找 NVMe：class 01 / sub 08 / progif 02 =================
.找NVMe:
    xor r12, r12
.n扫总:
    cmp r12, 4
    jae .n扫完
    xor r13, r13
.n扫设:
    cmp r13, 32
    jae .n下总
    mov eax, 0x80000000
    mov ecx, r12d
    shl ecx, 16
    or eax, ecx
    mov ecx, r13d
    shl ecx, 11
    or eax, ecx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    cmp eax, 0xFFFFFFFF
    je .n下设
    mov r14d, eax
    # 读 class（offset 8）低 24 位 = progif/subclass/class
    mov eax, 0x80000000
    mov ecx, r12d
    shl ecx, 16
    or eax, ecx
    mov ecx, r13d
    shl ecx, 11
    or eax, ecx
    add eax, 8
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    shr eax, 8
    and eax, 0xFFFF00
    cmp eax, 0x010802
    jne .n下设
    lea rsi, [rip + 报_NVMe]
    call 报串
    mov r8d, r14d
    and r8, 0xFFFF
    call 报十六
    mov al, 58
    call 报字节
    mov r8d, r14d
    shr r8, 16
    and r8, 0xFFFF
    call 报十六
    # 读 BAR0（offset 0x10）
    mov eax, 0x80000000
    mov ecx, r12d
    shl ecx, 16
    or eax, ecx
    mov ecx, r13d
    shl ecx, 11
    or eax, ecx
    add eax, 0x10
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov r8d, eax
    lea rsi, [rip + 报_MMIO]
    call 报串
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串
.n下设:
    inc r13
    jmp .n扫设
.n下总:
    inc r12
    jmp .n扫总
.n扫完:

    装轨 60000, 0, 阴入口, 0x7018

    # ==================== 多核：真的把 AP 拉起来 ====================
    # BootServices->LocateProtocol(MP_GUID, 0, &_mp)
    # ★ 偏移 320，不是 152 —— 152 是 LocateHandleBuffer（5 参数，BIO 那段用的就是它）
    lea rcx, [rip + MP_GUID]
    xor rdx, rdx
    lea r8, [rip + _mp]
    mov rax, [rbx + 96]
    call qword ptr [rax + 320]
    mov r15, rax
    lea rsi, [rip + 报_MP码]
    call 报串
    mov r8, r15
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串
    test r15, r15
    jnz .无MP

    mov rax, [rip + _mp]
    mov r15, rax
    lea rsi, [rip + 报_MPpt]
    call 报串
    mov r8, r15
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串
    test r15, r15
    jz .无MP

    # _mp->GetNumberOfProcessors(This, &核数, &已启)   [偏移 40]
    mov rcx, r15
    lea rdx, [rip + _核数]
    lea r8, [rip + _已启]
    call qword ptr [r15 + 40]
    mov r14, rax
    lea rsi, [rip + 报_MPgp]
    call 报串
    mov r8, r14
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串
    test r14, r14
    jnz .无MP

    # 报核数
    lea rsi, [rip + 报_核]
    call 报串
    mov r8, [rip + _核数]
    call 报十六
    lea rsi, [rip + 报_启]
    call 报串
    mov r8, [rip + _已启]
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串

    # 放行标记清零、到位计数清零（AP 先用独立地址 0x7F00/0x7F08）
    mov qword ptr [0x7F00], 0
    mov qword ptr [0x7F08], 0

    # _mp->StartupAllAPs(This, AP过程, SingleThread=1, 0, 0, 0, 0)  [偏移 216]
    mov rcx, [rip + _mp]
    lea rdx, [rip + AP过程]
    mov r8, 1
    xor r9, r9
    mov qword ptr [rsp + 0x20], 0
    mov qword ptr [rsp + 0x28], 0
    mov qword ptr [rsp + 0x30], 0
    mov rax, [rip + _mp]
    call qword ptr [rax + 216]

    # 等最多一小会儿，看有几个 AP 报到
    mov r12, 0
.等AP:
    inc r12
    cmp r12, 0x2000000
    ja .AP到位
    cmp qword ptr [0x7F00], 0
    je .等AP

.AP到位:
    lea rsi, [rip + 报_AP]
    call 报串
    mov r8, [rip + 0x7F00]
    test r8, r8
    jz .AP零
    call 报十六
    lea rsi, [rip + 报_换行]
    call 报串
    # 放行：AP 各自去 hlt 等着领任务
    mov qword ptr [0x7F08], 1
    jmp .AP完

.AP零:
    lea rsi, [rip + 报_AP0]
    call 报串

.AP完:
.无MP:
    # ================================================================
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

    装轨 60608, 44, 因时空, 0x7050
    mov rax, [rip + 因时空]
    mov [0x7090], rax

    装轨 60600, 45, 回收入口, 0x7058
    mov rax, [rip + 回收入口]
    mov [0x70A0], rax

    装轨 60624, 46, 象入口, 0x7060
    mov rax, [rip + 象入口]
    mov [0x70B0], rax

    装轨 60632, 47, 历入口, 0x7068
    mov rax, [rip + 历入口]
    mov [0x70C0], rax

    装轨 60640, 48, 数入口, 0x7070
    mov rax, [rip + 数入口]
    mov [0x70D0], rax

    装轨 60648, 49, 数测入口, 0x7078

    # 填XBP：帧缓冲四件套（模块都靠这个找屏幕）
    mov eax, [rip + _efi_fb]
    mov dword ptr [0x520], eax
    mov eax, [rip + _efi_pitch]
    mov dword ptr [0x524], eax
    mov eax, [rip + _efi_w]
    mov dword ptr [0x528], eax
    mov eax, [rip + _efi_h]
    mov dword ptr [0x52C], eax
    mov qword ptr [0x500], 0x50425958


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

.挂桌面:
    jmp .挂桌面

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

报字节:
    push rax
    push rcx
    push rdx
    mov [rip + 单字], al
    mov byte ptr [rip + 单字 + 1], 0
    mov rcx, [rbx + 64]
    lea rdx, [rip + 单字]
    call qword ptr [rcx + 8]
    pop rdx
    pop rcx
    pop rax
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
报_NVMe: .asciz "[ ok ] NVMe  "
报_MMIO: .asciz "  BAR0=0x"
报_PCI:  .asciz "[ .. ] PCI scan: find NIC\r\n"
报_网:   .asciz "[ ok ] NIC  "
报_核:   .asciz "[ ok ] cores 0x"
报_启:   .asciz "  enabled 0x"
报_MPh:   .asciz "[ .. ] MP handles ret=0x"
报_MPn:   .asciz "  count=0x"
报_MP码:  .asciz "[ .. ] MP locate ret=0x"
报_MPpt:  .asciz "[ .. ] MP this=0x"
报_MPgp:  .asciz "[ .. ] GetNumProc ret=0x"
报_AP:   .asciz "[ ok ] AP on stage 0x"
报_AP0:  .asciz "[ ok ] AP on stage 0 (single core)\r\n"
报_AP1:  .asciz "AP "
报_阴:   .asciz "[ ok ] yin  LBA 60000 hash 0x"
报_阳:   .asciz "[ ok ] yang LBA 60100 hash 0x"
报_印语: .asciz ""
报_OK:   .asciz "\r\n"
报_坏:   .asciz "\r\n[XBP] SEAL/HASH MISMATCH - refused\r\n"
报_装败: .asciz "\r\n[XBP] AllocateAddress FAILED pages=0x"
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
    .globl _mp
_mp:        .quad 0
_MP数:      .quad 0
_MP缓:      .quad 0
_核数:      .quad 0
_已启:      .quad 0
_img:       .quad 0
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
因时空:     .quad 0
回收入口:   .quad 0
象入口:     .quad 0
历入口:     .quad 0
数入口:     .quad 0
数测入口:   .quad 0

    .section .bss
    .align 16
宽缓:       .space 256
块缓冲:     .space 1024
map缓冲:    .space 0x80000
