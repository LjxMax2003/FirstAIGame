# -*- coding: utf-8 -*-
"""
《守艺人·百工夜行》v5 新增美术资产生成器（12 张 SVG）
依据：docs/design/art_assets_manifest.json（v5 需求清单）

落点决定（用户 2026-10-28 确认）：
- 只写工程 res://（GameDemo/first-xi-xue-gui/assets/art_shouyiren/），
  素材库 assets/craftkeepers/art_shouyiren/ 一律不动。
- items/passive_regen|shield 两张在工程里按 v5 的 64×64 出，库内 48×48 的 v4 版保留，
  分歧记在 assets/craftkeepers/manifest.json。

边界：
- 不做 12 面傩戏面具（清单自标 out_of_scope_referenced，『局外另议』）。
- 不改 scripts/Art.gd 的 ALL_PATHS / SLOT_ALIASES —— 接入是工程的后续步骤。
- 不重跑 generate.mjs（它会删掉非它生成的资产）。

合规红线（沿用 v4 §2.6）：不画宗教符号（符箓/八卦/神像文字），不放可读文字。
清单里写的『符箓/八卦』『开市字样』按用户确认改为竹篾护圈+朱绳结、无字朱印。

色板用本作真实色板（lib.mjs / v4_p0_build.py 一致）。
注意：art_assets_manifest.json 里的 #C8443B / #B87333 / #2E4A7B / #3E8E5A / #9A8C7A
在现有美术包里**一处都没有出现过**，只是示意色；落地一律折算到本包色板。

用法：python v5_build.py [--dry]
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_ART = os.path.normpath(os.path.join(
    ROOT, "..", "..", "GameDemo", "first-xi-xue-gui", "assets", "art_shouyiren"))

# ---- 色板（本作真实用色，grep 过全包）----
NIGHT = "#0F1B2D"; NIGHT_DEEP = "#08111E"
INK = "#1A1A1A"; INK_SOFT = "#2B2F3A"
CINNABAR = "#C53B2E"; CINNABAR_DEEP = "#8E2A20"; SEAL_LIGHT = "#D9503F"
LANTERN = "#F2A03D"; AMBER = "#E8B04B"
GOLD = "#D9A441"; GOLD_DEEP = "#A8781F"
TEAL = "#3E7C74"; TEAL_DEEP = "#24524C"
CREAM = "#F4E8D0"; CREAM_DIM = "#D6C4A2"; CREAM_PALE = "#F4ECD8"
GRAY = "#6B7A8F"; ASH = "#495468"
STEEL = "#7A7F8C"; STEEL_DEEP = "#3B4250"
WOOD = "#5A3B25"; WOOD_MID = "#8A5C37"; WOOD_LIGHT = "#7A5133"; WOOD_DEEP = "#3B2617"
CYAN = "#B8F6FF"

FORBIDDEN = ("<text", "<mask", "<filter", "<image", "<style", "@keyframes",
             "xlink:href", "http://www.w3.org/1999/xlink", "foreignObject",
             "<animate", "<feGaussian", "clip-path", "pattern=")


def P(cx, cy, r, deg):
    a = math.radians(deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def f(v):
    return ("%g" % round(v, 2))


def doc(w, h, body, defs=""):
    d = ("  <defs>%s</defs>\n" % defs) if defs else ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
            'viewBox="0 0 %d %d">\n%s%s\n</svg>\n' % (w, h, w, h, d, body))


def lg(gid, stops, x1, y1, x2, y2, unit="obj"):
    """线性渐变必须给显式方向；unit='user' 按用户坐标（跨图元共用同一明暗）"""
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


def ring_segments(cx, cy, r, gap_centers, gap_half, sw, color, opacity, cap="round"):
    out = []
    step = 360.0 / len(gap_centers)
    for gc in gap_centers:
        a0 = gc + gap_half; a1 = gc + step - gap_half
        out.append('<path d="%s" stroke="%s" stroke-width="%s" fill="none" opacity="%s" stroke-linecap="%s"/>'
                   % (arc_d(cx, cy, r, a0, a1), color, f(sw), f(opacity), cap))
    return "".join(out)


def circle(cx, cy, r, fill=None, stroke=None, sw=1.0, op=None, dash=None):
    a = ['cx="%s"' % f(cx), 'cy="%s"' % f(cy), 'r="%s"' % f(r)]
    a.append('fill="%s"' % (fill or "none"))
    if stroke:
        a.append('stroke="%s"' % stroke)
        a.append('stroke-width="%s"' % f(sw))
        if dash:
            a.append('stroke-dasharray="%s"' % dash)
    if op is not None:
        a.append('opacity="%s"' % f(op))
    return "<circle %s/>" % " ".join(a)


def path(d, stroke=None, sw=1.0, fill=None, op=None, cap=None, dash=None):
    a = ['d="%s"' % d]
    a.append('fill="%s"' % (fill or "none"))
    if stroke:
        a.append('stroke="%s"' % stroke)
        a.append('stroke-width="%s"' % f(sw))
        if cap:
            a.append('stroke-linecap="%s"' % cap)
        if dash:
            a.append('stroke-dasharray="%s"' % dash)
    if op is not None:
        a.append('opacity="%s"' % f(op))
    return '<path %s/>' % " ".join(a)


def rect(x, y, w, h, fill=None, stroke=None, sw=1.0, rx=0.0, op=None):
    a = ['x="%s"' % f(x), 'y="%s"' % f(y), 'width="%s"' % f(w), 'height="%s"' % f(h)]
    if rx:
        a.append('rx="%s"' % f(rx))
    a.append('fill="%s"' % (fill or "none"))
    if stroke:
        a.append('stroke="%s"' % stroke)
        a.append('stroke-width="%s"' % f(sw))
    if op is not None:
        a.append('opacity="%s"' % f(op))
    return "<rect %s/>" % " ".join(a)


def poly(points, **kw):
    pts = " ".join("%s,%s" % (f(x), f(y)) for x, y in points)
    attrs = "".join(' %s="%s"' % (k.replace("_", "-"), v) for k, v in kw.items())
    return '<polygon%s points="%s"/>' % (attrs, pts)


def octagon(cx, cy, r, rot=-90.0):
    return [P(cx, cy, r, rot + i * 45) for i in range(8)]


def shadow(cx, cy, rx, ry, op=0.3):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" opacity="%s"/>' % (
        f(cx), f(cy), f(rx), f(ry), NIGHT_DEEP, f(op))


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
    # 色板守卫：只允许本包用过的颜色
    for c in set(re.findall(r'#([0-9A-Fa-f]{6})\b', svg)):
        if ("#" + c.upper()) not in PALETTE:
            errs.append("off-palette color: #%s" % c)
    try:
        import xml.etree.ElementTree as ET
        ET.fromstring(svg)
    except Exception as exc:
        errs.append("xml parse: %s" % exc)
    return errs


PALETTE = {v for k, v in globals().items()
           if k.isupper() and isinstance(v, str) and re.match(r'^#[0-9A-F]{6}$', v)}

# =====================================================================
# 1 / 8. weapons/gong.svg + gong_evolved.svg —— 铜锣 96×96（无渐变，硬边）
#    清单 weapon_gong / weapon_gong_evolved：半径 150 由 WeaponManager 控制，
#    贴图只画锣面本体，不画整圈光环。
# =====================================================================
def leiwen(cx, cy, r_in, r_out, n, color, op, sw=1.7, cross=2.2):
    """ rim 上的云雷纹/回纹刻度：径向短棱 + 外端横向小杠，n 等分。
        注意：小杠方向必须归一化，否则切线向量的模是半径长度，会炸成一圈尖刺。"""
    out = []
    for i in range(n):
        deg = -90 + i * (360.0 / n)
        x0, y0 = P(cx, cy, r_in, deg)
        x1, y1 = P(cx, cy, r_out, deg)
        out.append(path("M%s %sL%s %s" % (f(x0), f(y0), f(x1), f(y1)),
                        stroke=color, sw=sw, op=op))
        # 外端小杠：沿切线方向，构成「回」的转角读感
        tx, ty = P(cx, cy, r_out, deg + 90)
        vx, vy = tx - x1, ty - y1
        norm = math.hypot(vx, vy) or 1.0
        vx, vy = vx / norm * cross / 2.0, vy / norm * cross / 2.0
        out.append(path("M%s %sL%s %s" % (f(x1 - vx), f(y1 - vy), f(x1 + vx), f(y1 + vy)),
                        stroke=color, sw=sw * 0.8, op=op))
    return "".join(out)


def gong_svg(evolved=False):
    cx, cy, R = 48.0, 54.0, 36.0
    b = []
    # —— 悬挂：朱红布绳 + 绳结 + 锣耳（先画，锣面压在上面）——
    b.append(path("M40 12L45.4 19", stroke=CINNABAR, sw=2.6, op=0.9))
    b.append(path("M56 12L50.6 19", stroke=CINNABAR, sw=2.6, op=0.9))
    b.append(path("M38 11q10-8 20 0", stroke=CINNABAR, sw=2.4, op=0.75))
    b.append(poly([(44.2, 20.4), (51.8, 20.4), (50.4, 15.0), (45.6, 15.0)],
                  fill=GOLD_DEEP))
    # —— 锣面：外圈翻边 + 内面，纯硬边，不用渐变 ——
    b.append(circle(cx, cy, R + 1.5 if evolved else R,
                    fill=GOLD_DEEP, stroke=AMBER if evolved else None,
                    sw=1.4, op=0.9 if evolved else None))
    b.append(circle(cx, cy, 30.0, fill=GOLD))
    # 统一光源：左上暖高光 / 右下冷影
    b.append(path(arc_d(cx, cy, 33.2, 196, 252), stroke=AMBER, sw=3.0, op=0.6, cap="round"))
    b.append(path(arc_d(cx, cy, 33.2, 18, 74), stroke=NIGHT_DEEP, sw=3.0, op=0.26, cap="round"))
    # —— 边缘回纹/云雷纹 ——
    b.append(leiwen(cx, cy, 30.6, 35.4, 16 if evolved else 12, AMBER, 0.78))
    # —— 朱红点缀：3 段漆在翻边上的短线 ——
    for deg in (30, 150, 270):
        b.append(path(arc_d(cx, cy, 33.2, deg - 7, deg + 7), stroke=CINNABAR, sw=2.6, op=0.85))
    # —— 内面两道车沟 ——
    b.append(circle(cx, cy, 24.5, fill="none", stroke=GOLD_DEEP, sw=1.6, op=0.5))
    b.append(circle(cx, cy, 20.5, fill="none", stroke=CREAM, sw=1.0, op=0.32))
    if evolved:
        b.append(circle(cx, cy, 27.2, fill="none", stroke=CREAM, sw=1.2, op=0.42, dash="7 5"))
        b.append(leiwen(cx, cy, 15.6, 19.4, 8, GOLD_DEEP, 0.5, sw=1.4, cross=2.6))
    # —— 中心：锤击凹痕 / 进化改无字朱印 ——
    if not evolved:
        b.append(circle(cx, cy, 10.5, fill=AMBER))
        b.append(circle(cx, cy, 10.5, fill="none", stroke=GOLD_DEEP, sw=1.3, op=0.55))
        b.append(path(arc_d(cx, cy, 7.4, 198, 252), stroke=CREAM, sw=1.8, op=0.55, cap="round"))
        for deg in (0, 120, 240):
            sx, sy = P(cx, cy, 5.6, deg)
            b.append(path(arc_d(sx, sy, 2.6, deg + 100, deg + 260),
                          stroke=CINNABAR_DEEP, sw=1.2, op=0.5))
        b.append(circle(cx, cy, 2.4, fill=CINNABAR, op=0.9))
    else:
        # 无字朱印：圆角方印 + 抽象印文（合规：不成字、不可读）
        s = 11.0
        b.append(rect(cx - s, cy - s, 2 * s, 2 * s, rx=2.6, fill=CINNABAR, op=0.92))
        b.append(rect(cx - s, cy - s, 2 * s, 2 * s, rx=2.6, fill="none", stroke=CREAM, sw=1.5, op=0.9))
        b.append(rect(cx - s + 2.6, cy - s + 2.6, 2 * s - 5.2, 2 * s - 5.2,
                      rx=1.4, fill="none", stroke=CREAM, sw=0.9, op=0.4))
        # 印面「纹路」：一横一竖加两个折，抽象化处理，不组成任何字
        b.append(path("M41.6 45.6h13.2", stroke=CREAM, sw=1.7, op=0.8))
        b.append(path("M48 47.4V61", stroke=CREAM, sw=1.7, op=0.8))
        b.append(path("M41.4 51.2q3.4 3.4 0 6.4M54.6 51.2q-3.4 3.4 0 6.4",
                      stroke=CREAM, sw=1.3, op=0.6))
        b.append(circle(cx - s + 1.6, cy - s + 1.6, 1.1, fill=GOLD, op=0.85))
        # 印角缺口（手刻崩边）
        b.append(rect(cx + s - 3.4, cy + s - 3.4, 3.4, 3.4, fill=GOLD_DEEP, op=0.55))
    # —— 顶部绳结压在最上层 ——
    b.append(circle(48, 8.4, 3.4, fill=CINNABAR))
    b.append(circle(46.9, 7.3, 1.1, fill=CREAM, op=0.5))
    b.append(path("M44.2 10.6q3.8 3.4 7.6 0", stroke=CINNABAR_DEEP, sw=1.3, op=0.7))
    if evolved:
        b.append(circle(48, 8.4, 5.2, fill="none", stroke=GOLD, sw=1.3, op=0.8))
    return doc(96, 96, "".join(b))


def gong():
    return gong_svg(False)


def gong_evolved():
    return gong_svg(True)


# =====================================================================
# 2 / 9. weapons/inkline.svg 220×16 + inkline_evolved.svg 220×18
#    清单 weapon_inkline：木线盒 + 笔直墨线 + 线端小坠；长度方向 = 飞行轴。
#    实测教训（v4 §7.2）：纯墨 #1A1A1A 芯线在夜色地面上不可见，
#    必须叠一条米白「棉线芯」，故本图保留 0.5 的米白发丝线。
# =====================================================================
def inkline_svg(evolved=False):
    h = 18 if evolved else 16
    w = 220
    cy = h / 2.0
    defs = (
        lg("ilWood", [(0, WOOD_LIGHT, 1), (0.55, WOOD, 1), (1, WOOD_DEEP, 1)],
           0, 2, 0, h - 2, unit="user")
        + lg("ilHalo", [(0, INK_SOFT, 0), (0.05, INK_SOFT, 0.34),
                        (0.9, INK_SOFT, 0.34), (1, INK_SOFT, 0)], 18, 0, 208, 0, unit="user")
        + lg("ilCore", [(0, INK, 0.2), (0.05, INK, 1), (0.9, INK, 1), (1, INK, 0.35)],
             18, 0, 208, 0, unit="user")
        + lg("ilThread", [(0, CREAM, 0), (0.06, CREAM, 0.62 if evolved else 0.5),
                          (0.88, CREAM, 0.62 if evolved else 0.5), (1, CREAM, 0)],
             18, 0, 208, 0, unit="user")
    )
    if evolved:
        defs += lg("ilGold", [(0, GOLD, 0), (0.06, GOLD, 0.85), (0.88, GOLD, 0.85), (1, GOLD, 0)],
                   18, 0, 208, 0, unit="user")
    b = []
    # —— 墨线（先画，线盒压住起点）——
    b.append(rect(18, cy - (3.5 if evolved else 3.0), 190, 7.0 if evolved else 6.0,
                  rx=3.2, fill="url(#ilHalo)"))
    b.append(rect(18, cy - (2.0 if evolved else 1.5), 190, 4.0 if evolved else 3.0,
                  fill="url(#ilCore)"))
    b.append(rect(18, cy - 0.5, 190, 1.0, fill="url(#ilThread)"))
    if evolved:
        b.append(rect(18, cy - 3.0, 190, 1.1, fill="url(#ilGold)"))
        b.append(rect(18, cy + 1.9, 190, 1.1, fill="url(#ilGold)"))
    # 线上两点甩墨，说明是「弹出来的线」
    b.append(circle(96, cy + 4.6, 0.9, fill=INK, op=0.5))
    b.append(circle(150, cy - 4.8, 0.7, fill=INK, op=0.4))
    # —— 墨斗线盒：木盒 + 铜箍 + 朱红封蜡 ——
    b.append(rect(2.0, cy - 6.0, 17, 12.0, rx=2.2, fill="url(#ilWood)"))
    b.append(rect(2.0, cy - 6.0, 17, 2.4, rx=1.2, fill=CREAM, op=0.22))
    b.append(rect(8.6, cy - 6.0, 2.4, 12.0, fill=GOLD, op=0.8))
    b.append(rect(2.0, cy - 6.0, 17, 12.0, rx=2.2, fill="none", stroke=NIGHT_DEEP, sw=1.0, op=0.5))
    b.append(circle(5.6, cy, 2.4, fill=CINNABAR))
    b.append(circle(4.9, cy - 0.7, 0.8, fill=SEAL_LIGHT, op=0.6))
    b.append(path("M12 %sq2 3 0 5.4" % f(cy + 4.2), stroke=WOOD_DEEP, sw=0.9, op=0.5))
    # —— 线端：小坠 / 进化改龙首 ——
    if not evolved:
        b.append(rect(203.5, cy - 3.2, 3.0, 6.4, rx=1.2, fill=CINNABAR))
        b.append(poly([(207.0, cy), (210.6, cy - 2.6), (216.0, cy), (210.6, cy + 2.6)],
                      fill=GOLD, stroke=GOLD_DEEP, stroke_width=0.8))
        b.append(circle(211.0, cy - 0.6, 0.8, fill=CREAM, op=0.55))
    else:
        # 龙首：吻部前伸 + 双角 + 朱瞳
        b.append(rect(202.0, cy - 3.6, 3.4, 7.2, rx=1.4, fill=CINNABAR))
        b.append(path("M206 %sL213 %sL219.4 %sL213 %sZ" % (f(cy), f(cy - 4.2), f(cy), f(cy + 4.2)),
                      fill=GOLD, stroke=GOLD_DEEP, sw=1.0))
        b.append(path("M209.6 %sL213.4 %sM209.6 %sL213.4 %s"
                      % (f(cy - 3.0), f(cy - 7.0), f(cy + 3.0), f(cy + 7.0)),
                      stroke=AMBER, sw=1.8, op=0.9, cap="round"))
        b.append(circle(211.6, cy - 0.8, 1.2, fill=CINNABAR_DEEP))
        b.append(circle(211.2, cy - 1.2, 0.5, fill=SEAL_LIGHT, op=0.9))
        b.append(path("M213.6 %sL218.6 %s" % (f(cy + 0.6), f(cy + 2.2)),
                      stroke=CREAM, sw=0.9, op=0.5))
    return doc(w, h, "".join(b), defs)


def inkline():
    return inkline_svg(False)


def inkline_evolved():
    return inkline_svg(True)


# =====================================================================
# 3. weapons/woodblock_print.svg —— 木版年画雕版 120×120
#    清单 weapon_print：方硬雕版 + 版面线刻 + 四角固定榫，
#    落地半径 105 由 WeaponManager 控制；区别圆形光环类靠「方」与「厚」。
# =====================================================================
def woodblock_print():
    b = []
    # 版体：木色 + 顶亮底暗 + 侧边厚度（硬边，不做圆角）
    b.append(rect(6, 6, 108, 108, rx=2.5, fill="url(#wpW)"))
    b.append(rect(6, 6, 108, 3.2, fill=CREAM, op=0.2))
    b.append(rect(6, 108, 108, 6, fill=NIGHT_DEEP, op=0.22))
    b.append(rect(108, 6, 6, 108, fill=NIGHT_DEEP, op=0.14))
    b.append(rect(6, 6, 108, 108, rx=2.5, fill="none", stroke=WOOD_DEEP, sw=2.0, op=0.6))
    # 版面凹槽
    b.append(rect(17, 17, 86, 86, fill=WOOD))
    b.append(rect(17, 17, 86, 86, fill="none", stroke=WOOD_DEEP, sw=1.4, op=0.55))
    # 版心回纹边框（剪纸硬边 + 断线，刻版走刀感）
    b.append(rect(23, 23, 74, 74, fill="none", stroke=CREAM, sw=1.5, op=0.3, ))
    b.append(rect(26.5, 26.5, 67, 67, fill="none", stroke=CREAM, sw=0.9, op=0.18))
    for i in range(4):
        x = 30 + i * 18
        b.append(rect(x, 20.6, 9, 3.4, fill=CREAM, op=0.22))
        b.append(rect(x, 96, 9, 3.4, fill=CREAM, op=0.16))
    # —— 门神线刻（抽象化处理，不成字、不是神像特写，只保留盔/眉/目/须的读感）——
    b.append(path("M42 44q18-13 36 0l-3.4 9.6q-14.6 7-29.2 0z", fill=CINNABAR, op=0.8))
    b.append(path("M42 44q18-13 36 0", stroke=GOLD, sw=1.8, op=0.85))
    b.append(circle(60, 39.4, 1.9, fill=AMBER, op=0.9))
    b.append(path("M47 57q6-6 13-2M73 57q-6-6-13-2", stroke=CREAM, sw=2.2, op=0.75, cap="round"))
    b.append(circle(52.6, 62.4, 2.5, fill=CREAM, op=0.7))
    b.append(circle(67.4, 62.4, 2.5, fill=CREAM, op=0.7))
    b.append(circle(52.6, 62.4, 1.1, fill=WOOD_DEEP))
    b.append(circle(67.4, 62.4, 1.1, fill=WOOD_DEEP))
    b.append(path("M57 69.6h6", stroke=CREAM, sw=1.6, op=0.6))
    b.append(path("M58.4 69.6v2.2M61.6 69.6v2.2", stroke=WOOD_DEEP, sw=0.8, op=0.6))
    # 三绺长须（竖刀，别画成笑弧）
    b.append(path("M50 74l-3.4 11M60 75.4v11M70 74l3.4 11",
                  stroke=CREAM, sw=1.2, op=0.42, cap="round"))
    b.append(path("M46 88h28", stroke=TEAL, sw=1.6, op=0.55))
    b.append(path("M34 52l7 3M86 52l-7 3", stroke=GOLD, sw=1.6, op=0.6, cap="round"))
    # —— 四角固定榫 ——
    for (px, py) in [(11.5, 11.5), (98.5, 11.5), (11.5, 98.5), (98.5, 98.5)]:
        b.append(rect(px, py, 10, 10, rx=1.4, fill=WOOD_DEEP))
        b.append(rect(px, py, 10, 10, rx=1.4, fill="none", stroke=GOLD, sw=1.3, op=0.85))
        b.append(circle(px + 5, py + 5, 1.5, fill=CREAM, op=0.6))
    # 木纹
    b.append(path("M20 12h14M70 108h16", stroke=WOOD_DEEP, sw=1.0, op=0.35))
    defs = lg("wpW", [(0, WOOD_LIGHT, 1), (0.5, WOOD, 1), (1, WOOD_DEEP, 1)], 6, 6, 114, 114, unit="user")
    return doc(120, 120, "".join(b), defs)


# =====================================================================
# 4. items/passive_regen.svg —— 回春 64×64（清单 passive_regen）
#    剪纸土坡冒嫩芽 + 露珠；绿用本包 TEAL/TEAL_DEEP（清单示意色 #3E8E5A 不在包内）。
# =====================================================================
def passive_regen():
    b = []
    b.append(shadow(32, 57.4, 15.0, 2.8, 0.3))
    # —— 剪纸土坡：主坡 + 错位内坡 + 坡脚暗带 ——
    b.append(path("M11 53q7-13 21-13t21 13z", fill="url(#prG)"))
    b.append(path("M12.6 53q6.6-11.4 19.4-11.4T51.4 53z", fill=TEAL_DEEP, op=0.2))
    b.append(path("M11 53q7-13 21-13t21 13z", fill="none", stroke=TEAL_DEEP, sw=1.1, op=0.34))
    b.append(rect(10.4, 51.6, 43.2, 2.6, rx=1.2, fill=TEAL_DEEP, op=0.5))
    b.append(path("M17 46q6-4 12-1M33 42q7-3 13 1", stroke=CREAM, sw=1.0, op=0.3, cap="round"))
    b.append(circle(20.6, 49.4, 0.9, fill=CREAM, op=0.35))
    b.append(circle(43.4, 49.8, 0.7, fill=CREAM, op=0.3))
    # —— 主芽 + 两支春枝 ——
    b.append(path("M32 41.6q-1.4-9.4 1.4-16.4", stroke=TEAL, sw=2.6, op=0.95, cap="round"))
    b.append(path("M32.6 30.4q-6.6-3.6-11.4 1.4 6 4.4 11.4-1.4z", fill=TEAL_DEEP))
    b.append(path("M33.4 25.2q8.6-6.4 12.6 0.6-8.4 5.4-12.6-0.6z", fill=TEAL))
    b.append(path("M34.2 18.6q6.4-4.6 8.6 0.8-6 3.4-8.6-0.8z", fill=TEAL, op=0.85))
    b.append(path("M33.6 26.0q5-3 9.6-0.4M32.4 31.0q-4.6-1.6-8.4 0.8M35.0 19.2q3.4-2 6-0.4",
                  stroke=CREAM, sw=0.9, op=0.42, cap="round"))
    # —— 顶芽朱红点缀 ——
    b.append(path("M33.4 17.4q1.6-4.6 4.6-6.6", stroke=TEAL_DEEP, sw=1.4, op=0.8, cap="round"))
    b.append(circle(38.6, 9.4, 2.6, fill=CINNABAR))
    b.append(circle(37.7, 8.5, 0.9, fill=SEAL_LIGHT, op=0.7))
    # —— 露珠：米白实珠 + 青高光（读「恢复」）——
    b.append(circle(45.4, 33.6, 3.0, fill=CREAM, op=0.82))
    b.append(circle(45.4, 33.6, 3.0, fill="none", stroke=TEAL_DEEP, sw=0.9, op=0.5))
    b.append(circle(44.3, 32.5, 1.0, fill=CREAM_PALE, op=0.95))
    b.append(circle(22.6, 24.2, 1.9, fill=CREAM, op=0.78))
    b.append(circle(22.0, 23.6, 0.7, fill=CREAM_PALE, op=0.95))
    b.append(circle(28.4, 47.0, 1.3, fill=CREAM, op=0.6))
    defs = lg("prG", [(0, CREAM, 1), (0.45, CREAM_DIM, 1), (1, TEAL_DEEP, 1)], 11, 39, 53, 53, unit="user")
    return doc(64, 64, "".join(b), defs)


# =====================================================================
# 5. items/passive_shield.svg —— 结界 64×64（清单 passive_shield）
#    用户确认：清单原文的「符箓/八卦/结字」属宗教符号 + 可读文字，踩 v4 §2.6 红线，
#    改画油纸伞骨式竹篾护圈 + 朱绳结；青蓝（本包 TEAL）+ 金边，屏障/守护读感不变。
# =====================================================================
def passive_shield():
    cx = cy = 32.0
    V = octagon(cx, cy, 27.0, rot=-90)
    b = []
    b.append(shadow(cx, 57.6, 14.0, 2.4, 0.28))
    # —— 护圈底面 + 分瓣伞面 ——
    b.append(poly(V, fill=CREAM, opacity=f(0.7)))
    panels = [
        ((cx + 3.2, cy - 3.2), V[1], V[2], (cx + 3.4, cy), TEAL),
        ((cx + 3.2, cy + 3.2), V[3], V[4], (cx, cy + 3.4), CREAM_DIM),
        ((cx - 3.2, cy + 3.2), V[5], V[6], (cx - 3.4, cy), TEAL),
        ((cx - 3.2, cy - 3.2), V[7], V[0], (cx, cy - 3.4), CREAM_DIM),
    ]
    for pts, col in [(p[:4], p[4]) for p in panels]:
        b.append(poly(pts, fill=col, opacity=f(0.26)))
    # —— 8 根竹篾骨架 + 两道篾圈 ——
    for i in range(8):
        ix, iy = P(cx, cy, 6.0, -90 + i * 45)
        b.append(path("M%s %sL%s %s" % (f(ix), f(iy), f(V[i][0]), f(V[i][1])),
                      stroke=WOOD, sw=1.5, op=0.85))
    b.append(path("M%s %sA15 15 0 1 1 %s %sA15 15 0 1 1 %s %s"
                  % (f(cx - 15), f(cy), f(cx + 15), f(cy), f(cx - 15), f(cy)),
                  fill="none", stroke=WOOD_LIGHT, sw=1.0, op=0.5))
    # —— 金边 + 错色朱内圈 ——
    b.append(poly(V, fill="none", stroke=GOLD, stroke_width=2.8, opacity=f(0.95), stroke_linejoin="round"))
    b.append(poly(octagon(cx, cy, 23.4), fill="none", stroke=CINNABAR_DEEP,
                  stroke_width=1.0, opacity=f(0.5)))
    b.append(poly(octagon(cx, cy, 29.4), fill="none", stroke=GOLD_DEEP,
                  stroke_width=1.0, opacity=f(0.4)))
    # —— 中心朱绳结：双环 + 缠心 + 两条短穗 ——
    b.append(path("M32 32q-9-7-13-1.6 4 8.4 13 1.6z", fill=CINNABAR, op=0.95))
    b.append(path("M32 32q9-7 13-1.6-4 8.4-13 1.6z", fill=CINNABAR, op=0.95))
    b.append(path("M21.4 29.0q4.6 2.4 9.0 2.0M42.6 29.0q-4.6 2.4-9.0 2.0",
                  stroke=CREAM, sw=0.9, op=0.5, cap="round"))
    b.append(path("M32 33.6q-3 6.4-7.4 9.6M32 33.6q3 6.4 7.4 9.6",
                  stroke=CINNABAR, sw=2.2, op=0.9, cap="round"))
    b.append(rect(29.2, 29.4, 5.6, 5.6, rx=1.8, fill=CINNABAR_DEEP))
    b.append(rect(29.2, 29.4, 5.6, 5.6, rx=1.8, fill="none", stroke=GOLD, sw=1.0, op=0.8))
    b.append(circle(30.6, 30.8, 0.9, fill=SEAL_LIGHT, op=0.75))
    # —— 4 枚金钉（护圈角上，读「结界桩」）——
    for i in (1, 3, 5, 7):
        bx, by = P(cx, cy, 27.0, -90 + i * 45)
        b.append(circle(bx, by, 1.9, fill=AMBER))
        b.append(circle(bx - 0.5, by - 0.5, 0.7, fill=CREAM, op=0.7))
    return doc(64, 64, "".join(b))


# =====================================================================
# 6. ui/skill_roar.svg —— 傩面替身·震吼 主动技按钮 96×96（清单 ui_skill_roar）
#    咆哮傩面 + 向外声纹弧；朱红底 + 金声纹，与被动图标（青/米白）拉开色相。
# =====================================================================
def skill_roar():
    b = []
    # —— 按钮底板：朱红→深朱（与被动图标的青/米白拉开色相）——
    b.append(rect(3, 3, 90, 90, rx=16, fill="url(#srP)"))
    # —— 声纹（先画，压在面具后面，向外扩散三段递减）——
    for r, op, sw in ((26.0, 0.85, 2.6), (33.0, 0.6, 2.2), (39.0, 0.38, 1.8)):
        b.append(path(arc_d(48, 46, r, -30, 30), stroke=GOLD, sw=sw, op=op, cap="round"))
        b.append(path(arc_d(48, 46, r, 150, 210), stroke=GOLD, sw=sw, op=op, cap="round"))
    for deg in (-14, 0, 14):
        b.append(path("M%s %sL%s %s" % (f(48 + 42 * math.cos(math.radians(deg))),
                                          f(46 + 42 * math.sin(math.radians(deg))),
                                          f(48 + 44.6 * math.cos(math.radians(deg))),
                                          f(46 + 44.6 * math.sin(math.radians(deg)))),
                      stroke=AMBER, sw=1.6, op=0.3))
        b.append(path("M%s %sL%s %s" % (f(48 - 42 * math.cos(math.radians(deg))),
                                          f(46 + 42 * math.sin(math.radians(deg))),
                                          f(48 - 44.6 * math.cos(math.radians(deg))),
                                          f(46 + 44.6 * math.sin(math.radians(deg)))),
                      stroke=AMBER, sw=1.6, op=0.3))
    # —— 咆哮傩面（硬边，浅色面 + 朱墨五官，在朱红底上跳得出来）——
    b.append(path("M28 24q20-11 40 0l-2.6 38q-17 11-34.8 0z", fill="url(#srM)"))
    b.append(path("M28 24q20-11 40 0l-2.6 38q-17 11-34.8 0z", fill="none",
                  stroke=GOLD, sw=2.2, op=0.95, cap="round"))
    b.append(path("M30 26q18-10 36 0", fill="none", stroke=CINNABAR, sw=1.6, op=0.55))
    # 额冠 + 双角
    b.append(path("M48 12l7.4 8.4-7.4 4.2-7.4-4.2z", fill=CINNABAR))
    b.append(circle(48, 17.6, 1.5, fill=AMBER, op=0.9))
    b.append(path("M31.6 18.4l5.2 7.2M64.4 18.4l-5.2 7.2", stroke=CINNABAR_DEEP,
                  sw=3.2, op=0.9, cap="round"))
    # 怒眉 / 眼 / 鼻
    b.append(path("M33.4 38.4q7.4-8.4 14.2-2.4M62.6 38.4q-7.4-8.4-14.2-2.4",
                  stroke=CINNABAR, sw=3.2, op=0.95, cap="round"))
    b.append('<ellipse cx="40.4" cy="45.4" rx="5.4" ry="6.2" fill="%s"/>' % NIGHT_DEEP)
    b.append('<ellipse cx="55.6" cy="45.4" rx="5.4" ry="6.2" fill="%s"/>' % NIGHT_DEEP)
    b.append(circle(41.8, 43.6, 1.3, fill=AMBER, op=0.85))
    b.append(circle(57.0, 43.6, 1.3, fill=AMBER, op=0.85))
    b.append(path("M48 47.6l2.6 5.6h-5.2z", fill=NIGHT_DEEP, op=0.7))
    # 张口（震吼的读感核心）+ 金齿
    b.append(path("M39.6 55.6q8.4 4.4 16.8 0l-2.2 10.6q-6.2 3.2-12.4 0z", fill=NIGHT_DEEP, op=0.9))
    b.append(path("M39.6 55.6q8.4 4.4 16.8 0", fill="none", stroke=CINNABAR, sw=1.6, op=0.8))
    b.append(rect(42.6, 57.2, 4.4, 2.6, rx=0.8, fill=AMBER, op=0.9))
    b.append(rect(49.0, 57.2, 4.4, 2.6, rx=0.8, fill=AMBER, op=0.9))
    b.append(rect(45.2, 63.4, 5.6, 2.2, rx=0.8, fill=CREAM, op=0.7))
    # 颊纹 / 颏带
    b.append(path("M32.6 50.4q-2.6 7 0 13.2M63.4 50.4q2.6 7 0 13.2",
                  stroke=CREAM_DIM, sw=1.2, op=0.4, cap="round"))
    b.append(path("M41.4 70.4q6.6 3.4 13.2 0", stroke=GOLD, sw=1.6, op=0.7, cap="round"))
    # —— 按钮底板（最后描边，声纹不会骑到边框上）——
    b.append(rect(3, 3, 90, 90, rx=16, fill="none", stroke=CREAM, sw=2.6, op=0.92))
    b.append(rect(7.4, 7.4, 81.2, 81.2, rx=13, fill="none", stroke=CREAM, sw=0.9, op=0.24))
    for i in range(10):
        fx_ = 10 + (i * 37) % 78
        fy_ = 12 + (i * 53) % 72
        if 26 <= fx_ <= 70 and 20 <= fy_ <= 74:
            continue
        b.append(circle(fx_, fy_, 0.8 + (i % 3) * 0.3, fill=ASH, op=0.16))
    defs = (lg("srP", [(0, SEAL_LIGHT, 1), (0.55, CINNABAR, 1), (1, CINNABAR_DEEP, 1)],
               3, 3, 3, 93, unit="user")
            + lg("srM", [(0, CREAM_PALE, 1), (0.6, CREAM, 1), (1, CREAM_DIM, 1)],
                 28, 24, 28, 62, unit="user"))
    return doc(96, 96, "".join(b), defs)


# =====================================================================
# 7. enemies/shell_crust.svg —— 浆壳兵·结壳层 overlay 48×48（方案 A）
#    必须与 paper_scrap 同尺寸同锚点：直接叠加即可对齐（基型本体占 x 9.6–38.3 / y 11–41.8，
#    接触阴影与双眼由基型提供，本层一律不覆盖眼窗 x[16.4,31.6] × y[21.2,28.8]，
#    否则叠上去会把基型的两个眼洞糊掉——v4 的 paper_scrap_shell 是重画整张，眼在壳之上，
#    overlay 反过来必须让开）。
# =====================================================================
SHELL_PLATES = [
    "M14.6 19.4L16.6 13.6L21.8 12.3L27.4 13.7L32.6 16.4L35.0 20.2L30.6 20.3"
    "L25.2 18.9L19.8 20.1L16.2 19.8Z",                                # 头顶壳
    "M33.4 17.0L36.2 19.4L34.6 21.4L32.2 19.2Z",                       # 右肩小块
    "M11.0 23.6L15.2 22.4L15.8 27.4L15.2 30.6L12.8 34.6L10.2 29.8Z",   # 左颊壳
    "M33.0 22.0L36.4 24.4L36.2 28.6L34.4 32.4L32.8 29.4L32.8 25.0Z",   # 右颊壳
    "M19.0 35.2L25.0 37.0L29.8 35.4L31.2 38.8L25.6 40.8L19.6 39.6Z",   # 腹壳
]
SHELL_SEAMS = [
    "M16.2 19.8L19.8 20.1L25.2 18.9L30.6 20.3L35.0 20.2",
    "M10.2 29.8L12.8 34.6L15.2 30.6",
    "M32.8 29.4L34.4 32.4L36.2 28.6",
    "M19.6 39.6L25.6 40.8L31.2 38.8",
]
SHELL_CRACKS = [
    "M20.4 13.6L22.8 17.6L21.2 20.4",
    "M28.6 14.4L30.0 18.2L28.2 20.4",
    "M12.6 25.4L15.0 28.6",
    "M33.6 23.4L35.2 27.6",
    "M23.4 36.4L26.6 39.4",
]
SHELL_RIDGES = [
    "M17.8 15.2l3.4 1.2", "M26.0 14.4l3.6 1.4", "M33.6 24.8l2.6-0.8", "M20.8 37.4l3.6 1.6",
]
SHELL_STRaws = [
    "M15.6 14.8L20.4 12.6L25.6 13.4", "M33.0 21.8l2.8 2.0", "M12.0 27.8l3.2-1.0",
]


def shell_crust():
    b = []
    # 壳本体：米白底（比基型略暗）+ 灰被（做出清单要的「灰白泥壳」质感）
    for d in SHELL_PLATES:
        b.append(path(d, fill=CREAM_DIM, op=0.88))
    for d in SHELL_PLATES:
        b.append(path(d, fill=GRAY, op=0.26))
    for d in SHELL_PLATES:
        b.append(path(d, fill=ASH, op=0.1))
    # 壳缘：湿泥青 + 硬边暗轮廓（「厚、可破」的读感靠这层）
    for d in SHELL_PLATES:
        b.append(path(d, fill="none", stroke=ASH, sw=1.0, op=0.42))
    for d in SHELL_SEAMS:
        b.append(path(d, stroke=TEAL_DEEP, sw=1.4, op=0.5, cap="round"))
    # 裂纹 + 脊高光 + 秸秆屑
    for d in SHELL_CRACKS:
        b.append(path(d, stroke=ASH, sw=1.0, op=0.75, cap="round"))
    for d in SHELL_RIDGES:
        b.append(path(d, stroke=CREAM, sw=0.9, op=0.65))
    for d in SHELL_STRaws:
        b.append(path(d, stroke=CREAM, sw=1.0, op=0.42, cap="round"))
    # 三粒壳面粗砂（避免整层太干净）
    for (sx, sy, sr, so) in ((23.0, 16.6, 1.1, 0.2), (34.2, 26.6, 0.9, 0.22), (26.4, 38.2, 1.0, 0.2)):
        b.append(circle(sx, sy, sr, fill=NIGHT_DEEP, op=so))
    return doc(48, 48, "".join(b))


# =====================================================================
# 10. weapons/extinguisher_evolved.svg —— 百子千花 80×80
#     本体 iron_flower_ladle(48×48) 等比 5/3 放大 + 金红双色铁花更繁密。
# =====================================================================
def star(cx, cy, r, color, op=0.9, rot=0.0, thin=0.26):
    pts = []
    for i in range(8):
        rad = r if i % 2 == 0 else r * thin
        pts.append(P(cx, cy, rad, rot + i * 45))
    return poly(pts, fill=color, opacity=f(op))


def extinguisher_evolved():
    b = []
    b.append(circle(50, 23, 33, fill="url(#eeG)"))
    b.append(circle(42, 30, 24, fill="url(#eeR)"))
    # 勺柄（木）+ 高光
    b.append(path("M10 70L33 50", stroke=WOOD_DEEP, sw=8, cap="round"))
    b.append(path("M11.6 68.4L31.4 51.4", stroke=WOOD_LIGHT, sw=2.2, op=0.55, cap="round"))
    # 铁勺（钢渐变）+ 金口 + 朱红箍
    b.append(path("M13.3 46.7a18.3 18.3 0 1 0 26.7 23.3 18.3 18.3 0 0 0-26.7-23.3z",
                  fill="url(#eeB)"))
    b.append(path("M18.3 50q10 6.7 20 0", stroke=GOLD, sw=3.2, op=0.95))
    b.append(path("M15.4 55.4q9 5.6 18.2 1.2", stroke=CINNABAR_DEEP, sw=1.6, op=0.55))
    # 勺内余铁水烧红（本体没有的一层，进化「连环炸」的预告）
    b.append(path("M20 53.4q9 8.6 18.6 3.4", stroke=CINNABAR, sw=3.4, op=0.72, cap="round"))
    b.append(path("M23 57.6q7 5.4 14 2.0", stroke=SEAL_LIGHT, sw=1.8, op=0.6, cap="round"))
    # 主铁花甩出：金 + 红 双线（本体只有金白双线）
    b.append(path("M23.3 43.3q10-13.3 26.7-16.7", stroke=LANTERN, sw=5.0, op=0.9, cap="round"))
    b.append(path("M26.6 46.0q11-12.4 28.4-14.4", stroke=CINNABAR, sw=3.4, op=0.75, cap="round"))
    b.append(path("M36.7 33.3q13.3-10 30-10", stroke=CREAM, sw=2.7, op=0.7, cap="round"))
    b.append(path("M28.6 38.6q9.4-9.4 20.6-11.4", stroke=SEAL_LIGHT, sw=2.4, op=0.6, cap="round"))
    # 迸溅：金 + 红 交替，比本体更密（进化「每 2 命中引爆」的视觉预告）
    gold_sparks = [(56.7, 10.0, 4.3), (70.0, 16.7, 3.5), (73.3, 33.3, 3.0), (60.0, 43.3, 2.5),
                   (43.3, 6.7, 2.7), (30.0, 16.7, 2.2), (64.6, 26.6, 2.0), (52.0, 4.6, 1.8),
                   (76.0, 44.0, 1.9), (44.0, 40.0, 1.6)]
    red_sparks = [(66.0, 10.6, 2.6), (76.6, 24.0, 2.2), (56.0, 34.0, 1.8), (48.0, 16.0, 1.7),
                  (38.6, 6.0, 1.5), (70.0, 38.0, 1.6)]
    for (sx, sy, sr) in gold_sparks:
        b.append(circle(sx, sy, sr, fill=AMBER, op=0.9))
    for (sx, sy, sr) in red_sparks:
        b.append(circle(sx, sy, sr, fill=CINNABAR, op=0.88))
    for (sx, sy, sr) in [(60.0, 14.0, 1.4), (72.0, 30.0, 1.2), (50.0, 8.0, 1.1)]:
        b.append(circle(sx, sy, sr, fill=CREAM, op=0.7))
    # 「千花」花火扇：从勺口向右上炸开的一片细流（本体完全没有的一层）
    for i in range(12):
        a = -78 + i * 6.6
        x0, y0 = P(34, 44, 13.0, a)
        x1, y1 = P(34, 44, 26.0 + (i % 3) * 4.0, a)
        b.append(path("M%s %sL%s %s" % (f(x0), f(y0), f(x1), f(y1)),
                      stroke=LANTERN if i % 2 == 0 else SEAL_LIGHT,
                      sw=2.0 if i % 3 == 0 else 1.3, op=0.72 if i % 2 == 0 else 0.55,
                      cap="round"))
    # 「千花」星芒：金红双色各三朵，这是与本体最主要的辨识差
    for (sx, sy, sr, rot) in [(66.0, 13.0, 6.4, 12), (75.0, 30.0, 5.2, 0), (50.0, 6.0, 4.6, 24),
                              (45.0, 20.0, 4.2, 30)]:
        b.append(star(sx, sy, sr, AMBER, 0.88, rot))
        b.append(star(sx, sy, sr * 0.42, CREAM, 0.8, rot))
    for (sx, sy, sr, rot) in [(59.0, 21.0, 5.4, 18), (72.0, 41.0, 4.4, 6), (38.0, 12.0, 3.8, 30),
                              (68.0, 21.0, 3.4, 42)]:
        b.append(star(sx, sy, sr, CINNABAR, 0.85, rot))
        b.append(star(sx, sy, sr * 0.38, SEAL_LIGHT, 0.8, rot))
    defs = (rg("eeG", 50, 23, 33, [(0, LANTERN, 0.68), (0.55, LANTERN, 0.24), (1, LANTERN, 0)])
            + rg("eeR", 42, 30, 24, [(0, CINNABAR, 0.46), (0.6, CINNABAR, 0.16), (1, CINNABAR, 0)])
            + lg("eeB", [(0, STEEL, 1), (1, STEEL_DEEP, 1)], 0, 46, 0, 70, unit="user"))
    return doc(80, 80, "".join(b), defs)


# =====================================================================
# 11. fx/surge_ring.svg —— 周期潮涌地面预警 256×256（清单 fx_surge_telegraph）
#     比 fx/boss_warning_ring 更大更密；地面预告层，中心必须留空（敌人在里面打）。
#     外缘收到 125：ThorVG 圆弧描边会有 ~1px 多边形化外凸，留出余量才不被画布裁掉。
# =====================================================================
def surge_ring():
    cx = cy = 128.0
    b = []
    b.append(circle(cx, cy, 125, fill="url(#suR)"))
    # 同心波纹：由内向外逐渐变密变亮。
    # alpha 预算（叠加是 a1+a2*(1-a1)，实测会顶到 0.95，故逐层压低）：
    #   最坏叠加点 = 45° 短棱 ∩ 外环 ∩ 渐变底 = 0.58 + 0.50*0.42 + 0.13*0.18 ≈ 0.82 <= 0.85
    #   中心 r<=26 必须留空（涌怪要站在圈里打），最内环放到 r=40
    b.append(circle(cx, cy, 40, fill="none", stroke=AMBER, sw=1.2, op=0.16))
    b.append(circle(cx, cy, 58, fill="none", stroke=CINNABAR, sw=1.4, op=0.24))
    b.append(circle(cx, cy, 76, fill="none", stroke=LANTERN, sw=1.6, op=0.3))
    b.append(circle(cx, cy, 94, fill="none", stroke=CINNABAR, sw=2.2, op=0.38, dash="11 9"))
    b.append(circle(cx, cy, 110, fill="none", stroke=AMBER, sw=2.0, op=0.4))
    b.append(circle(cx, cy, 120, fill="none", stroke=CINNABAR, sw=3.0, op=0.58, dash="18 12"))
    # 32 根外向短棱（比 boss 环的 24 根更密）
    for i in range(32):
        deg = i * 11.25
        sw = 4.0 if i % 4 == 0 else 2.0
        x0, y0 = P(cx, cy, 114, deg)
        x1, y1 = P(cx, cy, 124, deg)
        b.append(path("M%s %sL%s %s" % (f(x0), f(y0), f(x1), f(y1)),
                      stroke=CINNABAR, sw=sw, op=0.5 if sw == 4 else 0.34))
    # 8 组「涌」浪头双弧，指出潮水推进方向
    for i in range(8):
        base = -90 + i * 45
        b.append(path(arc_d(cx, cy, 82, base - 11, base + 11), stroke=AMBER, sw=2.0, op=0.34, cap="round"))
        b.append(path(arc_d(cx, cy, 89, base - 6, base + 6), stroke=AMBER, sw=1.4, op=0.22, cap="round"))
    # 4 枚角点（与鼓环同一语言，方便玩家把它认成「地面预告」家族）
    for deg in (45, 135, 225, 315):
        px, py = P(cx, cy, 104, deg)
        b.append(circle(px, py, 2.4, fill=CINNABAR, op=0.3))
    defs = rg("suR", cx, cy, 125,
              [(0, CINNABAR, 0), (0.5, CINNABAR, 0), (0.68, CINNABAR, 0.04),
               (0.88, CINNABAR, 0.2), (1.0, LANTERN, 0.08)])
    return doc(256, 256, "".join(b), defs)


# =====================================================================
# 12. ui/refine_badge.svg —— 精炼等级徽标 24×24（清单 ui_refine_badge）
#     卡角小标：3 道递增刻痕（1/2/3 级可截取），金边暗底，不与卡面文案冲突。
#     「炼」字小印不做——可读文字踩 v4 §2.6 红线。
# =====================================================================
def refine_badge():
    b = []
    b.append(rect(2, 2, 20, 20, rx=5.5, fill=INK_SOFT, op=0.92))
    b.append(rect(2, 2, 20, 20, rx=5.5, fill="none", stroke=GOLD, sw=1.5, op=0.9))
    b.append(rect(4.0, 4.0, 16.0, 16.0, rx=4.0, fill="none", stroke=CREAM, sw=0.7, op=0.2))
    b.append(path("M5.2 5.6h5.4", stroke=CREAM, sw=0.9, op=0.24, cap="round"))
    # 3 道递增刻痕
    b.append(path("M7.4 16.2L10.0 13.6", stroke=GOLD, sw=2.0, op=0.8, cap="round"))
    b.append(path("M11.0 16.6L14.4 13.2", stroke=AMBER, sw=2.0, op=0.9, cap="round"))
    b.append(path("M14.6 17.0L18.6 13.0", stroke=CREAM, sw=2.0, op=0.88, cap="round"))
    b.append(circle(18.6, 13.0, 1.1, fill=CINNABAR, op=0.9))
    b.append(rect(6.6, 18.2, 11.0, 1.4, rx=0.7, fill=GOLD_DEEP, op=0.7))
    return doc(24, 24, "".join(b))


ASSETS = [
    ("weapons/gong.svg", "96x96", "铜锣·世界贴图（v5 §3.1）", gong),
    ("weapons/inkline.svg", "220x16", "墨斗·弹线弹道（v5 §3.2）", inkline),
    ("weapons/woodblock_print.svg", "120x120", "木版年画·雕版（v5 §3.3）", woodblock_print),
    ("weapons/gong_evolved.svg", "96x96", "开市锣·进化（无字朱印）", gong_evolved),
    ("weapons/inkline_evolved.svg", "220x18", "龙筋墨线·进化", inkline_evolved),
    ("weapons/extinguisher_evolved.svg", "80x80", "百子千花·进化", extinguisher_evolved),
    ("items/passive_regen.svg", "64x64", "回春·被动卡面", passive_regen),
    ("items/passive_shield.svg", "64x64", "结界·被动卡面（绳结/竹篾护圈）", passive_shield),
    ("enemies/shell_crust.svg", "48x48", "浆壳兵·结壳 overlay（方案 A）", shell_crust),
    ("fx/surge_ring.svg", "256x256", "周期潮涌·地面预警", surge_ring),
    ("ui/skill_roar.svg", "96x96", "傩面替身·震吼主动技按钮", skill_roar),
    ("ui/refine_badge.svg", "24x24", "精炼等级徽标", refine_badge),
]


def main():
    dry = "--dry" in sys.argv
    if not os.path.isdir(PROJ_ART):
        sys.exit("工程美术目录不存在：%s" % PROJ_ART)
    problems, written = [], []
    for rel, size, title, fn in ASSETS:
        svg = fn()
        errs = validate(rel, svg, size)
        target = os.path.join(PROJ_ART, rel.replace("/", os.sep))
        if os.path.dirname(target).replace("\\", "/").startswith(ROOT.replace("\\", "/")):
            errs.append("refusing to write into the library")
        if os.path.exists(target) and os.path.basename(target) not in OWNED_OK:
            errs.append("would overwrite existing project art")
        if errs:
            problems.append((rel, errs))
            continue
        if not dry:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(svg)
        written.append(rel)
        print("OK  %-34s %6d B  %-9s %s" % (rel, len(svg.encode("utf-8")), size, title))
    if problems:
        for rel, errs in problems:
            print("FAIL %s: %s" % (rel, "; ".join(errs)))
        sys.exit(1)
    print("\n%d/12 产出，校验通过（%s）" % (len(written), "dry-run" if dry else PROJ_ART))


OWNED_OK = {os.path.basename(r) for r, _, _, _ in ASSETS}

if __name__ == "__main__":
    main()
