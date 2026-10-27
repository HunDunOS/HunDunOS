00 ============================================================
00 六爻自举编译器 lyc_self.ly - 纯血六爻版 v0.3.0
00 规范版本: 六爻指令集 SPEC_v1.0 01 64指令 02
00 架构：dt全局 + tf表 + tt函数 | 目标: x86-64 裸奔无libc
00 状态: 完整自举版 - 支持tt/tz/st/zz/运算/赋值/循环/条件/函数调用/数组/指针
00 ============================================================

00 ---- 全局状态 ----
tz dtd      00 当前字符
tz dtt      00 token类型: 0=EOF 1=数字 2=字符串 3=标识符 4=标点 5=卦指令
tz dth      00 token数值
tz dtz      00 token串指针
tz dtu      00 token长度
tz dtf      00 关键字首字节
tz dts      00 关键字次字节
tz dtn      00 源码长度
tz dtl      00 行号
tz dtb      00 源码指针
tz dtend    00 源码结束指针
tz dtlab    00 标签计数器
tz dsn      00 字符串表计数
tz dnv      00 变量数
tz dfr      00 栈帧大小（预扫描用）
tz dloc     00 局部变量偏移计数器（实际解析用）
tz dtcurfn  00 当前函数名指针
tz dtcurfnl 00 当前函数名长度
tz dln      00 循环嵌套深度

00 ---- 表 ----
tf dsb[65536]: u8    00 源码缓冲
tf dtv[128]: u64     00 变量名表
tf dtw[128]: u64     00 变量偏移表
tf dtisparam[128]: u64  00 是否是参数（1=参数，0=局部）
tf dtvl[128]: u64    00 变量名长度表
tf dsv[256]: u64     00 字符串表
tf dsl[256]: u64     00 字符串长度表
tf dltop[16]: u64    00 循环开始标签栈
tf dlend[16]: u64    00 循环结束标签栈
tf gname[64]: u64    00 全局变量名表
tf gsize[64]: u64    00 全局变量大小 01 字节 02
tf glen[64]: u64     00 全局变量名长度
tz gcount            00 全局变量数
tz infunc             00 是否在函数体内（1=是，0=否，用于区分全局/局部tz声明）
tf pname[16]: u64    00 参数名临时表
tf plen[16]: u64     00 参数名长度临时表
tz pcount            00 参数总数

00 ============================================================
00 基础工具
00 ============================================================

tt lds 01 s 02 -> u64  08
    tz i = 0
    ll  08
        tz a = s ht i
        tz r = fh a
        tz c = r hs 255
        lz c 0  08 zz i  09
        tz i = i ht 1
     09
 09

tt ldh 01 c 02 -> u64  08
    lr c >= 48  08 lr c <= 57  08 zz 1  09  09
    zz 0
 09

tt lsl 01 c 02 -> u64  08
    lr c >= 97  08 lr c <= 122  08 zz 1  09  09
    lr c >= 65  08 lr c <= 90  08 zz 1  09  09
    lr c >= 48  08 lr c <= 57  08 zz 1  09  09
    lr c == 95  08 zz 1  09
    lr c >= 128  08 zz 1  09
    zz 0
 09

tt lsg 01 c 02 -> u64  08
    lr c == 116  08 zz 1  09
    lr c == 122  08 zz 1  09
    lr c == 104  08 zz 1  09
    lr c == 108  08 zz 1  09
    lr c == 102  08 zz 1  09
    lr c == 115  08 zz 1  09
    lr c == 114  08 zz 1  09
    lr c == 100  08 zz 1  09
    zz 0
 09

tt ltm 01 a, b 02 -> u64  08
    tz i = 0
    ll  08
        tz aa = a ht i
        tz ra = fh aa
        tz ca = ra hs 255
        tz bb = b ht i
        tz rb = fh bb
        tz cb = rb hs 255
        lr ca != cb  08 zz 0  09
        lz ca 0  08 zz 1  09
        i = i ht 1
     09
 09

00 ============================================================
00 词法分析
00 ============================================================

tt lft 01  02 -> u64  08
    ll  08
        lr dtb >= dtend  08 zz 0  09
        tz a = dtb
        tz r = fh a
        tz c = r hs 255
        lr c == 32  08 dtb = dtb ht 1  09
        lr c == 9  08 dtb = dtb ht 1  09
        lr c == 10  08 dtb = dtb ht 1 05 dtl = dtl ht 1  09
        lr c == 13  08 dtb = dtb ht 1  09
        lr c != 32  08 lr c != 9  08 lr c != 10  08 lr c != 13  08 ls  09  09  09  09
     09
    zz 0
 09

tt ldn 01  02 -> u64  08
    tz val = 0
    tz digit = 0
    ll  08
        lr dtb >= dtend  08 ls  09
        tz a = dtb
        tz r = fh a
        tz c = r hs 255
        lr ldh 01 c 02 == 0  08 ls  09
        val = val hh 10
        digit = c hz 48
        val = val ht digit
        dtb = dtb ht 1
     09
    dtt = 1
    dth = val
    dtz = 0
    dtu = 0
    zz 1
 09

tt lst 01  02 -> u64  08
    tz start = dtb
    dtb = dtb ht 1
    ll  08
        lr dtb >= dtend  08 ls  09
        tz a = dtb
        tz r = fh a
        tz c = r hs 255
        lr c == 34  08 ls  09
        lr c == 92  08 dtb = dtb ht 1  09
        dtb = dtb ht 1
     09
    dtb = dtb ht 1
    dtt = 2
    dtz = start
    dtu = dtb hz start
    dth = 0
    zz 1
 09

tt lstc 01 02 -> u64  08
    00 纯血字符串扫描：零三开始零四结束，零七转义
    tz start = dtb
    dtb = dtb ht 2
    ll  08
        lr dtb >= dtend  08 ls  09
        tz a = dtb
        tz r = fh a
        tz c = r hs 255
        lr c == 48  08
            lr dtb ht 1 < dtend  08
                tz na = dtb ht 1
                tz nr = fh na
                tz nc = nr hs 255
                lr nc == 52  08
                    dtb = dtb ht 2
                    ls
                 09
                lr nc == 55  08
                    dtb = dtb ht 0
                    ll  08
                        lr dtb >= dtend  08 ls  09
                     09
                    lr dtb < dtend  08 dtb = dtb ht 0  09
                    lr dtb < dtend  08
                        lr dtb >= dtend  08 lr dtb >= dtend  08 dtb = dtb ht 0  09  09
                 09
             09
         09
     09
        dtb = dtb ht 1
     09
    dtt = 2
    dtz = start
    dtu = dtb hz start
    dth = 0
    zz 1
 09

tt llt 01  02 -> u64  08
    lft 01  02
    lr dtb >= dtend  08 dtt = 0 zz 0  09
    tz a = dtb
    tz r = fh a
    tz c = r hs 255
    dtd = c

    00 注释 01 00 02
    lr c == 48  08
        lr dtb ht 1 < dtend  08
            tz na = dtb ht 1
            tz nr = fh na
            tz nc = nr hs 255
            lr nc == 48  08
                dtb = dtb ht 2
                ll  08
                    lr dtb >= dtend  08 ls  09
                    tz a2 = dtb
                    tz r2 = fh a2
                    tz c2 = r2 hs 255
                    lr c2 == 10  08 ls  09
                    dtb = dtb ht 1
                 09
                llt 01  02
                zz 1
             09
         09
     09

    00 零一至零九数字编码（纯血标点）
    lr c == 48  08
        lr dtb ht 1 < dtend  08
            tz ncp = dtb ht 1
            tz ncr = fh ncp
            tz ncc = ncr hs 255
            lr ncc >= 49  08
                lr ncc <= 57  08
                    tz code = ncc hz 48
                    lr code == 3  08
                        00 零三 = 字符串开始
                        lstc 01 02
                        zz 1
                     09
                    00 转换成对应西洋标点码值
                    lr code == 1  08 dth = 40  09
                    lr code == 2  08 dth = 41  09
                    lr code == 5  08 dth = 59  09
                    lr code == 6  08 dth = 47  09
                    lr code == 8  08 dth = 123  09
                    lr code == 9  08 dth = 125  09
                    lr code == 4  08 dth = 34  09
                    lr code == 7  08 dth = 92  09
                    dtt = 4
                    dtz = 0
                    dtu = 1
                    dtb = dtb ht 2
                    zz 1
                 09
             09
         09
     09

    00 数字
    lr ldh 01 c 02 == 1  08 ldn 01  02 05 zz 1  09

    00 字符串
    lr c == 34  08 lst 01  02 05 zz 1  09

    00 两字节卦指令（第三字符若是标识符字符则是变量名，不是指令）
    lr lsg 01 c 02 == 1  08
        lr dtb ht 1 < dtend  08
            tz a3 = dtb ht 1
            tz r3 = fh a3
            tz c3 = r3 hs 255
            lr lsg 01 c3 02 == 1  08
                tz is_kw = 1
                lr dtb ht 2 < dtend  08
                    tz a4 = dtb ht 2
                    tz r4 = fh a4
                    tz c4 = r4 hs 255
                    lr lsl 01 c4 02 == 1  08 tz is_kw = 0  09
                 09
                lr is_kw == 1  08
                    dtf = c
                    dts = c3
                    dtz = dtb
                    dtu = 2
                    dtt = 5
                    dtb = dtb ht 2
                    zz 1
                 09
             09
         09
     09

    00 标识符
    lr lsl 01 c 02 == 1  08
        tz start = dtb
        ll  08
            lr dtb >= dtend  08 ls  09
            tz a4 = dtb
            tz r4 = fh a4
            tz c4 = r4 hs 255
            lr lsl 01 c4 02 == 0  08 ls  09
            dtb = dtb ht 1
         09
        dtz = start
        dtu = dtb hz start
        dtt = 3
        dth = 0
        zz 1
     09

    00 标点（单字符）
    dtt = 4
    dth = c
    dtz = 0
    dtu = 1
    dtb = dtb ht 1
    zz 1
 09

00 ============================================================
00 变量表
00 ============================================================

tt lfv 01 name 02 -> u64  08
    tz i = 0
    tz j = 0
    tz vlen = 0
    tz match = 0
    00 先查局部变量表
    ll  08
        lz i dnv  08 ls  09
        vlen = dtvl[i]
        match = 1
        j = 0
        ll  08
            lz j vlen  08 ls  09
            tz aa = dtv[i] ht j
            tz ra = fh aa
            tz ca = ra hs 255
            tz bb = name ht j
            tz rb = fh bb
            tz cb = rb hs 255
            lr ca != cb  08 match = 0 ls  09
            j = j ht 1
         09
        lr match == 1  08 zz i  09
        i = i ht 1
     09
    00 局部没找到，查全局变量表
    tz gi = 0
    ll  08
        lz gi gcount  08 zz dnv  09  00 全局也没找到，返回dnv

        vlen = glen[gi]
        match = 1
        j = 0
        ll  08
            lz j vlen  08 ls  09
            tz aa = gname[gi] ht j
            tz ra = fh aa
            tz ca = ra hs 255
            tz bb = name ht j
            tz rb = fh bb
            tz cb = rb hs 255

            lr ca != cb  08 match = 0 ls  09
            j = j ht 1
         09

        lr match == 1  08 zz dnv ht gi ht 1  09  00 全局变量返回dnv+gi+1
        gi = gi ht 1
     09
    zz dnv
 09

tt lfoutvar 01 vi 02 -> u64  08
    00 全局变量（vi > dnv）
    lr vi > dnv  08
        tz gi = vi hz dnv hz 1
        st dd 03[g_04
        tz sf0 = dtcurfn
        tz sf1 = dtcurfnl
        dtcurfn = gname[gi]
        dtcurfnl = glen[gi]
        zt lfoutname 01  02
        dtcurfn = sf0
        dtcurfnl = sf1
        st dd 03]04
        zz 0
     09
    00 参数用[rbp+N]，局部变量用[rbp-N]
    lr dtisparam[vi] == 1  08
        st dd 03[rbp+04
        st dt dtw[vi]
        st dd 03]04
        zz 0
     09
    st dd 03[rbp-04
    st dt dtw[vi]
    st dd 03]04
    zz 0
 09

00 ============================================================
00 预扫描：计算函数栈帧大小
00 ============================================================

tt lprescan 01  02 -> u64  08
    00 进入时当前token是 08后面的第一个token
    tz depth = 1
    ll  08
        lz dtt 0  08 zz 0  09
        lr dtt == 4  08 lr dth == 123  08 depth = depth ht 1  09  09
        lr dtt == 4  08 lr dth == 125  08
            depth = depth hz 1
            lz depth 0  08 zz 0  09
         09  09
        lr dtt == 5  08 lr dtf == 116  08 lr dts == 122  08
            00 tz 声明，每个占8字节
            dfr = dfr ht 8
         09  09  09
        llt 01  02
     09
 09

00 ============================================================
00 基础输出
00 ============================================================

tt chu 01 c 02 -> u64  08
    00 输出一个字符到 stdout（用运行时 _rt_putc）
    zt _rt_putc 01 c 02
    zz 0
 09

00 ============================================================
00 函数名mangle输出
00 ============================================================

tt lfoutname 01  02 -> u64  08
    tz i = 0
    ll  08
        lr i >= dtcurfnl  08 ls  09
        tz addr = dtcurfn ht i
        tz c = fh addr
        tz cb = c hs 255
        tz isasc = 0
        lr cb >= 97  08 lr cb <= 122  08 tz isasc = 1  09  09
        lr cb >= 65  08 lr cb <= 90  08 tz isasc = 1  09  09
        lr cb >= 48  08 lr cb <= 57  08 tz isasc = 1  09  09
        lr cb == 95  08 tz isasc = 1  09
        lr isasc == 1  08
            zt chu 01 cb 02
         09 ld  08
            zt chu 01 95 02
            tz hi = cb dl 4
            tz lo = cb hs 15
            lr hi < 10  08 zt chu 01 hi ht 48 02  09
            lr hi >= 10  08 zt chu 01 hi ht 87 02  09
            lr lo < 10  08 zt chu 01 lo ht 48 02  09
            lr lo >= 10  08 zt chu 01 lo ht 87 02  09
         09
        i = i ht 1
     09
    zz i
 09

00 ============================================================
00 表达式解析
00 ============================================================

tt zzp 01  02 -> u64  08
    00 前缀运算：ht a b = a + b, hz a b = a - b 等
    lr dtt == 5  08 lr dtf == 104  08
        tz preop1 = dtf
        tz preop2 = dts
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03mov rcx, rax 
pop rax 
 04
        lr preop1 == 104  08 lr preop2 == 116  08 st dd 03add rax, rcx 
 04  09  09
        lr preop1 == 104  08 lr preop2 == 122  08 st dd 03sub rax, rcx 
 04  09  09
        lr preop1 == 104  08 lr preop2 == 104  08 st dd 03imul rax, rcx 
 04  09  09
        lr preop1 == 104  08 lr preop2 == 108  08 st dd 03xor rdx, rdx 
div rcx 
 04  09  09
        lr preop1 == 104  08 lr preop2 == 102  08 st dd 03xor rdx, rdx 
div rcx 
mov rax, rdx 
 04  09  09
        lr preop1 == 104  08 lr preop2 == 115  08 st dd 03and rax, rcx 
 04  09  09
        lr preop1 == 104  08 lr preop2 == 114  08 st dd 03or rax, rcx 
 04  09  09
        lr preop1 == 104  08 lr preop2 == 100  08 st dd 03xor rax, rcx 
 04  09  09
        lr preop1 == 100  08 lr preop2 == 104  08 st dd 03shl rax, cl 
 04  09  09
        lr preop1 == 100  08 lr preop2 == 108  08 st dd 03shr rax, cl 
 04  09  09
        zz 0
     09  09
    00 zt 函数调用前缀
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 116  08
        llt 01  02
        lr dtt == 3  08
            tz name = dtz
            tz namelen = dtu
            llt 01  02
            lr dtt == 4  08 lr dth == 40  08
                llt 01  02
                tz nargs = 0
                ll  08
                    lr dtt == 4  08 lr dth == 41  08 ls  09  09
                    zzd 01  02
                    st dd 03push rax 
 04
                    nargs = nargs ht 1
                    lr dtt == 4  08 lr dth == 44  08 llt 01  02  09  09
                 09
                llt 01  02
                tz savefn = dtcurfn
                tz savefnl = dtcurfnl
                dtcurfn = name
                dtcurfnl = namelen
                st dd 03call fn_04
                zt lfoutname 01  02
                st dd 03 
 04
                dtcurfn = savefn
                dtcurfnl = savefnl
                lr nargs > 0  08
                    st dd 03add rsp, 04
                    tz nbytes = nargs hh 8
                    st dt nbytes
                    st dd 03 
 04
                 09
                zz 0
             09  09
         09
        zz 0
     09  09  09
    00 dz 空值/Null字面量
    lr dtt == 5  08 lr dtf == 100  08 lr dts == 122  08
        llt 01  02
        st dd 03mov rax, 0 
 04
        zz 0
     09  09  09
    00 df 数组字面量
    lr dtt == 5  08 lr dtf == 100  08 lr dts == 102  08
        llt 01  02
        00 跳过 [
        lr dtt == 4  08 lr dth == 91  08 llt 01  02  09
        tz cnt = 0
        ll  08
            lr dtt == 4  08 lr dth == 93  08 ls  09  09
            zzd 01  02
            st dd 03push rax 
 04
            cnt = cnt ht 1
            lr dtt == 4  08 lr dth == 44  08 llt 01  02  09  09
         09
        00 跳过 ]
        llt 01  02
        00 sub rsp, cnt * 8
        st dd 03sub rsp, 04
        tz nbytes = cnt hh 8
        st dt nbytes
        st dd 03 
 04
        00 逆序pop到连续栈空间
        tz i = 0
        ll  08
            lr i >= cnt  08 ls  09  09
            st dd 03pop rax 
 04
            st dd 03mov [rsp+04 
 04
            tz offset = i hh 8
            st dt offset
            st dd 03], rax 
 04
            i = i ht 1
         09
        st dd 03mov rax, rsp 
 04
        zz 0
     09  09  09
    00 ds 结构体字面量
    lr dtt == 5  08 lr dtf == 100  08 lr dts == 115  08
        llt 01  02
        00 跳过 {
        lr dtt == 4  08 lr dth == 123  08 llt 01  02  09
        tz cnt = 0
        ll  08
            lr dtt == 4  08 lr dth == 125  08 ls  09  09
            00 跳过 .field = （如果有）
            lr dtt == 3  08 lr dth == 0  08
                llt 01  02
                lr dtt == 4  08 lr dth == 61  08 llt 01  02  09  09
             09  09
            zzd 01  02
            st dd 03push rax 
 04
            cnt = cnt ht 1
            lr dtt == 4  08 lr dth == 44  08 llt 01  02  09  09
         09
        00 跳过 }
        llt 01  02
        00 sub rsp, cnt * 8
        st dd 03sub rsp, 04
        tz nbytes = cnt hh 8
        st dt nbytes
        st dd 03 
 04
        00 逆序pop到连续栈空间
        tz i = 0
        ll  08
            lr i >= cnt  08 ls  09  09
            st dd 03pop rax 
 04
            st dd 03mov [rsp+04 
 04
            tz offset = i hh 8
            st dt offset
            st dd 03], rax 
 04
            i = i ht 1
         09
        st dd 03mov rax, rsp 
 04
        zz 0
     09  09  09
    00 数字
    lr dtt == 1  08
        st dd 03mov rax, 04
        st dt dth
        st dd 03 
 04
        llt 01  02
        zz 0
     09
    00 字符串
    lr dtt == 2  08
        tz idx = dsn
        dsv[idx] = dtz
        dsl[idx] = dtu
        dsn = dsn ht 1
        st dd 03lea rax, [rip+.Lstr04
        st dt idx
        st dd 03]
 04
        llt 01  02
        zz 0
     09
    00 dr 按位取反
    lr dtt == 5  08 lr dtf == 100  08 lr dts == 114  08
        llt 01  02
        zzd 01  02
        st dd 03not rax 
 04
        zz 0
     09  09  09
    00 fd 逻辑非
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 100  08
        llt 01  02
        zzd 01  02
        st dd 03test rax, rax 
sete al 
movzx rax, al 
 04
        zz 0
     09  09  09
    00 ft 读键盘
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 116  08
        llt 01  02
        st dd 03call _rt_getc 
 04
        zz 0
     09  09  09
    00 fh 读内存地址
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 104  08
        llt 01  02
        zzd 01  02
        st dd 03mov rax, [rax]
 04
        zz 0
     09  09  09
    00 ff 读数组元素
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 102  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rcx 
mov rax, [rcx+rax*8]
 04
        zz 0
     09  09  09
    00 fr 获取栈指针（Retrieve SP）
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 114  08
        llt 01  02
        st dd 03mov rax, rsp 
 04
        zz 0
     09  09  09
    00 fz 读文件流
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 122  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03mov rdx, rax 
pop rsi 
pop rdi 
xor rax, rax 
syscall 
 04
        zz 0
     09  09  09
    00 fl 读硬件IO端口
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 108  08
        llt 01  02
        zzd 01  02
        st dd 03mov rdx, rax 
xor rax, rax 
in al, dx 
 04
        zz 0
     09  09  09
    00 fs 读结构体成员
    lr dtt == 5  08 lr dtf == 102  08 lr dts == 115  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rcx 
mov rax, [rax+rcx]
 04
        zz 0
     09  09  09
    00 zf 取地址
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 102  08
        llt 01  02
        lr dtt == 3  08
            tz name = dtz
            llt 01  02
            tz vi = lfv 01 name 02
            lr vi < dnv  08
                st dd 03lea rax, 04
                zt lfoutvar 01 vi 02
                st dd 03 
 04
                zz 0
             09
         09
        st dd 03mov rax, 0 
 04
        zz 0
     09  09  09
    00 标识符/数组下标/函数调用
    lr dtt == 3  08
        tz name = dtz
        tz namelen = dtu
        llt 01  02
        00 数组下标 arr[i]
        lr dtt == 4  08 lr dth == 91  08
            llt 01  02
            zzd 01  02
            00 跳过 ]
            ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 93  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
            st dd 03imul rax, 8 
 04
            st dd 03push rax 
 04
            tz vi = lfv 01 name 02
            lr vi < dnv  08
                st dd 03lea rax, 04
                zt lfoutvar 01 vi 02
                st dd 03 
 04
             09 ld  08
                st dd 03mov rax, offset g_04
                tz sf0 = dtcurfn
                tz sf1 = dtcurfnl
                dtcurfn = name
                dtcurfnl = namelen
                zt lfoutname 01  02
                dtcurfn = sf0
                dtcurfnl = sf1
                st dd 03 
 04
             09
            st dd 03mov rcx, rax 
pop rax 
add rax, rcx 
 04
            st dd 03mov rax, [rax]
 04
            zz 0
         09  09
        00 函数调用 name01 args 02
        lr dtt == 4  08 lr dth == 40  08
            llt 01  02
            tz nargs = 0
            ll  08
                lr dtt == 4  08 lr dth == 41  08 ls  09  09
                zzd 01  02
                st dd 03push rax 
 04
                nargs = nargs ht 1
                lr dtt == 4  08 lr dth == 44  08 llt 01  02  09  09
             09
            llt 01  02
            00 临时设置函数名用于mangle
            tz savefn = dtcurfn
            tz savefnl = dtcurfnl
            dtcurfn = name
            dtcurfnl = namelen
            st dd 03call fn_04
            zt lfoutname 01  02
            st dd 03 
 04
            dtcurfn = savefn
            dtcurfnl = savefnl
            lr nargs > 0  08
                st dd 03add rsp, 04
                tz nbytes = nargs hh 8
                st dt nbytes
                st dd 03 
 04
             09
            zz 0
         09  09
        00 普通变量
        tz vi = lfv 01 name 02
        lr vi != dnv  08
            st dd 03mov rax, 04
            zt lfoutvar 01 vi 02
            st dd 03 
 04
            zz 0
         09
        st dd 03mov rax, 0 
 04
        zz 0
     09
    00 未知，返回0
    llt 01  02
    st dd 03mov rax, 0 
 04
    zz 0
 09

tt zzd 01  02 -> u64  08
    zzp 01  02
    ll  08
        00 卦指令运算符（h_系, dh/dl）
        tz isop = 0
        lr dtt == 5  08
            lr dtf == 104  08 tz isop = 1  09
            lr dtf == 100  08 lr dts == 104  08 tz isop = 1  09  09
            lr dtf == 100  08 lr dts == 108  08 tz isop = 1  09  09
         09
        00 比较运算符（标点）
        lr dtt == 4  08
            lr dth == 60  08 tz isop = 1  09
            lr dth == 62  08 tz isop = 1  09
            lr dth == 61  08 tz isop = 1  09
            lr dth == 33  08 tz isop = 1  09
         09
        lr isop == 0  08 ls  09

        00 比较运算符
        lr dtt == 4  08
            tz cmpop = dth
            llt 01  02
            00 >= <= == !=
            lr cmpop == 62  08 lr dtt == 4  08 lr dth == 61  08 tz cmpop = 262 05 llt 01  02  09  09  09
            lr cmpop == 60  08 lr dtt == 4  08 lr dth == 61  08 tz cmpop = 260 05 llt 01  02  09  09  09
            lr cmpop == 61  08 lr dtt == 4  08 lr dth == 61  08 tz cmpop = 261 05 llt 01  02  09  09  09
            lr cmpop == 33  08 lr dtt == 4  08 lr dth == 61  08 tz cmpop = 233 05 llt 01  02  09  09  09
            st dd 03push rax 
 04
            zzd 01  02
            st dd 03mov rcx, rax 
pop rax 
cmp rax, rcx 
 04
            lr cmpop == 261  08 st dd 03sete al 
 04  09
            lr cmpop == 233  08 st dd 03setne al 
 04  09
            lr cmpop == 60  08 st dd 03setb al 
 04  09
            lr cmpop == 62  08 st dd 03seta al 
 04  09
            lr cmpop == 260  08 st dd 03setbe al 
 04  09
            lr cmpop == 262  08 st dd 03setae al 
 04  09
            st dd 03movzx rax, al 
 04
            zz 0
         09

        00 卦指令运算符
        tz opf = dtf
        tz ops = dts
        llt 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03mov rcx, rax 
pop rax 
 04
        lr opf == 104  08 lr ops == 116  08 st dd 03add rax, rcx 
 04  09  09
        lr opf == 104  08 lr ops == 122  08 st dd 03sub rax, rcx 
 04  09  09
        lr opf == 104  08 lr ops == 104  08 st dd 03imul rax, rcx 
 04  09  09
        lr opf == 104  08 lr ops == 108  08 st dd 03xor rdx, rdx 
div rcx 
 04  09  09
        lr opf == 104  08 lr ops == 102  08 st dd 03xor rdx, rdx 
div rcx 
mov rax, rdx 
 04  09  09
        lr opf == 104  08 lr ops == 115  08 st dd 03and rax, rcx 
 04  09  09
        lr opf == 104  08 lr ops == 114  08 st dd 03or rax, rcx 
 04  09  09
        lr opf == 104  08 lr ops == 100  08 st dd 03xor rax, rcx 
 04  09  09
        lr opf == 100  08 lr ops == 104  08 st dd 03shl rax, cl 
 04  09  09
        lr opf == 100  08 lr ops == 108  08 st dd 03shr rax, cl 
 04  09  09
     09
    zz 0
 09

00 ============================================================
00 语句处理
00 ============================================================

tt lzc 01  02 -> u64  08
    00 tz 变量声明
    llt 01  02
    lr dtt != 3  08 zz 0  09
    tz name = dtz
    tz namelen = dtu
    00 先查找变量是否已经存在
    tz vi = lfv 01 name 02
    lr vi < dnv  08
        00 变量已经存在，当成赋值
        llt 01  02
        lr dtt == 4  08 lr dth == 61  08
            llt 01  02
            zzd 01  02
            st dd 03mov 04
            zt lfoutvar 01 vi 02
            st dd 03, rax 
 04
         09  09
        zz 0
     09
    00 变量不存在，声明新变量
    tz vi = dnv
    dtv[vi] = name
    dtvl[vi] = namelen
    dloc = dloc ht 8
    dtw[vi] = dloc
    dtisparam[vi] = 0
    dnv = dnv ht 1
    llt 01  02
    00 = 赋值
    lr dtt == 4  08 lr dth == 61  08
        llt 01  02
        zzd 01  02
        st dd 03mov 04
        zt lfoutvar 01 vi 02
        st dd 03, rax 
 04
     09  09
    zz 0
 09

tt lzs 01  02 -> u64  08
    00 st 输出
    llt 01  02
    lr dtt != 5  08 zz 0  09
    lr dtf == 100  08 lr dts == 100  08
        00 st dd 字符串
        llt 01  02
        lr dtt == 2  08
            dsv[dsn] = dtz
            dsl[dsn] = dtu
            st dd 03lea rax, [rip+.Lstr04
            st dt dsn
            st dd 03]
 04
            st dd 03push rax 
call _rt_puts 
add rsp, 8 
 04
            dsn = dsn ht 1
         09
        zz 0
     09  09
    lr dtf == 100  08 lr dts == 116  08
        00 st dt 整数
        llt 01  02
        zzd 01  02
        st dd 03push rax 
call _rt_puti 
add rsp, 8 
 04
        zz 0
     09  09
    zz 0
 09

tt lzr 01  02 -> u64  08
    00 zz 返回
    llt 01  02
    lr dtt == 1  08
        st dd 03mov rax, 04
        st dt dth
        st dd 03 
 04
        llt 01  02
     09
    lr dtt != 4  08 lr dth != 125  08
        00 返回表达式
        zzd 01  02
     09  09
    st dd 03jmp .Lret_04
    zt lfoutname 01  02
    st dd 03 
 04
    zz 0
 09

tt lzassign 01  02 -> u64  08
    00 赋值语句：变量=表达式 或 数组[i]=表达式
    00 进入时当前token是标识符
    tz name = dtz
    tz namelen = dtu
    llt 01  02
    00 数组下标 arr[i] = expr
    lr dtt == 4  08 lr dth == 91  08
        llt 01  02
        zzd 01  02
        00 跳过 ]
        ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 93  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
        st dd 03imul rax, 8 
 04
        st dd 03push rax 
 04
        tz vi = lfv 01 name 02
        lr vi < dnv  08
            st dd 03lea rax, 04
            zt lfoutvar 01 vi 02
            st dd 03 
 04
         09 ld  08
            st dd 03mov rax, offset g_04
            tz sf0 = dtcurfn
            tz sf1 = dtcurfnl
            dtcurfn = name
            dtcurfnl = namelen
            zt lfoutname 01  02
            dtcurfn = sf0
            dtcurfnl = sf1
            st dd 03 
 04
         09
        st dd 03mov rcx, rax 
pop rax 
add rax, rcx 
 04
        st dd 03push rax 
 04
        00 跳过 =
        ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 61  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
        zzd 01  02
        st dd 03mov rcx, rax 
pop rax 
mov [rax], rcx 
 04
        zz 0
     09  09
    00 普通变量赋值
    00 跳过 =
    ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 61  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
    zzd 01  02
    tz vi = lfv 01 name 02
    lr vi != dnv  08
        st dd 03mov 04
        zt lfoutvar 01 vi 02
        st dd 03, rax 
 04
     09
    zz 0
 09

tt lzlr 01  02 -> u64  08
    00 lr 条件  08 ...  09 [ld  08 ...  09]
    llt 01  02
    zzd 01  02
    tz lab = dtlab
    dtlab = dtlab ht 1
    st dd 03test rax, rax 
jz .Lelse04
    st dt lab
    st dd 03 
 04
    00 跳过  08
    ll  08 lr dtt == 4  08 lr dth == 123  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
    00 then 块
    ll  08
        lr dtt == 4  08 lr dth == 125  08 ls  09  09
        zzh 01  02
     09
    llt 01  02
    00 ld else
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 100  08
        llt 01  02
        tz lab2 = dtlab
        dtlab = dtlab ht 1
        st dd 03jmp .Lendif04
        st dt lab2
        st dd 03 
.Lelse04
        st dt lab
        st dd 03:
 04
        00 跳过  08
        ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 123  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
        00 else 块
        ll  08
            lr dtt == 4  08 lr dth == 125  08 ls  09  09
            zzh 01  02
         09
        llt 01  02
        st dd 03.Lendif04
        st dt lab2
        st dd 03:
 04
        zz 0
     09  09  09
    st dd 03.Lelse04
    st dt lab
    st dd 03:
 04
    zz 0
 09

tt lzlz 01 unequal 02 -> u64  08
    00 lz 相等跳转 / lh 不等跳转
    llt 01  02
    zzd 01  02
    st dd 03push rax 
 04
    zzd 01  02
    st dd 03mov rcx, rax 
pop rax 
cmp rax, rcx 
 04
    tz lab = dtlab
    dtlab = dtlab ht 1
    lr unequal == 0  08
        st dd 03jne .Lelse04
     09 ld  08
        st dd 03je .Lelse04
     09
    st dt lab
    st dd 03 
 04
    00 跳过  08
    ll  08 lr dtt == 4  08 lr dth == 123  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
    00 块
    ll  08
        lr dtt == 4  08 lr dth == 125  08 ls  09  09
        zzh 01  02
     09
    llt 01  02
    st dd 03.Lelse04
    st dt lab
    st dd 03:
 04
    zz 0
 09

tt lzll 01  02 -> u64  08
    00 ll [条件]  08 ...  09
    llt 01  02
    tz top = dtlab
    tz end = dtlab ht 1
    dtlab = dtlab ht 2
    dltop[dln] = top
    dlend[dln] = end
    dln = dln ht 1
    st dd 03.Ltop04
    st dt top
    st dd 03:
 04
    00 条件循环（不是  08）
    lr dtt != 4  08
        zzd 01  02
        st dd 03test rax, rax 
jz .Lend04
        st dt end
        st dd 03 
 04
     09
    00 跳过  08
    ll  08 lr dtt == 4  08 lr dth == 123  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
    00 循环体
    ll  08
        lr dtt == 4  08 lr dth == 125  08 ls  09  09
        zzh 01  02
     09
    llt 01  02
    st dd 03jmp .Ltop04
    st dt top
    st dd 03 
.Lend04
    st dt end
    st dd 03:
 04
    dln = dln hz 1
    zz 0
 09

00 ============================================================
00 语句分派
00 ============================================================

tt zzh 01  02 -> u64  08
    lr dtt == 0  08 zz 0  09

    00 rt 栈上分配空间（Alloc on Stack）
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 116  08
        llt 01  02
        zzd 01  02
        st dd 03sub rsp, rax 
 04
        zz 0
     09  09  09

    00 rz 栈空间回收（Free on Stack）
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 122  08
        llt 01  02
        zzd 01  02
        st dd 03add rsp, rax 
 04
        zz 0
     09  09  09

    00 rh 强制类型转换
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 104  08
        llt 01  02
        llt 01  02
        zzd 01  02
        zz 0
     09  09  09

    00 rl 内存重分配（Realloc）
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 108  08
        llt 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rdi 
pop rsi 
mov rdi, rax 
mov rax, 12 
syscall 
 04
        zz 0
     09  09  09

    00 rf 内存清零
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 102  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rcx 
pop rdi 
mov rdi, rax 
mov rax, rcx 
call memset 
 04
        zz 0
     09  09  09

    00 rs 释放内存
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 115  08
        llt 01  02
        zzd 01  02
        st dd 03mov rdi, rax 
call free 
 04
        zz 0
     09  09  09

    00 rr 申请堆内存
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 114  08
        llt 01  02
        zzd 01  02
        st dd 03mov rdi, rax 
call malloc 
 04
        zz 0
     09  09  09

    00 rd 内存拷贝
    lr dtt == 5  08 lr dtf == 114  08 lr dts == 100  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rdx 
pop rsi 
pop rdi 
call memcpy 
 04
        zz 0
     09  09  09

    00 lt 无条件跳转
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 116  08
        llt 01  02
        lr dtt == 3  08
            st dd 03jmp .L04
            zt lfoutname 01  02
            st dd 03 
 04
         09
        zz 0
     09  09  09

    00 zh 标签定义
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 104  08
        llt 01  02
        lr dtt == 3  08
            st dd 03.L04
            zt lfoutname 01  02
            st dd 03:
 04
         09
        zz 0
     09  09  09

    00 ts 全局变量声明（Global Var）
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 115  08
        llt 01  02
        lr dtt == 3  08
            tz gi = gcount
            gname[gi] = dtz
            glen[gi] = dtu
            gsize[gi] = 8
            gcount = gcount ht 1
         09
        zz 0
     09  09  09

    00 th 只读常量
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 104  08
        llt 01  02
        lr dtt == 3  08
            tz gi = gcount
            gname[gi] = dtz
            glen[gi] = dtu
            gsize[gi] = 8
            gcount = gcount ht 1
         09
        zz 0
     09  09  09

    00 tr 枚举类型
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 114  08
        llt 01  02
        lr dtt == 4  08 lr dth == 123  08 llt 01  02  09  09
        ll  08
            lr dtt == 4  08 lr dth == 125  08 ls  09  09
            lr dtt == 3  08
                tz gi = gcount
                gname[gi] = dtz
                glen[gi] = dtu
                gsize[gi] = 8
                gcount = gcount ht 1
                llt 01  02
             09
            lr dtt == 4  08 lr dth == 61  08 llt 01  02  09  09
            zzd 01  02
            lr dtt == 4  08 lr dth == 44  08 llt 01  02  09  09
         09
        llt 01  02
        zz 0
     09  09  09

    00 td 布尔类型
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 100  08
        llt 01  02
        lr dtt == 3  08
            tz gi = gcount
            gname[gi] = dtz
            glen[gi] = dtu
            gsize[gi] = 8
            gcount = gcount ht 1
         09
        zz 0
     09  09  09

    00 tl 结构体蓝图
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 108  08
        llt 01  02
        lr dtt == 4  08 lr dth == 123  08 llt 01  02  09  09
        ll  08
            lr dtt == 4  08 lr dth == 125  08 ls  09  09
            lr dtt == 3  08
                tz gi = gcount
                gname[gi] = dtz
                glen[gi] = dtu
                gsize[gi] = 8
                gcount = gcount ht 1
                llt 01  02
             09
            lr dtt == 4  08 lr dth == 58  08 llt 01  02  09  09
            llt 01  02
            lr dtt == 4  08 lr dth == 44  08 llt 01  02  09  09
         09
        llt 01  02
        zz 0
     09  09  09

    00 tf 全局数组声明
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 102  08
        llt 01  02
        lr dtt == 3  08
            tz gi = gcount
            gname[gi] = dtz
            glen[gi] = dtu
            llt 01  02
            00 跳过 [
            ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 91  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
            tz arrn = dth
            llt 01  02
            00 跳过 ]
            ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 93  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
            00 跳过 : type
            ll  08 lz dtt 0  08 ls  09 05 lr dtt == 4  08 lr dth == 58  08 llt 01  02 05 ls  09  09 05 llt 01  02  09
            llt 01  02  00 跳过类型名
            gsize[gi] = arrn hh 8
            gcount = gcount ht 1
         09
        zz 0
     09  09  09
    00 tz 声明
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 122  08

        lr infunc == 0  08
            00 全局tz变量：记录到全局表，.bss分配8字节
            llt 01  02

            lr dtt == 3  08
                tz gi = gcount
                gname[gi] = dtz
                glen[gi] = dtu
                gsize[gi] = 8
                gcount = gcount ht 1
             09
            zz 0
         09
        lzc 01  02
        zz 0
     09  09  09

    00 st 输出
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 116  08 lzs 01  02 05 zz 0  09  09  09

    00 sz 写文件流
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 122  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03mov rdx, rax 
pop rsi 
pop rdi 
mov rax, 1 
syscall 
 04
        zz 0
     09  09  09

    00 sh 写内存地址
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 104  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rcx 
mov [rcx], rax 
 04
        zz 0
     09  09  09

    00 sl 写硬件IO端口
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 108  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03mov rcx, rax 
pop rdx 
mov rax, rcx 
out dx, al 
 04
        zz 0
     09  09  09

    00 sf 写数组元素
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 102  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rcx 
pop rdx 
mov [rdx+rcx*8], rax 
 04
        zz 0
     09  09  09

    00 ss 写结构体成员
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 115  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03push rax 
 04
        zzd 01  02
        st dd 03pop rcx 
pop rdx 
mov [rax+rcx], rdx 
 04
        zz 0
     09  09  09

    00 sr 重置栈指针（Reset SP）
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 114  08
        llt 01  02
        zzd 01  02
        st dd 03mov rsp, rax 
 04
        zz 0
     09  09  09

    00 sd 调试/日志输出
    lr dtt == 5  08 lr dtf == 115  08 lr dts == 100  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
call _rt_puti 
add rsp, 8 
 04
        zz 0
     09  09  09

    00 zz 返回
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 122  08 lzr 01  02 05 zz 0  09  09  09

    00 zl 函数指针/回调（取函数地址）
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 108  08
        llt 01  02
        lr dtt == 3  08
            st dd 03mov rax, offset fn_04
            zt lfoutname 01  02
            st dd 03 
 04
         09
        zz 0
     09  09  09

    00 zr 断言
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 114  08
        llt 01  02
        zzd 01  02
        st dd 03test rax, rax 
jnz .LokOk04
        st dd 03mov rax, 60 
xor rdi, rdi 
syscall 
 04
        st dd 03.LokOk: 
 04 
        zz 0
     09  09  09

    00 zs 内联汇编块
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 115  08
        llt 01  02
        lr dtt == 2  08
            st dd 03 04
            llt 01  02
         09
        zz 0
     09  09  09

    00 lr 条件
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 114  08 lzlr 01  02 05 zz 0  09  09  09

    00 lz 相等跳转
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 122  08 zt lzlz 01 0 02 05 zz 0  09  09  09

    00 lh 不等跳转
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 104  08 zt lzlz 01 1 02 05 zz 0  09  09  09

    00 ll 循环
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 108  08 lzll 01  02 05 zz 0  09  09  09

    00 ls 跳出
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 115  08
        llt 01  02
        lr dln > 0  08
            st dd 03jmp .Lend04
            tz idx = dln hz 1
            st dt dlend[idx]
            st dd 03 
 04
         09
        zz 0
     09  09  09

    00 lf 继续
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 102  08
        llt 01  02
        lr dln > 0  08
            st dd 03jmp .Ltop04
            tz idx = dln hz 1
            st dt dltop[idx]
            st dd 03 
 04
         09
        zz 0
     09  09  09

    00 ld 开关分支
    lr dtt == 5  08 lr dtf == 108  08 lr dts == 100  08
        llt 01  02
        zzd 01  02
        st dd 03push rax 
 04
        zz 0
     09  09  09

    00 zt 函数调用语句
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 116  08
        llt 01  02
        zzd 01  02
        zz 0
     09  09  09

    00 zd 系统调用
    lr dtt == 5  08 lr dtf == 122  08 lr dts == 100  08
        llt 01  02
        zzd 01  02
        st dd 03mov rax, rdi 
syscall 
 04
        zz 0
     09  09  09

    00 tt 函数定义
    lr dtt == 5  08 lr dtf == 116  08 lr dts == 116  08
        llt 01  02
        tz save_dtb = dtb
        lr dtt == 3  08
            dtcurfn = dtz
            dtcurfnl = dtu
         09
        00 跳过参数列表
        ll  08 llt 01  02 05 lr dtt == 4  08 lr dth == 41  08 ls  09  09  09
        00 跳过返回类型 -> u64  08
        ll  08 llt 01  02 05 lr dtt == 4  08 lr dth == 123  08 ls  09  09  09
        llt 01  02
        00 预扫描
        dfr = 0
        dnv = 0
        zt lprescan 01  02
        00 恢复重新解析
        dtb = save_dtb
        llt 01  02
        00 生成函数标签和序言
        st dd 03.globl fn_04
        zt lfoutname 01  02
        st dd 03 
fn_04
        zt lfoutname 01  02
        st dd 03:
 04
        st dd 03push rbp 
mov rbp, rsp 
sub rsp, 04
        st dt dfr
        st dd 03 
 04
        dnv = 0
        00 解析参数列表
        pcount = 0
        llt 01  02  00 跳过 01 
        ll  08
            lr dtt == 4  08 lr dth == 41  08 ls  09  09
            lr dtt == 3  08
                pname[pcount] = dtz
                plen[pcount] = dtu
                pcount = pcount ht 1
                llt 01  02
             09
            lr dtt == 4  08 lr dth == 44  08 llt 01  02  09  09
         09
        llt 01  02  00 跳过  02
        00 参数加入变量表: 第i个参数偏移=16+8*01 pcount-1-i 02
        tz pi2 = 0
        ll  08
            lz pi2 pcount  08 ls  09
            dtv[dnv] = pname[pi2]
            dtvl[dnv] = plen[pi2]
            dtw[dnv] = 16 ht 01 8 hh 01 pcount hz 1 hz pi2 02 02
            dtisparam[dnv] = 1
            dnv = dnv ht 1
            pi2 = pi2 ht 1
         09
        dloc = 0
        00 跳过返回类型
        ll  08 llt 01  02 05 lr dtt == 4  08 lr dth == 123  08 ls  09  09  09
        llt 01  02
        00 解析函数体
        infunc = 1
        ll  08
            lr dtt == 4  08 lr dth == 125  08
                infunc = 0
                st dd 03.Lret_04
                zt lfoutname 01  02
                st dd 03:
mov rsp, rbp 
pop rbp 
ret 
 04
                llt 01  02
                zz 0
             09  09
            zzh 01  02
         09
        infunc = 0
        zz 0
     09  09  09

    00 标识符开头：=或[走赋值，否则表达式语句（函数调用）
    lr dtt == 3  08
        tz s_dtd = dtd
        tz s_dtt = dtt
        tz s_dth = dth
        tz s_dtz = dtz
        tz s_dtu = dtu
        tz s_dtb = dtb
        llt 01  02
        lr dtt == 4  08 lr dth == 61  08
            dtd = s_dtd
            dtt = s_dtt
            dth = s_dth
            dtz = s_dtz
            dtu = s_dtu
            dtb = s_dtb
            lzassign 01  02
            zz 0
         09  09
        lr dtt == 4  08 lr dth == 91  08
            dtd = s_dtd
            dtt = s_dtt
            dth = s_dth
            dtz = s_dtz
            dtu = s_dtu
            dtb = s_dtb
            lzassign 01  02
            zz 0
         09  09
        dtd = s_dtd
        dtt = s_dtt
        dth = s_dth
        dtz = s_dtz
        dtu = s_dtu
        dtb = s_dtb
        zzd 01  02
        zz 0
     09

    00 未知，跳过
    llt 01  02
    zz 0
 09

00 ============================================================
00 主函数
00 ============================================================

tt zhu 01 fname 02 -> u64  08
    00 从命令行参数读取源码文件
    tz slen = 0
    tz src = zt _rt_slurp 01 fname, zf slen 02
    lz src 0  08 zz 1  09

    dtb = src
    dtn = slen
    dtend = src ht slen
    dtl = 1
    dtlab = 0
    dsn = 0
    dnv = 0
    dfr = 0
    dln = 0
    gcount = 0

    00 吐汇编头部
    st dd 03.intel_syntax noprefix 
.section .text 
 04

    00 解析
    llt 01  02
    ll  08
        lz dtt 0  08 ls  09
        zzh 01  02
     09

    00 输出 .bss 全局变量
    st dd 03.section .bss 
.align 8 
 04
    tz gi = 0
    ll  08
        lz gi gcount  08 ls  09
        st dd 03g_04
        tz sf0 = dtcurfn
        tz sf1 = dtcurfnl
        dtcurfn = gname[gi]
        dtcurfnl = glen[gi]
        zt lfoutname 01  02
        dtcurfn = sf0
        dtcurfnl = sf1
        st dd 03: .space 04
        st dt gsize[gi]
        st dd 03 
 04
        gi = gi ht 1
     09
    00 输出字符串表
    tz si = 0
    st dd 03.section .rodata 
 04
    ll  08
        lz si dsn  08 ls  09
        st dd 03.Lstr04
        st dt si
        st dd 03:.asciz 0304
        00 输出字符串内容（跳过03头04尾）
        tz sptr = dsv[si] ht 2
        tz slen2 = dsl[si] hz 4
        tz j = 0
        ll  08
            lz j slen2  08 ls  09
            tz a = sptr ht j
            tz r = fh a
            tz c = r hs 255
            tz h07nxt = c
            tz h07jump = 1
            00 零三串内引号 零七串内反斜杠 绝对无转义
            lr c == 48  08
                tz h07q1a = sptr ht j ht 1
                tz h07q1r = fh h07q1a
                tz h07q1 = h07q1r hs 255
                lr h07q1 == 51  08
                    h07nxt = 34
                    h07jump = 2
                 09
                lr h07q1 == 55  08
                    h07nxt = 92
                    h07jump = 2
                 09
             09
            lr h07nxt == 34  08 zt chu 01 92 02 05 zt chu 01 34 02  09
            lr h07nxt == 92  08 zt chu 01 92 02 05 zt chu 01 92 02  09
            lr h07nxt == 10  08 zt chu 01 92 02 05 zt chu 01 110 02  09
            lr h07nxt != 34  08 lr h07nxt != 92  08 lr h07nxt != 10  08 zt chu 01 h07nxt 02  09  09  09
            tz j = j ht h07jump
         09
        st dd 0303
 04
        tz si = si ht 1
     09

    zz 0
 09
