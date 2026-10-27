/* ============================================================================
 *  lyc —— 六爻(LiuYao) 编译器  stage0  v0.2.0
 *  规范版本: 六爻指令集 SPEC_v1.0 (64指令)
 *  输出目标: x86-64 模块 .s (配合 宿主64.s + 小链接.py 生成 Linux ELF)
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  规则 R1：编译器用 C 写，由 gcc/clang 直接构建。
 *  输出：i386 汇编（GNU as，Intel 语法）→ Multiboot1 内核 ELF
 *
 *  构建:  TMPDIR=/tmp cc -O2 -o lyc lyc.c
 *  用法:  ./lyc 输入.ly -o 输出.s
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
#include <ctype.h>

static void die(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    fprintf(stderr, "lyc: "); vfprintf(stderr, fmt, ap); fprintf(stderr, "\n");
    va_end(ap); exit(1);
}
static void *xmalloc(size_t n) { void *p = malloc(n); if (!p) die("内存不足"); return p; }
static void *xrealloc(void *p, size_t n) { void *q = realloc(p, n); if (!q) die("内存不足"); return q; }

/* ================================================================ 词法 */

enum { TK_EOF, TK_NL, TK_NUM, TK_STR, TK_ID, TK_KW, TK_TY, TK_P };

typedef struct { int k; long v; char *s; int line; } Tok;

static Tok *toks; static int ntoks, tpos, srcline;

static const char *KEYWORDS[] = { "tt","th","tz","tl","tf","ts","tr","td",
                                  "zt","zz","zh","zl","zf","zs","zr","zd",
                                  "ht","hz","hh","hl","hf","hs","hr","hd",
                                  "lt","lz","lh","ll","lf","ls","lr","ld",
                                  "ft","fz","fh","fl","ff","fs","fr","fd",
                                  "st","sz","sh","sl","sf","ss","sr","sd",
                                  "rt","rz","rh","rl","rf","rs","rr","rd",
                                  "dt","dz","dh","dl","df","ds","dr","dd",
                                  "qj","wx","true","false", NULL };
static const char *OPKW[]     = { "hs","hr","hd","ht","hz","hh","hl","hf","dh","dl", NULL };
/* ★ 五行 = 5×5 = 25 个类型名（大写两字母，和六爻的小写正好分开）
     单字：金J 木M 水S 火H 土T           —— 五行本身
     双字：JJ JM JS JH JT MJ … TT        —— 5×5 相配，一共 25 格
     尺寸由【第一个字】定：金=4（数值） 木=8（指针） 水=1（字节） 火=4（结构） 土=4（空）
     老名字 u8 u16 … z 保留为别名 */
/* ★ 类型名只认【首字母缩写】—— 中文只是文档里给人看的，编译器不认
     五行单字：J 金  M 木  S 水  H 火  T 土
     五行配对：JJ JM JS JH JT / MJ … / TT   （5×5 = 25）
     尺寸看第一个字：J=4（数值） M=8（指针） S=1（字节） H=4（结构） T=4（空）
     老名字 u8 u16 … z 保留为别名 */
static const char *TYPES[]    = { "u8","u16","u32","u64","i8","i16","i32","i64","z",
                                  "J","M","S","H","T", "JJ","JM","JS","JH","JT","MJ","MM","MS","MH","MT","SJ","SM","SS","SH","ST","HJ","HM","HS","HH","HT","TJ","TM","TS","TH","TT", NULL };

static int in_list(const char **l, const char *w) {
    for (int i = 0; l[i]; i++) if (!strcmp(l[i], w)) return 1;
    return 0;
}
static int is_idc(int c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || (unsigned char)c >= 0x80;
}

static char *还原数字标点(const char *src) {
    int len = (int)strlen(src);
    char *out = malloc(len * 2 + 16);
    int o = 0;
    const char *p = src;
    int 在串里 = 0;
    int 末是标识符 = 0;  /* 输出的最后一个字符是否是标识符字符（字母/数字/下划线/中文） */
    while (*p) {
        /* 00 注释：跳过到行尾 */
        if (p[0] == '0' && p[1] == '0' && !末是标识符 && !在串里) {
            while (*p && *p != '\n') p++;
            末是标识符 = 0;
            continue;
        }
        /* 01-09 标点编码：04/07只在串里识别；其他串外且非标识符后识别 */
        int code = (p[0] == '0' && p[1] >= '1' && p[1] <= '9') ? (p[1] - '0') : 0;
        int 允许 = 0;
        if (code == 4 && 在串里) 允许 = 1;
        else if (code == 7 && 在串里) 允许 = 1;
        else if (code != 4 && code != 7 && !末是标识符) 允许 = 1;
        if (code && 允许) {
            p += 2;
            if (code != 3 && code != 7 && *p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') {
                die("0%d编码后必须跟空格", code);
            }
            if (code == 3) {
                out[o++] = '"';                        /* 03 总是输出双引号 */
                if (!在串里) { 在串里 = 1; }           /* 不在串里 → 进入串模式 */
                末是标识符 = 0;
                continue;
            }
            if (code == 4) {
                if (!在串里) { die("语法错误：04 出现在字符串外，第 %d 行", srcline); }
                out[o++] = '\'';                        /* 04 输出单引号 */
                在串里 = 0;                             /* 退出串模式 */
                末是标识符 = 0;
                continue;
            }
            switch (code) {
                case 1: out[o++] = '('; break;
                case 2: out[o++] = ')'; break;
                case 5: out[o++] = ';'; break;
                case 6: out[o++] = '/'; break;
                case 7: out[o++] = '\\'; break;
                case 8: out[o++] = '{'; break;
                case 9: out[o++] = '}'; break;
            }
            末是标识符 = 0;
            continue;
        }
        /* 十六进制数 0x 后面的数字不还原 */
        if (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) {
            out[o++] = *p++;
            out[o++] = *p++;
            while ((*p >= '0' && *p <= '9') || (*p >= 'a' && *p <= 'f') || (*p >= 'A' && *p <= 'F'))
                out[o++] = *p++;
            末是标识符 = 0;
            continue;
        }
        out[o++] = *p++;
        {
            char ch = out[o-1];
            末是标识符 = ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                         (ch >= '0' && ch <= '9') || ch == '_' || (unsigned char)ch >= 128);
        }
    }
    out[o] = 0;
    return out;
}static void lex(const char *src) {
    int cap = 512; toks = xmalloc(cap * sizeof(Tok)); ntoks = 0; srcline = 1;
    const char *p = src;
    while (*p) {
        if (*p == ' ' || *p == '\t' || *p == '\r') { p++; continue; }
        if (*p == '\n') {
            if (ntoks + 2 >= cap) { cap *= 2; toks = xrealloc(toks, cap * sizeof(Tok)); }
            toks[ntoks++] = (Tok){TK_NL, 0, "\n", srcline}; srcline++; p++; continue;
        }
        if (*p == '0' && *(p+1) == '0') { while (*p && *p != '\n') p++; continue; }   /* 00 是注释（纯血六爻） */
        if (*p == '@') { while (*p && *p != '\n') p++; continue; }   /* @ 是注释（旧兼容） */
        if (*p == '#') { while (*p && *p != '\n') p++; continue; }   /* # 兼容保留 */
        if (ntoks + 2 >= cap) { cap *= 2; toks = xrealloc(toks, cap * sizeof(Tok)); }

        if (*p == '"') {
            p++; char buf[8192]; int n = 0;
            while (*p && *p != '\'') {
                if (n >= (int)sizeof(buf) - 8)
                    die("第 %d 行：字符串字面量太长（上限 %d 字节）", srcline, (int)sizeof(buf) - 8);
                buf[n++] = *p++;
            }
            if (*p != '\'') die("第 %d 行：字符串没有闭合", srcline);
            p++; buf[n] = 0;
            char *s = xmalloc(n + 1); memcpy(s, buf, n + 1);
            toks[ntoks++] = (Tok){TK_STR, 0, s, srcline};
            continue;
        }
        if (*p >= '0' && *p <= '9') {
            const char *start = p;
            char *end; long v = strtol(p, &end, 0);
            if (*end == '.') {
                float f = strtof(start, NULL);
                union { float f; unsigned u; } cvt; cvt.f = f;
                toks[ntoks++] = (Tok){TK_NUM, (long)cvt.u, NULL, srcline};
                p = end + 1;
                while (*p >= '0' && *p <= '9') p++;
                if (*p == 'e' || *p == 'E') { p++; if (*p == '+' || *p == '-') p++; while (*p >= '0' && *p <= '9') p++; }
                continue;
            }
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
        if (*p == '/') {   /* ★ 数字标点 06 = 斜杠本身：换行 / 分隔符 */
            if (ntoks + 2 >= cap) { cap *= 2; toks = xrealloc(toks, cap * sizeof(Tok)); }
            toks[ntoks++] = (Tok){TK_NL, 0, "\n", srcline};
            p++; continue;
        }
        if (*p == '\\') {  /* ★ 数字标点 07 = 反斜杠本身：代码块开始（等于 { ）*/
            if (ntoks + 2 >= cap) { cap *= 2; toks = xrealloc(toks, cap * sizeof(Tok)); }
            toks[ntoks++] = (Tok){TK_P, 0, "{", srcline};
            p++; continue;
        }
        if (*p == ';') {   /* ★ 六爻「05 = ; 语句结束」：分号当换行用 */
            if (ntoks + 2 >= cap) { cap *= 2; toks = xrealloc(toks, cap * sizeof(Tok)); }
            toks[ntoks++] = (Tok){TK_NL, 0, "\n", srcline};
            p++; continue;
        }
        if (strchr("(){}[]:,=+-*%<>!@^&|.", *p)) {
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

#include "编码器.c"          /* ★ 出口换到这个：文本模式照旧出 .s，字节模式直出机器码 */

static void em(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    if (bin_mode) {                     /* ★ 直出字节：不经 as */
        char 缓[1024];
        vsnprintf(缓, sizeof 缓, fmt, ap);
        va_end(ap);
        记指令(缓);          /* 只登记，排布和编码留到最后统一做（跳转要迭代松弛）*/
        return;
    }
    fprintf(out, "\t"); vfprintf(out, fmt, ap); fprintf(out, "\n");
    va_end(ap);
}
static void lbl(const char *s) {
    if (bin_mode) { 记标号(s); return; }
    fprintf(out, "%s:\n", s);
}
static char *newlab(const char *pre, char *buf) { sprintf(buf, ".L%s%d", pre, ++labeln); return buf; }

static char *mangle(const char *name) {
    static char buf[1024]; int n = 0;
    for (const unsigned char *p = (const unsigned char *)name; *p; p++) {
        if ((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '_')
            buf[n++] = *p;
        else n += sprintf(buf + n, "_%02x", *p);
        if (n > 900)
            die("名字太长：%s\n        （编译器给名字留 900 字节；一个汉字拼音化后占 9 字节，约 100 个汉字）", name);
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
    long init_val;         /* 全局变量初始值（仅第一个元素） */
    char glabel[1024];
} Var;

static Var vars[1024];   static int nvars, framesz;    /* 局部，逐函数重置 */
static Var globals[256]; static int nglobals;          /* 全局，全程有效 */
static int in_function;
static int scope_depth;
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
    vars[nvars].name = (char *)n; vars[nvars].off = 0; vars[nvars].size = 8;
    vars[nvars].count = 1; vars[nvars].mut = 1; vars[nvars].declared = 0;
    vars[nvars].is_ptr = 0; vars[nvars].struct_idx = -1;
    vars[nvars].glabel[0] = 0;
    return nvars++;
}
static int elem_size_of_type(const char *t) {
    if (!t) return 8;
    if (!strcmp(t, "u8") || !strcmp(t, "i8") || !strcmp(t, "z")) return 1;
    if (!strcmp(t, "u16") || !strcmp(t, "i16")) return 2;
    if (!strcmp(t, "u32") || !strcmp(t, "i32")) return 4;
    if (!strcmp(t, "u64") || !strcmp(t, "i64")) return 8;
    {   /* ★ 五行：尺寸看第一个字（J 金=4  M 木=8  S 水=1  H 火=4  T 土=4） */
        if (t[0] == 'J' || t[0] == 'M' || t[0] == 'S' || t[0] == 'H' || t[0] == 'T') {
            if (t[0] == 'M') return 8;
            if (t[0] == 'S') return 1;
            return 4;
        }
    }
    return 8;
}

/* ---------------- 结构体表 ---------------- */
#define MAX_FIELDS 32
typedef struct { char *name; int size; int off; } Field;
typedef struct { char *name; Field f[MAX_FIELDS]; int nf; int size; } StructDef;
static StructDef structs[64]; static int nstructs;

/* ── 函数签名记录（只给「符号表导出」用，不影响代码生成）── */
typedef struct {
    char 名[256];
    int  参个数;
    char 参名[16][128];
    int  参尺寸[16];
    int  参指针[16];
    int  返回尺寸;
} 函数记录;
static 函数记录 函记[256]; static int 函记数;
static int 符号模式 = 0;

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
static void binop_emit(const char *op);

static int prec_of(const char *op) {
    if (!strcmp(op, "||")) return 1;
    if (!strcmp(op, "&&")) return 2;
    if (!strcmp(op, "hr")) return 3;
    if (!strcmp(op, "hd")) return 4;
    if (!strcmp(op, "hs")) return 5;
    if (!strcmp(op, "ht") || !strcmp(op, "hz")) return 9;
    if (!strcmp(op, "hh") || !strcmp(op, "hl") || !strcmp(op, "hf")) return 10;
    if (!strcmp(op, "==") || !strcmp(op, "!=")) return 6;
    if (!strcmp(op, "<") || !strcmp(op, "<=") || !strcmp(op, ">") || !strcmp(op, ">=")) return 7;
    if (!strcmp(op, "<<") || !strcmp(op, ">>") || !strcmp(op, "dh") || !strcmp(op, "dl")) return 8;
    if (!strcmp(op, "+") || !strcmp(op, "-")) return 9;
    if (!strcmp(op, "*") || !strcmp(op, "/") || !strcmp(op, "%")) return 10;
    return 0;
}

/* 取左值地址 → eax；返回 1=全局 0=局部 -1=不存在 */
static int lvalue_addr(const char *name, int *elem) {
    int i = var_find_local(name);
    if (i >= 0) { *elem = vars[i].size; em("lea rax, [rbp%+d]", vars[i].off); return 0; }
    int g = global_find(name);
    if (g >= 0) { *elem = globals[g].size; em("mov rax, offset %s", globals[g].glabel); return 1; }
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
        em("lea rax, [rbp%+d]", vars[li].off);
    } else {
        gi = global_find(name);
        if (gi < 0) return -1;
        elem = globals[gi].size; count = globals[gi].count;
        sidx = globals[gi].struct_idx;
        em("mov rax, offset %s", globals[gi].glabel);
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
            em("cmp rax, %d", count);
            em("jb %s", newlab("bok", lok));
            em("call _rt_oob");
            lbl(lok);
        }
        if (elem > 1) em("imul rax, %d", elem);
        em("push rax");
        if (li >= 0) {
            em("lea rax, [rbp%+d]", vars[li].off);
            /* ★ 标量/指针参数：栈槽里存的是指针值，取出来当数组基址 */
            if (count == 1) em("mov rax, [rax]");
        } else         em("mov rax, offset %s", globals[gi].glabel);
        em("mov rcx, rax");
        em("pop rax");
        em("add rax, rcx");
    }

    if (is_p(".")) {                      /* 字段 */
        adv();
        if (had) *had = 1;
        if (cur()->k != TK_ID) die("第 %d 行：'.' 后面必须是字段名", ln);
        if (sidx < 0) die("第 %d 行：%s 不是结构体类型，不能取字段", ln, name);
        int f = struct_field_idx(sidx, cur()->s);
        if (f < 0) die("第 %d 行：结构体 %s 没有字段 %s", ln, structs[sidx].name, cur()->s);
        if (structs[sidx].f[f].off) em("add rax, %d", structs[sidx].f[f].off);
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

    /* 指令作为表达式：rr/fr/zf/sh/sr/fh/zd/zr/zl/ft/fz/sz/sd/fl/sl/rf/rd/rh/rl/rs */
    if (cur()->k == TK_KW && (
        is_kw("rr") || is_kw("fr") || is_kw("zf") || is_kw("sh") ||
        is_kw("sr") || is_kw("fh") || is_kw("zd") || is_kw("zr") ||
        is_kw("zl") || is_kw("ft") || is_kw("fz") || is_kw("sz") ||
        is_kw("sd") || is_kw("fl") || is_kw("sl") || is_kw("rf") ||
        is_kw("rd") || is_kw("rh") || is_kw("rl") || is_kw("rs") ||
        is_kw("df") || is_kw("ds") || is_kw("ff") || is_kw("fs") || is_kw("ss") ||
        is_kw("sf") || is_kw("sz") || is_kw("sh") || is_kw("sl") || is_kw("sr")
    )) { stmt(); return; }

    /* zt 函数调用前缀：跳过zt，后面跟函数名 */
    if (is_kw("zt")) { adv(); t = cur(); }

    if (t->k == TK_NUM) { em("mov rax, %ld", t->v); adv(); return; }

    /* dz 空值/null → 就是0 */
    if (is_kw("dz")) { em("mov rax, 0"); adv(); return; }

    /* 布尔字面量 true=1 false=0 */
    if (is_kw("true")) { em("mov rax, 1"); adv(); return; }
    if (is_kw("false")) { em("mov rax, 0"); adv(); return; }

    if (t->k == TK_STR) {
        if (nstr >= 1024) die("字符串太多");
        strtab[nstr++] = t->s; adv();
        em("mov rax, offset .Lstr%d", nstr - 1);
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
                em("push rax");
                if (a + 1 < GFX_BUILTINS[bi].nargs) expect_p(",");
            }
            expect_p(")");
            em("call %s", GFX_BUILTINS[bi].sym);
            if (GFX_BUILTINS[bi].nargs)
                em("add rsp, %d", GFX_BUILTINS[bi].nargs * 8);
            return;
        }

        /* 内建：出(c) —— 输出一个字节到串口 */
        if (!strcmp(name, "出") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            expr(0); expect_p(")");
            em("push rax"); em("call _rt_putc"); em("add rsp, 8");
            return;
        }

        /* 内建：清() —— 清屏 */
        if (!strcmp(name, "清") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv(); expect_p(")"); em("call _rt_cls"); em("mov rax, 0"); return;
        }
        /* 内建：置光标(行, 列) */
        if (!strcmp(name, "置光标") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            expr(0); em("push rax"); expect_p(","); expr(0); em("push rax");
            em("call _rt_goto"); em("add rsp, 8"); em("mov rax, 0");
            expect_p(")"); return;
        }

        /* 内建：印串(s) —— 输出一个以 0 结尾的字符串（指针） */
        if (!strcmp(name, "印串") && peek(1)->k == TK_P && !strcmp(peek(1)->s, "(")) {
            adv(); adv();
            expr(0);
            em("push rax"); em("call _rt_puts"); em("add rsp, 8");
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
            int elem = 8;
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
                    expr(0); em("push rax"); n++;
                    if (is_p(",")) { adv(); continue; }
                    break;
                }
            }
            expect_p(")");
            em("call fn_%s", mangle(name));
            if (n) em("add rsp, %d", 8 * n);
            return;
        }

        /* 变量（可能带下标与字段） */
        adv();
        int width = 8, had = 0;
        int isg = lvalue_full(name, &width, &had, t->line);
        if (isg < 0) die("第 %d 行：名字不存在：%s", t->line, name);
        if (had == 0 && lvalue_count(name) > 1) return;     /* 纯数组名 → 地址 */
        if (width == 1) em("movzx rax, byte ptr [rax]");
        else if (width == 2) em("movzx rax, word ptr [rax]");
        else if (width == 8) em("mov rax, [rax]");
        else em("mov rax, [rax]");            /* ★ 全64位 */
        return;
    }

    if (is_p("(")) { adv(); expr(0); expect_p(")"); return; }

    die("第 %d 行：表达式里出现意外的 '%s'", t->line, t->s ? t->s : "行尾");
}

static void unary(void) {
    if (is_p("-")) { adv(); unary(); em("neg rax"); return; }
    if (is_p("!")) { adv(); unary(); em("test rax, rax"); em("sete al"); em("movzx rax, al"); return; }
    if (is_kw("dr")) { adv(); unary(); em("not rax"); return; }
    if (is_kw("fd")) { adv(); unary(); em("test rax, rax"); em("sete al"); em("movzx rax, al"); return; }
    if (is_p("^")) {                                                             /* 解引用（字节） */
        if (!in_wx) die("第 %d 行：解引用原始指针是危险操作，必须写在 wx { } 危险块内", cur()->line);
        adv(); raw_ops++; unary(); em("movzx rax, byte ptr [rax]"); return;
    }
    /* ★ 前缀运算：ht a b = a + b（对齐自举编译器 zzp） */
    if (cur()->k == TK_KW && in_list(OPKW, cur()->s)) {
        char obuf[4]; strncpy(obuf, cur()->s, 3); obuf[3] = 0;
        adv();
        expr(0);
        em("push rax");
        expr(0);
        binop_emit(obuf);
        return;
    }
    primary();
}

static void binop_emit(const char *op) {
    em("mov rcx, rax"); em("pop rax");
    if (!strcmp(op, "+") || !strcmp(op, "ht"))  { em("add rax, rcx"); return; }
    if (!strcmp(op, "-") || !strcmp(op, "hz"))  { em("sub rax, rcx"); return; }
    if (!strcmp(op, "*") || !strcmp(op, "hh"))  { em("imul rax, rcx"); return; }
    if (!strcmp(op, "/") || !strcmp(op, "hl"))  { em("xor rdx, rdx"); em("div rcx"); return; }
    if (!strcmp(op, "%") || !strcmp(op, "hf"))  { em("xor rdx, rdx"); em("div rcx"); em("mov rax, rdx"); return; }
    if (!strcmp(op, "hs")) { em("and rax, rcx"); return; }
    if (!strcmp(op, "hr")) { em("or rax, rcx"); return; }
    if (!strcmp(op, "hd")) { em("xor rax, rcx"); return; }
    if (!strcmp(op, "<<") || !strcmp(op, "dh")) { em("shl rax, cl"); return; }
    if (!strcmp(op, ">>") || !strcmp(op, "dl")) { em("shr rax, cl"); return; }
    if (!strcmp(op, "==") || !strcmp(op, "!=") || !strcmp(op, "<") ||
        !strcmp(op, "<=") || !strcmp(op, ">") || !strcmp(op, ">=")) {
        em("cmp rax, rcx");
        const char *cc = !strcmp(op, "==") ? "e" : !strcmp(op, "!=") ? "ne" :
                         !strcmp(op, "<") ? "b" : !strcmp(op, "<=") ? "be" :
                         !strcmp(op, ">") ? "a" : "ae";
        em("set%s al", cc); em("movzx rax, al"); return;
    }
    if (!strcmp(op, "&&")) {
        em("test rax, rax"); em("setne al");
        em("test rcx, rcx"); em("setne cl");
        em("and al, cl"); em("movzx rax, al"); return;
    }
    if (!strcmp(op, "||")) { em("or rax, rcx"); em("setne al"); em("movzx rax, al"); return; }
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
        em("push rax");
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
        em("add rsp, 8");
    } else {
        expr(0); em("push rax"); em("call _rt_puti"); em("add rsp, 8");
    }
    expect_p(")");
}

/* 类型：'*' 或 类型名；指针变量本身占 4 字节，解引用按字节 */
static void parse_type_only(int *size) { *size = 8; }
static void parse_type_only_ex(int *size, int *isptr, int *struct_idx) {
    *size = 8; *isptr = 0; *struct_idx = -1;
    if (is_p("*")) {
        adv(); *isptr = 1; *size = 8;              /* ★ 64 位：指针 8 字节 */
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
    *size = 8; *count = 1; if (sidx) *sidx = -1;
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
    /* ---- rd 内存拷贝 ---- */
    if (is_kw("rd")) {
        adv(); expr(0); em("push rax"); expect_p(",");
        expr(0); em("push rax"); expect_p(",");
        expr(0); em("mov rcx, rax");
        em("pop rsi"); em("pop rdi");
        char l1[32], l2[32]; newlab("rdl", l1); newlab("rde", l2);
        lbl(l1); em("test rcx, rcx"); em("jz %s", l2);
        em("mov al, byte ptr [rsi]"); em("mov byte ptr [rdi], al");
        em("add rsi, 1"); em("add rdi, 1"); em("sub rcx, 1"); em("jmp %s", l1);
        lbl(l2); return;
    }
    /* ---- 结构体定义（仅顶层） ---- */
    if (is_kw("tl")) {
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
            int sz = 8, ip = 0, nsi = -1;
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
    if (is_kw("qj") || (is_kw("tz") && !in_function) || (is_kw("ts") && !in_function) || (is_kw("tf") && !in_function)) {
        adv();
        int ln = cur()->line;
        if (in_function) die("第 %d 行：全局声明只能出现在顶层", ln);
        if (cur()->k != TK_ID) die("第 %d 行：qj 后面必须是名字", ln);
        char *name = cur()->s; adv();
        int size = 8, count = 1, sidx = -1;
        parse_decl_tail(name, &size, &count, &sidx);
        int g = global_find(name);
        if (g < 0) { g = nglobals++; globals[g].name = name; }
        /* ★ 全局数组的元素跨度也至少 4 字节：代码生成永远是 32 位存取，
           u8 数组若按 1 字节跨越，写第 i 个元素会覆盖后面三个 */
        globals[g].size = (size < 4 ? 4 : size); globals[g].count = count;
        globals[g].struct_idx = sidx;
        globals[g].mut = 1; globals[g].declared = 1;
        snprintf(globals[g].glabel, sizeof globals[g].glabel, "g_%s", mangle(name));
        globals[g].init_val = 0;  /* 默认全 0 */
        /* ★ 全局初始化：零初始化放 .bss，非零初始化放 .data */
        if (is_p("=")) {
            adv();
            if (cur()->k != TK_NUM) die("第 %d 行：全局初始化只支持数字字面量", cur()->line);
            globals[g].init_val = cur()->v;
            adv();
            if (is_p(";")) adv();
        }
        return;
    }

    /* ---- 局部绑定 ---- */
    if (is_kw("th") || is_kw("td") || is_kw("tz")) {
        int mut = is_kw("tz"); adv();
        if (cur()->k != TK_ID) die("第 %d 行：声明必须跟一个名字", cur()->line);
        char *name = cur()->s; int ln = cur()->line; adv();
        int size = 8, count = 1, sidx = -1;
        parse_decl_tail(name, &size, &count, &sidx);
        int exist = var_find_local(name);
        /* ★ 放开重复声明：第二次 tz 同名，就复用原来的槽（重新赋值）
           —— 两个循环里各写一个 tz j 是很自然的写法 */
        /* ★ 作者定的简化写法： tz 名 值        （不带类型、不带冒号）
             老写法照旧：      tz 名: 类型 = 值  */
        int 简化 = 0;
        if (!is_p("=") && cur()->k != TK_NL && cur()->k != TK_EOF && !is_p("}")) 简化 = 1;
        if (exist >= 0 && vars[exist].declared) {
            vars[exist].size = size; vars[exist].count = count;
            vars[exist].mut = mut;   vars[exist].struct_idx = sidx;
            if (is_p("=")) {
                adv();
                if (count > 1) die("第 %d 行：数组不能就地初始化", ln);
                expr(0);
                em("mov [rbp%+d], rax", vars[exist].off);
            } else if (简化) {
                expr(0);
                em("mov [rbp%+d], rax", vars[exist].off);
            }
            return;
        }
        int i = var_new(name);
        if (vars[i].off == 0) {                 /* 没有被 prescan 覆盖（极少见）：兜底 */
            /* ★ 64 位：每个槽固定 8 字节（push/pop 就是 8 字节）*/
            framesz += 8 * count;
            vars[i].off = -framesz;
        }
        vars[i].size = size; vars[i].count = count; vars[i].mut = mut; vars[i].declared = 1;
        vars[i].struct_idx = sidx;
        if (is_p("=")) {
            adv();
            if (count > 1) die("第 %d 行：数组不能就地初始化", ln);
            expr(0);
            em("mov [rbp%+d], rax", vars[i].off);
        } else if (简化) {                       /* ★ tz 名 值 的简化写法 */
            expr(0);
            em("mov [rbp%+d], rax", vars[i].off);
        } else if (count == 1) {
            em("mov qword ptr [rbp%+d], 0", vars[i].off);
        }
        return;
    }

    /* ---- 相等跳转 lz / 不等跳转 lh（当"如果"用，带块）---- */
    if (is_kw("lz") || is_kw("lh")) {
        int 不等 = is_kw("lh");
        adv();
        expr(0); em("push rax");          /* 左边 */
        /* ★ 单表达式形式：lz A {块} = 若 A==0 执行块（对齐自举编译器） */
        if (is_p("{")) em("mov rcx, 0");
        else { expr(0); em("mov rcx, rax"); }      /* 右边 */
        em("pop rax");
        em("cmp rax, rcx");
        char le2[32];
        em(不等 ? "je %s" : "jne %s", newlab("else", le2));   /* 不满足就跳过块 */
        expect_p("{"); block(); expect_p("}");
        lbl(le2);
        return;
    }

    /* ---- 条件 ---- */
    if (is_kw("lr")) {
        adv(); expr(0);
        char le[32], lx[32];
        em("test rax, rax");
        em("jz %s", newlab("else", le));
        expect_p("{"); block(); expect_p("}");
        if (is_kw("ld")) {
            em("jmp %s", newlab("endif", lx));
            lbl(le);
            adv(); expect_p("{"); block(); expect_p("}");
            lbl(lx);
        } else lbl(le);
        return;
    }

    /* ---- 无限循环 ---- */
    /* ---- 循环 nn（震震）：带条件=条件循环，不带条件=无限循环 ---- */
    if (is_kw("ll")) {
        adv();
        char lt[32], lx[32];
        /* 标签前缀跟着「有没有条件」走 —— 这样和旧版编译器的输出逐字节一致 */
        if (is_p("{")) { newlab("ltop", lt); newlab("lend", lx); }      /* 无限循环 */
        else           { newlab("wtop", lt); newlab("wend", lx); }      /* 条件循环 */
        strcpy(loop_top[nloops], lt); strcpy(loop_end[nloops], lx); nloops++;
        lbl(lt);
        if (!is_p("{")) {                 /* 写了条件，就是条件循环 */
            expr(0);
            em("test rax, rax"); em("jz %s", lx);
        }
        expect_p("{"); block(); expect_p("}");
        nloops--;
        em("jmp %s", lt); lbl(lx);
        return;
    }

    if (is_kw("ls")) { adv(); if (!nloops) die("第 %d 行：tc 不在循环里", cur()->line);
                       em("jmp %s", loop_end[nloops - 1]); return; }
    if (is_kw("lf")) { adv(); if (!nloops) die("第 %d 行：jx 不在循环里", cur()->line);
                       em("jmp %s", loop_top[nloops - 1]); return; }

    if (is_kw("zz")) {
        adv();
        /* ★ 对齐自举 lzr：zz 表达式 = 求值返回；裸 zz（后接换行/}）= 保持 rax 返回 */
        if (cur()->k != TK_NL && !is_p("}")) expr(0);
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

    /* ---- 六爻 输出类：st dt 值（写整数） / st dd 串（写字符串）---- */
    if (is_kw("st")) {
        adv();
        if (is_kw("dt")) {                       /* 水天 + 地天 = 写屏幕·整数 */
            adv(); expr(0);
            em("push rax"); em("call _rt_puti"); em("add rsp, 8");
            return;
        }
        if (is_kw("dd")) {                       /* 水天 + 坤坤 = 写屏幕·字符串 */
            adv();
            if (cur()->k == TK_STR) {
                if (nstr >= 1024) die("字符串太多");
                strtab[nstr++] = cur()->s; adv();
                em("push offset .Lstr%d", nstr - 1);
            } else { expr(0); em("push rax"); }
            em("call _rt_puts"); em("add rsp, 8");
            return;
        }
        die("第 %d 行：st 后面只能是 dt（写整数）或 dd（写字符串）", cur()->line);
    }

    /* ---- zh 标签定义 ---- */
    if (is_kw("zh")) {
        adv();
        if (cur()->k != TK_ID) die("第 %d 行：zh 后面必须是标签名", cur()->line);
        lbl(cur()->s);
        adv();
        return;
    }

    /* ---- lt 无条件跳转 ---- */
    if (is_kw("lt")) {
        adv();
        if (cur()->k != TK_ID) die("第 %d 行：lt 后面必须是标签名", cur()->line);
        em("jmp %s", cur()->s);
        adv();
        return;
    }

    /* ---- zf 取地址 ---- */
    if (is_kw("zf")) {
        adv();
        if (cur()->k != TK_ID) die("第 %d 行：zf 后面必须是变量名", cur()->line);
        char *name = cur()->s; adv();
        int li = var_find_local(name);
        int gi = global_find(name);
        if (li >= 0) em("lea rax, [rbp%+d]", vars[li].off);
        else if (gi >= 0) em("mov rax, offset %s", globals[gi].glabel);
        else die("第 %d 行：zf 取地址：变量不存在：%s", cur()->line, name);
        return;
    }

    /* ---- zs 内联汇编 ---- */
    if (is_kw("zs")) {
        adv();
        if (cur()->k != TK_STR) die("第 %d 行：zs 后面必须是汇编字符串", cur()->line);
        em("%s", cur()->s);
        adv();
        return;
    }

    /* ---- zd 系统调用 ---- */
    if (is_kw("zd")) {
        adv();
        em("mov rax, rdi");  /* 第一个参数=syscall号 */
        em("syscall");
        return;
    }

    /* ---- fd 逻辑非 ---- */
    if (is_kw("fd")) {
        adv();
        expr(0);
        em("test rax, rax"); em("sete al"); em("movzx rax, al");
        return;
    }

    /* ---- fr 获取栈指针（Retrieve SP） ---- */
    if (is_kw("fr")) {
        adv();
        em("mov rax, rsp");
        return;
    }

    /* ---- fh 读内存(指定宽度) ---- */
    if (is_kw("fh")) {
        adv();
        expr(0);
        em("mov rax, [rax]");
        return;
    }

    /* ---- sh 写内存 ---- */
    if (is_kw("sh")) {
        adv();
        expr(0); em("push rax");  /* 地址 */
        expect_p(",");
        expr(0); em("mov rcx, rax"); em("pop rax");
        em("mov [rax], rcx");
        return;
    }

    /* ---- sr 重置栈指针（Reset SP） ---- */
    if (is_kw("sr")) {
        adv();
        expr(0);                   /* rax = 目标栈指针 */
        em("mov rsp, rax");
        return;
    }

    /* ---- rr 申请堆内存(malloc) ---- */
    if (is_kw("rr")) {
        adv();
        expr(0);
        em("mov rdi, rax");
        em("call malloc");
        return;
    }

    /* ---- rs 释放堆内存(free) ---- */
    if (is_kw("rs")) {
        adv();
        expr(0);
        em("mov rdi, rax");
        em("call free");
        return;
    }

    /* ---- rf 内存清零 ---- */
    if (is_kw("rf")) {
        adv(); expr(0); em("push rax"); expect_p(","); expr(0);
        em("mov rcx, rax"); em("pop rdi");
        char l1[32], l2[32]; newlab("rfl", l1); newlab("rfe", l2);
        lbl(l1); em("test rcx, rcx"); em("jz %s", l2);
        em("mov byte ptr [rdi], 0"); em("add rdi, 1"); em("sub rcx, 1"); em("jmp %s", l1);
        lbl(l2); return;
    }


    /* ---- df 数组字面量 ---- */
    if (is_kw("df")) {
        adv(); expect_p("[");
        int cnt = 0;
        while (!is_p("]")) {
            expr(0); em("push rax"); cnt++;
            if (is_p(",")) adv();
        }
        expect_p("]");
        /* 逆序弹出到连续栈空间 */
        em("sub rsp, %d", cnt * 8);
        for (int i = 0; i < cnt; i++) {
            em("pop rax"); em("mov [rsp+%d], rax", i * 8);
        }
        em("mov rax, rsp");
        return;
    }

    /* ---- ds 结构体字面量(简化：按顺序初始化字段) ---- */
    if (is_kw("ds")) {
        adv(); expect_p("{");
        int cnt = 0;
        while (!is_p("}")) {
            if (cur()->k == TK_ID && peek(1)->k == TK_P && !strcmp(peek(1)->s, "=")) {
                adv(); adv(); /* 跳过 .field = */
            }
            expr(0); em("push rax"); cnt++;
            if (is_p(",")) adv();
        }
        expect_p("}");
        em("sub rsp, %d", cnt * 8);
        for (int i = 0; i < cnt; i++) {
            em("pop rax"); em("mov [rsp+%d], rax", i * 8);
        }
        em("mov rax, rsp");
        return;
    }

    /* ---- dh 左移 ---- */
    if (is_kw("dh")) {
        adv();
        expr(0); em("push rax");
        expect_p(",");
        expr(0); em("mov rcx, rax"); em("pop rax");
        em("shl rax, cl");
        return;
    }

    /* ---- dl 右移 ---- */
    if (is_kw("dl")) {
        adv();
        expr(0); em("push rax");
        expect_p(",");
        expr(0); em("mov rcx, rax"); em("pop rax");
        em("shr rax, cl");
        return;
    }

    /* ---- dr 按位取反 ---- */
    if (is_kw("dr")) {
        adv();
        expr(0);
        em("not rax");
        return;
    }

    /* ---- rh 强制类型转换 ---- */
    if (is_kw("rh")) {
        adv();
        /* 跳过类型名（u64/i8 等标识符），再求值表达式 */
        if (cur()->k == TK_ID) adv();
        expr(0);  /* 六爻全 u64，转换即取值 */
        return;
    }

    /* ---- rl 内存重分配（Realloc，brk syscall） ---- */
    if (is_kw("rl")) {
        adv();
        expr(0); em("push rax");        /* 旧指针（brk 语义下忽略，只调堆顶） */
        expect_p(",");
        expr(0);                        /* 新大小 → rax */
        em("mov rdi, rax");             /* rdi = 新堆大小 */
        em("mov rax, 12");              /* brk */
        em("syscall");
        em("pop rsi");                  /* 弹掉旧指针，保持栈平衡 */
        return;
    }

    /* ---- rt 栈上分配空间（Alloc on Stack） ---- */
    if (is_kw("rt")) {
        adv();
        expr(0);                        /* rax = 分配字节数 */
        em("sub rsp, rax");
        return;
    }

    /* ---- rz 栈空间回收（Free on Stack） ---- */
    if (is_kw("rz")) {
        adv();
        expr(0);                        /* rax = 回收字节数 */
        em("add rsp, rax");
        return;
    }

    /* ---- sd 调试/日志输出 ---- */
    if (is_kw("sd")) {
        adv();
        if (cur()->k == TK_STR) {
            if (nstr >= 1024) die("字符串太多");
            strtab[nstr++] = cur()->s; adv();
            em("push offset .Lstr%d", nstr - 1);
            em("call _rt_puts"); em("add rsp, 8");
        } else {
            expr(0); em("push rax"); em("call _rt_puti"); em("add rsp, 8");
        }
        return;
    }

    /* ---- sz 写文件 ---- */
    if (is_kw("sz")) {
        adv();
        expr(0); em("push rax");  /* fd */
        expect_p(",");
        expr(0); em("push rax");  /* buf */
        expect_p(",");
        expr(0); em("mov rdx, rax");  /* count */
        em("pop rsi"); em("pop rdi");
        em("mov rax, 1"); em("syscall");  /* write */
        return;
    }

    /* ---- fz 读文件 ---- */
    if (is_kw("fz")) {
        adv();
        expr(0); em("push rax");  /* fd */
        expect_p(",");
        expr(0); em("push rax");  /* buf */
        expect_p(",");
        expr(0); em("mov rdx, rax");  /* count */
        em("pop rsi"); em("pop rdi");
        em("xor rax, rax"); em("syscall");  /* read */
        return;
    }

    /* ---- ft 读键盘 ---- */
    if (is_kw("ft")) {
        adv();
        em("call _rt_getc");
        return;
    }

    /* ---- fl 读IO端口 ---- */
    if (is_kw("fl")) {
        adv();
        expr(0);
        em("mov rdx, rax"); em("xor rax, rax"); em("in al, dx");
        return;
    }

    /* ---- sl 写IO端口 ---- */
    if (is_kw("sl")) {
        adv();
        expr(0); em("push rax");  /* port */
        expect_p(",");
        expr(0); em("mov rcx, rax"); em("pop rdx");
        em("mov rax, rcx"); em("out dx, al");
        return;
    }

    /* ---- zr 断言 ---- */
    if (is_kw("zr")) {
        adv();
        expr(0);
        em("test rax, rax");
        char lab[32];
        em("jnz %s", newlab("assert_ok", lab));
        em("mov rdi, 1"); em("call _rt_exit");
        lbl(lab);
        return;
    }

    /* ---- zl 函数指针(取函数地址) ---- */
    if (is_kw("zl")) {
        adv();
        if (cur()->k != TK_ID) die("第 %d 行：zl 后面必须是函数名", cur()->line);
        em("mov rax, offset fn_%s", cur()->s);
        adv();
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
        em("push rax");
        expr(0);
        em("mov rcx, rax"); em("pop rax");
        em("mov byte ptr [rax], cl");
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
        /* ★ 下标/字段赋值改的是元素/成员，不修改变量本身，跳过不可变检查 */
        if (is_p("[") || is_p(".")) {
            int width = 8, had = 0;
            (void)lvalue_full(name, &width, &had, ln);
            if (!is_p("=")) die("第 %d 行：这里只能赋值", ln);
            adv();
            em("push rax");
            expr(0);
            em("mov rcx, rax"); em("pop rax");
            if (width == 1) em("mov byte ptr [rax], cl");
            else if (width == 2) em("mov word ptr [rax], cx");
            else if (width == 8) em("mov [rax], rcx");
            else em("mov [rax], ecx");        /* ★ 4 字节槽：只写 32 位 */
            return;
        }

        expect_p("=");
        expr(0);
        if (li_chk >= 0) em("mov [rbp%+d], rax", vars[li_chk].off);   /* 局部槽固定 8 字节 */
        else {                       /* ★ 全局按【声明的大小】存，不然会踩到隔壁那个全局 */
            int 宽 = globals[gi_chk].size;
            em("push rax");
            em("mov rax, offset %s", globals[gi_chk].glabel);
            em("pop rcx");
            if (宽 == 1)      em("mov byte ptr [rax], cl");
            else if (宽 == 2) em("mov word ptr [rax], cx");
            else if (宽 == 8) em("mov [rax], rcx");
            else              em("mov dword ptr [rax], ecx");
        }
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
        else if (t->k == TK_KW && (!strcmp(t->s, "th") || !strcmp(t->s, "tz"))) {
            if (toks[i + 1].k != TK_ID) continue;
            const char *nm = toks[i + 1].s;
            int size = 8, count = 1, j = i + 2;
            if (toks[j].k == TK_P && !strcmp(toks[j].s, "[")) { count = (int)toks[j + 1].v; j += 3; }
            if (toks[j].k == TK_P && !strcmp(toks[j].s, ":")) {
                j++;
                if (toks[j].k == TK_P && !strcmp(toks[j].s, "*")) { size = 8; j += 2; }
                else {
                    if (toks[j].k == TK_ID) { int si = struct_find(toks[j].s); size = (si >= 0) ? structs[si].size : 4; }
                    else size = elem_size_of_type(toks[j].s);
                    j++;
                }
            }
            int idx = var_new(nm);
            vars[idx].size = size; vars[idx].count = count; vars[idx].mut = 1;
            /* ★ 同上：槽至少 4 字节 */
            framesz += 8 * count;
            vars[idx].off = -framesz;
        }
    }
}

static int nfunc;

static void parse_fn(void) {
    /* tr 枚举：批量定义全局常量 */
    if (is_kw("tr")) {
        adv();
        if (cur()->k != TK_ID) die("第 %d 行：tr 后面必须是枚举名", cur()->line);
        adv(); /* 跳过枚举名 */
        expect_p("{");
        skip_nl();
        int val = 0; /* 默认从0开始 */
        while (!is_p("}")) {
            if (cur()->k != TK_ID) die("第 %d 行：枚举成员必须是名字", cur()->line);
            char *ename = cur()->s; adv();
            if (is_p("=")) { adv(); expr(0); em("mov rcx, rax"); val++; }
            else { em("mov rax, %d", val); val++; }
            /* 定义为全局常量 */
            int g = global_find(ename);
            if (g < 0) { g = nglobals++; globals[g].name = ename; }
            globals[g].size = 8; globals[g].count = 1; globals[g].mut = 0;
            globals[g].declared = 1;
            snprintf(globals[g].glabel, sizeof globals[g].glabel, "g_%s", mangle(ename));
            skip_nl();
            if (is_p(",")) adv();
        }
        expect_p("}");
        skip_nl();
        return;
    }

    if (!is_kw("tt") && !is_kw("qj") && !is_kw("tz") && !is_kw("ts") && !is_kw("tf")) die("第 %d 行：顶层只能是 tt 函数定义或 qj/tz/tf/tr 全局声明", cur()->line);
    adv();
    if (cur()->k != TK_ID) die("第 %d 行：hs 后面必须是函数名", cur()->line);
    char *name = cur()->s; adv();

    nvars = 0; framesz = 0;
    expect_p("(");
    int np = 0; char *pname[32];
    if (!is_p(")")) {
        for (;;) {
            /* ★ 对齐自举编译器：参数空格/逗号分隔皆可，类型名可省略（全u64） */
            if (is_p(")")) break;
            if (is_p(",")) { adv(); continue; }
            if (cur()->k != TK_ID) { adv(); continue; }   /* 类型名等其它token直接跳过 */
            pname[np] = cur()->s;
            { char *qn = cur()->s; int qs = 8, qp = 0;   /* ★ 记下参数类型，符号表导出要用 */
              strncpy(函记[函记数].参名[np], qn, 127);
              adv();
              if (is_p(":")) {
                  adv();
                  if (is_p("*")) { adv(); qp = 1; qs = 8;
                      if (cur()->k != TK_TY) die("第 %d 行：参数类型缺失", cur()->line); adv(); }
                  else if (cur()->k == TK_TY) { qs = elem_size_of_type(cur()->s); adv(); }
                  else die("第 %d 行：参数类型缺失", cur()->line);
              } else if (cur()->k == TK_TY) {           /* ★ 无冒号裸类型名：读掉，对齐自举 */
                  qs = elem_size_of_type(cur()->s); adv();
              }
              函记[函记数].参尺寸[np] = qs;
              函记[函记数].参指针[np] = qp;
              np++;
            }
        }
    }
    expect_p(")");
    { int rs = 8;                                  /* 返回类型 */
      if (is_p("->")) { adv(); if (cur()->k != TK_TY) die("第 %d 行：返回类型缺失", cur()->line);
                        rs = elem_size_of_type(cur()->s); adv(); }
      if (函记数 < 256) {
          strncpy(函记[函记数].名, name, 255);
          函记[函记数].参个数 = np;
          函记[函记数].返回尺寸 = rs;
          函记数++;
      }
    }
    expect_p("{");

    char rlab[1024]; snprintf(rlab, sizeof rlab, ".Lret_%s", mangle(name));
    retlabel = rlab;

    prescan_locals(tpos - 1);

    for (int i = 0; i < np; i++) {
        int idx = var_new(pname[i]);
        vars[idx].off = 16 + 8 * (np - 1 - i);
        vars[idx].declared = 1; vars[idx].mut = 0;
        vars[idx].size = 8; vars[idx].count = 1;
    }

    nfunc++;
    in_function = 1;
    {
        char 标[1200];
        snprintf(标, sizeof 标, "fn_%s", mangle(name));
        if (bin_mode) 记标号(标);
        else fprintf(out, "%s\t.globl %s\n%s:\n", nfunc > 1 ? "\n" : "", 标, 标);
    }
    framesz = (framesz + 15) & ~15;        /* ★ 16 字节对齐 */
    em("push rbp"); em("mov rbp, rsp");
    if (framesz) em("sub rsp, %d", framesz);
    em("mov rax, 0");
    block();
    expect_p("}");

    if (bin_mode) 记标号(retlabel); else fprintf(out, "%s:\n", retlabel);
    em("mov rsp, rbp"); em("pop rbp"); em("ret");
    retlabel = NULL;
    in_function = 0;
}

/* ================================================================ 文件生成 */

static int no_mb = 0;   /* -nx：不生成 Multiboot 头（自研引导器路线） */
static int mod_mode = 0;/* -c ：模块（无 _start、无运行时、全局 .comm） */
static int main_mode = 0;/* -m ：主模块（有 _start、无运行时、全局 .comm） */
static int rt_mode = 0; /* -r ：只出运行时 */
static int 对象模式 = 0;/* -对象：出可重定位对象（给小链接器）*/

static void emit_header(void) {
    if (bin_mode) {                     /* ★ 字节模式：直接开始攒 .text */
        换区(区_文本);
        if (!no_mb && !mod_mode && !rt_mode && !main_mode) {
            记前缀(0x1BADB002); 记前缀(0x00000000); 记前缀((unsigned)(-(long)0x1BADB002));
        }
        if (rt_mode || (mod_mode && !main_mode)) return;
        记标号("_start");
        em("mov rsp, offset _kernel_stack_top");
        em("call _gfx_init");
        em("call _rt_cls");
        em("call fn_%s", mangle("zhu"));
        lbl(".Lhang"); em("cli"); em("hlt"); em("jmp .Lhang");
        return;
    }
    fprintf(out, "# 由 六爻(liuyao) 编译器 lyc 生成\n");
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
    em("mov rsp, offset _kernel_stack_top");
    em("call _gfx_init");                  /* EBX = XBP，取自引导器 */
    em("call _rt_cls");                    /* 开机先清屏，抹掉引导器残留 */
    em("call fn_%s", mangle("zhu"));
    lbl(".Lhang"); em("cli"); em("hlt"); em("jmp .Lhang");
}

static void emit_globals_bss(void) {
    if (!nglobals) return;
    if (bin_mode) {                     /* ★ 全局变量：零初始化放 .bss，非零放 .data */
        /* 先输出 .bss 段（全零的全局变量） */
        换区(区_未初);
        while (区长[区_未初] & 3) 出(0);
        for (int i = 0; i < nglobals; i++) {
            if (globals[i].init_val != 0) continue;  /* 非零初始化的放 .data */
            记标号(globals[i].glabel);
            int n = globals[i].size * globals[i].count;
            for (int k = 0; k < n; k++) 出(0);
        }
        /* 再输出 .data 段（非零初始化的全局变量） */
        换区(区_数据);
        while (区长[区_数据] & 7) 出(0);
        for (int i = 0; i < nglobals; i++) {
            if (globals[i].init_val == 0) continue;  /* 零初始化的放 .bss */
            记标号(globals[i].glabel);
            int n = globals[i].size * globals[i].count;
            for (int k = 0; k < n; k++) {
                /* 第一个元素写初始值，其余写 0 */
                long v = (k == 0) ? globals[i].init_val : 0;
                for (int b = 0; b < 8; b++) 出((v >> (b * 8)) & 0xFF);
            }
        }
        换区(区_文本);
        return;
    }
    /* 文本模式：零初始化放 .bss，非零放 .data */
    fprintf(out, "\n\t.section .bss\n\t.align 4\n");
    for (int i = 0; i < nglobals; i++) {
        if (globals[i].init_val != 0) continue;
        if (mod_mode || main_mode)
            fprintf(out, "\t.comm %s, %d, 4\n", globals[i].glabel,
                    globals[i].size * globals[i].count);
        else
            fprintf(out, "%s:\n\t.space %d\n", globals[i].glabel,
                    globals[i].size * globals[i].count);
    }
    fprintf(out, "\n\t.section .data\n\t.align 8\n");
    for (int i = 0; i < nglobals; i++) {
        if (globals[i].init_val == 0) continue;
        fprintf(out, "%s:\n\t.quad %d\n", globals[i].glabel, (int)globals[i].init_val);
        /* 数组其余元素补 0 */
        int rest = globals[i].size * globals[i].count - 8;
        if (rest > 0) fprintf(out, "\t.space %d\n", rest);
    }
}

static void emit_strings(void) {
    if (nstr) {
        if (bin_mode) {                 /* ★ 字符串：放进 .rodata */
            换区(区_只读);
            for (int i = 0; i < nstr; i++) {
                char 标[64];
                snprintf(标, sizeof 标, ".Lstr%d", i);
                记标号(标);
                for (const unsigned char *p = (const unsigned char *)strtab[i]; *p; p++) 出(*p);
                出(0);
            }
            换区(区_文本);
            return;
        }
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
    if (1) {                 /* ★ 64 位：老的手写 32 位 VGA 控制台不适用，
                                运行时改由 宿主/宿主64.s 或内核版提供 */
        换区(区_未初);
        while (区长[区_未初] & 15) 出(0);
        记标号("_kernel_stack");
        for (int i = 0; i < 262144; i++) 出(0);
        记标号("_kernel_stack_top");
        换区(区_文本);
        return;
    }
    if (bin_mode) {          /* ★ 字节模式：运行时是手写汇编，不走这条路；只留内核栈 */
        换区(区_未初);
        while (区长[区_未初] & 15) 出(0);
        记标号("_kernel_stack");
        for (int i = 0; i < 16384; i++) 出(0);
        记标号("_kernel_stack_top");
        换区(区_文本);
        return;
    }
    /* 模块模式下，别的模块也要调运行时 —— 所以运行时的符号必须导出 */
    fprintf(out, "\t.globl _rt_putc, _rt_puts, _rt_puti, _rt_cls, _rt_goto,"
                 " _rt_scroll, _rt_oob, _rt_getc, _rt_getkey, _kernel_stack_top, _rt_platform\n");
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

    /* 平台检测：1=Linux 2=Windows 3=hundunOS */
#ifdef __linux__
    fprintf(out, "\n_rt_platform:\n\tmov eax, 1\n\tret\n");
#elif _WIN32
    fprintf(out, "\n_rt_platform:\n\tmov eax, 2\n\tret\n");
#elif __hundun__
    fprintf(out, "\n_rt_platform:\n\tmov eax, 3\n\tret\n");
#else
    fprintf(out, "\n_rt_platform:\n\tmov eax, 0\n\tret\n");
#endif

    fprintf(out, "\n\t.section .bss\n\t.align 16\n_kernel_stack:\n\t.space 16384\n"
                 "_kernel_stack_top:\n");
}

/* ── 词法流导出（给 stage1 对拍用）─────────────────────────────────
   格式：每行 "<行号> <类别> <内容>"
     数字 → 十进制值        字符串 → 长度 十六进制字节
     关键字/标识符/类型/符号 → 原样文本
   ──────────────────────────────────────────────────────────────── */
static void dump_tokens(void) {
    static const char *类名[] = { "EOF","NL","NUM","STR","ID","KW","TY","P" };
    for (int i = 0; i < ntoks; i++) {
        Tok *t = &toks[i];
        printf("%d %s ", t->line, 类名[t->k]);
        if (t->k == TK_NUM)      printf("%ld\n", t->v);
        else if (t->k == TK_STR) {
            /* ★ 用十进制字节：六爻里只要 印(数字) 就能复现，不用写十六进制打印 */
            const unsigned char *p = (const unsigned char *)t->s;
            int n = strlen(t->s);
            printf("%d", n);
            for (int j = 0; j < n; j++) printf(" %d", p[j]);
            printf("\n");
        }
        else                     printf("%s\n", t->s ? t->s : "");
    }
}

/* ── 符号表导出（给 stage1 的 M2 当对拍靶子）──────────────────────── */
static void dump_syms(void) {
    for (int i = 0; i < nstructs; i++) {
        printf("结构体 %s %d %d\n", structs[i].name, structs[i].size, structs[i].nf);
        for (int j = 0; j < structs[i].nf; j++)
            printf("字段 %s %d\n", structs[i].f[j].name, structs[i].f[j].size);
    }
    for (int i = 0; i < nglobals; i++)
        printf("全局 %s %d %d\n", globals[i].name, globals[i].size, globals[i].count);
    for (int i = 0; i < 函记数; i++) {
        printf("函数 %s %d %d\n", 函记[i].名, 函记[i].参个数, 函记[i].返回尺寸);
        for (int j = 0; j < 函记[i].参个数; j++)
            printf("参数 %s %d %d\n", 函记[i].参名[j], 函记[i].参尺寸[j], 函记[i].参指针[j]);
    }
}

static int 词法模式 = 0;

int main(int argc, char **argv) {
    const char *in = NULL, *outp = "out.s";
    long 载入 = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-o") && i + 1 < argc) outp = argv[++i];
        else if (!strcmp(argv[i], "-nx")) no_mb = 1;   /* 不生成 Multiboot 头 */
        else if (!strcmp(argv[i], "-c")) mod_mode = 1; /* 只出模块 */
        else if (!strcmp(argv[i], "-m")) { main_mode = 1; mod_mode = 1; } /* 主模块 */
        else if (!strcmp(argv[i], "-r")) rt_mode = 1;  /* 只出运行时 */
        else if (!strcmp(argv[i], "-bin")) bin_mode = 1;              /* ★ 直出机器码，不经 as */
        else if (!strcmp(argv[i], "-占位")) 占位模式 = 1;             /* 全局符号留占位（和 .o 一样）*/
        else if (!strcmp(argv[i], "-对象")) { 对象模式 = 1; bin_mode = 1; 占位模式 = 1; }  /* ★ 可重定位对象 */
        else if (!strcmp(argv[i], "-词法")) 词法模式 = 1;             /* ★ 只吐词法流，给 stage1 对拍 */
        else if (!strcmp(argv[i], "-符号")) 符号模式 = 1;             /* ★ 只吐符号表，给 stage1 的 M2 对拍 */
        else if (!strcmp(argv[i], "-base") && i + 1 < argc) 载入 = strtol(argv[++i], 0, 0);
        else if (argv[i][0] != '-') in = argv[i];
    }
    if (!in) die("用法: lyc 输入.ly -o 输出.s   （-bin 直出机器码）");

    FILE *f = fopen(in, "r");
    if (!f) die("打不开源文件：%s", in);
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    char *src = xmalloc(sz + 1);
    if (fread(src, 1, sz, f) != (size_t)sz) die("读源文件失败");
    src[sz] = 0; fclose(f);
    src = 还原数字标点(src);

    /* ★ 作者定的：整个程序写在一个大区里   08 … 09
          → 那就给它补一个函数头，当成主函数（tt 主） */
    {
        const char *q = src;
        while (*q == ' ' || *q == '\t' || *q == '\n' || *q == '\r') q++;
        while (*q == '@' || *q == '#') { while (*q && *q != '\n') q++; while (*q == '\n') q++; }
        while (*q == ' ' || *q == '\t' || *q == '\n' || *q == '\r') q++;
        if (*q == '{') {
            char *新源 = xmalloc(strlen(src) + 32);
            strcpy(新源, "tt \xe4\xb8\xbb() ");
            strcat(新源, src);
            src = 新源;
        }
    }
    lex(src);
    if (词法模式) { dump_tokens(); return 0; }
    if (bin_mode) out = fopen("/dev/null", "w");     /* ★ 字节模式：.s 那条路空转 */
    else          out = fopen(outp, "w");
    if (!out) die("打不开输出文件：%s", outp);

    emit_header();

    if (!rt_mode) {
        tpos = 0; skip_nl();
        while (cur()->k != TK_EOF) {
            if (is_kw("qj") || is_kw("tz") || is_kw("ts") || is_kw("tf") || is_kw("tl")) { stmt(); skip_nl(); continue; }
            parse_fn(); skip_nl();
        }
        if (!nfunc) die("源文件里没有任何函数");
        if (符号模式) dump_syms();
        emit_globals_bss();
        emit_strings();
    }
    if (!mod_mode) emit_runtime();   /* -c/-m 都不出运行时 */
    fclose(out);
    if (bin_mode) {                  /* ★ 排版 + 回填 + 落盘 */
        if (对象模式) {
            snprintf(重定位路径, sizeof 重定位路径, "%s.重定位", outp);
            snprintf(符号表路径, sizeof 符号表路径, "%s.符号", outp);
        }
        int r = 收尾(outp, 载入);
        return r;
    }
    if (符号模式) return 0;          /* -符号：只吐符号表，别打统计 */
    printf("lyc: 六爻 stage0 v0.4 -> %s（%d 字符串 / %d 全局 / %d 函数）",
           outp, nstr, nglobals, nfunc);
    if (mod_mode && !main_mode) printf("  [模块]");
    if (main_mode) printf("  [主模块]");
    if (rt_mode)  printf("  [仅运行时]");
    printf("\n");
    printf("     危险统计：wx 危险块 %d 个，原始指针操作 %d 处\n", wx_blocks, raw_ops);
    return 0;
}
