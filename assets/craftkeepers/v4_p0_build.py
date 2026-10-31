# -*- coding: utf-8 -*-
"""
v4 P0 美术资产生成器（17 张 SVG）
依据：docs/design/art-requirements-v4.md §3.1 / §4 / §10

- 只写入本脚本登记过的 17 个新文件名，绝不触碰旧素材
- 与 assets/craftkeepers/generate.mjs 完全无关，不重跑它
- 浆壳兵以现有母图为底，逐字节保留接触阴影与锚点，只插入壳组
用法：python v4_p0_build.py [--dry]
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(ROOT, "art_shouyiren")

# ---- 色板（art-requirements-v4.md §2.2，与 lib.mjs 一致）----
NIGHT = "#0F1B2D"; NIGHT_DEEP = "#08111E"
INK = "#1A1A1A"; INK_SOFT = "#2B2F3A"
CINNABAR = "#C53B2E"; CINNABAR_DEEP = "#8E2A20"
LANTERN = "#F2A03D"; AMBER = "#E8B04B"
GOLD = "#D9A441"; GOLD_DEEP = "#A8781F"
TEAL = "#3E7C74"; TEAL_DEEP = "#24524C"
CREAM = "#F4E8D0"; CREAM_DIM = "#D6C4A2"
GRAY = "#6B7A8F"; ASH = "#495468"
WOOD = "#5A3B25"; WOOD_DEEP = "#3B2617"; WOOD_LIGHT = "#7A5133"
CYAN = "#B8F6FF"


def P(cx, cy, r, deg):
    a = math.radians(deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def f(v):
    return ("%g" % round(v, 2))


def doc(w, h, body, defs=""):
    d = ("  <defs>%s</defs>\n" % defs) if defs else ""
    return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s%s\n</svg>\n' % (w, h, w, h, d, body)


def lg(gid, stops, x1, y1, x2, y2, unit="obj"):
    """显式方向的线性渐变；unit='user' 时按用户坐标（跨图元共用同一明暗）"""
    inn = ' gradientUnits="userSpaceOnUse"' if unit == "user" else ""
    s = "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (f(o), c, f(a))
                for o, c, a in stops)
    return '<linearGradient id="%s"%s x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>' % (
        gid, inn, x1, y1, x2, y2, s)


def rg(gid, cx, cy, r, stops):
    """径向渐变必须 userSpaceOnUse，否则 Godot/ThorVG 画到框外变透明"""
    s = "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (f(o), c, a)
                for o, c, a in stops)
    return '<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">%s</radialGradient>' % (
        gid, cx, cy, r, s)


def arc_d(cx, cy, r, a0, a1):
    x0, y0 = P(cx, cy, r, a0); x1, y1 = P(cx, cy, r, a1)
    large = 1 if abs(a1 - a0) % 360 > 180 else 0
    return "M%s %sA%s %s 0 %d 1 %s %s" % (f(x0), f(y0), f(r), f(r), large, f(x1), f(y1))


def ring_segments(cx, cy, r, gap_centers, gap_half, sw, color, opacity):
    out = []
    for gc in gap_centers:
        a0 = gc + gap_half; a1 = gc + 360 / len(gap_centers) - gap_half
        out.append('<path d="%s" stroke="%s" stroke-width="%s" fill="none" opacity="%s" stroke-linecap="round"/>'
                   % (arc_d(cx, cy, r, a0, a1), color, f(sw), f(opacity)))
    return "".join(out)


def poly(points, **kw):
    pts = " ".join("%s,%s" % (f(x), f(y)) for x, y in points)
    attrs = "".join(' %s="%s"' % (k.replace("_", "-"), v) for k, v in kw.items())
    return '<polygon%s points="%s"/>' % ("", pts) if not attrs else '<polygon%s points="%s"/>' % (attrs, pts)


def octagon(cx, cy, r, rot=-90.0):
    return [P(cx, cy, r, rot + i * 45) for i in range(8)]


# =====================================================================
# 1. weapons/gong_icon.svg —— 铜锣图标 48×48
# =====================================================================
def gong_icon():
    cx, cy, R = 21.0, 26.0, 17.0
    defs = (
        lg("giC", [(0, AMBER, 1), (0.55, GOLD, 1), (1, GOLD_DEEP, 1)], 0, 0, 0, 1)
        + lg("giB", [(0, CREAM, 1), (0.5, AMBER, 1), (1, GOLD, 1)], 0, 0, 0, 1)
    )
    b = []
    b.append('<ellipse cx="21" cy="43.2" rx="14" ry="2.6" fill="%s" opacity="0.3"/>' % NIGHT_DEEP)
    b.append('<circle cx="%s" cy="%s" r="%s" fill="url(#giC)"/>' % (f(cx), f(cy), f(R)))
    # 4px 厚外圈
    b.append('<circle cx="%s" cy="%s" r="15" fill="none" stroke="%s" stroke-width="4" opacity="0.55"/>' % (f(cx), f(cy), GOLD_DEEP))
    b.append('<circle cx="%s" cy="%s" r="12.6" fill="none" stroke="%s" stroke-width="0.9" opacity="0.4"/>' % (f(cx), f(cy), CREAM))
    # 8 颗铜钉（在外圈上）
    for i in range(8):
        sx, sy = P(cx, cy, 15, -90 + i * 45)
        b.append('<circle cx="%s" cy="%s" r="1.35" fill="%s" opacity="0.9"/>' % (f(sx), f(sy), AMBER))
    # 中心鼓包 10px
    b.append('<circle cx="%s" cy="%s" r="5" fill="url(#giB)"/>' % (f(cx), f(cy)))
    b.append('<path d="M%s %sA5 5 0 0 1 %s %s" stroke="%s" stroke-width="1.5" fill="none" opacity="0.6"/>'
             % (f(cx - 4.4), f(cy + 2.3), f(cx + 2.3), f(cy - 4.4), CREAM))
    # 左上暖高光 / 右下冷影（统一光源）
    b.append('<path d="%s" stroke="%s" stroke-width="1.8" fill="none" opacity="0.5" stroke-linecap="round"/>'
             % (arc_d(cx, cy, 9.5, 195, 250), CREAM))
    b.append('<path d="%s" stroke="%s" stroke-width="2" fill="none" opacity="0.35" stroke-linecap="round"/>'
             % (arc_d(cx, cy, 9.5, 15, 70), ASH))
    # 短木槌（右上约 45°）
    b.append('<path d="M33 14L41 6" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % WOOD)
    b.append('<circle cx="31.6" cy="15.4" r="3.7" fill="%s"/>' % WOOD_LIGHT)
    b.append('<circle cx="30.6" cy="14.4" r="1.4" fill="%s" opacity="0.55"/>' % CREAM)
    b.append('<path d="M34.4 11.6l3.2 3.2" stroke="%s" stroke-width="1.6" opacity="0.85"/>' % CINNABAR)
    # 顶部朱砂绳结
    b.append('<path d="M13 11q8-7 16 0" stroke="%s" stroke-width="1.8" fill="none" opacity="0.9"/>' % CINNABAR)
    b.append('<circle cx="21" cy="7.2" r="2.1" fill="%s"/>' % CINNABAR)
    b.append('<circle cx="20.3" cy="6.6" r="0.7" fill="%s" opacity="0.5"/>' % CREAM)
    return doc(48, 48, "".join(b), defs)


# =====================================================================
# 2. weapons/gong_aura.svg —— 铜锣世界光环 256×256
# =====================================================================
def gong_aura():
    cx = cy = 128.0
    gaps = [45, 135, 225, 315]
    defs = rg("gaR", cx, cy, 122, [
        (0, GOLD, 0), (0.33, GOLD, 0), (0.80, GOLD, 0.04), (1.0, AMBER, 0.07)])
    b = []
    b.append('<circle cx="128" cy="128" r="122" fill="url(#gaR)"/>')
    # 主环：中心线 r=121.5、环宽 9.6（116.7..126.3），4 个槌击缺口
    # 外缘刻意收在 126.3（<127）：ThorVG 圆弧描边会有 ~1px 多边形化外凸，留出不被画布裁掉的余量
    # 校核定参：主环 0.34 + 收边线 0.18 = 0.52，留出 <=0.55 的余量（叠加会算两次 alpha）
    b.append(ring_segments(cx, cy, 121.5, gaps, 7, 9.6, GOLD, 0.34))
    b.append(ring_segments(cx, cy, 125.6, gaps, 7, 1.4, GOLD_DEEP, 0.18))
    b.append(ring_segments(cx, cy, 117.4, gaps, 7, 1.4, GOLD_DEEP, 0.18))
    # 12 颗铜钉 r=112（钉身 0.42 + 钉心高光 0.14 = 0.56 峰值出现在同一像素 → 降到 0.40/0.12）
    for i in range(12):
        sx, sy = P(cx, cy, 112, i * 30)
        b.append('<circle cx="%s" cy="%s" r="3" fill="%s" opacity="0.40"/>' % (f(sx), f(sy), GOLD))
        b.append('<circle cx="%s" cy="%s" r="1.2" fill="%s" opacity="0.12"/>' % (f(sx), f(sy), CREAM))
    # 两道回声环（不与铜钉同心，避免叠加）
    b.append('<circle cx="128" cy="128" r="100" fill="none" stroke="%s" stroke-width="2" opacity="0.18"/>' % GOLD)
    b.append('<circle cx="128" cy="128" r="84" fill="none" stroke="%s" stroke-width="1.4" opacity="0.1"/>' % AMBER)
    # 4 处槌击余震短刻度（缺口位，落在 r=103..108，避开 r=100 回声环）
    for gc in gaps:
        x0, y0 = P(cx, cy, 108, gc); x1, y1 = P(cx, cy, 103, gc)
        b.append('<path d="M%s %sL%s %s" stroke="%s" stroke-width="2" opacity="0.2" stroke-linecap="round"/>'
                 % (f(x0), f(y0), f(x1), f(y1), GOLD_DEEP))
    return doc(256, 256, "".join(b), defs)


# =====================================================================
# 3. weapons/inkline_icon.svg —— 墨斗图标 48×48
# =====================================================================
def inkline_icon():
    defs = lg("ikW", [(0, WOOD_LIGHT, 1), (0.55, WOOD, 1), (1, WOOD_DEEP, 1)], 0, 0, 0, 1)
    b = []
    b.append('<ellipse cx="20" cy="43" rx="15" ry="2.6" fill="%s" opacity="0.3"/>' % NIGHT_DEEP)
    # 斗身 28×18
    b.append('<rect x="5" y="20" width="28" height="18" rx="2" fill="url(#ikW)"/>')
    b.append('<rect x="5" y="20" width="28" height="2.2" fill="%s" opacity="0.3"/>' % CREAM)
    b.append('<path d="M8 30h9M8 34h13" stroke="%s" stroke-width="0.9" opacity="0.55"/>' % WOOD_DEEP)
    b.append('<path d="M7 24l4-1" stroke="%s" stroke-width="1" opacity="0.5"/>' % TEAL)
    # 线轮
    b.append('<circle cx="14" cy="29" r="6" fill="%s"/>' % CREAM_DIM)
    b.append('<circle cx="14" cy="29" r="2.3" fill="%s"/>' % WOOD_DEEP)
    for i in range(3):
        a = -90 + i * 120
        x0, y0 = P(14, 29, 2.6, a); x1, y1 = P(14, 29, 5.6, a)
        b.append('<path d="M%s %sL%s %s" stroke="%s" stroke-width="1" opacity="0.7"/>'
                 % (f(x0), f(y0), f(x1), f(y1), WOOD))
    # 墨槽湿墨
    b.append('<circle cx="25" cy="34.5" r="1.6" fill="%s" opacity="0.6"/>' % INK)
    # 摇柄
    b.append('<path d="M26 20l2.6-5.4" stroke="%s" stroke-width="2" stroke-linecap="round"/>' % WOOD)
    b.append('<circle cx="29" cy="13.6" r="2.1" fill="%s"/>' % WOOD_LIGHT)
    # 斗口 + 定针
    b.append('<rect x="28" y="17.4" width="6" height="3.6" rx="1" fill="%s"/>' % WOOD_DEEP)
    b.append('<path d="M33.4 17.4v-3.2" stroke="%s" stroke-width="1.2"/>' % CREAM_DIM)
    # 绷紧墨线斜向右上 + 末端墨点
    b.append('<path d="M31.4 13.6L41 7.4" stroke="%s" stroke-width="2.1" stroke-linecap="round"/>' % INK)
    b.append('<path d="M31.4 13.6L41 7.4" stroke="%s" stroke-width="0.7" stroke-linecap="round" opacity="0.5"/>' % CREAM)
    b.append('<circle cx="41.6" cy="6.8" r="2.3" fill="%s"/>' % INK)
    b.append('<circle cx="41.6" cy="6.8" r="4.2" fill="%s" opacity="0.28"/>' % INK_SOFT)
    b.append('<circle cx="40.9" cy="6.1" r="0.7" fill="%s" opacity="0.4"/>' % INK_SOFT)
    return doc(48, 48, "".join(b), defs)


# =====================================================================
# 4. weapons/inkline_beam.svg —— 墨线 256×32（左中锚点）
# =====================================================================
def inkline_beam():
    defs = (
        lg("ibCore", [(0, INK, 0), (0.031, INK, 1), (0.969, INK, 1), (1, INK, 0)], 0, 0, 1, 0)
        + lg("ibHalo", [(0, INK_SOFT, 0), (0.031, INK_SOFT, 0.35), (0.969, INK_SOFT, 0.35), (1, INK_SOFT, 0)], 0, 0, 1, 0)
    )
    defs += lg("ibLine", [(0, CREAM, 0), (0.031, CREAM, 0.5), (0.969, CREAM, 0.5), (1, CREAM, 0)], 0, 0, 1, 0)
    b = []
    b.append('<rect x="6" y="11" width="244" height="10" rx="5" fill="url(#ibHalo)"/>')
    b.append('<rect x="6" y="14.5" width="244" height="3" fill="url(#ibCore)"/>')
    b.append('<rect x="6" y="15.6" width="244" height="0.8" fill="url(#ibCore)" opacity="0.95"/>')
    # 墨线是"浸墨的棉线"：夜蓝底上纯墨黑会消失，故芯部留 1px 棉线本色（哑光，非高光）
    b.append('<rect x="6" y="15.5" width="244" height="1.0" fill="url(#ibLine)"/>')
    # 沿线纸纤维 / 干墨屑
    b.append('<circle cx="62" cy="10.4" r="0.8" fill="%s" opacity="0.12"/>' % CREAM)
    b.append('<circle cx="141" cy="21.8" r="0.9" fill="%s" opacity="0.1"/>' % CREAM)
    b.append('<circle cx="203" cy="11.6" r="0.7" fill="%s" opacity="0.12"/>' % CREAM)
    b.append('<circle cx="10" cy="16" r="2.4" fill="%s" opacity="0.5"/>' % INK)
    b.append('<circle cx="248" cy="16" r="1.8" fill="%s" opacity="0.4"/>' % INK)
    return doc(256, 32, "".join(b), defs)


# =====================================================================
# 5. weapons/inkline_impact.svg —— 墨线命中 48×48
# =====================================================================
def inkline_impact():
    defs = rg("iiR", 24, 24, 16, [(0, INK_SOFT, 0.35), (0.6, INK_SOFT, 0.16), (1, TEAL_DEEP, 0)])
    b = []
    b.append('<circle cx="24" cy="24" r="16" fill="url(#iiR)"/>')
    b.append('<circle cx="24" cy="24" r="9" fill="none" stroke="%s" stroke-width="1" opacity="0.35"/>' % TEAL_DEEP)
    # 夜蓝底上墨点会看不见：垫一小片哑光纸屑（0.22），墨点压在纸上
    b.append('<path d="M15.8 20.4L22.6 17.2L30.4 19.6L33.2 26.2L27.4 31.6L18.6 30.2Z" fill="%s" opacity="0.22"/>' % CREAM_DIM)
    b.append('<circle cx="24" cy="24" r="2.6" fill="%s"/>' % INK)
    splat = [(17.4, 18.2, 1.9, 0.8), (30.2, 20.4, 1.4, 0.7), (21.2, 31.4, 2.1, 0.75),
             (32.4, 29.6, 1.1, 0.6), (15.6, 27.4, 0.9, 0.5)]
    for x, y, r, o in splat:
        b.append('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="%s"/>' % (f(x), f(y), f(r), INK, f(o)))
    b.append('<path d="M24 24L16.4 30.6" stroke="%s" stroke-width="1.2" opacity="0.6" stroke-linecap="round"/>' % INK)
    b.append('<path d="M24 24l8.8-5.2" stroke="%s" stroke-width="1" opacity="0.5" stroke-linecap="round"/>' % INK_SOFT)
    b.append('<path d="M19 15.6q3.2 2.2 6.4 0.4" stroke="%s" stroke-width="0.9" fill="none" opacity="0.45"/>' % INK_SOFT)
    return doc(48, 48, "".join(b), defs)


# =====================================================================
# 6. weapons/print_icon.svg —— 木版年画图标 48×48
# =====================================================================
def print_icon():
    defs = lg("piW", [(0, WOOD_LIGHT, 1), (0.6, WOOD, 1), (1, WOOD_DEEP, 1)], 0, 0, 0, 1)
    b = []
    b.append('<ellipse cx="23" cy="43.6" rx="17" ry="2.4" fill="%s" opacity="0.3"/>' % NIGHT_DEEP)
    # 木刻版 30×24
    b.append('<rect x="6" y="17" width="30" height="24" rx="1.6" fill="url(#piW)"/>')
    b.append('<rect x="6" y="17" width="30" height="2" fill="%s" opacity="0.28"/>' % CREAM)
    # 版上刻线（通用纹样槽）
    b.append('<path d="M10 23h6M10 28h10M24 23h8M10 34h8M22 33h10" stroke="%s" stroke-width="1.4" opacity="0.6"/>' % WOOD_DEEP)
    b.append('<path d="M12 25.4h4v3h-4z" fill="none" stroke="%s" stroke-width="1.2" opacity="0.5"/>' % TEAL)
    # 斜压米白纸 26×20
    b.append('<g transform="rotate(-9 25 25)">')
    b.append('<rect x="13" y="15" width="25" height="19" rx="0.8" fill="%s"/>' % CREAM)
    b.append('<rect x="13" y="30.4" width="25" height="3.6" fill="%s" opacity="0.5"/>' % CREAM_DIM)
    # 纸面图案：鱼 + 水波（通用吉庆，无文字/门神）
    b.append('<path d="M18 24q4-4 9-1-2 4-9 3z" fill="%s" opacity="0.85"/>' % CINNABAR)
    b.append('<path d="M27 23l3-2v6z" fill="%s" opacity="0.8"/>' % CINNABAR_DEEP)
    b.append('<circle cx="20.6" cy="23.4" r="0.8" fill="%s"/>' % WOOD_DEEP)
    b.append('<path d="M17 29q3-2 6 0t6 0" stroke="%s" stroke-width="1.1" fill="none" opacity="0.7"/>' % TEAL)
    b.append('<path d="M17 31.6q3-2 6 0t6 0" stroke="%s" stroke-width="1" fill="none" opacity="0.45"/>' % TEAL_DEEP)
    # 朱砂抽象方印（8×8）
    b.append('<rect x="30" y="16.6" width="7.4" height="7.4" rx="0.8" fill="%s"/>' % CINNABAR)
    b.append('<path d="M32 18.6h3.4M32 22h3.4M33.4 18.6v3.4" stroke="%s" stroke-width="1.1" opacity="0.85"/>' % CREAM)
    b.append("</g>")
    # 右下角刻刀
    b.append('<path d="M31 43l7.4-5.2 2 2.8-7.4 5.2z" fill="%s"/>' % WOOD)
    b.append('<path d="M38.4 37.8l4-2.8 1.2 1.8-4 2.8z" fill="%s"/>' % CREAM_DIM)
    return doc(48, 48, "".join(b), defs)


# =====================================================================
# 7. weapons/print_zone_warn.svg —— 年画落点预警 256×256
# =====================================================================
def print_zone_warn():
    cx = cy = 128.0
    # 半径分层（避免叠色，Godot/ThorVG 实测峰值 0.46）：
    #   底纹 r<=122(<=0.10) / 朱砂框 123.7-126.7(0.42) / 十字 marks 115.5-122.5(0.40)
    #   木圈内收 r=110(109-111) / 四角卡口 角落 r=104.7 只向内伸展 / 对位点 r=104
    defs = rg("pwR", cx, cy, 122, [
        (0, CREAM, 0), (0.42, CREAM, 0), (0.80, CREAM, 0.05), (1.0, CREAM_DIM, 0.10)])
    b = []
    b.append('<circle cx="128" cy="128" r="122" fill="url(#pwR)"/>')
    # 外缘 r=124..127（对应 105 判定半径）
    b.append('<circle cx="128" cy="128" r="124.4" fill="none" stroke="%s" stroke-width="3" opacity="0.42"/>' % CINNABAR)
    b.append('<circle cx="128" cy="128" r="110" fill="none" stroke="%s" stroke-width="2" opacity="0.30"/>' % WOOD)
    # 4 个套色对位 marks（十字，非 dasharray）
    for a in (0, 90, 180, 270):
        x, y = P(cx, cy, 119, a)
        b.append('<path d="M%s %sh7M%s %sv7" stroke="%s" stroke-width="1.6" opacity="0.40"/>'
                 % (f(x - 3.5), f(y), f(x), f(y - 3.5), CREAM))
    # 四角方框卡口：轴对齐 L，两条臂都朝内，不碰木圈与外框
    for sx in (-1, 1):
        for sy in (-1, 1):
            X, Y = cx + sx * 74.0, cy + sy * 74.0
            b.append('<path d="M%s %sh%sM%s %sv%s" stroke="%s" stroke-width="2" fill="none" opacity="0.30"/>'
                     % (f(X), f(Y), f(-sx * 14.0), f(X), f(Y), f(-sy * 14.0), WOOD))
    # 内部通用吉庆纹样 alpha<=0.15，中心 r<=62 留空（纹样全部落在 r>62）
    # 上：莲（三瓣）
    b.append('<path d="M128 52q-10 10 0 20 10-10 0-20z" fill="%s" opacity="0.14"/>' % CINNABAR)
    b.append('<path d="M110 62q-2 12 12 14M146 62q2 12-12 14" stroke="%s" stroke-width="2.6" fill="none" opacity="0.12"/>' % TEAL_DEEP)
    # 右：鱼
    b.append('<path d="M182 108q16 10 22 22-14 6-24-4-6-10 2-18z" fill="%s" opacity="0.13"/>' % CINNABAR)
    b.append('<path d="M182 108l-12-8 2 14z" fill="%s" opacity="0.12"/>' % CINNABAR_DEEP)
    b.append('<circle cx="194" cy="120" r="2" fill="%s" opacity="0.14"/>' % WOOD_DEEP)
    # 下：水波
    b.append('<path d="M84 192q11-9 22 0t22 0 22 0" stroke="%s" stroke-width="3" fill="none" opacity="0.13"/>' % TEAL)
    b.append('<path d="M90 204q11-9 22 0t22 0 18 0" stroke="%s" stroke-width="2.4" fill="none" opacity="0.1"/>' % TEAL_DEEP)
    # 左：回纹
    b.append('<path d="M56 112h22v14h-14v-8h6" stroke="%s" stroke-width="2.6" fill="none" opacity="0.13"/>' % WOOD)
    b.append('<path d="M60 140h20v16h-13v-8h6" stroke="%s" stroke-width="2.2" fill="none" opacity="0.11"/>' % ASH)
    # 内圈短对位点（替代虚线）
    for i in range(16):
        a = i * 22.5
        if a % 90 == 0:
            continue
        x, y = P(cx, cy, 104, a)
        b.append('<circle cx="%s" cy="%s" r="1.4" fill="%s" opacity="0.14"/>' % (f(x), f(y), CREAM_DIM))
    return doc(256, 256, "".join(b), defs)


# =====================================================================
# 8. weapons/print_zone_stamp.svg —— 年画落点成画 256×256
# =====================================================================
def print_zone_stamp():
    cx = cy = 128.0
    # 叠色预算（成画是"平版套色"，一个像素最多两层墨）：
    #   纸底 = 错色青 0.05 + 米白 0.20 = 0.245
    #   主纹样单层 0.19 -> 0.387；错位细边 0.06 -> 0.410；眼点 0.07 -> 0.440
    #   => 印面内任意像素 <=0.45（§2.3 中心填充上限），整图最高是外框 0.45
    b = []
    # 外框（与 warn 同几何，高对比）
    b.append('<circle cx="128" cy="128" r="124.4" fill="none" stroke="%s" stroke-width="3.6" opacity="0.45"/>' % CINNABAR)
    b.append('<circle cx="128" cy="128" r="110" fill="none" stroke="%s" stroke-width="2.4" opacity="0.30"/>' % WOOD)
    b.append('<circle cx="128" cy="128" r="104.5" fill="none" stroke="%s" stroke-width="1.6" opacity="0.16"/>' % CREAM)
    # 印面：r=80（约占画幅 39%），先错色后纸白
    b.append('<circle cx="130.5" cy="130.5" r="80" fill="%s" opacity="0.05"/>' % TEAL_DEEP)
    b.append('<circle cx="128" cy="128" r="80" fill="%s" opacity="0.20"/>' % CREAM)
    # 回纹环带 r=96（在纸底之外，单层 0.26 + 错色 0.10）
    seg = []
    for i in range(12):
        x, y = P(cx, cy, 96, i * 30)
        seg.append('<rect x="%s" y="%s" width="9" height="9" fill="none" stroke="%s" stroke-width="2" opacity="0.26"/>'
                   % (f(x - 4.5), f(y - 4.5), CINNABAR))
        seg.append('<rect x="%s" y="%s" width="9" height="9" fill="none" stroke="%s" stroke-width="1.2" opacity="0.10"/>'
                   % (f(x - 2.5), f(y - 2.5), TEAL_DEEP))
    b.append("".join(seg))

    # 主纹样：单层填色 0.19 + 2px 错位细边 0.06（细边只在轮廓 1.2px 带上叠色）
    def over(path_d, fill, op=0.19):
        return ('<path d="%s" fill="%s" opacity="%s"/>' % (path_d, fill, f(op)),
                '<path d="%s" fill="none" stroke="%s" stroke-width="1.2" opacity="0.06"/>' % (path_d, TEAL_DEEP))
    p1, p2 = over("M128 82q-16 20 0 40 16-20 0-40z", CINNABAR)          # 莲
    b.append(p1); b.append(p2)
    p1, p2 = over("M150 136q22 6 30 24-18 12-34 2-8-16 4-26z", CINNABAR)  # 鱼
    b.append(p1); b.append(p2)
    b.append('<path d="M104 100q-4 18 20 24M152 100q4 18-20 24" stroke="%s" stroke-width="4" fill="none" opacity="0.08"/>' % TEAL_DEEP)
    b.append('<path d="M150 136l-16-10 3 19z" fill="%s" opacity="0.07"/>' % CINNABAR_DEEP)
    b.append('<circle cx="166" cy="148" r="2.4" fill="%s" opacity="0.07"/>' % WOOD_DEEP)
    # 水波（青绿主 + 米白错色）
    b.append('<path d="M88 176q13-12 26 0t26 0 26 0" stroke="%s" stroke-width="6" fill="none" opacity="0.20"/>' % TEAL)
    b.append('<path d="M90 178q13-12 26 0t26 0 26 0" stroke="%s" stroke-width="2.4" fill="none" opacity="0.06"/>' % CREAM)
    b.append('<path d="M96 194q13-12 26 0t26 0 20 0" stroke="%s" stroke-width="4.4" fill="none" opacity="0.14"/>' % TEAL_DEEP)
    # 左上莲叶
    b.append('<path d="M88 92q14-10 24 2-12 10-24-2z" fill="%s" opacity="0.18"/>' % CREAM_DIM)
    # 4 个套色对位 marks（r=119，臂长 ±3 → 116..122，不碰外框 123.2 与木圈 108.8）
    for a in (0, 90, 180, 270):
        x, y = P(cx, cy, 119, a)
        b.append('<path d="M%s %sh6M%s %sv6" stroke="%s" stroke-width="2" opacity="0.40"/>'
                 % (f(x - 3), f(y), f(x), f(y - 3), CREAM))
    # 纸纤维只撒在印面之外的环带（84..100），避免与纸底/纹样叠色
    fibers = []
    for i in range(22):
        a = (i * 137.5) % 360
        rr = 84 + (i * 61) % 17
        x, y = P(cx, cy, rr, a)
        fibers.append('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="%s"/>'
                      % (f(x), f(y), f(0.8 + (i % 3) * 0.4), CREAM_DIM, f(0.10 + (i % 4) * 0.02)))
    b.append("".join(fibers))
    return doc(256, 256, "".join(b))


# =====================================================================
# 9. items/passive_regen.svg —— 回春被动图标 48×48
# =====================================================================
def passive_regen():
    defs = lg("prG", [(0, CREAM, 1), (0.45, CREAM_DIM, 1), (1, TEAL_DEEP, 1)], 12, 11, 26, 42, unit="user")
    b = []
    b.append('<ellipse cx="23" cy="43.4" rx="11" ry="2.4" fill="%s" opacity="0.3"/>' % NIGHT_DEEP)
    # 窄腰葫芦（三段叠圆，共用同一 userSpace 渐变）
    b.append('<circle cx="22" cy="17" r="6" fill="url(#prG)"/>')
    b.append('<circle cx="22" cy="24.5" r="4.6" fill="url(#prG)"/>')
    b.append('<circle cx="22" cy="32.5" r="9.4" fill="url(#prG)"/>')
    # 葫芦口塞 + 腰线
    b.append('<rect x="19" y="8.6" width="6" height="3.4" rx="1.2" fill="%s"/>' % WOOD)
    b.append('<path d="M17.6 22.6q4.4 2.6 8.8 0" stroke="%s" stroke-width="1.2" fill="none" opacity="0.6"/>' % WOOD_DEEP)
    # 极小金色系绳（<=4px）
    b.append('<path d="M28.4 19.8q2.2 2.2 0 4.4" stroke="%s" stroke-width="1.4" fill="none" opacity="0.85"/>' % GOLD)
    b.append('<circle cx="28.6" cy="20.2" r="1.1" fill="%s" opacity="0.9"/>' % GOLD)
    # 米白高光
    b.append('<path d="M18 30q-2.4 6 1.6 9.6" stroke="%s" stroke-width="1.7" fill="none" opacity="0.55" stroke-linecap="round"/>' % CREAM)
    b.append('<path d="M18.6 14.4q-1.4 2.6 0 4.6" stroke="%s" stroke-width="1.3" fill="none" opacity="0.5"/>' % CREAM)
    # 新芽（8px，两片叶）
    b.append('<path d="M22 9.6q0.4-3.4 3.4-5.2" stroke="%s" stroke-width="1.7" fill="none" stroke-linecap="round"/>' % TEAL)
    b.append('<path d="M25.4 4.4q4.6-1.4 5.6 2.2-4.4 1.8-5.6-2.2z" fill="%s"/>' % TEAL)
    b.append('<path d="M24.2 6.8q-4-1.8-5.6 1.4 4 2.2 5.6-1.4z" fill="%s"/>' % TEAL_DEEP)
    # 露珠
    b.append('<path d="M35 21.6q3.6 4.6 0 6.8-3.6-2.2 0-6.8z" fill="%s" opacity="0.9"/>' % CREAM)
    b.append('<path d="M35 21.6q3.6 4.6 0 6.8-3.6-2.2 0-6.8z" fill="none" stroke="%s" stroke-width="0.9" opacity="0.6"/>' % TEAL)
    b.append('<circle cx="35.8" cy="25.6" r="0.8" fill="%s" opacity="0.7"/>' % TEAL_DEEP)
    return doc(48, 48, "".join(b), defs)


# =====================================================================
# 10. items/passive_shield.svg —— 结界被动图标（俯视油纸伞）48×48
# =====================================================================
def passive_shield():
    cx = cy = 24.0
    R = 18.0
    pts = octagon(cx, cy, R)
    b = []
    b.append('<ellipse cx="24" cy="43.6" rx="13" ry="2.2" fill="%s" opacity="0.28"/>' % NIGHT_DEEP)
    b.append(poly(pts, fill=CREAM, opacity=0.72))
    # 四片隔扇冷影，做出伞面起伏
    for i in (1, 3, 5, 7):
        a0 = -90 + i * 45
        quad = [P(cx, cy, 3.4, a0), P(cx, cy, R, a0), P(cx, cy, R, a0 + 45), P(cx, cy, 3.4, a0 + 45)]
        b.append(poly(quad, fill=TEAL if i in (1, 5) else CREAM_DIM, opacity=0.28))
    # 8 根竹骨
    for i in range(8):
        x, y = P(cx, cy, R, -90 + i * 45)
        b.append('<path d="M%s %sL%s %s" stroke="%s" stroke-width="1.3" opacity="0.85"/>'
                 % (f(cx), f(cy), f(x), f(y), WOOD))
    # 朱砂包边（八边形）
    b.append(poly(pts, fill="none", stroke=CINNABAR, stroke_width="2.6", opacity=0.95))
    b.append(poly(octagon(cx, cy, R - 3.4), fill="none", stroke=CINNABAR_DEEP, stroke_width="1", opacity=0.5))
    # 中心红线结
    b.append('<circle cx="24" cy="24" r="2.8" fill="%s"/>' % CINNABAR)
    b.append('<circle cx="23.2" cy="23.2" r="0.9" fill="%s" opacity="0.6"/>' % CREAM)
    return doc(48, 48, "".join(b))


# =====================================================================
# 11. fx/shield_ward.svg —— 护身罩 128×128（中心 44px 透明）
# =====================================================================
def shield_ward():
    cx = cy = 64.0
    # 中心 r<=22（直径 44px）必须完全透明：伞面/伞骨内缘一律从 r=26 起画
    # 叠色预算（Godot/ThorVG 实测，非估算）：
    #   包边 0.38 压在伞面 0.20 上 = 0.504  <- 全图最高
    #   伞骨 0.32 压在伞面 0.20 上 = 0.456；伞骨止于 r=47，避开八边形边带 49.5..52.1
    #   伞珠 0.28 放在面板中央 r=45（八边形边中点内缩 6px），只与伞面同像素
    R, RIN = 55.0, 26.0
    b = []
    for i in range(8):
        a0 = -90 + i * 45 + 1.5
        a1 = a0 + 42
        quad = [P(cx, cy, RIN, a0), P(cx, cy, R, a0), P(cx, cy, R, a1), P(cx, cy, RIN, a1)]
        b.append(poly(quad, fill=CREAM, opacity=0.20 if i % 2 == 0 else 0.13))
    # 8 根竹骨
    for i in range(8):
        x0, y0 = P(cx, cy, 29.0, -90 + i * 45)
        x1, y1 = P(cx, cy, 47.0, -90 + i * 45)
        b.append('<path d="M%s %sL%s %s" stroke="%s" stroke-width="1.8" opacity="0.32"/>'
                 % (f(x0), f(y0), f(x1), f(y1), WOOD))
    # 外缘朱砂包边
    b.append(poly(octagon(cx, cy, R), fill="none", stroke=CINNABAR, stroke_width="2.6", opacity=0.38))
    # 内缘收口：中心线 r=26.5、1.2px 宽 → 内缘 25.9，孔（r<=22）不沾
    b.append(poly(octagon(cx, cy, RIN + 0.5), fill="none", stroke=CINNABAR_DEEP,
                  stroke_width="1.2", opacity=0.16))
    # 8 处伞珠：面板中央（伞骨角 +22.5°），r=45 在八边形边带内侧
    for i in range(8):
        x, y = P(cx, cy, 45.0, -90 + i * 45 + 22.5)
        b.append('<circle cx="%s" cy="%s" r="1.6" fill="%s" opacity="0.28"/>' % (f(x), f(y), CINNABAR))
    return doc(128, 128, "".join(b))


# =====================================================================
# 12. fx/shield_break.svg —— 破罩 96×96
# =====================================================================
def shield_break():
    cx = cy = 48.0
    b = []
    shards = [
        (-88, 15, 22, 36, CREAM, 0.8), (-40, 16, 24, 40, CREAM_DIM, 0.72),
        (8, 15, 26, 38, CREAM, 0.66), (52, 14, 22, 34, CREAM_DIM, 0.7),
        (96, 16, 26, 42, CREAM, 0.62), (140, 14, 24, 36, CREAM_DIM, 0.68),
        (184, 15, 22, 38, CREAM, 0.58), (228, 13, 20, 32, CREAM_DIM, 0.64),
    ]
    for a, w, r0, r1, col, op in shards:
        p = [P(cx, cy, r0, a - w / 2), P(cx, cy, r1, a - w / 4),
             P(cx, cy, r1 - 3, a + w / 2), P(cx, cy, r0 + 1, a + w / 4)]
        b.append(poly(p, fill=col, opacity=op))
    # 3 片带朱砂包边的碎片
    for a in (-70, 30, 150):
        p = [P(cx, cy, 24, a - 7), P(cx, cy, 39, a), P(cx, cy, 36, a + 8)]
        b.append(poly(p, fill="none", stroke=CINNABAR, stroke_width="1.6", opacity=0.5))
    # 4 根竹篾
    for a, ln in ((-48, 24), (42, 20), (128, 22), (206, 18)):
        x0, y0 = P(cx, cy, 16, a)
        x1, y1 = P(cx, cy, 16 + ln, a)
        b.append('<path d="M%s %sL%s %s" stroke="%s" stroke-width="2" stroke-linecap="round" opacity="0.7"/>'
                 % (f(x0), f(y0), f(x1), f(y1), WOOD))
    # 1 段断红线
    b.append('<path d="M30 62q10 8 22 3 8-3 12 2" stroke="%s" stroke-width="1.8" fill="none" opacity="0.75" stroke-linecap="round"/>' % CINNABAR)
    b.append('<circle cx="30" cy="62" r="1.6" fill="%s" opacity="0.7"/>' % CINNABAR)
    # 干浆尘点
    for i in range(10):
        a = i * 36 + 11
        x, y = P(cx, cy, 44 + (i % 3) * 5, a)
        b.append('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="0.3"/>'
                 % (f(x), f(y), f(1.2 - (i % 3) * 0.3), CREAM_DIM))
    return doc(96, 96, "".join(b))


# =====================================================================
# 13~15 浆壳兵：以母图为底，只在指定层之前插入壳组
# =====================================================================
def shell_group(plates, cracks, straws, wet_edges, highlights, shrink=None, cx=24.0, cy=27.0):
    # shrink：把壳整体朝脚底锚点方向内缩，让母图的纸边/轮廓露出来（48px 仍读成原兵种）
    if shrink:
        g = ['<g transform="translate(%s %s) scale(%s)">' % (f(cx * (1 - shrink)), f(cy * (1 - shrink)), f(shrink))]
    else:
        g = ['<g>']
    for d in plates:
        g.append('<path d="%s" fill="%s" opacity="0.88"/>' % (d, CREAM_DIM))
    for d in wet_edges:
        g.append('<path d="%s" stroke="%s" stroke-width="1.4" fill="none" opacity="0.5" stroke-linecap="round"/>' % (d, TEAL_DEEP))
    for d in cracks:
        g.append('<path d="%s" stroke="%s" stroke-width="1" fill="none" opacity="0.75" stroke-linecap="round"/>' % (d, ASH))
    for d in straws:
        g.append('<path d="%s" stroke="%s" stroke-width="0.8" fill="none" opacity="0.7"/>' % (d, CREAM))
    for d in highlights:
        g.append('<path d="%s" stroke="%s" stroke-width="1" fill="none" opacity="0.5" stroke-linecap="round"/>' % (d, CREAM))
    g.append("</g>")
    return "".join(g)


def build_shell(base_file, anchor, group):
    path = os.path.join(ART, "enemies", base_file)
    with open(path, "r", encoding="utf-8") as fh:
        src = fh.read()
    if anchor not in src:
        raise SystemExit("anchor not found in %s" % base_file)
    return src.replace(anchor, group + anchor, 1)


def paper_scrap_shell():
    plates = [
        "M13.5 14.2L19 11.4L26.2 12.1L32.4 14.8L36.1 18.6L33.2 21.4L27.5 19.8L21.3 20.6L15.8 22.3L12.4 19.1Z",
        "M10.4 23.6L15.6 22.8L16.8 27.4L15.2 32.6L12.3 35.8L9.9 30.4Z",
        "M32.6 20.4L36.8 23.2L38.1 27.9L35.4 32.2L32.1 29.4L31.2 24.6Z",
        "M19.4 35.6L25.8 37.2L30.4 35.9L31.8 39.4L26.2 41.2L19.6 40.2Z",
    ]
    cracks = ["M17.8 12.6L20.4 17.2L18.6 20.8", "M28.6 13.8L30.2 18.4L28.4 20.6",
              "M12.8 26.4L15.4 30.2", "M34.2 22.6L35.8 27.4", "M23.4 36.6L26.8 39.8"]
    straws = ["M14.6 16.2l3.4 1.2", "M31.4 24.8l3-1", "M20.8 37.4l3.6 1.6"]
    wet = ["M12.4 19.1L15.8 22.3L21.3 20.6L27.5 19.8L33.2 21.4L36.1 18.6",
           "M9.9 30.4L12.3 35.8L15.2 32.6", "M32.1 29.4L35.4 32.2L38.1 27.9"]
    hi = ["M15.6 14.8L20.4 12.6L25.6 13.4", "M33.4 21.8l3.4 2.2"]
    group = shell_group(plates, cracks, straws, wet, hi, shrink=0.9)
    return build_shell("paper_scrap.svg",
                       '<path d="M17 20l5 3-2 4"', group)


def broken_kite_shell():
    plates = [
        "M12.6 15.8L18.4 12.2L22.6 15.4L20.2 20.6L14.4 21.8Z",
        "M18.6 24.4L24.8 22.6L29.6 25.8L26.4 31.2L20.2 32.4L17.2 28.6Z",
        "M22.4 8.6L26.4 10.4L24.6 13.6L21.2 12.4Z",
    ]
    cracks = ["M14.8 14.6L18.2 18.4", "M21.4 25.2L24.6 29.4", "M26.8 26.4L28.8 29.6"]
    straws = ["M15.4 17.8l3.2-1.2", "M22.6 30.2l3.6 1"]
    wet = ["M14.4 21.8L20.2 20.6L22.6 15.4", "M17.2 28.6L20.2 32.4L26.4 31.2L29.6 25.8"]
    hi = ["M13.8 17.2l3.6-2.4", "M19.8 25.4l3.8-1.4"]
    group = shell_group(plates, cracks, straws, wet, hi)
    return build_shell("broken_kite.svg",
                       '<path d="M24 6v30"', group)


def broken_puppet_shell():
    plates = [
        "M17.6 22.4L30.8 22.2L32.4 27.6L28.2 30.6L20.6 31L16.8 27.2Z",
        "M14.8 32.6L19.4 31.8L20.6 36.4L18.2 40.2L14.6 38.4Z",
        "M27.6 32.2L32.4 31.4L34.2 35.8L31.6 39.8L27.8 37.6Z",
    ]
    cracks = ["M20.4 23.4L23.2 28.6L21.4 30.8", "M28.6 24.2L30.4 28.4", "M16.4 34.4L19 38.2", "M29.4 33.6L32 37.4"]
    straws = ["M18.6 25.4l4.2-1.4", "M27.2 35.6l3.6 1.4", "M15.6 37.2l2.8-1"]
    wet = ["M16.8 27.2L20.6 31L28.2 30.6L32.4 27.6", "M14.6 38.4L18.2 40.2L20.6 36.4", "M27.8 37.6L31.6 39.8L34.2 35.8"]
    hi = ["M18.4 23.6l4.6-1", "M28.4 33.2l3-1"]
    group = shell_group(plates, cracks, straws, wet, hi)
    return build_shell("broken_puppet.svg",
                       '<path d="M17 24l-6 8 3 2 6-6z"', group)


# =====================================================================
# 16. ui/ui_geng_drum.svg —— 更鼓 HUD 图标 48×48
# =====================================================================
def ui_geng_drum():
    defs = lg("udG", [(0, "#E1573F", 1), (0.5, CINNABAR, 1), (1, CINNABAR_DEEP, 1)], 0, 0, 0, 1)
    b = []
    b.append('<ellipse cx="22" cy="43.4" rx="14" ry="2.4" fill="%s" opacity="0.3"/>' % NIGHT_DEEP)
    # 桶形鼓身 28×24（含鼓面）
    b.append('<path d="M9 15h26l1.6 17q-14.6 4.4-29.2 0z" fill="url(#udG)"/>')
    b.append('<ellipse cx="22" cy="14.6" rx="13" ry="4.2" fill="%s"/>' % CREAM)
    b.append('<ellipse cx="22" cy="14.6" rx="10.4" ry="3.2" fill="none" stroke="%s" stroke-width="1" opacity="0.6"/>' % CREAM_DIM)
    b.append('<path d="M8.2 23.4h27.6" stroke="%s" stroke-width="1.6" opacity="0.4"/>' % GOLD_DEEP)
    # 金铜鼓钉（上下两圈，短段替代虚线）
    for i in range(7):
        x = 10.5 + i * 3.9
        b.append('<circle cx="%s" cy="18.6" r="1.05" fill="%s" opacity="0.9"/>' % (f(x), GOLD))
    for i in range(6):
        x = 12 + i * 3.9
        b.append('<circle cx="%s" cy="31.4" r="1" fill="%s" opacity="0.75"/>' % (f(x), GOLD))
    b.append('<path d="M13.6 21.6q-1.2 6 0 10.8" stroke="%s" stroke-width="1.2" fill="none" opacity="0.5"/>' % CREAM)
    # 双腿鼓架 + 横撑
    b.append('<path d="M13 33l-3.4 9.6M31 33l3.4 9.6" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % WOOD)
    b.append('<path d="M11.6 38.4h20.8" stroke="%s" stroke-width="2" stroke-linecap="round"/>' % WOOD_DEEP)
    # 右侧两根交叉鼓槌
    b.append('<path d="M34.4 7.6L43.4 17.6" stroke="%s" stroke-width="2" stroke-linecap="round"/>' % WOOD)
    b.append('<path d="M43.4 7.6L34.4 17.6" stroke="%s" stroke-width="2" stroke-linecap="round"/>' % WOOD)
    b.append('<circle cx="34.4" cy="7.6" r="2.2" fill="%s"/>' % GOLD)
    b.append('<circle cx="43.4" cy="7.6" r="2.2" fill="%s"/>' % GOLD)
    b.append('<circle cx="33.8" cy="7" r="0.8" fill="%s" opacity="0.6"/>' % CREAM)
    return doc(48, 48, "".join(b), defs)


# =====================================================================
# 17. fx/drum_ripple.svg —— 跨更波纹 256×256
# =====================================================================
def drum_ripple():
    cx = cy = 128.0
    b = []
    gaps8 = [i * 45 + 22.5 for i in range(8)]
    # r=70（4px, alpha .45）与 r=110（2px, alpha .25），8 个短缺口
    b.append(ring_segments(cx, cy, 70, gaps8, 6, 4, GOLD, 0.45))
    b.append(ring_segments(cx, cy, 110, [i * 45 for i in range(8)], 5, 2, GOLD, 0.25))
    # 环上鼓面余震短刻度
    for i in range(8):
        a = i * 45 + 22.5
        x0, y0 = P(cx, cy, 76, a); x1, y1 = P(cx, cy, 86, a)
        b.append('<path d="M%s %sL%s %s" stroke="%s" stroke-width="2" opacity="0.2" stroke-linecap="round"/>'
                 % (f(x0), f(y0), f(x1), f(y1), GOLD_DEEP))
    # 4 处朱砂点（时间感，不做红黑攻击圈）
    for i in range(4):
        x, y = P(cx, cy, 110, 45 + i * 90)
        b.append('<circle cx="%s" cy="%s" r="2.2" fill="%s" opacity="0.3"/>' % (f(x), f(y), CINNABAR))
    # 内外极淡收边
    b.append('<circle cx="128" cy="128" r="60" fill="none" stroke="%s" stroke-width="1" opacity="0.1"/>' % GOLD)
    b.append('<circle cx="128" cy="128" r="122" fill="none" stroke="%s" stroke-width="1" opacity="0.08"/>' % GOLD_DEEP)
    return doc(256, 256, "".join(b))


ASSETS = [
    ("weapons/gong_icon.svg", "48x48", "铜锣·图标", gong_icon),
    ("weapons/gong_aura.svg", "256x256", "铜锣·世界光环（半径 150）", gong_aura),
    ("weapons/inkline_icon.svg", "48x48", "墨斗·图标", inkline_icon),
    ("weapons/inkline_beam.svg", "256x32", "墨斗·墨线（左中锚点）", inkline_beam),
    ("weapons/inkline_impact.svg", "48x48", "墨斗·命中墨溅", inkline_impact),
    ("weapons/print_icon.svg", "48x48", "木版年画·图标", print_icon),
    ("weapons/print_zone_warn.svg", "256x256", "木版年画·落点预警", print_zone_warn),
    ("weapons/print_zone_stamp.svg", "256x256", "木版年画·落点成画", print_zone_stamp),
    ("items/passive_regen.svg", "48x48", "回春·被动图标（药葫芦+新芽）", passive_regen),
    ("items/passive_shield.svg", "48x48", "结界·被动图标（俯视油纸伞）", passive_shield),
    ("fx/shield_ward.svg", "128x128", "结界·护身罩（中心 44px 透明）", shield_ward),
    ("fx/shield_break.svg", "96x96", "结界·破罩碎片", shield_break),
    ("enemies/paper_scrap_shell.svg", "48x48", "纸屑·浆壳变体", paper_scrap_shell),
    ("enemies/broken_kite_shell.svg", "48x48", "断线纸鸢·浆壳变体（保留青尾）", broken_kite_shell),
    ("enemies/broken_puppet_shell.svg", "48x48", "断线傀儡·浆壳变体（保留提线关节）", broken_puppet_shell),
    ("ui/ui_geng_drum.svg", "48x48", "更鼓·HUD 标识", ui_geng_drum),
    ("fx/drum_ripple.svg", "256x256", "更鼓·跨更波纹", drum_ripple),
]

# 只允许写这 17 个新文件，其他一律不碰
OWNED = {p for p, _, _, _ in ASSETS}

FORBIDDEN = ["<text", "<clipPath", "<mask", "<filter", "<image", "<style", "@keyframes",
             "stroke-dasharray", "mix-blend-mode", "href=", "url(http", "NaN", "undefined"]


def validate(rel, svg, size):
    errs = []
    w, h = size.split("x")
    if 'width="%s"' % w not in svg or 'height="%s"' % h not in svg:
        errs.append("canvas width/height mismatch")
    if 'viewBox="0 0 %s %s"' % (w, h) not in svg:
        errs.append("viewBox mismatch")
    for tok in FORBIDDEN:
        if tok in svg:
            errs.append("forbidden token: %s" % tok)
    ids = re.findall(r'\bid="([^"]+)"', svg)
    if len(ids) != len(set(ids)):
        errs.append("duplicate id")
    refs = set(re.findall(r'url\(#([^)]+)\)', svg))
    if refs - set(ids):
        errs.append("dangling url(#): %s" % (refs - set(ids)))
    for m in re.finditer(r'<radialGradient\b[^>]*>', svg):
        if 'gradientUnits="userSpaceOnUse"' not in m.group(0):
            errs.append("radialGradient without userSpaceOnUse")
    for m in re.finditer(r'<linearGradient\b[^>]*>', svg):
        tag = m.group(0)
        if not all(k in tag for k in ('x1=', 'y1=', 'x2=', 'y2=')):
            errs.append("linearGradient without explicit direction")
    try:
        import xml.etree.ElementTree as ET
        ET.fromstring(svg)
    except Exception as exc:
        errs.append("xml parse: %s" % exc)
    return errs


def main():
    dry = "--dry" in sys.argv
    problems = []
    rows = []
    for rel, size, title, fn in ASSETS:
        svg = fn()
        errs = validate(rel, svg, size)
        if errs:
            problems.append((rel, errs))
            continue
        path = os.path.join(ART, rel)
        if not dry:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(svg)
        rows.append({"file": rel, "replaces": None, "size": size, "tier": "P0",
                     "title": title, "bytes": len(svg.encode("utf-8")),
                     "source": "v4_p0_build.py", "feature": "v4"})
        print("OK  %-38s %6d B  %s" % (rel, len(svg.encode("utf-8")), size))
    if problems:
        for rel, errs in problems:
            print("FAIL %s: %s" % (rel, "; ".join(errs)))
        sys.exit(1)
    print("\n%d/17 generated, validation clean" % len(rows))
    if not dry:
        mpath = os.path.join(ROOT, "manifest.json")
        with open(mpath, "r", encoding="utf-8") as fh:
            man = json.load(fh)
        have = {a.get("file") for a in man["assets"]}
        added = 0
        for r in rows:
            if r["file"] in have:
                man["assets"] = [r if a.get("file") == r["file"] else a for a in man["assets"]]
            else:
                man["assets"].append(r)
                added += 1
        man["counts"]["new_p0_v4"] = len(rows)
        man["counts"]["total"] = len(man["assets"])
        man["v4_note"] = ("P0 v4 的 17 张由 assets/craftkeepers/v4_p0_build.py 产出，"
                          "不在 generate.mjs 里；重跑 generate.mjs 会删除它们，"
                          "重跑后需再执行 python v4_p0_build.py 复原。")
        with open(mpath, "w", encoding="utf-8") as fh:
            json.dump(man, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print("manifest.json: +%d 条，total=%d" % (added, man["counts"]["total"]))


if __name__ == "__main__":
    main()
