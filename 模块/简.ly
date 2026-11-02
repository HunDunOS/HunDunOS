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
    zz a1 ht 01 01 b1 hh a4 ht b2 02 dh 2 02
 09

tt f2 01 b1 , b2 , b3 02 -> u64  08
    tz b4 = fh a6
    tz b5 = fh a7
    tz b6 = 01 b3 hs 255 02
    b6 = b6 hr 01 b4 dh 8 02
    b6 = b6 hr 01 b5 dh 16 02
    sh zt f1 01 b1 , b2 02 , b6
    zz 0
 09

tt f3 01 b1 , b2 02 -> u64  08
    zz fh zt f1 01 b1 , b2 02
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
    ll  08
        lz b1 01 a5 hz 1 02  08 ls  09
        tz b2 = 0
        ll  08
            lz b2 a4  08 ls  09
            tz b3 = zt f3 01 01 b1 ht 1 02 , b2 02
            sh zt f1 01 b1 , b2 02 , b3
            b2 = b2 ht 1
         09
        b1 = b1 ht 1
     09
    zt f4 01 a5 hz 1 02
    zz 0
 09

tt f7 01 02 -> u64  08
    tz b1 = fh a2
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
    tz b2 = b1 dh 2
    tz b3 = fh 01 a8 ht b2 02
    sh a6 , b3
    zz 0
 09

00 设背景色：a1 = 0 到 7
tt fg 01 b1 02 -> u64  08
    lz b1 8  08
        zz 0
     09
    tz b2 = b1 dh 2
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
    tz b2 = 01 b1 hs 255 02
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

tt fb 01 b1 02 -> u64  08
    tz b2 = b1
    ll  08
        tz b3 = fh b2
        tz b4 = 01 b3 hs 255 02
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
