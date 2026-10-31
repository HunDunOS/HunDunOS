#!/bin/sh
# ============================================================================
#  混沌 构建脚本 —— UEFI 版（纯 64 位，无 BIOS、无路径寻址）
#
#      sh 构建/建UEFI.sh                → 出 构建/uefi/混沌.img
#      sh 构建/建UEFI.sh 输出.img
#
#  一条命令干完：
#     lyc 编六爻主体 → as 收汇编 → ld 链 PE32+ → 打两枚 .dao → 焊 ESP 镜像
#
#  依赖：gcc、binutils(as/ld/objcopy)、mkfs.vfat、mtools(mcopy/mmd)、python3
# ============================================================================
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="${1:-$ROOT/构建/uefi/混沌.img}"
B="$ROOT/构建/uefi"
mkdir -p "$B"

AS="as"
LD="ld"
OBJCOPY="objcopy"

echo "[1/5] 编 lyc"
gcc -O2 -w -o "$B/lyc" "$ROOT/编译器/lyc.c"

echo "[2/5] 汇编 UEFI 桩与帧缓冲运行时"
"$AS" "$ROOT/引导器/efi桩.asm" -o "$B/efi桩.o"
"$AS" "$ROOT/运行时/efi图形.asm" -o "$B/efi图形.o"

python3 "$ROOT/工具/造字.py" "$B/字体.s" "$ROOT"/模块/*.ly "$ROOT/引导器/Dao.ly" > /dev/null
"$AS" "$B/字体.s" -o "$B/字体.o"

echo "[3/5] 打双轨裸块 + XBP 道标"
"$AS" "$ROOT/引导器/yu0裸.asm" -o "$B/y0.o"
$LD -m elf_x86_64 -Ttext=0x100000 -o "$B/y0.elf" "$B/y0.o"
$OBJCOPY -O binary --only-section=.text "$B/y0.elf" "$B/y0.raw"

"$AS" "$ROOT/引导器/yu1裸.asm" -o "$B/y1.o"
$LD -m elf_x86_64 -Ttext=0x200000 -o "$B/y1.elf" "$B/y1.o"
$OBJCOPY -O binary --only-section=.text "$B/y1.elf" "$B/y1.raw"

python3 "$ROOT/工具/打dao.py" "$B/yu0.dao" 0  0x100000 "$B/y0.raw"
python3 "$ROOT/工具/打dao.py" "$B/yu1.dao" 63 0x200000 "$B/y1.raw"

echo "[4/5] 链 Dao.efi（PE32+ / EFI application）"
$LD -m i386pep -subsystem 10 -e efi_main --image-base 0x10000000 \
    -o "$B/Dao.efi" \
    "$B/efi桩.o" "$B/efi图形.o" "$B/字体.o"

echo "[5/5] 焊 ESP 镜像（FAT32 只装门票，双轨是裸扇区）"
rm -f "$OUT"
dd if=/dev/zero of="$OUT" bs=1M count=64 status=none
mkfs.vfat -F 32 "$OUT" > /dev/null 2>&1
mmd -i "$OUT" ::/EFI ::/EFI/BOOT
mcopy -i "$OUT" "$B/Dao.efi" ::/EFI/BOOT/BOOTX64.EFI

# ★ 阴 / 阳 不进目录树，直接按物理扇区钉进去
dd if="$B/yu0.dao" of="$OUT" bs=512 seek=60000 conv=notrunc status=none
dd if="$B/yu1.dao" of="$OUT" bs=512 seek=60100 conv=notrunc status=none

echo
echo "完成：$OUT  ($(stat -c%s "$OUT") 字节)"
echo "跑：qemu-system-x86_64 -m 256 -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/edk2-x86_64-code.fd \\"
echo "     -drive if=pflash,format=raw,file=vars.fd -drive format=raw,file=$OUT"
