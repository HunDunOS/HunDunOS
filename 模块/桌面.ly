00 ============================================================
00 混沌桌面 - 六爻语言 v0.2
00 顶栏 + 坞 + 窗口 + 鼠标
00 ============================================================

00 ---- 全局变量 ----
ts mx = 400          00 鼠标x
ts my = 300          00 鼠标y
ts mbtn = 0          00 鼠标按键
ts winx = 100        00 窗口x
ts winy = 100        00 窗口y
ts winw = 400        00 窗口宽
ts winh = 300        00 窗口高
ts dragging = 0       00 是否正在拖窗口
ts dragdx = 0        00 拖拽偏移x
ts dragdy = 0        00 拖拽偏移y

00 ---- 函数 ----

00 画一个按钮
tt hbtn 01 x, y, w, h, label 02 08
    00 按钮背景
    hk x, y, w, h, 0x2d2d3a
    00 上边高光
    hk x, y, w, 2, 0x4a4a5a
    00 左边高光
    hk x, y, 2, h, 0x4a4a5a
    00 下边阴影
    hk x, y+h-2, w, 2, 0x1a1a2a
    00 右边阴影
    hk x+w-2, y, 2, h, 0x1a1a2a
    00 按钮文字
    pc x+10, y+10, label, 0xffffff
  09

00 画桌面壁纸
00 深色渐变背景
tt hdesk 08
    tz i = 0
    ll  08
        lr i > 600  08 ls  09
            tz c = 0x1a1a2e + i * 0x10
            hk 0, i, 800, 1, c
            i = i ht 1
         09
     09
  09

00 画顶栏
tt htop 08
    hk 0, 0, 800, 30, 0x16213e
    pc 10, 8, dd "HunDunOS', 0x00ff88
    pc 700, 8, dd "12:30', 0xffffff
  09

00 画底部坞
tt hdock 08
    hk 0, 560, 800, 40, 0x16213e
    00 坞上的图标按钮
    hbtn 10, 565, 60, 30, dd "终端'
    hbtn 80, 565, 60, 30, dd "文件'
    hbtn 150, 565, 60, 30, dd "画板'
    hbtn 220, 565, 60, 30, dd "设置'
  09

00 画一个窗口
tt hwin 01 x, y, w, h, title 02 08
    00 窗口阴影
    hk x+2, y+2, w, h, 0x000000
    00 窗口背景
    hk x, y, w, h, 0x2d2d3a
    00 标题栏
    hk x, y, w, 24, 0x1a1a2e
    00 标题文字
    pc x+8, y+6, title, 0xffffff
    00 关闭按钮
    hk x+w-20, y+4, 16, 16, 0xff4444
  09

00 画鼠标光标
tt hcur 08
    hd mx, my, 2, 12, 0xffffff
    hd mx, my, 12, 2, 0xffffff
  09

00 主函数
tt 主 01 argv 02 -> u64  08
    00 画桌面
    hdesk
    htop
    hdock

    00 画一个默认窗口
    hwin winx, winy, winw, winh, dd "系统信息'
    pc winx+10, winy+40, dd "HunDunOS v0.2', 0x00ff88
    pc winx+10, winy+60, dd "内核: HunDun', 0xffffff
    pc winx+10, winy+80, dd "引导: Dao', 0xffffff
    pc winx+10, winy+100, dd "语言: 六爻', 0xffffff

    00 主循环
    ll  08
        00 读鼠标
        tz oldx = mx
        tz oldy = my
        sx 01 0x60, 02  00 读鼠标端口？不对！用内建函数
        tz mx = sx()
        tz my = sy()
        tz mbtn = sb()

        00 检测是不是在拖窗口标题栏
        lr mx > winx & mx < winx+winw & my > winy & my < winy+24 & mbtn == 1  08
            dragging = 1
            dragdx = mx - winx
            dragdy = my - winy
         09

        00 如果在拖窗口，就跟着鼠标动
        lr dragging == 1 & mbtn == 1  08
            winx = mx - dragdx
            winy = my - dragdy
         09

        00 如果鼠标松开了，就停止拖
        lr mbtn == 0  08
            dragging = 0
         09

        00 重绘！
        hdesk
        htop
        hdock
        hwin winx, winy, winw, winh, dd "系统信息'
        pc winx+10, winy+40, dd "HunDunOS v0.2', 0x00ff88
        pc winx+10, winy+60, dd "内核: HunDun', 0xffffff
        pc winx+10, winy+80, dd "引导: Dao', 0xffffff
        pc winx+10, winy+100, dd "语言: 六爻', 0xffffff
        hcur

        00 睡一会，别占满 CPU
        sm 16
     09

    zz 0
  09

00 ============================================================
00 内建函数列表：
00 hk(x,y,w,h,色) - 画矩形
00 hd(x,y,w,h,色) - 画小点
00 pc(x,y,串,色) - 画字符串
00 sx() - 读鼠标x
00 sy() - 读鼠标y
00 sb() - 读鼠标按键
00 sm(ms) - 睡一会儿
00 ============================================================
