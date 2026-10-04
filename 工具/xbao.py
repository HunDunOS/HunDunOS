#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
混沌包格式 .bao  ——  v2

=============================================================================
 为什么不是 zip，也不是 apk
=============================================================================
  zip   = 中央目录 + 本地文件头     → 为【随机访问 + 流式写】优化
  apk   = zip + 特定条目            → 为【复用 zip 生态】优化
  两个都是围绕【文件】设计的。

 混沌里没有"文件"，只有"对象"。所以照着抄反而是错的。差别的根在这：
   zip/apk 装完 → 变成一堆文件散在目录树里
   .bao   装完 → 变成对象区里的一批对象 + 一个映射引用（原包还能留着，可校验可回退）

=============================================================================
 结构
=============================================================================
 包头（40 字节）
   +0   魔数 "BAO2"          4
   +4   格式版本             4      = 2
   +8   成员数               4
   +12  清单长度             4      = 成员数 × 32
   +16  清单哈希             4      ★ 清单本身是独立对象（规范 公理 6）
   +20  包的世代             4      第几版
   +24  上一个包哈希         4      ★ 形成链，能回退
   +28  需要的能力位图       4      ★ 别人没有的：包自己声明要什么权柄
   +32  包自校验             4      FNV-1a(前 32 字节)
   +36  数据区长度           4
   +40  成员清单开始

 成员项（每条 32 字节）
   +0   名字哈希             4      ★ 名字本身也是对象（UTF-8 字符串）
   +4   名字偏移             4         相对数据区——所以人能读出成员叫什么
   +8   名字长度             4
   +12  内容哈希             4
   +16  长度                 4
   +20  偏移                 4         相对数据区
   +24  类型                 4      0=数据 1=可执行 2=文档 3=字库
   +28  入口偏移             4      类型=可执行时用

 数据区：各成员原始字节（名字字符串也在里面，是一个独立对象）

=============================================================================
 能力位图
=============================================================================
   bit0 屏幕   bit1 键盘   bit2 鼠标   bit3 盘（对象存储）   bit4 网络
   装包 = 给这个包一个分身，分身的视图里只有它声明要的能力。

=============================================================================
 用法
=============================================================================
  python3 xbao.py 输出.bao 成员1.bin 成员2.txt
  python3 xbao.py 输出.bao --可执行=程序.bin:0x400000 文档=说明.txt:文档
  python3 xbao.py --列 某个.bao        （打印清单，验证格式）
=============================================================================
"""

import struct
import sys
import os

MAGIC = b"BAO2"
VERSION = 2
HDR = 40
ENT = 32

# 能力位
CAP_SCREEN = 1 << 0
CAP_KBD = 1 << 1
CAP_MOUSE = 1 << 2
CAP_DISK = 1 << 3
CAP_NET = 1 << 4

TYPE_DATA, TYPE_EXEC, TYPE_DOC, TYPE_FONT, TYPE_CMD = 0, 1, 2, 3, 4
TYPE_NAMES = {0: "数据", 1: "可执行", 2: "文档", 3: "字库", 4: "命令"}
TYPE_BY_NAME = {"数据": TYPE_DATA, "可执行": TYPE_EXEC, "文档": TYPE_DOC,
                "字库": TYPE_FONT, "命令": TYPE_CMD}


def fnv(data, basis=2166136261):
    h = basis
    for b in data:
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return h


def le32(v):
    return struct.pack("<I", v & 0xFFFFFFFF)


def build(out_path, members, caps=0, generation=1, prev=0):
    """members: [(名字(unicode), 内容(bytes), 类型, 入口偏移)]"""
    n = len(members)

    # ---- 数据区：先放各成员内容，再放名字字符串 ----
    data = bytearray()
    placed = []
    for name, blob, ty, entry in members:
        off = len(data)
        data += blob
        while len(data) % 4:
            data += b"\x00"
        placed.append((name, blob, ty, entry, off))

    manifest = bytearray()
    name_off = {}
    for name, blob, ty, entry, off in placed:
        if name not in name_off:
            nb = name.encode("utf-8")
            name_off[name] = (len(data), len(nb))
            data += nb
            while len(data) % 4:
                data += b"\x00"

    for name, blob, ty, entry, off in placed:
        noff, nlen = name_off[name]
        nb = name.encode("utf-8")
        manifest += le32(fnv(nb))          # 名字哈希
        manifest += le32(noff)             # 名字偏移
        manifest += le32(nlen)             # 名字长度
        manifest += le32(fnv(blob))        # 内容哈希
        manifest += le32(len(blob))        # 长度
        manifest += le32(off)              # 偏移
        manifest += le32(ty)               # 类型
        manifest += le32(entry)            # 入口偏移

    man_hash = fnv(bytes(manifest))

    hdr = bytearray(HDR)
    hdr[0:4] = MAGIC
    struct.pack_into("<I", hdr, 4, VERSION)
    struct.pack_into("<I", hdr, 8, n)
    struct.pack_into("<I", hdr, 12, len(manifest))
    struct.pack_into("<I", hdr, 16, man_hash)
    struct.pack_into("<I", hdr, 20, generation)
    struct.pack_into("<I", hdr, 24, prev)
    struct.pack_into("<I", hdr, 28, caps)
    struct.pack_into("<I", hdr, 32, fnv(bytes(hdr[0:32])))
    struct.pack_into("<I", hdr, 36, len(data))

    img = bytes(hdr) + bytes(manifest) + bytes(data)
    open(out_path, "wb").write(img)

    # 包哈希 = Merkle 根（各成员内容哈希 + 清单哈希，按顺序滚）
    root = 2166136261
    for name, blob, ty, entry, off in placed:
        root = fnv(le32(fnv(blob)), root)
    root = fnv(le32(man_hash), root)

    print("已生成 %s（%d 字节，%d 个成员）" % (out_path, len(img), n))
    print("  包哈希 %08x   清单哈希 %08x   世代 %d" % (root, man_hash, generation))
    if caps:
        names = []
        for b, t in ((CAP_SCREEN, "屏幕"), (CAP_KBD, "键盘"), (CAP_MOUSE, "鼠标"),
                     (CAP_DISK, "盘"), (CAP_NET, "网络")):
            if caps & b:
                names.append(t)
        print("  需要的能力: " + " ".join(names))
    for name, blob, ty, entry, off in placed:
        print("  %-10s %-6s %6d 字节  内容哈希 %08x%s"
              % (name, TYPE_NAMES.get(ty, "?"), len(blob), fnv(blob),
                 ("  入口 0x%X" % entry) if ty == TYPE_EXEC else ""))
    return root


def dump(path):
    d = open(path, "rb").read()
    if d[0:4] != MAGIC:
        print("  这不是 .bao v2（魔数是 %r）" % d[0:4])
        return
    g = lambda o: struct.unpack_from("<I", d, o)[0]
    print("  %s（%d 字节）" % (path, len(d)))
    print("  版本 %d   成员 %d   清单 %d 字节   清单哈希 %08x"
          % (g(4), g(8), g(12), g(16)))
    print("  世代 %d   上一个包 %08x   能力 0x%X   数据区 %d 字节"
          % (g(20), g(24), g(28), g(36)))
    ok = "对" if g(32) == fnv(d[0:32]) else "错"
    print("  包头自校验: %s" % ok)
    n = g(8)
    doff = HDR + g(12)
    for i in range(n):
        o = HDR + i * ENT
        nh, noff, nlen, ch, ln, off, ty, entry = struct.unpack_from("<IIIIIIII", d, o)
        name = d[doff + noff: doff + noff + nlen].decode("utf-8", "replace")
        print("  [%d] %-12s %-6s %6d 字节  名字哈希 %08x  内容哈希 %08x%s"
              % (i, name, TYPE_NAMES.get(ty, "?"), ln, nh, ch,
                 ("  入口 0x%X" % entry) if ty == TYPE_EXEC else ""))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    if sys.argv[1] == "--列":
        dump(sys.argv[2])
        return 0

    out = sys.argv[1]
    members = []
    caps = 0
    for a in sys.argv[2:]:
        if a.startswith("--能力="):
            for w in a.split("=", 1)[1].split(","):
                caps |= {"屏幕": CAP_SCREEN, "键盘": CAP_KBD, "鼠标": CAP_MOUSE,
                         "盘": CAP_DISK, "网络": CAP_NET}.get(w, 0)
            continue
        name, spec = a.split("=", 1)
        # 形如  名字=文件路径[:类型][:入口]     类型和入口顺序随便
        parts = spec.split(":")
        path = parts[0]
        ty = TYPE_DATA
        定过类型 = False
        entry = 0
        for pt in parts[1:]:
            if not pt:
                continue
            if pt in TYPE_BY_NAME:
                ty = TYPE_BY_NAME[pt]
                定过类型 = True
            elif pt.lower().startswith("0x"):
                entry = int(pt, 16)
                # ★ 没显式给类型才默认成「可执行」——
                #   以前这里无条件覆盖，会把「命令」改回「可执行」
                if not 定过类型:
                    ty = TYPE_EXEC
        blob = open(path, "rb").read()
        members.append((name, blob, ty, entry))
    build(out, members, caps=caps)
    return 0


if __name__ == "__main__":
    sys.exit(main())
