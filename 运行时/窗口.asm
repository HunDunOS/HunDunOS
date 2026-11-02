    .intel_syntax noprefix
    .section .text

打点:
    push rax
    push rdx
    mov dx, 0x3F8
    out dx, al
    pop rdx
    pop rax
    ret

打十六:
    push rax
    push rcx
    push rdx
    push r8
    mov ecx, 16
.hx:
    rol r8, 4
    mov al, r8b
    and al, 15
    add al, 48
    cmp al, 58
    jb .hp
    add al, 7
.hp:
    push rdx
    mov dx, 0x3F8
    out dx, al
    pop rdx
    dec ecx
    jnz .hx
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret

    .globl _win_open
_win_open:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, [rsp + 40]
    mov r12, [rsp + 48]
    mov r13, [rsp + 56]
    mov r14, [rsp + 64]
    mov rax, [rsp + 72]

    mov [rip + _win_x], rbx
    mov [rip + _win_y], r12
    mov [rip + _win_w], r13
    mov [rip + _win_h], r14
    mov [rip + _win_bg], rax
    mov qword ptr [rip + _win_on], 1

    lea rcx, [rip + _win_面]
    mov [rip + _tgt], rcx
    mov rcx, r13
    shl rcx, 2
    mov [rip + _tgt_pitch], rcx

    lea rdi, [rip + _win_面]
    mov rcx, r13
    imul rcx, r14
    mov eax, [rip + _win_bg]
1:
    test rcx, rcx
    jz 2f
    mov [rdi], eax
    add rdi, 4
    dec rcx
    jmp 1b
2:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

    .globl _win_compose
_win_compose:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x30
    cmp qword ptr [rip + _win_on], 0
    je .wc_end

    mov rax, [rip + _win_x]
    mov [rsp + 0], rax
    mov rax, [rip + _win_y]
    mov [rsp + 8], rax
    mov rax, [rip + _win_w]
    mov [rsp + 16], rax
    mov rax, [rip + _win_h]
    mov [rsp + 24], rax

    mov al, 83
    call 打点
    mov r8, [rsp + 0]
    call 打十六
    mov r8, [rsp + 8]
    call 打十六
    mov r8, [rsp + 16]
    call 打十六
    mov r8, [rsp + 24]
    call 打十六
    mov al, 10
    call 打点

    mov r15, [rip + _efi_fb]
    mov r14, [rip + _efi_pitch]

    xor rbx, rbx
.sh_row:
    cmp rbx, qword ptr [rsp + 24]
    jae .sh_done
    mov rax, [rsp + 8]
    add rax, rbx
    add rax, 6
    imul rax, r14
    mov rdx, [rsp + 0]
    add rdx, 6
    shl rdx, 2
    add rax, rdx
    add rax, r15
    mov rcx, [rsp + 16]
    mov edx, 0x00161620
.sh_col:
    test rcx, rcx
    jz .sh_next
    mov [rax], edx
    add rax, 4
    dec rcx
    jmp .sh_col
.sh_next:
    inc rbx
    jmp .sh_row
.sh_done:

    xor rbx, rbx
.b_row:
    cmp rbx, qword ptr [rsp + 24]
    jae .b_done
    lea r12, [rip + _win_面]
    mov rax, rbx
    imul rax, [rsp + 16]
    shl rax, 2
    add r12, rax
    mov rax, [rsp + 8]
    add rax, rbx
    imul rax, r14
    mov rdx, [rsp + 0]
    shl rdx, 2
    add rax, rdx
    add rax, r15
    mov rcx, [rsp + 16]
.b_col:
    test rcx, rcx
    jz .b_next
    mov edx, [r12]
    mov [rax], edx
    add r12, 4
    add rax, 4
    dec rcx
    jmp .b_col
.b_next:
    inc rbx
    jmp .b_row
.b_done:
    call _gfx_screen
.wc_end:
    add rsp, 0x30
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

    .globl _win_demo
_win_demo:
    push rbx
    push r12
    sub rsp, 0x28

    mov al, 68
    call 打点

    call _gfx_screen
    push 0x00202830
    push 800
    push 1280
    push 0
    push 0
    call _gfx_fill
    add rsp, 40

    mov al, 66
    call 打点

    push 0x001E1E26
    push 400
    push 640
    push 60
    push 80
    call _win_open
    add rsp, 40

    push 0x00262633
    push 40
    push 640
    push 0
    push 0
    call _gfx_fill
    add rsp, 40

    push 0x00E0554A
    push 12
    push 12
    push 14
    push 14
    call _gfx_fill
    add rsp, 40

    push 0x00E6E6F0
    push 12
    push 40
    push 0x181000
    push 0
    call _gfx_text
    add rsp, 40

    push 0x002D6CDF
    push 48
    push 180
    push 240
    push 40
    call _gfx_fill
    add rsp, 40

    push 0x003FD0C0
    push 48
    push 180
    push 240
    push 100
    call _gfx_fill
    add rsp, 40

    push 0x004A4A5A
    push 2
    push 560
    push 320
    push 40
    call _gfx_fill
    add rsp, 40

    mov al, 67
    call 打点

    call _win_compose

    mov al, 68
    call 打点

    add rsp, 0x28
    pop r12
    pop rbx
    ret

    .section .data
    .align 8
    .globl _win_x
_win_x:    .quad 0
    .globl _win_y
_win_y:    .quad 0
_win_w:    .quad 0
_win_h:    .quad 0
_win_bg:   .quad 0
_win_on:   .quad 0

    .section .bss
    .align 16
    .globl _win_面
_win_面:   .space 0x100000
