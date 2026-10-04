#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""在新语编出来的 .elf 里找某个函数的地址。
   新语的符号名规则：fn__ + 名字的 UTF-8 字节，每字节两位十六进制，用 _ 连起来。
   例：主（e4 b8 bb）→ fn__e4_b8_bb

   用法：python3 工具/入口.py <nm 命令> <.elf 路径> <新语函数名>
"""
import subprocess, sys

nm, elf, name = sys.argv[1], sys.argv[2], sys.argv[3]
want = "fn__" + "_".join("%02x" % b for b in name.encode("utf-8"))

out = subprocess.run([nm, elf], capture_output=True, text=True).stdout
for line in out.split("\n"):
    p = line.split()
    if len(p) == 3 and p[2] == want:
        print(p[0])
        sys.exit(0)

# 找不到就把所有新语函数列出来，方便查名字
sys.stderr.write("找不到 %s（mangled: %s）\n" % (name, want))
for line in out.split("\n"):
    p = line.split()
    if len(p) == 3 and p[2].startswith("fn__"):
        try:
            s = bytes.fromhex(p[2][4:].replace("_", "")).decode("utf-8")
            sys.stderr.write("   %s  →  %s\n" % (p[0], s))
        except Exception:
            sys.stderr.write("   %s  →  %s\n" % (p[0], p[2]))
sys.exit(1)
