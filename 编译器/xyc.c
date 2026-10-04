/* ============================================================================
 *  xyc —— 新语(XinYu) 编译器  stage0  v0.3
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  规则 R1：编译器用 C 写，由 gcc/clang 直接构建。
 *  输出：i386 汇编（GNU as，Intel 语法）→ Multiboot1 内核 ELF
 *
 *  构建:  TMPDIR=/tmp cc -O2 -o xyc xyc.c
 *  用法:  ./xyc 输入.xy -o 输出.s
 *
 *  语言要点
 *    关键字（拼音缩写）: hs 函数 / fh 返回 / bl 不可变绑定 / kb 可变绑定
 *                        rg 如果 / bz 不然 / xh 无限循环 / dy 条件循环
 *                        tc 跳出 / jx 继续 / qj 全局
 *                        wy 位与 / wh 位或 / yh 异或（中缀关键字运算符）
 *    类型: u8 u16 u32 u64 i8 i16 i32 i64 z ；指针 *类型
 *    声明: 名字 [ '[' 长度 ']' ] [ ':' 类型 ] [ '=' 初值 ]
 *    运算符: @x 取地址   ^p 解引用（按字节）   p[i] / 数组名[i] 下标
 *    字符串字面量可作值（求值为地址）
 * ==========================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

static void die(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    fprintf(stderr, "xyc: "); vfprintf(stderr, fmt, ap); fprintf(stderr, "\n");
    va_end(ap); exit(1);
}
static void *xmalloc(size_t n) { void *p = malloc(n); if (!p) die("内存不足"); return p; }
static void *xrealloc(void *p, size_t n) { void *q = realloc(p, n); if (!q) die("内存不足"); return q; }

/* ================================================================ 词法 */

enum { TK_EOF, TK_NL, TK_NUM, TK_STR, TK_ID, TK_KW, TK_TY, TK_P };

typedef struct { int k; long v; char *s; int line; } Tok;

static Tok *toks; static int ntoks, tpos, srcline;

static const char *KEYWORDS[] = { "hs","fh","bl","kb","jc","rg","bz","xh","dy",
                                  "tc","jx","jg","mk","wb","nl","qj","wx", NULL };
static const char *OPKW[]     = { "wy","wh","yh", NULL };
static const char *TYPES[]    = { "u8","u16","u32","u64","i8","i16","i32","i64","z", NULL };

static int in_list(const char **l, const char *w) {
    for (int i = 0; l[i]; i++) if (!strcmp(l[i], w)) return 1;
    return 0;
}
static int is_idc(int c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || (unsigned char)c >= 0x80;
}

static void lex(const char *src) {
    int cap = 512; toks = xmalloc(cap * sizeof(Tok)); ntoks = 0; srcline = 1;
    const char *p = src;
    while (*p) {
        if (*p == ' ' || *p == '\t' || *p == '\r') { p++; continue; }
        if (*p == '\n') {
            if (ntoks + 2 >= cap) { cap *= 2; toks = xrealloc(toks, cap * sizeof(Tok)); }
            toks[ntoks++] = (Tok){TK_NL, 0, "\n", srcline}; srcline++; p++; continue;
        }
        if (*p == '@') { while (*p && *p != '\n') p++; continue; }   /* @ 是注释 */
        if (*p == '#') { while (*p && *p != '\n') p++; continue; }   /* # 兼容保留 */
        if (ntoks + 2 >= cap) { cap *= 2; toks = xrealloc(toks, cap * sizeof(Tok)); }

        if (*p == '"') {
            p++; char buf[8192]; int n = 0;
            while (*p && *p != '"') {
                if (*p == '\\' && p[1]) {
                    p++; char c = *p;
                    buf[n++] = (c == 'n') ? '\n' : (c == 't') ? '\t' : (c == '0') ? '\0'
                             : (c == 'e') ? 27 : (c == 'r') ? 13 : (c == 'b') ? 8 : c;
                    p++;
                } else buf[n++] = *p++;
            }
            if (*p != '"') die("第 %d 行：字符串没有闭合", srcline);
            p++; buf[n] = 0;
            char *s = xmalloc(n + 1); memcpy(s, buf, n + 1);
            toks[ntoks++] = (Tok){TK_STR, 0, s, srcline};
            continue;
        }
        if (*p >= '0' && *p <= '9') {
            char *end; long v = strtol(p, &end, 0);
            toks[ntoks++] = (Tok){TK_NUM, v, NULL, srcline};
            p = end; continue;
        }
        if (is_idc((unsigned char)*p)) {
            const char *q = p;
            while (is_idc((unsigned char)*q) || (*q >= '0' && *q <= '9')) q++;
            int n = (int)(q - p);
            char *w = xmalloc(n + 1); memcpy(w, p, n); w[n] = 0;
            int k = TK_ID;
            if (in_list(KEYWORDS, w) || in_list(OPKW, w)) k = TK_KW;
            else if (in_list(TYPES, w)) k = TK_TY;
            toks[ntoks++] = (Tok){k, 0, w, srcline};
            p = q; continue;
        }
        /* 双字符 */
        if ((p[0] == '<' && p[1] == '<') || (p[0] == '>' && p[1] == '>') ||
            (p[0] == '-' && p[1] == '>') ||
            ((p[0] == '=' || p[0] == '!' || p[0] == '<' || p[0] == '>') && p[1] == '=') ||
            ((p[0] == '&' && p[1] == '&') || (p[0] == '|' && p[1] == '|'))) {
            char *s = xmalloc(3); s[0] = p[0]; s[1] = p[1]; s[2] = 0;
            toks[ntoks++] = (Tok){TK_P, 0, s, srcline};
            p += 2; continue;
        }
        if (strchr("(){}[]:;,=+-*/%<>!@^&|.", *p)) {
            char *s = xmalloc(2); s[0] = *p; s[1] = 0;
            toks[ntoks++] = (Tok){TK_P, 0, s, srcline};
            p++; continue;
        }
        die("第 %d 行：不认识的字符 '%c'", srcline, *p);
    }
    toks[ntoks++] = (Tok){TK_EOF, 0, NULL, srcline};
}

/* ================================================================ 输出 */

static FILE *out;
static int labeln;
static char *strtab[1024]; static int nstr;

static void em(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    fprintf(out, "\t"); vfprintf(out, fmt, ap); fprintf(out, "\n");
    va_end(ap);
}
static void lbl(const char *s) { fprintf(out, "%s:\n", s); }
static char *newlab(const char *pre, char *buf) { sprintf(buf, ".L%s%d", pre, ++labeln); return buf; }

static char *mangle(const char *name) {
    static char buf[1024]; int n = 0;
    for (const unsigned char *p = (const unsigned char *)name; *p; p++) {
        if ((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '_')
            buf[n++] = *p;
        else n += sprintf(buf + n, "_%02x", *p);
        if (n > 1000) break;
    }
    buf[n] = 0; return buf;
}

/* ================================================================ 符号表 */

typedef struct {
    char *name;
    int off;              /* 局部：相对 ebp 的偏移 */
    int size;             /* 单元素字节数 */
    int count;            /* 元素个数（非数组 = 1） */
    int mut, declared;
    int is_ptr;            /* 是否为指针变量 */
    int struct_idx;        /* 结构体类型索引，-1 表示非结构体 */
    char glabel[256];
} Var;

static Var vars[1024];   static int nvars, framesz;    /* 局部，逐函数重置 */
static Var globals[256]; static int nglobals;          /* 全局，全程有效 */
static int in_function;
static int in_wx;          /* 是否处于危险块内 */
static int wx_blocks;      /* 危险块数量（统计） */
static int raw_ops;        /* 原始指针操作数量（统计） */

static int var_find_local(const char *n) {
    for (int i = 0; i < nvars; i++) if (!strcmp(vars[i].name, n)) return i;
    return -1;
}
static int global_find(const char *n) {
    for (int i = 0; i < nglobals; i++) if (!strcmp(globals[i].name, n)) return i;
    return -1;
}
static int var_new(const char *n) {
    int i = var_find_local(n);
    if (i >= 0) return i;
    vars[nvars].name = (char *)n; vars[nvars].off = 0; vars[nvars].size = 4;
    vars[nvars].count = 1; vars[nvars].mut = 1; vars[nvars].declared = 0;
    vars[nvars].is_ptr = 0; vars[nvars].struct_idx = -1;
    vars[nvars].glabel[0] = 0;
    return nvars++;
}
static int elem_size_of_type(const char *t) {
    if (!t) return 4;
    if (!strcmp(t, "u8") || !strcmp(t, "i8") || !strcmp(t, "z")) return 1;
    if (!strcmp(t, "u16") || !strcmp(t, "i16")) return 2;
    return 4;
}

/* ---------------- 结构体表 ---------------- */
#define MAX_FIELDS 32
typedef struct { char *name; int size; int off; } Field;
typedef struct { char *name; Field f[MAX_FIELDS]; int nf; int size; } StructDef;
static StructDef structs[64]; static int nstructs;

static int struct_find(const char *n) {
    for (int i = 0; i < nstructs; i++) if (!strcmp(structs[i].name, n)) return i;
    return -1;
}
static int dummy_ptr, dummy_ptr2;
static int struct_field_idx(int si, const char *fn) {
    for (int i = 0; i < structs[si].nf; i++) if (!strcmp(structs[si].f[i].name, fn)) return i;
    return -1;
}

/* ================================================================ 循环与返回 */

static char loop_top[64][32], loop_end[64][32]; static int nloops;
static char *retlabel;

/* ================================================================ 语法工具 */

static Tok *cur(void) { return &toks[tpos]; }
static Tok *peek(int k) { return &toks[tpos + k]; }
static void adv(void) { if (toks[tpos].k != TK_EOF) tpos++; }
static int is_p(const char *s) { return cur()->k == TK_P && !strcmp(cur()->s, s); }
static int is_kw(const char *s) { return cur()->k == TK_KW && !strcmp(cur()->s, s); }
static void skip_nl(void) { while (cur()->k == TK_NL) adv(); }
static void expect_p(const char *s) {
    if (!is_p(s)) die("第 %d 行：期望 '%s'，实际是 '%s'", cur()->line, s, cur()->s ? cur()->s : "行尾");
    adv();
}

static void expr(int minprec);
static void block(void);
static void stmt(void);

static int prec_of(const char *op) {
    if (!strcmp(op, "||")) return 1;
    if (!strcmp(op, "&&")) return 2;
    if (!strcmp(op, "wh")) return 3;
    if (!strcmp(op, "yh")) return 4;
    if (!strcmp(op, "wy")) return 5;
    if (!strcmp(op, "==") || !strcmp(op, "!=")) return 6;
    if (!strcmp(op, "<") || !strcmp(op, "<=") || !strcmp(op, ">") || !strcmp(op, ">=")) return 7;
    if (!strcmp(op, "<<") || !strcmp(op, ">>")) return 8;
    if (!strcmp(op, "+") || !strcmp(op, "-")) return 9;
    if (!strcmp(op, "*") || !strcmp(op, "/") || !strcmp(op, "%")) return 10;
    return 0;
}

/* 取左值地址 → eax；返回 1=全局 0=局部 -1=不存在 */
static int lvalue_addr(const char *name, int *elem) {
    int i = var_find_local(name);
    if (i >= 0) { *elem = vars[i].size; em("lea eax, [ebp%+d]", vars[i].off); return 0; }
    int g = global_find(name);
    if (g >= 0) { *elem = globals[g].size; em("mov eax, offset %s", globals[g].glabel); return 1; }
    return -1;
}
static int lvalue_size(const char *name) {
    int i = var_find_local(name); if (i >= 0) return vars[i].size;
    int g = global_find(name);    if (g >= 0) return globals[g].size;
    return 4;
}
static int lvalue_count(const char *name) {
    int i = var_find_local(name); if (i >= 0) return vars[i].count;
    int g = global_find(name);    if (g >= 0) return globals[g].count;
    return 1;
}

/* ================================================================ 表达式 */


/* 计算 名[下标].字段 的地址 → eax；返回 1=全局 0=局部 -1=不存在；*width=读写宽度 */
static int lvalue_full(const char *name, int *width, int *had, int ln) {
    int li = var_find_local(name), gi = -1, elem, count, sidx, isptr = 0;
    if (li >= 0) {
        elem = vars[li].size; count = vars[li].count;
        sidx = vars[li].struct_idx; isptr = vars[li].is_ptr;
        em("lea eax, [ebp%+d]", vars[li].off);
    } else {
        gi = global_find(name);
        if (gi < 0) return -1;
        elem = globals[gi].size; count = globals[gi].count;
        sidx = globals[gi].struct_idx;
        em("mov eax, offset %s", globals[gi].glabel);
    }
    *width = elem;
    if (had) *had = 0;

    if (is_p("[")) {                      /* 下标 */
        adv();
        if (had) *had = 1;
        if (isptr && !in_wx)
            die("第 %d 行：指针下标是危险操作，必须写在 wx { } 危险块内", ln);
        expr(0); expect_p("]");
        if (!isptr && count > 1) {        /* 定长数组：越界检查 */
            char lok[32];
            em("cmp eax, %d", count);
            em("jb %s", newlab("bok", lok));
            em("call _rt_oob");
            lbl(lok);
        }
        if (elem > 1) em("imul eax, %d", elem);
        em("push eax");
        if (li >= 0) em("lea eax, [ebp%+d]", vars[li].off);
        else         em("mov eax, offset %s", globals[gi].glabel);
        em("mov ecx, eax");
        em("pop eax");
        em("add eax, ecx");
    }

    if (is_p(".")) {                      /* 字段 */
        adv();
        if (had) *had = 1;
        if (cur()->k != TK_ID) die("第 %d 行：'.' 后面必须是字段名", ln);
        if (sidx < 0) die("第 %d 行：%s 不是结构体类型，不能取字段", ln, name);
        int f = struct_field_idx(sidx, cur()->s);
        if (f < 0) die("第 %d 行：结构体 %s 没有字段 %s", ln, structs[sidx].name, cur()->s);
        if (structs[sidx].f[f].off) em("add eax, %d", structs[sidx].f[f].off);
        *width = structs[sidx].f[f].size;
        adv();
    }
    return li >= 0 ? 0 : 1;
}

/* ---- 图形/输入内建：名字 → 运行时符号 + 参数个数（实现在 图形.asm）---- */
static const struct { const char *name; const char *sym; int nargs; } GFX_BUILTINS[] = {
    {"屏宽",   "_gfx_getw",      0},
    {"屏高",   "_gfx_geth",      0},
    {"帧址",   "_gfx_getfb",     0},
    {"行宽",   "_gfx_getpitch",  0},
    {"内存",   "_gfx_getmem",    0},
    {"毫秒",   "_gfx_ms",        0},
    {"键",     "_gfx_key",       0},
    {"鼠x",    "_gfx_msx",       0},
    {"鼠y",    "_gfx_msy",       0},
    {"鼠钮",   "_gfx_msbtn",     0},
    {"轮询",   "_gfx_poll",      0},
    {"时",     "_gfx_hour",      0},
    {"分",     "_gfx_min",       0},
    {"秒",     "_gfx_sec",       0},
    {"睡",     "_gfx_sleep",     1},
    {"绘点",   "_gfx_px",        3},
    {"取点",   "_gfx_getpx",     2},
    {"绘块",   "_gfx_fill",      5},
    {"绘框",   "_gfx_frame",     5},
    {"绘字",   "_gfx_text",      4},
    {"绘数",   "_gfx_num",       4},
    {"绘十六", "_gfx_hex",       4},
    {"绘块混", "_gfx_fillblend", 6},
    {"滚屏",   "_gfx_scrollup",   2},
    {"滚块",   "_gfx_scrollrect", 6},
    /* ---- 机器原语（原语.asm）---- */
    {"端入",   "_pr_in8",        1},
    {"端入字", "_pr_in16",       1},
    {"端出",   "_pr_out8",       2},
    {"端出字", "_pr_out16",      2},
    {"读32",   "_pr_ld32",       1},
    {"写32",   "_pr_st32",       2},
    {"读8",    "_pr_ld8",        1},
    {"写8",    "_pr_st8",        2},
    {"停机",   "_pr_halt",       0},
    {"调用",   "_pr_call",       5},
    {"读CPUID","_pr_cpuid",      2},
    {"CPUE",   "_pr_ca",         0},
    {"CPUB",   "_pr_cb",         0},
    {"CPUC",   "_pr_cc",         0},
    {"CPUD",   "_pr_cd",         0},
    {"端出32", "_pr_out32",      2},
    {"端入32", "_pr_in32",       1},
    {NULL, NULL, 0}
};

static void primary(void) {
    Tok *t = cur();

    if (t->k == TK_NUM) { em("mov eax, %ld", t->v); adv(); return; }

    if (t->k == TK_STR) {
        if (nstr >= 1024) die("字符串太多");
        strtab[nstr++] = t->s; adv();
        em("mov eax, offset .Lstr%d", nstr - 1);
        return;
    }

    if (t->k == TK_ID) {
        char *name = t->s;

        /* 图形 / 输入内建（优先于编译器自带内建，实现在 图形.asm） */
        for (int bi = 0; GFX_BUILTINS[bi].name; bi++) {
            if (strcmp(name, GFX_BUILTINS[bi].name)) continue;
            if (peek(1)->k != TK_P || strcmp(peek(1)->s, "(")) break;
            adv(); adv();
            for (int a = 0; a < GFX_BUILTINS[bi].nargs; a++) {
                expr(0);
                em("push eax");
                if (a + 1 < GFX_BUILTINS[bi].nargs) expect_p(",");
            }
            expect_p(")");
            em("call %s", GFX_BUILTINS[bi].sym);
            if (GFX_BUILTINS[bi].nargs)
                em("add esp, %d", GFX_BUILTINS[bi].nargs * 4);
            return;
        }

        /* 内建：出(c) —— 输出一个字节到串口 */
        if (!strcmp(name, "出") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            expr(0); expect_p(")");
            em("push eax"); em("call _rt_putc"); em("add esp, 4");
            return;
        }

        /* 内建：清() —— 清屏 */
        if (!strcmp(name, "清") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv(); expect_p(")"); em("call _rt_cls"); em("mov eax, 0"); return;
        }
        /* 内建：置光标(行, 列) */
        if (!strcmp(name, "置光标") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            expr(0); em("push eax"); expect_p(","); expr(0); em("push eax");
            em("call _rt_goto"); em("add esp, 8"); em("mov eax, 0");
            expect_p(")"); return;
        }

        /* 内建：印串(s) —— 输出一个以 0 结尾的字符串（指针） */
        if (!strcmp(name, "印串") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            expr(0);
            em("push eax"); em("call _rt_puts"); em("add esp, 4");
            expect_p(")");
            return;
        }

        /* 内建：地址(名) —— 取变量地址（危险操作，须在 wx 内） */
        if (!strcmp(name, "地址") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            if (!in_wx)
                die("第 %d 行：取地址是危险操作，必须写在 wx { } 危险块内", t->line);
            adv(); adv(); raw_ops++;
            if (cur()->k != TK_ID) die("第 %d 行：地址() 里面必须是名字", cur()->line);
            char *vn = cur()->s; int vln = cur()->line; adv();
            int elem = 4;
            if (lvalue_addr(vn, &elem) < 0) die("第 %d 行：名字不存在：%s", vln, vn);
            expect_p(")");
            return;
        }

        /* 内建：键() —— 从 PS/2 键盘读一个键（阻塞） */
        if (!strcmp(name, "键") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv(); expect_p(")"); em("call _rt_getkey"); return;
        }

        /* 内建：读() —— 从串口读一个字节（阻塞） */
        if (!strcmp(name, "读") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            expect_p(")");
            em("call _rt_getc");
            return;
        }

        /* 函数调用 */
        if (peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            int n = 0;
            if (!is_p(")")) {
                for (;;) {
                    expr(0); em("push eax"); n++;
                    if (is_p(",")) { adv(); continue; }
                    break;
                }
            }
            expect_p(")");
            em("call fn_%s", mangle(name));
            if (n) em("add esp, %d", 4 * n);
            return;
        }

        /* 变量（可能带下标与字段） */
        adv();
        int width = 4, had = 0;
        int isg = lvalue_full(name, &width, &had, t->line);
        if (isg < 0) die("第 %d 行：名字不存在：%s", t->line, name);
        if (had == 0 && lvalue_count(name) > 1) return;     /* 纯数组名 → 地址 */
        if (width == 1) em("movzx eax, byte ptr [eax]");
        else if (width == 2) em("movzx eax, word ptr [eax]");
        else em("mov eax, [eax]");
        return;
    }

    if (is_p("(")) { adv(); expr(0); expect_p(")"); return; }

    die("第 %d 行：表达式里出现意外的 '%s'", t->line, t->s ? t->s : "行尾");
}

static void unary(void) {
    if (is_p("-")) { adv(); unary(); em("neg eax"); return; }
    if (is_p("!")) { adv(); unary(); em("test eax, eax"); em("sete al"); em("movzx eax, al"); return; }
    if (is_p("^")) {                                                             /* 解引用（字节） */
        if (!in_wx) die("第 %d 行：解引用原始指针是危险操作，必须写在 wx { } 危险块内", cur()->line);
        adv(); raw_ops++; unary(); em("movzx eax, byte ptr [eax]"); return;
    }
    primary();
}

static void binop_emit(const char *op) {
    em("mov ecx, eax"); em("pop eax");
    if (!strcmp(op, "+"))  { em("add eax, ecx"); return; }
    if (!strcmp(op, "-"))  { em("sub eax, ecx"); return; }
    if (!strcmp(op, "*"))  { em("imul eax, ecx"); return; }
    if (!strcmp(op, "/"))  { em("xor edx, edx"); em("div ecx"); return; }
    if (!strcmp(op, "%"))  { em("xor edx, edx"); em("div ecx"); em("mov eax, edx"); return; }
    if (!strcmp(op, "wy")) { em("and eax, ecx"); return; }
    if (!strcmp(op, "wh")) { em("or eax, ecx"); return; }
    if (!strcmp(op, "yh")) { em("xor eax, ecx"); return; }
    if (!strcmp(op, "<<")) { em("shl eax, cl"); return; }
    if (!strcmp(op, ">>")) { em("shr eax, cl"); return; }
    if (!strcmp(op, "==") || !strcmp(op, "!=") || !strcmp(op, "<") ||
        !strcmp(op, "<=") || !strcmp(op, ">") || !strcmp(op, ">=")) {
        em("cmp eax, ecx");
        const char *cc = !strcmp(op, "==") ? "e" : !strcmp(op, "!=") ? "ne" :
                         !strcmp(op, "<") ? "l" : !strcmp(op, "<=") ? "le" :
                         !strcmp(op, ">") ? "g" : "ge";
        em("set%s al", cc); em("movzx eax, al"); return;
    }
    if (!strcmp(op, "&&")) {
        em("test eax, eax"); em("setne al");
        em("test ecx, ecx"); em("setne cl");
        em("and al, cl"); em("movzx eax, al"); return;
    }
    if (!strcmp(op, "||")) { em("or eax, ecx"); em("setne al"); em("movzx eax, al"); return; }
    die("内部错误：未知运算符 %s", op);
}

static void expr(int minprec) {
    unary();
    for (;;) {
        const char *op = NULL;
        if (cur()->k == TK_P) op = cur()->s;
        else if (cur()->k == TK_KW && in_list(OPKW, cur()->s)) op = cur()->s;
        else break;
        int p = prec_of(op);
        if (p == 0 || p < minprec) break;
        char obuf[4]; strncpy(obuf, op, 3); obuf[3] = 0;
        adv();
        em("push eax");
        expr(p + 1);
        binop_emit(obuf);
    }
}

/* ================================================================ 语句 */

static void do_print(void) {
    adv(); expect_p("(");
    if (cur()->k == TK_STR) {
        if (nstr >= 1024) die("字符串太多");
        strtab[nstr++] = cur()->s; adv();
        em("push offset .Lstr%d", nstr - 1);
        em("call _rt_puts");
        em("add esp, 4");
    } else {
        expr(0); em("push eax"); em("call _rt_puti"); em("add esp, 4");
    }
    expect_p(")");
}

/* 类型：'*' 或 类型名；指针变量本身占 4 字节，解引用按字节 */
static void parse_type_only(int *size) { *size = 4; }
static void parse_type_only_ex(int *size, int *isptr, int *struct_idx) {
    *size = 4; *isptr = 0; *struct_idx = -1;
    if (is_p("*")) {
        adv(); *isptr = 1;
        if (cur()->k != TK_TY) die("第 %d 行：'*' 后面必须是类型", cur()->line);
        adv(); return;
    }
    if (cur()->k == TK_TY) { *size = elem_size_of_type(cur()->s); adv(); return; }
    if (cur()->k == TK_ID) {                       /* 结构体名 */
        int si = struct_find(cur()->s);
        if (si < 0) die("第 %d 行：未知的类型：%s", cur()->line, cur()->s);
        *size = structs[si].size; *struct_idx = si; adv(); return;
    }
    die("第 %d 行：缺少类型", cur()->line);
}

/* 声明尾：名字 [ '[' N ']' ] [ ':' 类型 ] */
static void parse_decl_tail(const char *name, int *size, int *count, int *sidx) {
    (void)name;
    *size = 4; *count = 1; if (sidx) *sidx = -1;
    if (is_p("[")) {
        adv();
        if (cur()->k != TK_NUM) die("第 %d 行：数组长度必须是常数", cur()->line);
        *count = (int)cur()->v; adv();
        expect_p("]");
    }
    if (is_p(":")) {
        adv();
        if (sidx) parse_type_only_ex(size, &dummy_ptr, sidx);
        else { int d = 0; parse_type_only_ex(size, &d, &dummy_ptr2); }
    }
}

static void stmt(void) {
    /* ---- 结构体定义（仅顶层） ---- */
    if (is_kw("jg")) {
        adv();
        int ln = cur()->line;
        if (in_function) die("第 %d 行：jg 只能出现在顶层", ln);
        if (cur()->k != TK_ID) die("第 %d 行：jg 后面必须是结构体名", ln);
        if (nstructs >= 64) die("结构体太多");
        int si = nstructs++;
        structs[si].name = cur()->s; structs[si].nf = 0; structs[si].size = 0;
        adv(); skip_nl(); expect_p("{"); skip_nl();
        while (!is_p("}") && cur()->k != TK_EOF) {
            if (cur()->k != TK_ID) die("第 %d 行：字段名缺失", cur()->line);
            char *fn = cur()->s; adv();
            expect_p(":");
            int sz = 4, ip = 0, nsi = -1;
            parse_type_only_ex(&sz, &ip, &nsi);
            if (structs[si].nf >= MAX_FIELDS) die("结构体字段太多");
            int fi = structs[si].nf++;
            structs[si].f[fi].name = fn;
            structs[si].f[fi].size = sz;
            structs[si].f[fi].off  = structs[si].size;
            structs[si].size += sz;
            skip_nl();
        }
        expect_p("}");
        return;
    }

    /* ---- 全局声明（仅顶层） ---- */
    if (is_kw("qj")) {
        adv();
        int ln = cur()->line;
        if (in_function) die("第 %d 行：qj 只能出现在顶层", ln);
        if (cur()->k != TK_ID) die("第 %d 行：qj 后面必须是名字", ln);
        char *name = cur()->s; adv();
        int size = 4, count = 1, sidx = -1;
        parse_decl_tail(name, &size, &count, &sidx);
        int g = global_find(name);
        if (g < 0) { g = nglobals++; globals[g].name = name; }
        /* ★ 全局数组的元素跨度也至少 4 字节：代码生成永远是 32 位存取，
           u8 数组若按 1 字节跨越，写第 i 个元素会覆盖后面三个 */
        globals[g].size = (size < 4 ? 4 : size); globals[g].count = count;
        globals[g].struct_idx = sidx;
        globals[g].mut = 1; globals[g].declared = 1;
        sprintf(globals[g].glabel, "g_%s", mangle(name));
        return;
    }

    /* ---- 局部绑定 ---- */
    if (is_kw("bl") || is_kw("kb")) {
        int mut = is_kw("kb"); adv();
        if (cur()->k != TK_ID) die("第 %d 行：声明必须跟一个名字", cur()->line);
        char *name = cur()->s; int ln = cur()->line; adv();
        int size = 4, count = 1, sidx = -1;
        parse_decl_tail(name, &size, &count, &sidx);
        int exist = var_find_local(name);
        if (exist >= 0 && vars[exist].declared)
            die("第 %d 行：%s 已经绑定过了", ln, name);
        int i = var_new(name);
        if (vars[i].off == 0) {                 /* 没有被 prescan 覆盖（极少见）：兜底 */
            /* ★ 每个槽至少 4 字节：代码生成永远是 32 位存取，
               u8/u16 局部若只分 1~2 字节，写入会覆盖相邻变量 */
            framesz += (size < 4 ? 4 : size) * count;
            vars[i].off = -framesz;
        }
        vars[i].size = size; vars[i].count = count; vars[i].mut = mut; vars[i].declared = 1;
        vars[i].struct_idx = sidx;
        if (is_p("=")) {
            adv();
            if (count > 1) die("第 %d 行：数组不能就地初始化", ln);
            expr(0);
            em("mov [ebp%+d], eax", vars[i].off);
        } else if (count == 1) {
            em("mov dword ptr [ebp%+d], 0", vars[i].off);
        }
        return;
    }

    /* ---- 条件 ---- */
    if (is_kw("rg")) {
        adv(); expr(0);
        char le[32], lx[32];
        em("test eax, eax");
        em("jz %s", newlab("else", le));
        expect_p("{"); block(); expect_p("}");
        if (is_kw("bz")) {
            em("jmp %s", newlab("endif", lx));
            lbl(le);
            adv(); expect_p("{"); block(); expect_p("}");
            lbl(lx);
        } else lbl(le);
        return;
    }

    /* ---- 无限循环 ---- */
    if (is_kw("xh")) {
        adv();
        char lt[32], lx[32];
        newlab("ltop", lt); newlab("lend", lx);
        lbl(lt);
        strcpy(loop_top[nloops], lt); strcpy(loop_end[nloops], lx); nloops++;
        expect_p("{"); block(); expect_p("}");
        nloops--;
        em("jmp %s", lt); lbl(lx);
        return;
    }

    /* ---- 条件循环 ---- */
    if (is_kw("dy")) {
        adv();
        char lt[32], lx[32];
        newlab("wtop", lt); newlab("wend", lx);
        strcpy(loop_top[nloops], lt); strcpy(loop_end[nloops], lx); nloops++;
        lbl(lt);
        expr(0);
        em("test eax, eax"); em("jz %s", lx);
        expect_p("{"); block(); expect_p("}");
        nloops--;
        em("jmp %s", lt); lbl(lx);
        return;
    }

    if (is_kw("tc")) { adv(); if (!nloops) die("第 %d 行：tc 不在循环里", cur()->line);
                       em("jmp %s", loop_end[nloops - 1]); return; }
    if (is_kw("jx")) { adv(); if (!nloops) die("第 %d 行：jx 不在循环里", cur()->line);
                       em("jmp %s", loop_top[nloops - 1]); return; }

    if (is_kw("fh")) {
        adv();
        if (cur()->k != TK_NL && !is_p("}")) expr(0); else em("mov eax, 0");
        em("jmp %s", retlabel);
        return;
    }

    if (is_kw("wx")) {                       /* 危险块 */
        adv();
        int saved = in_wx;
        in_wx = 1; wx_blocks++;
        expect_p("{"); block(); expect_p("}");
        in_wx = saved;
        return;
    }

    if (cur()->k == TK_ID && !strcmp(cur()->s, "印")) { do_print(); return; }

    if (cur()->k == TK_ID && !strcmp(cur()->s, "读")) {      /* 内建：读串口（阻塞） */
        adv();
        if (is_p("(")) { adv(); expect_p(")"); }
        em("call _rt_getc");
        return;
    }

    /* ---- 解引用赋值（按字节写） ---- */
    if (is_p("^")) {
        if (!in_wx) die("第 %d 行：解引用写入是危险操作，必须写在 wx { } 危险块内", cur()->line);
        adv(); raw_ops++; unary();           /* eax = 地址 */
        if (!is_p("=")) die("第 %d 行：解引用后只能是赋值", cur()->line);
        adv();
        em("push eax");
        expr(0);
        em("mov ecx, eax"); em("pop eax");
        em("mov byte ptr [eax], cl");
        return;
    }

    /* ---- 名字开头：赋值（标量 / 下标 / 字段） ---- */
    if (cur()->k == TK_ID && peek(1)->k == TK_P &&
        (!strcmp(peek(1)->s, "=") || !strcmp(peek(1)->s, "[") || !strcmp(peek(1)->s, "."))) {
        char *name = cur()->s; int ln = cur()->line;
        adv();

        int li_chk = var_find_local(name);
        int gi_chk = global_find(name);
        if (li_chk < 0 && gi_chk < 0) die("第 %d 行：名字不存在：%s", ln, name);
        if (li_chk >= 0 && !vars[li_chk].mut)
            die("第 %d 行：不可变绑定不可赋值：%s（要可变请用 kb 声明）", ln, name);

        if (is_p("[") || is_p(".")) {
            int width = 4, had = 0;
            (void)lvalue_full(name, &width, &had, ln);
            if (!is_p("=")) die("第 %d 行：这里只能赋值", ln);
            adv();
            em("push eax");
            expr(0);
            em("mov ecx, eax"); em("pop eax");
            if (width == 1) em("mov byte ptr [eax], cl");
            else if (width == 2) em("mov word ptr [eax], cx");
            else em("mov [eax], ecx");
            return;
        }

        expect_p("=");
        expr(0);
        if (li_chk >= 0) em("mov [ebp%+d], eax", vars[li_chk].off);
        else             em("mov [%s], eax", globals[gi_chk].glabel);
        return;
    }

    expr(0);   /* 表达式语句（函数调用） */
}

static void block(void) {
    skip_nl();
    while (!is_p("}") && cur()->k != TK_EOF) { stmt(); skip_nl(); }
}

/* 预扫描：为本函数所有局部绑定分配栈帧（序言必须在解析之前就知道 frame 大小） */
static void prescan_locals(int start) {
    int depth = 0;
    for (int i = start; i < ntoks; i++) {
        Tok *t = &toks[i];
        if (t->k == TK_P && !strcmp(t->s, "{")) depth++;
        else if (t->k == TK_P && !strcmp(t->s, "}")) { depth--; if (!depth) return; }
        else if (t->k == TK_KW && (!strcmp(t->s, "bl") || !strcmp(t->s, "kb"))) {
            if (toks[i + 1].k != TK_ID) continue;
            const char *nm = toks[i + 1].s;
            int size = 4, count = 1, j = i + 2;
            if (toks[j].k == TK_P && !strcmp(toks[j].s, "[")) { count = (int)toks[j + 1].v; j += 3; }
            if (toks[j].k == TK_P && !strcmp(toks[j].s, ":")) {
                j++;
                if (toks[j].k == TK_P && !strcmp(toks[j].s, "*")) { size = 4; j += 2; }
                else {
                    if (toks[j].k == TK_ID) { int si = struct_find(toks[j].s); size = (si >= 0) ? structs[si].size : 4; }
                    else size = elem_size_of_type(toks[j].s);
                    j++;
                }
            }
            int idx = var_new(nm);
            vars[idx].size = size; vars[idx].count = count; vars[idx].mut = 1;
            /* ★ 同上：槽至少 4 字节 */
            framesz += (size < 4 ? 4 : size) * count;
            vars[idx].off = -framesz;
        }
    }
}

static int nfunc;

static void parse_fn(void) {
    if (!is_kw("hs")) die("第 %d 行：顶层只能是 hs 函数定义或 qj 全局声明", cur()->line);
    adv();
    if (cur()->k != TK_ID) die("第 %d 行：hs 后面必须是函数名", cur()->line);
    char *name = cur()->s; adv();

    nvars = 0; framesz = 0;
    expect_p("(");
    int np = 0; char *pname[32];
    if (!is_p(")")) {
        for (;;) {
            if (cur()->k != TK_ID) die("第 %d 行：参数名缺失", cur()->line);
            pname[np++] = cur()->s; adv();
            if (is_p(":")) {
                adv();
                if (is_p("*")) { adv(); if (cur()->k != TK_TY) die("第 %d 行：参数类型缺失", cur()->line); adv(); }
                else if (cur()->k == TK_TY) adv();
                else die("第 %d 行：参数类型缺失", cur()->line);
            }
            if (is_p(",")) { adv(); continue; }
            break;
        }
    }
    expect_p(")");
    if (is_p("->")) { adv(); if (cur()->k != TK_TY) die("第 %d 行：返回类型缺失", cur()->line); adv(); }
    expect_p("{");

    char rlab[128]; sprintf(rlab, ".Lret_%s", mangle(name));
    retlabel = rlab;

    prescan_locals(tpos - 1);

    for (int i = 0; i < np; i++) {
        int idx = var_new(pname[i]);
        vars[idx].off = 8 + 4 * (np - 1 - i);
        vars[idx].declared = 1; vars[idx].mut = 0;
        vars[idx].size = 4; vars[idx].count = 1;
    }

    nfunc++;
    in_function = 1;
    fprintf(out, "%s\t.globl fn_%s\nfn_%s:\n", nfunc > 1 ? "\n" : "",
            mangle(name), mangle(name));
    em("push ebp"); em("mov ebp, esp");
    if (framesz) em("sub esp, %d", framesz);
    em("mov eax, 0");

    block();
    expect_p("}");

    fprintf(out, "%s:\n", retlabel);
    em("mov esp, ebp"); em("pop ebp"); em("ret");
    retlabel = NULL;
    in_function = 0;
}

/* ================================================================ 文件生成 */

static int no_mb = 0;   /* -nx：不生成 Multiboot 头（自研引导器路线） */
static int mod_mode = 0;/* -c ：模块（无 _start、无运行时、全局 .comm） */
static int main_mode = 0;/* -m ：主模块（有 _start、无运行时、全局 .comm） */
static int rt_mode = 0; /* -r ：只出运行时 */

static void emit_header(void) {
    fprintf(out, "# 由 新语(xinyu) 编译器 xyc 生成\n");
    fprintf(out, "\t.intel_syntax noprefix\n");
    if (!no_mb && !mod_mode && !rt_mode && !main_mode) {
        /* Multiboot 头：只有走 isolinux/mboot.c32 的老路线才需要 */
        fprintf(out, "\t.section .multiboot, \"a\"\n\t.align 4\n");
        fprintf(out, "\t.long 0x1BADB002\n\t.long 0x00000000\n\t.long 0x%08X\n",
                (unsigned)(-(long)0x1BADB002));
    }
    fprintf(out, "\n\t.section .text\n");
    if (rt_mode || (mod_mode && !main_mode)) return;   /* 模块/运行时：不出入口 */
    fprintf(out, "\t.globl _start\n_start:\n");
    em("mov esp, offset _kernel_stack_top");
    em("call _gfx_init");                  /* EBX = XBP，取自引导器 */
    em("call _rt_cls");                    /* 开机先清屏，抹掉引导器残留 */
    em("call fn_%s", mangle("主"));
    lbl(".Lhang"); em("cli"); em("hlt"); em("jmp .Lhang");
}

static void emit_globals_bss(void) {
    if (!nglobals) return;
    fprintf(out, "\n\t.section .bss\n\t.align 4\n");
    for (int i = 0; i < nglobals; i++)
        /* 模块模式：用 .comm 声明公共符号 —— 多个模块同名全局由链接器
           合并成一份。这正是"对象区在内核里只有一份"的物理保证。 */
        if (mod_mode || main_mode)
            fprintf(out, "\t.comm %s, %d, 4\n", globals[i].glabel,
                    globals[i].size * globals[i].count);
        else
            fprintf(out, "%s:\n\t.space %d\n", globals[i].glabel,
                    globals[i].size * globals[i].count);
}

static void emit_strings(void) {
    if (nstr) {
        fprintf(out, "\n\t.section .rodata\n");
        for (int i = 0; i < nstr; i++) {
            fprintf(out, ".Lstr%d:\n\t.asciz \"", i);
            for (const unsigned char *p = (const unsigned char *)strtab[i]; *p; p++) {
                if (*p == '\n')      fprintf(out, "\\n");
                else if (*p == '\t') fprintf(out, "\\t");
                else if (*p == '"')  fprintf(out, "\\\"");
                else if (*p == '\\') fprintf(out, "\\\\");
                else fputc(*p, out);
            }
            fprintf(out, "\"\n");
        }
        fprintf(out, "\t.section .text\n");
    }
}

static void emit_runtime(void) {
    /* 模块模式下，别的模块也要调运行时 —— 所以运行时的符号必须导出 */
    fprintf(out, "\t.globl _rt_putc, _rt_puts, _rt_puti, _rt_cls, _rt_goto,"
                 " _rt_scroll, _rt_oob, _rt_getc, _rt_getkey, _kernel_stack_top\n");
    /* 必须显式切回代码段：调用方可能刚写过 .bss（全局变量） */
    fprintf(out, "\n\t.section .text\n");
    fprintf(out, "# ---- 运行时：VGA 文本控制台(0xB8000) + COM1 串口 双路输出 ----\n");
    fprintf(out, "_rt_putc:\n");
    em("push eax"); em("push ebx"); em("push edx");
    em("movzx eax, byte ptr [esp+16]");
    em("push eax");
    em("mov dx, 0x3FD");
    lbl(".Lpc_w");
    em("in al, dx"); em("test al, 0x20"); em("jz .Lpc_w");
    em("mov dx, 0x3F8"); em("pop eax"); em("push eax"); em("out dx, al"); em("pop eax");
    em("test al, al"); em("js .Lpc_end");       /* >=0x80 的多字节字符：屏幕不显示 */
    em("test al, al"); em("js .Lpc_end");       /* >=0x80：多字节字符，文本模式显示不了，屏幕跳过 */
    em("cmp al, 8"); em("je .Lpc_bs");          /* 退格：光标回退并擦除 */
    em("cmp al, 10"); em("je .Lpc_nl");
    em("cmp al, 13"); em("je .Lpc_end");
    em("movzx ebx, word ptr [_rt_cursor]");
    em("cmp ebx, 2000"); em("jb .Lpc_put");
    em("call _rt_scroll"); em("movzx ebx, word ptr [_rt_cursor]");
    lbl(".Lpc_put");
    em("mov edx, 0xB8000"); em("add edx, ebx"); em("add edx, ebx");
    em("mov [edx], al"); em("mov byte ptr [edx+1], 0x0F");
    em("inc ebx"); em("mov [_rt_cursor], bx");
    em("cmp ebx, 2000"); em("jb .Lpc_end");
    em("call _rt_scroll");
    lbl(".Lpc_end");
    em("pop edx"); em("pop ebx"); em("pop eax"); em("ret");

    fprintf(out, "\n_rt_nl:\n");
    lbl(".Lnl_x");
    em("ret");

    fprintf(out, "\n.Lpc_bs:\n");
    em("movzx ebx, word ptr [_rt_cursor]");
    em("test ebx, ebx"); em("jz .Lpc_end");
    em("dec ebx"); em("mov [_rt_cursor], bx");
    em("mov edx, 0xB8000"); em("add edx, ebx"); em("add edx, ebx");
    em("mov byte ptr [edx], 32"); em("mov byte ptr [edx+1], 0x0F");
    em("jmp .Lpc_end");

    fprintf(out, "\n.Lpc_nl:\n");
    em("movzx ebx, word ptr [_rt_cursor]");
    em("mov eax, ebx"); em("xor edx, edx"); em("mov ecx, 80"); em("div ecx");
    em("inc eax"); em("imul eax, 80");
    em("cmp eax, 2000"); em("jb .Lpc_nl2");
    em("call _rt_scroll"); em("jmp .Lpc_end");
    lbl(".Lpc_nl2");
    em("mov [_rt_cursor], ax"); em("jmp .Lpc_end");

    fprintf(out, "\n_rt_scroll:\n");
    em("pushad");
    em("mov esi, 0xB8000+160"); em("mov edi, 0xB8000");
    em("mov ecx, 80*24");
    lbl(".Lsc_l");
    em("mov ax, [esi]"); em("mov [edi], ax");
    em("add esi, 2"); em("add edi, 2");
    em("dec ecx"); em("jnz .Lsc_l");
    em("mov ecx, 80"); em("mov ax, 0x0720");
    lbl(".Lsc_c");
    em("mov [edi], ax"); em("add edi, 2");
    em("dec ecx"); em("jnz .Lsc_c");
    em("mov word ptr [_rt_cursor], 80*24");
    em("popad"); em("ret");

    fprintf(out, "\n_rt_cls:\n");
    em("pushad");
    em("mov edi, 0xB8000"); em("mov ecx, 80*25"); em("mov ax, 0x0720");
    lbl(".Lcls_l");
    em("mov [edi], ax"); em("add edi, 2");
    em("dec ecx"); em("jnz .Lcls_l");
    em("mov word ptr [_rt_cursor], 0");
    em("popad"); em("ret");

    fprintf(out, "\n_rt_goto:\n");
    em("push eax"); em("push ecx"); em("push edx");
    em("mov eax, [esp+16]"); em("dec eax"); em("imul eax, 80");
    em("mov ecx, [esp+20]"); em("dec ecx"); em("add eax, ecx");
    em("mov [_rt_cursor], ax");
    em("pop edx"); em("pop ecx"); em("pop eax"); em("ret");

    fprintf(out, "\n\t.section .data\n_rt_cursor:\n\t.word 0\n\t.section .text\n");

    /* ---- PS/2 键盘：阻塞读一个键 ---- */
    fprintf(out, "\n# ---- PS/2 键盘 ----\n");
    fprintf(out, "_rt_getkey:\n");
    lbl(".Lgk_l");
    em("mov dx, 0x64"); em("in al, dx"); em("test al, 0x01"); em("jz .Lgk_l");
    em("mov dx, 0x60"); em("in al, dx"); em("movzx eax, al");
    /* 断码：处理 shift 抬起 */
    em("cmp eax, 0xAA"); em("je .Lgk_sh0");
    em("cmp eax, 0xB6"); em("je .Lgk_sh0");
    em("cmp eax, 0x2A"); em("je .Lgk_sh1");
    em("cmp eax, 0x36"); em("je .Lgk_sh1");
    em("test eax, 0x80"); em("jnz .Lgk_l");
    em("cmp eax, 0xE0"); em("je .Lgk_ext");
    em("cmp eax, 128"); em("jae .Lgk_l");
    em("mov ebx, offset _kb_map");
    em("cmp byte ptr [_rt_shift], 0"); em("je .Lgk_t");
    em("mov ebx, offset _kb_map_sh");
    lbl(".Lgk_t");
    em("add ebx, eax"); em("movzx eax, byte ptr [ebx]");
    em("test eax, eax"); em("jz .Lgk_l"); em("ret");
    lbl(".Lgk_sh0");
    em("mov byte ptr [_rt_shift], 0"); em("jmp .Lgk_l");
    lbl(".Lgk_sh1");
    em("mov byte ptr [_rt_shift], 1"); em("jmp .Lgk_l");
    lbl(".Lgk_ext");
    lbl(".Lgk_e2");
    em("mov dx, 0x64"); em("in al, dx"); em("test al, 0x01"); em("jz .Lgk_e2");
    em("mov dx, 0x60"); em("in al, dx"); em("movzx eax, al");
    em("cmp eax, 0x48"); em("je .Lgk_up");
    em("cmp eax, 0x50"); em("je .Lgk_dn");
    em("cmp eax, 0x4B"); em("je .Lgk_lt");
    em("cmp eax, 0x4D"); em("je .Lgk_rt");
    em("jmp .Lgk_l");
    lbl(".Lgk_up"); em("mov eax, 0x103"); em("ret");
    lbl(".Lgk_dn"); em("mov eax, 0x104"); em("ret");
    lbl(".Lgk_lt"); em("mov eax, 0x101"); em("ret");
    lbl(".Lgk_rt"); em("mov eax, 0x102"); em("ret");

    /* 扫描码表（set 1，未按下 shift / 按下 shift） */
    {
        static const unsigned char kb_lo[128] = {
            0,27,'1','2','3','4','5','6','7','8','9','0','-','=',8,9,
            'q','w','e','r','t','y','u','i','o','p','[',']',13,0,
            'a','s','d','f','g','h','j','k','l',';',39,'`',0,92,
            'z','x','c','v','b','n','m',',','.','/',0,0,0,' ',0
        };
        static const unsigned char kb_hi[128] = {
            0,27,'!','@','#','$','%','^','&','*','(',')','_','+',8,9,
            'Q','W','E','R','T','Y','U','I','O','P','{','}',13,0,
            'A','S','D','F','G','H','J','K','L',':','"','~',0,'|',
            'Z','X','C','V','B','N','M','<','>','?',0,0,0,' ',0
        };
        fprintf(out, "\n\t.section .data\n_rt_shift:\n\t.byte 0\n");
        fprintf(out, "_kb_map:\n");
        for (int i = 0; i < 128; i++) fprintf(out, "\t.byte %d\n", kb_lo[i]);
        if (0) for (int i = 0; i < 128; i++) (void)kb_hi[i];
        fprintf(out, "_kb_map_sh:\n");
        for (int i = 0; i < 128; i++) fprintf(out, "\t.byte %d\n", kb_hi[i]);
        fprintf(out, "\t.section .text\n");
    }

    fprintf(out, "\n_rt_oob:\n");            /* 越界：打印并停机 */
    em("mov esi, offset .Loob_msg");
    lbl(".Loob_l");
    em("mov al, [esi]");
    em("test al, al");
    em("jz .Loob_h");
    em("push eax"); em("call _rt_putc"); em("add esp, 4");
    em("inc esi"); em("jmp .Loob_l");
    lbl(".Loob_h");
    em("cli"); em("hlt"); em("jmp .Loob_h");

    fprintf(out, "\n_rt_getc:\n");          /* 阻塞读一个字节；无数据则等待 */
    lbl(".Lgc_w");
    em("mov dx, 0x3FD");
    em("in al, dx");
    em("test al, 0x01");
    em("jz .Lgc_w");
    em("mov dx, 0x3F8");
    em("in al, dx");
    em("movzx eax, al");
    em("ret");

    fprintf(out, "\n_rt_puts:\n");
    em("push ebx"); em("mov ebx, [esp+8]"); lbl(".Lps_l");
    em("mov al, [ebx]"); em("test al, al"); em("jz .Lps_d");
    em("push eax"); em("call _rt_putc"); em("add esp, 4");
    em("inc ebx"); em("jmp .Lps_l");
    lbl(".Lps_d"); em("pop ebx"); em("ret");

    fprintf(out, "\n_rt_puti:\n");
    em("push ebx"); em("push esi");
    em("mov eax, [esp+12]");
    em("xor ecx, ecx"); em("mov ebx, 10");
    em("test eax, eax"); em("jns .Lpi_d");
    em("neg eax"); em("push eax"); em("mov eax, 45"); em("push eax");
    em("call _rt_putc"); em("add esp, 4"); em("pop eax");
    lbl(".Lpi_d");
    em("xor edx, edx"); em("div ebx"); em("add dl, 48"); em("push edx"); em("inc ecx");
    em("test eax, eax"); em("jnz .Lpi_d");
    lbl(".Lpi_o");
    em("pop eax"); em("push eax"); em("push eax");
    em("call _rt_putc"); em("add esp, 4"); em("pop eax");
    em("dec ecx"); em("jnz .Lpi_o");
    em("pop esi"); em("pop ebx"); em("ret");

    fprintf(out, "\n.Loob_msg:\n\t.asciz \"\\n[越界] 数组下标超出范围，程序已停止\\n\"\n");

    fprintf(out, "\n\t.section .bss\n\t.align 16\n_kernel_stack:\n\t.space 16384\n"
                 "_kernel_stack_top:\n");
}

int main(int argc, char **argv) {
    const char *in = NULL, *outp = "out.s";
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-o") && i + 1 < argc) outp = argv[++i];
        else if (!strcmp(argv[i], "-nx")) no_mb = 1;   /* 不生成 Multiboot 头 */
        else if (!strcmp(argv[i], "-c")) mod_mode = 1; /* 只出模块 */
        else if (!strcmp(argv[i], "-m")) { main_mode = 1; mod_mode = 1; } /* 主模块 */
        else if (!strcmp(argv[i], "-r")) rt_mode = 1;  /* 只出运行时 */
        else if (argv[i][0] != '-') in = argv[i];
    }
    if (!in) die("用法: xyc 输入.xy -o 输出.s");

    FILE *f = fopen(in, "r");
    if (!f) die("打不开源文件：%s", in);
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    char *src = xmalloc(sz + 1);
    if (fread(src, 1, sz, f) != (size_t)sz) die("读源文件失败");
    src[sz] = 0; fclose(f);

    lex(src);
    out = fopen(outp, "w");
    if (!out) die("打不开输出文件：%s", outp);

    emit_header();

    if (!rt_mode) {
        tpos = 0; skip_nl();
        while (cur()->k != TK_EOF) {
            if (is_kw("qj") || is_kw("jg")) { stmt(); skip_nl(); continue; }
            parse_fn(); skip_nl();
        }
        if (!nfunc) die("源文件里没有任何函数");
        emit_globals_bss();
        emit_strings();
    }
    if (!mod_mode) emit_runtime();   /* -c/-m 都不出运行时 */
    fclose(out);
    printf("xyc: 新语 stage0 v0.4 -> %s（%d 字符串 / %d 全局 / %d 函数）",
           outp, nstr, nglobals, nfunc);
    if (mod_mode && !main_mode) printf("  [模块]");
    if (main_mode) printf("  [主模块]");
    if (rt_mode)  printf("  [仅运行时]");
    printf("\n");
    printf("     危险统计：wx 危险块 %d 个，原始指针操作 %d 处\n", wx_blocks, raw_ops);
    return 0;
}
