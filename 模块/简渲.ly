00 ========== 简 的渲染：网格 → 帧缓冲 ==========
00 网格 0x20000 起，40 列 × 25 行，每格 8 字节：码位(4) | 前景(2) | 背景(2)
00 先铺背景块，再用 _桌_字 画字符

ts 简基 = 0x20000
ts 简列 = 40
ts 简行 = 25
ts 简光标行 = 0x1F000
ts 简光标列 = 0x1F008

00 桌用.asm 的全局
ts 桌x = 0
ts 桌y = 0
ts 桌w = 0
ts 桌h = 0
ts 桌色 = 0
ts 桌tx = 0
ts 桌ty = 0
ts 桌tp = 0

ts 格行 = 0
ts 格列 = 0

00 ========== 画一格 ==========
tt 格 01 02 -> u64  08
    tz g1 = 0
    tz g2 = 0
    tz g3 = 0
    tz g4 = 0
    tz g5 = 0
    tz g6 = 0
    tz g7 = 0
    tz g8 = 0
    tz 串 = 0
    tz 串1 = 0

    00 格子地址 = 简基 + (行*40 + 列)*8
    g1 = 格行 hh 简列
    g1 = g1 ht 格列
    g1 = g1 dh 3
    g1 = 简基 ht g1

    00 读格
    g2 = fh g1
    g3 = g2 hs 0xFFFFFFFF
    g4 = 01 01 g2 dl 32 02 hs 65535 02
    g5 = 01 01 g2 dl 48 02 hs 65535 02

    00 屏幕坐标
    g6 = 格列 hh 32
    g7 = 格行 hh 32

    00 铺背景
    桌x = g6
    桌y = g7
    桌w = 32
    桌h = 32
    桌色 = g5
    zs 08
call _桌_块
09

    00 空格跳过
    lz g3 32  08
        zz 0
     09

    00 画字符
    串 = 0x280000
    sh 串 , g3
    串1 = 串 ht 1
    sh 串1 , 0
    桌tx = g6
    桌ty = g7
    桌tp = 串
    桌色 = g4
    zs 08
call _桌_字
09
    zz 0
 09

00 ========== 整屏刷新 ==========
tt 简刷 01 02 -> u64  08
    tz h1 = 0
    tz h2 = 0
    ll  08
        lz h1 简行  08 ls  09
        h2 = 0
        ll  08
            lz h2 简列  08 ls  09
            格行 = h1
            格列 = h2
            zt 格 01 02
            h2 = h2 ht 1
         09
        h1 = h1 ht 1
     09
    zz 0
 09

00 ========== 清屏 + 刷 ==========
tt 简渲画 01 02 -> u64  08
    zs 08
mov edi, [0x3000]
mov esi, [0x3004]
mov ecx, [0x3008]
imul ecx, esi
shr ecx, 2
mov eax, 0x00080810
cld
rep stosd
09
    zt 简刷 01 02
    zz 0
 09
