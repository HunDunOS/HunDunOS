00 简测 —— 字符台上屏验证
00 清屏 → 写几行字 → 渲染到帧缓冲 → 光标 → 停住

ts gh = 0
ts 串地 = 0

00 写一串 ASCII 到当前光标
tt t1 01 02 -> u64  08
    tz p1 = 0
    tz c1 = 0
    p1 = 串地
    ll  08
        c1 = fh p1
        c1 = 01 c1 hs 255 02
        lz c1 0  08 ls  09
        gh = c1
        zt f8 01 02
        p1 = 01 p1 ht 1 02
     09
    zz 0
 09

tt zx 01 argv 02 -> u64  08
    zt f5 01 02

    串地 = 03CL hundun LL 03
    zt t1 01 02
    gh = 10
    zt f8 01 02

    串地 = 03yin  0x100000 03
    zt t1 01 02
    gh = 10
    zt f8 01 02

    串地 = 03yang 0x200000 03
    zt t1 01 02
    gh = 10
    zt f8 01 02

    串地 = 03he   0x180000 03
    zt t1 01 02
    gh = 10
    zt f8 01 02

    串地 = 03YSK 336 qu 03
    zt t1 01 02
    gh = 10
    zt f8 01 02

    串地 = 03causal address 03
    zt t1 01 02

    zt fi 01 02
    zt fj 01 02

    ll  08
     09
    zz 0
 09
