00 圆测 —— 面 + 圆 + 合成（验证牛顿开方画圆）
ts 屏基 = 0
ts 屏行 = 0
ts 屏宽 = 0
ts 屏高 = 0
ts gx = 0
ts gy = 0
ts gw = 0
ts gh = 0
ts gc = 0
ts gr = 0
ts ga = 0

tt zx 01 argv 02 -> u64  08
    屏基 = fh 0x0520
    屏基 = 01 屏基 hs 0xFFFFFFFF 02
    屏行 = fh 0x0524
    屏行 = 01 屏行 hs 0xFFFFFFFF 02

    00 铺底色
    gx = 0
    gy = 0
    gw = 640
    gh = 400
    zt 象_面 01 02
    gc = 0x001E1E26
    zt 象_块 01 02

    00 大圆（青）
    gx = 320
    gy = 200
    gr = 120
    gc = 0x003FD0C0
    zt 象_圆 01 02

    00 小圆（蓝）
    gx = 120
    gy = 120
    gr = 60
    gc = 0x002D6CDF
    zt 象_圆 01 02

    00 合成到屏幕
    gx = 80
    gy = 60
    zt 象_合 01 02

    ll  08
     09
    zz 0
 09
