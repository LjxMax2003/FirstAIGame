#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《守艺人·百工夜行》v6 满级觉醒 —— 美术资产生成器

依据 docs/design/v6_fx_art_plan.md §3.2 / §4 + docs/design/v6_fx_art_manifest.json。

本轮交付的是**美术资产** = 4 张 SVG（1 必须 + 3 推荐）：
  ui/awaken_badge.svg      必须  Lv8 卡面觉醒角标（清单里唯一的 must 美术）
  fx/molten_blob.svg       推荐  打铁花铁水团弹体（替代当前复用的 sugar_thread）
  weapons/ink_line_tex.svg 推荐  墨斗龙筋墨线（可平铺长条）
  fx/woodblock_seal.svg    推荐  年画雕版印记（浮雕光印 / 落点预显）

清单里的 molten_scatter / lantern_stream 是 canvas_item shader（代码，不是美术资产），
由渲染达在 scripts/ShaderFX.gd + assets/shaders/fx/ 落地，本文件不产出。

落点（沿用 v5 已确认口径）：
  只写 GameDemo/first-xi-xue-gui/assets/art_shouyiren/（工程 res://），
  库 assets/craftkeepers/ 不动，绝不覆盖任何既有工程图。
边界：
  · 不改 scripts/Art.gd（登记常量 + ALL_PATHS 与调用点是工程侧的一次原子改动，见报告）。
  · 不新增武器美术、不动 12 张傩面（局外另议）、不跑 generate.mjs（它会 rmSync 非自有资产）。
  · 合规红线（v4 §2.6 延续）：不出现可读文字与宗教符号 —— 清单写的「'觉'字」改成
    剪纸火焰纹，「门神」改成莲花 + 回字边的抽象雕版纹样。
  · 清单里 #FF5C38 / #FF7A1A / #FFD16B / #FFC752 是 shader uniform 默认值，不是用色；
    SVG 一律走本包真实色板（v5_build.PALETTE 守卫会拦住越板颜色）。

用法：
  python v6_build.py --dry    只校验不写盘
  python v6_build.py          写入工程
"""

import math
import os
import sys

from v5_build import *          # 色板 / P f doc lg rg circle path rect poly shadow validate / PROJ_ART

# =====================================================================
# 局部几何助手
# =====================================================================

def ell(cx, cy, rx, ry, fill=None, stroke=None, sw=1.0, op=None):
    a = ['cx="%s"' % f(cx), 'cy="%s"' % f(cy),
         'rx="%s"' % f(rx), 'ry="%s"' % f(ry), 'fill="%s"' % (fill or "none")]
    if stroke:
        a += ['stroke="%s"' % stroke, 'stroke-width="%s"' % f(sw)]
    if op is not None:
        a.append('opacity="%s"' % f(op))
    return "<ellipse %s/>" % " ".join(a)


def sine_d(y0, amp, period, phase, x_from, x_to, step=4.0):
    """横向正弦折线。period 必须整除画布宽，接缝两侧取值才相等（可平铺）。"""
    pts = []
    x = x_from
    while x <= x_to + 1e-6:
        pts.append("%s %s" % (f(x), f(y0 + amp * math.sin(2 * math.pi * (x / period) + phase))))
        x += step
    return "M" + "L".join(pts)


def hui_hook(x, y, s, color, op, sw, flip=1, dy=1):
    """方形回钩（剪纸/雕版的「回」字），从 (x,y) 起沿 +x 走 s，折返 dy 方向。"""
    pts = [(0.0, 0.0), (s, 0.0), (s, 0.62 * s * dy), (0.36 * s, 0.62 * s * dy),
           (0.36 * s, 0.24 * s * dy), (0.72 * s, 0.24 * s * dy)]
    d = "M" + "L".join("%s %s" % (f(x + a * flip), f(y + b)) for a, b in pts)
    return path(d, stroke=color, sw=sw, op=op, cap="butt")


def hui_band(ax, ay, bx, by, n, s, step, color, op, sw):
    """回字纹带：从 A 沿带走到 B（留出一个 s 的收尾），每 step 一个方形回钩，
       钩朝法向 n 伸出。四条带按同一旋转方向走 → 经典连续回字边。"""
    dx, dy = bx - ax, by - ay
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    out = []
    k = 0.0
    while k + s <= ln + 1e-6:
        ox, oy = ax + ux * k, ay + uy * k
        pts = [(0.0, 0.0), (s, 0.0), (s, 0.66 * s), (0.34 * s, 0.66 * s),
               (0.34 * s, 0.28 * s), (0.72 * s, 0.28 * s)]
        d = "M" + "L".join(
            "%s %s" % (f(ox + a * ux + b * n[0]), f(oy + a * uy + b * n[1])) for a, b in pts)
        out.append(path(d, stroke=color, sw=sw, op=op, cap="butt"))
        k += step
    return "".join(out)


def petal(cx, cy, ang, r_in, r_out, half_w=13.0, shoulder=0.8, tip_w=5.0):
    """尖头莲瓣：底宽、肩收、尖端。"""
    pts = [P(cx, cy, r_in, ang - half_w),
           P(cx, cy, r_out * shoulder, ang - tip_w),
           P(cx, cy, r_out, ang),
           P(cx, cy, r_out * shoulder, ang + tip_w),
           P(cx, cy, r_in, ang + half_w)]
    return pts


# =====================================================================
# 1 / 4. ui/awaken_badge.svg —— 64×32 Lv8 卡面觉醒角标（must）
#    清单：朱红底 + 金边、剪纸风、叠卡面右上角、非 Lv8 隐藏。
#    「觉」字 → 火焰纹（ThorVG 不渲 <text>，且合规红线禁可读文字）。
#    贴图本身做到「半透明底 + 实心纹样」，运行时明度由 HUD 的 modulate.a 统一压。
# =====================================================================

def badge_flame(scale=1.0, cx=32.0, cy=20.0, dx=0.0):
    """剪纸火焰：左右对称的锯齿泪滴。锚点在 (cx,cy)（焰根），向上生长。"""
    raw = [(0.0, -14.5), (3.6, -9.2), (2.6, -6.6), (6.4, -3.4), (5.0, 0.6),
           (7.4, 2.0), (2.6, 5.2), (0.0, 4.0),
           (-2.6, 5.2), (-7.4, 2.0), (-5.0, 0.6), (-6.4, -3.4), (-2.6, -6.6), (-3.6, -9.2)]
    return [(cx + x * scale + dx, cy + y * scale) for x, y in raw]


def awaken_badge():
    body = []
    # 底：朱红圆角牌（上亮下暗，剪纸纸面感）。做成「半透明朱印」而不是实心块 ——
    # 卡面是纸纹，角标像盖上去的印，透得出纸纹（实测平均 alpha 压在 0.75 以下）
    body.append(rect(2.0, 2.0, 60.0, 28.0, rx=7.0, fill="url(#abP)"))
    # 金边（外粗内细两道，与 refine_badge / skill_rank_rim 的描边型同族）
    body.append(rect(2.0, 2.0, 60.0, 28.0, rx=7.0, stroke=GOLD, sw=2.0, op=0.95))
    body.append(rect(4.8, 4.8, 54.4, 22.4, rx=5.2, stroke=CREAM, sw=0.7, op=0.26))
    # 中央火焰：外焰 + 内焰 + 四点火星
    body.append(poly(badge_flame(1.0), fill=AMBER, opacity=0.95))
    body.append(poly(badge_flame(0.5, cx=32.0, cy=21.6), fill=CREAM_PALE, opacity=0.9))
    body.append(circle(41.5, 8.5, 1.3, fill=CREAM_PALE, op=0.62))
    body.append(circle(22.5, 10.5, 1.0, fill=CREAM_PALE, op=0.52))
    body.append(circle(45.5, 23.5, 0.9, fill=AMBER, op=0.6))
    body.append(circle(18.5, 23.5, 1.0, fill=AMBER, op=0.55))
    # 左右回字钩（雕版味，同时把两侧空白填成「有纹样」而不是空牌）
    body.append(hui_hook(7.6, 14.8, 8.8, GOLD, 0.8, 1.5, flip=1, dy=1))
    body.append(hui_hook(56.4, 14.8, 8.8, GOLD, 0.8, 1.5, flip=-1, dy=1))
    # 焰座三重阶（Lv8「满级」的读数，非文字）
    body.append(rect(23.0, 25.8, 18.0, 1.6, rx=0.8, fill=GOLD_DEEP, op=0.78))
    body.append(rect(26.6, 27.7, 10.8, 1.0, rx=0.5, fill=GOLD_DEEP, op=0.5))
    defs = lg("abP", [(0, SEAL_LIGHT, 0.66), (0.55, CINNABAR, 0.6), (1, CINNABAR_DEEP, 0.58)],
              0, 2.0, 0, 30.0, unit="user")
    return doc(64, 32, "".join(body), defs)


# =====================================================================
# 2 / 4. fx/molten_blob.svg —— 24×24 打铁花铁水团（recommended）
#    替代 BULLET_GLOWSTICK = sugar_thread.svg：要读得出「熔铁」不是「糖丝」。
#    按加法混合的写法出图：alpha 承载亮度衰减（半透明处加得少），
#    rgb 保持橙红/奶白的高温色，不画暗壳 —— 加法下暗色只会糊成脏红。
# =====================================================================

def molten_blob():
    body = []
    # 外晕：橙红，alpha 从 .5 衰减到 0（半径 11.2 = 留 0.8 余量，画布边不被裁出硬切）
    body.append(circle(12, 12, 11.2, fill="url(#mbH)"))
    # 熔核：不规则铁水滴（半径抖动，避免读成圆点）
    rr = [6.4, 5.0, 6.1, 4.6, 6.3, 5.4, 4.8, 6.7]
    core = [P(11.6, 11.8, rr[i], -90 + i * 45) for i in range(8)]
    body.append(poly(core, fill="url(#mbC)"))
    # 核内白热斑
    body.append(circle(10.4, 10.2, 2.5, fill=CREAM_PALE, op=0.85))
    body.append(circle(13.8, 13.6, 1.5, fill=AMBER, op=0.8))
    # 甩出的铁水星子：molten_scatter 的「小尺度预告」
    body.append(star(18.6, 5.4, 2.8, CREAM_PALE, 0.5, 18))
    body.append(circle(20.2, 4.2, 1.0, fill=AMBER, op=0.75))
    body.append(circle(3.4, 18.2, 1.2, fill=LANTERN, op=0.7))
    body.append(circle(18.4, 19.6, 0.9, fill=AMBER, op=0.6))
    body.append(circle(2.8, 6.6, 0.8, fill=LANTERN, op=0.5))
    # 一道掠过的亮筋（熔铁的表面流动感）
    body.append(path("M7.2 14.6q2.6 2.2 6.2 1.4", stroke=CREAM_PALE, sw=1.0, op=0.45, cap="round"))
    defs = (rg("mbH", 12, 12, 11.2,
               [(0, LANTERN, 0.48), (0.46, LANTERN, 0.28), (0.76, CINNABAR, 0.1), (1, CINNABAR, 0.0)]) +
            rg("mbC", 11.0, 11.2, 7.0,
               [(0, CREAM_PALE, 0.95), (0.42, AMBER, 0.9), (0.78, LANTERN, 0.72), (1, CINNABAR, 0.35)]))
    return doc(24, 24, "".join(body), defs)


# =====================================================================
# 3 / 4. weapons/ink_line_tex.svg —— 256×8 墨斗龙筋墨线（recommended）
#    用法：墨斗沿 玩家→目标 拉伸/平铺成直线，Lv8 改 scale.y 加粗。
#    平铺纪律：纹样周期 64（256 = 4 周期），横向贯通元素一律画到画布外（-2..258）
#    靠 viewBox 裁齐，接缝不留帽；结节正好骑在 0/256 缝上，两半拼回一个整结。
# =====================================================================

def ink_line_tex():
    body = []
    # 墨线本体（贯通，天然无缝）
    body.append(rect(-2, 2.05, 260, 3.9, fill=INK, op=0.9))
    # 暗青上下描边（清单：墨色 + 暗青描边）。贯通线画到画布外，接缝靠 viewBox 裁齐
    body.append(path("M-2 2.05H258", stroke=TEAL_DEEP, sw=1.1, op=0.8))
    body.append(path("M-2 5.95H258", stroke=TEAL_DEEP, sw=1.1, op=0.8))
    # 龙筋：三股错相 120° 的正弦拧成一根绳（周期 64 → 接缝处相位一致）
    body.append(path(sine_d(4.0, 1.15, 64, 0.0, -4, 260), stroke=TEAL, sw=1.25, op=0.8))
    body.append(path(sine_d(4.0, 1.15, 64, 2 * math.pi / 3.0, -4, 260), stroke=INK_SOFT, sw=1.25, op=0.9))
    body.append(path(sine_d(4.0, 1.15, 64, 4 * math.pi / 3.0, -4, 260), stroke=GOLD_DEEP, sw=0.7, op=0.5))
    # 亮筋（湿墨反光），只压一点点，别把整根线洗白
    body.append(path(sine_d(3.1, 0.5, 64, 0.5, -2, 258, 4), stroke=CREAM_PALE, sw=0.55, op=0.2))
    # 结节：每 64 一个，骑在接缝上
    for k in range(5):
        x = k * 64
        body.append(ell(x, 4.0, 2.3, 2.15, fill=INK_SOFT, stroke=TEAL, sw=0.8, op=0.85))
        body.append(circle(x, 4.0, 0.7, fill=CREAM_PALE, op=0.35))
    defs = ""
    return doc(256, 8, "".join(body), defs)


# =====================================================================
# 4 / 4. fx/woodblock_seal.svg —— 160×160 年画雕版印记（recommended）
#    清单：方形阴刻印（门神/莲花/回字边）+ 金线描边，落点预显与落地浮雕光印。
#    门神 → 换成莲花 + 回字边（合规红线：不画神像脸）；
#    阴刻的「刻掉」用低透明度朱红面表示，线条是留墨的金线。
#    这是叠在敌人/地面上的一层，峰值 alpha 压在 0.85 以下（与 surge_ring 同口径）。
# =====================================================================

def woodblock_seal():
    cx = cy = 80.0
    body = []
    # 落地底光：一圈暖辉，压得很低，让印子读成「压出来的光」而不是贴纸
    body.append(circle(80, 80, 74, fill="url(#wsG)"))
    # 雕版版面（木色低透 = 阴刻刻掉的面）
    body.append(rect(9, 9, 142, 142, rx=5, fill="url(#wsP)", op=0.9))
    # 阴刻细纹：米字刀路，只在框内（压得很低，只给「刻过」的质感，不抢纹样）
    for d in ["M38 38L122 122", "M122 38L38 122", "M80 36L80 124", "M36 80L124 80"]:
        body.append(path(d, stroke=CINNABAR_DEEP, sw=1.0, op=0.1))
    # 边框：外粗内细两道金线
    body.append(rect(9.5, 9.5, 141, 141, rx=5, stroke=GOLD, sw=2.2, op=0.74))
    body.append(rect(31.0, 31.0, 98, 98, stroke=GOLD, sw=1.2, op=0.58))
    body.append(rect(34.5, 34.5, 91, 91, stroke=GOLD_DEEP, sw=0.9, op=0.38))
    # 回字纹带：四条边同向连续（经典雕版回字边）
    body.append(hui_band(34, 31, 126, 31, (0, -1), 13.0, 23.0, GOLD, 0.6, 1.3))
    body.append(hui_band(129, 34, 129, 126, (1, 0), 13.0, 23.0, GOLD, 0.6, 1.3))
    body.append(hui_band(126, 129, 34, 129, (0, 1), 13.0, 23.0, GOLD, 0.6, 1.3))
    body.append(hui_band(31, 126, 31, 34, (-1, 0), 13.0, 23.0, GOLD, 0.6, 1.3))
    # 四角角花：双层方回，落在带子不经过的对角位
    for (px, py) in [(20, 20), (140, 20), (20, 140), (140, 140)]:
        body.append(rect(px - 5, py - 5, 10, 10, stroke=GOLD, sw=1.2, op=0.56))
        body.append(rect(px - 2.2, py - 2.2, 4.4, 4.4, stroke=GOLD_DEEP, sw=0.9, op=0.46))
    # 莲瓣：外八瓣 + 内八瓣错 22.5°
    # ⚠️ 用 fill-opacity / stroke-opacity 分开控：整元素 opacity 会把金线一起压到 .26，
    #    实测在深浅底上都会糊成「没有描边」的一团（v6 第一版就踩了这个）。
    for i in range(8):
        ang = -90 + i * 45
        body.append(poly(petal(cx, cy, ang, 20, 42), fill=CINNABAR, fill_opacity="0.26",
                         stroke=GOLD, stroke_opacity="0.7", stroke_width="1.4"))
    for i in range(8):
        ang = -90 + 22.5 + i * 45
        body.append(poly(petal(cx, cy, ang, 12, 27, 11, 0.78, 4), fill=AMBER, fill_opacity="0.2",
                         stroke=GOLD, stroke_opacity="0.58", stroke_width="1.1"))
    # 莲蓬：只留一圈 outline + 7 个莲房孔，别在中心叠实
    body.append(circle(80, 80, 10, fill=SEAL_LIGHT, op=0.34))
    body.append(circle(80, 80, 10, stroke=GOLD_DEEP, sw=1.2, op=0.5))
    body.append(circle(80, 80, 1.6, fill=GOLD, op=0.52))
    for i in range(6):
        px, py = P(80, 80, 5.4, -90 + i * 60)
        body.append(circle(px, py, 1.4, fill=GOLD, op=0.5))
    defs = (rg("wsG", 80, 80, 74,
               [(0, LANTERN, 0.14), (0.6, CINNABAR, 0.08), (1, CINNABAR_DEEP, 0.0)]) +
            lg("wsP", [(0, WOOD_DEEP, 0.22), (0.5, WOOD, 0.18), (1, WOOD_DEEP, 0.22)],
               0, 9, 0, 151, unit="user"))
    return doc(160, 160, "".join(body), defs)


# =====================================================================
# 产出
# =====================================================================

ASSETS6 = [
    ("ui/awaken_badge.svg", "64x32", "觉醒徽记（Lv8 卡面角标）", awaken_badge),
    ("fx/molten_blob.svg", "24x24", "铁水团（打铁花弹体）", molten_blob),
    ("weapons/ink_line_tex.svg", "256x8", "墨斗·龙筋墨线（可平铺）", ink_line_tex),
    ("fx/woodblock_seal.svg", "160x160", "年画·雕版印记（莲花回字边）", woodblock_seal),
]

OWNED6 = {os.path.basename(r) for r, _, _, _ in ASSETS6}


def main():
    dry = "--dry" in sys.argv
    if not os.path.isdir(PROJ_ART):
        sys.exit("工程美术目录不存在：%s" % PROJ_ART)
    problems, written = [], []
    for rel, size, title, fn in ASSETS6:
        svg = fn()
        errs = validate(rel, svg, size)
        target = os.path.join(PROJ_ART, rel.replace("/", os.sep))
        if os.path.dirname(target).replace("\\", "/").startswith(ROOT.replace("\\", "/")):
            errs.append("refusing to write into the library")
        if os.path.exists(target) and os.path.basename(target) not in OWNED6:
            errs.append("would overwrite existing project art")
        if errs:
            problems.append((rel, errs))
            continue
        if not dry:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(svg)
        written.append(rel)
        print("OK  %-30s %6d B  %-7s %s" % (rel, len(svg.encode("utf-8")), size, title))
    if problems:
        for rel, errs in problems:
            print("FAIL %s: %s" % (rel, "; ".join(errs)))
        sys.exit(1)
    print("\n%d/4 产出，校验通过（%s）" % (len(written), "dry-run" if dry else PROJ_ART))


if __name__ == "__main__":
    main()
