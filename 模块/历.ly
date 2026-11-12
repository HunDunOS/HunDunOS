00 历 —— 公历时间（2026-11-06 起）
00 年 月 日 时 分 秒，全是 u64

ts ni = 2026
ts yu = 11
ts ri = 6
ts shi = 0
ts fen = 0
ts miao = 0
ts gn = 0
ts 串 = 0

00 本月有几天
tt mt 01 02 -> u64  08
    tz m1 = 0
    tz m2 = 0
    m1 = yu
    lz m1 2  08
        m2 = 01 ni hf 4 02
        lz m2 0  08 zz 29 09
        zz 28
     09
    lz m1 4  08 zz 30 09
    lz m1 6  08 zz 30 09
    lz m1 9  08 zz 30 09
    lz m1 11  08 zz 30 09
    zz 31
 09

00 走一秒：秒进分，分进时，时进日，日进月，月进年
tt tk 01 02 -> u64  08
    tz d1 = 0
    tz d2 = 0
    tz d3 = 0
    miao = 01 miao ht 1 02
    lz miao 60  08
        miao = 0
        fen = 01 fen ht 1 02
     09
    lz fen 60  08
        fen = 0
        shi = 01 shi ht 1 02
     09
    lz shi 24  08
        shi = 0
        ri = 01 ri ht 1 02
     09
    d1 = zt mt 01 02
    d2 = 01 d1 ht 1 02
    lz ri d2  08
        ri = 1
        yu = 01 yu ht 1 02
     09
    lh yu 12  08
        yu = 1
        ni = 01 ni ht 1 02
     09
    zz 0
 09

00 打十进制（gn 里的数）
tt pr 01 02 -> u64  08
    tz p1 = 0
    tz p2 = 0
    tz p3 = 0
    p1 = gn
    lz p1 0  08
        sl 01 0x3F8 02 , 48
        zz 0
     09
    p2 = 0
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

00 打两位（不足补 0）
tt p2b 01 02 -> u64  08
    lz gn 10  08
        sl 01 0x3F8 02 , 48
     09
    zt pr 01 02
    zz 0
 09

00 打印 YYYY-MM-DD HH:MM:SS
tt pt 01 02 -> u64  08
    gn = ni
    zt pr 01 02
    sl 01 0x3F8 02 , 45
    gn = yu
    zt p2b 01 02
    sl 01 0x3F8 02 , 45
    gn = ri
    zt p2b 01 02
    sl 01 0x3F8 02 , 32
    gn = shi
    zt p2b 01 02
    sl 01 0x3F8 02 , 58
    gn = fen
    zt p2b 01 02
    sl 01 0x3F8 02 , 58
    gn = miao
    zt p2b 01 02
    sl 01 0x3F8 02 , 10
    zz 0
 09

00 测试：走 3660 秒（1 小时 1 分）
tt zx 01 argv 02 -> u64  08
    tz i1 = 0
    i1 = 0
    ll  08
        lz i1 3660  08 ls  09
        zt tk 01 02
        i1 = 01 i1 ht 1 02
     09
    zt pt 01 02
    ll  08
     09
    zz 0
 09
