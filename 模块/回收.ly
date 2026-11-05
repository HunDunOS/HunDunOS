00 回收 —— 世代折叠
00 判定极简：索引里有没有。墓碑 = 0xFFFFFFFF
00 触发：一个区「死字节 > 活字节」（过半）
00 折叠：超级块世代 +1，上一代整块作废（O(1)，只改一个数字）

ts gh = 0
ts gc = 0
ts gy = 0
ts gz = 0
ts 墓 = 0xFFFFFFFF
ts 槽值 = 0

00 串口打字符
tt q1 01 02 -> u64  08
    tz d1 = 0
    d1 = 01 gh hs 255 02
    sl 01 0x3F8 02 , d1
    zz 0
 09

00 打十六进制（gz）
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

00 槽是不是墓碑：gz = 槽里的因果，返回 1 是墓碑
tt r1 01 02 -> u64  08
    tz v1 = 0
    v1 = 01 gz hs 墓 02
    lz v1 墓  08
        zz 1
     09
    zz 0
 09

00 该不该整理：gh = 活字节，gc = 死字节，返回 1 该整理
tt r2 01 02 -> u64  08
    tz a1 = 0
    tz a2 = 0
    lz gc 0  08
        zz 0
     09
    a1 = 01 gh hz gc 02
    lz a1 0  08
        zz 0
     09
    a2 = 01 a1 dl 63 02
    lz a2 1  08
        zz 1
     09
    zz 0
 09

00 折叠：超级块世代 +1（gyz = 世代），返回新世代
tt r3 01 02 -> u64  08
    gy = 01 gy ht 1 02
    zz gy
 09

00 测试：三组（活,死）看该不该整理
tt zx 01 argv 02 -> u64  08
    tz i1 = 0

    i1 = 0
    ll  08
        lz i1 4  08 ls  09

        00 活 100 死 200 → 该死（死 > 活）
        lz i1 0  08
            gh = 100
            gc = 200
         09
        00 活 300 死 100 → 不该死
        lz i1 1  08
            gh = 300
            gc = 100
         09
        00 活 100 死 100 → 刚好一半，不该死
        lz i1 2  08
            gh = 100
            gc = 100
         09
        00 活 100 死 0 → 死字节为 0，不该死
        lz i1 3  08
            gh = 100
            gc = 0
         09

        gh = 91
        zt q1 01 02
        gz = gh
        00 打活字节
        gz = gh
        zt q2 01 02
        gh = 47
        zt q1 01 02
        gz = gc
        zt q2 01 02
        gh = 93
        zt q1 01 02

        00 打判定结果
        gh = gc
        gz = gh
        tz a5 = zt r2 01 02
        gh = 01 a5 ht 48 02
        zt q1 01 02
        gh = 10
        zt q1 01 02

        i1 = 01 i1 ht 1 02
     09
    zz 0
 09
