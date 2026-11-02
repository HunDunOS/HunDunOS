00 包 —— .bao 解包
00 包头 40 字节：魔数 BAO2 / 版本 / 成员数 / 清单长 / 清单因果 / 世代 / 上包因果 / 能力位 / 自校验 / 数据区长
00 成员 32 字节：名字因果 / 名字偏移 / 名字长 / 内容因果 / 长度 / 偏移 / 类型 / 入口
00 数据区在包尾

ts k1 = 0xBA020000
ts k2 = 0x32324142

00 包基址 0x40000，读到这
tt h1 01 a1 02 -> u64  08
    zz fh 01 a1 ht 0 02
 09

00 魔数校验：返回 1 对 0 错
tt h2 01 a1 02 -> u64  08
    tz b1 = fh a1
    lz b1 0x324F4142  08
        zz 1
     09
    zz 0
 09

00 成员数
tt h3 01 a1 02 -> u64  08
    zz fh 01 a1 ht 8 02
 09

00 清单长
tt h4 01 a1 02 -> u64  08
    zz fh 01 a1 ht 12 02
 09

00 数据区起点 = 40 + 清单长
tt h5 01 a1 02 -> u64  08
    zz 01 a1 ht 40 02 ht zt h4 01 a1 02
 09

00 第 n 个成员项地址
tt h6 01 a1 , a2 02 -> u64  08
    zz 01 a1 ht 40 02 ht 01 a2 hh 32 02
 09

00 成员名字地址 = 数据区 + 名字偏移
tt h7 01 a1 , a2 02 -> u64  08
    tz b1 = zt h6 01 a1 , a2 02
    tz b2 = fh 01 b1 ht 4 02
    zz 01 zt h5 01 a1 02 ht b2 02
 09

00 成员名字长
tt h8 01 a1 , a2 02 -> u64  08
    tz b1 = zt h6 01 a1 , a2 02
    zz fh 01 b1 ht 8 02
 09

00 成员内容地址 = 数据区 + 偏移
tt h9 01 a1 , a2 02 -> u64  08
    tz b1 = zt h6 01 a1 , a2 02
    tz b2 = fh 01 b1 ht 20 02
    zz 01 zt h5 01 a1 02 ht b2 02
 09

00 成员内容长
tt ha 01 a1 , a2 02 -> u64  08
    tz b1 = zt h6 01 a1 , a2 02
    zz fh 01 b1 ht 16 02
 09

00 名字比对：成员名 与 目标名（UTF-8 串）是否相同
tt hb 01 a1 , a2 , a3 02 -> u64  08
    tz b1 = zt h7 01 a1 , a2 02
    tz b2 = zt h8 01 a1 , a2 02
    tz b3 = 0
    ll  08
        lz b3 b2  08
            tz b4 = fh 01 a3 ht b3 02
            lz 01 b4 hs 255 02 0  08
                zz 1
             09
            zz 0
         09
        tz b4 = fh 01 b1 ht b3 02
        tz b4 = 01 b4 hs 255 02
        tz b5 = fh 01 a3 ht b3 02
        tz b5 = 01 b5 hs 255 02
        lh b4 b5  08
            zz 0
         09
        b3 = b3 ht 1
     09
    zz 0
 09

00 按名字找成员，返回成员序号，找不到返回 0xFFFFFFFF
tt hc 01 a1 , a2 02 -> u64  08
    lz zt h2 01 a1 02 0  08
        zz 0xFFFFFFFF
     09
    tz b1 = zt h3 01 a1 02
    tz b2 = 0
    ll  08
        lz b2 b1  08 ls  09
        lz zt hb 01 a1 , b2 , a2 02 1  08
            zz b2
         09
        b2 = b2 ht 1
     09
    zz 0xFFFFFFFF
 09

00 取成员内容：返回内容地址，长度写到 0x2D000
tt he 01 a1 , a2 02 -> u64  08
    lz zt h2 01 a1 02 0  08
        sh 0x2D000 , 0
        zz 0
     09
    tz b1 = zt hc 01 a1 , a2 02
    lz b1 0xFFFFFFFF  08
        sh 0x2D000 , 0
        zz 0
     09
    tz b2 = zt ha 01 a1 , b1 02
    lh b2 0  08
        sh 0x2D000 , 0
        zz 0
     09
    tz b3 = zt h9 01 a1 , b1 02
    lz b3 0x80000  08
        sh 0x2D000 , 0
        zz 0
     09
    lh b3 0x80000  08
        sh 0x2D000 , 0
        zz 0
     09
    sh 0x2D000 , b2
    zz b3
 09
