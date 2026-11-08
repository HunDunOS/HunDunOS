set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="${1:-$ROOT/构建/uefi/混沌.img}"
B="$ROOT/构建/uefi"
mkdir -p "$B"

AS="as"
LD="ld"
OBJCOPY="objcopy"

echo "[1/5] 编 lyc（六爻编译器，属于 liuyao 仓库）"
LYC_SRC="${LYC_SRC:-}"
for c in "$LYC_SRC" "$ROOT/编译器/lyc.c" "$ROOT/../liuyao/lyc.c" "$ROOT/../../liuyao/lyc.c" "$ROOT/../三仓库/liuyao/lyc.c"; do
    if [ -n "$c" ] && [ -f "$c" ]; then LYC_SRC="$c"; break; fi
done
if [ -z "$LYC_SRC" ] || [ ! -f "$LYC_SRC" ]; then
    echo "找不到 lyc.c。它是 liuyao 仓库的东西，请："
    echo "  git clone https://github.com/HunDunOS/liuyao  兄弟目录"
    echo "  或者 LYC_SRC=/路径/lyc.c sh 构建/建UEFI.sh"
    exit 1
fi
echo "  用 $LYC_SRC"
gcc -O2 -w -o "$B/lyc" "$LYC_SRC"

echo "[2/5] 汇编 UEFI 桩与帧缓冲运行时"
"$AS" "$ROOT/引导器/大道.asm" -o "$B/大道.o"
"$AS" "$ROOT/运行时/墨.asm" -o "$B/墨.o"
"$AS" "$ROOT/运行时/窗口.asm" -o "$B/窗口.o"
"$AS" "$ROOT/运行时/绘字.asm" -o "$B/绘字.o"
"$AS" "$ROOT/运行时/efi变量.asm" -o "$B/efi变量.o"

python3 "$ROOT/工具/造字.py" "$B/字体.s" "$ROOT"/模块/*.ly "$ROOT/引导器/Dao.ly" > /dev/null
"$AS" "$B/字体.s" -o "$B/字体.o"

echo "[3/5] 打双轨裸块 + XBP 道标"
"$AS" "$ROOT/引导器/yu0裸.asm" -o "$B/y0.o"
$LD -m elf_x86_64 -Ttext=0x100000 -o "$B/y0.elf" "$B/y0.o"
$OBJCOPY -O binary -j .text -j .rodata -j .data "$B/y0.elf" "$B/y0.raw"

"$AS" "$ROOT/引导器/yu1裸.asm" -o "$B/y1.o"
$LD -m elf_x86_64 -Ttext=0x300000 -o "$B/y1.elf" "$B/y1.o"
$OBJCOPY -O binary -j .text -j .rodata -j .data "$B/y1.elf" "$B/y1.raw"

python3 "$ROOT/工具/打dao.py" "$B/yu0.dao" 0  0x100000 "$B/y0.raw"
python3 "$ROOT/工具/打dao.py" "$B/yu1.dao" 63 0x300000 "$B/y1.raw"

"$B/lyc" -c "$ROOT/引导器/hundun.ly" -o "$B/hd.s"
"$B/lyc" -c "$ROOT/模块/象.ly"      -o "$B/xiang.s"
"$B/lyc" -c "$ROOT/模块/数.ly"      -o "$B/shu.s"
"$AS" "$B/hd.s" -o "$B/hd.o"
"$AS" "$B/xiang.s" -o "$B/xiang.o"
"$AS" "$B/shu.s" -o "$B/shu.o"
$LD -m elf_x86_64 --defsym MOD_BASE=0x180000 -T "$ROOT/链接/模块.ld" -o "$B/hd.elf" \
    "$B/hd.o" "$B/xiang.o" "$B/shu.o" "$B/墨.o" "$B/efi变量.o" "$B/字体.o"
$OBJCOPY -O binary -j .text -j .rodata -j .data "$B/hd.elf" "$B/hd.raw"
python3 "$ROOT/工具/打dao.py" "$B/hundun.dao" 21 0x180000 "$B/hd.raw"

echo "[4/5] 链 Dao.efi（PE32+ / EFI application）"
$LD -m i386pep -subsystem 10 -e efi_main --image-base 0x10000000 \
    -o "$B/Dao.efi" \
    "$B/大道.o" "$B/墨.o" "$B/窗口.o" "$B/字体.o"

echo "[5/5] 焊 ESP 镜像（FAT32 只装门票，双轨是裸扇区）"
rm -f "$OUT"
dd if=/dev/zero of="$OUT" bs=1M count=64 status=none
mkfs.vfat -F 32 "$OUT" > /dev/null 2>&1
mmd -i "$OUT" ::/EFI ::/EFI/BOOT
mcopy -i "$OUT" "$B/Dao.efi" ::/EFI/BOOT/BOOTX64.EFI
# ★ startup.nsh：UEFI Shell 倒计时一过就自动跑 Dao.efi，不用手敲
if [ -f "$ROOT/构建/startup.nsh" ]; then
    mcopy -i "$OUT" "$ROOT/构建/startup.nsh" ::/startup.nsh
fi

dd if="$B/yu0.dao" of="$OUT" bs=512 seek=60000 conv=notrunc status=none
dd if="$B/yu1.dao" of="$OUT" bs=512 seek=60100 conv=notrunc status=none
dd if="$B/hundun.dao" of="$OUT" bs=512 seek=60200 conv=notrunc status=none

# ★ 模块区：编译好的六爻模块（.dao），内核按需装载
#   布局：LBA 60400 起，每个模块 8 扇区（4KB），道标自带落址
MODS_DIR="$ROOT/模块/成品"
# 固定顺序（不靠文件名排序，加模块也不会乱）
MODLIST="回收 因时空 算派 象 历 数 数测"
n=0
for m in $MODLIST; do
    f="$MODS_DIR/$m.dao"
    [ -f "$f" ] || continue
    dd if="$f" of="$OUT" bs=512 seek=$((60600 + n * 8)) conv=notrunc status=none
    echo "  模块 $m.dao → LBA $((60600 + n * 8))"
    n=$((n + 1))
done

# ★ 系统包：所有模块源码 + 编译器 + 界面，内核自己读
if [ -f "$ROOT/系统.bao" ]; then
    dd if="$ROOT/系统.bao" of="$OUT" bs=512 seek=60300 conv=notrunc status=none
    echo "  系统包 → LBA 60300（$(stat -c%s "$ROOT/系统.bao") 字节）"
fi

echo
echo "完成：$OUT  ($(stat -c%s "$OUT") 字节)"
echo "跑：qemu-system-x86_64 -m 256 -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/edk2-x86_64-code.fd \\"
echo "     -drive if=pflash,format=raw,file=vars.fd -drive format=raw,file=$OUT"
