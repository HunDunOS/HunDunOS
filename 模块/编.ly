00 编 —— 编辑器
00 缓冲 0x50000 起，64 行 x 80 列
00 行数 0x4F000，光行 0x4F008，光列 0x4F010，脏 0x4F018

ts r1 = 0x50000
ts r2 = 0x4F000
ts r3 = 0x4F008
ts r4 = 0x4F010
ts r5 = 0x4F018
ts r6 = 80
ts r7 = 64

00 行首地址：a1 = 行
tt o1 01 a1 02 -> u64  08
    tz b1 = a1 hh r6
    zz 01 r1 ht b1 02
 09

00 取字符：a1 行、a2 列
tt o2 01 a1 , a2 02 -> u64  08
    tz b1 = zt o1 01 a1 02
    tz b2 = 01 b1 ht a2 02
    zz 01 fh b2 hs 255 02
 09

00 放字符：a1 行、a2 列、a3 字
tt o3 01 a1 , a2 , a3 02 -> u64  08
    tz b1 = zt o1 01 a1 02
    tz b2 = 01 b1 ht a2 02
    sh b2 , a3
    zz 0
 09

00 清一行：a1 行
tt o4 01 a1 02 -> u64  08
    tz b1 = 0
    ll  08
        lz b1 r6  08 ls  09
        zt o3 01 a1 , b1 , 32 02
        b1 = b1 ht 1
     09
    zz 0
 09

00 清全部
tt o5 01 02 -> u64  08
    tz b1 = 0
    ll  08
        lz b1 r7  08 ls  09
        zt o4 01 b1 02
        b1 = b1 ht 1
     09
    sh r2 , 1
    sh r3 , 0
    sh r4 , 0
    zz 0
 09

00 在光标处插字：a1 字（右移腾位置）
tt o6 01 a1 02 -> u64  08
    tz b1 = fh r3
    tz b2 = fh r4
    lz b2 r6  08
        zz 0
     09
    tz b3 = 79
    ll  08
        lz b3 b2  08 ls  09
        tz b7 = b3 hz 1
        tz b4 = zt o2 01 b1 , b7 02
        zt o3 01 b1 , b3 , b4 02
        b3 = b3 hz 1
     09
    zt o3 01 b1 , b2 , a1 02
    b2 = b2 ht 1
    sh r4 , b2
    sh r5 , 1
    zz 0
 09

00 退格：光标左移并删字
tt o7 01 02 -> u64  08
    tz b1 = fh r3
    tz b2 = fh r4
    lz b2 0  08
        tz b3 = fh r3
        lz b3 0  08
            zz 0
         09
        b3 = b3 hz 1
        sh r3 , b3
        tz b4 = 79
        ll  08
            lz b4 0  08 ls  09
            tz b5 = zt o2 01 b3 , b4 02
            lz b5 0  08 ls  09
            b4 = b4 hz 1
         09
        zt o3 01 b3 , b4 , 32 02
        sh r4 , b4
        zz 0
     09
    b2 = b2 hz 1
    sh r4 , b2
    tz b5 = 79
    ll  08
        lz b5 b2  08 ls  09
        tz b7 = b5 ht 1
        tz b6 = zt o2 01 b1 , b7 02
        zt o3 01 b1 , b5 , b6 02
        b5 = b5 hz 1
     09
    zt o3 01 b1 , 79 , 32 02
    sh r5 , 1
    zz 0
 09

00 回车：断行
tt o8 01 02 -> u64  08
    tz b1 = fh r2
    lz b1 r7  08
        zz 0
     09
    tz b2 = b1
    ll  08
        lz b2 b1  08 ls  09
        tz b3 = 0
        ll  08
            lz b3 r6  08 ls  09
            tz b4 = zt o2 01 b2 , b3 02
            zt o3 01 01 b2 ht 1 02 , b3 , b4 02
            b3 = b3 ht 1
         09
        zt o4 01 b2 02
        b2 = b2 hz 1
     09
    tz b5 = fh r3
    tz b6 = fh r4
    zt o4 01 b5 02
    tz b7 = b6
    ll  08
        lz b7 r6  08 ls  09
        tz b7 = b7 hz 1
        tz b8 = zt o2 01 b5 , b7 02
        zt o3 01 b5 , b7 , b8 02
        b7 = b7 ht 1
     09
    tz b9 = 0
    ll  08
        lz b9 b6  08 ls  09
        zt o3 01 b5 , b9 , 32 02
        b9 = b9 ht 1
     09
    sh r2 , 01 b1 ht 1 02
    sh r3 , 01 b1 ht 1 02
    sh r4 , 0
    sh r5 , 1
    zz 0
 09

00 光标移动：a1 方向（1上 2下 3左 4右）
tt o9 01 a1 02 -> u64  08
    tz b1 = fh r3
    tz b2 = fh r4
    lz a1 1  08
        lz b1 0  08
            zz 0
         09
        b1 = b1 hz 1
        sh r3 , b1
        zz 0
     09
    lz a1 2  08
        b1 = b1 ht 1
        lz b1 fh r2  08
            sh r3 , b1
            sh r4 , 0
         09
        zz 0
     09
    lz a1 3  08
        lz b2 0  08
            zz 0
         09
        sh r4 , 01 b2 hz 1 02
        zz 0
     09
    lz a1 4  08
        lz b2 79  08
            zz 0
         09
        tz b7 = b2 ht 1
        tz b3 = zt o2 01 b1 , b7 02
        lh b3 0  08
            sh r4 , b7
         09
        zz 0
     09
    zz 0
 09

00 取一行的可见长度
tt oa 01 a1 02 -> u64  08
    tz b1 = 79
    ll  08
        lz b1 0  08 ls  09
        tz b2 = zt o2 01 a1 , b1 02
        lh b2 0  08
            zz 01 b1 ht 1 02
         09
        b1 = b1 hz 1
     09
    zz 0
 09

00 画屏：调简
tt ob 01 02 -> u64  08
    zt f5 01 02
    tz b1 = 0
    ll  08
        lz b1 fh r2  08 ls  09
        lz b1 23  08 ls  09
        tz b2 = 0
        ll  08
            lz b2 40  08 ls  09
            tz b3 = zt o2 01 b1 , b2 02
            lz b3 0  08 ls  09
            zt fa 01 b3 02
            b2 = b2 ht 1
         09
        zt f9 01 10 02
        b1 = b1 ht 1
     09
    zz 0
 09
