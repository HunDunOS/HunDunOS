#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
打dao.py —— XBP 打包器（纯 64 位版）

一个 .dao = 64 字节道标 + 纯机器码
道标是八个 u64，一个 32 位字段都不许出现：

    +0   道标   8   "HUNDUNV1"
    +8   卦象   8   低 6 位六爻：全阴 = 0（yu0 阴）  全阳 = 63（yu1 阳）
    +16  落址   8   加载物理地址
    +24  长度   8   机器码字节数
    +32  指纹   8   机器码 FNV-1a 64
    +40  入口   8   相对落址的入口偏移
    +48  世代   8   第几版
    +56  头印   8   前 56 字节的 FNV-1a 64（道标自校验）

用法：
    python3 打dao.py 输出.dao 卦象 落址 机器码.bin [入口偏移] [世代]
      卦象：0 = 全阴（yu0）   63 = 全阳（yu1）
"""
import struct
import sys

道标 = b"HUNDUNV1"


def fnv(d):
    h = 0xcbf29ce484222325
    for b in d:
        h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


def build(卦象, 落址, code, 入口=0, 世代=1):
    hdr = 道标
    hdr += struct.pack("<Q", 卦象)
    hdr += struct.pack("<Q", 落址)
    hdr += struct.pack("<Q", len(code))
    hdr += struct.pack("<Q", fnv(code))
    hdr += struct.pack("<Q", 入口)
    hdr += struct.pack("<Q", 世代)
    assert len(hdr) == 56, len(hdr)
    hdr += struct.pack("<Q", fnv(hdr))
    assert len(hdr) == 64

    blob = hdr + code
    blob += b"\x00" * ((512 - len(blob) % 512) % 512)
    return blob


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        return 1
    out, 卦象, 落址, src = sys.argv[1], int(sys.argv[2]), int(sys.argv[3], 0), sys.argv[4]
    入口 = int(sys.argv[5], 0) if len(sys.argv) > 5 else 0
    世代 = int(sys.argv[6], 0) if len(sys.argv) > 6 else 1

    code = open(src, "rb").read()
    blob = build(卦象, 落址, code, 入口, 世代)
    open(out, "wb").write(blob)
    print("%-18s 卦象=%02d(%s)  落址=0x%X  长度=%d  指纹=0x%016X  头印=0x%016X  包=%d"
          % (out, 卦象,
             "全阴" if 卦象 == 0 else ("全阳" if 卦象 == 63 else "阴阳"),
             落址, len(code), fnv(code),
             struct.unpack("<Q", blob[56:64])[0], len(blob)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
