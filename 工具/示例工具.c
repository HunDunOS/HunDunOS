/* ===========================================================================
 *  示例工具 —— 用 C 写的，编成 .bao，在混沌里跑
 *
 *  它不碰任何硬件，只调内核给的几个入口（k_puts / k_puti / ...）。
 *  链接时那些符号指向内核里的 C接口.asm。
 *
 *  编译：
 *    clang --target=i386-unknown-elf -m32 -ffreestanding -nostdlib -fno-pic \
 *          -fno-stack-protector -O2 -c 示例工具.c -o 工具.o
 *    ld -m elf_i386 -Ttext=0x400000 --just-symbols=kernel.elf -o 工具.elf 工具.o
 * =========================================================================== */

void k_cls(void);
void k_puts(const char *s);
void k_puti(int n);
void k_putc(int c);
int  k_getc(void);
void k_rect(int x, int y, int w, int h, int color);

/* 一段纯计算的代码，证明这是真的在跑机器码 */
static int 斐波那契(int n)
{
    int a = 0, b = 1, i;
    for (i = 0; i < n; i++) {
        int t = a + b;
        a = b;
        b = t;
    }
    return a;
}

static void 分隔线(void)
{
    k_puts("----------------------------------------\n");
}

void tool_main(void)
{
    int i;

    k_cls();
    k_rect(0, 0, 9999, 3, 0x1E9E8A);

    k_puts("C 工具  ·  跑在混沌里\n");
    分隔线();

    k_puts("这段程序是 clang 编出来的 i386 机器码，\n");
    k_puts("不是新语，是一份 .bao 包。\n\n");

    k_puts("算个数给你看：\n");
    for (i = 0; i < 10; i++) {
        k_puts("  斐波那契(");
        k_puti(i);
        k_puts(") = ");
        k_puti(斐波那契(i));
        k_puts("\n");
    }

    k_puts("\n");
    分隔线();
    k_puts("按任意键退出\n");

    k_getc();
}
