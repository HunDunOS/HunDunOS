#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""跑 混沌.iso：抓串口 + 屏幕 + VGA 文本缓冲 + 寄存器。"""
import subprocess, time, os, sys

ISO = sys.argv[1] if len(sys.argv) > 1 else "测试.iso"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/run"
WAIT = float(sys.argv[3]) if len(sys.argv) > 3 else 6.0

os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    try:
        os.remove(os.path.join(OUT, f))
    except OSError:
        pass

p = subprocess.Popen(
    ["qemu-system-i386", "-cdrom", ISO, "-boot", "d", "-m", "512",
     "-vga", "std", "-display", "none",
     "-serial", "file:%s/serial.log" % OUT,
     "-monitor", "stdio", "-no-reboot"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT, text=True, errors="replace")


def mon(line):
    try:
        p.stdin.write(line + "\n")
        p.stdin.flush()
    except Exception:
        pass


time.sleep(WAIT)
mon("screendump %s/screen.ppm" % OUT)
time.sleep(2)
mon("info registers")
time.sleep(1)
mon("xp /2048xb 0xb8000")
time.sleep(2)
mon("quit")
time.sleep(0.5)
p.terminate()

try:
    t = p.stdout.read()
except Exception:
    t = ""
open("%s/monitor.txt" % OUT, "w").write(t)

print("=== 串口 ===")
try:
    print(open("%s/serial.log" % OUT).read() or "(空)")
except OSError:
    print("(无)")

# 从 VGA 文本缓冲还原屏幕文字
lines = [l for l in t.splitlines() if l.startswith("0x00000000000b8")]
buf = []
for l in lines:
    parts = l.split(":")
    if len(parts) < 2:
        continue
    for tok in parts[1].split():
        if len(tok) == 3 and tok.startswith("0x"):
            buf.append(int(tok, 16))
text = ""
for i in range(0, len(buf) - 1, 2):
    ch = buf[i]
    if ch == 0:
        ch = 32
    text += chr(ch) if 32 <= ch < 127 else "."
print("=== VGA 文本缓冲 ===")
for r in range(0, 25):
    row = text[r * 80:(r + 1) * 80].rstrip()
    if row:
        print("| " + row)
print("=== EIP 等 ===")
for l in t.splitlines():
    if l.startswith(("EIP", "CS =", "EAX", "EBX", "CR0")):
        print(l[:90])
