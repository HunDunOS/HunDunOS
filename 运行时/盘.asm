    .intel_syntax noprefix
    .code64
    .section .text

# ============================================================================
#  ATA PIO 读写（主盘，LBA28）
#    _ata读  rdi=LBA  rsi=缓冲
#    _ata写  rdi=LBA  rsi=缓冲
#    返回 rax: 0 成功 / 1 失败
# ============================================================================

# ---- 等 BSY 清、DRDY 置 ----
就绪:
    push rcx
    push rdx
    mov dx, 0x1F7
    xor ecx, ecx
1:
    in al, dx
    test al, 0x80
    jnz 2f
    test al, 0x40
    jnz 3f
2:
    inc ecx
    cmp ecx, 0x100000
    ja 3f
    jmp 1b
3:
    pop rdx
    pop rcx
    ret

# ---- 等 DRQ ----
数据就绪:
    push rcx
    push rdx
    mov dx, 0x1F7
    xor ecx, ecx
1:
    in al, dx
    test al, 0x08
    jnz 3f
    inc ecx
    cmp ecx, 0x100000
    ja 3f
    jmp 1b
3:
    pop rdx
    pop rcx
    ret

# ---- 发 LBA48 地址（上限 2^48 扇区 = 128 TB）----
# LBA48 规则：先写高 3 字节，再写低 3 字节
发址:
    push rbx
    push rdx
    mov rbx, rdi

    # 扇区数：高字节 0，低字节 1
    mov dx, 0x1F2
    xor al, al
    out dx, al
    mov al, 1
    out dx, al

    # LBA 高 3 字节（rdi >> 24 / 32 / 40）
    mov dx, 0x1F3
    mov rax, rbx
    shr rax, 24
    out dx, al
    mov dx, 0x1F4
    mov rax, rbx
    shr rax, 32
    out dx, al
    mov dx, 0x1F5
    mov rax, rbx
    shr rax, 40
    out dx, al

    # LBA 低 3 字节（rdi >> 0 / 8 / 16）
    mov dx, 0x1F3
    mov rax, rbx
    out dx, al
    mov dx, 0x1F4
    mov rax, rbx
    shr rax, 8
    out dx, al
    mov dx, 0x1F5
    mov rax, rbx
    shr rax, 16
    out dx, al

    # 驱动器/头：0x40 = LBA 模式，不用高 4 位
    mov dx, 0x1F6
    mov al, 0x40
    out dx, al

    pop rdx
    pop rbx
    ret

# ---- 读一个扇区 ----
    .globl _ata读
_ata读:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    call 就绪
    call 发址
    mov dx, 0x1F7
    mov al, 0x24
    out dx, al
    call 数据就绪
    mov rbx, rsi
    mov rcx, 128
    mov dx, 0x1F0
1:
    in eax, dx
    mov [rbx], eax
    add rbx, 4
    dec rcx
    jnz 1b
    xor eax, eax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

# ---- 写一个扇区 ----
    .globl _ata写
_ata写:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    call 就绪
    call 发址
    mov dx, 0x1F7
    mov al, 0x34
    out dx, al
    call 数据就绪
    mov rbx, rsi
    mov rcx, 128
    mov dx, 0x1F0
1:
    mov eax, [rbx]
    out dx, eax
    add rbx, 4
    dec rcx
    jnz 1b
    call 就绪
    xor eax, eax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
