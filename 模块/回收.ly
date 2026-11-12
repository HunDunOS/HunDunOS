00 回收 —— 世代折叠（完整版）
00
00 区布局（内存模拟，真盘时把基址换成扇区号）：
00   区基 +0    活字节
00   区基 +8    死字节
00   区基 +16   追加指针（已用字节）
00   区基 +24   索引 64 槽 × 8 字节（因果低32 + 偏移）
00   数据从 区基 + 536 起，只追加
00
00 判据：槽里因果 == 0xFFFFFFFF → 墓碑
00 触发：死字节 > 活字节
00 折叠：世代 +1，老一代整块作废（O(1)）

ts gh = 0
ts gc = 0
ts gy = 0
ts gz = 0
ts gw = 0
ts 墓 = 0xFFFFFFFF
ts 槽数 = 64
ts 区基 = 0x80000

00 ========== 串口输出 ==========
tt q1 01 02 -> u64  08
    tz d1 = 0
    d1 = 01 gh hs 255 02
    sl 01 0x3F8 02 , d1
    zz 0
 09

tt q2 01 02 -> u64  08
    tz b1 = 0
    tz b2 = 0
    tz e1 = 0
    tz e2 = 0
    b1 = 01 gz dl 4 02
    b2 = 01 b1 hs 15 02
    lz b2 10  08
        e1 = 01 48 ht b2 02
        gh = e1
        zt q1 01 02
     09
    lh b2 10  08
        e2 = 01 b2 hz 10 02
        e1 = 01 65 ht e2 02
        gh = e1
        zt q1 01 02
     09
    b1 = 01 gz hs 15 02
    lz b1 10  08
        e1 = 01 48 ht b1 02
        gh = e1
        zt q1 01 02
     09
    lh b1 10  08
        e2 = 01 b1 hz 10 02
        e1 = 01 65 ht e2 02
        gh = e1
        zt q1 01 02
     09
    zz 0
 09

00 ========== 区头 ==========
00 取区头字段（gz = 偏移 0/8/16），返回
tt r4 01 02 -> u64  08
    tz f1 = 0
    tz f2 = 0
    f1 = 01 区基 ht gz 02
    f2 = fh f1
    zz f2
 09

00 存区头字段（gz = 偏移，gh = 值）
tt r5 01 02 -> u64  08
    tz f6 = 0
    tz f7 = 0
    f6 = 01 区基 ht gz 02
    f7 = gh
    sh f6 , f7
    zz 0
 09

00 ========== 索引 ==========
00 槽地址（gz = 槽号），返回地址
tt r6 01 02 -> u64  08
    tz f3 = 0
    tz f4 = 0
    tz f5 = 0
    f4 = 01 gz dh 3 02
    f5 = 01 区基 ht 24 02
    f3 = 01 f5 ht f4 02
    zz f3
 09

00 找槽：gz = 因果低32，返回槽号（找不到返回 64）
tt r7 01 02 -> u64  08
    tz g1 = 0
    tz g2 = 0
    tz g3 = 0
    g1 = 0
    ll  08
        lz g1 槽数  08 ls  09
        g2 = zt r6 01 g1 02
        g3 = fh g2
        g3 = 01 g3 hs 0xFFFFFFFF 02
        lz g3 gz  08 zz g1 09
        g1 = 01 g1 ht 1 02
     09
    zz 槽数
 09

00 登记：gz = 因果低32，gh = 偏移，返回槽号（满了返回 64）
tt r8 01 02 -> u64  08
    tz h1 = 0
    tz h2 = 0
    tz h3 = 0
    tz h4 = 0
    h1 = 0
    ll  08
        lz h1 槽数  08 ls  09
        h2 = zt r6 01 h1 02
        h3 = fh h2
        h3 = 01 h3 hs 0xFFFFFFFF 02
        lz h3 墓  08
            h4 = 0xFFFFFFFF
            sh h2 , h4
            zz h1
         09
        h1 = 01 h1 ht 1 02
     09
    zz 槽数
 09

00 立墓碑：gz = 槽号，活-512 死+512
tt r9 01 02 -> u64  08
    tz i1 = 0
    tz i2 = 0
    i1 = zt r6 01 gz 02
    i2 = 0xFFFFFFFF
    sh i1 , i2
    00 更新区头
    gz = 0
    tz 活 = zt r4 01 02
    gz = 8
    tz 死 = zt r4 01 02
    gz = 0
    gh = 01 活 hz 512 02
    zt r5 01 02
    gz = 8
    gh = 01 死 ht 512 02
    zt r5 01 02
    zz 1
 09

00 判墓碑：gz = 槽内容，返回 1 是墓碑
tt ra 01 02 -> u64  08
    tz j1 = 0
    j1 = 01 gz hs 墓 02
    lz j1 墓  08 zz 1 09
    zz 0
 09

00 判该整理：死 > 活？
tt rb 01 02 -> u64  08
    tz k1 = 0
    tz k2 = 0
    tz k3 = 0
    gz = 0
    k1 = zt r4 01 02
    gz = 8
    k2 = zt r4 01 02
    lz k2 0  08 zz 0 09
    k3 = 01 k1 hz k2 02
    lz k3 0  08 zz 0 09
    tz k4 = 01 k3 dl 63 02
    lz k4 1  08 zz 1 09
    zz 0
 09

00 折叠：世代 +1，返回新世代
tt rc 01 02 -> u64  08
    gy = 01 gy ht 1 02
    gh = gy
    zz gy
 09

00 ========== 测试 ==========
tt zx 01 argv 02 -> u64  08
    tz m1 = 0
    tz m2 = 0

    00 初始化区头
    gz = 0
    gh = 0
    zt r5 01 02
    gz = 8
    gh = 0
    zt r5 01 02
    gz = 16
    gh = 0
    zt r5 01 02

    00 登记三个对象：因果 111 222 333
    gz = 111
    gh = 0
    zt r8 01 02
    gz = 222
    gh = 512
    zt r8 01 02
    gz = 333
    gh = 1024
    zt r8 01 02

    00 打：登记了几个槽
    gh = 91
    zt q1 01 02
    gz = 3
    zt q2 01 02
    gh = 93
    zt q1 01 02

    00 找槽：222 应该在第 1 槽
    gz = 222
    m1 = zt r7 01 02
    gh = 91
    zt q1 01 02
    gz = m1
    zt q2 01 02
    gh = 93
    zt q1 01 02

    00 立墓碑：槽 0 死
    gz = 0
    zt r9 01 02

    00 立墓碑：槽 1 死
    gz = 1
    zt r9 01 02

    00 现在 活 512 死 1024 → 该整理（死 > 活）
    gh = 91
    zt q1 01 02
    m2 = zt rb 01 02
    gz = m2
    zt q2 01 02
    gh = 93
    zt q1 01 02

    00 折叠：世代 +1
    tz m3 = zt rc 01 02
    gh = 91
    zt q1 01 02
    gz = m3
    zt q2 01 02
    gh = 93
    zt q1 01 02
    gh = 10
    zt q1 01 02

    ll  08
     09
    zz 0
 09
