00 浑天 —— 因果寻址：因果 → 时间（十二地支）→ 空间（二十八星宿）→ 物理 LBA
00 位段彻底分开：低 8 位定时间，次 8 位定空间
00 变量全在函数头声明，传参一律走全局

ts gh = 0
ts gt = 0
ts gs = 0
ts a6 = 2048
ts a7 = 97
ts a8 = 12
ts a9 = 28

00 串口打字符
tt o1 01 02 -> u64  08
    tz d1 = 0
    d1 = 01 gh hs 255 02
    sl 01 0x3F8 02 , d1
    zz 0
 09

00 串口打两位十六进制（gh）
tt o2 01 02 -> u64  08
    tz b1 = 0
    tz b2 = 0
    tz e1 = 0
    tz e2 = 0
    b1 = 01 gh dl 4 02
    b2 = 01 b1 hs 15 02
    lz b2 10  08
        e1 = 01 48 ht b2 02
        gh = e1
        zt o1 01 02
     09
    lh b2 10  08
        e2 = 01 b2 hz 10 02
        e1 = 01 65 ht e2 02
        gh = e1
        zt o1 01 02
     09
    b1 = 01 gh hs 15 02
    lz b1 10  08
        e1 = 01 48 ht b1 02
        gh = e1
        zt o1 01 02
     09
    lh b1 10  08
        e2 = 01 b1 hz 10 02
        e1 = 01 65 ht e2 02
        gh = e1
        zt o1 01 02
     09
    zz 0
 09

00 算时间维：低 8 位 % 12
tt o3 01 02 -> u64  08
    tz a1 = 0
    a1 = 01 gh hs 255 02
    gt = 01 a1 hf a8 02
    zz gt
 09

00 算空间维：次 8 位 % 28
tt o4 01 02 -> u64  08
    tz a2 = 0
    a2 = 01 gh dl 8 02
    a2 = 01 a2 hs 255 02
    gs = 01 a2 hf a9 02
    zz gs
 09

00 算物理 LBA：a6 + (时*28 + 宿)*a7
tt o5 01 02 -> u64  08
    tz a3 = 0
    tz a4 = 0
    zt o3 01 02
    zt o4 01 02
    a3 = 01 gt hh a9 02
    a3 = 01 a3 ht gs 02
    a4 = 01 a3 hh a7 02
    zz 01 a6 ht a4 02
 09

00 打一个坐标：[时]-[宿] 用数字
tt o6 01 02 -> u64  08
    gh = 91
    zt o1 01 02
    gh = 01 gt ht 48 02
    zt o1 01 02
    gh = 93
    zt o1 01 02
    gh = 01 gs ht 65 02
    zt o1 01 02
    zz 0
 09

00 主函数：吃一个因果，报落点
tt zx 01 argv 02 -> u64  08
    tz i1 = 0
    tz p1 = 0
    tz 表 = 0

    00 三个测试因果
    i1 = 0
    ll  08
        lz i1 3  08 ls  09

        00 第 1 个：0x8A3F
        lz i1 0  08
            gh = 0x8A3F
         09
        00 第 2 个：0x1234
        lz i1 1  08
            gh = 0x1234
         09
        00 第 3 个：0xFFFF
        lz i1 2  08
            gh = 0xFFFF
         09

        00 打 [因果 时 宿 址]
        gh = 91
        zt o1 01 02
        zt o2 01 02
        gh = 93
        zt o1 01 02
        zt o3 01 02
        zt o4 01 02
        zt o6 01 02
        gh = 32
        zt o1 01 02
        tz a5 = zt o5 01 02
        gh = 01 01 a5 dl 8 02 hs 255 02
        zt o2 01 02
        gh = 10
        zt o1 01 02

        i1 = 01 i1 ht 1 02
     09
    zz 0
 09

00 ========== 太阴块 / 太阳块（双超级块，交替写）==========
00 太阴 = 0x10000   太阳 = 0x10800    都在内存（还没落盘）
00 写的顺序：世代+1 → 先太阴再太阳
00 读的原则：比两块的世代号，选大的
00 阵眼 = [ZI]-[JIAO]，盘起 +0 是太阴块，+1 是太阳块
ts 太阴块 = 0x10000
ts 太阳块 = 0x10800
ts 世 = 0

00 组一块超级块到缓冲区（gh = 世代，gc = 放哪个缓冲）
ts gc = 0
tt o7 01 02 -> u64  08
    tz i1 = 0
    tz s1 = 0
    00 魔数 YSK(0)
    sh gc , 0x004B5359
    00 版本 1
    sh 01 gc ht 8 02 , 1
    00 世代
    sh 01 gc ht 16 02 , gh
    00 区数 336
    sh 01 gc ht 24 02 , 336
    00 每区扇数 97
    sh 01 gc ht 32 02 , 97
    00 对象数（先写 0）
    sh 01 gc ht 40 02 , 0
    00 校验：前 48 字节的低 32 位累加
    i1 = 0
    s1 = 0
    ll  08
        lz i1 6  08 ls  09
        tz v1 = fh 01 gc ht 01 i1 dh 3 02 02
        s1 = 01 s1 ht v1 02
        i1 = 01 i1 ht 1 02
     09
    sh 01 gc ht 48 02 , s1
    zz s1
 09

00 双写：世代 +1，先写 B 再写 A（下次读选大的）
tt o8 01 02 -> u64  08
    世 = 01 世 ht 1 02
    gh = 世
    gc = 太阴块
    zt o7 01 02
    gh = 世
    gc = 太阳块
    zt o7 01 02
    zz 世
 09

00 读：比两块世代，选大的
tt o9 01 02 -> u64  08
    tz ga = 0
    tz gb = 0
    tz gz = 0
    ga = fh 01 太阴块 ht 16 02
    gb = fh 01 太阳块 ht 16 02
    gz = ga
    lh gb ga  08
        gz = gb
     09
    zz gz
 09
