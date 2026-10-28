00 ============================================================
00 hd pkt模块（pkt.ly）—— read .bao v2
00 
00 ============================================================

00 ---- g_vars ----
ts phc[512] = 0
ts phds = 0
ts phsy = 0
ts phzj = 0
ts pktbuf[16384] = 0
ts pktbuf址 = 0
ts pkt址 = 0
ts pkt起始LBA = 0
ts pkt扇区数 = 0
ts pkt成员数 = 0
ts pkt清单 = 0
ts pktdata = 0
ts pkt长 = 0
ts pkt清单hash = 0
ts pkt世代 = 0
ts pkt能力 = 0
ts view能力[4] = 0

ts 插件名[16] = 0
ts 插件口[16] = 0
ts 插件数 = 0
ts 当前view = 0
ts pkt可执行入口 = 0
ts pkt可执行偏移 = 0
ts pkt可执行长 = 0
ts pkt加载址 = 0
ts pkt装进数 = 0
ts pkt名址 = 0
ts pkt名[128] = 0
ts pkt装[512] = 0
ts pkt装址 = 0

00 ============================================================
00 逐扇区从盘上read到buf
00 ============================================================
tt pkt_read盘 01 lba  扇区数 02 -> u64  08
    tz i = 0
    ll  08
        lz i 扇区数  08 ls  09
        zt pdd 01 01 lba ht i 02 02
        tz j = 0
        ll  08
            lz j 256  08 ls  09
            st 01 pktbuf址 ht i ht 512 ht j ht 2 02 = 01 phc ht j ht 2 02
            st 01 pktbuf址 ht i ht 512 ht j ht 2 ht 1 02 = 01 phc ht j ht 2 ht 1 02
            j = j ht 1
         09
        i = i ht 1
     09
    zz 1
 09

00 ============================================================
00 从buf里按字节取
00 ============================================================
tt pkt取8 01 off 02 -> u64  08
    tz v = fh 01 pkt址 ht off 02
    zz v
 09

tt pkt取32 01 off 02 -> u64  08
    zz 01 01 pkt取8 01 off 02 ht 01 pkt取8 01 off ht 1 02 ht 256 02 ht 01 pkt取8 01 off ht 2 02 ht 65536 02 ht 01 pkt取8 01 off ht 3 02 ht 16777216 02 02
 09

00 ============================================================
00 校验：魔数 + pkt头自校验
00 ============================================================
tt pkt_校验 01 02 -> u64  08
    lh 01 pkt取32 01 0 02 02 0x324F4142  08
        zz 0
     09
    lh pkt取32 01 4 02 2  08
        zz 0
     09
    tz h = 2166136261
    tz i = 0
    ll  08
        lz i 32  08 ls  09
        h = 01 h yh pkt取8 01 i 02 02
        h = 01 h ht 16777619 02
        i = i ht 1
     09
    lh h pkt取32 01 32 02  08
        zz 0
     09
    pkt成员数 = pkt取32 01 8 02
    pkt清单 = 40
    pktdata = 01 pkt址 ht 40 ht pkt取32 01 12 02 02
    pkt长 = pkt取32 01 36 02
    pkt清单hash = pkt取32 01 16 02
    pkt世代 = pkt取32 01 20 02
    pkt能力 = pkt取32 01 28 02
    zz 1
 09

00 ============================================================
00 第 i 个成员的name
00 ============================================================
tt pkt_成员名 01 i  出 02 -> u64  08
    tz o = 01 pkt清单 ht i ht 32 02
    tz noff = pkt取32 01 o ht 4 02
    tz nlen = pkt取32 01 o ht 8 02
    tz j = 0
    ll  08
        lz j nlen  08 ls  09
        tz v = fh 01 pktdata ht noff ht j 02
        st 01 出 ht j 02 = v
        j = j ht 1
     09
    st 01 出 ht nlen 02 = 0
    zz nlen
 09

tt pkt_成员type 01 i 02 -> u64  08
    zz pkt取32 01 01 pkt清单 ht i ht 32 ht 24 02 02
 09

tt pkt_成员长 01 i 02 -> u64  08
    zz pkt取32 01 01 pkt清单 ht i ht 32 ht 16 02 02
 09

tt pkt_成员hash 01 i 02 -> u64  08
    zz pkt取32 01 01 pkt清单 ht i ht 32 ht 12 02 02
 09

tt pkt_能力名 01 v 02 -> u64  08
    lz v 0  08
        pc 01 03data04 02
        zz 0
     09
    lz v 1  08
        pc 01 03可执行04 02
        zz 0
     09
    lz v 2  08
        pc 01 03文档04 02
        zz 0
     09
    lz v 3  08
        pc 01 03字库04 02
        zz 0
     09
    pc 01 03?04 02
    zz 0
 09

00 ============================================================
00 列清单
00 ============================================================
tt pkt_列 01 02 -> u64  08
    pss 01 0x9AC4FF 02
    pc 01 03  pkt里 04 02
    ps 01 pkt成员数 02
    pc 01 03  个成员 · 世代 04 02
    ps 01 pkt世代 02
    pc 01 03 · 清单hash 04 02
    zt 打十六_pkt 01 pkt清单hash 02
    ph 01 02
    tz i = 0
    ll  08
        lz i pkt成员数  08 ls  09
        tz o = 01 pkt清单 ht i ht 32 02
        pss 01 0x6E86A8 02
        pc 01 03    04 02
        ps 01 01 i ht 1 02 02
        pc 01 03. 04 02
        pss 01 0xE8F0FF 02
        zt pkt_成员名 01 i  pkt名址 02
        pc 01 pkt名址 02
        pss 01 0x5F7A9C 02
        pc 01 03  04 02
        zt pkt_能力名 01 zt pkt_成员type 01 i 02 02
        pc 01 03  04 02
        ps 01 zt pkt_成员长 01 i 02 02
        pc 01 03  字节  contenthash 04 02
        zt 打十六_pkt 01 zt pkt_成员hash 01 i 02 02
        lz zt pkt_成员type 01 i 02 1  08
            pc 01 03  入口 0x04 02
            zt 打十六_pkt 01 pkt取32 01 o ht 28 02 02
         09
        ph 01 02
        i = i ht 1
     09
    zz 0
 09

00 ============================================================
00 打十六的小工具
00 ============================================================
tt 打十六_pkt 01 v 02 -> u64  08
    tz i = 0
    ll  08
        tz 移 = 01 01 7 - i 02 ht 4 02
        tz t = 01 01 v / 01 1 ht 移 02 02 % 16 02
        lh t 10  08
            屏出 01 01 48 ht t 02 02
         09
        lz t 10  08
            屏出 01 01 87 ht t 02 02
         09
        i = i ht 1
        lh i 8  08 ls  09
     09
    zz 0
 09

00 ============================================================
00 FNV-1a：namehash
00 ============================================================
tt namehash 01 址 02 -> u64  08
    tz h = 2166136261
    tz i = 0
    ll  08
        tz c = fh 01 址 ht i 02
        lz c 0  08 ls  09
        h = 01 h yh c 02
        h = 01 h ht 16777619 02
        i = i ht 1
     09
    lz h 0  08
        h = 1
     09
    zz h
 09

00 ============================================================
00 按命令名找插件并dy它
00 ============================================================
tt 插件_跑 01 名址  参址 02 -> u64  08
    lz 插件数 0  08
        zz 0
     09
    tz h = zt namehash 01 名址 02
    tz i = 0
    ll  08
        lz i 插件数  08 ls  09
        lz 01 插件名 ht i 02 h  08
            dy 01 01 插件口 ht i 02  0  0  0  参址 02
            zz 1
         09
        i = i ht 1
     09
    zz 0
 09

00 ============================================================
00 列出装进来的手
00 ============================================================
tt 插件_列 01 02 -> u64  08
    lz 插件数 0  08
        zz 0
     09
    pss 01 0x8FA6C8 02
    pc 01 03  装进来的手：04 02
    ps 01 插件数 02
    pc 01 03  只04 02
    ph 01 02
    tz i = 0
    ll  08
        lz i 插件数  08 ls  09
        pc 01 03    0x04 02
        zt 打十六_pkt 01 01 插件名 ht i 02 02
        pc 01 03  →  0x04 02
        zt 打十六_pkt 01 01 插件口 ht i 02 02
        ph 01 02
        i = i ht 1
     09
    zz 0
 09

00 ============================================================
00 装pkt：把每个成员的content当成obj存进obj区
00 ============================================================
tt pkt_装 01 02 -> u64  08
    pkt装进数 = 0
    tz i = 0
    ll  08
        lz i pkt成员数  08 ls  09
        tz o = 01 pkt清单 ht i ht 32 02
        tz off = pkt取32 01 o ht 20 02
        tz ln = pkt取32 01 o ht 16 02
        tz j = 0
        ll  08
            lz j ln  08 ls  09
            tz v = fh 01 pktdata ht off ht j 02
            st 01 pkt装址 ht j 02 = v
            j = j ht 1
         09
        st 01 pkt装址 ht ln 02 = 0
        zt 盘存obj 01 pkt装址 02
        lz zt pkt_成员type 01 i 02 4  08
            lh 插件数 16  08
                zt pkt_成员名 01 i  pkt名址 02
                st 01 插件名 ht 插件数 02 = zt namehash 01 pkt名址 02
                st 01 插件口 ht 插件数 02 = pkt取32 01 o ht 28 02
                插件数 = 01 插件数 ht 1 02
                pss 01 0x37C46A 02
                pc 01 03    ↑ 长出一只手：04 02
                pc 01 pkt名址 02
                ph 01 02
             09
         09
        pkt装进数 = 01 pkt装进数 ht 1 02
        i = i ht 1
     09
    pss 01 0x37C46A 02
    pc 01 03  装pkt完成：04 02
    ps 01 pkt装进数 02
    pc 01 03  个成员，obj区现有 04 02
    ps 01 phds 02
    pc 01 03  个obj04 02
    ph 01 02
    zz 1
 09

00 ============================================================
00 找可执行成员，把code搬到 0x400000
00 ============================================================
tt pkt_跑 01 02 -> u64  08
    tz i = 0
    ll  08
        lz i pkt成员数  08 ls  09
        tz 可装 = 0
        lz zt pkt_成员type 01 i 02 1  08
            可装 = 1
         09
        lz zt pkt_成员type 01 i 02 4  08
            可装 = 1
         09
        lz 可装 1  08
            tz off = pkt取32 01 01 pkt清单 ht i ht 32 ht 20 02 02
            tz ln = pkt取32 01 01 pkt清单 ht i ht 32 ht 16 02 02
            tz ent = pkt取32 01 01 pkt清单 ht i ht 32 ht 28 02 02
            tz k = 0
            ll  08
                lz k 16384  08 ls  09
                st 01 pkt加载址 ht k 02 = 0
                k = k ht 1
             09
            tz j = 0
            ll  08
                lz j ln  08 ls  09
                tz v = fh 01 pktdata ht off ht j 02
                st 01 pkt加载址 ht j 02 = v
                j = j ht 1
             09
            pkt可执行入口 = ent
            pkt可执行偏移 = off
            pkt可执行长 = ln
            pss 01 0x37C46A 02
            pc 01 03  可执行成员 04 02
            ps 01 ln 02
            pc 01 03  字节 → 已搬到 0x04 02
            zt 打十六_pkt 01 pkt加载址 02
            pc 01 03，入口 0x04 02
            zt 打十六_pkt 01 ent 02
            ph 01 02
            zz ent
         09
        i = i ht 1
     09
    zz 0
 09

00 ============================================================
00 从盘上readpkt + 校验 + 列
00 ============================================================
tt pkt_从盘装 01 02 -> u64  08
    pkt加载址 = 0x400000
    pkt名址 = dz 01 pkt名 02
    pkt装址 = dz 01 pkt装 02
    pkt址 = pktbuf址
    pss 01 0x8FA6C8 02
    pc 01 03  从盘上readpkt（LBA 04 02
    ps 01 pkt起始LBA 02
    pc 01 03）…04 02
    ph 01 02
    lz zt pkt_read盘 01 pkt起始LBA  pkt扇区数 02 0  08
        pss 01 0xE0554A 02
        pc 01 03  readpktfail04 02
        ph 01 02
        zz 0
     09
    lz zt pkt_校验 01 02 0  08
        pss 01 0xE0554A 02
        pc 01 03  这不是一个合法的 .bao v2 pkt04 02
        ph 01 02
        zz 0
     09
    lz zt view_给得起 01 pkt能力 02 0  08
        pss 01 0xE0554A 02
        pc 01 03  这个pkt要的能力（0x04 02
        zt 打十六_pkt 01 pkt能力 02
        pc 01 03），当前view只有 0x04 02
        zt 打十六_pkt 01 01 view能力 ht 当前view 02 02
        ph 01 02
        zz 0
     09
    zt pkt_列 01 02
    zt pkt_装 01 02
    zt pkt_跑 01 02
    zz 1
 09

00 ============================================================
00 装pkt + 跑里面的可执行成员
00 ============================================================
tt pkt_装并跑 01 02 -> u64  08
    lz zt pkt_从盘装 01 02 0  08
        zz 0
     09
    tz e = zt pkt_跑 01 02
    lz e 0  08
        pss 01 0xE0554A 02
        pc 01 03  pkt里没有可执行成员04 02
        ph 01 02
        zz 0
     09
    dy 01 e  0  0  屏宽 01 02  屏高 01 02 02
    pss 01 0x37C46A 02
    pc 01 03  程序已exit04 02
    ph 01 02
    zz 1
 09
