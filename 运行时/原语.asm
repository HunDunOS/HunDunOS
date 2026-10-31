# ============================================================================
#  混沌 原语模块（原语.asm）—— 64 位版
#
#  内核里唯一该存在的汇编：机器之外表达不了的那几件。
#      · 读写 I/O 端口
#      · 按字节 / 按字 / 按双字读写任意内存
#      · 停机
#      · 调到任意地址（可返回）
#      · CPUID
#
#  参数约定：从左到右压栈，每个参数 8 字节。
#      第 1 个参数 [rsp + 8]，第 2 个 [rsp + 16]，第 n 个 [rsp + 8n]
#      （call 压了 8 字节返回地址）
#  一律 u64 进出，不存半截。
# ============================================================================

    .code64
    .intel_syntax noprefix
    .section .text

# ---------------------------------------------------------------------------
#  端入( 端口 ) → 字节
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
#  端出( 端口, 值 )
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
#  读8( 地址 ) / 写8( 地址, 值 )
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
#  读32( 地址 ) / 写32( 地址, 值 )   —— 名字里的"32"是访问宽度，返回值仍是 u64
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
#  停机
# ---------------------------------------------------------------------------
    .globl _pr_halt
_pr_halt:
    cli
    hlt
    jmp _pr_halt

# ---------------------------------------------------------------------------
#  调用( 目标, a, b, c, d ) —— 可返回
#  第 5 个参数（最先压、最深）是目标：[rsp + 40]
# ---------------------------------------------------------------------------
    .globl _pr_call
_pr_call:
    push rax
    mov dx, 0x3F8
    mov al, 67
    out dx, al
    pop rax
    mov rax, [rsp + 40]
    # ---- 临时：把目标地址打成 16 进制 ----
    push rbx
    push rcx
    push rdx
    push rax
    mov rbx, rax
    mov ecx, 16
.Lhex:
    rol rbx, 4
    mov eax, ebx
    and al, 15
    add al, 48
    cmp al, 58
    jb .Lout
    add al, 7
.Lout:
    mov dx, 0x3F8
    out dx, al
    dec ecx
    jnz .Lhex
    pop rax
    pop rdx
    pop rcx
    pop rbx
    call rax
    ret

# ---------------------------------------------------------------------------
#  读CPUID( 叶, 子叶 ) → 把 eax/ebx/ecx/edx 存起来，再单独取
# ---------------------------------------------------------------------------
    .globl _pr_cpuid
_pr_cpuid:
    push rbx
    mov eax, [rsp + 16]             # 叶
    mov ecx, [rsp + 24]             # 子叶
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

# ---------------------------------------------------------------------------
#  数据
# ---------------------------------------------------------------------------
    .section .data
    .align 8
_cpuid_a:  .quad 0
_cpuid_b:  .quad 0
_cpuid_c:  .quad 0
_cpuid_d:  .quad 0
