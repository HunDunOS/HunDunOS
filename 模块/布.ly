00 布 —— 布局：节点表 → 矩形表
00 节点 0x30000，每节点 8 字段 x 8 字节
00 矩形 0x34000，每行 6 个 u64：x y 宽 高 色 圆角
00 文字 0x38000，每行 6 个 u64：x y 字号 色 串址 长
00 计数：矩形数 0x2C000，文字数 0x2C008

ts j1 = 0x30000
ts j2 = 0x34000
ts j3 = 0x38000
ts j4 = 0x2C000
ts j5 = 0x2C008

00 节点第 a1 个、第 a2 个字段的地址
tt i1 01 a1 , a2 02 -> u64  08
    tz b1 = a1 hh 64
    tz b2 = a2 dh 3
    zz 01 01 j1 ht b1 02 ht b2 02
 09

00 节点第 a1 个、第 a2 个字段的值
tt i2 01 a1 , a2 02 -> u64  08
    tz b1 = zt i1 01 a1 , a2 02
    zz fh b1
 09

00 是不是文字节点（标签首字节 116 = t）
tt i3 01 a1 02 -> u64  08
    tz b1 = zt i2 01 a1 , 0 02
    lz b1 0  08
        zz 0
     09
    tz b2 = fh b1
    tz b2 = 01 b2 hs 255 02
    lz b2 116  08
        zz 1
     09
    zz 0
 09

00 矩形表第 a1 行的基址
tt i4 01 a1 02 -> u64  08
    tz b1 = a1 hh 48
    zz 01 j2 ht b1 02
 09

00 文字表第 a1 行的基址
tt i5 01 a1 02 -> u64  08
    tz b1 = a1 hh 48
    zz 01 j3 ht b1 02
 09

00 把节点 a2 抄到矩形第 a1 行
tt i6 01 a1 , a2 02 -> u64  08
    tz b1 = zt i4 01 a1 02
    tz b2 = zt i2 01 a2 , 1 02
    sh b1 , b2
    tz b3 = zt i2 01 a2 , 2 02
    sh 01 b1 ht 8 02 , b3
    tz b3 = zt i2 01 a2 , 3 02
    sh 01 b1 ht 16 02 , b3
    tz b3 = zt i2 01 a2 , 4 02
    sh 01 b1 ht 24 02 , b3
    tz b3 = zt i2 01 a2 , 5 02
    sh 01 b1 ht 32 02 , b3
    tz b3 = zt i2 01 a2 , 6 02
    sh 01 b1 ht 40 02 , b3
    zz 0
 09

00 把节点 a2 抄到文字第 a1 行
tt i7 01 a1 , a2 02 -> u64  08
    tz b1 = zt i5 01 a1 02
    tz b2 = zt i2 01 a2 , 1 02
    sh b1 , b2
    tz b3 = zt i2 01 a2 , 2 02
    sh 01 b1 ht 8 02 , b3
    tz b3 = zt i2 01 a2 , 6 02
    sh 01 b1 ht 16 02 , b3
    tz b3 = zt i2 01 a2 , 5 02
    sh 01 b1 ht 24 02 , b3
    tz b3 = zt i2 01 a2 , 7 02
    sh 01 b1 ht 32 02 , b3
    zz 0
 09

00 布局：遍历 a1 个节点分流
tt iz 01 a1 02 -> u64  08
    lh a1 256  08
        lz a1 256  08
            zz 0
         09
     09
    tz b1 = 0
    tz b2 = 0
    ll  08
        lz b1 a1  08 ls  09
        tz b3 = zt i3 01 b1 02
        lz b3 1  08
            zt i7 01 b2 , b1 02
            b2 = b2 ht 1
         09
        lz b3 0  08
            tz b4 = zt i2 01 b1 , 1 02
            tz b5 = zt i2 01 b1 , 3 02
            tz b6 = zt i2 01 b1 , 4 02
            lz b5 0  08
                b1 = b1 ht 1
             09
            lh b5 0  08
                zt i6 01 b2 , b1 02
                b2 = b2 ht 1
             09
         09
        b1 = b1 ht 1
     09
    sh j4 , b2
    zz 0
 09
