00 简 —— 字符台（带颜色）
00 每格 4 字节：字符 | 前景 << 8 | 背景 << 16
00 网格 0x20000，40 列 x 25 行
00 光标 0x1F000/0x1F008，当前前景 0x1F010，当前背景 0x1F018
00 色表 0x1F100 起，8 色 x 4 字节
00 f1 格址 f2 存格 f3 读格 f4 清行 f5 清屏 f6 卷屏 f7 下一行
00 f8 写字 f9 控制 fa 吐 fb 吐串 fc 设色 fd 扫色表

ts a1 = 0x20000
ts a2 = 0x1F000
ts a3 = 0x1F008
ts a4 = 40
ts a5 = 25
ts a6 = 0x1F010
ts a7 = 0x1F018
ts a8 = 0x1F100

tt f1 01 b1 , b2 02 -> u64  08
    zz a1 ht 01 01 b1 hh a4 ht b2 02 dh 3 02
 09

tt f2 01 b1 , b2 , b3 02 -> u64  08
    tz b4 = fh a6
    tz b5 = fh a7
    tz b6 = b3
    tz b7 = 01 b4 hs 65535 02
    tz b8 = 01 b5 hs 65535 02
    b6 = b6 hr 01 b7 dh 32 02
    b6 = b6 hr 01 b8 dh 48 02
    tz b9 = zt f1 01 b1 , b2 02
    sh b9 , b6
    zz 0
 09
tt f3 01 b1 , b2 02 -> u64  08
    tz c1 = fh zt f1 01 b1 , b2 02
    zz 01 c1 hs 0xFFFFFFFF 02
 09

tt f4 01 b1 02 -> u64  08
    tz b2 = 0
    ll  08
        lz b2 a4  08 ls  09
        zt f2 01 b1 , b2 , 32 02
        b2 = b2 ht 1
     09
    zz 0
 09

tt f5 01 02 -> u64  08
    tz b1 = 0
    ll  08
        lz b1 a5  08 ls  09
        zt f4 01 b1 02
        b1 = b1 ht 1
     09
    sh a2 , 0
    sh a3 , 0
    zz 0
 09

tt f6 01 02 -> u64  08
    tz b1 = 0
    tz 行末 = 0
    行末 = a5 hz 1
    ll  08
        lz b1 行末  08 ls  09
        tz b2 = 0
        ll  08
            lz b2 a4  08 ls  09
            tz b4 = 01 b1 ht 1 02
            tz b3 = zt f3 01 b4 , b2 02
            tz b5 = zt f1 01 b1 , b2 02
            sh b5 , b3
            b2 = b2 ht 1
         09
        b1 = b1 ht 1
     09
    zt f4 01 a5 hz 1 02
    zz 0
 09

tt f7 01 02 -> u64  08
    tz b1 = fh a2
    sh a3 , 0
    b1 = b1 ht 1
    lz b1 a5  08
        zt f6 01 02
        zz 0
     09
    sh a2 , b1
    zz 0
 09

tt f8 01 b1 02 -> u64  08
    tz b2 = fh a2
    tz b3 = fh a3
    zt f2 01 b2 , b3 , b1 02
    b3 = b3 ht 1
    b3 = b3 hf a4
    lz b3 0  08
        zt f7 01 02
        zz 0
     09
    sh a3 , b3
    zz 0
 09

00 设前景色：a1 = 0 到 7
tt fc 01 b1 02 -> u64  08
    lz b1 8  08
        zz 0
     09
    tz b2 = b1 dh 3
    tz b3 = fh 01 a8 ht b2 02
    sh a6 , b3
    zz 0
 09

00 设背景色：a1 = 0 到 7
tt fg 01 b1 02 -> u64  08
    lz b1 8  08
        zz 0
     09
    tz b2 = b1 dh 3
    tz b3 = fh 01 a8 ht b2 02
    sh a7 , b3
    zz 0
 09

00 控制码：10 换行 13 回行首 8 退格 1 清屏 27 ESC
tt f9 01 b1 02 -> u64  08
    lz b1 10  08
        sh a3 , 0
        zt f7 01 02
        zz 0
     09
    lz b1 13  08
        sh a3 , 0
        zz 0
     09
    lz b1 8  08
        tz b2 = fh a3
        lz b2 0  08
            zz 0
         09
        b2 = b2 hz 1
        sh a3 , b2
        tz b3 = fh a2
        zt f2 01 b3 , b2 , 32 02
        zz 0
     09
    lz b1 1  08
        zz zt f5 01 02
     09
    zz 0
 09

tt fa 01 b1 02 -> u64  08
    tz b2 = 01 b1 hs 0xFFFFFFFF 02
    lz b2 10  08
        zz zt f9 01 10 02
     09
    lz b2 13  08
        zz zt f9 01 13 02
     09
    lz b2 8  08
        zz zt f9 01 8 02
     09
    lz b2 1  08
        zz zt f9 01 1 02
     09
    zz zt f8 01 b2 02
 09

tt 吐串 01 b1 02 -> u64  08
    tz b2 = b1
    ll  08
        tz b3 = fh b2
        tz b4 = 01 b3 hs 0xFFFFFFFF 02
        lz b4 0  08 ls  09
        zt fa 01 b4 02
        b2 = b2 ht 1
     09
    zz 0
 09

00 初始化色表（8 色，跟符咒配色一致）
tt fe 01 02 -> u64  08
    sh a8 , 0xE0554A
    sh 01 a8 ht 4 02 , 0x3FD0C0
    sh 01 a8 ht 8 02 , 0xD0C060
    sh 01 a8 ht 12 02 , 0x2D6CDF
    sh 01 a8 ht 16 02 , 0x8A5AD0
    sh 01 a8 ht 20 02 , 0x40B0E0
    sh 01 a8 ht 24 02 , 0xE6E6F0
    sh 01 a8 ht 28 02 , 0x101014
    sh a6 , 0xE6E6F0
    sh a7 , 0x101014
    zz 0
 09

00 ========== 渲染：网格 → 帧缓冲 ==========
00 a9 = 拼行缓冲，aa = 每行像素高，ab = 字符宽
ts a9 = 0x30000
ts gh = 0
ts aa = 32
ts ab = 16

00 把第 gh 行拼成 C 串（40 字符 + 结尾 0）到 a9
tt fk 01 02 -> u64  08
    tz h1 = 0
    tz h2 = 0
    tz h3 = 0
    tz p1 = 0
    tz p2 = 0
    tz p3 = 0
    h1 = 0
    ll  08
        lz h1 a4  08 ls  09
        p1 = gh hh a4
        p2 = p1 ht h1
        p3 = p2 hh 8
        h2 = a1 ht p3
        h3 = fh h2
        h3 = 01 h3 hs 0xFFFFFFFF 02
        lz h3 0  08
            h3 = 32
         09
        sh 01 a9 ht h1 02 , h3
        h1 = 01 h1 ht 1 02
     09
    sh 01 a9 ht a4 02 , 0
    zz 0
 09

00 整屏上屏：逐行拼串 → 绘字
tt fi 01 02 -> u64  08
    tz j1 = 0
    tz j2 = 0
    j1 = 0
    ll  08
        lz j1 a5  08 ls  09
        gh = j1
        zt fk 01 02
        j2 = 01 j1 hh aa 02
        gh = 0
        00 绘字( x=0, y=j2, 串=a9, 色=0xE6E6F0 )
        绘字 01 0 , j2 , a9 , 0x00E6E6F0 02
        j1 = 01 j1 ht 1 02
     09
    zz 0
 09

00 光标：在第 gh 行第 gc 列画一个下划线
tt fj 01 02 -> u64  08
    tz k1 = 0
    tz k2 = 0
    tz k3 = 0
    k1 = 01 fh a3 02 hh ab
    k2 = 01 gh hh aa 02 ht 01 aa hz 2 02
    绘块 01 k1 , k2 , ab , 2 , 0x00E6E6F0 02
    zz 0
 09

