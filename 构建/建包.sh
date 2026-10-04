#!/bin/sh
# ============================================================================
#  混沌 建包 —— 把编辑器打成一个 .bao，放进混沌盘
#
#      sh 构建/建包.sh
#
#  做五件事：
#    1. 先构建内核（拿到符号表）
#    2. 把编辑器链到固定地址 0x400000（借内核的符号解析调用）
#    3. objcopy 出扁平二进制
#    4. xbao.py 打成 编辑器.bao（可执行 + 一份示例文档）
#    5. 把包写进 混沌盘.img 的 LBA 8000
# ============================================================================
set -e
cd "$(dirname "$0")/.."
export TMPDIR="${TMPDIR:-/tmp}"
[ -w "$TMPDIR" ] || TMPDIR=/tmp

AS="i586-alpine-linux-musl-as";  command -v $AS >/dev/null || AS=as
LD="i586-alpine-linux-musl-ld";  command -v $LD >/dev/null || LD=ld
OC="i586-alpine-linux-musl-objcopy"; command -v $OC >/dev/null || OC=objcopy
NM="i586-alpine-linux-musl-nm";  command -v $NM >/dev/null || NM=nm
B="构建/中间"

echo "[1/5] 构建内核（要它的符号表）"
sh 构建/构建.sh 终端 /tmp/_包构建_.iso > /dev/null

echo "[2/5] 编译编辑器 + 包模块，链到 0x400000"
"$B/xyc" -c 模块/编辑器.xy -o "$B/编辑器.s"
"$AS" --32 "$B/编辑器.s" -o "$B/编辑器.o"
cat > "$B/link_editor.ld" <<'LD'
/* 编辑器：固定加载地址 —— 位置相关代码，不需要重定位 */
ENTRY(_start)
SECTIONS
{
    . = 0x400000;
    .text   : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data   : { *(.data*) }
    .bss    : { *(.bss*) *(COMMON) }
}
LD
$LD -m elf_i386 -T "$B/link_editor.ld" --just-symbols="$B/kernel.elf" \
    -o "$B/编辑器.elf" "$B/编辑器.o"
$OC -O binary "$B/编辑器.elf" "$B/编辑器.bin"
echo "      编辑器.bin = $(stat -c%s "$B/编辑器.bin") 字节"

echo "[3/5] 找入口符号"
# 编辑器主的 mangled 名
ENT=$(python3 -c "
import re,subprocess
o=subprocess.run(['$NM','$B/编辑器.elf'],capture_output=True,text=True).stdout
for l in o.split(chr(10)):
    p=l.split()
    if len(p)==3 and p[2].startswith('fn__'):
        try:
            if bytes.fromhex(p[2][4:].replace('_','')).decode('utf-8')=='编辑器主':
                print(p[0]); break
        except Exception: pass
")
echo "      编辑器主 @ 0x$ENT"

echo "[4/5] 打成 .bao"
cat > "$B/示例文档.txt" <<'TXT'
混沌 编辑器

这是一份示例文档。
可以打字、可以存成对象。

命令：先按 : 再输
  cun   存成对象
  qu    按哈希读回来
  xin   看当前文档的哈希
  tui   退出
TXT
python3 工具/xbao.py "$B/编辑器.bao" --能力=屏幕,键盘 \
    "编辑器=$B/编辑器.bin:可执行:0x$ENT" \
    "示例文档=$B/示例文档.txt:文档"

echo "[5/5] 把包写进混沌盘（LBA 8000）"
python3 - "$B/编辑器.bao" <<'PY'
import os, sys
pkg = open(sys.argv[1], 'rb').read()
p = '混沌盘.img'
img = bytearray(open(p, 'rb').read()) if os.path.exists(p) else bytearray(8 * 1024 * 1024)
if len(img) < 8000 * 512 + len(pkg):
    img = bytearray(8 * 1024 * 1024)
img[8000 * 512: 8000 * 512 + len(pkg)] = pkg
open(p, 'wb').write(bytes(img))
print("      包 %d 字节 → LBA 8000" % len(pkg))
PY
echo "完成：编辑器.bao 已进 混沌盘.img"
