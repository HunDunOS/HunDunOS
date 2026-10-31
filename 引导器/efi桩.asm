# ============================================================================
#  efi桩.asm —— UEFI 下的最小汇编层（纯 64 位 · XBP 协议解析）
#
#  UEFI 一进门就是 64 位长模式 + 恒等映射 + GOP：
#    没有 A20、没有实模式、没有 INT 13h、没有 VBE、没有 32 位过渡
#
#  Dao 的活：
#    1. 拿 GOP（帧缓冲地址先存下来，ExitBootServices 之后还得靠它画）
#    2. 拿 Block I/O —— 一切皆哈希，不认文件名、不认路径
#    3. 按物理 LBA 读 .dao，解 XBP 道标（八个 u64），验道标 / 验头印 /
#       验卦象 / 验指纹，对不上直接停机
#    4. 把机器码铺到落址，画符咒 → ExitBootServices → 跳阴轨入口
#
#  XBP 道标（64 字节，全 u64）：
#     +0 道标 "HUNDUNV1"   +8 卦象(0=全阴 yu0, 63=全阳 yu1)
#     +16 落址   +24 长度   +32 指纹   +40 入口   +48 世代   +56 头印
#
#  MS x64 ABI：RCX, RDX, R8, R9，第 5 个参数在 [rsp+0x20]
# ============================================================================
    .intel_syntax noprefix
    .section .text
    .globl efi_main

# ---------------------------------------------------------------------------
#  FNV-1a 64：rsi = 起点，rcx = 字节数 → r12
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
#  装一条轨：lba, 卦象, 入口槽
# ---------------------------------------------------------------------------
.macro 装轨 lba, 卦, 槽, 纹槽
    # ---- 先读一扇，解道标 ----
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
    mov rcx, 0x31564E55444E5548        # "HUNDUNV1"
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

    # ---- 落址 / 长度 ----
    mov r14, [rip + 块缓冲 + 16]        # 落址
    mov r13, [rip + 块缓冲 + 24]        # 机器码长度
    test r13, r13
    jz .道标错

    # ---- 按长度算页数，批地基 ----
    lea rax, [r13 + 64 + 4095]
    shr rax, 12                         # 页数
    mov [rip + 申请页], rax
    mov [rip + 申请址], r14
    mov rcx, 2                          # AllocateAddress（枚举：Any=0 Max=1 Address=2）
    mov rdx, 1                          # EfiLoaderCode（Data 段在部分固件上是 NX）
    mov r8, rax
    lea r9, [rip + 申请址]
    mov rax, [rbx + 96]
    call qword ptr [rax + 40]
    test rax, rax
    jz 88f
    # ★ 真机：那个物理地址被固件占了 —— 哈希不认地址，另找一块
    mov rcx, 0                          # AllocateAnyPages
    mov rdx, 1                          # EfiLoaderCode
    mov r8, [rip + 申请页]
    lea r9, [rip + 申请址]
    mov rax, [rbx + 96]
    call qword ptr [rax + 40]
    test rax, rax
    jnz .道标错
88:
    mov r14, [rip + 申请址]              # 落址以实际拿到的为准

    # ---- 整块裸读（道标 + 机器码）到落址 ----
    lea rax, [r13 + 64 + 511]
    shr rax, 9                          # 扇区数
    shl rax, 9                          # 换算成字节
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

    # ---- 验机器码指纹 ----
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

    # ---- 入口 = 落址 + 入口偏移 ----
    lea rax, [r14 + 40]
    mov rax, [rax]
    add rax, r14
    add rax, 64                         # 道标占 64 字节，机器码从落址+64 起
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

    # ================= 1. GOP =================
    lea rcx, [rip + GOP_GUID]
    xor rdx, rdx
    lea r8, [rip + _efi_gop]
    mov rax, [rbx + 96]
    call qword ptr [rax + 320]          # LocateProtocol（没有 This 参数）
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

    # 绘制目标先指屏幕
    call _gfx_screen


    # 缩放比 = 屏高 / 400（800 -> 2，1080 -> 2，2160 -> 5），至少 1
    mov rax, [rip + _efi_h]
    xor rdx, rdx
    mov rcx, 400
    div rcx
    test rax, rax
    jnz 77f
    mov rax, 1
77:
    mov [rip + _efi_scale], rax

    # ---- 真机加固：认屏格式 ----
    #  +12 PixelFormat  0=RGB 1=BGR 2=BitMask 3=BltOnly
    #  +16/+20/+24 红/绿/蓝掩码
    mov ecx, [rax + 12]
    mov [rip + _efi_fmt], rcx
    mov r14, rax                        # r14 = Info
    mov ecx, [r14 + 16]
    mov [rip + _mask_r], rcx
    mov ecx, [r14 + 20]
    mov [rip + _mask_g], rcx
    mov ecx, [r14 + 24]
    mov [rip + _mask_b], rcx

    # 移位量 = 掩码里最低位的位置（bsf）
    mov rax, [rip + _mask_r]
    call 算移位
    mov [rip + _sh_r], rax
    mov rax, [rip + _mask_g]
    call 算移位
    mov [rip + _sh_g], rax
    mov rax, [rip + _mask_b]
    call 算移位
    mov [rip + _sh_b], rax

    # ================= 2. Block I/O =================
    mov rcx, [rip + _img]
    lea rdx, [rip + LI_GUID]
    lea r8, [rip + _li]
    mov rax, [rbx + 96]
    call qword ptr [rax + 152]          # HandleProtocol（也没有 This）
    test rax, rax
    jnz .没块设备
    mov rax, [rip + _li]
    test rax, rax
    jz .没块设备
    mov rcx, [rax + 24]                 # DeviceHandle
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

    # ================= 3. 阴 =================
    lea rsi, [rip + 报_阴]
    call 报串
    装轨 60000, 0, 阴入口, 0x7018

    # ================= 4. 阳 =================
    lea rsi, [rip + 报_阳]
    call 报串
    装轨 60100, 63, 阳入口, 0x7020


    # ================= 6. 踹开固件 =================
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
    call qword ptr [rax + 56]           # GetMemoryMap

    mov rcx, [rip + _img]
    mov rdx, [rip + map钥匙]
    mov rax, [rbx + 96]
    call qword ptr [rax + 232]          # ExitBootServices

    # ================= 7. 点火：阴 =================
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

# ---- 重画自检屏（保住调用者的关键寄存器）----
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

# ---- 掩码 → 移位量（rax = 掩码，返回最低位序号）----
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

# ---- 把 ASCII 串转成 UTF-16 吐给 ConOut（rsi = 串）----
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

# ---- 停一下，让滚屏看得见（Stall(微秒)，无 This 参数）----
停:
    push rcx
    push rdx
    mov rcx, 45000                          # 微秒
    mov rax, [rbx + 96]
    call qword ptr [rax + 248]              # Stall
    pop rdx
    pop rcx
    ret

# ---- 打 16 位十六进制（r8）----
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
BIO_GUID:
    .byte 0x21, 0x5b, 0x4e, 0x96, 0x59, 0x64, 0xd2, 0x11
    .byte 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b

报_头:   .asciz "\r\n\r\nHunDunOS  -  XBP boot\r\n\r\n"
报_屏:   .asciz "[ ok ] GOP     fb=0x"
报_w:    .asciz "  w=0x"
报_h:    .asciz "  h=0x"
报_块:   .asciz "[ ok ] BLOCKIO ready\r\n"
报_换行: .asciz "\r\n"
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

    .section .bss
    .align 16
宽缓:       .space 256
块缓冲:     .space 1024
map缓冲:    .space 0x80000
