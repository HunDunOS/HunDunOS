#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* ══════════════════════════════════════════════════════════════════════
   编码器.c —— 六爻 → x86-64 机器码  v1.0  (不经 as, 不经 ld)

   挂在 lyc.c 的同一个出口 em() / lbl() 上：
       文本模式：em("mov rax, 1")  →  "\tmov rax, 1\n" 写给 .s
       字节模式：em("mov rax, 1")  →  这里，落地成 48 C7 C0 01 00 00 00

   lyc.c 里其他几百处 em("...") 一行都不改。

   跳转松弛：先按 rel32 排，再迭代把够得着的跳转压成 rel8
             （和 GNU as 的做法一致 → 输出能和 as 逐字节对上）

   64 位的几条规矩（都是拿 as 的输出来校的）：
     · 64 位操作数一律带 REX.W（0x48）
     · push/pop r64 不带 REX.W（长模式下默认就是 64 位）
     · mov eax,[rax] / mov [rax],ecx / setcc al 不带 REX.W（32 位 / 8 位操作）
     · mov rax, 小立即数 → REX.W C7 /0 id（不是 B8）；大数才用 B8 + imm64
     · 算术立即数：rax 有专用操作码（05/0D/25/2D/35/3D），短一字节
     · 符号用绝对 32 位（SIB: mod=00 rm=100 sib=0x25 disp32）
   ══════════════════════════════════════════════════════════════════════ */

#define 区_文本 0
#define 区_只读 1
#define 区_未初 2
#define 区_数据 3
#define 区数    4

static unsigned char 区体[区数][1 << 22];
static int           区长[区数];
static int           当前区 = 区_文本;
static int           区基[区数];
static unsigned char 前缀体[64];
static int           文本前缀长 = 0;
static void 记前缀(long v) {
    if (文本前缀长 <= 60) {
        前缀体[文本前缀长++] = v & 255;       前缀体[文本前缀长++] = (v >> 8) & 255;
        前缀体[文本前缀长++] = (v >> 16) & 255; 前缀体[文本前缀长++] = (v >> 24) & 255;
    }
}

static int bin_mode = 0;
static int 占位模式 = 0;                            /* 1 = 全局符号留占位（和 as 的 .o 一样，可比对）*/
static char 重定位路径[512] = {0};                  /* 非空 → 把「外部符号待补位置」写成表，给小链接器用 */
static char 符号表路径[512] = {0};                  /* 非空 → 把「本模块定义的符号」写成表 */
static int 总错 = 0;
static char 失败集[64][128]; static int 失败数 = 0;
static void 记失败(const char *s) {
    if (失败数 < 64) { strncpy(失败集[失败数], s, 127); 失败集[失败数][127] = 0; 失败数++; }
}

/* ── 标号表 ───────────────────────────────────────────────────────── */
typedef struct { char 名[192]; int 区; int 偏移; int 指令序; } 一个标号;
static 一个标号 标号表[1 << 15];
static int      标号数 = 0;

/* ── 待补表 ───────────────────────────────────────────────────────── */
/* 类：0 = 绝对 32 位   1 = 相对 32 位   2 = 相对 8 位 */
typedef struct { int 区; int 处; char 名[192]; int 类; int 加数; } 一笔待补;
static 一笔待补 待补表[1 << 17];
static int      待补数 = 0;

/* ── 指令表（跳转松弛用）─────────────────────────────────────────── */
#define 最多指令 (1 << 16)
static char 指令文[最多指令][80];
static int  指令数 = 0;
static int  指令长[最多指令];
static int  指令短[最多指令];
static int  指令跳[最多指令];
static char 指令靶[最多指令][192];
static int  本短 = 0;
static int  本跳 = 0;
static char 本靶[192];

static void 记指令(const char *s) {
    if (指令数 >= 最多指令) { 总错 = 1; return; }
    strncpy(指令文[指令数], s, 79); 指令文[指令数][79] = 0;
    指令数++;
}

/* ── 底层 ─────────────────────────────────────────────────────────── */
static void 出(unsigned char b) {
    if (区长[当前区] >= (1 << 22)) { 总错 = 1; return; }
    区体[当前区][区长[当前区]++] = b;
}
static void 出32(long v) { 出(v & 255); 出((v >> 8) & 255); 出((v >> 16) & 255); 出((v >> 24) & 255); }
static void 出16x(long v) { 出(v & 255); 出((v >> 8) & 255); }
static void 出64(long long v) {
    for (int i = 0; i < 8; i++) 出((v >> (8 * i)) & 255);
}
static void 换区(int n) { 当前区 = n; }
static void 写前缀(void) { for (int i = 0; i < 文本前缀长; i++) 出(前缀体[i]); }

static int 找标号(const char *名) {
    for (int i = 0; i < 标号数; i++) if (!strcmp(标号表[i].名, 名)) return i;
    return -1;
}
static void 记标号(const char *名) {
    int i = 找标号(名);
    if (i >= 0) { 标号表[i].区 = 当前区; 标号表[i].偏移 = 区长[当前区];
                  标号表[i].指令序 = 指令数; return; }
    if (标号数 >= (1 << 15)) { 总错 = 1; return; }
    strncpy(标号表[标号数].名, 名, 191); 标号表[标号数].名[191] = 0;
    标号表[标号数].区 = 当前区;
    标号表[标号数].偏移 = 区长[当前区];
    标号表[标号数].指令序 = 指令数;
    标号数++;
}
static void 记待补(int 类, const char *名, int 加数, int 宽) {
    if (待补数 >= (1 << 17)) { 总错 = 1; return; }
    一笔待补 *t = &待补表[待补数++];
    t->区 = 当前区; t->处 = 区长[当前区] - 宽;
    strncpy(t->名, 名 ? 名 : "", 191); t->名[191] = 0;
    t->类 = 类; t->加数 = 加数;
}

/* ── 重定位表（给小链接器用）────────────────────────────────────── */
static FILE *重定位文件 = NULL;
static void 重定位里记(int 处, int 类, const char *名) {
    if (!重定位文件) {
        重定位文件 = fopen(重定位路径, "w");
        if (!重定位文件) return;
    }
    fprintf(重定位文件, "%d %d %s\n", 处, 类, 名);
}

/* ── 寄存器：号 0..15 ─────────────────────────────────────────────── */
static const char *名64[] = { "rax","rcx","rdx","rbx","rsp","rbp","rsi","rdi",
                              "r8","r9","r10","r11","r12","r13","r14","r15", 0 };
static const char *名32[] = { "eax","ecx","edx","ebx","esp","ebp","esi","edi",
                              "r8d","r9d","r10d","r11d","r12d","r13d","r14d","r15d", 0 };
static const char *名16[] = { "ax","cx","dx","bx","sp","bp","si","di",
                              "r8w","r9w","r10w","r11w","r12w","r13w","r14w","r15w", 0 };
static const char *名8[]  = { "al","cl","dl","bl","spl","bpl","sil","dil",
                              "r8b","r9b","r10b","r11b","r12b","r13b","r14b","r15b", 0 };

static int 查表(const char **表, const char *s) {
    for (int i = 0; 表[i]; i++) if (!strcmp(s, 表[i])) return i;
    return -1;
}

static void 出REX(int W, int R, int X, int B) {
    unsigned r = 0x40 | (W ? 8 : 0) | ((R & 8) ? 4 : 0) | ((X & 8) ? 2 : 0) | ((B & 8) ? 1 : 0);
    if (r != 0x40) 出((unsigned char)r);
}

/* ── 操作数 ───────────────────────────────────────────────────────── */
enum { 空操作数 = 0, 数值 = 1, 寄存器 = 2, 内存 = 3 };
typedef struct {
    int  类;
    int  号;         /* 寄存器：0..15 */
    int  宽;         /* 寄存器：8 / 16 / 32 / 64 */
    long 值;
    int  有名;
    char 名[192];
    int  基址;
    long 偏移;
    int  尺寸;       /* 内存：1/2/4/8 */
} 操作数;

static void 去空白(char *s) {
    char *p = s; while (*p == ' ' || *p == '\t') p++;
    if (p != s) memmove(s, p, strlen(p) + 1);
    int n = strlen(s);
    while (n > 0 && (s[n-1] == ' ' || s[n-1] == '\t')) s[--n] = 0;
}

static void 解操作数(char *t, 操作数 *o) {
    memset(o, 0, sizeof(*o));
    o->基址 = -1; o->尺寸 = 8;
    去空白(t);
    {
        static const struct { const char *前; int 宽; } 前缀[] = {
            {"byte ptr ", 1}, {"word ptr ", 2}, {"dword ptr ", 4}, {"qword ptr ", 8}, {0, 0} };
        for (int i = 0; 前缀[i].前; i++) {
            size_t L = strlen(前缀[i].前);
            if (!strncmp(t, 前缀[i].前, L)) {
                o->尺寸 = 前缀[i].宽;
                memmove(t, t + L, strlen(t + L) + 1);
                去空白(t);
                break;
            }
        }
    }
    if (!*t) { o->类 = 空操作数; return; }
    if (!strncmp(t, "offset ", 7)) {
        o->类 = 数值; o->有名 = 1;
        strncpy(o->名, t + 7, 191); 去空白(o->名);
        return;
    }
    if (t[0] == '[') {
        o->类 = 内存;
        int n = strlen(t);
        if (n > 1 && t[n-1] == ']') t[n-1] = 0;
        char *内 = t + 1; 去空白(内);
        int r = 查表(名64, 内);
        if (r >= 0) { o->基址 = r; o->偏移 = 0; return; }
        char *pm = strchr(内, '+'), *mm = strchr(内, '-');
        char *切 = pm ? pm : mm;
        if (切 && 切 != 内) {
            char 基[64]; int k = (int)(切 - 内); if (k > 63) k = 63;
            memcpy(基, 内, k); 基[k] = 0; 去空白(基);
            int base = 查表(名64, 基);
            if (base >= 0) {
                long d = strtol(切 + 1, 0, 0);
                o->基址 = base;
                o->偏移 = (切 == mm) ? -d : d;
                return;
            }
        }
        o->有名 = 1; strncpy(o->名, 内, 191);
        return;
    }
    {
        int r = 查表(名64, t); if (r >= 0) { o->类 = 寄存器; o->号 = r; o->宽 = 64; return; }
            r = 查表(名32, t); if (r >= 0) { o->类 = 寄存器; o->号 = r; o->宽 = 32; return; }
            r = 查表(名16, t); if (r >= 0) { o->类 = 寄存器; o->号 = r; o->宽 = 16; return; }
            r = 查表(名8,  t); if (r >= 0) { o->类 = 寄存器; o->号 = r; o->宽 = 8;  return; }
    }
    {
        char *end; long v = strtol(t, &end, 0);
        if (end != t && *end == 0) { o->类 = 数值; o->值 = v; return; }
    }
    o->类 = 数值; o->有名 = 1; strncpy(o->名, t, 191);
}

/* ── 内存操作数 ───────────────────────────────────────────────────── */
typedef struct { int mod, rm, 有SIB, sib, disp长; long disp; int 有名; int 基号; char 名[192]; } 内存规划;

static void 规划内存(操作数 *o, 内存规划 *m) {
    memset(m, 0, sizeof(*m));
    if (o->有名) {                       /* [符号] → 绝对 32 位（SIB） */
        m->mod = 0; m->rm = 4; m->有SIB = 1; m->sib = 0x25;
        m->disp长 = 4; m->有名 = 1; m->基号 = -1;
        strncpy(m->名, o->名, 191);
        return;
    }
    int b = o->基址, r = b & 7;
    m->基号 = b;
    if (r == 4) {                        /* rsp/r12 必须走 SIB */
        m->rm = 4; m->有SIB = 1; m->sib = (0 << 6) | (4 << 3) | (b & 7);
        if (o->偏移 == 0) { m->mod = 0; }
        else if (o->偏移 >= -128 && o->偏移 <= 127) { m->mod = 1; m->disp长 = 1; m->disp = o->偏移; }
        else { m->mod = 2; m->disp长 = 4; m->disp = o->偏移; }
        return;
    }
    if (r == 5 && o->偏移 == 0 && b < 8) { /* rbp 不能 mod=00 */
        m->mod = 1; m->rm = 5; m->disp长 = 1; m->disp = 0; return;
    }
    m->rm = r;
    if (o->偏移 == 0) { m->mod = 0; }
    else if (o->偏移 >= -128 && o->偏移 <= 127) { m->mod = 1; m->disp长 = 1; m->disp = o->偏移; }
    else { m->mod = 2; m->disp长 = 4; m->disp = o->偏移; }
}

static void 出内存体(int reg字段, 内存规划 *m) {
    出((unsigned char)((m->mod << 6) | ((reg字段 & 7) << 3) | m->rm));
    if (m->有SIB) 出((unsigned char)m->sib);
    if (m->disp长 == 1) 出((unsigned char)(m->disp & 255));
    else if (m->disp长 == 4) {
        if (m->有名) { 出32(0); 记待补(0, m->名, 0, 4); }
        else 出32(m->disp);
    }
}

/* 带内存操作数的一条指令：reg 是 ModRM.reg 字段
   R = 需不需要 REX.R；W = 需不需要 REX.W */
static void 出内存指令(int W, int R, int 操作码, int reg字段, 操作数 *mem) {
    内存规划 m;
    规划内存(mem, &m);
    int B = (m.基号 >= 0) ? m.基号 : 0;        /* ★ SIB 的基址扩展位也走 REX.B */
    出REX(W, R ? reg字段 : 0, 0, B);
    if (操作码 > 0xFF) { 出((unsigned char)(操作码 >> 8)); 出((unsigned char)(操作码 & 255)); }
    else 出((unsigned char)操作码);
    出内存体(reg字段, &m);
}

/* 算术：reg, reg / reg, imm */
static void 算术64(int 码_rr, int 码_imm, int 码_rax, int 数字段, 操作数 *d, 操作数 *s) {
    if (d->类 != 寄存器 || d->宽 != 64) { 总错 = 1; return; }
    if (s->类 == 寄存器) {
        出REX(1, s->号, 0, d->号);
        出((unsigned char)码_rr);
        出((unsigned char)((3 << 6) | ((s->号 & 7) << 3) | (d->号 & 7)));
        return;
    }
    if (s->类 == 数值) {
        if (!s->有名 && s->值 >= -128 && s->值 <= 127) {
            出REX(1, 0, 0, d->号);
            出(0x83);
            出((unsigned char)((3 << 6) | ((数字段 & 7) << 3) | (d->号 & 7)));
            出((unsigned char)(s->值 & 255));
        } else if (d->号 == 0 && !s->有名) {      /* rax 专用形式 */
            出REX(1, 0, 0, 0);
            出((unsigned char)码_rax);
            出32(s->值);
        } else {
            出REX(1, 0, 0, d->号);
            出((unsigned char)码_imm);
            出((unsigned char)((3 << 6) | ((数字段 & 7) << 3) | (d->号 & 7)));
            if (s->有名) { 出32(0); 记待补(0, s->名, 0, 4); } else 出32(s->值);
        }
        return;
    }
    总错 = 1;
}

static const struct { const char *名; int 码; } 跳转集[] = {
    {"jo",0x80},{"jno",0x81},{"jb",0x82},{"jnae",0x82},{"jae",0x83},{"jnb",0x83},
    {"je",0x84},{"jz",0x84},{"jne",0x85},{"jnz",0x85},{"jbe",0x86},{"ja",0x87},
    {"js",0x88},{"jns",0x89},{"jp",0x8A},{"jnp",0x8B},{"jl",0x8C},{"jnge",0x8C},
    {"jge",0x8D},{"jnl",0x8D},{"jle",0x8E},{"jng",0x8E},{"jg",0x8F},{"jnle",0x8F},{0,0} };

/* ══ 一条指令 → 字节 ═══════════════════════════════════════════════ */
static void 编码(const char *原文) {
    char 缓[512];
    strncpy(缓, 原文, 511); 缓[511] = 0;
    char *p = 缓; while (*p == ' ' || *p == '\t') p++;
    char *mn = p;
    while (*p && *p != ' ' && *p != '\t') p++;
    if (*p) *p++ = 0;

    char *参[4]; int n参 = 0;
    if (*p) {
        char *q = p;
        while (*q && n参 < 4) {
            char *逗 = strchr(q, ',');
            if (逗) *逗 = 0;
            参[n参++] = q;
            if (!逗) break;
            q = 逗 + 1;
        }
    }
    操作数 o[4];
    for (int i = 0; i < n参; i++) 解操作数(参[i], &o[i]);
    本跳 = 0; 本靶[0] = 0;

    if (!n参) {
        if (!strcmp(mn, "ret"))   { 出(0xC3); return; }
        if (!strcmp(mn, "nop"))   { 出(0x90); return; }
        if (!strcmp(mn, "cli"))   { 出(0xFA); return; }
        if (!strcmp(mn, "sti"))   { 出(0xFB); return; }
        if (!strcmp(mn, "hlt"))   { 出(0xF4); return; }
        if (!strcmp(mn, "leave")) { 出(0xC9); return; }
        if (!strcmp(mn, "cld"))   { 出(0xFC); return; }
        if (!strcmp(mn, "iret"))  { 出(0xCF); return; }
        if (!strcmp(mn, "int3"))  { 出(0xCC); return; }
        if (!strcmp(mn, "syscall")) { 出(0x0F); 出(0x05); return; }
        总错 = 1; return;
    }

    /* ── push / pop（长模式下默认 64 位，不带 REX.W）── */
    if (!strcmp(mn, "push")) {
        if (o[0].类 == 寄存器) { 出REX(0, 0, 0, o[0].号); 出((unsigned char)(0x50 + (o[0].号 & 7))); return; }
        if (o[0].类 == 数值) {
            出(0x68);
            if (o[0].有名) { 出32(0); 记待补(0, o[0].名, 0, 4); } else 出32(o[0].值);
            return;
        }
        总错 = 1; return;
    }
    if (!strcmp(mn, "pop")) {
        if (o[0].类 == 寄存器) { 出REX(0, 0, 0, o[0].号); 出((unsigned char)(0x58 + (o[0].号 & 7))); return; }
        总错 = 1; return;
    }

    /* ── mov ── */
    if (!strcmp(mn, "mov")) {
        int dW = (o[0].类 == 寄存器) ? o[0].宽 : o[0].尺寸;
        int sW = (o[1].类 == 寄存器) ? o[1].宽 : o[1].尺寸;
        if (o[0].类 == 寄存器 && o[1].类 == 寄存器) {
            出REX(dW == 64, o[1].号, 0, o[0].号);
            出(0x89);
            出((unsigned char)((3 << 6) | ((o[1].号 & 7) << 3) | (o[0].号 & 7)));
            return;
        }
        if (o[0].类 == 寄存器 && o[1].类 == 内存) {
            出内存指令(dW == 64, 1, 0x8B, o[0].号, &o[1]);
            return;
        }
        if (o[0].类 == 寄存器 && o[1].类 == 数值) {
            long long v = o[1].值;
            if (o[1].有名 || (v >= -2147483648LL && v <= 2147483647LL)) {
                出REX(1, 0, 0, o[0].号);
                出(0xC7);
                出((unsigned char)((3 << 6) | (0 << 3) | (o[0].号 & 7)));
                if (o[1].有名) { 出32(0); 记待补(0, o[1].名, 0, 4); }
                else 出32((long)v);
            } else {
                出REX(1, 0, 0, o[0].号);
                出((unsigned char)(0xB8 + (o[0].号 & 7)));
                出64(v);
            }
            return;
        }
        if (o[0].类 == 内存 && o[1].类 == 寄存器) {
            if (sW == 16) 出(0x66);                   /* 16 位要 0x66 前缀 */
            出内存指令(sW == 64, 1, (sW == 8) ? 0x88 : 0x89, o[1].号, &o[0]);
            return;
        }
        if (o[0].类 == 内存 && o[1].类 == 数值) {
            int 宽 = o[0].尺寸;
            if (宽 == 1) { 出内存指令(0, 0, 0xC6, 0, &o[0]); 出((unsigned char)(o[1].值 & 255)); return; }
            if (宽 == 2) { 出(0x66); 出内存指令(0, 0, 0xC7, 0, &o[0]); 出16x(o[1].值); return; }
            出内存指令(宽 == 8, 0, 0xC7, 0, &o[0]);
            if (宽 == 8) 出32((long)o[1].值); else 出32((long)o[1].值);
            return;
        }
        总错 = 1; return;
    }
    if (!strcmp(mn, "lea")) {
        if (o[0].类 == 寄存器 && o[1].类 == 内存) {
            出内存指令(o[0].宽 == 64, 1, 0x8D, o[0].号, &o[1]);
            return;
        }
        总错 = 1; return;
    }
    if (!strcmp(mn, "movzx") || !strcmp(mn, "movsx")) {
        int 首 = !strcmp(mn, "movzx") ? 0xB6 : 0xBE;
        if (o[0].类 != 寄存器) { 总错 = 1; return; }
        int W = (o[0].宽 == 64);
        if (o[1].类 == 寄存器) {
            int 码 = 首 + (o[1].宽 == 16 ? 1 : 0);
            出REX(W, o[0].号, 0, o[1].号);
            出(0x0F); 出((unsigned char)码);
            出((unsigned char)((3 << 6) | ((o[0].号 & 7) << 3) | (o[1].号 & 7)));
            return;
        }
        if (o[1].类 == 内存) {
            int 码 = 首 + (o[1].尺寸 == 2 ? 1 : 0);
            出内存指令(W, 1, 0x0F00 | 码, o[0].号, &o[1]);
            return;
        }
        总错 = 1; return;
    }
    if (!strcmp(mn, "add")) { 算术64(0x01, 0x81, 0x05, 0, &o[0], &o[1]); return; }
    if (!strcmp(mn, "or"))  { 算术64(0x09, 0x81, 0x0D, 1, &o[0], &o[1]); return; }
    if (!strcmp(mn, "and")) { 算术64(0x21, 0x81, 0x25, 4, &o[0], &o[1]); return; }
    if (!strcmp(mn, "sub")) { 算术64(0x29, 0x81, 0x2D, 5, &o[0], &o[1]); return; }
    if (!strcmp(mn, "xor")) { 算术64(0x31, 0x81, 0x35, 6, &o[0], &o[1]); return; }
    if (!strcmp(mn, "cmp")) { 算术64(0x39, 0x81, 0x3D, 7, &o[0], &o[1]); return; }
    if (!strcmp(mn, "test")) {
        if (o[0].类 == 寄存器 && o[1].类 == 寄存器) {
            出REX(o[0].宽 == 64, o[1].号, 0, o[0].号);
            出(0x85);
            出((unsigned char)((3 << 6) | ((o[1].号 & 7) << 3) | (o[0].号 & 7)));
            return;
        }
        if (o[0].类 == 寄存器 && o[1].类 == 数值) {
            if (o[0].号 == 0 && !o[1].有名) {
                出REX(1, 0, 0, 0); 出(0xA9); 出32(o[1].值); return;
            }
            出REX(1, 0, 0, o[0].号); 出(0xF7);
            出((unsigned char)((3 << 6) | (0 << 3) | (o[0].号 & 7)));
            出32(o[1].值);
            return;
        }
        总错 = 1; return;
    }
    if (!strcmp(mn, "imul")) {
        if (o[0].类 != 寄存器) { 总错 = 1; return; }
        if (o[1].类 == 寄存器) {                    /* 0F AF /r ：reg = 目标 */
            出REX(1, o[0].号, 0, o[1].号);
            出(0x0F); 出(0xAF);
            出((unsigned char)((3 << 6) | ((o[0].号 & 7) << 3) | (o[1].号 & 7)));
            return;
        }
        if (o[1].类 == 数值) {
            if (!o[1].有名 && o[1].值 >= -128 && o[1].值 <= 127) {
                出REX(1, o[0].号, 0, o[0].号); 出(0x6B);
                出((unsigned char)((3 << 6) | ((o[0].号 & 7) << 3) | (o[0].号 & 7)));
                出((unsigned char)(o[1].值 & 255));
            } else {
                出REX(1, o[0].号, 0, o[0].号); 出(0x69);
                出((unsigned char)((3 << 6) | ((o[0].号 & 7) << 3) | (o[0].号 & 7)));
                出32(o[1].值);
            }
            return;
        }
        总错 = 1; return;
    }
    if (!strcmp(mn, "div") || !strcmp(mn, "idiv") || !strcmp(mn, "mul") ||
        !strcmp(mn, "neg") || !strcmp(mn, "not")) {
        int 段 = !strcmp(mn, "div") ? 6 : !strcmp(mn, "idiv") ? 7 : !strcmp(mn, "mul") ? 4
               : !strcmp(mn, "neg") ? 3 : 2;
        if (o[0].类 == 寄存器 && o[0].宽 == 64) {
            出REX(1, 0, 0, o[0].号); 出(0xF7);
            出((unsigned char)((3 << 6) | (段 << 3) | (o[0].号 & 7)));
            return;
        }
        总错 = 1; return;
    }
    if (!strcmp(mn, "shl") || !strcmp(mn, "sal") || !strcmp(mn, "shr") || !strcmp(mn, "sar")) {
        int 段 = (!strcmp(mn, "shr")) ? 5 : (!strcmp(mn, "sar")) ? 7 : 4;
        if (o[0].类 != 寄存器 || o[0].宽 != 64) { 总错 = 1; return; }
        if (o[1].类 == 寄存器 && o[1].宽 == 8) {          /* cl */
            出REX(1, 0, 0, o[0].号); 出(0xD3);
            出((unsigned char)((3 << 6) | (段 << 3) | (o[0].号 & 7)));
            return;
        }
        if (o[1].类 == 数值) {
            if (o[1].值 == 1) {
                出REX(1, 0, 0, o[0].号); 出(0xD1);
                出((unsigned char)((3 << 6) | (段 << 3) | (o[0].号 & 7)));
            } else {
                出REX(1, 0, 0, o[0].号); 出(0xC1);
                出((unsigned char)((3 << 6) | (段 << 3) | (o[0].号 & 7)));
                出((unsigned char)(o[1].值 & 255));
            }
            return;
        }
        总错 = 1; return;
    }
    {
        static const struct { const char *名; int 码; } 集[] = {
            {"seto",0x90},{"setno",0x91},{"setb",0x92},{"setae",0x93},{"sete",0x94},{"setne",0x95},
            {"setbe",0x96},{"seta",0x97},{"sets",0x98},{"setns",0x99},{"setp",0x9A},{"setnp",0x9B},
            {"setl",0x9C},{"setge",0x9D},{"setle",0x9E},{"setg",0x9F},{0,0} };
        for (int i = 0; 集[i].名; i++) if (!strcmp(mn, 集[i].名)) {
            if (o[0].类 != 寄存器 || o[0].宽 != 8) { 总错 = 1; return; }
            出REX(0, 0, 0, o[0].号);
            出(0x0F); 出((unsigned char)集[i].码);
            出((unsigned char)((3 << 6) | (0 << 3) | (o[0].号 & 7)));
            return;
        }
    }
    if (!strcmp(mn, "jmp")) {
        本跳 = 1; strncpy(本靶, o[0].名, 191);
        if (本短) { 出(0xEB); 出(0); 记待补(2, o[0].名, 0, 1); }
        else      { 出(0xE9); 出32(0); 记待补(1, o[0].名, 0, 4); }
        return;
    }
    if (!strcmp(mn, "call")) {
        本跳 = 1; strncpy(本靶, o[0].名, 191);
        出(0xE8); 出32(0); 记待补(1, o[0].名, 0, 4); return;
    }
    for (int i = 0; 跳转集[i].名; i++) if (!strcmp(mn, 跳转集[i].名)) {
        本跳 = 2;
        strncpy(本靶, o[0].名, 191);
        if (本短) { 出((unsigned char)(跳转集[i].码 - 0x10)); 出(0); 记待补(2, o[0].名, 0, 1); }
        else      { 出(0x0F); 出((unsigned char)跳转集[i].码); 出32(0); 记待补(1, o[0].名, 0, 4); }
        return;
    }
    总错 = 1;
}

/* ══════════════════════════════════════════════════════════════════════
   排版：迭代松弛 + 回填 + 落盘
   ══════════════════════════════════════════════════════════════════════ */
static int 收尾(const char *路径, long 载入) {
    int n = 指令数;
    static int 起[最多指令 + 1];
    static int 尺寸[最多指令];

    for (int i = 0; i < n; i++) {
        换区(区_文本);
        本短 = 0; 区长[区_文本] = 0; 写前缀(); 编码(指令文[i]);
        指令长[i] = 区长[区_文本] - 文本前缀长;
        指令跳[i] = 本跳;
        if (本跳) { strncpy(指令靶[i], 本靶, 191); 指令靶[i][191] = 0; }
        else 指令靶[i][0] = 0;

        指令短[i] = 0;
        if (本跳) {
            本短 = 1; 区长[区_文本] = 0; 写前缀(); 编码(指令文[i]);
            指令短[i] = 区长[区_文本] - 文本前缀长;
        }
    }
    if (总错) {
        fprintf(stderr, "编码器：有 %d 条指令编不了：\n", 失败数);
        for (int i = 0; i < 失败数; i++) fprintf(stderr, "   %s\n", 失败集[i]);
        return 1;
    }

    for (int i = 0; i < n; i++) 尺寸[i] = 指令长[i];
    for (int 轮 = 0; 轮 < 24; 轮++) {
        起[0] = 文本前缀长;
        for (int i = 0; i < n; i++) 起[i + 1] = 起[i] + 尺寸[i];
        int 变 = 0;
        for (int i = 0; i < n; i++) {
            if (!指令短[i]) continue;
            int j = 找标号(指令靶[i]);
            if (j < 0 || 标号表[j].区 != 区_文本) continue;
            long 目标 = 起[标号表[j].指令序];
            /* ★ 向前跳：目标跟着前移，相对距离不变
               向后跳：目标不动，相对距离多出 Δ                */
            long 相对 = 目标 - (起[i] + 尺寸[i]);
            if (目标 <= 起[i]) 相对 += (尺寸[i] - 指令短[i]);
            int 要 = (相对 >= -128 && 相对 <= 127) ? 指令短[i] : 指令长[i];
            if (尺寸[i] != 要) { 尺寸[i] = 要; 变 = 1; }
        }
        if (!变) break;
    }

    待补数 = 0; 总错 = 0;
    换区(区_文本); 区长[区_文本] = 0;
    写前缀();
    for (int i = 0; i < n; i++) {
        本短 = (指令短[i] > 0 && 尺寸[i] == 指令短[i]) ? 1 : 0;
        编码(指令文[i]);
        起[i + 1] = 区长[区_文本];
    }

    区基[区_文本] = (int)载入;
    int p = (区长[区_文本] + 3) & ~3;
    区基[区_只读] = (int)载入 + p;
    p = (p + 区长[区_只读] + 3) & ~3;
    区基[区_未初] = (int)载入 + p;
    for (int i = 0; i < 标号数; i++)
        if (标号表[i].区 == 区_文本) 标号表[i].偏移 = 起[标号表[i].指令序];

    int 未回填 = 0, 外部 = 0;
    for (int i = 0; i < 待补数; i++) {
        一笔待补 *t = &待补表[i];
        int j = 找标号(t->名);
        int 要占位 = 0;
        if (占位模式 && j >= 0) {
            if (!strncmp(t->名, "fn_", 3) || !strncmp(t->名, "g__", 3)) 要占位 = 1;
            else if (标号表[j].区 != 区_文本) 要占位 = 1;
        }
        long v;
        if (j >= 0 && !要占位) {
            long 目标 = (long)区基[标号表[j].区] + 标号表[j].偏移;
            long 处   = (long)区基[t->区] + t->处;
            if (t->类 == 0)      v = 目标 + t->加数;
            else if (t->类 == 1) v = 目标 - (处 + 4);
            else {
                v = 目标 - (处 + 1);
                if (v < -128 || v > 127) { fprintf(stderr, "编码器：rel8 越界\n"); 未回填++; continue; }
            }
        } else {
            /* ★ x86-64 用 RELA：加数写在重定位表里，字段本身留 0
               （32 位用 REL，那时才要写 -4）*/
            if (t->类 == 1)      v = 0;
            else if (t->类 == 2) v = 0;
            else v = 0;          /* ★ 64 位：不管跨不跨节，字段一律留 0 */
            外部++;
            if (重定位路径[0])
                重定位里记(t->处, t->类, t->名);
        }
        区体[t->区][t->处] = v & 255;
        if (t->类 != 2) {
            区体[t->区][t->处 + 1] = (v >> 8) & 255;
            区体[t->区][t->处 + 2] = (v >> 16) & 255;
            区体[t->区][t->处 + 3] = (v >> 24) & 255;
        }
    }

    /* ── 顺便出一份「六爻」：3 字节 = 24 位 = 正好 4 个六爻 ── */
    {
        static const char 卦字母[8] = { 'd','r','s','f','l','h','z','t' };  /* 值 0..7 */
        char 六爻路径[600];
        snprintf(六爻路径, sizeof 六爻路径, "%s.六爻.ly", 路径);
        FILE *q = fopen(六爻路径, "w");
        if (q) {
            int 总 = 区长[区_文本] + 区长[区_只读];
            for (int b = 0; b < 总; b += 3) {
                long v = 0;
                for (int k = 0; k < 3; k++)
                    v = (v << 8) | (b + k < 总 ? 区体[b + k < 区长[区_文本] ? 区_文本 : 区_只读]
                                                [b + k - (b + k < 区长[区_文本] ? 0 : 区长[区_文本])] : 0);
                for (int k = 3; k >= 0; k--) {
                    int 爻 = (v >> (6 * k)) & 63;
                    fputc(卦字母[(爻 >> 3) & 7], q);
                    fputc(卦字母[爻 & 7], q);
                    fputc(' ', q);
                }
                fputc('\n', q);
            }
            fclose(q);
        }
    }

    FILE *f = fopen(路径, "wb");
    if (!f) { fprintf(stderr, "编码器：打不开 %s\n", 路径); return 1; }
    fwrite(区体[区_文本], 1, 区长[区_文本], f);
    for (int i = 区长[区_文本]; i < ((区长[区_文本] + 3) & ~3); i++) fputc(0, f);
    fwrite(区体[区_只读], 1, 区长[区_只读], f);
    fclose(f);

    if (重定位文件) { fclose(重定位文件); 重定位文件 = NULL; }
    if (符号表路径[0]) {
        {   /* 先把三个区的长度写出来，小链接器要用 */
            char q[520]; snprintf(q, sizeof q, "%s.尺寸", 符号表路径);
            FILE *zf = fopen(q, "w");
            if (zf) { fprintf(zf, "%d %d %d\n", 区长[区_文本], 区长[区_只读], 区长[区_未初]); fclose(zf); }
        }
        FILE *sf = fopen(符号表路径, "w");
        if (sf) {
            for (int i = 0; i < 标号数; i++)
                fprintf(sf, "%s %d %d\n", 标号表[i].名, 标号表[i].区, 标号表[i].偏移);
            fclose(sf);
        }
        fprintf(stderr, "符号表：%d 个\n", 标号数);
    }
    printf("     编码器：.text %d 字节 / .rodata %d 字节 / .bss %d 字节 / "
           "回填 %d 笔（外部 %d）%s\n",
           区长[区_文本], 区长[区_只读], 区长[区_未初], 待补数, 外部,
           未回填 ? "  ✗ 有没回填的" : "  ✓");
    if (总错) { fprintf(stderr, "编码器：编不了\n"); return 1; }
    return 未回填 ? 1 : 0;
}
