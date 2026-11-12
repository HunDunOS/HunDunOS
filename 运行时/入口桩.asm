    .code64
    .intel_syntax noprefix
    .section .text

    .weak _gfx_init
_gfx_init:
    ret

    .section .bss
    .align 16
    .globl _kernel_stack
_kernel_stack:
    .space 0x8000
    .globl _kernel_stack_top
_kernel_stack_top:
