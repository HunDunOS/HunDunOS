import subprocess, time, os, sys, shutil
ISO = sys.argv[1] if len(sys.argv) > 1 else "/tmp/桌面2.iso"
IMG = sys.argv[2] if len(sys.argv) > 2 else "/var/minis/workspace/hundun-dev/混沌盘.img"
OUT = sys.argv[3] if len(sys.argv) > 3 else "/tmp/dc"
WORD = sys.argv[4] if len(sys.argv) > 4 else "gongju"
CMDS = WORD.split(",")
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    try: os.remove(os.path.join(OUT, f))
    except: pass
shutil.copy(IMG, "/tmp/cd2.img")
p = subprocess.Popen(["qemu-system-i386", "-cdrom", ISO, "-boot", "d", "-m", "256",
    "-vga", "std", "-display", "none", "-serial", "file:" + OUT + "/s.log",
    "-monitor", "stdio", "-no-reboot",
    "-drive", "file=/tmp/cd2.img,format=raw,if=ide",
    "-netdev", "user,id=n0", "-device", "ne2k_pci,netdev=n0"],
    stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
    stderr=open(OUT + "/qemu.err", "w"), text=True)
def mon(l):
    try:
        p.stdin.write(l + "\n"); p.stdin.flush()
    except Exception: pass
def shot(n):
    mon("screendump %s/%s.ppm" % (OUT, n)); time.sleep(2.5)
def keys(seq, w=0.16):
    SP = {"<ret>": "ret", "<spc>": "spc"}
    for t in seq:
        mon("sendkey " + SP.get(t, t)); time.sleep(w)
time.sleep(9)
shot("1桌面")
mon("mouse_move 176 490"); time.sleep(2)
mon("mouse_button 1"); time.sleep(0.5); mon("mouse_button 0"); time.sleep(4)
shot("2史书开了")
for cmd in CMDS:
    ci = 0
    while ci < len(cmd):
        if cmd[ci:ci+4] == "<bs>":
            mon("sendkey backspace"); time.sleep(0.25); ci += 4; continue
        if cmd[ci:ci+5] == "<bsp>":   # 只退格不回车时用
            mon("sendkey backspace"); time.sleep(0.25); ci += 5; continue
        ch = cmd[ci]
        mon("sendkey " + ({" ": "spc", ".": "dot"}.get(ch, ch))); time.sleep(0.18)
        ci += 1
    if not cmd.startswith("<"): 
        mon("sendkey ret"); time.sleep(7)
shot("5跑完")
mon("quit"); time.sleep(0.5)
p.terminate()
print("ok")
