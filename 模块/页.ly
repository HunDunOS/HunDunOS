00 页 —— HTML 解析与布局
00 节点表 0x30000 起，每节点 8 个 u64
00   c1 标签  c2 x  c3 y  c4 宽  c5 高  c6 底色  c7 圆角  c8 文字址
00 节点数 0x2F000
00 只支持属性顺序无关的 xml 风格自闭合，够画桌面

ts e1 = 0x30000
ts e2 = 0x2F000
ts e3 = 8

00 找字符：串里第 i 个位置的字节
tt g1 01 a1 , a2 02 -> u64  08
    zz 01 fh 01 a1 ht a2 02 hs 255 02
 09

00 串长度
tt g2 01 a1 02 -> u64  08
    tz b1 = 0
    ll  08
        tz b2 = zt g1 01 a1 , b1 02
        lz b2 0  08 ls  09
        b1 = b1 ht 1
     09
    zz b1
 09

00 从位置 p 起找字节 ch，返回位置或 0
tt g3 01 a1 , a2 , a3 02 -> u64  08
    tz b1 = a2
    ll  08
        tz b2 = zt g1 01 a1 , b1 02
        lz b2 0  08
            zz 0
         09
        lz b2 a3  08
            zz b1
         09
        b1 = b1 ht 1
     09
    zz 0
 09

00 从位置 p 起跳空格
tt g4 01 a1 , a2 02 -> u64  08
    tz b1 = a2
    ll  08
        tz b2 = zt g1 01 a1 , b1 02
        lz b2 32  08
            b1 = b1 ht 1
         09
        lh b2 32  08 ls  09
     09
    zz b1
 09

00 读十进制数字串，返回 {值在 b1, 新位置在 b2}
tt g5 01 a1 , a2 02 -> u64  08
    tz b1 = 0
    tz b2 = a2
    ll  08
        tz b3 = zt g1 01 a1 , b2 02
        lh b3 47  08 ls  09
        lh b3 58  08 ls  09
        b1 = 01 b1 hh 10 02 ht 01 b3 hz 48 02
        b2 = b2 ht 1
     09
    sh 0x2E000 , b1
    sh 0x2E008 , b2
    zz b1
 09

00 十六进制数字串
tt g6 01 a1 , a2 02 -> u64  08
    tz b1 = 0
    tz b2 = a2
    ll  08
        tz b3 = zt g1 01 a1 , b2 02
        lh b3 47  08 ls  09
        lh b3 58  08 ls  09
        lz 01 b3 hs 32 02 0  08
            lz b3 56  08
                b3 = b3 hz 87
                zz 0
             09
            b3 = b3 hz 55
            lz b3 10  08
                b3 = b3 hz 7
             09
         09
        b1 = 01 b1 hh 16 02 ht b3
        b2 = b2 ht 1
     09
    sh 0x2E000 , b1
    sh 0x2E008 , b2
    zz b1
 09

00 找属性：返回值的起始位置或 0
00 参数：串、起点、键首字节、键次字节
tt g7 01 a1 , a2 02 -> u64  08
    tz b1 = a2
    ll  08
        tz b2 = zt g1 01 a1 , b1 02
        lz b2 0  08 zz 0 09
        tz b3 = zt g1 01 a1 , 01 b1 ht 1 02 02
        lz b2 120  08
            lz b3 61  08
                zz 01 b1 ht 2 02
             09
         09
        lz b2 121  08
            lz b3 61  08
                zz 01 b1 ht 2 02
             09
         09
        lz b2 119  08
            lz b3 61  08
                zz 01 b1 ht 2 02
             09
         09
        lz b2 104  08
            lz b3 61  08
                zz 01 b1 ht 2 02
             09
         09
        b1 = b1 ht 1
     09
    zz 0
 09

00 取节点地址（第 n 个）
tt g8 01 a1 02 -> u64  08
    zz e1 ht a1 hh 64
 09

00 写节点字段：第 n 个节点的第 f 个字段
tt g9 01 a1 , a2 , a3 02 -> u64  08
    sh 01 zt g8 01 a1 02 ht 01 a2 dh 3 02 02 , a3
    zz 0
 09

00 存节点数
tt ga 01 a1 02 -> u64  08
    sh e2 , a1
    zz 0
 09

tt gb 01 02 -> u64  08
    zz fh e2
 09
