/* 新语内核链接脚本 —— xboot 自研引导路线
 *
 * 与 Multiboot 版 link.ld 的区别：
 *   · 加载地址 0x10000（64KB，实模式就能寻址 → 引导器不需要 unreal mode）
 *   · _start 必须落在映像偏移 0（引导器直接跳加载地址）
 *   · 不再需要 Multiboot 头（阶段 5 已删）
 */
ENTRY(_start)

SECTIONS
{
    . = 0x10000;

    .text : {
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    /* 万一还有 .multiboot 段（老编译器），挪到最后，别占 _start 的位置 */
    .multiboot : {
        *(.multiboot)
    }

    _kernel_bss_start = .;
    .bss : {
        *(.bss*)
        *(COMMON)
    }
    _kernel_bss_end = .;
}
