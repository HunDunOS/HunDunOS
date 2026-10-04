#!/bin/sh
# ============================================================================
#  混沌 构建脚本
#
#      sh 构建/构建.sh               → 做终端盘（默认）
#      sh 构建/构建.sh 终端 输出.iso
#      sh 构建/构建.sh 桌面 输出.iso
#
#  依赖：clang、binutils(as/ld/objcopy)、python3
#  从仓库根目录跑，或者从任何地方跑（脚本自己会 cd 到仓库根）
# ============================================================================
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
# 有些环境里 TMPDIR 指向不存在的路径，clang 会报 unable to make temporary file
if [ ! -w "${TMPDIR:-/nonexistent}" ]; then TMPDIR=/tmp; fi
export TMPDIR

MODE="${1:-终端}"
case "$MODE" in
  终端|term)  OUT="${2:-混沌终端.iso}" ;;
  桌面|gui)   OUT="${2:-混沌桌面.iso}"  ;;
  *)          echo "用法: sh 构建/构建.sh [终端|桌面] [输出.iso]"; exit 1 ;;
esac

AS="i586-alpine-linux-musl-as"
LD="i586-alpine-linux-musl-ld"
OBJCOPY="i586-alpine-linux-musl-objcopy"
command -v "$AS" >/dev/null 2>&1 || AS="as"
command -v "$LD" >/dev/null 2>&1 || LD="ld"
command -v "$OBJCOPY" >/dev/null 2>&1 || OBJCOPY="objcopy"

B="$ROOT/构建/中间"
mkdir -p "$B"

echo "[1/7] 编译 xyc"
clang -O2 -w -o "$B/xyc" "$ROOT/编译器/xyc.c"

echo "[2/7] 拆模块（桌面.xy → 内核对象 / 界面 / 应用 / 主）"
python3 "$ROOT/工具/拆分.py" "$ROOT/模块/桌面.xy" "$B/生成"

echo "[3/7] 编译新语模块"
: > "$B/空.xy"
"$B/xyc" -r "$B/空.xy"                     -o "$B/运行时.s"
"$B/xyc" -c "$B/生成/内核对象.xy"            -o "$B/内核对象.s"
"$B/xyc" -c "$B/生成/界面.xy"               -o "$B/界面.s"
"$B/xyc" -c "$B/生成/应用.xy"               -o "$B/应用.s"
"$B/xyc" -c "$ROOT/模块/盘.xy"              -o "$B/盘.s"
"$B/xyc" -c "$ROOT/模块/盘格式.xy"          -o "$B/盘格式.s"
"$B/xyc" -c "$ROOT/模块/压缩.xy"            -o "$B/压缩.s"
"$B/xyc" -c "$ROOT/模块/机器.xy"            -o "$B/机器.s"
"$B/xyc" -c "$ROOT/模块/网卡.xy"            -o "$B/网卡.s"
"$B/xyc" -c "$ROOT/模块/视图.xy"            -o "$B/视图.s"
"$B/xyc" -c "$ROOT/模块/包.xy"              -o "$B/包.s"
"$B/xyc" -c "$ROOT/模块/壳.xy"              -o "$B/壳.s"
"$B/xyc" -m "$B/生成/主.xy"                 -o "$B/主.s"
MODS="运行时 内核对象 界面 应用 盘 盘格式 压缩 机器 网卡 包 视图 壳 主"

for m in $MODS; do
    "$AS" --32 "$B/$m.s" -o "$B/$m.o"
done

echo "[4/7] 汇编运行时（图形 / 原语 / C 接口）"
"$AS" --32 "$ROOT/运行时/图形.asm" -o "$B/图形.o"
"$AS" --32 "$ROOT/运行时/原语.asm" -o "$B/原语.o"
"$AS" --32 "$ROOT/运行时/C接口.asm" -o "$B/C接口.o"

echo "[5/7] 生成字库"
python3 "$ROOT/工具/造字.py" "$B/字体.s" "$ROOT/模块"/*.xy "$B/生成"/*.xy > /dev/null
"$AS" --32 "$B/字体.s" -o "$B/字体.o"

echo "[6/7] 链接内核"
OBJS=""
for m in $MODS; do OBJS="$OBJS $B/$m.o"; done
$LD -m elf_i386 -T "$ROOT/链接/link_xboot.ld" -o "$B/kernel.elf" \
    $OBJS "$B/图形.o" "$B/原语.o" "$B/C接口.o" "$B/字体.o" 2>/dev/null

"$AS" --32 "$ROOT/引导器/boot1.asm" -o "$B/boot1.o"
# 终端版和桌面版都用 VBE（终端是画在帧缓冲上的）
"$AS" --32 --defsym WITH_VBE=1 "$ROOT/引导器/boot2.asm" -o "$B/boot2.o"
$LD -m elf_i386 -T "$ROOT/引导器/xboot.ld" -o "$B/xboot.elf" "$B/boot1.o" "$B/boot2.o"
$OBJCOPY -O binary "$B/xboot.elf" "$B/xboot.bin"

echo "[7/7] 打 ISO"
python3 "$ROOT/工具/xiso.py" "$OUT" "$B/xboot.bin" "内核=$B/kernel.elf" | tail -4
echo
echo "完成：$OUT  ($(stat -c%s "$OUT") 字节)"
echo "跑：qemu-system-i386 -cdrom $OUT -boot d -m 256 -vga std"
