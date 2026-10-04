#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
拆分.py —— 把单体 桌面.xy 拆成若干个【真模块】

每个模块都带全量的 jg（结构体，编译期概念，重复无害）和全量 qj（全局），
全局用 .comm 声明 —— 链接器会把同名全局合并成一份，所以"对象区"在
内核里物理上只有一份，不管几个模块在用它。

用法：python3 拆分.py 桌面.xy 输出目录
"""
import os
import re
import sys

# ---- 模块划分：函数名 → 模块 ----
模块表 = {
    "内核对象": ["串长", "串等", "摘要", "记轴", "找对象", "存对象", "找名字",
                "加名", "删名", "改名", "存视图", "恢复视图", "对象区自检"],
    "界面": ["点判定", "根", "文宽", "圆角内缩", "圆角块", "圆角块混", "圆角框",
            "阴影", "光斑", "直线", "界面开始", "界面结束", "当前", "布局行",
            "间隔", "控位", "控位满", "命中", "新号", "进控件", "文字", "按钮",
            "复选框", "滑块", "面板开始", "面板结束", "画壁纸", "两位", "画顶栏",
            "画图标", "坞图标", "画坞", "画鼠标", "存光标", "还光标",
            "画块", "画框", "画字", "画数", "画块混"],
    "应用": ["信息行", "画信息", "算键", "计算器按键", "画计算器", "画板色块",
            "画板色条", "画板输入", "画画板", "画关于", "对象动作", "对象按钮",
            "画对象区", "取秒", "画窗口", "坞点击",
            "记控件", "控件在", "终端输入"],
    "主":   ["初始化", "主"],
}

说明 = {
    "内核对象": "内核层：内容寻址的对象区。全场唯一共享的状态就在这里。\n"
                "#  因为全局用 .comm 声明，链接器会把它们合并成一份 ——\n"
                "#  不管多少个模块都用它，内存里只有一个对象区。",
    "界面":     "界面层：绘图基元 + 混沌UI（译自 microui 架构）+ 部件与图标。",
    "应用":     "应用层：四个应用 + 对象区窗口。只通过内核原语访问对象。",
    "主":       "主模块：唯一带 _start 的模块。",
}


def 切块(text):
    """返回 (结构体列表, 全局列表, {函数名: 代码})"""
    lines = text.split("\n")
    i, n = 0, len(lines)
    结构体, 全局, 函数 = [], [], {}
    结构体块 = []
    while i < n:
        line = lines[i]
        s = line.strip()
        if s.startswith("jg "):
            blk = [line]
            i += 1
            while i < n and lines[i].strip() != "}":
                blk.append(lines[i])
                i += 1
            if i < n:
                blk.append(lines[i])
            i += 1
            结构体.extend(blk)
            结构体.append("")
            continue
        if s.startswith("qj "):
            全局.append(line)
            i += 1
            continue
        if s.startswith("hs "):
            m = re.match(r"hs\s+([^\s(]+)", s)
            名 = m.group(1) if m else "?"
            blk = [line]
            depth = line.count("{") - line.count("}")
            i += 1
            while i < n and depth > 0:
                blk.append(lines[i])
                depth += lines[i].count("{") - lines[i].count("}")
                i += 1
            函数[名] = "\n".join(blk)
            continue
        i += 1
    return 结构体, 全局, 函数


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    text = open(src, encoding="utf-8").read()
    结构体, 全局, 函数 = 切块(text)
    print("解析到：%d 行结构体 / %d 个全局 / %d 个函数" %
          (len(结构体), len(全局), len(函数)))

    已分 = set()
    for 模块, 名单 in 模块表.items():
        body = ["# ============================================================================",
                "#  %s  ——  由 拆分.py 从 桌面.xy 拆出，可单独编译" % 模块,
                "#  %s" % 说明.get(模块, ""),
                "# ============================================================================",
                ""]
        body += 结构体
        body.append("# ---- 全局（用 .comm 声明，链接器合并成一份）----")
        body += 全局
        body.append("")
        for f in 名单:
            if f not in 函数:
                print("  [警告] %s 里没有函数 %s" % (模块, f))
                continue
            body.append(函数[f])
            body.append("")
            已分.add(f)
        open(os.path.join(outdir, 模块 + ".xy"), "w", encoding="utf-8").write("\n".join(body))
        print("  %-10s %2d 个函数 → %s.xy" % (模块, len(名单), 模块))

    剩下 = set(函数) - 已分
    if 剩下:
        print("  [未分配] %s" % " ".join(sorted(剩下)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
