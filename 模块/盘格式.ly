00 ============================================================
00 混沌 HDGX 盘格式（盘格式.ly）
00 六爻语言移植版
00 ============================================================

00 ---- 全局变量 ----
ts phc[512] = 0

ts phvb = 0
ts phzs = 0
ts phsy = 0
ts phss = 0
ts phdq = 0
ts phzj = 0
ts phzz = 0
ts 盘轴数 = 0
ts phst = 0
ts phds = 0
ts phsd = 0

ts hq[512] = 0
ts hq址 = 0

00 ============================================================
00 一、扇区内的字节读写
00 ============================================================
tt sz 01 off  v 02 -> u64  08
    st 01 phc ht off 02 = 01 v % 256 02
    zz 0
 09

tt sz32 01 off  v 02 -> u64  08
    zt sz 01 off  01 v % 256 02 02
    zt sz 01 01 off ht 1 02  01 01 v / 256 02 % 256 02 02 02
    zt sz 01 01 off ht 2 02  01 01 v / 65536 02 % 256 02 02 02
    zt sz 01 01 off ht 3 02  01 01 v / 16777216 02 % 256 02 02 02
    zz 0
 09

tt sq32 01 off 02 -> u64  08
    zz 01 01 phc ht off 02 ht 01 phc ht 01 off ht 1 02 ht 256 02 ht 01 phc ht 01 off ht 2 02 ht 65536 02 ht 01 phc ht 01 off ht 3 02 ht 16777216 02 02
 09

tt sjy 01 n 02 -> u64  08
    tz h = 2166136261
    tz i = 0
    ll  08
        lz i n  08 ls  09
        h = 01 h yh 01 phc ht i 02 02
        h = 01 h ht 16777619 02
        i = i ht 1
     09
    zz h
 09

tt 串写扇 01 off  s  n 02 -> u64  08
    tz i = 0
    ll  08
        lz i n  08 ls  09
        tz c = fh 01 s ht i 02
        zt sz 01 01 off ht i 02  c 02
        i = i ht 1
     09
    zz 0
 09

00 ============================================================
00 二、超级块
00 ============================================================
tt 超级块组装 01 02 -> u64  08
    tz i = 0
    ll  08
        lz i 512  08 ls  09
        st 01 phc ht i 02 = 0
        i = i ht 1
     09
    zt sz 01 0  72 02
    zt sz 01 1  68 02
    zt sz 01 2  71 02
    zt sz 01 3  88 02
    zt sz32 01 4  phvb 02
    zt sz32 01 8  512 02
    zt sz32 01 12  phzs 02
    zt sz32 01 16  2 02
    zt sz32 01 20  phsy 02
    zt sz32 01 24  phss 02
    zt sz32 01 28  phdq 02
    zt sz32 01 32  phzj 02
    zt sz32 01 36  phzz 02
    zt sz32 01 40  盘轴数 02
    zt sz32 01 44  phst 02
    zt sz32 01 48  phds 02
    zt sz32 01 52  phsd 02
    zt sz32 01 56  zt sjy 01 56 02 02
    zz 0
 09

tt 超级块写 01 哪块 02 -> u64  08
    zt 超级块组装 01 02
    lz 哪块 0  08
        zz zt pdx 01 0 02
     09
    zz zt pdx 01 1 02
 09

tt 块世代 01 哪块 02 -> u64  08
    lz zt pdd 01 哪块 02 0  08
        zz 0
     09
    lh sq32 01 0 02 0x58474448  08
        zz 0
     09
    tz 存 = sq32 01 56 02
    zt sz32 01 56  0 02
    tz 算 = zt sjy 01 56 02
    zt sz32 01 56  存 02
    lh 算 存  08
        zz 0
     09
    zz sq32 01 52 02
 09

tt 载入字段 01 02 -> u64  08
    phvb = sq32 01 4 02
    phzs = sq32 01 12 02
    phsy = sq32 01 20 02
    phss = sq32 01 24 02
    phdq = sq32 01 28 02
    phzj = sq32 01 32 02
    phzz = sq32 01 36 02
    盘轴数 = sq32 01 40 02
    phst = sq32 01 44 02
    phds = sq32 01 48 02
    phsd = sq32 01 52 02
    zz 1
 09

tt 超级块读 01 02 -> u64  08
    tz ga = zt 块世代 01 0 02
    tz gb = zt 块世代 01 1 02
    lz ga 0  08
        lz gb 0  08
            zz 0
         09
        zt 块世代 01 1 02
        zz zt 载入字段 01 02
     09
    lz gb 0  08
        zt 块世代 01 0 02
        zz zt 载入字段 01 02
     09
    lh gb ga  08
        zt 块世代 01 1 02
        zz zt 载入字段 01 02
     09
    zt 块世代 01 0 02
    zz zt 载入字段 01 02
 09

00 ============================================================
00 三、索引区：哈希 → 扇区号
00 ============================================================
tt syz 01 h 02 -> u64  08
    tz i = 0
    tz 扇 = 0
    ll  08
        lz 扇 16  08 ls  09
        lz zt pdd 01 01 phsy ht 扇 02 02 0  08
            zz 0xFFFFFFFF
         09
        tz j = 0
        ll  08
            lz j 64  08 ls  09
            tz off = 01 j ht 8 02
            lz sq32 01 off 02 h  08
                lh sq32 01 01 off ht 4 02 02 phzj  08
                    lh h 0  08
                        zz sq32 01 01 off ht 4 02 02
                     09
                 09
             09
            j = j ht 1
         09
        扇 = 扇 ht 1
     09
    zz 0xFFFFFFFF
 09

tt 索引加 01 h  lba 02 -> u64  08
    tz 扇 = 0
    ll  08
        lz 扇 16  08 ls  09
        lz zt pdd 01 01 phsy ht 扇 02 02 0  08
            zz 0
         09
        tz j = 0
        ll  08
            lz j 64  08 ls  09
            tz off = 01 j ht 8 02
            lz sq32 01 off 02 0  08
                zt sz32 01 off  h 02
                zt sz32 01 01 off ht 4 02  lba 02
                zt pdx 01 01 phsy ht 扇 02 02
                zz 1
             09
            j = j ht 1
         09
        扇 = 扇 ht 1
     09
    zz 0
 09

00 ============================================================
00 四、对象区：只追加
00 ============================================================
tt 对象写扇 01 内容  长  哈希  类型 02 -> u64  08
    tz i = 0
    ll  08
        lz i 512  08 ls  09
        st 01 phc ht i 02 = 0
        i = i ht 1
     09
    zt sz 01 0  79 02
    zt sz 01 1  66 02
    zt sz 01 2  74 02
    zt sz 01 3  0 02
    zt sz32 01 4  类型 02
    zt sz32 01 8  长 02
    zt sz32 01 12  哈希 02
    zt 串写扇 01 16  内容  长 02
    zt sz32 01 496  zt sjy 01 496 02 02
    zz zt pdx 01 phzj 02
 09

tt 对象读扇 01 lba 02 -> u64  08
    lz zt pdd 01 lba 02 0  08
        zz 0
     09
    lh sq32 01 0 02 0x004A424F  08
        zz 0
     09
    tz 存 = sq32 01 496 02
    zt sz32 01 496  0 02
    lh zt sjy 01 496 02  存  08
        zz 0
     09
    zz 1
 09

tt 对象长 01 02 -> u64  08
    zz sq32 01 8 02
 09

tt 对象哈希 01 02 -> u64  08
    zz sq32 01 12 02
 09

00 ============================================================
00 五、对外：格式化 / 存 / 取 / 列
00 ============================================================
tt 盘格式化 01 总扇 02 -> u64  08
    phvb = 1
    phzs = 总扇
    phsy = 3
    phss = 1024
    phdq = 19
    phzj = 19
    phzz = 4096
    盘轴数 = 0
    phst = 0
    phds = 0
    phsd = 1

    tz s = 0
    ll  08
        lz s 16  08 ls  09
        tz i = 0
        ll  08
            lz i 512  08 ls  09
            st 01 phc ht i 02 = 0
            i = i ht 1
         09
        zt pdx 01 01 phsy ht s 02 02
        s = s ht 1
     09
    zt 超级块写 01 0 02
    zt 超级块写 01 1 02
    zz 1
 09

tt 盘存对象 01 串 02 -> u64  08
    tz h = 2166136261
    tz i = 0
    ll  08
        tz c = fh 01 串 ht i 02
        lz c 0  08 ls  09
        h = 01 h yh c 02
        h = 01 h ht 16777619 02
        i = i ht 1
     09
    lz h 0  08
        zz 0
     09
    tz 老 = zt syz 01 h 02
    lh 老 0xFFFFFFFF  08
        phst = h
        phsd = 01 phsd ht 1 02
        zt 超级块写 01 01 phsd % 2 02 02
        zz h
     09
    tz 长 = i
    lh 长 480  08
        zz 0
     09
    lz zt 对象写扇 01 串  长  h  1 02 0  08
        zz 0
     09
    lz zt 索引加 01 h  phzj 02 0  08
        zz 0
     09
    phzj = 01 phzj ht 1 02
    phds = 01 phds ht 1 02
    phsd = 01 phsd ht 1 02
    盘轴数 = 01 盘轴数 ht 1 02
    phst = h
    lz zt 超级块写 01 01 phsd % 2 02 02 0  08
        zz 0
     09
    zz h
 09

tt 盘取对象 01 h 02 -> u64  08
    tz lba = zt syz 01 h 02
    lz lba 0xFFFFFFFF  08
        zz 0
     09
    lz zt 对象读扇 01 lba 02 0  08
        zz 0
     09
    lh zt 对象哈希 01 02  h  08
        zz 0
     09
    tz n = zt 对象长 01 02
    tz i = 0
    ll  08
        lz i n  08 ls  09
        tz v = 01 phc ht 01 16 ht i 02 02
        st 01 hq址 ht i 02 = v
        i = i ht 1
     09
    st 01 hq址 ht n 02 = 0
    zz n
 09

tt hqy 01 02 -> u64  08
    yc 01 hq址 02
    zz 0
 09

00 ============================================================
00 六、自检
00 ============================================================
tt 盘格式自检 01 02 -> u64  08
    hq址 = dz 01 hq 02
    lz zt 盘就绪吗 01 02 0  08
        y 01 03[HDGX] 没有盘
04 02
        zz 0
     09
    lz zt 超级块读 01 02 1  08
        y 01 03[HDGX] 盘上已有格式：版本 04 02
        y 01 phvb 02
        y 01 03  世代 04 02
        y 01 phsd 02
        y 01 03  对象数 04 02
        y 01 phds 02
        y 01 03  追加指针 LBA 04 02
        y 01 phzj 02
        y 01 03
04 02
        tz h = zt 盘存对象 01 03混沌04 02
        y 01 03[HDGX] 按哈希hq「混沌」→ 「04 02
        lh zt 盘取对象 01 h 02 0  08
            zt hqy 01 02
         09
        y 01 03」
04 02
        tz h2 = zt 盘存对象 01 03一切皆哈希04 02
        y 01 03[HDGX] hq第二个 → 「04 02
        lh zt 盘取对象 01 h2 02 0  08
            zt hqy 01 02
         09
        y 01 03」
04 02
        zz 1
     09
    y 01 03[HDGX] 盘上没有格式 —— 自检不格式化（要重来请用 格式化 命令）
04 02
    zz 0
 09
