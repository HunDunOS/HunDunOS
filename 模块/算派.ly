00 算派 —— 混沌调度器
00 分派：因果位与，一个 and 就出来
00 时间片：12000μs × φ^级别，定点 16.16 递减（单位用微秒，免得整数截断到 0）
00 仲裁：tick % 就绪数，位图轮转

ts 核数 = 8
ts 就绪 = 0
ts 片基 = 12000

tt 派 01 h0 02 -> u64  08
    zz 01 h0 hs 01 核数 hz 1 02 02
 09

tt 片 01 级 02 -> u64  08
    tz v0 = 片基
    tz i0 = 0
    ll  08
        lz i0 级  08 ls  09
        v0 = 01 01 v0 hh 0x9E38 02 dl 16 02
        i0 = i0 ht 1
     09
    zz v0
 09

tt 数 01 02 -> u64  08
    tz c0 = 0
    tz i0 = 0
    ll  08
        lz i0 64  08 ls  09
        tz b0 = 01 就绪 dl i0 02 hs 1
        lz b0 1  08
            c0 = c0 ht 1
         09
        i0 = i0 ht 1
     09
    zz c0
 09

tt 选 01 钟 02 -> u64  08
    tz n0 = zt 数 01 02
    lz n0 0  08
        zz 0
     09
    tz 目 = 01 01 钟 hf n0 02 ht 1 02
    tz c0 = 0
    tz i0 = 0
    ll  08
        lz i0 64  08 ls  09
        tz b0 = 01 就绪 dl i0 02 hs 1
        lz b0 1  08
            c0 = c0 ht 1
            lz c0 目  08 zz i0 09
         09
        i0 = i0 ht 1
     09
    zz 0
 09

tt 挂 01 i0 02 -> u64  08
    sh 0x680 , 01 就绪 hr 01 1 dh i0 02 02
    zz 0
 09

tt 摘 01 i0 02 -> u64  08
    sh 0x680 , 01 就绪 hs dr 01 1 dh i0 02 02
    zz 0
 09
