
    .code64
    .intel_syntax noprefix
    .section .text

    .globl _pr_in8
_pr_in8:
    mov rdx, [rsp + 8]
    xor eax, eax
    in al, dx
    ret

    .globl _pr_in16
_pr_in16:
    mov rdx, [rsp + 8]
    xor eax, eax
    in ax, dx
    ret

    .globl _pr_in32
_pr_in32:
    mov rdx, [rsp + 8]
    xor eax, eax
    in eax, dx
    ret

    .globl _pr_out8
_pr_out8:
    mov rdx, [rsp + 8]
    mov rax, [rsp + 16]
    out dx, al
    ret

    .globl _pr_out16
_pr_out16:
    mov rdx, [rsp + 8]
    mov rax, [rsp + 16]
    out dx, ax
    ret

    .globl _pr_out32
_pr_out32:
    mov rdx, [rsp + 8]
    mov rax, [rsp + 16]
    out dx, eax
    ret

    .globl _pr_ld8
_pr_ld8:
    mov rax, [rsp + 8]
    movzx rax, byte ptr [rax]
    ret

    .globl _pr_st8
_pr_st8:
    mov rax, [rsp + 8]
    mov rcx, [rsp + 16]
    mov [rax], cl
    ret

    .globl _pr_ld32
_pr_ld32:
    mov rax, [rsp + 8]
    mov eax, dword ptr [rax]
    ret

    .globl _pr_st32
_pr_st32:
    mov rax, [rsp + 8]
    mov rcx, [rsp + 16]
    mov dword ptr [rax], ecx
    ret

    .globl _pr_halt
_pr_halt:
    cli
    hlt
    jmp _pr_halt

    .globl _pr_call
_pr_call:
    mov rax, [rsp + 40]
    call rax
    ret

    .globl _pr_cpuid
_pr_cpuid:
    push rbx
    mov eax, [rsp + 16]
    mov ecx, [rsp + 24]
    cpuid
    mov [_cpuid_a], eax
    mov [_cpuid_b], ebx
    mov [_cpuid_c], ecx
    mov [_cpuid_d], edx
    pop rbx
    xor eax, eax
    ret

    .globl _pr_ca
_pr_ca:
    mov eax, [_cpuid_a]
    ret

    .globl _pr_cb
_pr_cb:
    mov eax, [_cpuid_b]
    ret

    .globl _pr_cc
_pr_cc:
    mov eax, [_cpuid_c]
    ret

    .globl _pr_cd
_pr_cd:
    mov eax, [_cpuid_d]
    ret

    .section .data
    .align 8
_cpuid_a:  .quad 0
_cpuid_b:  .quad 0
_cpuid_c:  .quad 0
_cpuid_d:  .quad 0

# ---------------------------------------------------------------------------
#  运行时桩：数组越界（lyc 生成的代码会引用）
#  真越界就停机 —— 不搞高级异常
# ---------------------------------------------------------------------------
    .globl _rt_oob
_rt_oob:
    cli
    hlt
    jmp _rt_oob

# ---------------------------------------------------------------------------
#  _rt_puts(串地址) —— 串口输出，0 结尾
# ---------------------------------------------------------------------------
    .globl _rt_puts
_rt_puts:
    push rsi
    push rax
    push rdx
    mov rsi, [rsp + 32]
1:
    movzx eax, byte ptr [rsi]
    test al, al
    jz 2f
    mov dx, 0x3F8
    out dx, al
    inc rsi
    jmp 1b
2:
    pop rdx
    pop rax
    pop rsi
    ret

# ---------------------------------------------------------------------------
#  _rt_puti(整数) —— 十进制输出
# ---------------------------------------------------------------------------
    .globl _rt_puti
_rt_puti:
    push rax
    push rcx
    push rdx
    push r8
    mov rax, [rsp + 40]
    mov r8, 10
    test rax, rax
    jnz 1f
    mov dx, 0x3F8
    mov al, 48
    out dx, al
    jmp 3f
1:
    xor ecx, ecx
2:
    xor edx, edx
    div r8
    push rdx
    inc ecx
    test rax, rax
    jnz 2b
4:
    pop rax
    add al, 48
    push rcx
    mov dx, 0x3F8
    out dx, al
    pop rcx
    dec ecx
    jnz 4b
3:
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret
