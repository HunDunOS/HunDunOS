00 ============================================================
00 hddesktop - 六爻语言 v0.5
00 混合方案！核心用六爻！应用UI用HTML！
00 ============================================================

00 ---- g_vars ----
ts mx = 400
ts my = 300
ts mbtn = 0
ts winx = 200
ts winy = 150
ts winw = 400
ts winh = 300
ts dragging = 0
ts dragdx = 0
ts dragdy = 0

00 main
tt 主 01 argv 02 -> u64  08
    tz i = 0

    00 ---- 渐变壁纸 ----
    ll  08
        lr i > 600  08 ls  09
        tz c = 0x1a1a2e + i * 0x10
        hk 01 0, i, 800, 1, c 02
        i = i ht 1
     09

    00 ---- 主loop ----
    ll  08
        00 readmouse
        tz mx = sx 01 02
        tz my = sy 01 02
        tz mbtn = sb 01 02

        00 检测是不是在拖wintitle栏
        lr mx > winx  08
        lr mx < winx+winw  08
        lr my > winy  08
        lr my < winy+24  08
        lr mbtn == 1  08
            dragging = 1
            dragdx = mx - winx
            dragdy = my - winy
         09  09  09  09  09

        00 if在拖win，就跟着mouse动
        lr dragging == 1  08
        lr mbtn == 1  08
            winx = mx - dragdx
            winy = my - dragdy
         09  09

        00 ifmouse松开了，就停止拖
        lr mbtn == 0  08
            dragging = 0
         09

        00 ---- 重绘 ----
        tz j = 0
        ll  08
            lr j > 600  08 ls  09
            tz c = 0x1a1a2e + j * 0x10
            hk 01 0, j, 800, 1, c 02
            j = j ht 1
         09

        hk 01 0, 0, 800, 30, 0x16213e 02
        pc 01 10, 8, "HunDunOS', 0x00ff88 02
        pc 01 700, 8, "12:30', 0xffffff 02

        hk 01 0, 560, 800, 40, 0x16213e 02
        hk 01 10, 565, 60, 30, 0x2d2d3a 02
        pc 01 20, 572, "终端', 0xffffff 02
        hk 01 80, 565, 60, 30, 0x2d2d3a 02
        pc 01 95, 572, "file', 0xffffff 02

        hk 01 winx+2, winy+2, winw, winh, 0x000000 02
        hk 01 winx, winy, winw, winh, 0x2d2d3a 02
        hk 01 winx, winy, winw, 24, 0x1a1a2e 02
        pc 01 winx+8, winy+6, "sys信息', 0xffffff 02
        pc 01 winx+10, winy+40, "HunDunOS v0.5', 0x00ff88 02
        pc 01 winx+10, winy+60, "kernel: HunDun', 0xffffff 02
        pc 01 winx+10, winy+80, "boot: Dao', 0xffffff 02

        hk 01 mx, my, 2, 12, 0xffffff 02
        hk 01 mx, my, 12, 2, 0xffffff 02

        sm 01 16 02
     09

    zz 0
 09
