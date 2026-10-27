#!/bin/sh
# ============================================================================
#  混沌 构建脚本 - lyc 版
#
#      sh 构建/构建.sh               → 做终端盘（默认）
#      sh 构建/构建.sh 终端 输出.iso
#      sh 构建/构建.sh 桌面 输出.iso
#
#  依赖：gcc、binutils(as/ld/objcopy)、python3
#  从仓库根目录跑，或者从任何地方跑（脚本自己会 cd 到仓库根）
# ============================================================================
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
if [ ! -w "${TMPDIR:-/nonexistent}" ]; then TMPDIR=/tmp; fi
export TMPDIR

MODE="${1:-终端}"
case "$MODE" in
  终端|term)  OUT="${2:-混沌终端.iso}" ;;
  桌面|gui)   OUT="${2:-混沌桌面.iso}"  ;;
  *)          echo "用法: sh 构建/构建.sh [终端|桌面] [输出.iso]"; exit 1 ;;
esac

AS="as"
LD="ld"
OBJCOPY="objcopy"
ARCH="elf_x86_64"
BITS="64"

B="$ROOT/构建/中间"
mkdir -p "$B"

echo "[1/7] 编译 lyc"
gcc -O2 -w -o "$B/lyc" "$ROOT/编译器/lyc.c"

echo "[2/7] 编译六爻模块"
MODS="桌面"
for m in $MODS; do
    echo "  → $m.ly"
    "$B/lyc" "$ROOT/模块/$m.ly" -o "$B/$m.s"
done

echo "[3/7] 汇编模块成目标文件（64位）"
for m in $MODS; do
    "$AS" "$B/$m.s" -o "$B/$m.o"
done

echo "[4/7] 汇编运行时（图形 / 原语 / C 接口）（64位）"
"$AS" "$ROOT/运行时/图形.asm" -o "$B/图形.o"
"$AS" "$ROOT/运行时/原语.asm" -o "$B/原语.o"
"$AS" "$ROOT/运行时/C接口.asm" -o "$B/C接口.o"

echo "[5/7] 生成字库"
python3 "$ROOT/工具/造字.py" "$B/字体.s" "$ROOT/模块"/*.ly > /dev/null
"$AS" "$B/字体.s" -o "$B/字体.o"

echo "[6/7] 链接内核（64位）"
OBJS=""
for m in $MODS; do OBJS="$OBJS $B/$m.o"; done
$LD -m elf_x86_64 -T "$ROOT/链接/link_Dao.ld" -o "$B/kernel.elf" \
    $OBJS "$B/图形.o" "$B/原语.o" "$B/C接口.o" "$B/字体.o" 2>/dev/null

"$AS" --16 "$ROOT/引导器/Dao1.asm" -o "$B/Dao1.o"
"$AS" --32 --defsym WITH_VBE=1 "$ROOT/引导器/Dao2.asm" -o "$B/Dao2.o"
$LD -m elf_i386 -T "$ROOT/引导器/Dao.ld" -o "$B/Dao.elf" "$B/Dao1.o" "$B/Dao2.o"
# 引导器是 16/32 位过渡，内核是 64 位！
$OBJCOPY -O binary "$B/Dao.elf" "$B/Dao.bin"

echo "[7/7] 打 ISO"
python3 "$ROOT/工具/xiso.py" "$OUT" "$B/Dao.bin" "内核=$B/kernel.elf" | tail -4
echo
echo "完成：$OUT  ($(stat -c%s "$OUT") 字节)"
echo "跑：qemu-system-x86_64 -cdrom $OUT -boot d -m 256 -vga std"
