00 敕令层 —— 变量全在函数头声明（tz 不能进循环，不能重复）

00 ★ 跳板：链接后 落址+64 必须落在它身上，它再叫主函数进来
tt 入口 01 02 -> u64  08
    zt zx 01 02
    zz 0
 
09

ts 鼠X = 0
ts g5 = 0
ts s6 = 0
ts 鼠Y = 0
ts 鼠键 = 0
ts 鼠在 = 0

00 简 的全局（链接时合并）
ts a1 = 0
ts a2 = 0
ts a3 = 0
ts a4 = 0
ts a5 = 0
ts a6 = 0
ts a7 = 0
ts a8 = 0
ts 简基 = 0x20000
ts 简列 = 40
ts 简行 = 25
ts 简光标行 = 0
ts 简光标列 = 0

ts 标X = 0
ts 标Y = 0
ts 标显 = 0

ts 卡基址 = 0
ts 卡在 = 0
ts 卡MAC = 0
ts 发缓基 = 0
ts 收缓基 = 0
ts 帧长 = 0

ts g1 = 0
ts k9 = 0
ts ni = 2026
ts yu = 11
ts ri = 6
ts shi = 0
ts fen = 0
ts miao = 0

ts g2 = 0
ts g3 = 0
ts g0 = 0

00 ---- 象 的全局（链接时合并）----
ts gx = 0
ts gy = 0
ts gw = 0
ts gh = 0
ts gc = 0
ts gr = 0
ts 屏基 = 0
ts 屏行 = 0


00 ---- 数 的全局 ----
ts ga = 0
ts gb = 0

00 输出 g1 的字符
tt tu 01 02 -> u64  08
    tz d1 = 0
    d1 = 01 g1 hs 255 02
    sl 01 0x3F8 02 , d1
    zz 0
 
09

00 输出 g1 指向的 0 结尾串
tt tc 01 02 -> u64  08
    tz p0 = 0
    tz 动 = 0
    tz d2 = 0
    p0 = g1
    动 = 1
    ll  08
        lz 动 0  08 ls  
09
        d2 = fh p0
        d2 = 01 d2 hs 255 02
        lz d2 0  08
            动 = 0
         
09
        lh d2 0  08
            g1 = d2
            zt tu 01 02
         
09
        p0 = 01 p0 ht 1 02
     
09
    zz 0
 
09

00 打 g2 的两位十六进制
tt sx 01 02 -> u64  08
    tz b1 = 0
    tz b2 = 0
    tz e1 = 0
    tz e2 = 0
    b1 = 01 g2 dl 4 02
    b2 = 01 b1 hs 15 02
    lz b2 10  08
        e1 = 01 48 ht b2 02
        g1 = e1
        zt tu 01 02
     
09
    lh b2 10  08
        e2 = 01 b2 hz 10 02
        e1 = 01 65 ht e2 02
        g1 = e1
        zt tu 01 02
     
09
    b1 = 01 g2 hs 15 02
    lz b1 10  08
        e1 = 01 48 ht b1 02
        g1 = e1
        zt tu 01 02
     
09
    lh b1 10  08
        e2 = 01 b1 hz 10 02
        e1 = 01 65 ht e2 02
        g1 = e1
        zt tu 01 02
     
09
    zz 0
 
09

00 读键
tt du 01 02 -> u64  08
    tz a1 = 0
    tz a2 = 0
    tz a3 = 0
    tz a4 = 0
    tz a5 = 0
    ll  08
        00 等 0x64 bit0 = 1（有数据）
        a1 = fl 01 0x64 02
        a2 = 01 a1 hs 1 02
        lz a2 0  08
            a3 = fl 01 0x3FD 02
            a3 = 01 a3 hs 1 02
            lz a3 1  08 zz fl 01 0x3F8 02  
09
         
09
        lh a2 0  08
            00 读扫描码
            a3 = fl 01 0x60 02
            a4 = 01 a3 hs 0x80 02
            lz a4 0  08
                00 松开键，继续等
                a3 = 0
             
09
            lh a4 0x80  08
                00 按下的键，转 ASCII（顺序判断，先精确后范围）
                lz a3 0x1C  08 zz 13  
09
                lz a3 0x0E  08 zz 8   
09
                lz a3 0x39  08 zz 32  
09
                lz a3 0x1E  08 zz 97  
09
                lz a3 0x30  08 zz 98  
09
                lz a3 0x2E  08 zz 99  
09
                lz a3 0x20  08 zz 100 
09
                lz a3 0x12  08 zz 101 
09
                lz a3 0x21  08 zz 102 
09
                lz a3 0x22  08 zz 103 
09
                lz a3 0x23  08 zz 104 
09
                lz a3 0x17  08 zz 105 
09
                lz a3 0x24  08 zz 106 
09
                lz a3 0x25  08 zz 107 
09
                lz a3 0x26  08 zz 108 
09
                lz a3 0x32  08 zz 109 
09
                lz a3 0x31  08 zz 110 
09
                lz a3 0x18  08 zz 111 
09
                lz a3 0x19  08 zz 112 
09
                lz a3 0x10  08 zz 113 
09
                lz a3 0x13  08 zz 114 
09
                lz a3 0x1F  08 zz 115 
09
                lz a3 0x14  08 zz 116 
09
                lz a3 0x16  08 zz 117 
09
                lz a3 0x2F  08 zz 118 
09
                lz a3 0x11  08 zz 119 
09
                lz a3 0x2D  08 zz 120 
09
                lz a3 0x15  08 zz 121 
09
                lz a3 0x2C  08 zz 122 
09
             
09
         
09
     
09
    zz 0
 
09


00 读一行到 0x700，返回长度
tt ln 01 02 -> u64  08
    tz c1 = 0
    tz c2 = 0
    tz c3 = 0
    tz 停 = 0
    c1 = 0
    停 = 0
    ll  08
        lz 停 1  08 ls  
09
        c2 = zt du 01 02
        00 没读到就继续
        lz c2 0  08
            c1 = 0
         
09
        lh c2 0  08
            zt f8 01 c2 02
            zt 简刷 01 02
            lz c2 13  08
                停 = 1
                00 回车：换行
                c3 = 10
                zt f8 01 c3 02
                zt 简刷 01 02
             
09
         
09
        c1 = 0
     
09
    zz c1
 
09


00 命令分派：g3 = 长度
tt ml 01 02 -> u64  08
    tz i1 = 0
    tz i2 = 0
    tz s2 = 0
    tz s3 = 0
    tz s4 = 0
    lz g3 0  08
        zz 0
     
09
    i1 = fh 0x700
    i1 = 01 i1 hs 255 02
    lz i1 99  08
        lz g3 2  08
            i2 = fh 0x708
            i2 = 01 i2 hs 255 02
            lz i2 108  08
                s2 = 03cl yuan0 neng11111 03
                g1 = s2
                zt tc 01 02
                g1 = 10
                zt tu 01 02
                zz 0
             
09
         
09
     
09
    00 ★ 启动时从 XBP 读真实时间
    ni = fh 0x550
    yu = fh 0x558
    ri = fh 0x560
    shi = fh 0x568
    fen = fh 0x570
    miao = fh 0x578

    00 ★ ti = 显示时间
    lz i1 116  08
        lz g3 2  08
            i2 = fh 0x708
            i2 = 01 i2 hs 255 02
            lz i2 105  08
                zt 时画 01 02
                zt 简刷 01 02
                g3 = 0
                zz 0
             
09
         
09
     
09
    lz i1 100  08
        s3 = 03db yin 0x100000 yang 0x200000 he 0x180000 03
        g1 = s3
        zt tc 01 02
        g1 = 10
        zt tu 01 02
        zz 0
     
09
    00 ★ ZM = 进桌面
    lz i1 90  08
        lz g3 2  08
            i2 = fh 0x708
            i2 = 01 i2 hs 255 02
            lz i2 77  08
                s2 = 03desk 03
                g1 = s2
                zt tc 01 02
                g1 = 10
                zt tu 01 02
                zt 画面 01 02
                zz 0
             
09
         
09
     
09
    s4 = 03unknown - try bz 03
    g1 = s4
    zt tc 01 02
    g1 = 10
    zt tu 01 02
    zz 0
 
09

00 ========== 打十进制（g2）==========
tt pd 01 02 -> u64  08
    tz q1 = 0
    tz q2 = 0
    tz q3 = 0
    q1 = g2
    lz q1 0  08
        g1 = 48
        zt tu 01 02
        zz 0
     
09
    q2 = 0
    q3 = g2
    ll  08
        lz q3 0  08 ls  
09
        q1 = 01 q3 hf 10 02
        q1 = 01 q1 ht 48 02
        sh 01 0x700 ht q2 02 , q1
        q3 = 01 q3 hl 10 02
        q2 = 01 q2 ht 1 02
     
09
    ll  08
        lz q2 0  08 ls  
09
        q2 = 01 q2 hz 1 02
        g1 = fh 01 0x700 ht q2 02
        zt tu 01 02
     
09
    zz 0
 
09

tt 打空 01 02 -> u64  08
    g1 = 32
    zt tu 01 02
    zz 0
 
09

00 ========== 在帧缓冲上画字（调 运行时/绘字.asm 的 _xy_draw_text）==========
ts q1 = 0
ts q2 = 0
ts sd1 = 0




00 ========== 开机画面：面 → 圆 → 合成 ==========
tt 画面 01 02 -> u64  08
    00 画面 = 交给 桌.ly 的 画桌面，它自己管壁纸和布局
    00 墨.asm 需要的帧缓冲参数从这里灌
    zs 08
call _efi_从XBP
09
    g1 = 90
    zt tu 01 02

    g1 = 49
    zt tu 01 02
        00 zt 画桌面 01 02
    g1 = 50
    zt tu 01 02
        00 zt 写字层 01 02

    g1 = 89
    zt tu 01 02

    00 ★ 跑 minly 自举编译器（落址 0x400000，入口 0x400000）
    g0 = fh 0x70E0
    lr g0 08
        zs 08
            mov rax , [0x70E0]
            call rax
        09
     09
    g1 = 77
    zt tu 01 02

    00 ★ 终端：铺黑底 + 清网格 + 提示符
    zt 简渲画 01 02
    00 ★ 铺黑底（盖掉固件的输出）
    zt 简渲画 01 02
    zt f5 01 02
    g0 = 13
    zt f8 01 g0 02
    g0 = 10
    zt f8 01 g0 02
    g0 = 72
    zt f8 01 g0 02
    g0 = 68
    zt f8 01 g0 02
    g0 = 62
    zt f8 01 g0 02
    zt 简刷 01 02
    g1 = 84
    zt tu 01 02
    zz 0
 
09

00 ========== 读数自检：牛顿开方 / 斐波那契 / 定点除 ==========
tt 读数 01 02 -> u64  08
    tz r1 = 0
    tz r2 = 0
    tz r3 = 0

    ga = 144
    g2 = zt sq 01 02
    r1 = 03sqrt144= 03
    g1 = r1
    zt tc 01 02
    zt pd 01 02
    zt 打空 01 02

    ga = 20
    g2 = zt fb 01 02
    r2 = 03fib20= 03
    g1 = r2
    zt tc 01 02
    zt pd 01 02
    zt 打空 01 02

    ga = 65536
    gb = 131072
    g2 = zt dc 01 02
    g2 = 01 g2 hl 65536 02
    r3 = 03div= 03
    g1 = r3
    zt tc 01 02
    zt pd 01 02
    zt 打空 01 02
    zz 0
 
09

00 画字用的常量串（放 .rodata 段末，由 zs 引用）
tt 占位 01 02 -> u64  08
    zz 0
 
09

00 主循环
tt zx 01 02 -> u64  08
    sl 01 0x3F8 02 , 88
    tz s5 = 0
    tz n1 = 0
    tz r9 = 0
    tz s9 = 0
    tz 网态 = 0
    tz d1 = 0
    tz d2 = 0
    tz d3 = 0
    s5 = 03CL hundun LL 03
    g1 = 10
    zt tu 01 02
    r9 = 0
    zs 08
call _efi_从XBP
09
    00 ★ 开机先进终端（简），输入 ZM 再进桌面

    00 ★ 再开终端：清屏 + 大字 + 提示符
    zs 08
mov qword ptr [rip + _桌缩], 2
09
    zt f5 01 02
    g0 = 13
    zt f8 01 g0 02
    g0 = 10
    zt f8 01 g0 02
    00 提示符：chi hundun ling >
    s6 = 03chi hundun ling > 03
    g0 = 0
    ll  08
        zs 08
        mov rax, [g_s6]
        mov rcx, [g_g0]
        add rax, rcx
        movzx eax, byte ptr [rax]
        mov [g_g5], rax
        09
        lz g5 0  08 ls  
09
        zt fa 01 g5 02
        g0 = g0 ht 1
     
09
    00 ★ 诊断：读网格前 5 格，打到串口
    tz dd1 = 0
    tz dd2 = 0
    ll  08
        lz dd1 5  08 ls 09
        dd2 = 0x20000 ht 01 dd1 dh 2 02
        tz dv = fh dd2
        tz dc = 01 dv hs 255 02
        sl 0x3F8 , dc
        dd1 = dd1 ht 1
     09
    tz dlf = 10
    sl 0x3F8 , dlf
    00 ★ 用 简 自带的上屏（fi）：每行拼串 → _gfx_text
    zs 08
call _efi_从XBP
09
    00 ★ 先铺全屏黑底（清掉 UEFI 残留）
    zt 绘块 01 0 , 0 , 1280 , 800 , 0x00000000 02
    zt fi 01 02
    00 ★ 光标：填位图 + 画一次
    zt 标填 01 02
    标显 = 1
    标X = 960
    标Y = 540
    zt 标画 01 02
    s9 = 03term ok 03
    g1 = s9
    zt tc 01 02
    g1 = 10
    zt tu 01 02
    00 ★ 鼠标初始化
    zt 鼠启 01 02
    g1 = 77
    zt tu 01 02
    g2 = 鼠在
    zt pd 01 02
    g1 = 10
    zt tu 01 02
    ll  08
        00 每轮读一帧鼠标，读到就重画光标
        g0 = zt 鼠读 01 02
        lz g0 1  08
            g1 = 114
            zt tu 01 02
            g2 = 鼠X
            zt pd 01 02
            g1 = 44
            zt tu 01 02
            g2 = 鼠Y
            zt pd 01 02
            g1 = 10
            zt tu 01 02
            zt 画鼠标 01 02
         
09
        g1 = s5
        zt tc 01 02
        n1 = zt ln 01 02
        g3 = n1
        zt ml 01 02
     
09
    zz 0
 
09
00 ========== 时画：把时间写进 简 的网格（YYYY-MM-DD HH:MM:SS）==========
00 辅助：写两位十进制数（值在 k9 里）
tt 时双 01 02 -> u64  08
    tz d1 = 0
    tz d2 = 0
    d1 = k9 hl 10
    d2 = k9 hf 10
    d1 = 48 ht d1
    g1 = d1
    zt f8 01 g1 02
    d2 = 48 ht d2
    g1 = d2
    zt f8 01 g1 02
    zz 0
 09

tt 时画 01 02 -> u64  08
    tz k1 = 0
    tz k2 = 0

    00 换行
    g1 = 10
    zt f8 01 g1 02

    00 年：2026 → 先写 "20"，再写后两位
    g1 = 50
    zt f8 01 g1 02
    g1 = 48
    zt f8 01 g1 02
    k1 = ni hz 2000
    k9 = k1
    zt 时双 01 02

    00 横杠
    g1 = 45
    zt f8 01 g1 02

    00 月
    k9 = yu
    zt 时双 01 02

    g1 = 45
    zt f8 01 g1 02

    00 日
    k9 = ri
    zt 时双 01 02

    g1 = 32
    zt f8 01 g1 02

    00 时
    k9 = shi
    zt 时双 01 02

    g1 = 58
    zt f8 01 g1 02

    00 分
    k9 = fen
    zt 时双 01 02

    g1 = 58
    zt f8 01 g1 02

    00 秒
    k9 = miao
    zt 时双 01 02

    00 换行
    g1 = 10
    zt f8 01 g1 02
    zz 0
 09
