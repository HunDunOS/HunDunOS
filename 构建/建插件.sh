#!/bin/sh
# ============================================================================
#  建「手」（shou）—— 把一个新语插件编成 .bao 并写进盘
#
#      sh 构建/建插件.sh 插件/打印.xy dayin 8200
#          参数1 = 插件源码      默认 插件/打印.xy
#          参数2 = 命令名        默认 dayin
#          参数3 = 盘上的 LBA    默认 8200
#
#  流程和内编辑器的包一样：
#    新语 --xyc--> .s --as--> .o --ld(借内核符号, 固定在 0x400000)--> .elf
#    --objcopy--> .bin --xbao.py--> .bao --写进盘--
#
#  跟普通包的区别只有一个：成员类型是【命令】，
#  内核装包时看到它，就把它挂进命令表 —— 装一个包 = 长一只手。
# ============================================================================
set -e
cd "$(dirname "$0")/.."
ROOT=$PWD
export TMPDIR="${TMPDIR:-/tmp}"
[ -w "$TMPDIR" ] || TMPDIR=/tmp

SRC="${1:-插件/打印.xy}"
CMD="${2:-dayin}"
LBA="${3:-8200}"

AS=i586-alpine-linux-musl-as;  command -v $AS >/dev/null 2>&1 || AS=as
LD=i586-alpine-linux-musl-ld;  command -v $LD >/dev/null 2>&1 || LD=ld
OC=i586-alpine-linux-musl-objcopy; command -v $OC >/dev/null 2>&1 || OC=objcopy
NM=i586-alpine-linux-musl-nm;  command -v $NM >/dev/null 2>&1 || NM=nm
B="$ROOT/构建/中间"

echo "[手 1/5] 构建内核（要它的符号表）"
sh 构建/构建.sh "" /tmp/_插件基.iso > /dev/null

echo "[手 2/5] 编插件"
"$B/xyc" -c "$SRC" -o "$B/插件.s"
"$AS" --32 "$B/插件.s" -o "$B/插件.o"

echo "[手 3/5] 链到 0x400000（位置相关，借内核符号）"
printf 'SECTIONS {\n  . = 0x400000;\n  .text   : { *(.text*) }\n  .rodata : { *(.rodata*) }\n  .data   : { *(.data*) }\n  .bss    : { *(.bss*) *(COMMON) }\n}\n' > "$B/link_插件.ld"
$LD -m elf_i386 -T "$B/link_插件.ld" --just-symbols="$B/kernel.elf" \
    -o "$B/插件.elf" "$B/插件.o" 2>&1 | grep -v 'RWX' || true
$OC -O binary "$B/插件.elf" "$B/插件.bin"
echo "      插件.bin = $(stat -c%s "$B/插件.bin") 字节"

echo "[手 4/5] 打包（成员类型 = 命令）"
ENT=$(python3 工具/入口.py "$NM" "$B/插件.elf" 插件体)
[ -n "$ENT" ] || { echo "  找不到入口 插件体"; exit 1; }
echo "      插件体 @ 0x$ENT"
python3 工具/xbao.py "$B/$CMD.bao" --能力=屏幕 "$CMD=$B/插件.bin:命令:0x$ENT"

echo "[手 5/5] 写进盘（LBA $LBA）"
python3 工具/写盘.py 混沌盘.img "$B/$CMD.bao" "$LBA"
echo "完成：$CMD.bao 已在盘上 LBA $LBA"
