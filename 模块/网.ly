00 ========== 网 —— E1000 网卡（最小可验证子集）==========
00 只有 6 件事：找卡 / 复位 / 读MAC / 初始化 / 发帧 / 收帧 / 自环
00 不打印，全部用返回值表达（1=成功 0=失败），调用方自己报

ts 卡基址 = 0
ts 卡在 = 0
ts 卡MAC = 0
ts 发缓基 = 0x60000
ts 收缓基 = 0x70000
ts 帧长 = 0

00 IO 端口读写：卡基址 + 寄存器偏移
tt 卡写 01 reg , val 02 -> u64  08
    tz 口 = 0
    口 = 卡基址 ht reg
    sl 01 口 02 , val
    zz 0
 09

tt 卡读 01 reg 02 -> u64  08
    tz 口 = 0
    口 = 卡基址 ht reg
    zz fl 01 口 02
 09

00 ========== 找卡：PCI 扫描 E1000（8086:100E）==========
00 走 PCI 配置空间 IO 口 0xCF8 / 0xCFC
tt 找卡 01 02 -> u64  08
    tz bus = 0
    00 先用大道存下的地址（XBP 0x540/0x544）
    tz 有 = 0
    tz 址 = 0
    有 = fh 0x0544
    有 = 有 hs 0xFFFFFFFF
    lz 有 1  08
        址 = fh 0x0540
        址 = 址 hs 0xFFFFFFFF
        lz 址 0  08
            卡基址 = 址
            卡在 = 1
            zz 1
         09
     09
    tz dev = 0
    tz cfg = 0
    tz id = 0
    tz bar0 = 0
    卡在 = 0
    bus = 0
    ll  08
        lz bus 256  08 ls  09
        dev = 0
        ll  08
            lz dev 32  08 ls  09
            00 组配置地址：bit31=1, bus<<16, dev<<11, func<<8, reg&0xFC
            cfg = 0x80000000
            cfg = cfg hr 01 bus dh 16 02
            cfg = cfg hr 01 dev dh 11 02
            sl 01 0xCF8 02 , cfg
            id = fl 01 0xCFC 02
            00 厂商 8086，设备 100E
            lz id 0x100E8086  08
                00 读 BAR0（寄存器 4）
                cfg = cfg hr 0x10
                sl 01 0xCF8 02 , cfg
                bar0 = fl 01 0xCFC 02
                bar0 = 01 bar0 hs 0xFFFFFFF0 02
                卡基址 = bar0
                卡在 = 1
                zz 1
             09
            dev = dev ht 1
         09
        bus = bus ht 1
     09
    zz 0
 09

00 ========== 复位 ==========
tt 复位卡 01 02 -> u64  08
    tz n = 0
    zt 卡写 01 0x00 , 0x04000000 02
    n = 0
    ll  08
        lz n 100000  08 ls  09
        n = n ht 1
     09
    zt 卡写 01 0x00 , 0 02
    zz 1
 09

00 ========== 读 MAC（前 6 字节，E1000 的 RAL0/RAH0）==========
tt 读MAC 01 02 -> u64  08
    tz lo = 0
    tz hi = 0
    tz i = 0
    lo = zt 卡读 01 0x5400 02
    hi = zt 卡读 01 0x5404 02
    卡MAC = 0x68000
    i = 0
    ll  08
        lz i 4  08 ls  09
        tz sh1 = 0
        tz b = 0
        sh1 = i dh 3
        b = lo dl sh1
        b = b hs 255
        tz 目 = 0
        目 = 卡MAC ht i
        sh 目 , b
        i = i ht 1
     09
    i = 0
    ll  08
        lz i 2  08 ls  09
        tz sh2 = 0
        tz b2 = 0
        tz 目2 = 0
        sh2 = i dh 3
        b2 = hi dl sh2
        b2 = b2 hs 255
        目2 = 卡MAC ht 4
        目2 = 目2 ht i
        sh 目2 , b2
        i = i ht 1
     09
    zz 1
 09

00 ========== 初始化：开收环 + 设 MAC + 使能 ==========
tt 初始化 01 02 -> u64  08
    00 清掉中断（先不接中断，轮询）
    zt 卡写 01 0x00D0 , 0xFFFFFFFF 02
    00 设 MAC 到 RAL0/RAH0
    tz lo = 0
    tz hi = 0
    tz i = 0
    lo = 0
    hi = 0
    i = 0
    ll  08
        lz i 4  08 ls  09
        tz bt = 0
        tz sh3 = 0
        tz pv = 0
        bt = fh 01 卡MAC ht i 02
        bt = bt hs 255
        sh3 = i dh 3
        pv = bt dl sh3
        lo = lo hr pv
        i = i ht 1
     09
    zt 卡写 01 0x5400 , lo 02
    hi = 0x80000000
    zt 卡写 01 0x5404 , hi 02

    00 允许接收（RCTL：EN + BAM + UPE + MPE + LPE）
    zt 卡写 01 0x0100 , 0x0400801C 02
    00 设 TCTL：EN + PSP + CT=0x10 + COLD=0x40
    zt 卡写 01 0x0400 , 0x0004010A 02
    zt 卡写 01 0x0410 , 0x00000600 02
    zt 卡写 01 0x0420 , 0x00000200 02
    zt 卡写 01 0x0428 , 0x00000000 02
    zt 卡写 01 0x0008 , 0x00000600 02
    zt 卡写 01 0x0010 , 0x00000200 02
    zt 卡写 01 0x0018 , 0x00000000 02
    zt 卡写 01 0x0008 , 0x00000610 02
    zz 1
 09

00 ========== 发一帧：把 发缓基 的 帧长 字节发出去 ==========
00 用最简单的发送描述符（TDBAL/TDLEN 配一次，之后只敲门铃）
tt 发帧 01 02 -> u64  08
    tz lo = 0
    tz hi = 0
    tz n = 0
    lo = 发缓基
    hi = 0
    tz 长2 = 0
    长2 = 帧长 hs 0xFFFF
    帧长 = 长2
    tz 高 = 0
    高 = 帧长 dh 16
    hi = hi hr 长2
    hi = hi hr 高
    00 TDBAL / TDBAH
    zt 卡写 01 0x3800 , lo 02
    zt 卡写 01 0x3804 , 0 02
    00 TDLEN = 1 个描述符 × 16
    zt 卡写 01 0x3808 , 16 02
    00 TDH = 0，TDT = 1（已提交一个）
    zt 卡写 01 0x3810 , 0 02
    zt 卡写 01 0x3818 , 1 02
    n = 0
    ll  08
        lz n 500000  08 ls  09
        n = n ht 1
     09
    zz 1
 09

00 ========== 自环测试：发一个 64 字节的帧，看能不能收到 ==========
00 不依赖外部网络，只验证「发→收」这条路对不对
tt 自环 01 02 -> u64  08
    tz i = 0
    tz v = 0
    tz n = 0
    00 填测试帧：目标广播 FF*6，源是卡MAC，类型 0x88B5（实验用）
    i = 0
    ll  08
        lz i 6  08 ls  09
        sh 01 发缓基 ht i 02 , 0xFF
        i = i ht 1
     09
    i = 0
    ll  08
        lz i 6  08 ls  09
        v = fh 01 卡MAC ht i 02
        sh 01 发缓基 ht 01 6 ht i 02 02 , v
        i = i ht 1
     09
    sh 01 发缓基 ht 12 02 , 0x88
    sh 01 发缓基 ht 13 02 , 0xB5
    00 剩下填充
    i = 14
    ll  08
        lz i 64  08 ls  09
        sh 01 发缓基 ht i 02 , 0x41
        i = i ht 1
     09
    帧长 = 64
    zt 发帧 01 02
    zz 1
 09
