#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把一个 .bao 写进 混沌盘.img 的指定 LBA。
   用法：python3 工具/写盘.py 混沌盘.img 某个.bao 8200
（把建包/建工具/建插件三个脚本里重复的那段集中到这儿）"""
import os, sys

盘, 包, lba = sys.argv[1], sys.argv[2], int(sys.argv[3])
pkg = open(包, "rb").read()
if os.path.exists(盘):
    img = bytearray(open(盘, "rb").read())
else:
    img = bytearray(8 * 1024 * 1024)
if len(img) < lba * 512 + len(pkg):
    img = bytearray(max(8 * 1024 * 1024, lba * 512 + len(pkg)))
img[lba * 512: lba * 512 + len(pkg)] = pkg
open(盘, "wb").write(bytes(img))
print("      %d 字节 → LBA %d（盘偏移 %d）" % (len(pkg), lba, lba * 512))
