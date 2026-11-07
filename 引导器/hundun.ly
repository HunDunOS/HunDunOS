00 敕令层 —— 变量全在函数头声明（tz 不能进循环，不能重复）

00 ★ 跳板：链接后 落址+64 必须落在它身上，它再叫主函数进来
tt 入口 01 02 -> u64  08
    zt zx 01 02
    zz 0
 09

ts g1 = 0
ts g2 = 0
ts g3 = 0
ts g0 = 0

00 ---- 象 的全局（链接时合并）----
ts gx = 0
ts gy = 0
ts gw = 0
ts gh = 0
ts gc = 0
ts gr = 0
ts 屏基 = 0
ts 屏行 = 0


00 ---- 数 的全局 ----
ts ga = 0
ts gb = 0

00 输出 g1 的字符
tt tu 01 02 -> u64  08
    tz d1 = 0
    d1 = 01 g1 hs 255 02
    sl 01 0x3F8 02 , d1
    zz 0
 09

00 输出 g1 指向的 0 结尾串
tt tc 01 02 -> u64  08
    tz p0 = 0
    tz 动 = 0
    tz d2 = 0
    p0 = g1
    动 = 1
    ll  08
        lz 动 0  08 ls  09
        d2 = fh p0
        d2 = 01 d2 hs 255 02
        lz d2 0  08
            动 = 0
         09
        lh d2 0  08
            g1 = d2
            zt tu 01 02
         09
        p0 = 01 p0 ht 1 02
     09
    zz 0
 09

00 打 g2 的两位十六进制
tt sx 01 02 -> u64  08
    tz b1 = 0
    tz b2 = 0
    tz e1 = 0
    tz e2 = 0
    b1 = 01 g2 dl 4 02
    b2 = 01 b1 hs 15 02
    lz b2 10  08
        e1 = 01 48 ht b2 02
        g1 = e1
        zt tu 01 02
     09
    lh b2 10  08
        e2 = 01 b2 hz 10 02
        e1 = 01 65 ht e2 02
        g1 = e1
        zt tu 01 02
     09
    b1 = 01 g2 hs 15 02
    lz b1 10  08
        e1 = 01 48 ht b1 02
        g1 = e1
        zt tu 01 02
     09
    lh b1 10  08
        e2 = 01 b1 hz 10 02
        e1 = 01 65 ht e2 02
        g1 = e1
        zt tu 01 02
     09
    zz 0
 09

00 读键
tt du 01 02 -> u64  08
    tz a1 = 0
    tz a2 = 0
    ll  08
        a1 = fl 01 0x3FD 02
        a2 = 01 a1 hs 1 02
        lz a2 1  08 ls  09
     09
    zz fl 01 0x3F8 02
 09

00 读一行到 0x700，返回长度
tt ln 01 02 -> u64  08
    tz c1 = 0
    tz s1 = 0
    tz k1 = 0
    c1 = 0
    s1 = 0
    ll  08
        lz s1 1  08 ls  09
        k1 = zt du 01 02
        g2 = k1
        zt sx 01 02
        lz k1 13  08
            s1 = 1
         09
        lh k1 13  08
            lz k1 8  08
                lh c1 0  08
                    c1 = 01 c1 hz 1 02
                 09
             09
            lh k1 8  08
                lz c1 64  08
                    sh 01 0x700 ht 01 c1 dh 3 02 02 , k1
                    c1 = 01 c1 ht 1 02
                 09
             09
         09
     09
    g1 = 13
    zt tu 01 02
    g1 = 10
    zt tu 01 02
    zz c1
 09

00 命令分派：g3 = 长度
tt ml 01 02 -> u64  08
    tz i1 = 0
    tz i2 = 0
    tz s2 = 0
    tz s3 = 0
    tz s4 = 0
    lz g3 0  08
        zz 0
     09
    i1 = fh 0x700
    i1 = 01 i1 hs 255 02
    lz i1 99  08
        lz g3 2  08
            i2 = fh 0x708
            i2 = 01 i2 hs 255 02
            lz i2 108  08
                s2 = 03cl yuan0 neng11111 03
                g1 = s2
                zt tc 01 02
                g1 = 10
                zt tu 01 02
                zz 0
             09
         09
     09
    lz i1 100  08
        s3 = 03db yin 0x100000 yang 0x200000 he 0x180000 03
        g1 = s3
        zt tc 01 02
        g1 = 10
        zt tu 01 02
        zz 0
     09
    s4 = 03unknown - try bz 03
    g1 = s4
    zt tc 01 02
    g1 = 10
    zt tu 01 02
    zz 0
 09

00 ========== 打十进制（g2）==========
tt pd 01 02 -> u64  08
    tz q1 = 0
    tz q2 = 0
    tz q3 = 0
    q1 = g2
    lz q1 0  08
        g1 = 48
        zt tu 01 02
        zz 0
     09
    q2 = 0
    q3 = g2
    ll  08
        lz q3 0  08 ls  09
        q1 = 01 q3 hf 10 02
        q1 = 01 q1 ht 48 02
        sh 01 0x700 ht q2 02 , q1
        q3 = 01 q3 hl 10 02
        q2 = 01 q2 ht 1 02
     09
    ll  08
        lz q2 0  08 ls  09
        q2 = 01 q2 hz 1 02
        g1 = fh 01 0x700 ht q2 02
        zt tu 01 02
     09
    zz 0
 09

tt 打空 01 02 -> u64  08
    g1 = 32
    zt tu 01 02
    zz 0
 09

00 ========== 开机画面：面 → 圆 → 合成 ==========
tt 画面 01 02 -> u64  08
    g0 = fh 0x0520
    屏基 = 01 g0 hs 0xFFFFFFFF 02
    g0 = fh 0x0524
    屏行 = 01 g0 hs 0xFFFFFFFF 02

    g1 = 97
    zt tu 01 02
    gx = 0
    gy = 0
    gw = 640
    gh = 400
    zt 象_面 01 02
    g1 = 98
    zt tu 01 02
    gc = 0x001E1E26
    zt 象_块 01 02
    g1 = 99
    zt tu 01 02
    ga = 14400
    g2 = zt sq 01 02
    zt pd 01 02
    g1 = 44
    zt tu 01 02

    gx = 0
    gy = 0
    gw = 640
    gh = 32
    gc = 0x00262633
    zt 象_块 01 02

    gx = 320
    gy = 200
    gr = 120
    gc = 0x003FD0C0
    zt 象_圆 01 02
    g1 = 100
    zt tu 01 02

    gx = 120
    gy = 200
    gr = 60
    gc = 0x002D6CDF
    zt 象_圆 01 02

    gx = 80
    gy = 60
    zt 象_合 01 02
    g1 = 101
    zt tu 01 02
    zz 0
 09

00 ========== 读数自检：牛顿开方 / 斐波那契 / 定点除 ==========
tt 读数 01 02 -> u64  08
    tz r1 = 0
    tz r2 = 0
    tz r3 = 0

    ga = 144
    g2 = zt sq 01 02
    r1 = 03sqrt144= 03
    g1 = r1
    zt tc 01 02
    zt pd 01 02
    zt 打空 01 02

    ga = 20
    g2 = zt fb 01 02
    r2 = 03fib20= 03
    g1 = r2
    zt tc 01 02
    zt pd 01 02
    zt 打空 01 02

    ga = 65536
    gb = 131072
    g2 = zt dc 01 02
    g2 = 01 g2 hl 65536 02
    r3 = 03div= 03
    g1 = r3
    zt tc 01 02
    zt pd 01 02
    zt 打空 01 02
    zz 0
 09

00 主循环
tt zx 01 02 -> u64  08
    sl 01 0x3F8 02 , 88
    tz s5 = 0
    tz n1 = 0
    tz r9 = 0
    tz s9 = 0
    s5 = 03CL hundun LL 03
    g1 = 10
    zt tu 01 02
    r9 = 0
    zt 画面 01 02
    s9 = 03face ok 03
    g1 = s9
    zt tc 01 02
    g1 = 10
    zt tu 01 02
    zt 读数 01 02
    ll  08
        g1 = s5
        zt tc 01 02
        n1 = zt ln 01 02
        g3 = n1
        zt ml 01 02
     09
    zz 0
 09
