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

    .globl k_tryc
k_tryc:
    pushad
    call _gfx_key
    mov [esp + 28], eax
    popad
    ret

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
