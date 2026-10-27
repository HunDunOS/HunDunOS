@ ============================================================
@ 混沌 HTML 渲染器（渲染器.ly）
@ 用六爻语言写，在内核里跑
@ 解析 HTML 字符串，调用底层画图函数
@ ============================================================

@ ---- 状态 ----
ts html_buf[4096] = 0
ts html_len = 0
ts html_pos = 0
ts html_x = 0
ts html_y = 0
ts html_w = 0
ts html_h = 0
ts html_color = 0x000000
ts html_bg = 0xFFFFFF
ts html_in_tag = 0
ts html_tag_name[32] = 0
ts html_tag_len = 0
ts html_text_buf[256] = 0
ts html_text_len = 0

@ ---- 函数 ----

tt html_初始化 01 串 02 -> u64 08
    tz i = 0
    tz len = 串长 01 02
    html_len = len
    html_pos = 0
    html_x = 0
    html_y = 0
    html_w = 800
    html_h = 600
    html_color = 0x000000
    html_bg = 0xFFFFFF
    html_in_tag = 0
    html_tag_len = 0
    html_text_len = 0
    09

tt html_画背景 08
    画矩形 0 0 html_w html_h html_bg
    09

tt html_画文字 01 x 01 y 01 串 02 08
    屏串 x y 串 html_color
    09

tt html_画按钮 01 x 01 y 01 w 01 h 01 文 02 08
    画矩形 x y w h 0xCCCCCC
    画矩形 x y w 2 0xFFFFFF
    画矩形 x y+h-2 w 2 0x888888
    画矩形 x y 2 h 0xFFFFFF
    画矩形 x+w-2 y 2 h 0x888888
    html_画文字 x+10 y+10 文
    09

tt html_解析标签 08
    tz i = 0
    html_tag_len = 0
    ll  08
        tz c = html_buf[html_pos]
        lz c 0x3E  08 ls  09
        lz c 0x3C  08 ls  09
        html_tag_name[html_tag_len] = c
        html_tag_len = html_tag_len + 1
        html_pos = html_pos + 1
     09

    lz html_tag_len 3 08 ls  09
        tz t0 = html_tag_name[0]
        tz t1 = html_tag_name[1]

        00 <div>
        lz t0 0x64 08 ls  09 00 d
            lz t1 0x69 08 ls  09 00 i
                00 <div> 忽略，块级元素
             09
         09

        00 <button>
        lz t0 0x62 08 ls  09 00 b
            lz t1 0x75 08 ls  09 00 u
                00 <button> 开始收集文字
                html_text_len = 0
             09
         09

        00 </button>
        lz t0 0x2F 08 ls  09 00 /
            tz t1b = html_tag_name[1]
            lz t1b 0x62 08 ls  09 00 b
                tz t2 = html_tag_name[2]
                lz t2 0x75 08 ls  09 00 u
                    00 </button> 画按钮
                    html_text_buf[html_text_len] = 0
                    html_画按钮 html_x html_y 120 40 html_text_buf
                    html_y = html_y + 50
                 09
             09
         09
     09
    09

tt html_渲染 01 串 02 08
    html_初始化 01 02
    html_画背景

    ll  08
        lz html_pos html_len 08 ls  09
        tz c = html_buf[html_pos]

        lz c 0x3C 08 ls  09 00 <
            html_解析标签
         09

        00 普通文字
        lz html_in_tag 1 08 ls  09
            html_text_buf[html_text_len] = c
            html_text_len = html_text_len + 1
         09

        html_pos = html_pos + 1
     09

    09

@ ============================================================
@ 用法：
@ html_渲染 03 <html><body>
@  <button>你好混沌</button>
@  <button>系统信息</button>
@ </body></html>04
@ ============================================================
