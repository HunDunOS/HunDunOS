#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
xelf.py —— 极简 ELF32 读取器（自研路线图阶段 2 的第一步）

用途：把 xyc 生成、ld 链出来的 kernel.elf 摊平成"从加载地址开始的连续字节"，
      同时取出入口地址和 BSS 边界，供引导器补丁表回填。

不依赖 objcopy。只认 i386 小端 ELF32 可执行文件。
"""
import struct

PT_LOAD = 1
SHT_SYMTAB = 2


def is_elf(data):
    return len(data) >= 4 and data[:4] == b"\x7fELF"


def load(path):
    d = open(path, "rb").read()
    if not is_elf(d):
        raise ValueError("%s 不是 ELF" % path)
    if d[4] != 1 or d[5] != 1:
        raise ValueError("只支持 32 位小端 ELF")

    e_entry = struct.unpack_from("<I", d, 0x18)[0]
    e_phoff = struct.unpack_from("<I", d, 0x1C)[0]
    e_shoff = struct.unpack_from("<I", d, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", d, 0x2A)[0]
    e_phnum = struct.unpack_from("<H", d, 0x2C)[0]
    e_shentsize = struct.unpack_from("<H", d, 0x2E)[0]
    e_shnum = struct.unpack_from("<H", d, 0x30)[0]

    # ---- 段表 ----
    loads = []
    for i in range(e_phnum):
        o = e_phoff + i * e_phentsize
        p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz = \
            struct.unpack_from("<6I", d, o)
        if p_type == PT_LOAD:
            loads.append((p_offset, p_vaddr, p_filesz, p_memsz))
    if not loads:
        raise ValueError("没有 PT_LOAD 段")

    base = min(l[1] for l in loads)
    file_end = max(l[1] + l[2] for l in loads)
    mem_end = max(l[1] + l[3] for l in loads)

    buf = bytearray(file_end - base)
    for p_offset, p_vaddr, p_filesz, _ in loads:
        s = p_vaddr - base
        buf[s:s + p_filesz] = d[p_offset:p_offset + p_filesz]

    # ---- 符号表（只为找 BSS 边界）----
    syms = {}
    symtab_off = symtab_size = symtab_link = 0
    for i in range(e_shnum):
        o = e_shoff + i * e_shentsize
        sh_type, = struct.unpack_from("<I", d, o + 4)
        if sh_type == SHT_SYMTAB:
            sh_offset, sh_size, sh_link = struct.unpack_from("<3I", d, o + 16)
            symtab_off, symtab_size, symtab_link = sh_offset, sh_size, sh_link
            break
    if symtab_off:
        strtab_off = struct.unpack_from("<I", d, e_shoff + symtab_link * e_shentsize + 16)[0]
        n = symtab_size // 16
        for i in range(n):
            o = symtab_off + i * 16
            st_name, st_value = struct.unpack_from("<II", d, o)
            if st_name == 0:
                continue
            e = d.index(b"\x00", strtab_off + st_name)
            name = d[strtab_off + st_name:e].decode("utf-8", "replace")
            syms[name] = st_value

    return {
        "flat": bytes(buf),
        "base": base,                 # 加载地址
        "entry": e_entry,
        "file_end": file_end,
        "mem_end": mem_end,
        "bss_start": syms.get("_kernel_bss_start", file_end),
        "bss_end": syms.get("_kernel_bss_end", mem_end),
        "symbols": syms,
    }


if __name__ == "__main__":
    import sys
    r = load(sys.argv[1])
    print("加载地址  0x%08X" % r["base"])
    print("入口      0x%08X" % r["entry"])
    print("文件末尾  0x%08X  (%d 字节)" % (r["file_end"], len(r["flat"])))
    print("内存末尾  0x%08X" % r["mem_end"])
    print("BSS       0x%08X - 0x%08X  (%d 字节)"
          % (r["bss_start"], r["bss_end"], r["bss_end"] - r["bss_start"]))
