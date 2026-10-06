#!/bin/sh
# ============================================================================
#  混沌 · 环境自检
#
#      sh 装.sh
#
#  做的事：把构建/运行需要的东西一个一个查过去，
#          缺什么就按你的发行版给出【准确的安装命令】，最后跑一次试构建。
#  它【不会】自动装东西 —— 只告诉你该装什么。
# ============================================================================

echo "════════════════════════════════════════════════"
echo "  混沌 · 环境自检"
echo "════════════════════════════════════════════════"

ARCH=$(uname -m)
echo "  机器架构：$ARCH"
if [ "$ARCH" = "x86_64" ]; then
    echo "           ✓ x86_64 —— 系统自带的 as/ld 就能编 i386，不需要交叉工具链"
elif [ "$ARCH" = "i686" ] || [ "$ARCH" = "i386" ]; then
    echo "           ✓ 本来就是 32 位，直接编"
else
    echo "           ⚠ 不是 x86 —— 你需要交叉工具链 i586-*-as/ld（或 i686-*-）"
    echo "             否则编出来的内核没法在这台机器上跑 QEMU 之外的任何东西"
fi
echo

# ---------- 认发行版 ----------
DISTRO="unknown"
[ -f /etc/arch-release ] && DISTRO="arch"
command -v pacman  >/dev/null 2>&1 && DISTRO="arch"
command -v apt     >/dev/null 2>&1 && DISTRO="debian"
command -v dnf     >/dev/null 2>&1 && DISTRO="fedora"
command -v apk     >/dev/null 2>&1 && DISTRO="alpine"
echo "  发行版：$DISTRO"

case "$DISTRO" in
  arch)    INSTALL_CMD="sudo pacman -S clang binutils python qemu-system-x86"
           MUSL="sudo pacman -S i686-linux-gnu-binutils" ;;
  debian)  INSTALL_CMD="sudo apt install clang binutils python3 qemu-system-x86"
           MUSL="sudo apt install binutils-i686-linux-gnu" ;;
  fedora)  INSTALL_CMD="sudo dnf install clang binutils python3 qemu-system-x86"
           MUSL="sudo dnf install binutils-i686-linux-gnu" ;;
  alpine)  INSTALL_CMD="apk add clang binutils python3 qemu-system-i386"
           MUSL="apk add binutils-i586-alpine-linux-musl" ;;
  *)       INSTALL_CMD="（自己查发行版的包名）clang / binutils / python3 / qemu-system-i386" ;;
esac
echo

# ---------- 一样一样查 ----------
MISS=0
chk() {                      # chk 名字 命令 [要装什么]
    if command -v "$2" >/dev/null 2>&1; then
        printf "  ✓ %-14s %s\n" "$1" "$(command -v "$2")"
    else
        printf "  ✗ %-14s 缺！（这个包是：%s）\n" "$1" "$3"
        MISS=$((MISS+1))
    fi
}

echo "  构建要的："
chk "clang"     clang    clang
chk "as"        as       binutils
chk "ld"        ld       binutils
chk "objcopy"   objcopy  binutils
chk "python3"   python3  python3

echo "  运行要的："
chk "qemu"      qemu-system-i386  qemu-system-x86
echo

# ---------- i386 目标支持 ----------
echo "  能不能编 i386 目标："
TMP=$(mktemp -d 2>/dev/null || echo /tmp/混沌自检)
mkdir -p "$TMP"
printf '.code32\nmov $1,%%eax\n' > "$TMP/t.s" 2>/dev/null
if as --32 "$TMP/t.s" -o "$TMP/t.o" 2>/dev/null; then
    echo "    ✓ as --32 能用"
elif command -v i586-alpine-linux-musl-as >/dev/null 2>&1; then
    echo "    ✓ 有 i586 交叉 as"
elif command -v i686-linux-gnu-as >/dev/null 2>&1; then
    echo "    ✓ 有 i686 交叉 as"
else
    echo "    ✗ 编不了 i386 —— 要么装交叉工具链，要么换 x86_64 机器"
    echo "      交叉工具链：$MUSL"
    MISS=$((MISS+1))
fi
rm -rf "$TMP"
echo

# ---------- 结论 ----------
if [ "$MISS" -eq 0 ]; then
    echo "  ── 都齐了 ──"
    echo
    echo "  下一步："
    echo "    sh 构建/构建.sh \"\" 混沌桌面.iso"
    echo
    echo "  跑："
    echo "    qemu-system-i386 -cdrom 混沌桌面.iso -boot d -m 256 -vga std \\"
    echo "      -drive file=混沌盘.img,format=raw,if=ide \\"
    echo "      -netdev user,id=n0 -device ne2k_pci,netdev=n0"
    echo
    echo "  自动测（不用手点）："
    echo "    python3 工具/测试/跑桌面.py 混沌桌面.iso 混沌盘.img /tmp/t \"cun hello,lie\""
else
    echo "  ── 还缺 $MISS 样 ──"
    echo
    echo "  一次装齐："
    echo "    $INSTALL_CMD"
    echo
    echo "  装完再跑一次  sh 装.sh  确认。"
fi
echo "════════════════════════════════════════════════"
