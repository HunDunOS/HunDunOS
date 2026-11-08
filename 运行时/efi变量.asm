    .intel_syntax noprefix
    .section .data
    .align 8
    .globl _efi_fb
_efi_fb:     .quad 0
    .globl _efi_w
_efi_w:      .quad 0
    .globl _efi_h
_efi_h:      .quad 0
    .globl _efi_pitch
_efi_pitch:  .quad 0
    .globl _efi_scale
_efi_scale:  .quad 1
    .globl _efi_fmt
_efi_fmt:    .quad 0
    .globl _sh_r
_sh_r:       .quad 16
    .globl _sh_g
_sh_g:       .quad 8
    .globl _sh_b
_sh_b:       .quad 0
    .globl _gfx_w
_gfx_w:      .long 0
    .globl _gfx_h
_gfx_h:      .long 0
    .globl _gfx_fb
_gfx_fb:     .long 0
    .globl _gfx_pitch
_gfx_pitch:  .long 0

    .section .text
# 从 XBP 把帧缓冲参数抄进这些变量
    .extern _tgt
    .extern _tgt_pitch
    .globl _efi_从XBP
_efi_从XBP:
    mov eax, [0x520]
    mov [_efi_fb], rax
    mov [_gfx_fb], eax
    mov eax, [0x524]
    mov [_efi_pitch], rax
    mov [_gfx_pitch], eax
    mov eax, [0x528]
    mov [_efi_w], rax
    mov [_gfx_w], eax
    mov eax, [0x52C]
    mov [_efi_h], rax
    mov [_gfx_h], eax
    # ★ 关键：_gfx_text 看 _tgt，必须指向帧缓冲
    mov rax, [_efi_fb]
    mov [_tgt], rax
    mov rax, [_efi_pitch]
    mov [_tgt_pitch], rax
    ret
