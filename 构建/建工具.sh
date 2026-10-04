#!/bin/sh
# ===========================================================================
#  建「工具包」—— 把 C 写的工具编成 .bao
#
#  流程：
#    C 源码 --clang--> 工具.o --ld(借内核符号)--> 工具.elf --objcopy--> 工具.bin
#    工具.bin --xbao--> 工具.bao --> 写进盘的固定 LBA
# ===========================================================================
set -e
cd "$(dirname "$0")/.."
ROOT=$PWD
B="$ROOT/构建/中间"
AS=i586-alpine-linux-musl-as
LD=i586-alpine-linux-musl-ld
OC=i586-alpine-linux-musl-objcopy
command -v "$AS" >/dev/null 2>&1 || AS=as
command -v "$LD" >/dev/null 2>&1 || LD=ld
command -v "$OC" >/dev/null 2>&1 || OC=objcopy

TOOL="${1:-工具/示例工具.c}"
LBA="${2:-8100}"

echo "[工具 1/5] 先构建内核（要它的符号表）"
sh 构建/构建.sh 终端 "$B/_工具基.iso" > /dev/null

echo "[工具 2/5] 编 C 工具（i386 裸机目标）"
clang --target=i386-unknown-elf -m32 -ffreestanding -nostdlib -fno-pic \
      -fno-stack-protector -fno-builtin -O2 -c "$TOOL" -o "$B/工具.o"
echo "      工具.o = $(stat -c%s "$B/工具.o") 字节"

echo "[工具 3/5] 链到 0x400000（借内核的符号）"
printf 'ENTRY(tool_main)\nSECTIONS {\n  . = 0x400000;\n  .text : { *(.text*) }\n  .rodata : { *(.rodata*) }\n  .data : { *(.data*) }\n  .bss : { *(.bss*) *(COMMON) }\n}\n' > "$B/link_tool.ld"
$LD -m elf_i386 -T "$B/link_tool.ld" --just-symbols="$B/kernel.elf" \
    -o "$B/工具.elf" "$B/工具.o" 2>&1 | grep -v 'RWX' || true
$OC -O binary "$B/工具.elf" "$B/工具.bin"
echo "      工具.bin = $(stat -c%s "$B/工具.bin") 字节"

echo "[工具 4/5] 找入口 + 打包"
ENTRY=$(nm "$B/工具.elf" | awk '$3=="tool_main"{print $1}')
[ -n "$ENTRY" ] || { echo "  找不到 tool_main"; exit 1; }
echo "      tool_main @ 0x$ENTRY"
python3 工具/xbao.py "$B/工具.bao" --能力=屏幕,键盘 \
    "C工具=$B/工具.bin:可执行:0x$ENTRY"

echo "[工具 5/5] 写进盘（LBA $LBA）"
python3 - "$B/工具.bao" "$LBA" <<'PYEOF'
import sys, os
pkg = open(sys.argv[1], 'rb').read()
lba = int(sys.argv[2])
img = bytearray(open('混沌盘.img', 'rb').read())
off = lba * 512
img[off:off + len(pkg)] = pkg
open('混沌盘.img', 'wb').write(bytes(img))
print("      %d 字节 → 盘偏移 %d" % (len(pkg), off))
PYEOF
echo "完成"
