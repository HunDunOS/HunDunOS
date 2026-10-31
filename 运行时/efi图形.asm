# ============================================================================
#  efi图形.asm —— UEFI 下的帧缓冲运行时（纯 64 位）
#
#  只实现六爻内建用得到的那几件：
#      屏宽 / 屏高 / 绘点 / 绘块 / 绘字
#  帧缓冲地址和屏参由 efi桩.asm 填好（GOP 直接给，不需要 VBE）
#
#  参数约定：从左到右压栈，每参数 8 字节
#      第 1 个参数 [rsp + 8]，第 n 个 [rsp + 8n]
# ============================================================================
    .intel_syntax noprefix
    .section .text

# ---- 屏宽 / 屏高 ----
    .globl _tgt
_tgt:        .quad 0
    .globl _tgt_pitch
_tgt_pitch:  .quad 0

    .globl _gfx_getw
_gfx_getw:
    mov rax, [rip + _efi_w]
    ret

# ---- 把绘制目标切到屏幕 ----
    .globl _gfx_screen
_gfx_screen:
    mov rax, [rip + _efi_fb]
    mov [rip + _tgt], rax
    mov rax, [rip + _efi_pitch]
    mov [rip + _tgt_pitch], rax
    ret

    .globl _gfx_geth
_gfx_geth:
    mov rax, [rip + _efi_h]
    ret

    .globl _gfx_getfb
_gfx_getfb:
    mov rax, [rip + _efi_fb]
    ret

    .globl _gfx_getpitch
_gfx_getpitch:
    mov rax, [rip + _efi_pitch]
    ret

# ---- 写点：rcx=x rdx=y r15d=色（按 _efi_scale 放大成方块）----
写点:
    push rax
    push r8
    push r9
    push r10
    push r11
    mov r8, [rip + _efi_scale]
    xor r9, r9
.dy:
    cmp r9, r8
    jge .done
    xor r10, r10
.dx:
    cmp r10, r8
    jge .dye
    mov r11, rdx
    add r11, r9
    imul r11, [rip + _tgt_pitch]
    mov rax, rcx
    add rax, r10
    shl rax, 2
    add r11, rax
    add r11, [rip + _tgt]
    mov eax, r15d
    mov [r11], eax
    inc r10
    jmp .dx
.dye:
    inc r9
    jmp .dy
.done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rax
    ret

# ---- 颜色编码：eax = 0x00RRGGBB → eax = 真机上该写的值 ----
#  fmt 0/1 = 标准 32bpp（直通），fmt 2 = BitMask（按掩码移位），其它直通
编码色:
    push rcx
    push rdx
    push rbx
    mov r11d, eax
    mov rax, [rip + _efi_fmt]
    cmp rax, 2
    jne .enc_raw
    # r = (c>>16)&0FF , g = (c>>8)&0FF , b = c&0FF
    mov ebx, r11d
    shr ebx, 16
    and ebx, 0xFF
    mov rcx, [rip + _sh_r]
    shl rbx, cl
    mov edx, r11d
    shr edx, 8
    and edx, 0xFF
    mov rcx, [rip + _sh_g]
    shl rdx, cl
    or  rbx, rdx
    mov edx, r11d
    and edx, 0xFF
    mov rcx, [rip + _sh_b]
    shl rdx, cl
    or  rbx, rdx
    mov eax, ebx
    jmp .enc_out
.enc_raw:
    mov eax, r11d
.enc_out:
    pop rbx
    pop rdx
    pop rcx
    ret

# ---- 绘点( x, y, 色 ) ----
    .globl _gfx_px
_gfx_px:
    mov r8, [rsp + 8]
    mov r9, [rsp + 16]
    mov eax, [rsp + 24]
    call 编码色
    mov r10, [rip + _tgt]
    test r10, r10
    jz .px_end
    mov r11, [rip + _tgt_pitch]
    imul r9, r11
    lea r8, [r8 * 4]
    add r9, r8
    add r9, r10
    mov [r9], eax
.px_end:
    ret

# ---- 绘块( x, y, 宽, 高, 色 ) ----
    .globl _gfx_fill
_gfx_fill:
    push rbx
    mov rdi, [rsp + 48]             # x（第 1 个，最深）
    mov rsi, [rsp + 40]             # y
    mov r8,  [rsp + 32]             # 宽
    mov r9,  [rsp + 24]             # 高
    mov eax, [rsp + 16]             # 色（最后压）
    call 编码色
    mov r10, [rip + _tgt]
    test r10, r10
    jz .fl_end
    test r8, r8
    jle .fl_end
    test r9, r9
    jle .fl_end
    mov r11, [rip + _efi_pitch]
.fl_row:
    test r9, r9
    jle .fl_end
    mov rcx, r8
    mov rdx, rsi
    imul rdx, r11
    lea rbx, [rdi * 4]
    add rdx, rbx
    add rdx, r10
.fl_col:
    test rcx, rcx
    jle .fl_next
    mov [rdx], eax
    add rdx, 4
    dec rcx
    jmp .fl_col
.fl_next:
    inc rsi
    dec r9
    jmp .fl_row
.fl_end:
    pop rbx
    ret

# ---- 绘字( x, y, 串, 色 ) → 返回宽度 ----
    .globl _gfx_text
_gfx_text:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, [rsp + 72]             # x
    mov r13, [rsp + 64]             # y
    mov r14, [rsp + 56]             # 串（UTF-8）
    mov eax, [rsp + 48]
    call 编码色
    mov r15d, eax                   # 色（编码后）
    mov rbx, r12
    mov r11, [rip + _tgt]
    test r11, r11
    jz .t_end

.t_loop:
    movzx eax, byte ptr [r14]
    test al, al
    jz .t_end
    cmp al, 0x80
    jb .t_ascii

    # ---- 3 字节 UTF-8 ----
    and eax, 0x0F
    shl eax, 12
    movzx ecx, byte ptr [r14 + 1]
    and ecx, 0x3F
    shl ecx, 6
    or eax, ecx
    movzx ecx, byte ptr [r14 + 2]
    and ecx, 0x3F
    or eax, ecx
    add r14, 3

    # ---- 二分找字模 ----
    push rsi
    push rdi
    xor esi, esi
    mov edi, [_font_cjk_count]
    dec edi
.t_find:
    cmp esi, edi
    jg .t_nofont
    mov ecx, esi
    add ecx, edi
    shr ecx, 1
    mov edx, [_font_cjk_uni + rcx * 4]
    cmp edx, eax
    je .t_hit
    jl .t_lo
    lea edi, [rcx - 1]
    jmp .t_find
.t_lo:
    lea esi, [rcx + 1]
    jmp .t_find
.t_hit:
    mov rax, rcx
    shl rax, 5
    lea r8, [rip + _font_cjk_data]
    add r8, rax
    pop rdi
    pop rsi
    jmp .t_draw
.t_nofont:
    pop rdi
    pop rsi
    add rbx, 16
    jmp .t_loop

.t_ascii:
    add r14, 1
    sub eax, 32
    cmp eax, 0
    jge .t_ok
    xor eax, eax
.t_ok:
    shl eax, 5
    lea r8, [rip + _font_ascii]
    add r8, rax

.t_draw:
    xor r9d, r9d
.t_row:
    cmp r9, 16
    jge .t_next
    movzx eax, word ptr [r8 + r9 * 2]
    xor r10d, r10d
.t_col:
    cmp r10, 16
    jge .t_rowend
    test eax, 0x8000
    jz .t_skip
    push r8
    push r9
    push r10
    mov rcx, r10
    imul rcx, [rip + _efi_scale]
    add rcx, rbx
    mov rdx, r9
    imul rdx, [rip + _efi_scale]
    add rdx, r13
    call 写点
    pop r10
    pop r9
    pop r8
.t_skip:
    shl eax, 1
    inc r10
    jmp .t_col
.t_rowend:
    inc r9
    jmp .t_row
.t_next:
    mov rax, [rip + _efi_scale]
    shl rax, 4
    add rbx, rax
    jmp .t_loop

.t_end:
    mov rax, rbx
    sub rax, r12
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
