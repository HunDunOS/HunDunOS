# ===========================================================================
#  C 接口 —— 给 .bao 里的 C 工具用的入口
# 
#  为什么是汇编写：C 的链接器只会找 C 风格的符号名，
#  而新语编出来的符号名是 UTF-8 十六进制（fn__e4_b8_bb），C 用不了。
#  这一层只做转接：C 名字 -> 内核内部。
# 
#  ⚠ 内部调 _gfx_* 时要按【新语约定】压栈（从左到右，第 1 个参数在最深处），
#     不是 C 的从右到左。这是最容易写错的地方。
# ===========================================================================
    .code32
    .intel_syntax noprefix

    .section .bss
k_x:    .space 4
k_y:    .space 4
k_ch:   .space 4
k_nbuf: .space 16

    .section .text
    .globl _capi_init
_capi_init:
    mov dword ptr [k_x], 8
    mov dword ptr [k_y], 8
    ret

# ---- 内部：画 k_ch 里的那个字符，光标前进 ----
k_draw:
    pushad
    mov eax, [k_x]
    push eax
    mov eax, [k_y]
    push eax
    mov eax, offset k_ch
    push eax
    mov eax, 0xE8F0FF
    push eax
    call _gfx_text
    add esp, 16
    add dword ptr [k_x], 8
    popad
    ret

# ---- void k_cls(void) ----
    .globl k_cls
k_cls:
    pushad
    xor eax, eax
    push eax
    push eax
    mov eax, [_gfx_w]
    push eax
    mov eax, [_gfx_h]
    push eax
    mov eax, 0x0A0E18
    push eax
    call _gfx_fill
    add esp, 20
    mov dword ptr [k_x], 8
    mov dword ptr [k_y], 8
    popad
    ret

# ---- void k_putc(int c) ----
    .globl k_putc
k_putc:
    pushad
    mov eax, [esp + 36]
    cmp eax, 10
    je .kp_nl
    mov [k_ch], al
    call k_draw
    jmp .kp_end
.kp_nl:
    mov dword ptr [k_x], 8
    add dword ptr [k_y], 18
    mov eax, [_gfx_h]
    sub eax, 26
    cmp [k_y], eax
    jl .kp_end
    sub dword ptr [k_y], 18
.kp_end:
    popad
    ret

# ---- void k_puts(const char *s) ----
    .globl k_puts
k_puts:
    pushad
    mov esi, [esp + 36]
.ks_loop:
    movzx eax, byte ptr [esi]
    test eax, eax
    jz .ks_end
    push eax
    call k_putc
    add esp, 4
    inc esi
    jmp .ks_loop
.ks_end:
    popad
    ret

# ---- void k_puti(int n) ----
    .globl k_puti
k_puti:
    pushad
    mov eax, [esp + 36]
    mov edi, offset k_nbuf + 15
    mov byte ptr [edi], 0
    mov ecx, 10
    test eax, eax
    jns .ki_pos
    neg eax
    mov ebx, 1
    jmp .ki_conv
.ki_pos:
    xor ebx, ebx
.ki_conv:
    dec edi
    xor edx, edx
    div ecx
    add dl, 48
    mov [edi], dl
    test eax, eax
    jnz .ki_conv
    test ebx, ebx
    jz .ki_out
    dec edi
    mov byte ptr [edi], 45
.ki_out:
    push edi
    call k_puts
    add esp, 4
    popad
    ret

# ---- int k_getc(void) ----  阻塞读一个键
    .globl k_getc
k_getc:
    pushad
.kg_loop:
    call _gfx_key
    test eax, eax
    jz .kg_loop
    mov [esp + 28], eax
    popad
    ret

# ---- int k_tryc(void) ----  不阻塞，没键返回 0
    .globl k_tryc
k_tryc:
    pushad
    call _gfx_key
    mov [esp + 28], eax
    popad
    ret

# ---- void k_rect(int x, int y, int w, int h, int color) ----
    .globl k_rect
k_rect:
    pushad
    mov eax, [esp + 36]
    push eax
    mov eax, [esp + 44]
    push eax
    mov eax, [esp + 52]
    push eax
    mov eax, [esp + 60]
    push eax
    mov eax, [esp + 68]
    push eax
    call _gfx_fill
    add esp, 20
    popad
    ret

# ---- void k_pixel(int x, int y, int color) ----
    .globl k_pixel
k_pixel:
    pushad
    mov eax, [esp + 36]
    push eax
    mov eax, [esp + 44]
    push eax
    mov eax, [esp + 52]
    push eax
    call _gfx_px
    add esp, 12
    popad
    ret
