# ============================================================================
#  混沌 图形与输入运行时（图形.asm）
#
#  内核的一部分，由 ld 直接链进去；新语代码通过内建函数调用。
#
#  ★ 参数顺序约定（必须和新语自己的调用约定一致，别按 C 的习惯想）：
#      新语调用函数时是"从左到右"依次 push 的，
#      所以进入被调用函数时：
#          最后一个参数在 [esp+4]，倒数第二个在 [esp+8]……
#          第 1 个参数在 [esp + 4*n]
#      本文件所有函数开头都用 pushad（32 字节），因此再多 32：
#          参数 i（0 起，共 n 个）在 [esp + 36 + 4*(n-1-i)]
#      举例：绘点(色) → [esp+36]；绘点(y) → [esp+40]；绘点(x) → [esp+44]
#
#  颜色一律 0x00RRGGBB。VBE 32bpp 线性帧缓冲的字节序正好是 B,G,R,X，
#  所以直接把 0x00RRGGBB 写进显存就是对的，不需要任何转换。
# ============================================================================

    .code32
    .intel_syntax noprefix

# ---------------------------------------------------------------------------
#  状态
# ---------------------------------------------------------------------------
    .section .data
    .globl _gfx_w, _gfx_h, _gfx_fb, _gfx_pitch
_gfx_fb:    .long 0
_gfx_pitch: .long 0
_gfx_w:     .long 0
_gfx_h:     .long 0
_gfx_mem:   .long 0
_pit_last:  .long 0
_pit_acc:   .long 0
_ms_x:      .long 400
_ms_y:      .long 300
_ms_btn:    .long 0
_ms_cyc:    .byte 0
_ms_b0:     .byte 0
_ms_b1:     .byte 0
_ms_b2:     .byte 0
_kb_shift:  .byte 0
_kb_ext:    .byte 0
_kb_head:   .long 0
_kb_tail:   .long 0
_kb_last:   .long 0
_mc_tmp:    .byte 0

    .section .bss
    .align 4
_kb_buf:    .space 64
_bm_ptr:    .space 4
_bm_x:      .space 4
_bm_y:      .space 4
_bm_color:  .space 4
_bm_bits:   .space 4
_bl_base:   .space 4
_bl_rows:   .space 4
_gt_x0:     .space 4
_gt_ret:    .space 4
_gn_buf:    .space 16
_gn_neg:    .space 1
_gp_ret:    .space 4

# ---------------------------------------------------------------------------
#  宏：把一个通道混合进 [edi]（edi=目标 ecx=源色 ebp=透明度）
# ---------------------------------------------------------------------------
    .macro BLENDCH sh
    mov eax, [edi]
    mov ebx, eax
    shr ebx, \sh
    and ebx, 0xFF
    mov edx, ecx
    shr edx, \sh
    and edx, 0xFF
    sub edx, ebx
    imul edx, ebp
    sar edx, 8
    add edx, ebx
    and edx, 0xFF
    shl edx, \sh
    mov eax, 0xFF
    shl eax, \sh
    not eax
    and [edi], eax
    or [edi], edx
    .endm

    .section .text

# ===========================================================================
#  初始化（EBX = XBP 引导信息块地址）
# ===========================================================================
    .globl _gfx_init
_gfx_init:
    pushad
    mov eax, [ebx + 32]
    mov [_gfx_fb], eax
    mov eax, [ebx + 36]
    mov [_gfx_pitch], eax
    mov eax, [ebx + 40]
    mov [_gfx_w], eax
    mov eax, [ebx + 44]
    mov [_gfx_h], eax
    mov eax, [ebx + 12]
    mov [_gfx_mem], eax

    mov eax, [_gfx_w]
    shr eax, 1
    mov [_ms_x], eax
    mov eax, [_gfx_h]
    shr eax, 1
    mov [_ms_y], eax

    call _pit_read
    mov [_pit_last], eax
    call _mouse_init
    popad
    ret

# ===========================================================================
#  计时
# ===========================================================================
    .globl _pit_read
_pit_read:
    push ebx
    push ecx
    push edx
    xor al, al
    mov dx, 0x43
    out dx, al
    mov dx, 0x40
    in al, dx
    mov cl, al
    in al, dx
    mov ch, al
    movzx eax, cx
    pop edx
    pop ecx
    pop ebx
    ret

    .globl _gfx_ms
_gfx_ms:
    push ebx
    push ecx
    push edx
    call _pit_read
    mov ecx, [_pit_last]
    mov [_pit_last], eax
    sub ecx, eax
    and ecx, 0xFFFF
    add [_pit_acc], ecx
    mov eax, [_pit_acc]
    xor edx, edx
    mov ecx, 1193
    div ecx
    pop edx
    pop ecx
    pop ebx
    ret

    .globl _gfx_sleep
_gfx_sleep:                         # 睡(n)：参数在 [esp+4]
    push ebx
    call _gfx_ms
    mov ebx, eax
    add ebx, [esp + 8]
.sl_l:
    push ebx
    call _gfx_ms
    pop ebx
    cmp eax, ebx
    jb .sl_l
    pop ebx
    ret

# ===========================================================================
#  属性
# ===========================================================================
    .globl _gfx_getw
_gfx_getw:      mov eax, [_gfx_w]     ; ret
    .globl _gfx_geth
_gfx_geth:      mov eax, [_gfx_h]     ; ret
    .globl _gfx_getfb
_gfx_getfb:     mov eax, [_gfx_fb]    ; ret
    .globl _gfx_getpitch
_gfx_getpitch:  mov eax, [_gfx_pitch] ; ret
    .globl _gfx_getmem
_gfx_getmem:    mov eax, [_gfx_mem]   ; ret

# ---- CMOS 实时时钟（BCD → 十进制）----
_rtc_get:                           # 入 al = 寄存器号，出 eax
    push edx
    out 0x70, al
    in al, 0x71
    movzx eax, al
    mov edx, eax
    and eax, 0x0F
    shr edx, 4
    imul edx, 10
    add eax, edx
    pop edx
    ret

    .globl _gfx_hour
_gfx_hour:
    mov al, 4
    jmp _rtc_get
    .globl _gfx_min
_gfx_min:
    mov al, 2
    jmp _rtc_get
    .globl _gfx_sec
_gfx_sec:
    xor al, al
    jmp _rtc_get

# ===========================================================================
#  绘点( x, y, 色 )
# ===========================================================================
    .globl _gfx_px
_gfx_px:
    pushad
    mov ebx, [_gfx_fb]
    test ebx, ebx
    jz .px_end
    mov eax, [esp + 44]             # x
    test eax, eax
    js .px_end
    cmp eax, [_gfx_w]
    jae .px_end
    mov edx, [esp + 40]             # y
    test edx, edx
    js .px_end
    cmp edx, [_gfx_h]
    jae .px_end
    imul edx, [_gfx_pitch]
    add edx, ebx
    lea edx, [edx + eax*4]
    mov eax, [esp + 36]             # 色
    mov [edx], eax
.px_end:
    popad
    ret

# ===========================================================================
#  绘块( x, y, 宽, 高, 色 )
# ===========================================================================
    .globl _gfx_fill
_gfx_fill:
    pushad
    mov ebx, [_gfx_fb]
    test ebx, ebx
    jz .fl_end
    mov edi, [esp + 52]             # x
    mov esi, [esp + 48]             # y
    mov ecx, [esp + 44]             # 宽
    mov edx, [esp + 40]             # 高
    mov eax, [esp + 36]             # 色
    test ecx, ecx
    jle .fl_end
    test edx, edx
    jle .fl_end
    test edi, edi
    jns .fl_x0
    add ecx, edi
    xor edi, edi
.fl_x0:
    test esi, esi
    jns .fl_y0
    add edx, esi
    xor esi, esi
.fl_y0:
    mov ebp, [_gfx_w]
    sub ebp, edi
    cmp ecx, ebp
    jle .fl_x1
    mov ecx, ebp
.fl_x1:
    mov ebp, [_gfx_h]
    sub ebp, esi
    cmp edx, ebp
    jle .fl_y1
    mov edx, ebp
.fl_y1:
    test ecx, ecx
    jle .fl_end
    test edx, edx
    jle .fl_end
    mov ebp, [_gfx_pitch]
    imul ebp, esi
    add ebp, ebx
    lea ebp, [ebp + edi*4]
.fl_row:
    mov edi, ebp
    mov esi, ecx
.fl_col:
    mov [edi], eax
    add edi, 4
    dec esi
    jnz .fl_col
    add ebp, [_gfx_pitch]
    dec edx
    jnz .fl_row
.fl_end:
    popad
    ret

# ===========================================================================
#  绘框( x, y, 宽, 高, 色 )
# ===========================================================================
    .globl _gfx_frame
_gfx_frame:
    pushad
    mov edi, [esp + 52]
    mov esi, [esp + 48]
    mov ecx, [esp + 44]
    mov edx, [esp + 40]
    mov eax, [esp + 36]
    push eax                        # 上边
    push 1
    push ecx
    push esi
    push edi
    call _gfx_fill
    add esp, 20
    mov edi, [esp + 52]
    mov esi, [esp + 48]
    mov ecx, [esp + 44]
    mov edx, [esp + 40]
    mov eax, [esp + 36]
    dec edx
    add esi, edx
    push eax                        # 下边
    push 1
    push ecx
    push esi
    push edi
    call _gfx_fill
    add esp, 20
    mov edi, [esp + 52]
    mov esi, [esp + 48]
    mov ecx, [esp + 44]
    mov edx, [esp + 40]
    mov eax, [esp + 36]
    push eax                        # 左边
    push edx
    push 1
    push esi
    push edi
    call _gfx_fill
    add esp, 20
    mov edi, [esp + 52]
    mov esi, [esp + 48]
    mov ecx, [esp + 44]
    mov edx, [esp + 40]
    mov eax, [esp + 36]
    dec ecx
    add edi, ecx
    push eax                        # 右边
    push edx
    push 1
    push esi
    push edi
    call _gfx_fill
    add esp, 20
    popad
    ret

# ===========================================================================
#  绘块混( x, y, 宽, 高, 色, 透明度 )
# ===========================================================================
    .globl _gfx_fillblend
_gfx_fillblend:
    pushad
    mov ebx, [_gfx_fb]
    test ebx, ebx
    jz .fb_end
    mov edi, [esp + 56]             # x
    mov esi, [esp + 52]             # y
    mov ecx, [esp + 48]             # 宽
    mov edx, [esp + 44]             # 高
    mov eax, [esp + 40]             # 色
    mov [esp + 40], eax
    mov eax, [esp + 36]             # 透明度
    test eax, eax
    jz .fb_end
    cmp eax, 255
    jbe .fb_a0
    mov eax, 255
.fb_a0:
    mov [esp + 36], eax
    test ecx, ecx
    jle .fb_end
    test edx, edx
    jle .fb_end
    test edi, edi
    jns .fb_x0
    add ecx, edi
    xor edi, edi
.fb_x0:
    test esi, esi
    jns .fb_y0
    add edx, esi
    xor esi, esi
.fb_y0:
    mov ebp, [_gfx_w]
    sub ebp, edi
    cmp ecx, ebp
    jle .fb_x1
    mov ecx, ebp
.fb_x1:
    mov ebp, [_gfx_h]
    sub ebp, esi
    cmp edx, ebp
    jle .fb_y1
    mov edx, ebp
.fb_y1:
    test ecx, ecx
    jle .fb_end
    test edx, edx
    jle .fb_end
    mov ebp, [_gfx_pitch]
    imul ebp, esi
    add ebp, ebx
    lea ebp, [ebp + edi*4]
    mov [_bl_base], ebp
    mov [_bl_rows], edx
.fb_row:
    mov edi, [_bl_base]
    mov esi, ecx
.fb_col:
    mov ecx, [esp + 40]             # 源色
    mov ebp, [esp + 36]             # 透明度
    BLENDCH 0
    BLENDCH 8
    BLENDCH 16
    add edi, 4
    dec esi
    jnz .fb_col
    mov eax, [_gfx_pitch]
    add [_bl_base], eax
    dec dword ptr [_bl_rows]
    jnz .fb_row
.fb_end:
    popad
    ret

# ===========================================================================
#  字形位图绘制（_bm_* 由调用方填好）
#    位图：每行 2 字节，bit15 = 最左像素
# ===========================================================================
_glyph_blit:
    pushad
    mov ebx, [_gfx_fb]
    test ebx, ebx
    jz .gb_end
    mov edi, [_bm_x]
    test edi, edi
    js .gb_end
    cmp edi, [_gfx_w]
    jae .gb_end
    xor ebp, ebp
.gb_row:
    cmp ebp, 16
    jae .gb_end
    mov eax, [_bm_y]
    add eax, ebp
    js .gb_nextrow
    cmp eax, [_gfx_h]
    jae .gb_nextrow
    imul eax, [_gfx_pitch]
    add eax, ebx
    mov edx, [_bm_x]
    lea edi, [eax + edx*4]
    mov esi, [_bm_ptr]
    lea esi, [esi + ebp*2]
    movzx edx, word ptr [esi]
    mov ecx, [_bm_bits]
    mov esi, [_bm_color]
.gb_col:
    test edx, 0x8000
    jz .gb_skip
    mov [edi], esi
.gb_skip:
    shl edx, 1
    add edi, 4
    dec ecx
    jnz .gb_col
.gb_nextrow:
    inc ebp
    jmp .gb_row
.gb_end:
    popad
    ret

# ===========================================================================
#  找汉字字形：eax = 码点 → eax = 索引（-1 = 没有）
# ===========================================================================
_cjk_find:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    xor esi, esi
    mov edi, [_font_cjk_count]
    dec edi
.cf_l:
    cmp esi, edi
    jg .cf_no
    mov ebx, esi
    add ebx, edi
    shr ebx, 1
    mov ecx, [_font_cjk_uni + ebx*4]
    cmp ecx, eax
    je .cf_hit
    jl .cf_lo
    lea edi, [ebx-1]
    jmp .cf_l
.cf_lo:
    lea esi, [ebx+1]
    jmp .cf_l
.cf_hit:
    mov eax, ebx
    jmp .cf_out
.cf_no:
    mov eax, -1
.cf_out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

# ===========================================================================
#  绘字( x, y, 串, 色 ) → 返回宽度
# ===========================================================================
    .globl _gfx_text
_gfx_text:
    pushad
    mov edi, [esp + 48]             # x
    mov ebp, [esp + 44]             # y
    mov esi, [esp + 40]             # 串
    mov eax, [esp + 36]             # 色
    mov [_bm_color], eax
    mov [_bm_y], ebp
    mov [_gt_x0], edi
.gt_loop:
    movzx eax, byte ptr [esi]
    test eax, eax
    jz .gt_end
    cmp eax, 0x80
    jb .gt_ascii
    cmp eax, 0xE0
    jb .gt_2b
    cmp eax, 0xF0
    jb .gt_3b
    and eax, 0x07
    shl eax, 6
    movzx ecx, byte ptr [esi+1]
    and ecx, 0x3F
    or eax, ecx
    shl eax, 6
    movzx ecx, byte ptr [esi+2]
    and ecx, 0x3F
    or eax, ecx
    shl eax, 6
    movzx ecx, byte ptr [esi+3]
    and ecx, 0x3F
    or eax, ecx
    add esi, 4
    jmp .gt_cjk
.gt_3b:
    and eax, 0x0F
    shl eax, 6
    movzx ecx, byte ptr [esi+1]
    and ecx, 0x3F
    or eax, ecx
    shl eax, 6
    movzx ecx, byte ptr [esi+2]
    and ecx, 0x3F
    or eax, ecx
    add esi, 3
    jmp .gt_cjk
.gt_2b:
    and eax, 0x1F
    shl eax, 6
    movzx ecx, byte ptr [esi+1]
    and ecx, 0x3F
    or eax, ecx
    add esi, 2
.gt_cjk:
    push esi
    push edi
    call _cjk_find
    pop edi
    pop esi
    test eax, eax
    js .gt_wide_skip
    shl eax, 5                      # 每字形 32 字节
    add eax, offset _font_cjk_data
    mov [_bm_ptr], eax
    mov [_bm_x], edi
    mov dword ptr [_bm_bits], 16
    push esi
    push edi
    call _glyph_blit
    pop edi
    pop esi
.gt_wide_skip:
    add edi, 16
    jmp .gt_loop
.gt_ascii:
    inc esi                         # ★ 单字节字符：指针 +1（多字节的在上面已加）
    cmp eax, 32
    jb .gt_asc_skip
    cmp eax, 126
    ja .gt_asc_skip
    sub eax, 32
    shl eax, 5                      # 每字形 32 字节
    add eax, offset _font_ascii
    mov [_bm_ptr], eax
    mov [_bm_x], edi
    mov dword ptr [_bm_bits], 8
    push esi
    push edi
    call _glyph_blit
    pop edi
    pop esi
.gt_asc_skip:
    add edi, 8
    jmp .gt_loop
.gt_end:
    mov eax, edi
    sub eax, [_gt_x0]
    mov [_gt_ret], eax
    popad
    mov eax, [_gt_ret]
    ret

# ===========================================================================
#  输入：键盘 + 鼠标（PS/2，轮询）
# ===========================================================================
_poll_wbuf:
    push ecx
    push edx
    mov ecx, 100000
.pw_l:
    mov dx, 0x64
    in al, dx
    test al, 2
    jz .pw_ok
    dec ecx
    jnz .pw_l
.pw_ok:
    pop edx
    pop ecx
    ret

_poll_rbuf:
    push ecx
    push edx
    mov ecx, 100000
.pr_l:
    mov dx, 0x64
    in al, dx
    test al, 1
    jnz .pr_ok
    dec ecx
    jnz .pr_l
.pr_ok:
    pop edx
    pop ecx
    ret

_mouse_cmd:
    push edx
    mov [_mc_tmp], al
    call _poll_wbuf
    mov dx, 0x64
    mov al, 0xD4
    out dx, al
    call _poll_wbuf
    mov dx, 0x60
    mov al, [_mc_tmp]
    out dx, al
    call _poll_rbuf
    mov dx, 0x60
    in al, dx
    pop edx
    ret

_mouse_init:
    pushad
    call _poll_wbuf
    mov dx, 0x64
    mov al, 0xA8
    out dx, al
    call _poll_wbuf
    mov dx, 0x64
    mov al, 0x20
    out dx, al
    call _poll_rbuf
    mov dx, 0x60
    in al, dx
    mov bl, al
    or bl, 2
    and bl, 0xDF
    call _poll_wbuf
    mov dx, 0x64
    mov al, 0x60
    out dx, al
    call _poll_wbuf
    mov dx, 0x60
    mov al, bl
    out dx, al
    mov al, 0xF6
    call _mouse_cmd
    mov al, 0xF4
    call _mouse_cmd
    popad
    ret

_kb_put:                            # al = 值
    pushad
    mov ecx, [_kb_head]
    mov ebx, ecx
    inc ebx
    and ebx, 63
    cmp ebx, [_kb_tail]
    je .kp_full
    mov [_kb_buf + ecx], al
    mov [_kb_head], ebx
.kp_full:
    popad
    ret

_kbd_decode:                        # al = 扫描码
    pushad
    mov bl, al
    cmp bl, 0xE0
    jne .kd_ne
    mov byte ptr [_kb_ext], 1
    jmp .kd_end
.kd_ne:
    test bl, 0x80
    jz .kd_down
    and bl, 0x7F
    cmp bl, 0x2A
    je .kd_sr
    cmp bl, 0x36
    je .kd_sr
    jmp .kd_end
.kd_sr:
    mov byte ptr [_kb_shift], 0
    jmp .kd_end
.kd_down:
    cmp bl, 0x2A
    je .kd_sp
    cmp bl, 0x36
    je .kd_sp
    cmp byte ptr [_kb_ext], 1
    je .kd_arrow
    movzx ebx, bl
    movzx eax, byte ptr [_sctab + ebx]
    test eax, eax
    jz .kd_end
    cmp byte ptr [_kb_shift], 0
    je .kd_put
    movzx eax, byte ptr [_sctab_shift + ebx]
.kd_put:
    mov [_kb_last], eax
    call _kb_put
    jmp .kd_end
.kd_sp:
    mov byte ptr [_kb_shift], 1
    jmp .kd_end
.kd_arrow:
    mov byte ptr [_kb_ext], 0
    movzx eax, bl
    cmp eax, 0x48
    jne .kd_a1
    mov eax, 0x11
    jmp .kd_put
.kd_a1:
    cmp eax, 0x50
    jne .kd_a2
    mov eax, 0x12
    jmp .kd_put
.kd_a2:
    cmp eax, 0x4B
    jne .kd_a3
    mov eax, 0x13
    jmp .kd_put
.kd_a3:
    cmp eax, 0x4D
    jne .kd_end
    mov eax, 0x14
    jmp .kd_put
.kd_end:
    popad
    ret

    .globl _input_poll
_input_poll:
    pushad
    mov ecx, 32
.ip_l:
    push ecx
    mov dx, 0x64
    in al, dx
    pop ecx
    test al, 1
    jz .ip_end
    test al, 0x20
    jz .ip_kbd
    mov dx, 0x60
    in al, dx
    mov bl, [_ms_cyc]
    test bl, bl
    jnz .ip_m1
    mov [_ms_b0], al
    inc byte ptr [_ms_cyc]
    jmp .ip_next
.ip_m1:
    cmp bl, 1
    jne .ip_m2
    mov [_ms_b1], al
    inc byte ptr [_ms_cyc]
    jmp .ip_next
.ip_m2:
    mov [_ms_b2], al
    mov byte ptr [_ms_cyc], 0
    mov al, [_ms_b0]
    test al, 0x08
    jz .ip_next
    and eax, 7
    mov [_ms_btn], eax
    movzx eax, byte ptr [_ms_b1]
    mov bl, [_ms_b0]
    test bl, 0x10
    jz .ip_mx
    or eax, 0xFFFFFF00
.ip_mx:
    mov ebx, eax
    movzx eax, byte ptr [_ms_b2]
    mov dl, [_ms_b0]
    test dl, 0x20
    jz .ip_my
    or eax, 0xFFFFFF00
.ip_my:
    mov edx, eax
    neg edx
    mov eax, [_ms_x]
    add eax, ebx
    cmp eax, 0
    jg .ip_cx0
    xor eax, eax
.ip_cx0:
    mov ebx, [_gfx_w]
    dec ebx
    cmp eax, ebx
    jle .ip_cx1
    mov eax, ebx
.ip_cx1:
    mov [_ms_x], eax
    mov eax, [_ms_y]
    add eax, edx
    cmp eax, 0
    jg .ip_cy0
    xor eax, eax
.ip_cy0:
    mov ebx, [_gfx_h]
    dec ebx
    cmp eax, ebx
    jle .ip_cy1
    mov eax, ebx
.ip_cy1:
    mov [_ms_y], eax
    jmp .ip_next
.ip_kbd:
    mov dx, 0x60
    in al, dx
    call _kbd_decode
.ip_next:
    dec ecx
    jnz .ip_l
.ip_end:
    popad
    ret

    .globl _gfx_key
_gfx_key:
    call _input_poll
    mov ecx, [_kb_tail]
    cmp ecx, [_kb_head]
    je .gk_none
    movzx eax, byte ptr [_kb_buf + ecx]
    inc ecx
    and ecx, 63
    mov [_kb_tail], ecx
    ret
.gk_none:
    xor eax, eax
    ret

    .globl _gfx_msx
_gfx_msx:
    call _input_poll
    mov eax, [_ms_x]
    ret

    .globl _gfx_msy
_gfx_msy:
    call _input_poll
    mov eax, [_ms_y]
    ret

    .globl _gfx_msbtn
_gfx_msbtn:
    call _input_poll
    mov eax, [_ms_btn]
    ret

    .globl _gfx_getpx
_gfx_getpx:                         # 取点( x, y ) → 色
    pushad
    xor eax, eax
    mov ebx, [_gfx_fb]
    test ebx, ebx
    jz .gp_end
    mov edi, [esp + 40]             # x（2 个参数：最后一个在 +36）
    cmp edi, [_gfx_w]
    jae .gp_end
    mov esi, [esp + 36]             # y
    cmp esi, [_gfx_h]
    jae .gp_end
    imul esi, [_gfx_pitch]
    add esi, ebx
    lea esi, [esi + edi*4]
    mov eax, [esi]
.gp_end:
    mov [_gp_ret], eax
    popad
    mov eax, [_gp_ret]
    ret

    .globl _gfx_hex
_gfx_hex:                           # 绘十六( x, y, 值, 色 ) —— 画 8 位十六进制
    pushad
    mov eax, [esp + 40]             # 值
    mov edi, offset _gn_buf
    mov ecx, 8
.gh_loop:
    rol eax, 4
    mov edx, eax
    and edx, 0x0F
    cmp edx, 10
    jb .gh_dig
    add edx, 'a' - 10
    jmp .gh_put
.gh_dig:
    add edx, '0'
.gh_put:
    mov [edi], dl
    inc edi
    dec ecx
    jnz .gh_loop
    mov byte ptr [edi], 0
    mov ebx, [esp + 48]             # x
    mov ebp, [esp + 44]             # y
    mov ecx, [esp + 36]             # 色
    push ebx
    push ebp
    push offset _gn_buf
    push ecx
    call _gfx_text
    add esp, 16
    popad
    ret

# ===========================================================================
#  滚屏( 像素 ) —— 整屏向上挪 n 像素，底部 n 像素填背景色
#  用 rep movsd 一次搬完，在汇编里做是因为新语逐像素太慢
# ===========================================================================
    .globl _gfx_scrollup
_gfx_scrollup:
    pushad
    mov ebx, [_gfx_fb]
    test ebx, ebx
    jz .su_end
    mov ecx, [esp + 36]             # n
    test ecx, ecx
    jle .su_end
    mov edx, [_gfx_h]
    cmp ecx, edx
    jb .su_ok
    xor ecx, ecx                    # n >= 高 → 就当整屏清掉
    mov [esp + 36], ecx
    mov ecx, edx
.su_ok:
    mov eax, [_gfx_pitch]
    imul eax, ecx                   # n * pitch
    mov esi, ebx
    add esi, eax                    # 源 = fb + n*pitch
    mov edi, ebx                    # 目的 = fb
    mov edx, [_gfx_h]
    sub edx, ecx
    imul edx, [_gfx_pitch]
    shr edx, 2                      # 按 dword 数
    mov ecx, edx
    cld
    rep movsd
    # 底部 n 行填背景
    mov ecx, [esp + 36]
    mov eax, [_gfx_pitch]
    imul eax, ecx
    mov edi, [_gfx_fb]
    mov edx, [_gfx_h]
    sub edx, ecx
    imul edx, [_gfx_pitch]
    add edi, edx
    shr eax, 2
    mov ecx, eax
    mov eax, [esp + 40]             # 背景色（第 2 个参数）
    cld
    rep stosd
.su_end:
    popad
    ret

    .globl _gfx_poll
_gfx_poll:
    call _input_poll
    ret

# ===========================================================================
#  绘数( x, y, 数, 色 ) —— 把整数画到屏上
# ===========================================================================
    .globl _gfx_num
_gfx_num:
    pushad
    mov eax, [esp + 40]             # 数
    mov edi, offset _gn_buf + 15
    mov byte ptr [edi], 0
    mov byte ptr [_gn_neg], 0
    test eax, eax
    jns .gn_pos
    neg eax
    mov byte ptr [_gn_neg], 1
.gn_pos:
    mov ecx, 10
.gn_conv:
    dec edi
    xor edx, edx
    div ecx
    add dl, '0'
    mov [edi], dl
    test eax, eax
    jnz .gn_conv
    cmp byte ptr [_gn_neg], 0
    je .gn_out
    dec edi
    mov byte ptr [edi], '-'
.gn_out:
    mov ebx, [esp + 48]             # x
    mov ebp, [esp + 44]             # y
    mov ecx, [esp + 36]             # 色
    push ebx
    push ebp
    push edi
    push ecx
    call _gfx_text
    add esp, 16
    popad
    ret

# ===========================================================================
#  扫描码表（Set 1）
# ===========================================================================
    .section .data
_sctab:
    .byte 0,27,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    .byte 'q','w','e','r','t','y','u','i','o','p','[',']',13,0,'a','s'
    .byte 'd','f','g','h','j','k','l',';',39,'`',0,92,'z','x','c','v'
    .byte 'b','n','m',',','.','/',0,'*',0,' ',0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
_sctab_shift:
    .byte 0,27,'!','@','#','$','%','^','&','*','(',')','_','+',8,9
    .byte 'Q','W','E','R','T','Y','U','I','O','P','{','}',13,0,'A','S'
    .byte 'D','F','G','H','J','K','L',':','"','~',0,'|','Z','X','C','V'
    .byte 'B','N','M','<','>','?',0,'*',0,' ',0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
