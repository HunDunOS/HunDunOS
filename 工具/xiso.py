#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
xiso.py —— 自研 ISO 9660 + El Torito 打包器  v0.2
（路线图阶段 3，为阶段 4 的自研引导器简化过）

v0.1 → v0.2 的变化：
  · 引导映像不再放最后，改成固定排在目录之后；文件排它后面（布局可预测）
  · 新增「补丁表」：按魔数 XBOO 在引导映像里找到 4 个 32 位字段，
    回填 内核 LBA / 内核扇区数（都以 2048 字节为单位）
    → 引导器不需要读 ISO 9660 目录，直接按 LBA 把内核捞出来
  · 文件可以没有子目录（阶段 4 之后不再需要 ISOLINUX/ 那一套）

用法:
    python3 xiso.py 输出.iso 引导映像.bin 文件1=路径1 [文件2=路径2 ...]
例:
    python3 xiso.py 混沌.iso xboot.bin 内核=0x10000.bin
"""
import struct
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xelf

SECTOR = 2048
PATCH_MAGIC = b"XBOO"

# ---- 固定布局 ----
LBA_PVD, LBA_BR, LBA_TERM, LBA_CAT = 16, 17, 18, 19
LBA_PT = 20
LBA_ROOT = 21
LBA_BOOTIMG = 22          # 引导映像固定在这（阶段 4 起）
LBA_FILES = None          # 由引导映像大小推出


def le16(v):  return struct.pack("<H", v)
def be16(v):  return struct.pack(">H", v)
def le32(v):  return struct.pack("<I", v)
def be32(v):  return struct.pack(">I", v)
def both16(v): return le16(v) + be16(v)
def both32(v): return le32(v) + be32(v)


def pad(b, n, fill=b"\x00"):
    if len(b) > n:
        raise ValueError("字段超长: %d > %d" % (len(b), n))
    return b + fill * (n - len(b))


def dtime7():
    return bytes([126, 10, 2, 23, 0, 0, 0])   # 2026-10-02 23:00:00 UTC


def dtime17():
    return b"2026100223000000" + b"\x00"


def dir_record(ident, lba, size, is_dir):
    rec = bytearray()
    rec.append(0)
    rec.append(0)
    rec += both32(lba)
    rec += both32(size)
    rec += dtime7()
    rec.append(2 if is_dir else 0)
    rec.append(0)
    rec.append(0)
    rec += both16(1)
    rec.append(len(ident))
    rec += ident
    if len(rec) % 2:
        rec.append(0)
    rec[0] = len(rec)
    return bytes(rec)


def path_table_record(ident, lba, parent):
    rec = bytearray()
    rec.append(len(ident))
    rec.append(0)
    rec += le32(lba)
    rec += le16(parent)
    rec += ident
    if len(rec) % 2:
        rec.append(0)
    return bytes(rec)


def build_pvd(volume_id, total_sectors, path_table_lba, path_table_size,
              root_lba, root_size):
    pvd = bytearray(2048)
    pvd[0] = 1
    pvd[1:6] = b"CD001"
    pvd[6] = 1
    pvd[40:72] = pad(volume_id, 32, b" ")
    pvd[80:88] = both32(total_sectors)
    pvd[120:124] = both16(1)
    pvd[124:128] = both16(1)
    pvd[128:132] = both16(SECTOR)
    pvd[132:140] = both32(path_table_size)
    pvd[140:144] = le32(path_table_lba)
    pvd[144:148] = le32(0)
    pvd[148:152] = be32(0)
    pvd[152:156] = be32(0)
    root = dir_record(b"\x00", root_lba, root_size, True)
    pvd[156:156 + len(root)] = root
    pvd[190:318] = pad(b"", 128, b" ")
    pvd[318:446] = pad(b"", 128, b" ")
    pvd[446:574] = pad(b"", 128, b" ")
    pvd[574:702] = pad(b"", 128, b" ")
    pvd[702:739] = pad(b"", 37, b" ")
    pvd[739:776] = pad(b"", 37, b" ")
    pvd[776:813] = pad(b"", 37, b" ")
    pvd[813:830] = dtime17()
    pvd[830:847] = dtime17()
    pvd[847:864] = pad(b"", 17, b"0")
    pvd[864:881] = pad(b"", 17, b"0")
    pvd[881] = 1
    return bytes(pvd)


def build_boot_record(catalog_lba):
    br = bytearray(2048)
    br[0] = 0
    br[1:6] = b"CD001"
    br[6] = 1
    br[7:39] = pad(b"EL TORITO SPECIFICATION", 32)
    br[71:75] = le32(catalog_lba)
    return bytes(br)


def build_catalog(boot_lba, boot_sectors):
    cat = bytearray(2048)
    val = bytearray(32)
    val[0] = 1
    val[1] = 0
    val[4:28] = pad(b"HunDun xboot", 24)
    val[30:32] = b"\x55\xAA"
    s = sum(struct.unpack("<16H", bytes(val)))
    val[28:30] = le16((0x10000 - (s & 0xFFFF)) & 0xFFFF)
    cat[0:32] = val
    ent = bytearray(32)
    ent[0] = 0x88
    ent[1] = 0
    ent[2:4] = le16(0)                # 加载段 0 → 默认 0x7C00
    ent[4] = 0
    ent[6:8] = le16(boot_sectors)     # 占用扇区数（512 字节为单位）
    ent[8:12] = le32(boot_lba)
    cat[32:64] = ent
    return bytes(cat)


def pack_directory(entries):
    data = bytearray()
    for e in entries:
        data += dir_record(*e)
    if len(data) > SECTOR:
        raise ValueError("目录超过一个扇区（MVP 限制）")
    data += b"\x00" * (SECTOR - len(data))
    return bytes(data)


def patch_bootimg(boot, info):
    """在引导映像里按魔数 XBOO 回填内核信息（6 个 32 位字段）"""
    off = boot.find(PATCH_MAGIC)
    if off < 0:
        print("  [警告] 引导映像里没有 XBOO 补丁表，跳过回填")
        return boot, None
    if off + 28 > len(boot):
        raise ValueError("XBOO 补丁表越界")
    buf = bytearray(boot)
    fields = [info["lba"], info["secs"], info["load"],
              info["entry"], info["bss_start"], info["bss_end"]]
    for i, v in enumerate(fields):
        buf[off + 4 + i * 4: off + 8 + i * 4] = le32(v)
    return bytes(buf), off


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    out_iso = sys.argv[1]
    boot_img = sys.argv[2]
    files = []
    for a in sys.argv[3:]:
        name, src = a.split("=", 1)
        files.append((name.upper(), src))

    boot = open(boot_img, "rb").read()
    boot_blocks = (len(boot) + SECTOR - 1) // SECTOR
    boot_sectors_512 = (len(boot) + 511) // 512

    LBA_FILES = LBA_BOOTIMG + boot_blocks

    # ---- 读入文件内容（ELF 就地摊平成"从加载地址开始的连续字节"）----
    loaded = []
    kinfo = None
    for idx, (name, src) in enumerate(files):
        raw = open(src, "rb").read()
        if xelf.is_elf(raw):
            e = xelf.load(src)
            data = e["flat"]
            if idx == 0:
                kinfo = e
        else:
            data = raw
        loaded.append((name, src, data))

    # ---- 布局：第一个文件就是内核，LBA 从 LBA_FILES 开始 ----
    file_layout = []
    cur = LBA_FILES
    for name, src, data in loaded:
        size = len(data)
        blocks = (size + SECTOR - 1) // SECTOR
        file_layout.append((name, src, cur, size, blocks, data))
        cur += blocks
    total = cur

    # ---- 补丁：把内核位置/入口/BSS 回填进引导映像 ----
    patch_off = None
    if kinfo is not None:
        info = {
            "lba": file_layout[0][2],
            "secs": file_layout[0][4],
            "load": kinfo["base"],
            "entry": kinfo["entry"],
            "bss_start": kinfo["bss_start"],
            "bss_end": kinfo["bss_end"],
        }
        boot, patch_off = patch_bootimg(boot, info)

    # ---- 目录 ----
    root_entries = [(b"\x00", LBA_ROOT, SECTOR, True),
                    (b"\x01", LBA_ROOT, SECTOR, True)]
    for name, src, lba, size, blocks, data in file_layout:
        root_entries.append((name.encode(), lba, size, False))
    root_data = pack_directory(root_entries)

    pt = bytearray()
    pt += path_table_record(b"\x00", LBA_ROOT, 1)
    if len(pt) % 2:
        pt += b"\x00"
    pt_size = len(pt)
    pt_data = pt + b"\x00" * (SECTOR - len(pt))

    # ---- 拼盘 ----
    img = bytearray()
    img += b"\x00" * (SECTOR * 16)
    img += build_pvd(b"HUNDUN", total, LBA_PT, pt_size, LBA_ROOT, SECTOR)
    img += build_boot_record(LBA_CAT)
    img += bytes([255]) + b"CD001" + bytes([1]) + b"\x00" * (2048 - 7)
    img += build_catalog(LBA_BOOTIMG, boot_sectors_512)
    img += pt_data
    img += root_data
    assert len(img) == LBA_BOOTIMG * SECTOR, "引导映像位置错位"
    img += boot
    img += b"\x00" * (SECTOR - (len(boot) % SECTOR) if len(boot) % SECTOR else 0)

    for name, src, lba, size, blocks, data in file_layout:
        assert len(img) == lba * SECTOR, "文件位置错位: 期望 %d，实际 %d" % (lba * SECTOR, len(img))
        img += data
        rem = len(data) % SECTOR
        if rem:
            img += b"\x00" * (SECTOR - rem)

    assert len(img) == total * SECTOR
    open(out_iso, "wb").write(bytes(img))

    print("已生成 %s" % out_iso)
    print("  扇区数 %d  (%d 字节)" % (len(img) // SECTOR, len(img)))
    print("  PVD=%d  引导记录=%d  引导目录=%d  路径表=%d  根目录=%d"
          % (LBA_PVD, LBA_BR, LBA_CAT, LBA_PT, LBA_ROOT))
    print("  引导映像 LBA=%d  %d 字节 / %d 个 512 字节扇区"
          % (LBA_BOOTIMG, len(boot), boot_sectors_512))
    if patch_off is not None:
        print("  XBOO 补丁表 @引导映像偏移 0x%X" % patch_off)
        print("    内核 LBA=%d  扇区数=%d (%d 字节)  加载 0x%X  入口 0x%X"
              % (info["lba"], info["secs"], info["secs"] * SECTOR,
                 info["load"], info["entry"]))
        print("    BSS 0x%X - 0x%X (%d 字节)"
              % (info["bss_start"], info["bss_end"],
                 info["bss_end"] - info["bss_start"]))
    for name, src, lba, size, blocks, data in file_layout:
        print("  文件 %-16s LBA=%-6d %d 字节  <- %s" % (name, lba, size, src))
    return 0


if __name__ == "__main__":
    sys.exit(main())
