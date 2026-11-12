
    .code64
    .intel_syntax noprefix

    .section .data
    .align 8
_gfx_fb:    .quad 0
_gfx_pitch: .quad 0
_gfx_w:     .quad 0
_gfx_h:     .quad 0

    .section .text

    .globl _gfx_init
_gfx_init:
    push rax
    mov eax, [rbx + 32]
    mov [_gfx_fb], rax
    mov eax, [rbx + 36]
    mov [_gfx_pitch], rax
    mov eax, [rbx + 40]
    mov [_gfx_w], rax
    mov eax, [rbx + 44]
    mov [_gfx_h], rax
    pop rax
    ret

    .globl _gfx_getw
_gfx_getw:
    mov rax, [_gfx_w]
    ret

    .globl _gfx_geth
_gfx_geth:
    mov rax, [_gfx_h]
    ret

    .globl _gfx_getfb
_gfx_getfb:
    mov rax, [_gfx_fb]
    ret

    .globl _gfx_getpitch
_gfx_getpitch:
    mov rax, [_gfx_pitch]
    ret

    .globl _gfx_getmem
_gfx_getmem:
    xor eax, eax
    ret

    .globl _gfx_px
_gfx_px:
    mov r8, [rsp + 8]
    mov r9, [rsp + 16]
    mov eax, [rsp + 24]
    mov r10, [_gfx_fb]
    test r10, r10
    jz .px_end
    mov r11, [_gfx_pitch]
    imul r9, r11
    lea r8, [r8 * 4]
    add r9, r8
    add r9, r10
    mov [r9], eax
.px_end:
    ret

    .globl _gfx_fill
_gfx_fill:
    push rbx
    mov rdi, [rsp + 48]
    mov rsi, [rsp + 40]
    mov r8,  [rsp + 32]
    mov r9,  [rsp + 24]
    mov eax, [rsp + 16]
    mov r10, [_gfx_fb]
    test r10, r10
    jz .fl_end
    test r8, r8
    jle .fl_end
    test r9, r9
    jle .fl_end
    mov r11, [_gfx_pitch]
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

    .globl _gfx_text
_gfx_text:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, [rsp + 72]
    mov r13, [rsp + 64]
    mov r14, [rsp + 56]
    mov r15d, [rsp + 48]
    mov rbx, r12
    mov r11, [_gfx_fb]
    test r11, r11
    jz .t_end

.t_loop:
    movzx eax, byte ptr [r14]
    test al, al
    jz .t_end
    cmp al, 0x80
    jb .t_ascii

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
    mov r8, offset _font_cjk_data
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
    mov r8, offset _font_ascii
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
    mov rcx, rbx
    add rcx, r10
    mov rdx, r13
    add rdx, r9
    mov rsi, [_gfx_pitch]
    imul rdx, rsi
    lea rcx, [rcx * 4]
    add rdx, rcx
    add rdx, r11
    mov esi, r15d
    mov [rdx], esi
.t_skip:
    shl eax, 1
    inc r10
    jmp .t_col
.t_rowend:
    inc r9
    jmp .t_row
.t_next:
    add rbx, 16
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

    .globl _rt_cls
_rt_cls:
    push rbx
    push 0
    push 0
    push qword ptr [_gfx_w]
    push qword ptr [_gfx_h]
    push 0x101018
    call _gfx_fill
    add rsp, 40
    pop rbx
    ret
