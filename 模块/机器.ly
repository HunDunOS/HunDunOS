00 ============================================================
00 混沌 机器模块（机器.ly）—— 去问真实硬件
00 六爻语言移植版
00 ============================================================

00 ---- 缓冲区 ----
ts 机器缓[256] = 0
ts 机器缓址 = 0
ts 机器缓2[256] = 0
ts 机器缓2址 = 0

00 ---- 函数 ----
tt 机器抄 01 出  s 02 -> u64  08
    tz i = 0
    ll  08
        tz c = fh 01 s ht i 02
        lz c 0  08 ls  09
        st 01 出 ht i 02 = c
        i = i ht 1
     09
    st 01 出 ht i 02 = 0
    zz i
 09

tt 机器清 01 出  n 02 -> u64  08
    tz i = 0
    ll  08
        lz i n  08 ls  09
        st 01 出 ht i 02 = 0
        i = i ht 1
     09
    zz 0
 09

00 ============================================================
00 CPU：CPUID
00 ============================================================
tt 机器_CPU厂商 01 出 02 -> u64  08
    00 读CPUID(0, 0)
    tz b = CPUB 01 02
    tz d = CPUD 01 02
    tz c = CPUC 01 02
    tz i = 0
    ll  08
        lz i 4  08 ls  09
        st 01 出 ht i 02 = 01 b / 01 1 ht 01 i ht 8 02 02 02 % 256
        i = i ht 1
     09
    ll  08
        lz i 8  08 ls  09
        st 01 出 ht i 02 = 01 d / 01 1 ht 01 01 i 02 - 4 02 ht 8 02 02 02 % 256
        i = i ht 1
     09
    ll  08
        lz i 12  08 ls  09
        st 01 出 ht i 02 = 01 c / 01 1 ht 01 01 i 02 - 8 02 ht 8 02 02 02 % 256
        i = i ht 1
     09
    st 01 出 ht 12 02 = 0
    zz 12
 09

tt 机器_CPU型号 01 出 02 -> u64  08
    tz f = 0x80000002
    tz k = 0
    ll  08
        lz k 3  08 ls  09
        00 读CPUID(f, 0)
        tz a = CPUE 01 02
        tz b = CPUB 01 02
        tz c = CPUC 01 02
        tz d = CPUD 01 02
        tz i = 0
        ll  08
            lz i 4  08 ls  09
            st 01 出 ht k ht 16 ht i 02 = 01 a / 01 1 ht 01 i ht 8 02 02 02 % 256
            i = i ht 1
         09
        ll  08
            lz i 8  08 ls  09
            st 01 出 ht k ht 16 ht i 02 = 01 b / 01 1 ht 01 01 i 02 - 4 02 ht 8 02 02 02 % 256
            i = i ht 1
         09
        ll  08
            lz i 12  08 ls  09
            st 01 出 ht k ht 16 ht i 02 = 01 c / 01 1 ht 01 01 i 02 - 8 02 ht 8 02 02 02 % 256
            i = i ht 1
         09
        ll  08
            lz i 16  08 ls  09
            st 01 出 ht k ht 16 ht i 02 = 01 d / 01 1 ht 01 01 i 02 - 12 02 ht 8 02 02 02 % 256
            i = i ht 1
         09
        f = f ht 1
        k = k ht 1
     09
    st 01 出 ht 48 02 = 0
    zz 48
 09

tt 机器_CPU核数 01 02 -> u64  08
    00 读CPUID(1, 0)
    zz 01 01 CPUB 01 02 02 / 65536 02 % 256
 09

00 ============================================================
00 SMBIOS
00 ============================================================
tt 机器_SMBIOS表 01 02 -> u64  08
    tz p = 0xF0000
    ll  08
        lh p 0xFFFFF  08 ls  09
        lz 01 读32 01 p 02 02 0x5F4D535F  08
            zz 01 读32 01 p ht 24 02 02
         09
        p = p ht 16
     09
    zz 0
 09

tt 机器_下个结构 01 t 02 -> u64  08
    tz L = r8 01 t ht 1 02
    lz L 0  08
        zz 0
     09
    tz p = t ht L
    tz 步 = 0
    ll  08
        lh 步 512  08 ls  09
        lz r8 01 p 02 0  08 ls  09
        p = p ht 1
        步 = 步 ht 1
     09
    p = p ht 1
    lz r8 01 p 02 0  08
        p = p ht 1
     09
    zz p
 09

tt 机器_找结构 01 type 02 -> u64  08
    tz t = zt 机器_SMBIOS表 01 02
    lz t 0  08
        zz 0
     09
    tz i = 0
    ll  08
        lz i 64  08 ls  09
        tz ty = r8 01 t 02
        lz ty 127  08
            zz 0
         09
        lz ty type  08
            zz t
         09
        t = zt 机器_下个结构 01 t 02
        lz t 0  08
            zz 0
         09
        i = i ht 1
     09
    zz 0
 09

tt 机器_取串 01 结构  序号  出 02 -> u64  08
    lz 结构 0  08
        zz 0
     09
    lz 序号 0  08
        zz 0
     09
    tz L = r8 01 结构 ht 1 02
    tz s = 结构 ht L
    tz n = 1
    ll  08
        lz n 序号  08 ls  09
        ll  08
            lz r8 01 s 02 0  08 ls  09
            s = s ht 1
         09
        s = s ht 1
        n = n ht 1
        lz r8 01 s 02 0  08
            zz 0
         09
     09
    tz i = 0
    ll  08
        tz c = r8 01 s ht i 02
        lz c 0  08 ls  09
        st 01 出 ht i 02 = c
        i = i ht 1
     09
    st 01 出 ht i 02 = 0
    zz i
 09

tt 机器_BIOS厂商 01 出 02 -> u64  08
    tz t = zt 机器_找结构 01 0 02
    lz t 0  08
        zz 0
     09
    zz zt 机器_取串 01 t  r8 01 t ht 4 02  出 02
 09

tt 机器_整机厂商 01 出 02 -> u64  08
    tz t = zt 机器_找结构 01 1 02
    lz t 0  08
        zz 0
     09
    zz zt 机器_取串 01 t  r8 01 t ht 4 02  出 02
 09

tt 机器_整机型号 01 出 02 -> u64  08
    tz t = zt 机器_找结构 01 1 02
    lz t 0  08
        zz 0
     09
    zz zt 机器_取串 01 t  r8 01 t ht 5 02  出 02
 09

00 ============================================================
00 PCI / 显卡
00 ============================================================
tt 机器_PCI读 01 总线  设备  功能  偏移 02 -> u64  08
    dc32 01 0xCF8  0x80000000 ht 总线 ht 65536 ht 设备 ht 2048 ht 功能 ht 256 ht 01 偏移 wy 0xFC 02 02
    zz dr32 01 0xCFC 02
 09

ts 显卡厂商号 = 0
ts 显卡设备号 = 0
ts 显卡总线 = 0

tt 机器_找显卡 01 02 -> u64  08
    tz bus = 0
    ll  08
        lz bus 256  08 ls  09
        tz dev = 0
        ll  08
            lz dev 32  08 ls  09
            tz id = zt 机器_PCI读 01 bus  dev  0  0 02
            lh 01 01 id wy 0xFFFF 02 02 0xFFFF  08
                lh id 0xFFFFFFFF  08
                    tz cc = zt 机器_PCI读 01 bus  dev  0  8 02
                    lz 01 cc / 16777216 02 3  08
                        显卡厂商号 = id wy 0xFFFF
                        显卡设备号 = id / 65536
                        显卡总线 = bus ht 256 ht dev
                        zz 1
                     09
                 09
             09
            dev = dev ht 1
         09
        bus = bus ht 1
     09
    zz 0
 09

tt 机器_显卡名 01 出 02 -> u64  08
    lz zt 机器_找显卡 01 02 0  08
        zz zt 机器抄 01 出  03（PCI 上没找到显示设备）04 02
     09
    lz 显卡厂商号 0x1234  08
        zz zt 机器抄 01 出  03QEMU / Bochs 标准 VGA04 02
     09
    lz 显卡厂商号 0x8086  08
        zz zt 机器抄 01 出  03Intel 集成显卡04 02
     09
    lz 显卡厂商号 0x10DE  08
        zz zt 机器抄 01 出  03NVIDIA04 02
     09
    lz 显卡厂商号 0x1002  08
        zz zt 机器抄 01 出  03AMD / ATI04 02
     09
    lz 显卡厂商号 0x1AF4  08
        zz zt 机器抄 01 出  03Virtio GPU（虚拟化）04 02
     09
    lz 显卡厂商号 0x15AD  08
        zz zt 机器抄 01 出  03VMware 虚拟显卡04 02
     09
    zz zt 机器抄 01 出  03未识别的厂商04 02
 09

00 ============================================================
00 CPU 核数 —— 数 ACPI 的 MADT 表
00 ============================================================
tt 机器_RSDP 01 02 -> u64  08
    tz p = 0xE0000
    ll  08
        lh p 0xFFFFF  08 ls  09
        lz 读32 01 p 02 0x20445352  08
            lz 读32 01 p ht 4 02 0x20525450  08
                zz p
             09
         09
        p = p ht 16
     09
    zz 0
 09

tt 机器_ACPI表 01 签名 02 -> u64  08
    tz r = zt 机器_RSDP 01 02
    lz r 0  08
        zz 0
     09
    tz rsdt = 读32 01 r ht 16 02
    lz rsdt 0  08
        zz 0
     09
    lh 读32 01 rsdt 02 0x54445352  08
        zz 0
     09
    tz 长 = 读32 01 rsdt ht 4 02
    lh 长 36  08
        zz 0
     09
    lh 长 4096  08
        zz 0
     09
    tz n = 01 01 长 - 36 02 / 4 02
    lh n 64  08
        n = 64
     09
    tz i = 0
    ll  08
        lz i n  08 ls  09
        tz t = 读32 01 rsdt ht 36 ht i ht 4 02
        lh t 0  08
            lz 读32 01 t 02 签名  08
                zz t
             09
         09
        i = i ht 1
     09
    zz 0
 09

tt 机器_核数 01 02 -> u64  08
    tz m = zt 机器_ACPI表 01 0x43495041 02
    lz m 0  08
        zz 0
     09
    tz 长 = 读32 01 m ht 4 02
    lh 长 44  08
        zz 0
     09
    lh 长 8192  08
        zz 0
     09
    tz p = m ht 44
    tz 尾 = m ht 长
    tz n = 0
    ll  08
        lh 01 p ht 2 02 尾  08 ls  09
        tz 类型 = r8 01 p 02
        tz 记录长 = r8 01 p ht 1 02
        lh 记录长 2  08 ls  09
        lz 类型 0  08
            lz 01 r8 01 p ht 4 02 02 wy 1  08
                n = n ht 1
             09
         09
        p = p ht 记录长
     09
    zz n
 09
