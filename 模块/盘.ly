00 ============================================================
00 hd 磁盘模块（盘.ly）—— ATA PIO 驱动
00 
00 ============================================================

00 ---- g_vars ----
ts phc[512] = 0
ts 盘号 = 0
ts pready = 0

00 ---- ATA port ----
00 0x1F0 data  0x1F2 扇区数  0x1F3/4/5 LBA 低中高  0x1F6 驱动器  0x1F7 状态/命令

tt 盘等 01 02 -> u64  08
    tz i = 0
    ll  08
        lz i 1000000  08 ls  09
        tz s = dr 01 0x1F7 02
        lh s 128  08
            lz s 8  08
                zz s
             09
            lz s 1  08
                zz s
             09
         09
        i = i ht 1
     09
    zz 0
 09

tt pready吗 01 02 -> u64  08
    dc 01 0x1F6, 0xA0 02
    dc 01 0x1F2, 0 02
    dc 01 0x1F3, 0 02
    dc 01 0x1F4, 0 02
    dc 01 0x1F5, 0 02
    tz s = dr 01 0x1F7 02
    lz s 0  08
        zz 0
     09
    lz s 0xFF  08
        zz 0
     09
    zz 1
 09

tt pselect 01 lba 02 -> u64  08
    dc 01 0x1F6  0xE0 ht 01 01 lba / 16777216 02 % 16 02 02
    dc 01 0x1F2  1 02
    dc 01 0x1F3  01 lba % 256 02
    dc 01 0x1F4  01 01 lba / 256 02 % 256 02 02
    dc 01 0x1F5  01 01 lba / 65536 02 % 256 02 02
    zz 0
 09

tt pdd 01 lba 02 -> u64  08
    zt pselect 01 lba 02
    dc 01 0x1F7  0x20 02
    tz s = zt 盘等 01 02
    lz s 0  08
        zz 0
     09
    lz 01 s % 2 02 1  08
        zz 0
     09
    tz i = 0
    ll  08
        lz i 256  08 ls  09
        tz w = drz 01 0x1F0 02
        st 01 phc ht i ht 2 02 = 01 w % 256 02
        st 01 phc ht i ht 2 ht 1 02 = 01 w / 256 02
        i = i ht 1
     09
    zz 1
 09

tt pdx 01 lba 02 -> u64  08
    zt pselect 01 lba 02
    dc 01 0x1F7  0x30 02
    tz s = zt 盘等 01 02
    lz s 0  08
        zz 0
     09
    tz i = 0
    ll  08
        lz i 256  08 ls  09
        dcz 01 0x1F0  01 01 phc ht i ht 2 02 ht 01 phc ht i ht 2 ht 1 02 ht 256 02 02 02
        i = i ht 1
     09
    dc 01 0x1F7  0xE7 02
    zt 盘等 01 02
    zz 1
 09

tt phc十六 01 x  y  n  c 02 -> u64  08
    tz i = 0
    ll  08
        lz i n  08 ls  09
        绘十六 01 x  y ht i ht 18  01 01 phc ht i ht 2 02 ht 01 phc ht i ht 2 ht 1 02 ht 256 02 02  c 02
        i = i ht 1
     09
    zz 0
 09

tt 盘自检 01 02 -> u64  08
    lz zt pready吗 01 02 0  08
        y 01 03[盘] 主通道没有 ATA 盘
04 02
        pready = 0
        zz 0
     09
    pready = 1
    y 01 03[盘] ATA 盘在，read LBA 100 …
04 02
    lz zt pdd 01 100 02 0  08
        y 01 03[盘] read取fail
04 02
        zz 0
     09
    y 01 03[盘] 头 8 字节 = 04 02
    tz i = 0
    ll  08
        lz i 8  08 ls  09
        y 01 01 phc ht i 02 02
        y 01 03  04 02
        i = i ht 1
     09
    y 01 03
04 02
    lz phc 0 0  08
        lz phc 1 0  08
            y 01 03[盘] 签名 HDGX 校验通过
04 02
         09
     09
    zz 1
 09
