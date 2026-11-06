00 象测 —— 面 + 块 + 合成
00 从 XBP 读帧缓冲参数 → 画面 → 画块 → 合成到屏幕

ts gh = 0
ts gc2 = 0
ts 屏基 = 0
ts 屏行 = 0
ts 屏宽 = 0
ts 屏高 = 0
ts gx = 0
ts gy = 0
ts gw = 0
ts gh = 0
ts gc = 0

tt zx 01 argv 02 -> u64  08
    tz a1 = 0
    00 从 XBP 读：+32 帧缓冲 +36 行跨 +40 宽 +44 高
    屏基 = fh 0x0520
    屏基 = 01 屏基 hs 0xFFFFFFFF 02
    屏行 = fh 0x0524
    屏行 = 01 屏行 hs 0xFFFFFFFF 02
    屏宽 = fh 0x0528
    屏宽 = 01 屏宽 hs 0xFFFFFFFF 02
    屏高 = fh 0x052C
    屏高 = 01 屏高 hs 0xFFFFFFFF 02

    00 切到面，铺底色
    zt 象_面 01 02
    gx = 0
    gy = 0
    gw = 640
    gh = 400
    gc = 0x001E1E26
    zt 象_块 01 02

    00 标题栏
    gx = 0
    gy = 0
    gw = 640
    gh = 40
    gc = 0x00262633
    zt 象_块 01 02

    00 红点
    gx = 14
    gy = 14
    gw = 12
    gh = 12
    gc = 0x00E0554A
    zt 象_块 01 02

    00 青金点
    gx = 34
    gy = 14
    gw = 12
    gh = 12
    gc = 0x003FD0C0
    zt 象_块 01 02

    00 按钮甲
    gx = 40
    gy = 240
    gw = 180
    gh = 48
    gc = 0x002D6CDF
    zt 象_块 01 02

    00 按钮乙
    gx = 240
    gy = 240
    gw = 180
    gh = 48
    gc = 0x003FD0C0
    zt 象_块 01 02

    00 合成到屏幕 (80,60)
    gx = 80
    gy = 60
    zt 象_合 01 02

    ll  08
     09
    zz 0
 09
