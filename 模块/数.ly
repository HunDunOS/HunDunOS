00 数 —— 定点常数与算法（每样都刚刚好）
00 定点格式 Q16.16：低 16 位是小数，高 48 位是整数
00 判据：误差 < 下一个像素 / 下一微秒

ts 定一 = 65536
ts 定PI = 205887

ts ga = 0
ts gb = 0
ts gc = 0

00 定点乘：(a * b) >> 16
tt mc 01 02 -> u64  08
    tz x1 = 0
    tz x2 = 0
    x1 = 01 ga hh gb 02
    x1 = 01 x1 dl 16 02
    zz x1
 09

00 定点除：(a << 16) / b
tt dc 01 02 -> u64  08
    tz x3 = 0
    tz x4 = 0
    x3 = 01 ga dh 16 02
    x3 = 01 x3 hl gb 02
    zz x3
 09

00 整数开方（牛顿迭代）：x = (x + n/x) / 2，从 n 开始收敛
tt sq 01 02 -> u64  08
    tz s1 = 0
    tz s2 = 0
    tz s3 = 0
    tz s4 = 0
    lz ga 0  08 zz 0 09
    lz ga 1  08 zz 1 09
    s1 = ga
    s2 = 0
    ll  08
        s3 = 01 ga hl s1 02
        s4 = 01 s1 ht s3 02
        s4 = 01 s4 hl 2 02
        lz s4 s1  08
            s2 = s1
         09
        lh s4 s1  08
            s1 = s4
         09
        lh s2 0  08 ls  09
     09
    zz s1
 09

00 斐波那契第 n 个
tt fb 01 02 -> u64  08
    tz f1 = 0
    tz f2 = 0
    tz f3 = 0
    tz f4 = 0
    lz ga 0  08 zz 0 09
    lz ga 1  08 zz 1 09
    f1 = 0
    f2 = 1
    f3 = 0
    ll  08
        lz f3 ga  08 ls  09
        f4 = 01 f1 ht f2 02
        f1 = f2
        f2 = f4
        f3 = 01 f3 ht 1 02
     09
    zz f1
 09

00 打十进制（gc 里的数）
tt pr 01 02 -> u64  08
    tz p1 = 0
    tz p2 = 0
    tz p3 = 0
    p1 = gc
    p2 = 0
    lz p1 0  08
        sl 01 0x3F8 02 , 48
        zz 0
     09
    ll  08
        lz p1 0  08 ls  09
        p3 = 01 p1 hf 10 02
        p3 = 01 p3 ht 48 02
        sh 01 0x30000 ht p2 02 , p3
        p1 = 01 p1 hl 10 02
        p2 = 01 p2 ht 1 02
     09
    ll  08
        lz p2 0  08 ls  09
        p2 = 01 p2 hz 1 02
        p1 = fh 01 0x30000 ht p2 02
        sl 01 0x3F8 02 , p1
     09
    zz 0
 09

tt 空 01 02 -> u64  08
    sl 01 0x3F8 02 , 32
    zz 0
 09

00 测试：开方、斐波那契、定点乘、定点除
tt ze 01 argv 02 -> u64  08
    tz t1 = 0
    00 开方 144 = 12
    ga = 144
    t1 = zt sq 01 02
    gc = t1
    zt pr 01 02
    zt 空 01 02
    00 开方 1000 = 31
    ga = 1000
    t1 = zt sq 01 02
    gc = t1
    zt pr 01 02
    zt 空 01 02
    00 斐波那契第 20 = 6765
    ga = 20
    t1 = zt fb 01 02
    gc = t1
    zt pr 01 02
    zt 空 01 02
    00 π 定点转十进制：205887 / 65536 = 3
    gc = 01 定PI hl 定一 02
    zt pr 01 02
    zt 空 01 02
    00 1.5 × 2.0 = 3.0（Q16.16）
    ga = 98304
    gb = 131072
    t1 = zt mc 01 02
    gc = 01 t1 hl 定一 02
    zt pr 01 02
    zt 空 01 02
    ll  08
     09
    zz 0
 09
