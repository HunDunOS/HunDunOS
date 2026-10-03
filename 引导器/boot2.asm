# ============================================================================
#  混沌 自研引导器 —— 第二阶段（xboot stage2）
#  路线图阶段 4（自研引导器）+ 阶段 5（自研引导协议 XBP），合并完成
#
#  由第一阶段（0x7C00）跳到 0x7E00 运行。实模式，DS=ES=SS=CS=0x07C0。
#
#  职责：
#    1. 打开 A20
#    2. 取内存大小（INT 15h E801h）
#    3. 用 BIOS 扩展读（INT 13h AH=42h）把内核从光盘读进 0x10000
#    4. 用 VBE 找并设置一个 32 位色、≥800x600 的图形模式
#    5. 建 GDT，进 32 位保护模式
#    6. 在 0x0500 填好 XBP 引导信息块
#    7. EAX=XBP 魔数，EBX=XBP 地址，跳到内核入口
#
#  ★ NovaOS 死掉的两个坑，这里都绕开：
#     · 段基址没处理 —— boot1 已把 CS/DS/ES/SS 全定到 0x07C0
#     · 读盘循环寄存器复用 —— 进度存内存，LBA 与目标段分开寄存器
#  ★ 本文件里所有 [标号] 都是 DS(=0x07C0) 相对，VBE 缓冲区也放在自己的
#    数据段里，所以不需要切段寄存器，也就不会踩"绝对地址 vs 段基址"的坑
# ============================================================================

    .code16
    .intel_syntax noprefix

    .ifndef WITH_VBE
    .set WITH_VBE, 1        /* 默认设图形模式；纯终端版用 --defsym WITH_VBE=0 */
    .endif
    .section .boot2, "ax"
    .globl _stage2

    .set XBP,        0x0500        # 引导信息块（低内存）
    .set KERNEL_SEG, 0x1000        # 内核加载到 0x10000
    .set CHUNK,      32            # 每次读 32 个 2048 字节扇区 = 64 KiB

# ---------------------------------------------------------------------------
#  入口
# ---------------------------------------------------------------------------
_stage2:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    call serial_init
    mov si, offset m_banner
    call print

    # ---- 引导盘号从 XBP+8 取回（boot1 存的）----
    mov al, [XBP + 8]
    mov [boot_drive], al

    call a20_on
    call get_mem

    mov si, offset m_load
    call print
    call load_kernel
    jc .fail
    mov si, offset m_loaded
    call print

    .if WITH_VBE
    call vbe_setup                  # 失败不致命，退回文本模式
    .endif
    # WITH_VBE=0 时不设图形模式，留在 BIOS 文本模式（纯终端用）

    cli
    .byte 0x66                      # 操作数尺寸前缀 → lgdt 读 6 字节（386 形式）
    lgdt [gdt_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    ljmp 0x08:pm_entry

.fail:
    mov si, offset m_fail
    call print
.halt:
    cli
    hlt
    jmp .halt

# ---------------------------------------------------------------------------
#  A20
# ---------------------------------------------------------------------------
a20_on:
    mov ax, 0x2401
    int 0x15
    jc .fast
    cmp ah, 0
    je .done
.fast:
    in al, 0x92
    test al, 2
    jnz .done
    or al, 2
    and al, 0xFE
    out 0x92, al
.done:
    ret

# ---------------------------------------------------------------------------
#  内存大小：INT 15h E801h
# ---------------------------------------------------------------------------
get_mem:
    pusha
    xor cx, cx
    xor dx, dx
    mov ax, 0xE801
    int 0x15
    jc .fallback
    # ★ 不要检查 AH：E801 成功时把"1MB..16MB 的 KB 数"放在 AX 里，
    #   AH 是那个数的【高位】，不是状态码。查 AH 会把大内存误判成失败。
    cmp ax, 0
    je .fallback
    cmp bx, 0
    je .have
    movzx ecx, ax
    movzx edx, bx
    jmp .have
.fallback:
    int 0x12
    movzx ecx, ax
    xor edx, edx
.have:
    shl edx, 6
    add ecx, edx
    add ecx, 1024
    mov [mem_kb], ecx
    popa
    ret

# ---------------------------------------------------------------------------
#  读内核：INT 13h AH=42h 扩展读（光盘逻辑扇区 2048 字节）
# ---------------------------------------------------------------------------
load_kernel:
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc .bad
    cmp bx, 0xAA55
    jne .bad

    mov dword ptr [prog], 0
    mov word ptr [cur_seg], KERNEL_SEG

.rk_loop:
    mov eax, [prog]
    movzx ecx, word ptr [krn_secs]
    test ecx, ecx
    jz .bad
    cmp eax, ecx
    jae .ok
    sub ecx, eax
    cmp ecx, CHUNK
    jbe .chunk
    mov ecx, CHUNK
.chunk:
    mov [dap_count], cx
    mov word ptr [dap_off], 0
    mov ax, [cur_seg]
    mov [dap_seg], ax
    mov eax, [krn_lba]
    add eax, [prog]
    mov [dap_lba], eax

    mov cx, 3
.rk_retry:
    push cx
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, offset dap
    int 0x13
    pop cx
    jnc .rk_ok
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    loop .rk_retry
    jmp .bad

.rk_ok:
    movzx eax, word ptr [dap_count]
    add [prog], eax
    shl eax, 7
    add [cur_seg], ax
    jmp .rk_loop

.ok:
    clc
    ret
.bad:
    stc
    ret

# ---------------------------------------------------------------------------
#  VBE：找一个宽≥800 高≥600 的 32 位直接色模式并设置
#  缓冲区在本映像的数据段里 → 全程 DS=ES=CS，不用切段
# ---------------------------------------------------------------------------
vbe_setup:
    xor ax, ax
    mov es, ax
    mov dword ptr [fb_addr], 0
    mov word ptr [best_mode], 0xFFFF
    mov dword ptr [best_area], 0

    mov di, offset vbe_info_buf
    mov ax, 0x4F00
    int 0x10
    cmp ax, 0x004F
    jne .no

    mov si, [vbe_info_buf + 14]     # 模式列表远指针：偏移
    mov ax, [vbe_info_buf + 16]     #                 段
    mov fs, ax
    mov bx, si

.mode_loop:
    mov cx, fs:[bx]
    cmp cx, 0xFFFF
    je .scan_end
    add bx, 2

    push bx
    mov ax, 0x4F01                  # 取模式信息
    mov di, offset vbe_mode_buf
    int 0x10
    pop bx
    cmp ax, 0x004F
    jne .mode_loop

    cmp byte ptr [vbe_mode_buf + 0x19], 32    # 32 位色
    jne .mode_loop
    cmp byte ptr [vbe_mode_buf + 0x1B], 6     # 直接色
    jne .mode_loop
    cmp dword ptr [vbe_mode_buf + 0x28], 0    # 有线性帧缓冲
    je .mode_loop

    movzx eax, word ptr [vbe_mode_buf + 0x12] # 宽
    movzx edx, word ptr [vbe_mode_buf + 0x14] # 高
    cmp eax, 800
    jb .mode_loop
    cmp edx, 600
    jb .mode_loop

    # 正好 1920x1080 → 立刻用它
    cmp eax, 1920
    jne .keep_best
    cmp edx, 1080
    jne .keep_best
    mov [saved_mode], cx
    jmp .set_it

.keep_best:
    # 否则记住面积最大的一个，扫完再用
    imul eax, edx
    cmp eax, [best_area]
    jbe .mode_loop
    mov [best_area], eax
    mov [best_mode], cx
    jmp .mode_loop

.scan_end:
    mov cx, [best_mode]
    cmp cx, 0xFFFF
    je .no
    mov [saved_mode], cx

.set_it:
    mov bx, cx
    or bx, 0x4000                   # 用线性帧缓冲
    mov ax, 0x4F02
    int 0x10
    cmp ax, 0x004F
    jne .no

    mov ax, 0x4F01                  # 设置后重取一次，数据才准
    mov di, offset vbe_mode_buf
    mov cx, [saved_mode]
    int 0x10

    movzx eax, word ptr [vbe_mode_buf + 0x10]
    mov [fb_pitch], eax
    movzx eax, word ptr [vbe_mode_buf + 0x12]
    mov [fb_w], eax
    movzx eax, word ptr [vbe_mode_buf + 0x14]
    mov [fb_h], eax
    movzx eax, byte ptr [vbe_mode_buf + 0x19]
    mov [fb_bpp], eax
    mov eax, [vbe_mode_buf + 0x28]
    mov [fb_addr], eax
    test eax, eax
    jz .no

    mov si, offset m_mode_ok
    call print
    ret
.no:
    mov dword ptr [fb_addr], 0
    mov si, offset m_no_vbe
    call print
    ret

# ===========================================================================
#  32 位保护模式
# ===========================================================================
    .code32
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x70000

    # ---- 清 BSS ----
    mov edi, [bss_start]
    mov ecx, [bss_end]
    sub ecx, edi
    shr ecx, 2
    xor eax, eax
    rep stosd

    # ---- 填 XBP 引导信息块（0x0500）----
    mov edi, XBP
    mov eax, [xbp_magic]                    # XBP 魔数（用 .ascii，不手算字节序）
    mov [edi + 0], eax
    mov dword ptr [edi + 4], 1              # 协议版本 1
    mov eax, [mem_kb]
    mov [edi + 12], eax                     # 可用内存 KB
    mov eax, [krn_load]
    mov [edi + 16], eax                     # 内核加载地址
    mov eax, [krn_secs]
    shl eax, 11
    mov [edi + 20], eax                     # 内核大小（字节）
    mov eax, [krn_lba]
    mov [edi + 24], eax                     # 内核 LBA
    movzx eax, byte ptr [boot_drive]
    mov [edi + 28], eax                     # 引导盘号
    mov eax, [fb_addr]
    mov [edi + 32], eax                     # 帧缓冲物理地址
    mov eax, [fb_pitch]
    mov [edi + 36], eax                     # 每行字节数
    mov eax, [fb_w]
    mov [edi + 40], eax                     # 宽
    mov eax, [fb_h]
    mov [edi + 44], eax                     # 高
    mov eax, [fb_bpp]
    mov [edi + 48], eax                     # 色深
    mov eax, [krn_entry]
    mov [edi + 52], eax                     # 内核入口

    # ---- 交棒 ----
    mov eax, [xbp_magic]
    mov ebx, XBP
    jmp dword ptr [krn_entry]

# ===========================================================================
#  实模式辅助
# ===========================================================================
    .code16
print:
    pusha
.pr_l:
    lodsb
    or al, al
    jz .pr_done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    mov dx, 0x3F8                   # 同时走串口，方便无头调试
    out dx, al
    jmp .pr_l
.pr_done:
    popa
    ret

# ---- 串口初始化（COM1）----
serial_init:
    pusha
    mov dx, 0x3F9
    xor al, al
    out dx, al                      # 关中断
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al                      # 允许设波特率
    mov dx, 0x3F8
    mov al, 1
    out dx, al                      # 除数低字节 = 1 → 115200
    mov dx, 0x3F9
    xor al, al
    out dx, al
    mov dx, 0x3FB
    mov al, 3
    out dx, al                      # 8N1
    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al                      # FIFO
    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al                      # RTS/DSR
    popa
    ret

# ---- 打印 eax（8 位十六进制）到屏幕+串口 ----
print_hex:
    pusha
    mov ebx, eax
    mov cx, 8
.ph_loop:
    rol ebx, 4
    mov al, bl
    and al, 0x0F
    cmp al, 10
    jb .ph_dig
    add al, 'A' - 10
    jmp .ph_out
.ph_dig:
    add al, '0'
.ph_out:
    mov ah, 0x0E
    int 0x10
    mov dx, 0x3F8
    out dx, al
    dec cx
    jnz .ph_loop
    popa
    ret

# ===========================================================================
#  数据
# ===========================================================================
    .align 8
gdt_start:
    .quad 0x0000000000000000
    .quad 0x00CF9A000000FFFF
    .quad 0x00CF92000000FFFF
gdt_end:
gdt_desc:
    .word gdt_end - gdt_start - 1
    .long gdt_start

    .align 4
# ---- 打包器补丁表：xiso.py 按魔数查找并回填（32 位小端）----
    .globl xboot_patch
xboot_patch:
xboot_magic:
    .ascii "XBOO"
krn_lba:   .long 0                          # +4  内核 LBA（2048 字节扇区）
krn_secs:  .long 0                          # +8  内核扇区数（2048 字节单位）
krn_load:  .long 0                          # +12 内核加载地址
krn_entry: .long 0                          # +16 内核入口地址
bss_start: .long 0                          # +20 BSS 起始
bss_end:   .long 0                          # +24 BSS 结束

# ★ 魔数一律用 .ascii 写，让汇编器去算字节序（人别手算小端 dword）
    .align 4
xbp_magic:
    .ascii "XYBP"

fb_addr:   .long 0
fb_pitch:  .long 0
fb_w:      .long 0
fb_h:      .long 0
fb_bpp:    .long 0
mem_kb:    .long 0
prog:      .long 0
cur_seg:   .word KERNEL_SEG
boot_drive:.byte 0
saved_mode:.word 0
best_mode: .word 0xFFFF
best_area: .long 0

    .align 4
dap:
    .byte 0x10
    .byte 0x00
dap_count: .word 0
dap_off:   .word 0
dap_seg:   .word 0
dap_lba:   .quad 0

    .align 4
vbe_info_buf: .space 512
vbe_mode_buf: .space 256

m_banner:  .asciz "\n[xboot2] HunDun self-hosted bootloader\n"
m_load:    .asciz "[xboot2] loading kernel...\n"
m_loaded:  .asciz "[xboot2] kernel loaded\n"
m_cand:    .asciz "[xboot2] mode candidate 0x"
m_nl:      .asciz "\n"
m_mode_ok: .asciz "[xboot2] graphics mode set\n"
m_no_vbe:  .asciz "[xboot2] no VBE, text mode\n"
m_fail:    .asciz "[xboot2] FAILED\n"
