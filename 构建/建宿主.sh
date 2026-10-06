#!/bin/sh
# ============================================================================
#  建「宿主程序」—— 把一个新语 .xy 编成【Linux 能直接跑】的可执行文件
#
#      sh 构建/建宿主.sh 示例/宿主你好.xy 你好
#
#  原理：
#     xyc 输出的是 i386 汇编（跟编内核时一模一样），
#     区别只在【链接什么】：编内核是链到帧缓冲和端口上，
#     这里是链到 宿主/宿主.c —— 把那 50 多个内建函数接到 Linux 系统调用上。
#
#  ★ 参数顺序是反的（新语第一个参数压得最深，C 是第一个在 [esp+4]），
#    宿主/宿主.c 里全部倒着写，改的时候注意。
# ============================================================================
set -e
cd "$(dirname "$0")/.."
ROOT=$PWD
export TMPDIR="${TMPDIR:-/tmp}"
[ -w "$TMPDIR" ] || TMPDIR=/tmp

SRC="${1:-示例/宿主你好.xy}"
OUT="${2:-宿主程序}"
B="$ROOT/构建/中间"
mkdir -p "$B"

AS=i586-alpine-linux-musl-as;  command -v $AS >/dev/null 2>&1 || AS=as
LD=i586-alpine-linux-musl-ld;  command -v $LD >/dev/null 2>&1 || LD=ld
CC="${CC:-clang}"

echo "[宿主 1/5] 编编译器（要 xyc）"
[ -x "$B/xyc" ] || $CC -O2 -w -o "$B/xyc" "$ROOT/编译器/xyc.c"

echo "[宿主 2/5] 编译新语（主模块，带 _start）"
"$B/xyc" -m "$SRC" -o "$B/宿主.s"

echo "[宿主 3/5] 把结尾的 cli/hlt 换成干净退出"
# 编译器生成的结尾是：   .Lhang: cli / hlt / jmp .Lhang
# 这两条是特权指令，用户态执行会 SIGSEGV —— 换成 exit(0)
python3 - "$B/宿主.s" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
旧 = ".Lhang:\n\tcli\n\thlt\n\tjmp .Lhang\n"
新 = (".Lhang:\n"
      "\tmov eax, 1\n"
      "\txor ebx, ebx\n"
      "\tint 0x80\n")
if 旧 in s:
    s = s.replace(旧, 新, 1)
    print("      改掉了（cli/hlt → exit）")
else:
    print("      ⚠ 没找到 cli/hlt 结尾 —— 编译器版本变了吗？")
open(p, 'w', encoding='utf-8').write(s)
PY

echo "[宿主 4/5] 汇编 + 编宿主运行时"
"$AS" --32 "$B/宿主.s" -o "$B/宿主程序.o"
$CC --target=i386-linux-gnu -m32 -ffreestanding -nostdlib -fno-pic \
    -fno-stack-protector -fno-builtin -O2 -c "$ROOT/宿主/宿主.c" -o "$B/宿主运行时.o"

echo "[宿主 5/5] 链接成 Linux 可执行文件"
$LD -m elf_i386 -static -e _start -o "$OUT" "$B/宿主程序.o" "$B/宿主运行时.o"
chmod +x "$OUT"

SIZE=$(stat -c%s "$OUT")
echo
echo "完成：$OUT（$SIZE 字节，i386 Linux 静态可执行）"
echo "跑：  ./$OUT"
echo
echo "★ 是 32 位静态二进制 —— x86_64 的 Linux 直接能跑，不用装 32 位库"
