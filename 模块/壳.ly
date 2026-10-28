00 ============================================================
00 hd 终端shell（shell.ly）—— 纯文本模式的命令行
00 
00 ============================================================

00 ---- g_vars ----
ts 行buf[136] = 0

ts pkt起始LBA = 0
ts 工具LBA = 0
ts 盘状态 = 0
ts 当前view = 0
ts objhash[16] = 0
ts pkt扇区数 = 0
ts pkt成员数 = 0
ts pkt清单 = 0
ts pktdata = 0
ts pkt长 = 0
ts pktbuf[8192] = 0
ts pktbuf址 = 0

ts 卡基址 = 0
ts 卡在 = 0
ts 卡MAC[6] = 0
ts pkt址 = 0
ts pkt可执行入口 = 0
ts pkt可执行偏移 = 0
ts pkt可执行长 = 0
ts pkt加载址 = 0
ts 行长 = 0
ts 词[136] = 0
ts 词址 = 0
ts 参址 = 0

ts hq[512] = 0
ts hq址 = 0

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

ts machine缓[256] = 0
ts machine缓2[256] = 0
ts machine缓址 = 0
ts machine缓2址 = 0
ts gpu厂商号 = 0
ts gpu设备号 = 0
ts gpu总线 = 0

ts 光x = 0
ts 光y = 0
ts 史书字[5200] = 0
ts 史书色[5200] = 0
ts 史书行数 = 0
ts 史书顶 = 0
ts 史书列 = 0
ts 史书暂[400] = 0
ts 史书暂址 = 0

ts 区x = 0
ts 区y = 0
ts 区宽 = 0
ts 区高 = 0
ts 当前色 = 0
ts seg缓[640] = 0
ts seg址 = 0

00 ============================================================
00 文宽2(s)
00 ============================================================
tt 文宽2 01 s 02 -> u64  08
    tz n = 0
    tz i = 0
    ll  08
        tz c = fh 01 s ht i 02
        lz c 0  08 ls  09
        lh c 128  08
            n = 01 n ht 8 02
         09
        lz c 128  08
            n = 01 n ht 16 02
         09
        i = i ht 1
     09
    zz n
 09

00 ============================================================
00 身份符号
00 ============================================================
ts 身份 = 0

tt 身份行 01 02 -> u64  08
    lz 身份 1  08
        pc 01 03 hundun♂GNY04 02
        zz 0
     09
    pc 01 03 hundun♀04 02
    zz 0
 09

tt pss 01 c 02 -> u64  08
    当前色 = c
    zz 0
 09

ts 标x = 0
ts valx = 0
ts 行y = 0

tt 行进 01 02 -> u64  08
    行y = 01 行y ht 22 02
    光y = 行y
    光x = valx
    zz 0
 09

tt 终端信息行 01 名  val  色 02 -> u64  08
    光x = valx
    光y = 行y
    pss 01 0x6E86A8 02
    pc 01 名 02
    光x = 01 valx ht 96 02
    pss 01 色 02
    pc 01 val 02
    光x = 01 valx ht 96 02
    zt 行进 01 02
    zz 0
 09

00 ============================================================
00 hd标志
00 ============================================================
ts 标志x = 0
ts 标志y = 0
ts 行高 = 0

tt 标志行 01 串  色 02 -> u64  08
    pss 01 色 02
    光x = 标志x
    光y = 标志y
    pc 01 串 02
    标志y = 01 标志y ht 行高 02
    zz 0
 09

tt machine标志 01 02 -> u64  08
    标志x = 01 区x ht 14 02
    标志y = 01 区y ht 26 02
    行高 = 22
    zt 标志行 01 03       ░░░░░04  0x2E4A6E 02
    zt 标志行 01 03     ░▒▒▒▒▒▒▒░04  0x3A5C86 02
    zt 标志行 01 03    ░▒▓▓▓▓▓▓▓▒░04  0x4C8DFF 02
    zt 标志行 01 03   ░▒▓███████▓▒░04  0x6FA8FF 02
    zt 标志行 01 03   ░▒▓█▒▒▒▒▒█▓▒░04  0x9AC4FF 02
    zt 标志行 01 03   ░▒▓█▓███▒█▓▒░04  0xC8DEFF 02
    zt 标志行 01 03   ░▒▓███████▓▒░04  0x6FA8FF 02
    zt 标志行 01 03    ░▒▓▓▓▓▓▓▓▒░04  0x4C8DFF 02
    zt 标志行 01 03     ░▒▒▒▒▒▒▒░04  0x3A5C86 02
    zt 标志行 01 03       ░░░░░04  0x2E4A6E 02
    zz 0
 09

00 ============================================================
00 设区 / 清屏
00 ============================================================
tt 设区 01 x  y  w  h 02 -> u64  08
    区x = x
    区y = y
    区宽 = w
    区高 = h
    zz 0
 09

tt 区内清 01 02 -> u64  08
    lz 区宽 0  08
        绘块 01 0  0  屏宽 01 02  屏高 01 02  0x0A0E18 02
        zz 0
     09
    绘块 01 区x  区y  区宽  区高  0x0A0E18 02
    zz 0
 09

tt 屏清 01 02 -> u64  08
    lz 区宽 0  08
        绘块 01 0  0  屏宽 01 02  屏高 01 02  0x0A0E18 02
        绘块 01 0  0  屏宽 01 02  3  0x1E9E8A 02
        光x = 14
        光y = 14
        zz 0
     09
    绘块 01 区x  区y  区宽  区高  0x0A0E18 02
    zt 史书_清 01 02
    光x = 01 区x ht 8 02
    光y = 01 区y ht 8 02
    zz 0
 09

tt ph 01 02 -> u64  08
    出 01 10 02
    lz 区宽 0  08
        光x = 14
        光y = 01 光y ht 22 02
        lh 光y 01 01 屏高 01 02 - 30 02  08
            滚屏 01 22  0x0A0E18 02
            光y = 01 光y - 22 02
         09
        zz 0
     09
    tz 旧顶 = 史书顶
    zt 史书_换 01 02
    lh 史书顶 旧顶  08
        zt 史书_画 01 02
        zz 0
     09
    光x = 01 区x ht 8 02
    光y = 01 01 区y ht 8 02 ht 01 01 史书行数 - 史书顶 02 ht 22 02 02 02
    zz 0
 09

tt 屏出 01 c 02 -> u64  08
    lz c 10  08
        zt ph 01 02
        zz 0
     09
    lz c 8  08
        lh 光x 14  08
            光x = 01 光x - 8 02
            绘块 01 光x  光y  8  18  0x0A0E18 02
         09
        zz 0
     09
    lh c 32  08
        出 01 c 02
     09
    lz c 13  08
        zz 0
     09
    lh c 32  08
        zz 0
     09
    lh c 128  08
        zz 0
     09
    st 01 seg址 ht 0 02 = c
    st 01 seg址 ht 1 02 = 0
    绘字 01 光x  光y  seg址  当前色 02
    zt 史书_write字 01 c 02
    光x = 01 光x ht 8 02
    lz 区宽 0  08
        lh 光x 01 01 屏宽 01 02 - 24 02  08
            zt ph 01 02
         09
     09
    lz 区宽 0  08 ls  09
    lh 光x 01 01 区x ht 区宽 02 - 16 02  08
        zt ph 01 02
     09
    zz 0
 09

tt pc 01 s 02 -> u64  08
    yc 01 s 02
    tz i = 0
    ll  08
        tz c = fh 01 s ht i 02
        lz c 0  08
            zz 0
         09
        tz j = 0
        ll  08
            tz d = fh 01 s ht 01 i ht j 02 02
            lz d 0  08 ls  09
            lz d 10  08 ls  09
            st 01 seg址 ht j 02 = d
            j = j ht 1
         09
        st 01 seg址 ht j 02 = 0
        lh j 0  08
            绘字 01 光x  光y  seg址  当前色 02
            zt 史书_write串 01 seg址 02
            光x = 01 光x ht zt 文宽2 01 seg址 02 02
         09
        i = 01 i ht j 02
        tz e = fh 01 s ht i 02
        lz e 10  08
            zt ph 01 02
            i = i ht 1
         09
        lz e 0  08
            zz 0
         09
        lz 区宽 0  08
            lh 光x 01 01 屏宽 01 02 - 24 02  08
                zt ph 01 02
             09
         09
        lz 区宽 0  08 ls  09
        lh 光x 01 01 区x ht 区宽 02 - 16 02  08
            zt ph 01 02
         09
     09
    zz 0
 09

tt ps 01 n 02 -> u64  08
    tz 十 = 0
    tz t = n
    ll  08
        十 = 01 十 ht 1 02
        t = 01 t / 10 02
        lz t 0  08 ls  09
     09
    tz i = 0
    tz 权 = 1
    ll  08
        lz i 01 十 - 1 02  08 ls  09
        权 = 01 权 ht 10 02
        i = i ht 1
     09
    ll  08
        zt 屏出 01 01 48 ht 01 01 n / 权 02 % 10 02 02 02
        权 = 01 权 / 10 02
        lz 权 0  08 ls  09
     09
    zz 0
 09

00 ============================================================
00 基础func
00 ============================================================
tt 换行 01 02 -> u64  08
    zt ph 01 02
    zz 0
 09

tt yc2 01 s 02 -> u64  08
    zt pc 01 s 02
    zz 0
 09

tt cl2 01 s 02 -> u64  08
    tz i = 0
    ll  08
        tz c = fh 01 s ht i 02
        lz c 0  08 ls  09
        i = i ht 1
     09
    zz i
 09

tt 串等2 01 a  b 02 -> u64  08
    tz i = 0
    ll  08
        tz x = fh 01 a ht i 02
        tz y = fh 01 b ht i 02
        lh x y  08
            zz 0
         09
        lz x 0  08
            zz 1
         09
        i = i ht 1
     09
    zz 0
 09

tt 十六val 01 c 02 -> u64  08
    tz r = 99
    lh c 48  08
        lh c 57  08
            r = 01 c - 48 02
         09
     09
    lh c 97  08
        lh c 102  08
            r = 01 c - 87 02
         09
     09
    lh c 65  08
        lh c 70  08
            r = 01 c - 55 02
         09
     09
    zz r
 09

tt 串转数 01 s 02 -> u64  08
    tz n = 0
    tz i = 0
    tz c0 = fh 01 s ht 0 02
    tz c1 = fh 01 s ht 1 02
    lz c0 48  08
        lz c1 120  08
            i = 2
            ll  08
                tz hc = fh 01 s ht i 02
                tz v = zt 十六val 01 hc 02
                lh v 15  08 ls  09
                n = 01 01 n ht 16 02 ht v 02
                i = i ht 1
             09
            zz n
         09
     09
    ll  08
        tz c = fh 01 s ht i 02
        lh c 48  08 ls  09
        lh c 57  08 ls  09
        n = 01 01 n ht 10 02 ht 01 c - 48 02 02
        i = i ht 1
     09
    zz n
 09

00 ============================================================
00 read一行
00 ============================================================
ts 光位 = 0
ts 行首y = 0
ts 行首x = 0

tt 重画行 01 02 -> u64  08
    光x = 行首x
    光y = 行首y
    tz i = 0
    ll  08
        lz i 行长  08 ls  09
        zt 屏出 01 01 行buf ht i 02 02
        i = i ht 1
     09
    tz j = 0
    ll  08
        lz j 10  08 ls  09
        zt 屏出 01 32 02
        j = j ht 1
     09
    光x = 01 行首x ht 01 光位 ht 8 02 02
    光y = 行首y
    zz 0
 09

tt 行插 01 c 02 -> u64  08
    lh 行长 130  08
        zz 0
     09
    tz j = 行长
    ll  08
        lh j 光位  08 ls  09
        st 01 行buf ht j 02 = 01 行buf ht 01 j - 1 02 02
        j = 01 j - 1 02
     09
    st 01 行buf ht 光位 02 = c
    行长 = 01 行长 ht 1 02
    光位 = 01 光位 ht 1 02
    zz 0
 09

tt 行删位 01 02 -> u64  08
    lh 光位 行长  08 ls  09
    tz i = 光位
    ll  08
        lz i 01 行长 - 1 02  08 ls  09
        st 01 行buf ht i 02 = 01 行buf ht 01 i ht 1 02 02
        i = i ht 1
     09
    行长 = 01 行长 - 1 02
    zz 0
 09

tt 行删前 01 02 -> u64  08
    lz 光位 0  08
        zz 0
     09
    tz i = 01 光位 - 1 02
    ll  08
        lz i 01 行长 - 1 02  08 ls  09
        st 01 行buf ht i 02 = 01 行buf ht 01 i ht 1 02 02
        i = i ht 1
     09
    行长 = 01 行长 - 1 02
    光位 = 01 光位 - 1 02
    zz 0
 09

tt read行 01 02 -> u64  08
    行长 = 0
    光位 = 0
    行首y = 光y
    ll  08
        tz k = 键 01 02
        lz k 0  08
            睡 01 8 02
            lx
         09
        lz k 13  08 ls  09
        lz k 8  08
            zt 行删前 01 02
            zt 重画行 01 02
            lx
         09
        lz k 19  08
            lh 光位 0  08
                光位 = 01 光位 - 1 02
                zt 重画行 01 02
             09
            lx
         09
        lz k 20  08
            lh 光位 行长  08
                光位 = 01 光位 ht 1 02
                zt 重画行 01 02
             09
            lx
         09
        lz k 6  08
            光位 = 行长
            zt 重画行 01 02
            lx
         09
        lz k 21  08
            光位 = 0
            zt 重画行 01 02
            lx
         09
        lh k 32  08
            zt 行插 01 k 02
            zt 重画行 01 02
         09
     09
    st 01 行buf ht 行长 02 = 0
    zt 换行 01 02
    zz 行长
 09

00 ============================================================
00 min词
00 ============================================================
tt min词 01 02 -> u64  08
    tz i = 0
    tz n = 0
    ll  08
        lz 01 行buf ht i 02 0  08 ls  09
        lh 01 行buf ht i 02 32  08 ls  09
        i = i ht 1
     09
    ll  08
        lz 01 行buf ht i 02 0  08 ls  09
        lz 01 行buf ht i 02 32  08 ls  09
        tz c = 01 行buf ht i 02
        st 01 词址 ht n 02 = c
        n = n ht 1
        i = i ht 1
     09
    st 01 词址 ht n 02 = 0
    ll  08
        lz 01 行buf ht i 02 0  08 ls  09
        lh 01 行buf ht i 02 32  08 ls  09
        i = i ht 1
     09
    tz j = 0
    ll  08
        lz 01 行buf ht i 02 0  08 ls  09
        tz c2 = 01 行buf ht i 02
        st 01 参址 ht j 02 = c2
        j = j ht 1
        i = i ht 1
     09
    st 01 参址 ht j 02 = 0
    zz 0
 09

00 ============================================================
00 打十六
00 ============================================================
tt 打十六 01 v 02 -> u64  08
    tz i = 0
    ll  08
        tz 移 = 01 01 7 - i 02 ht 4 02
        tz t = 01 01 01 v / 01 01 1 ht 移 02 02 02 % 16 02
        lh t 10  08
            zt 屏出 01 01 48 ht t 02 02
         09
        lz t 10  08
            zt 屏出 01 01 87 ht t 02 02
         09
        i = i ht 1
        lh i 8  08 ls  09
     09
    zz 0
 09

00 ============================================================
00 列obj
00 ============================================================
tt 列obj 01 02 -> u64  08
    tz 扇 = 0
    tz 数 = 0
    ll  08
        lz 扇 16  08 ls  09
        lz zt pdd 01 01 phsy ht 扇 02 02 0  08 ls  09
        tz j = 0
        ll  08
            lz j 64  08 ls  09
            tz off = 01 j ht 8 02
            tz h = 01 01 01 01 phc ht off 02 ht 01 phc ht 01 off ht 1 02 02 ht 256 02 ht 01 phc ht 01 off ht 2 02 02 ht 65536 02 ht 01 phc ht 01 off ht 3 02 02 ht 16777216 02 02 02 02
            lh h 0  08
                tz lba = 01 01 01 01 phc ht 01 off ht 4 02 02 ht 01 phc ht 01 off ht 5 02 02 ht 256 02 ht 01 phc ht 01 off ht 6 02 02 ht 65536 02 ht 01 phc ht 01 off ht 7 02 02 ht 16777216 02 02 02 02
                pc 01 03   04 02
                zt 打十六 01 h 02
                pc 01 03    扇区 04 02
                ps 01 lba 02
                pc 01 03    content「04 02
                lh zt 盘取obj 01 h 02 0  08
                    pc 01 hq址 02
                 09
                pc 01 03 」04 02
                zt 换行 01 02
                数 = 01 数 ht 1 02
                zt pdd 01 01 phsy ht 扇 02 02
             09
            j = j ht 1
         09
        扇 = 01 扇 ht 1 02
     09
    lz 数 0  08
        pc 01 03  （盘上还没有obj）04 02
        zt 换行 01 02
     09
    pc 01 03   共 04 02
    ps 01 数 02
    pc 01 03  个obj04 02
    zt 换行 01 02
    zz 数
 09

00 ============================================================
00 帮助
00 ============================================================
tt 帮助 01 02 -> u64  08
    pc 01 03   hd HunDun — kernel能力终端04 02
    zt 换行 01 02
    pc 01 03   ------------------------------------------04 02
    zt 换行 01 02
    pc 01 03   xin         看这台machine的信息（真去问hw）04 02
    zt 换行 01 02
    pc 01 03   wang        nic自检（找 NE2000、read MAC）04 02
    zt 换行 01 02
    pc 01 03   zhuang      把 .bao pkt装进obj区（kernel装pkt）04 02
    zt 换行 01 02
    pc 01 03   bianji      装pkt并进editor（跑pkt里的code）04 02
    zt 换行 01 02
    pc 01 03   gongju      跑 C 工具pkt（任何语言的工具，只要能编成 .bao）04 02
    zt 换行 01 02
    pc 01 03   cun content    存obj（content寻址）→ 打yhash04 02
    zt 换行 01 02
    pc 01 03   qu hash     按hashhq04 02
    zt 换行 01 02
    pc 01 03   lie         列出盘上所有obj04 02
    zt 换行 01 02
    pc 01 03   pan         盘状态04 02
    zt 换行 01 02
    pc 01 03   shi         存一seg中文示例04 02
    zt 换行 01 02
    pc 01 03   bang        这份帮助04 02
    zt 换行 01 02
    pc 01 03   qing        清屏04 02
    zt 换行 01 02
    pc 01 03   guan        停机04 02
    zt 换行 01 02
    zt 换行 01 02
    pc 01 03   提示：同样的content存两次，hash一样，盘上只占一份。04 02
    zt 换行 01 02
    pc 01 03         关掉再开，东西还在 —— 因为它在盘上。04 02
    zt 换行 01 02
    zz 0
 09

00 ============================================================
00 执行命令
00 ============================================================
tt 执行 01 02 -> u64  08
    tz hh = 0
    lz zt 命令是 01 03 cun04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        tz 长 = zt cl2 01 参址 02
        lz 长 0  08
            pc 01 03   用法：cun content04 02
            zt 换行 01 02
            zz 0
         09
        hh = zt 盘存obj 01 参址 02
        lz hh 0  08
            pc 01 03   存fail04 02
            zt 换行 01 02
            zz 0
         09
        pc 01 03   已存 → hash 0x04 02
        zt 打十六 01 hh 02
        zt 换行 01 02
        zt view_加映射 01 参址  hh 02
        pc 01 03   并在这个view里起名「04 02
        pc 01 参址 02
        pc 01 03 」04 02
        zt 换行 01 02
        zz 0
     09
    lz zt 命令是 01 03 qu04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        hh = zt 串转数 01 参址 02
        lz zt 盘取obj 01 hh 02 0  08
            pc 01 03   取不到：盘上没有这个hash04 02
            zt 换行 01 02
            zz 0
         09
        pc 01 03  「04 02
        pc 01 hq址 02
        pc 01 03 」04 02
        zt 换行 01 02
        zz 0
     09
    lz zt 命令是 01 03 liepan04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        zt 列obj 01 02
        zz 0
     09
    lz zt 命令是 01 03 format04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        pss 01 0xE0554A 02
        pc 01 03   format：盘上现有 04 02
        ps 01 phds 02
        pc 01 03  个obj，全部清掉04 02
        zt 换行 01 02
        zt 盘format 01 16384 02
        zt 超级块read 01 02
        盘状态 = 1
        pss 01 0x37C46A 02
        pc 01 03   已重新format04 02
        zt 换行 01 02
        zz 0
     09
    lz zt 命令是 01 03 pan04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        lz zt 超级块read 01 02 0  08
            pc 01 03   盘上没有格式04 02
            zt 换行 01 02
            zz 0
         09
        pc 01 03   格式版本 04 02
        ps 01 phvb 02
        pc 01 03    世代 04 02
        ps 01 phsd 02
        zt 换行 01 02
        pc 01 03   obj数 04 02
        ps 01 phds 02
        pc 01 03    追加ptr LBA 04 02
        ps 01 phzj 02
        pc 01 03    索引起 LBA 04 02
        ps 01 phsy 02
        zt 换行 01 02
        zz 0
     09
    lz zt 命令是 01 03 shi04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        tz a = zt 盘存obj 01 03 hd04 02
        tz b = zt 盘存obj 01 03 一切皆hash04 02
        tz c = zt 盘存obj 01 03 hd04 02
        pc 01 03   存入「hd」→ 04 02
        zt 打十六 01 a 02
        zt 换行 01 02
        pc 01 03   存入「一切皆hash」→ 04 02
        zt 打十六 01 b 02
        zt 换行 01 02
        pc 01 03   再存一次「hd」→ 04 02
        zt 打十六 01 c 02
        lz c a  08
            pc 01 03    （同一个hash，盘上只占一份）04 02
         09
        zt 换行 01 02
        zz 0
     09
    lz zt 命令是 01 03 xin04 02 1  08
        zt 显示machine信息 01 02
        zz 0
     09
    lz zt 命令是 01 03 wang04 02 1  08
        zt nic_自检 01 02
        zz 0
     09
    lz zt 命令是 01 03 ping04 02 1  08
        zt nic_PING 01 参址 02
        zz 0
     09
    lz zt 命令是 01 03 wen04 02 1  08
        zt nic_问 01 10  0  2  2 02
        zz 0
     09
    lz zt 命令是 01 03 lie04 02 1  08
        zt view_列映射 01 02
        zz 0
     09
    lz zt 命令是 01 03 qie04 02 1  08
        zt view_切换名 01 参址 02
        zt 换行 01 02
        zt 提示符 01 02
        zz 0
     09
    lz zt 命令是 01 03 fen04 02 1  08
        zt view_签发 01 参址  7 02
        zt 换行 01 02
        zt 提示符 01 02
        zz 0
     09
    lz zt 命令是 01 03 shui04 02 1  08
        zt view_自检 01 02
        zz 0
     09
    lz zt 命令是 01 03 zhuang04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        tz 哪 = zt 串转数 01 参址 02
        lh 哪 0  08
            pkt起始LBA = 哪
         09
        zt pkt_从盘装 01 02
        zz 0
     09
    lz zt 命令是 01 03 shou04 02 1  08
        zt 插件_列 01 02
        zz 0
     09
    lz zt 命令是 01 03 bianji04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        zt pkt_装并跑 01 02
        zz 0
     09
    lz zt 命令是 01 03 gongju04 02 1  08
        lz zt view_要能力 01 8 02 0  08
            zz 0
         09
        pss 01 0x9AC4FF 02
        pc 01 03   跑 C 工具pkt（LBA 04 02
        ps 01 工具LBA 02
        pc 01 03 ）04 02
        zt 换行 01 02
        tz 旧 = pkt起始LBA
        pkt起始LBA = 工具LBA
        zt pkt_装并跑 01 02
        pkt起始LBA = 旧
        zz 0
     09
    lz zt 命令是 01 03 bang04 02 1  08
        zt 帮助 01 02
        zz 0
     09
    lz zt 命令是 01 03 qing04 02 1  08
        zt 屏清 01 02
        zz 0
     09
    lz zt 命令是 01 03 guan04 02 1  08
        pc 01 03   再见。04 02
        zt 换行 01 02
        停机 01 02
        zz 0
     09
    lz zt 命令是 01 03 shang04 02 1  08
        zt 史书_上 01 02
        zz 0
     09
    lz zt 命令是 01 03 xia04 02 1  08
        zt 史书_下 01 02
        zz 0
     09
    lz zt 插件_跑 01 词址  参址 02 1  08
        zz 0
     09
    pc 01 03   不认识的命令：04 02
    pc 01 词址 02
    zt 换行 01 02
    pc 01 03   input bang 看帮助04 02
    zt 换行 01 02
    zz 0
 09

00 ============================================================
00 显示machine信息（fastfetch）
00 ============================================================
tt 显示machine信息 01 02 -> u64  08
    zt 屏清 01 02
    标x = 01 区x ht 14 02
    valx = 01 区x ht 130 02
    行y = 01 区y ht 20 02
    zt machine标志 01 02

    光x = valx
    光y = 行y
    pss 01 0x37C46A 02
    zt 身份行 01 02
    zt 行进 01 02
    pss 01 0x2A3A5C 02
    光x = valx
    pc 01 03 -----------------------04 02
    zt 行进 01 02

    zt 终端信息行 01 03 sys04  03 hd HunDun OS04  0x9AC4FF 02
    zt 终端信息行 01 03 kernel04  03 自研boot器 xboot + 新语kernel04  0x9AC4FF 02
    zt 终端信息行 01 03 语言04  03 六爻（关键字全拼音，危险操作要 wx{}）04  0x9AC4FF 02

    lh zt machine_BIOS厂商 01 machine缓2址 02 0  08
        zt 终端信息行 01 03 固件04  machine缓2址  0x8FA6C8 02
     09

    zt machine_CPU型号 01 machine缓址 02
    zt machine_CPU厂商 01 machine缓2址 02
    zt 终端信息行 01 03 处理器04  machine缓址  0x37C46A 02
    光x = 01 valx ht 96 02
    光y = 行y
    pss 01 0x5F7A9C 02
    pc 01 machine缓2址 02
    pc 01 03  · 04 02
    tz 核 = zt machine_核数 01 02
    lz 核 0  08
        核 = zt machine_CPU核数 01 02
     09
    lz 核 0  08
        核 = 1
     09
    ps 01 核 02
    pc 01 03  核04 02
    zt 行进 01 02

    zt machine_gpu名 01 machine缓址 02
    zt 终端信息行 01 03 gpu04  machine缓址  0x9B5CF6 02

    machine清 01 machine缓址  32 02
    光x = valx
    光y = 行y
    pss 01 0x6E86A8 02
    pc 01 03 mem04 02
    光x = 01 valx ht 96 02
    pss 01 0x00BFA5 02
    ps 01 01 mem 01 02 / 1024 02 02
    pc 01 03  MB04 02
    zt 行进 01 02

    光x = valx
    光y = 行y
    pss 01 0x6E86A8 02
    pc 01 03 显示04 02
    光x = 01 valx ht 96 02
    pss 01 0x4C8DFF 02
    ps 01 屏宽 01 02 02
    pc 01 03  x 04 02
    ps 01 屏高 01 02 02
    pc 01 03  x 32 位　framebuf 0x04 02
    zt 打十六 01 frame址 01 02 02
    zt 行进 01 02

    lz zt 超级块read 01 02 1  08
        光x = valx
        光y = 行y
        pss 01 0x6E86A8 02
        pc 01 03 盘04 02
        光x = 01 valx ht 96 02
        pss 01 0xF2A93B 02
        pc 01 03 hd盘 v04 02
        ps 01 phvb 02
        pc 01 03 　04 02
        ps 01 01 phzs / 2048 02 02
        pc 01 03  MB　04 02
        ps 01 phds 02
        pc 01 03  个obj04 02
        zt 行进 01 02
     09

    zt 终端信息行 01 03 net04  03 （还没有netstack，所以没有 IP）04  0x7A5F5F 02
    光x = 01 valx ht 96 02
    光y = 行y
    pss 01 0xE0554A 02

    光x = 01 valx ht 96 02
    光y = 行y
    pss 01 0xE0554A 02

    光x = valx
    光y = 01 行y ht 22 02
    pss 01 0x3A4A66 02
    pc 01 03 一切皆hash · content寻址 · 只追加04 02
    zt 行进 01 02
    zt 行进 01 02
    光x = 14
    光y = 行y
    zz 0
 09

tt 命令是 01 s 02 -> u64  08
    zz zt 串等2 01 词址  s 02
 09

00 ============================================================
00 提示符 / 终端开
00 ============================================================
ts 终端已开 = 0

tt 提示符 01 02 -> u64  08
    pss 01 0x37C46A 02
    pc 01 zt view_当前名 01 02 02
    lz 当前view 0  08
        pc 01 03 ♂> 04 02
     09
    lz 当前view 0  08 ls  09
    pc 01 03 ♀> 04 02
    pss 01 0xE8F0FF 02
    行首x = 光x
    行首y = 光y
    行长 = 0
    光位 = 0
    zz 0
 09

tt 终端开 01 02 -> u64  08
    lz 身份 0  08
        身份 = 1
     09
    zt 屏清 01 02
    pss 01 0x9AC4FF 02
    pc 01 03 @（关键字全拼音，危险操作要 wx{}）04 02
    zt ph 01 02
    pss 01 0x3A4A66 02
    pc 01 03 --------------------------------------04 02
    zt ph 01 02
    pss 01 0x8FA6C8 02
    pc 01 03 xin 看hw · cun 存obj · qu hq · lie 列出 · pan 盘状态04 02
    zt ph 01 02
    pss 01 0x8FA6C8 02
    pc 01 03 shui view · fen 签发min身 · qie 切view · zhuang 装pkt · gongju 跑C工具04 02
    zt ph 01 02
    zt ph 01 02
    zt 盘_报状态 01 02
    zt ph 01 02
    pss 01 0xE8F0FF 02
    zt 提示符 01 02
    zz 0
 09

tt 终端一步 01 02 -> u64  08
    tz n = 0
    ll  08
        lz n 4  08 ls  09
        tz k = 键 01 02
        lz k 0  08 ls  09
        lz k 13  08
            zt 换行 01 02
            st 01 行buf ht 行长 02 = 0
            zt min词 01 02
            zt 执行 01 02
            zt 提示符 01 02
            n = 01 n ht 1 02
            lx
         09
        lz k 8  08
            zt 行删前 01 02
            zt 重画行 01 02
            n = 01 n ht 1 02
            lx
         09
        lz k 127  08
            zt 行删位 01 02
            zt 重画行 01 02
            n = 01 n ht 1 02
            lx
         09
        lz k 21  08
            光位 = 0
            zt 重画行 01 02
            n = 01 n ht 1 02
            lx
         09
        lz k 6  08
            光位 = 行长
            zt 重画行 01 02
            n = 01 n ht 1 02
            lx
         09
        lz k 19  08
            lh 光位 0  08
                光位 = 01 光位 - 1 02
                zt 重画行 01 02
             09
            n = 01 n ht 1 02
            lx
         09
        lz k 20  08
            lh 光位 行长  08
                光位 = 01 光位 ht 1 02
                zt 重画行 01 02
             09
            n = 01 n ht 1 02
            lx
         09
        lh k 32  08
            zt 行插 01 k 02
            zt 重画行 01 02
            n = 01 n ht 1 02
         09
     09
    zz 0
 09

00 ============================================================
00 shell_init / 盘准备
00 ============================================================
tt shell_init 01 02 -> u64  08
    seg址 = dz 01 seg缓 02
    machine缓址 = dz 01 machine缓 02
    machine缓2址 = dz 01 machine缓2 02
    当前色 = 0xE8F0FF
    词址 = dz 01 词 02
    史书暂址 = dz 01 史书暂 02
    参址 = 01 dz 01 词 02 ht 64 02
    hq址 = dz 01 hq 02
    pktbuf址 = dz 01 pktbuf 02
    pkt起始LBA = 8000
    工具LBA = 8100
    pkt扇区数 = 32
    zt view_init 01 02
    zt 盘_准备好 01 02
    zz 0
 09

tt 盘_准备好 01 02 -> u64  08
    lz zt pready吗 01 02 0  08
        盘状态 = 0
        zz 0
     09
    lz zt 超级块read 01 02 1  08
        盘状态 = 2
        zz 0
     09
    lz zt 盘_空盘吗 01 02 1  08
        zt 盘format 01 16384 02
        zt 超级块read 01 02
        盘状态 = 1
        zz 0
     09
    盘状态 = 3
    zz 0
 09

tt 盘_空盘吗 01 02 -> u64  08
    tz i = 0
    ll  08
        lz i 2  08 ls  09
        lz zt pdd 01 i 02 0  08
            zz 0
         09
        tz j = 0
        ll  08
            lz j 512  08 ls  09
            lh 01 phc ht j 02 0  08
                zz 0
             09
            j = j ht 1
         09
        i = i ht 1
     09
    zz 1
 09

tt 盘_报状态 01 02 -> u64  08
    lz 盘状态 0  08
        pss 01 0xF2A93B 02
        pc 01 03 [盘] 主通道没有 ATA 盘，只能看不能存04 02
        zt 换行 01 02
        zz 0
     09
    lz 盘状态 1  08
        pss 01 0x37C46A 02
        pc 01 03 [盘] 空白盘 —— 已建立hd盘格式04 02
        zt 换行 01 02
        zz 0
     09
    lz 盘状态 3  08
        pss 01 0xE0554A 02
        pc 01 03 [盘] 有content但read不出超级块 —— 没动它（怕把data清了）04 02
        zt 换行 01 02
        pc 01 03     要真重来，得你自己说：format04 02
        zt 换行 01 02
        zz 0
     09
    pss 01 0x00BFA5 02
    pc 01 03 [盘] read到已有格式 · 世代 04 02
    ps 01 phsd 02
    pc 01 03  · obj 04 02
    ps 01 phds 02
    pc 01 03  个04 02
    zt 换行 01 02
    zz 0
 09

00 ============================================================
00 史书的文字buf
00 ============================================================
tt 史书_可见 01 02 -> u64  08
    tz h = 区高
    lh h 40  08
        h = 40
     09
    zz 01 01 h - 8 02 / 22 02
 09

tt 史书_清 01 02 -> u64  08
    tz i = 0
    ll  08
        lz i 5200  08 ls  09
        st 01 史书字 ht i 02 = 0
        st 01 史书色 ht i 02 = 0
        i = i ht 1
     09
    史书行数 = 0
    史书顶 = 0
    史书列 = 0
    zt 史书_空行 01 0 02
    zz 0
 09

tt 史书_空行 01 n 02 -> u64  08
    tz j = 0
    ll  08
        lz j 80  08 ls  09
        st 01 01 史书字 ht 01 n ht 80 02 ht j 02 02 02 = 0
        st 01 01 史书色 ht 01 n ht 80 02 ht j 02 02 02 = 0
        j = j ht 1
     09
    zz 0
 09

tt 史书_write字 01 c 02 -> u64  08
    lh 史书列 78  08
        zz 0
     09
    st 01 01 史书字 ht 01 史书行数 ht 80 02 ht 史书列 02 02 02 = c
    st 01 01 史书色 ht 01 史书行数 ht 80 02 ht 史书列 02 02 02 = 当前色
    史书列 = 01 史书列 ht 1 02
    zz 0
 09

tt 史书_write串 01 s 02 -> u64  08
    tz i = 0
    ll  08
        tz c = fh 01 s ht i 02
        lz c 0  08 ls  09
        zt 史书_write字 01 c 02
        i = i ht 1
     09
    zz 0
 09

tt 史书_换 01 02 -> u64  08
    lh 01 史书行数 ht 1 02 64  08
        tz i = 0
        ll  08
            lz i 01 63 ht 80 02  08 ls  09
            st 01 史书字 ht i 02 = 01 史书字 ht 01 i ht 80 02 02
            st 01 史书色 ht i 02 = 01 史书色 ht 01 i ht 80 02 02
            i = i ht 1
         09
        史书行数 = 63
        zt 史书_空行 01 63 02
     09
    史书行数 = 01 史书行数 ht 1 02
    史书列 = 0
    zt 史书_空行 01 史书行数 02
    tz 可见 = zt 史书_可见 01 02
    lh 史书行数 01 史书顶 ht 可见 02  08
        史书顶 = 01 01 史书行数 - 可见 02 ht 1 02
     09
    zz 0
 09

tt 史书_画行 01 n  y 02 -> u64  08
    tz x = 01 区x ht 8 02
    tz k = 0
    ll  08
        tz c = 01 史书字 ht 01 n ht 80 02 ht k 02 02
        lz c 0  08 ls  09
        tz col = 01 史书色 ht 01 n ht 80 02 ht k 02 02
        tz j = 0
        ll  08
            tz d = 01 史书字 ht 01 n ht 80 02 ht k 02 02
            lz d 0  08 ls  09
            tz dc = 01 史书色 ht 01 n ht 80 02 ht k 02 02
            lh dc col  08 ls  09
            st 01 史书暂址 ht j 02 = d
            j = j ht 1
            k = k ht 1
            lh j 60  08 ls  09
            lh k 79  08 ls  09
         09
        st 01 史书暂址 ht j 02 = 0
        lh j 0  08
            绘字 01 x  y  史书暂址  col 02
            x = 01 x ht zt 文宽2 01 史书暂址 02 02
         09
        lh k 79  08 ls  09
     09
    zz 0
 09

tt 史书_画 01 02 -> u64  08
    绘块 01 区x  区y  区宽  区高  0x0A0E18 02
    tz n = zt 史书_可见 01 02
    tz i = 0
    ll  08
        lz i n  08 ls  09
        tz 行 = 01 史书顶 ht i 02
        lh 行 史书行数  08
            zt 史书_画行 01 行  01 01 区y ht 8 02 ht 01 i ht 22 02 02 02
         09
        i = i ht 1
     09
    光x = 01 区x ht 8 02
    光y = 01 01 区y ht 8 02 ht 01 01 史书行数 - 史书顶 02 ht 22 02 02 02
    zz 0
 09

tt 史书_上 01 02 -> u64  08
    lz 史书顶 0  08
        zz 0
     09
    lh 史书顶 zt 史书_可见 01 02  08
        史书顶 = 01 史书顶 - zt 史书_可见 01 02
     09
    lz 史书顶 zt 史书_可见 01 02  08
        史书顶 = 0
     09
    zt 史书_画 01 02
    zz 0
 09

tt 史书_下 01 02 -> u64  08
    tz 可见 = zt 史书_可见 01 02
    lh 史书行数 可见  08
        zz 0
     09
    tz 底行 = 01 01 史书行数 - 可见 02 ht 1 02
    lh 史书顶 底行  08
        zz 0
     09
    史书顶 = 01 史书顶 ht 可见 02
    lh 史书顶 底行  08
        史书顶 = 底行
     09
    zt 史书_画 01 02
    zz 0
 09
