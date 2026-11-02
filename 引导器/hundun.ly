tt zx 01 argv 02 -> u64  08
    zt tu 01 10 02
    zt tc 01 03HunDun 敕令层03 02
    zt tu 01 10 02
    ll  08
        zt tc 01 03敕 hundun 令 03 02
        tz n0 = zt ln 01 02
        zt ml 01 n0 02
     09
    zz 0
 09

00 敕令层

tt by 01 v0 02 -> u64  08
    zz 01 v0 hs 255 02
 09

tt tu 01 v0 02 -> u64  08
    sl 01 0x3F8 02 , 01 v0 hs 255 02
    zz 0
 09

tt tc 01 p0 02 -> u64  08
    tz q0 = p0
    ll  08
        tz c0 = fh q0
        tz b0 = zt by 01 c0 02
        lz b0 0  08 ls  09
        zt tu 01 b0 02
        q0 = q0 ht 1
     09
    zz 0
 09

tt du 01 02 -> u64  08
    ll  08
        tz a0 = fl 01 0x3FD 02
        lz 01 01 a0 hs 1 02 02 1  08 ls  09
     09
    zz fl 01 0x3F8 02
 09

tt ln 01 02 -> u64  08
    tz c0 = 0
    tz s0 = 0
    ll  08
        lz s0 1  08 ls  09
        tz k0 = zt du 01 02
        lz k0 13  08
            s0 = 1
         09
        lh k0 13  08
            lz k0 8  08
                lh c0 0  08
                    c0 = c0 hz 1
                    zt tu 01 8 02
                 09
             09
            lh k0 8  08
                lz c0 64  08
                    sh 01 0x700 ht 01 c0 dh 3 02 02 , k0
                    c0 = c0 ht 1
                    zt tu 01 k0 02
                 09
             09
         09
     09
    zt tu 01 13 02
    zt tu 01 10 02
    zz c0
 09

tt sy 01 i0 02 -> u64  08
    zz fh 01 0x700 ht 01 i0 dh 3 02 02
 09

tt ml 01 n0 02 -> u64  08
    lz n0 0  08
        zz 0
     09
    tz a0 = zt sy 01 0 02
    tz e0 = zt sy 01 1 02

    lz a0 99  08
        zt tc 01 03cl  大道于0  能力位11111  天道0个03 02
        zt tu 01 10 02
        zz 0
     09

    lz a0 100  08
        lz e0 98  08
            zt tc 01 03db  yin   卦象00  落址0x100000  指纹5F6E9CA8548E0F9903 02
            zt tu 01 10 02
            zt tc 01 03db  yang  卦象63  落址0x200000  指纹72D3020192E129C503 02
            zt tu 01 10 02
            zt tc 01 03db  道标HUNDUNV1  世代103 02
            zt tu 01 10 02
            zz 0
         09
     09

    lz a0 103  08
        lz e0 100  08
            zt tc 01 03gd  he  卦象21  落址0x300000  交互层03 02
            zt tu 01 10 02
            zz 0
         09
     09

    lz a0 98  08
        lz e0 122  08
            zt tc 01 03cl 敕令  db 道标  gd 轨道  bz 帮助03 02
            zt tu 01 10 02
            zz 0
         09
     09

    zt tc 01 03未识  试bz03 02
    zt tu 01 10 02
    zz 0
 09
