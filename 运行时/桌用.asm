    .intel_syntax noprefix
    .section .text

# ============================================================
#  _桌_块 —— 给六爻用的最简矩形填充
#
#  六爻没法可靠地压 5 个参数（栈对齐、参数顺序都容易错），
#  所以这里从全局取：g__e6_a1_8cx g__e6_a1_8cy g__e6_a1_8cw g__e6_a1_8ch g__e6_a1_8c_e8_89_b2
#
#  内部直接算地址写内存，不经过 _gfx_fill（避开 _tgt 状态）
# ============================================================
    .globl _桌_块
_桌_块:
    push rbx
    push r12
    push r13
    push r14
    push r15

    # 帧缓冲参数（XBP 4 字节写，必须 4 字节读）
    mov ebx, [0x3000]              # 基址
    mov r10d, [0x3004]             # 字节行跨（大道已 ×4）
    test rbx, rbx
    jz .k_end

    mov r12d, [rip + g__e6_a1_8cx]
    mov r13d, [rip + g__e6_a1_8cy]
    mov r14d, [rip + g__e6_a1_8cw]
    mov r15d, [rip + g__e6_a1_8ch]
    mov eax, [rip + g__e6_a1_8c_e8_89_b2]

    test r14d, r14d
    jle .k_end
    test r15d, r15d
    jle .k_end
    # 越界保护：x/y 必须在屏幕内，w/h 不能超过屏幕
    cmp r12d, 1920
    jae .k_end
    cmp r13d, 1080
    jae .k_end
    cmp r14d, 1920
    ja .k_end
    cmp r15d, 1080
    ja .k_end

    # 起始行地址 = fb + y*pitch + x*4
    mov rsi, r13
    imul rsi, r10
    mov rcx, r12
    shl rcx, 2
    add rsi, rcx
    add rsi, rbx                  # rsi = 当前行起点

.k_row:
    mov rcx, r14                  # 每行 w 个像素
    mov rdi, rsi
.k_col:
    mov [rdi], eax
    add rdi, 4
    dec rcx
    jnz .k_col

    add rsi, r10                  # 下一行
    dec r15
    jnz .k_row

.k_end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# ------------------------------------------------------------
#  _桌_字 —— 画一串 ASCII，参数从全局取
#   g__e6_a1_8ctx g__e6_a1_8cty g__e6_a1_8ctp(串指针) g__e6_a1_8c_e8_89_b2
#  内部直接查字模写像素，不经过 _gfx_text
# ------------------------------------------------------------
    .globl _桌_字
_桌_字:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r11d, [0x3000]
    mov r10d, [0x3004]
    test r11, r11
    jz .z_end

    mov r12d, [rip + g__e6_a1_8ctx]             # x
    mov r13d, [rip + g__e6_a1_8cty]             # y
    mov r14, [rip + g__e6_a1_8ctp]              # 串指针
    mov r15d, [rip + g__e6_a1_8c_e8_89_b2]             # 色
    mov r9, 2                                          # 缩放写死 2（每格 32 像素，不靠跨模块变量）

    test r14, r14
    jz .z_end

.z_char:
    movzx eax, byte ptr [r14]
    test al, al
    jz .z_end
    cmp al, 0x80
    jb .z_ascii
    inc r14
    jmp .z_char

.z_ascii:
    sub eax, 32
    cmp eax, 0
    jge .z_ok
    xor eax, eax
.z_ok:
    shl eax, 5
    lea r8, [rip + _font_ascii]
    add r8, rax                   # r8 = 字形基址

    xor ebx, ebx                  # 行 0..15
.z_row:
    cmp ebx, 16
    jge .z_next
    movzx edx, word ptr [r8 + rbx * 2]

    # 行地址 = fb + (y + 行号*N) * pitch + x*4
    mov rax, rbx
    imul rax, r9
    mov rdi, r13
    add rdi, rax
    imul rdi, r10
    mov rcx, r12
    shl rcx, 2
    add rdi, rcx
    add rdi, r11

    mov ecx, 15                   # 位 15..0（bit15 = 最左）
.z_bit:
    bt edx, ecx
    jnc .z_np
    push rcx
    mov rcx, r9
.z_sx:
    mov [rdi], r15d
    add rdi, 4
    dec rcx
    jnz .z_sx
    pop rcx
    jmp .z_bit2
.z_np:
    mov rax, r9
    shl rax, 2
    add rdi, rax
.z_bit2:
    dec ecx
    jns .z_bit

    inc ebx
    jmp .z_row

.z_next:
    mov rax, 16
    imul rax, r9
    add r12, rax
    inc r14
    jmp .z_char
    jmp .z_char

.z_end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

    .section .data
    # 坐标/色/串指针由 桌.ly 的 ts 声明提供（.comm）
    # 缩放只有这里定义
    .align 8
    .globl _桌缩
_桌缩:   .quad 1
