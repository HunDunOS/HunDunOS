/* ============================================================================
 *  模块链接脚本 —— 六爻模块编成可装载的裸机器码
 *
 *  基址由命令行给：ld --defsym MOD_BASE=0x400000 -T 模块.ld
 *  这个基址就是运行地址，所以汇编里的 offset 符号全是真的。
 * ==========================================================================*/
ENTRY(_start)

SECTIONS
{
    . = 0x1C0040;

    .text : {
        KEEP(*(.text.head))
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    _mod_bss_start = .;
    .bss : {
        *(.bss*)
        *(COMMON)
    }
    _mod_bss_end = .;

    /DISCARD/ : {
        *(.note*)
        *(.comment)
        *(.eh_frame)
        *(.multiboot)
    }
}
