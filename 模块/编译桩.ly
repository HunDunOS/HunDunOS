00 编译桩 —— 让 lyc_self 能在 hundun 里跑
00 lyc_self 期望两个六爻函数：_rt_putc 输出字符、_rt_slurp 读源文件

ts m1 = 0x2D000

00 输出一个字符（走串口，暂时）
tt _rt_putc 01 a1 02 -> u64  08
    sl 01 0x3F8 02 , 01 a1 hs 255 02
    zz 0
 09

00 读源文件：a1 = 名字串，返回内容地址，长度写 0x2D000
00 现在还没有文件系统，先返回空（编译空源 = 一个空模块）
tt _rt_slurp 01 a1 02 -> u64  08
    sh m1 , 0
    zz 0x80000
 09
