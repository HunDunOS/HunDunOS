#!/bin/sh
# 造模块.sh —— 按固定落址表把六爻模块编成 .dao
# 规矩：落址不许撞，每个间隔 0x20000（128KB），模块最大 0x101f，够用
# 注意：变量名必须是 ASCII（BusyBox ash 不认中文变量）
set -e
R=$(cd "$(dirname "$0")/.." && pwd)
C=${C:-$R/构建缓存}
cd "$R"
mkdir -p "$C"
# 编译器：真机原生 as/ld/objcopy；沙箱用交叉软链
if [ -d "$C/xbin" ]; then
    AS="$C/xbin/as"; LD="$C/xbin/ld"; OC="$C/xbin/objcopy"
else
    AS=as; LD=ld; OC=objcopy
fi
LYC=${LYC:-$C/lyc}
OUT=$R/模块/成品
mkdir -p "$OUT" "$C/mo"

# mkdao 名字 落址 卦 主文件 [依赖...]
mkdao() {
    N=$1; ADDR=$2; GUA=$3; shift 3
    OBJS=""
    for f in "$@"; do
        B=$(basename "$f" .ly)
        "$LYC" -c "$f" -o "$C/mo/$B.s" > /dev/null
        "$AS" "$C/mo/$B.s" -o "$C/mo/$B.o"
        OBJS="$OBJS $C/mo/$B.o"
    done
    "$LD" -m elf_x86_64 --defsym MOD_BASE=$ADDR -T 链接/模块.ld -o "$C/mo/$N.elf" $OBJS 2>/dev/null
    "$OC" -O binary -j .text -j .rodata -j .data "$C/mo/$N.elf" "$C/mo/$N.raw"
    python3 工具/打dao.py "$OUT/$N.dao" "$GUA" "$ADDR" "$C/mo/$N.raw"
}

mkdao 象     0x1C0000 46 模块/象.ly 模块/数.ly
mkdao 历     0x1E0000 47 模块/历.ly
mkdao 数     0x200000 48 模块/数.ly
mkdao 数测   0x220000 49 测试/数测.ly 模块/数.ly
mkdao 回收   0x240000 45 模块/回收.ly
mkdao 因时空 0x260000 44 模块/因时空.ly
mkdao 算派   0x280000 43 模块/算派.ly

echo "---- 落址表 ----"
for f in "$OUT"/*.dao; do
    python3 -c "
import struct,sys,os
d=open(sys.argv[1],'rb').read(64); v=struct.unpack('<8Q',d)
print('%-14s 卦 %-3d 落址 0x%06X 长 0x%04X' % (os.path.basename(sys.argv[1]), v[1], v[2], v[3]))
" "$f"
done
