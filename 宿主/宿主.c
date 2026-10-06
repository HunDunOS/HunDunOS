/* ===========================================================================
 *  新语 · 宿主运行时（Linux i386 版）
 *
 *  作用：让 xyc 编出来的 .s 能在 Linux 上【直接跑】——
 *        把内建函数接到 Linux 系统调用上，而不是接到帧缓冲和端口上。
 *
 *  所以：
 *    · 屏串 / 屏出 / 换行  →  直接打到 stdout（终端）
 *    · 绘块 / 绘框 / 绘点  →  空操作（终端里没法画像素）
 *    · 端入 / 端出         →  空操作（用户态没有端口权限）
 *    · 读8 / 写8 / 读32 / 写32 → 真的（用户态内存随便读写）
 *    · 键()                →  非阻塞读 stdin
 *    · 毫秒() / 时/分/秒    →  系统调用
 *    · 停机()              →  exit()
 *
 *  ★★ 一个关键约定：参数顺序是【反的】
 *     新语把参数【从左到右】压栈 → 第一个参数落在最深处。
 *     而 C 的 cdecl 是第一个参数在 [esp+4]。
 *     所以这里的 C 函数参数表必须【倒着写】：
 *          新语  绘块(x, y, 宽, 高, 色)
 *          C     _gfx_fill(色, 高, 宽, y, x)
 *     返回值没问题（都是 eax），栈清理也没问题（都是调用方清理）。
 *
 *  编译：clang --target=i386-linux-gnu -m32 -ffreestanding -nostdlib
 *        -fno-pic -fno-stack-protector -fno-builtin -O2 -c 宿主.c
 *  链接：ld -m elf_i386 -static -e _start
 * =========================================================================== */

/* ---------------------------------------------------------------- 系统调用 */
static int 系统调用(int 号, int a, int b, int c)
{
    int 返回值;
    __asm__ volatile ("int $0x80"
                      : "=a"(返回值)
                      : "a"(号), "b"(a), "c"(b), "d"(c)
                      : "memory", "esi", "edi");
    return 返回值;
}

#define 系统_退出  1
#define 系统_读    3
#define 系统_写    4
#define 系统_取时间 13
#define 系统_取毫秒 78

static int 写出去(const char *s, int 长)
{
    return 系统调用(系统_写, 1, (int)s, 长);
}
static int 写字(const char *s)
{
    int n = 0;
    while (s[n]) n = n + 1;
    if (n == 0) return 0;
    return 写出去(s, n);
}
static void 退出程序(int 码)
{
    系统调用(系统_退出, 码, 0, 0);
    for (;;) { }                       /* 不会到这儿 */
}

/* ---------------------------------------------------------------- _rt_*  */
void _rt_putc(int c)
{
    char b = (char)c;
    if (c == 10) { 写出去("\n", 1); return; }
    if (c == 9)  { 写出去("        ", 8); return; }
    if (c == 13) return;
    if (c < 32)  return;
    写出去(&b, 1);
}

void _rt_puts(const char *s) { 写字(s); }

void _rt_puti(int n)
{
    char 缓[16];
    int i = 15, 负 = 0;
    缓[15] = 0;
    if (n < 0) { 负 = 1; n = -n; }
    if (n == 0) { i = i - 1; 缓[i] = '0'; }
    while (n > 0) {
        i = i - 1;
        缓[i] = (char)('0' + (n % 10));
        n = n / 10;
    }
    if (负) { i = i - 1; 缓[i] = '-'; }
    写字(&缓[i]);
}

void _rt_cls(void)   { 写出去("\033[2J\033[H", 7); }     /* ANSI：清屏 + 光标归位 */
void _rt_goto(int 列, int 行)                             /* ★ 参数倒着：新语是 置光标(行,列) */
{
    char b[24];
    int i = 0;
    b[i++] = 27; b[i++] = '[';
    /* 行 */
    if (行 == 0) { b[i++] = '0'; } else {
        char t[8]; int k = 0;
        while (行 > 0) { t[k++] = (char)('0' + 行 % 10); 行 = 行 / 10; }
        while (k > 0) b[i++] = t[--k];
    }
    b[i++] = ';';
    if (列 == 0) { b[i++] = '0'; } else {
        char t[8]; int k = 0;
        while (列 > 0) { t[k++] = (char)('0' + 列 % 10); 列 = 列 / 10; }
        while (k > 0) b[i++] = t[--k];
    }
    b[i++] = 'H';
    写出去(b, i);
}
void _rt_scroll(void) { }
void _rt_oob(void) { 写字("\n[越界] 数组下标超出范围，程序已停止\n"); 退出程序(3); }

int _rt_getc(void)
{
    char b;
    int n = 系统调用(系统_读, 0, (int)&b, 1);
    if (n <= 0) return 0;
    return (int)(unsigned char)b;
}

/* 非阻塞：终端里 read 本来就会阻塞，这里用"有就读、没有就返回 0"
   的做法只能靠 ioctl 设 O_NONBLOCK —— 宿主版先简单点：直接阻塞读一个字节。
   学习用够了（程序要等你按一下回车才继续）。 */
int _rt_getkey(void)
{
    char b;
    int n = 系统调用(系统_读, 0, (int)&b, 1);
    if (n <= 0) return 0;
    if (b == 10) return 13;
    return (int)(unsigned char)b;
}

/* ---------------------------------------------------------------- _gfx_* */
/* ★ 栈：_start 第一句是  mov esp, offset _kernel_stack_top
     所以 _kernel_stack_top 必须是【一块真栈的顶部】。
     办法：在它前面放一个大数组，让链接器把它排在数组末尾 ——
     .bss 里 栈区 之后紧跟着 _kernel_stack_top，它正好是这块栈的顶。
     （踩过的坑：别在 _gfx_init 里切 esp —— 切完 ret 会从新栈弹返回地址，
       而那上面是 0，会跳到 NULL 段错误。） */
static char 栈区[256 * 1024];
char _kernel_stack_top[4];

void _gfx_init(void) { }

int _gfx_getw(void)     { return 80; }         /* 假装是 80 列的老终端 */
int _gfx_geth(void)     { return 25; }
int _gfx_getfb(void)    { return 0; }          /* 没有帧缓冲 */
int _gfx_getpitch(void) { return 80 * 4; }
int _gfx_getmem(void)   { return 64 * 1024 * 1024; }

int _gfx_ms(void)
{
    int t[2];                                   /* gettimeofday: 秒 + 微秒 */
    系统调用(系统_取毫秒, (int)t, 0, 0);
    return t[1] / 1000;
}
int _gfx_hour(void) { int t = 系统调用(系统_取时间, 0, 0, 0); return (t / 3600 + 8) % 24; }
int _gfx_min(void)  { int t = 系统调用(系统_取时间, 0, 0, 0); return (t / 60) % 60; }
int _gfx_sec(void)  { int t = 系统调用(系统_取时间, 0, 0, 0); return t % 60; }

int _gfx_key(void)      { return _rt_getkey(); }
int _gfx_msx(void)      { return 0; }
int _gfx_msy(void)      { return 0; }
int _gfx_msbtn(void)    { return 0; }
int _gfx_poll(void)     { return 0; }
void _gfx_sleep(int 毫秒数) { 系统调用(系统_取毫秒, 0, 0, 0); (void)毫秒数; }

/* 绘图类：终端里全是空操作 */
void _gfx_px(int 色, int y, int x)                       { (void)色; (void)y; (void)x; }
int  _gfx_getpx(int y, int x)                            { (void)y; (void)x; return 0; }
void _gfx_fill(int 色, int 高, int 宽, int y, int x)      { (void)色; (void)高; (void)宽; (void)y; (void)x; }
void _gfx_frame(int 色, int 高, int 宽, int y, int x)     { (void)色; (void)高; (void)宽; (void)y; (void)x; }
void _gfx_fillblend(int 透明, int 色, int 高, int 宽, int y, int x)
{ (void)透明; (void)色; (void)高; (void)宽; (void)y; (void)x; }
void _gfx_scrollup(int 色, int 像素)                      { (void)色; (void)像素; }
void _gfx_scrollrect(int 色, int 像素, int 高, int 宽, int y, int x)
{ (void)色; (void)像素; (void)高; (void)宽; (void)y; (void)x; }

/* 绘字：这是关键 —— 宿主版就把它变成"打印字符串"，
   所以壳里那些 屏串 / 屏出 / 换行 全都能直接用。返回宽度。 */
int _gfx_text(int 色, const char *串, int y, int x)
{
    (void)色; (void)y; (void)x;
    int n = 0, 宽 = 0;
    while (串[n]) n = n + 1;
    写出去(串, n);
    /* 宽度：ASCII 8 像素，中文按 2 个字符算（只影响光标位置） */
    for (int i = 0; i < n; i = i + 1)
        宽 = 宽 + (((unsigned char)串[i] >= 0x80) ? 4 : 8);
    return 宽;
}
int _gfx_num(int 色, int 数, int y, int x) { (void)色; (void)y; (void)x; _rt_puti(数); return 32; }
int _gfx_hex(int 色, int 数, int y, int x)
{
    (void)色; (void)y; (void)x;
    static const char h[] = "0123456789abcdef";
    char b[9];
    for (int i = 0; i < 8; i = i + 1) b[i] = h[(数 >> ((7 - i) * 4)) & 15];
    b[8] = 0;
    写字(b);
    return 64;
}

/* ---------------------------------------------------------------- _pr_*  */
int _pr_in8(int 口)  { (void)口; return 0; }
int _pr_in16(int 口) { (void)口; return 0; }
int _pr_in32(int 口) { (void)口; return 0; }
void _pr_out8(int 值, int 口)  { (void)值; (void)口; }
void _pr_out16(int 值, int 口) { (void)值; (void)口; }
void _pr_out32(int 值, int 口) { (void)值; (void)口; }

int  _pr_ld32(int 址)         { return *(volatile int *)址; }
void _pr_st32(int 值, int 址) { *(volatile int *)址 = 值; }
int  _pr_ld8(int 址)          { return *(volatile unsigned char *)址; }
void _pr_st8(int 值, int 址)  { *(volatile unsigned char *)址 = (unsigned char)值; }

void _pr_halt(void) { 退出程序(0); }

/* 调用(地址, a, b, c, d) —— 尾跳。C 里用函数指针调用，参数顺序倒着。 */
int _pr_call(int d, int c, int b, int a, int 地址)
{
    int (*f)(int, int, int, int) = (int (*)(int, int, int, int))地址;
    (void)d; (void)c; (void)b; (void)a;
    return f(a, b, c, d);
}

int _pr_cpuid(int 叶, int 寄存器号) { (void)叶; (void)寄存器号; return 0; }
int _pr_ca(void) { return 0; }
int _pr_cb(void) { return 0; }
int _pr_cc(void) { return 0; }
int _pr_cd(void) { return 0; }


