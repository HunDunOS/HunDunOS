    .intel_syntax noprefix
    .section .text

# ============================================================
#  绘字 —— 严格分三层
#
#  行为：走一遍字符串，每个字符算出一个 16×16 点阵地址
#  样式：点阵位 → 屏幕上 N×N 个方块（N = _xy_scale）
#  结构：帧缓冲基址 + 行跨 + 坐标换算
#
#  只有一处会写内存：[结构] 算出的那一个像素地址
#  三层各自独立，坏哪层一眼看得出
# ============================================================

#  ----------------------------------------------------------
#  结构和样式公共部分：给定 (x, y) 和颜色，画一个 N×N 方块
#    rdi = x   rsi = y   r15d = 色   r9 = 缩放
#    r10 = 行跨   rbp = 帧缓冲基址
# ----------------------------------------------------------
    .globl _xy_draw_text
_xy_draw_text:
    # 保存
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    # ---- [结构] 读帧缓冲参数 ----
    mov ebp, [0x520]              # 基址（32 位写，必须 32 位读）
    mov r10d, [0x524]             # 行跨
    test rbp, rbp
    jz .dt_end

    # ---- 参数 ----
    mov r12, rdi                  # 当前 x
    mov r13, rsi                  # 当前 y
    mov r14, rdx                  # 串指针
    mov r15d, ecx                 # 色

    # ---- [行为] 逐字符 ----
.dt_char:
    movzx eax, byte ptr [r14]
    test al, al
    jz .dt_end

    cmp al, 0x80
    jb .dt_ascii
    inc r14                       # 非 ASCII：跳过 1 字节
    jmp .dt_char

.dt_ascii:
    sub eax, 32
    cmp eax, 0
    jge .dt_ok
    xor eax, eax
.dt_ok:
    shl eax, 5
    lea r8, [rip + _font_ascii]
    add r8, rax                   # r8 = 字形基址（32 字节 = 16 行 × 2）

    # ---- [样式] 16 行，每行 16 位 ----
    xor r9d, r9d                  # 行号
.dt_row:
    cmp r9, 16
    jge .dt_next

    movzx ebx, word ptr [r8 + r9 * 2]    # 该行 16 位（ebx 低 16 位有效）

    xor ecx, ecx                  # 列号 0..15
.dt_col:
    bt ebx, ecx                   # 从低位试（第 0 位 = 最左点）
    jnc .dt_colnext

    # 这一个点 → 屏幕坐标：x + col*N，y + row*N
    mov rax, r12
    mov rdx, rcx
    imul rdx, [rip + _xy_scale]
    add rax, rdx                  # 屏幕 x

    mov rdx, r9                   # 行号
    imul rdx, [rip + _xy_scale]   # × N
    add rdx, r13                  # + 字 y = 屏幕 y

    # ---- [结构] 算地址并画 N×N ----
    call 画块

.dt_colnext:
    inc ecx
    cmp ecx, 16
    jb .dt_col

    inc r9
    jmp .dt_row

.dt_next:
    mov rax, 8
    imul rax, [rip + _xy_scale]
    add r12, rax
    inc r14
    jmp .dt_char

.dt_end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

# ----------------------------------------------------------
#  画块：rax = 屏幕 x，rdx = 屏幕 y，画 N×N 个像素
#  用 r8/r11 之外的所有寄存器都要保护
# ----------------------------------------------------------
画块:
    push rcx
    push rdx
    push rsi
    push rdi
    push rbx

    mov rbx, rdx                  # 起始 y
    mov rsi, rax                  # 起始 x
    mov r8, [rip + _xy_scale]     # N

    xor rdi, rdi                  # 纵向计数
.blk_y:
    cmp rdi, r8
    jge .blk_end

    # 该行地址 = fb + (y+dy)*pitch + x*4
    mov rax, rbx
    add rax, rdi
    imul rax, r10
    mov rcx, rsi
    shl rcx, 2
    add rax, rcx
    add rax, rbp                  # rax = 行起点

    xor rcx, rcx                  # 横向计数
.blk_x:
    cmp rcx, r8
    jge .blk_xend
    mov [rax], r15d
    add rax, 4
    inc rcx
    jmp .blk_x
.blk_xend:

    inc rdi
    jmp .blk_y

.blk_end:
    pop rbx
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    ret

    .section .data
    .align 8
    .globl _xy_scale
_xy_scale:  .quad 2
