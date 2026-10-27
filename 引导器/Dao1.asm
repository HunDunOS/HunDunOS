# ============================================================================
#  混沌 自研引导器 —— 第一阶段（512 字节 El Torito 引导扇区）
#  路线图阶段 4：替换 isolinux.bin
#
#  ★ 地址模型（整个引导器统一）：
#      BIOS 把本扇区载入到 07C0:0000。我们第一件事就是远跳到 0000:7C00，
#      把 CS 归零，然后 DS/ES/SS 也全部归零。
#      这样**标号的值就是线性地址**，不用再做 段:偏移 换算，
#      也就不会踩 NovaOS 那个"段基址没处理"的坑。
#
#  职责（只做三件事，512 字节够用）：
#    1. 段全部归零，栈放到映像下方
#    2. 把 BIOS 给的引导盘号存进 XBP 引导信息块（0x0500）
#    3. 跳到第二阶段（0x7E00，紧跟本扇区，El Torito 一次载入）
#
#  汇编：as --32 boot1.asm -o boot1.o（与 boot2.o 一起用 xboot.ld 链接）
# ============================================================================

    .code16
    .intel_syntax noprefix
    .section .boot1, "ax"
    .globl _start

    .set XBP,         0x0500        # 引导信息块（低内存）

_start:
    cli
    ljmp 0x0000:start_here          # ★ CS 归零 → 之后一律线性地址

start_here:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00                  # 栈在映像下方（0x7A00 一带，空闲区）
    sti

    mov [XBP + 8], dl               # 引导盘号（第二阶段读盘要用）

    mov si, msg_hello
    call print
    jmp _stage2                     # 就近跳到 0x7E00

# ---- 打印以 0 结尾的串（si）----
print:
    pusha
.pr_l:
    lodsb
    or al, al
    jz .pr_done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp .pr_l
.pr_done:
    popa
    ret

msg_hello:   .asciz "[xboot1] "

    .space 510 - (. - _start)
    .word 0xAA55
