#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
造字.py —— 从 unifont 生成内核用的点阵字库（字体.s）

只挑界面真正用到的字，不整包搬 —— 省空间，也少搬别人的东西。

位图统一格式：每行 2 字节，bit15 = 最左边那个像素。
  8 宽的 ASCII：高 8 位放像素
  16 宽的汉字 ：高 8 位 + 低 8 位

用法：
    python3 造字.py 输出.s 源1.xy 源2.xy ...
（会扫描所有 .xy 里的字符串字面量，取其中的非 ASCII 字符）
"""
import sys
import os
import re
import gzip

UNIFONT = "/tmp/unifont.hex.gz"


def load_unifont(path=UNIFONT):
    table = {}
    if not os.path.exists(path):
        raise SystemExit("找不到字库文件 %s" % path)
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or ":" not in line:
                continue
            cp, bits = line.split(":", 1)
            try:
                table[int(cp, 16)] = bits
            except ValueError:
                continue
    return table


def glyph_ascii(hexbits):
    """8x16 → 16 个字（每个字 = 行，像素在高 8 位）"""
    raw = bytes.fromhex(hexbits)
    if len(raw) != 16:
        return None
    out = []
    for r in range(16):
        out.append(raw[r] << 8)
    return out


def glyph_wide(hexbits):
    """16x16 → 16 个字"""
    raw = bytes.fromhex(hexbits)
    if len(raw) != 32:
        return None
    out = []
    for r in range(16):
        out.append((raw[r * 2] << 8) | raw[r * 2 + 1])
    return out


def scan_chars(files):
    chars = set()
    for fn in files:
        try:
            text = open(fn, encoding="utf-8").read()
        except OSError:
            continue
        # 所有字符串字面量里的非 ASCII 字符
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', text):
            for ch in m.group(1):
                if ord(ch) > 127:
                    chars.add(ch)
        # 顺带把注释里的也算上（方便临时加字）
        for ch in text:
            if ord(ch) > 127:
                chars.add(ch)
    return sorted(chars, key=ord)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    out_path = sys.argv[1]
    srcs = sys.argv[2:]

    font = load_unifont()
    chars = scan_chars(srcs)
    print("扫描到 %d 个非 ASCII 字符" % len(chars))

    ascii_rows = []
    for c in range(32, 127):
        b = font.get(c)
        g = glyph_ascii(b) if b else None
        ascii_rows.append(g if g else [0] * 16)

    cjk = []
    missing = []
    for ch in chars:
        cp = ord(ch)
        b = font.get(cp)
        if not b:
            missing.append(ch)
            continue
        g = glyph_wide(b)
        if g is None:
            g = glyph_ascii(b)
            if g is None:
                missing.append(ch)
                continue
            g = [((w >> 8) << 8) | (w & 0xFF) for w in g]
        cjk.append((cp, g))

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("# 由 造字.py 从 unifont 生成 —— 只含界面用到的字\n")
        f.write("# 位图格式：每字形 16 行 × 2 字节，bit15 = 最左像素\n")
        f.write("\t.intel_syntax noprefix\n")
        f.write("\t.section .rodata\n")
        f.write("\t.globl _font_ascii\n")
        f.write("_font_ascii:\n")
        for g in ascii_rows:
            f.write("\t.short " + ",".join("0x%04X" % w for w in g) + "\n")

        f.write("\t.globl _font_cjk_uni\n")
        f.write("_font_cjk_uni:\n")
        if cjk:
            for i in range(0, len(cjk), 8):
                f.write("\t.long " + ",".join("0x%X" % c[0] for c in cjk[i:i + 8]) + "\n")
        else:
            f.write("\t.long 0\n")

        f.write("\t.globl _font_cjk_data\n")
        f.write("_font_cjk_data:\n")
        for cp, g in cjk:
            f.write("\t.short " + ",".join("0x%04X" % w for w in g) + "\n")

        f.write("\t.globl _font_cjk_count\n")
        f.write("_font_cjk_count:\n\t.long %d\n" % len(cjk))

    print("已生成 %s：ASCII 95 字形 + 汉字 %d 字形" % (out_path, len(cjk)))
    if missing:
        print("字库里没有的字符（会显示成空白）：%s" % " ".join(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
