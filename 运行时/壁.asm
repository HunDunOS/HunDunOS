    .intel_syntax noprefix
    .section .text

# ============================================================
#  _壁_铺 —— 把 PPM 铺满帧缓冲
#
#  PPM P6 格式：
#     P6\n<宽> <高>\n<最大值>\n<RGB 裸数据>
#  头部用空白分隔，三个字段，之后就是像素
#
#  PPM 里是 RGB，帧缓冲要 0x00RRGGBB 的小端 32 位 → 直接按字节拷贝即可
#  （x86 小端：内存里 R G B 00 = 0x00BBGGRR，注意要调顺序）
# ============================================================
    .globl _壁_铺
_壁_铺:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov ebx, [0x520]              # 帧缓冲
    mov r10d, [0x524]             # 字节行跨
    test rbx, rbx
    jz .w_end

    mov r12, [_壁址]              # PPM 数据地址
    test r12, r12
    jz .w_end

    mov r13d, [_壁宽]             # 图宽（像素）
    mov r14d, [_壁高]             # 图高
    test r13d, r13d
    jle .w_end
    test r14d, r14d
    jle .w_end

    # r12 已跳过头部，指向 RGB 数据
    xor r15, r15                  # 行号
.w_row:
    cmp r15, r14
    jge .w_end

    # 目标行地址 = fb + y*pitch
    mov rdi, r15
    imul rdi, r10
    add rdi, rbx

    mov rcx, r13                  # 每行像素数
.w_col:
    movzx eax, byte ptr [r12]         # R
    movzx edx, byte ptr [r12 + 1]     # G
    movzx r8d, byte ptr [r12 + 2]     # B
    # 拼成 0x00RRGGBB
    shl eax, 16
    shl edx, 8
    or  eax, edx
    or  eax, r8d
    mov [rdi], eax

    add r12, 3
    add rdi, 4
    dec rcx
    jnz .w_col

    inc r15
    jmp .w_row

.w_end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# ------------------------------------------------------------
#  _壁_找头 —— 跳过 PPM 头部，把数据指针和宽高填进全局
#   入参：_壁源 = PPM 起始地址
# ------------------------------------------------------------
    .globl _壁_找头
_壁_找头:
    push rbx
    push r12

    mov r12, [_壁源]
    test r12, r12
    jz .h_fail

    # 跳过 "P6"
    cmp byte ptr [r12], 'P'
    jne .h_fail
    inc r12
    cmp byte ptr [r12], '6'
    jne .h_fail
    inc r12

    # 跳过空白
.h_s1:
    movzx eax, byte ptr [r12]
    cmp al, ' '
    je .h_i1
    cmp al, 10
    je .h_i1
    cmp al, 13
    je .h_i1
    cmp al, 9
    je .h_i1
    jmp .h_w
.h_i1:
    inc r12
    jmp .h_s1

    # 读宽
.h_w:
    xor ebx, ebx
.h_wl:
    movzx eax, byte ptr [r12]
    cmp al, '0'
    jb .h_wd
    cmp al, '9'
    ja .h_wd
    sub eax, '0'
    imul ebx, ebx, 10
    add ebx, eax
    inc r12
    jmp .h_wl
.h_wd:
    mov [_壁宽], rbx

    # 跳过空白
.h_s2:
    movzx eax, byte ptr [r12]
    cmp al, ' '
    jb .h_h
    inc r12
    jmp .h_s2

    # 读高
.h_h:
    xor ebx, ebx
.h_hl:
    movzx eax, byte ptr [r12]
    cmp al, '0'
    jb .h_hd
    cmp al, '9'
    ja .h_hd
    sub eax, '0'
    imul ebx, ebx, 10
    add ebx, eax
    inc r12
    jmp .h_hl
.h_hd:
    mov [_壁高], rbx

    # 跳过空白 + 读最大值（255）
.h_s3:
    movzx eax, byte ptr [r12]
    cmp al, ' '
    jb .h_max
    inc r12
    jmp .h_s3
.h_max:
    xor ebx, ebx
.h_ml:
    movzx eax, byte ptr [r12]
    cmp al, '0'
    jb .h_md
    cmp al, '9'
    ja .h_md
    sub eax, '0'
    imul ebx, ebx, 10
    add ebx, eax
    inc r12
    jmp .h_ml
.h_md:
    # 跳过分隔符（单个字节 0x0A 或 0x0D 0x0A）
    movzx eax, byte ptr [r12]
    cmp al, 13
    jne .h_p1
    inc r12
.h_p1:
    inc r12

    mov [_壁址], r12
    mov eax, 1
    jmp .h_ret
.h_fail:
    xor eax, eax
.h_ret:
    pop r12
    pop rbx
    ret

    .section .data
    .align 8
    .globl _壁源
_壁源:   .quad 0
    .globl _壁址
_壁址:   .quad 0
    .globl _壁宽
_壁宽:   .quad 0
    .globl _壁高
_壁高:   .quad 0
    .globl 壁果
壁果:    .quad 0
