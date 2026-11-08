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
    tz a3 = 0
    tz a4 = 0
    00 优先读 8042 键盘（新世界），再退回串口（调试用）
    ll  08
        a1 = fl 01 0x64 02
        a2 = 01 a1 hs 1 02
        lz a2 1  08
            a3 = fl 01 0x60 02
            a4 = 01 a3 hs 0x80 02
            lz a4 0x80  08
                00 松开键，丢掉继续等
                a3 = 0
             09
            lh a4 0x80  08
                lz a3 0x1C  08 zz 13  09
                lz a3 0x0E  08 zz 8   09
                lz a3 0x39  08 zz 32  09
                lz a3 0x1E  08 zz 97  09
                lz a3 0x30  08 zz 98  09
                lz a3 0x2E  08 zz 99  09
                lz a3 0x20  08 zz 100 09
                lz a3 0x12  08 zz 101 09
                lz a3 0x21  08 zz 102 09
                lz a3 0x22  08 zz 103 09
                lz a3 0x23  08 zz 104 09
                lz a3 0x17  08 zz 105 09
                lz a3 0x24  08 zz 106 09
                lz a3 0x25  08 zz 107 09
                lz a3 0x26  08 zz 108 09
                lz a3 0x32  08 zz 109 09
                lz a3 0x31  08 zz 110 09
                lz a3 0x18  08 zz 111 09
                lz a3 0x19  08 zz 112 09
                lz a3 0x10  08 zz 113 09
                lz a3 0x13  08 zz 114 09
                lz a3 0x1F  08 zz 115 09
                lz a3 0x14  08 zz 116 09
                lz a3 0x16  08 zz 117 09
                lz a3 0x2F  08 zz 118 09
                lz a3 0x11  08 zz 119 09
                lz a3 0x2D  08 zz 120 09
                lz a3 0x15  08 zz 121 09
                lz a3 0x2C  08 zz 122 09
             09
         09
        00 顺便看串口（保留调试通道）
        a4 = fl 01 0x3FD 02
        a4 = 01 a4 hs 1 02
        lz a4 1  08
            zz fl 01 0x3F8 02
         09
     09
    zz 0
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

00 ========== 在帧缓冲上画字（调 运行时/绘字.asm 的 _xy_draw_text）==========
ts q1 = 0
ts q2 = 0
ts sd1 = 0




00 ========== 开机画面：面 → 圆 → 合成 ==========
tt 画面 01 02 -> u64  08
    tz s1 = 0
    tz z1 = 0
    tz z2 = 0
    tz z3 = 0
    g0 = fh 0x0520
    屏基 = 01 g0 hs 0xFFFFFFFF 02
    g0 = fh 0x0524
    屏行 = 01 g0 hs 0xFFFFFFFF 02

    00 ★ 最简验证：整屏刷成靛蓝（像素数按 XBP 里的宽高算，不写死）
    g0 = fh 0x0528
    g0 = 01 g0 hs 0xFFFFFFFF 02
    z3 = fh 0x052C
    z3 = 01 z3 hs 0xFFFFFFFF 02
    z3 = 01 z3 hh g0 02
    z3 = 01 z3 hh 4 02
    z1 = 屏基
    z2 = 0
    ll  08
        lz z2 z3  08 ls  09
        sh z1 , 0x00303060
        z1 = 01 z1 ht 4 02
        z2 = 01 z2 ht 4 02
     09
    zs 04call _efi_从XBP
04
    g1 = 90
    zt tu 01 02

    00 ★ 用 运行时/绘字.asm 直接在帧缓冲上画字（不依赖 UEFI）
    00 用六爻字符串（进 .rodata）+ 内联汇编画字
    s1 = 03HunDunOS 03
    s1 = 03H03
    zs 04push 0xE8F0FF
push rax
push 200
push 200
call _gfx_text
add esp, 16
04
    g1 = 87
    zt tu 01 02

    00 ★ 第二步：往「面」0xC00000 写 1000 个像素，再搬到屏幕左上角
    z1 = 0xC00000
    z2 = 0
    ll  08
        lz z2 400000  08 ls  09
        sh z1 , 0x00FF8800
        z1 = 01 z1 ht 4 02
        z2 = 01 z2 ht 4 02
     09
    g1 = 89
    zt tu 01 02

    00 把面的前 640 像素搬到屏幕第一行
    z1 = 0xC00000
    z2 = 屏基
    z3 = 0
    ll  08
        lz z3 640  08 ls  09
        g0 = fh z1
        sh z2 , g0
        z1 = 01 z1 ht 4 02
        z2 = 01 z2 ht 4 02
        z3 = 01 z3 ht 1 02
     09
    g1 = 88
    zt tu 01 02

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

00 画字用的常量串（放 .rodata 段末，由 zs 引用）
tt 占位 01 02 -> u64  08
    zz 0
 09

00 主循环
tt zx 01 02 -> u64  08
    sl 01 0x3F8 02 , 88
    tz s5 = 0
    tz n1 = 0
    tz r9 = 0
    tz s9 = 0
    tz d1 = 0
    tz d2 = 0
    tz d3 = 0
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
