00 布测 —— 布局测试
00 造 4 个节点，调布局，串口打矩形表

ts t1 = 0x30000

00 串口打一个字节
tt q1 01 a1 02 -> u64  08
    sl 01 0x3F8 02 , 01 a1 hs 255 02
    zz 0
 09

00 串口打 16 位十六进制
tt q2 01 a1 02 -> u64  08
    tz b1 = 16
    ll  08
        lz b1 0  08 ls  09
        b1 = 01 b1 hz 1 02
        tz b2 = 01 01 a1 dl b1 02 hs 15 02
        lz b2 10  08
            zt q1 01 48 ht b2 02
         09
        lh b2 10  08
            zt q1 01 65 ht 01 b2 hz 10 02 02
         09
     09
    zz 0
 09

00 打换行
tt q3 01 02 -> u64  08
    zt q1 01 10 02
    zz 0
 09

00 写节点：序号、标签址、x、y、宽、高、色、圆角
tt q4 01 a1 , a2 , a3 , a4 , a5 , a6 , a7 , a8 02 -> u64  08
    tz b1 = a1 hh 64
    tz b2 = 01 t1 ht b1 02
    sh b2 , a2
    tz b3 = 01 b2 ht 8 02
    sh b3 , a3
    tz b3 = 01 b2 ht 16 02
    sh b3 , a4
    tz b3 = 01 b2 ht 24 02
    sh b3 , a5
    tz b3 = 01 b2 ht 32 02
    sh b3 , a6
    tz b3 = 01 b2 ht 40 02
    sh b3 , a7
    tz b3 = 01 b2 ht 48 02
    sh b3 , a8
    zz 0
 09

tt zhu 01 argv 02 -> u64  08
    zt q3 01 02
    zt q1 01 76 02
    zt q1 01 61 02
    zt q1 01 79 02
    zt q3 01 02

    zt q4 01 0 , 100 , 0 , 0 , 1280 , 800 , 0x202830 , 0 02
    zt q4 01 1 , 100 , 80 , 60 , 640 , 400 , 0x1E1E26 , 12 02
    zt q4 01 2 , 116 , 120 , 72 , 0 , 0 , 0xE6E6F0 , 2 02
    zt q4 01 3 , 100 , 120 , 300 , 180 , 48 , 0x2D6CDF , 8 02

    zt iz 01 4 02

    tz b1 = fh 0x2C000
    zt q1 01 82 02
    zt q1 01 32 02
    zt q2 01 b1 02
    zt q3 01 02

    tz b2 = 0
    ll  08
        lz b2 b1  08 ls  09
        tz b3 = 01 0x34000 ht 01 b2 hh 48 02
        tz b4 = fh b3
        zt q2 01 b4 02
        zt q1 01 32 02
        tz b3 = 01 b3 ht 8 02
        tz b4 = fh b3
        zt q2 01 b4 02
        zt q1 01 32 02
        tz b3 = 01 b3 ht 16 02
        tz b4 = fh b3
        zt q2 01 b4 02
        zt q1 01 32 02
        tz b3 = 01 b3 ht 24 02
        tz b4 = fh b3
        zt q2 01 b4 02
        zt q3 01 02
        b2 = b2 ht 1
     09
    zz 0
 09
