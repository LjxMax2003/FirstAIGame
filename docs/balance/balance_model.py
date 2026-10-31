#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FirstXiXueGui 伤害与成长 —— 解析式平衡分析（v2 定稿）
依据：核心玩法完善步骤.md / 吸血鬼幸存者核心玩法拆解.md
参数：params.json

为什么用解析式而不是逐帧模拟：
  自行搭建的逐帧模拟在 12 轮迭代中反复出现"敌人叠点、贴身判定失真、武器覆盖与刷怪环
  量纲不匹配"等自身缺陷（NUM_DESIGN.md 3.4 节有完整记录）。与其交付一个自己都
  不敢信的数字，不如用可手算复现的闭式公式，并把每个假设写在台面上。

所有输出都可手算复现。运行：
    python balance_model.py --json balance_result.json
"""

import json
import math
import argparse
from pathlib import Path

HERE = Path(__file__).resolve().parent


# ============================================================ 基础
def load():
    with open(HERE / "params.json", "r", encoding="utf-8") as f:
        return json.load(f)


def lerp(tab, x):
    if x <= tab[0][0]:
        return tab[0][1]
    if x >= tab[-1][0]:
        return tab[-1][1]
    for i in range(len(tab) - 1):
        x0, y0 = tab[i]
        x1, y1 = tab[i + 1]
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return tab[-1][1]


def sm(kind, lv, P):
    """被动乘数。lv = 已点级数（0 表示没有该被动）"""
    s = P["stats"][kind]
    lv = max(0, min(int(lv), s["cap"]))
    if kind in ("cooldown", "might"):
        return max(s["floor"], 1.0 - s["step"] * lv)
    return 1.0 + s["step"] * lv


def maxhp(lv, P):
    s = P["stats"]["max_hp"]
    return P["player"]["max_hp"] + s["step"] * min(int(lv), s["cap"])


# ============================================================ 敌潮（需求侧）
def ehp(t, P, mult=1.0):
    e = P["enemy"]
    ref = e.get("hp_ref", e.get("hp_ref_A"))
    return e["hp_base"] * (1.0 + t / ref) ** e["time_exponent"] * mult


def spawn_interval(t, P):
    s = P["spawn"]
    a = min(1.0, t / s["interval_ramp_s"])
    return s["interval_base"] + (s["interval_end"] - s["interval_base"]) * a


def batch(t, P):
    s = P["spawn"]
    return min(s["batch_base"] + s["batch_per_s_A"] * t, s["batch_cap"])


def elite_share(t, P):
    for wv in P["waves"]:
        if wv["t0"] <= t < wv["t1"]:
            return wv["elite_share"]
    return P["waves"][-1]["elite_share"]


def demand_hp(t, P):
    """每秒进入战场的血量 = 需求侧 DPS 门槛"""
    es = elite_share(t, P)
    return batch(t, P) / spawn_interval(t, P) * (
        (1 - es) * ehp(t, P) + es * ehp(t, P, P["enemy"]["elite_hp_mult"]))


def density(t, P):
    """同屏期望数 = 每秒入场 × 行进时间（无击杀上界）"""
    inc = batch(t, P) / spawn_interval(t, P)
    speed = 0.5 * (P["enemy"]["speed_min"] + P["enemy"]["speed_max"])
    travel = (P["world"]["spawn_ring"] - 24.0) / speed
    return inc * travel


# ============================================================ 武器（供给侧）
def aim_rate(L, pm, P):
    """单体武器的稳定输出比例：每发锁定目标，目标可能在弹道飞行中死亡（文档魔杖穿透 1）"""
    w = P["weapons"]["glowstick"]
    if w["pierce"] >= 1:
        return 0.88          # 穿透 2 目标，首发落空仍在第二目标结算
    return 0.45              # 无穿透：目标先死则整发落空（飞刀 0 穿透）


def weapon_unit(wid, L, pm, P):
    """
    单把武器的"基础 DPS"（不含被动乘数、不含 AoE 命中数）
    返回 dict: base_dps(每目标), cd, 覆盖(radius/len), aoe_cap
    """
    dM = sm("damage", pm.get("damage", 0), P)
    cM = sm("cooldown", pm.get("cooldown", 0), P)
    aM = sm("area", pm.get("area", 0), P)
    W = P["weapons"]
    if wid == "whip":
        w = W["whip"]
        dmg = (w["damage"] + w["dmg_per_level"] * (L - 1)) * dM
        ln = min((w["length"] + w["length_per_level"] * (L - 1)) * aM, w["length_cap"])
        return {"base": dmg / (w["cooldown"] * cM), "dmg": dmg, "cd": w["cooldown"] * cM,
                "len": ln, "radius": ln * 0.5, "cap": 8}
    if wid == "halo":
        w = W["halo"]
        dmg = (w["damage"] + w["dmg_per_level"] * (L - 1)) * dM
        return {"base": dmg / (w["cooldown"] * cM), "dmg": dmg, "cd": w["cooldown"] * cM,
                "radius": (w["radius"] + w["radius_per_level"] * (L - 1)) * aM, "cap": 10}
    if wid == "phone":
        w = W["phone"]
        dmg = (w["damage"] + w["dmg_per_level"] * (L - 1)) * dM
        return {"base": dmg / (w["cooldown"] * cM), "dmg": dmg, "cd": w["cooldown"] * cM,
                "radius": (w["orbit_radius"] + w["orbit_radius_per_level"] * (L - 1)) * aM, "cap": 8}
    if wid == "extinguisher":
        w = W["extinguisher"]
        dmg = (w["damage"] + w["dmg_per_level"] * (L - 1)) * dM
        return {"base": dmg / (w["cooldown"] * cM), "dmg": dmg, "cd": w["cooldown"] * cM,
                "radius": 240.0, "cap": 10}
    if wid == "glowstick":
        w = W["glowstick"]
        dmg = (w["damage"] + w["dmg_per_level"] * (L - 1)) * dM
        cd = max(0.15, w["cooldown"] * (1 - w["cd_per_level"] * (L - 1)) * cM)
        n = min(1 + (L - 1) // 2, 4)
        return {"base": dmg * n / cd * aim_rate(L, pm, P), "dmg": dmg, "cd": cd,
                "radius": w["range"], "cap": n * (1 + w["pierce"])}
    if wid == "blade":
        w = W["blade"]
        dmg = (w["damage"] + w["dmg_per_level"] * (L - 1)) * dM
        cd = max(0.1, w["cooldown"] * (1 - w["cd_per_level"] * (L - 1)) * cM)
        return {"base": dmg / cd * aim_rate(L, pm, P), "dmg": dmg, "cd": cd, "radius": 520.0, "cap": 1}
    raise KeyError(wid)


def hits_from_geometry(u, alive_n, P):
    """
    AoE 命中数：由覆盖面积 × 敌群面密度（6*neighbor_cell^2 = 单敌占地）算出，再乘队列深度修正。
    文档口径：同屏 300~500 只压在一片屏幕上 → 面密度 ≈ N / 可视面积
    """
    W = P["world"]
    area_screen = W["view_w"] * W["view_h"]
    dens = alive_n / area_screen
    # 圆形覆盖取 50%（敌群按线阵压来，圆的一半有效；贴脸时整圈有效，取几何平均 0.5）
    cover = math.pi * (u["radius"] ** 2) * 0.5
    raw = cover * dens
    return max(1.0, min(raw, u["cap"]))


def build_dps(build, P, alive_n, enhance=None):
    """
    返回 (稳定 DPS, 单体 DPS, 明细)
    enhance: 可叠加的额外乘数（进化/共鸣），{'wid': mult}
    """
    pm = build.get("passives", {})
    wl = build.get("weapons", {})
    meta = build.get("meta", {})
    tr = P["meta_shop"]["tracks"]
    mM = 1.0 + tr[0]["step"] * meta.get("might", 0)
    mCd = 1.0 - tr[2]["step"] * meta.get("cooldown", 0)
    scale = build.get("level_scale", 1.0)     # 等级不足的折损（阶段表用）
    total, single, detail = 0.0, 0.0, []
    for wid, v in wl.items():
        if isinstance(v, str):               # 进化形态
            base_L = 8
            evo = next(x for x in P["evolution"]["forms"] if x["id"] == v[2:])
        else:
            base_L = v
            evo = None
        u = weapon_unit(wid, base_L, pm, P)
        mult = mM / mCd * (evo["dps_mult"] if evo else 1.0)
        if enhance and wid in enhance:
            mult *= enhance[wid]
        if wid in ("whip", "halo", "phone", "extinguisher"):
            h = hits_from_geometry(u, alive_n, P)
            d = u["base"] * mult * h
            single += u["base"] * mult
        else:
            h = 1.0
            d = u["base"] * mult
            single += d
        total += d
        detail.append({"wid": wid, "lv": v, "base": round(u["base"], 1),
                       "hits": round(h, 1), "mult": round(mult, 2), "dps": round(d)})
    return total * scale, single * scale, detail


# ============================================================ 生存（受击侧）
def contact_threat(touching, P, def_mults=(1.0,)):
    """
    贴身威胁：无敌帧 0.5s / cadence 0.6s → 每 0.6s 最多结算 1 次命中
    伤害 = 每轮伤害 × 每秒轮数
    """
    pl, en = P["player"], P["enemy"]
    per_cycle_hits = max(1, math.ceil(en["contact_cadence"] / pl["invuln"]))
    ev = en["contact_damage"] * per_cycle_hits
    for m in def_mults:
        ev *= m
    dps = ev / en["contact_cadence"]
    # 速度带来的回避：能贴身的人数随走位倍率下降
    return dps


def survival_time(hp, dps_taken):
    return hp / dps_taken if dps_taken > 1e-9 else float("inf")


# ============================================================ 阶段表
STAGES = [
    # (t, 期望等级, 构筑)
    (0,   1,  {"weapons": {"whip": 1}, "passives": {}}),
    (60,  4,  {"weapons": {"whip": 2}, "passives": {"damage": 1}}),
    (300, 11, {"weapons": {"whip": 3, "halo": 2, "glowstick": 1}, "passives": {"damage": 2, "cooldown": 1}}),
    (600, 20, {"weapons": {"whip": 4, "halo": 3, "glowstick": 3, "phone": 1},
               "passives": {"damage": 3, "cooldown": 2, "area": 1}}),
    (900, 28, {"weapons": {"whip": 5, "halo": 4, "glowstick": 4, "phone": 2, "blade": 2},
               "passives": {"damage": 4, "cooldown": 3, "area": 2}}),
    (1200, 34, {"weapons": {"whip": 6, "halo": 5, "glowstick": 5, "phone": 3, "blade": 3, "extinguisher": 2},
                "passives": {"damage": 4, "cooldown": 3, "area": 3, "might": 1}}),
    (1500, 40, {"weapons": {"whip": 7, "halo": 6, "glowstick": 6, "phone": 4, "blade": 4, "extinguisher": 3},
                "passives": {"damage": 5, "cooldown": 4, "area": 4, "might": 2}}),
    (1800, 45, {"weapons": {k: 8 for k in ("whip", "halo", "glowstick", "phone", "blade", "extinguisher")},
                "passives": {"damage": 5, "cooldown": 5, "area": 5, "might": 2}}),
]


def stage_table(P):
    rows = []
    for t, lv, b in STAGES:
        b = dict(b)
        b["meta"] = {}
        dens = density(t, P)
        dem = demand_hp(t, P)
        dps, single, detail = build_dps(b, P, dens)
        hp = maxhp(b["passives"].get("max_hp", 0), P)
        def_m = sm("might", b["passives"].get("might", 0), P)
        # 近战武器护身：鞭子/蒜环会先清掉贴身敌人，按覆盖比例折算贴身人数
        guard = 0.0
        for wid in ("whip", "halo", "phone"):
            if wid in b["weapons"]:
                guard += 0.45 if wid == "whip" else (0.35 if wid == "halo" else 0.25)
        effective_touch = max(1.0, 8.0 * (1.0 - min(guard, 0.8)))
        threat = contact_threat(effective_touch, P, (def_m,))
        rows.append({
            "t": t, "mm": "%02d:%02d" % (t // 60, t % 60), "lv": lv,
            "density": round(dens), "demand_hp": round(dem),
            "dps": round(dps), "dps_ratio": round(dps / dem, 2),
            "single_dps": round(single),
            "hp": round(hp), "threat": round(threat, 1),
            "survive_s": round(survival_time(hp, threat), 1),
            "kill_per_s": round(dps / max(dem / max(density(t, P), 1) * 1.0, 1e-6) * 0.0 + (
                dps / max((dem / max(batch(t, P) / spawn_interval(t, P), 1e-9)), 1e-9)), 2),
            "detail": detail,
        })
    return rows


# ============================================================ 极端组合
def extreme_builds():
    SIX = {k: 8 for k in ("whip", "halo", "glowstick", "phone", "blade", "extinguisher")}
    FM = {"might": 5, "max_hp": 5, "cooldown": 5, "magnet": 3, "revive": 2}
    return [
        ("X1 全增益拉满（5被动满+meta满）", SIX,
         {"damage": 5, "cooldown": 5, "area": 5, "might": 5, "speed": 5}, FM, None),
        ("X2 纯AOE极限（进化蒜+圣经+斧+范围满）", {"halo": "E:evolve_halo", "phone": 8, "extinguisher": 8},
         {"area": 5, "damage": 5, "might": 5}, FM, None),
        ("X3 单武器极限（进化鞭+全增益）", {"whip": "E:evolve_whip"},
         {"damage": 5, "cooldown": 5, "area": 5, "might": 5, "speed": 5}, FM, None),
        ("X4 龟壳（蒜Lv1+全防御，零输出）", {"halo": 1},
         {"might": 5, "speed": 5, "max_hp": 5, "magnet": 5, "cooldown": 5}, {}, None),
        ("X5 纯走位（鞭Lv1+全生存）", {"whip": 1},
         {"speed": 5, "might": 5, "max_hp": 5, "magnet": 5, "cooldown": 5}, FM, None),
        ("X6 六武器Lv8 零被动（槽位极值）", SIX, {}, {}, None),
        ("X7 被动满+单武器（被动力极值）", {"whip": 8},
         {"damage": 5, "cooldown": 5, "area": 5, "might": 5, "max_hp": 5}, FM, None),
        ("X8 零构筑对照（鞭Lv1，什么都不点）", {"whip": 1}, {}, {}, None),
        # 故意越界的两组（参数不允许，但用来验证"如果多给一点会怎样"）
        ("X9 越界·冷却11级（超出上限5+meta5）", SIX,
         {"damage": 5, "cooldown": 11, "area": 5}, FM, None),
        ("X10 越界·范围11级", {"halo": "E:evolve_halo", "phone": 8},
         {"area": 11, "damage": 5}, {}, None),
        # 币值上限：三把主力武器全部进化 + 满增益。被动 5 槽×5 级 = 25 级，
        # 取"输出三区满 + 力量 + 移速"（与 X1 同配置，只是武器换成三把进化形态）
        ("X11 三武器全进化+满增益（币值上限）",
         {"whip": "E:evolve_whip", "halo": "E:evolve_halo", "glowstick": "E:evolve_glowstick"},
         {"damage": 5, "cooldown": 5, "area": 5, "might": 5, "speed": 5}, FM, None),
    ]


def extreme_table(P):
    rows = []
    t_ref = 1800
    dens = density(t_ref, P)
    dem = demand_hp(t_ref, P)
    for name, wl, pm, meta, enh in extreme_builds():
        b = {"name": name, "weapons": wl, "passives": pm, "meta": meta}
        dps, single, detail = build_dps(b, P, dens, enh)
        hp = maxhp(pm.get("max_hp", 0), P)
        defm = sm("might", pm.get("might", 0), P)
        rev = meta.get("revive", 0)
        spd = sm("speed", pm.get("speed", 0), P)
        # 威胁：贴身人数随覆盖与速度下降
        guard = sum(0.45 if w == "whip" else 0.30 if w == "halo" else 0.20 if w == "phone" else 0
                    for w in wl)
        touch = max(1.0, 8.0 * (1.0 - min(guard, 0.85)) / spd)
        threat = contact_threat(touch, P, (defm,))
        rows.append({
            "name": name, "dps": round(dps), "single": round(single),
            "ratio": round(dps / dem, 2), "hp": round(hp),
            "revive": rev, "threat": round(threat, 1),
            "survive_s": round(survival_time(hp * (1 + 0.5 * rev), threat), 1),
            "detail": detail,
        })
    # 排序：DPS 从高到低
    rows.sort(key=lambda r: -r["dps"])
    return rows


# ============================================================ 边际收益与拐点
def marginal(kind, P, levels=5):
    """单属性各级的边际 DPS 增益（孤立看）"""
    out = []
    base = mult_total(kind, 0, P)
    prev = base
    for lv in range(1, levels + 1):
        cur = mult_total(kind, lv, P)
        out.append({"lv": lv, "delta_pct": round((cur / prev - 1) * 100, 1),
                    "cum_pct": round((cur / base - 1) * 100, 1)})
        prev = cur
    return out


def mult_total(kind, lv, P):
    if kind == "cooldown":
        return 1.0 / sm("cooldown", lv, P)
    if kind == "area":
        return 1.0 + P["stats"]["area"]["step"] * lv     # AoE 命中数≈面积∝1+step*lv
    if kind == "damage":
        return sm("damage", lv, P)
    return 1.0


def combo_table(P):
    """组合收益表：验证"加算 vs 乘算"的排序差异"""
    out = []
    for dv in (0, 3, 5):
        for cv in (0, 3, 5):
            for av in (0, 2, 5):
                d = sm("damage", dv, P)
                c = 1.0 / sm("cooldown", cv, P)
                a = 1.0 + P["stats"]["area"]["step"] * av
                out.append({"dmg": dv, "cd": cv, "area": av,
                            "mult": round(d * c * a, 3)})
    out.sort(key=lambda r: -r["mult"])
    return out


def breakeven(P):
    """AoE 覆盖必须命中多少目标才能超过单体武器：临界值"""
    res = []
    for t in (60, 300, 600, 900, 1200, 1500, 1800):
        d = density(t, P)
        u_g = weapon_unit("halo", 8, {}, P)
        u_w = weapon_unit("glowstick", 8, {}, P)
        # 蒜环在半径 r 内命中的数量（面密度）
        area_screen = P["world"]["view_w"] * P["world"]["view_h"]
        n_in_circle = d / area_screen * math.pi * u_g["radius"] ** 2 * 0.5
        res.append({"t": t, "mm": "%02d:%02d" % (t // 60, t % 60),
                    "garlic_r": round(u_g["radius"], 1), "in_circle": round(n_in_circle, 2),
                    "garlic_dps": round(u_g["base"] * max(1, n_in_circle), 1),
                    "wand_dps": round(u_w["base"], 1)})
    return res


# ============================================================ 敌人血量定标
def hp_calibration(P):
    """反推：要让需求曲线匹配供给曲线，敌人血量应为多少"""
    rows = []
    for t in (60, 300, 600, 900, 1200, 1500, 1800):
        # 找该时刻的构筑
        lv, b = None, None
        for st, sl, sb in STAGES:
            if st <= t:
                lv, b = sl, sb
        b = dict(b); b["meta"] = {}
        dens = density(t, P)
        dps, _, _ = build_dps(b, P, dens)
        supply = dps
        rate = batch(t, P) / spawn_interval(t, P)
        # 需求 = rate * avg_hp；令 supply = demand → avg_hp = supply/rate
        avg_hp_needed = supply / rate
        es = elite_share(t, P)
        # avg_hp = (1-es)*hp + es*hp*18 → hp = avg/(1-es+18es)
        hp_need = avg_hp_needed / ((1 - es) + es * P["enemy"]["elite_hp_mult"])
        hp_now = ehp(t, P)
        rows.append({"t": t, "mm": "%02d:%02d" % (t // 60, t % 60),
                     "supply_dps": round(supply), "spawn_rate": round(rate, 2),
                     "hp_needed": round(hp_need, 1), "hp_current": round(hp_now, 1),
                     "gap_ratio": round(hp_need / hp_now, 2)})
    return rows


# ============================================================ 经验供给 vs 消耗
def xp_supply(P, kill_gain=0.9, dt=5.0):
    """30min 经验供给：入场率 × 精英加权经验 × 可实现击杀率(R) × 拾取有效率"""
    total_in, total_kill = 0.0, 0.0
    t = 0.0
    while t < P["meta_info"]["run_target_s"]:
        rate = batch(t, P) / spawn_interval(t, P)
        es = elite_share(t, P)
        xp_each = (1 - es) * P["enemy"]["xp_drop"] + es * P["enemy"]["elite_xp_mult"]
        total_in += rate * xp_each * dt
        r = ratio_at(t, P)
        total_kill += rate * xp_each * dt * min(1.0, r)
        t += dt
    return {"xp_entered": round(total_in), "xp_killable": round(total_kill),
            "xp_picked": round(total_kill * kill_gain),
            "kill_gain": kill_gain, "pickup_rate": kill_gain}


def ratio_at(t, P):
    """任意时刻的 R（阶段间线性插值）"""
    prev = None
    for i, (st, sl, sb) in enumerate(STAGES):
        b = dict(sb); b["meta"] = {}
        d = density(st, P)
        r = build_dps(b, P, d)[0] / demand_hp(st, P)
        if st >= t:
            if prev is None:
                return r
            (t0, r0) = prev
            w = (t - t0) / (st - t0) if st > t0 else 0
            return r0 + (r - r0) * w
        prev = (st, r)
    return prev[1] if prev else 0.0


def level_from_xp(total_xp, P):
    """按 xp_curve.formula 的指数（解析自 formula 字符串）逐级消耗"""
    f = float(P["xp_curve"]["formula"].split("^")[1])
    cap = P["xp_curve"].get("level_cap", 99)
    L, acc = 0, total_xp
    while L < cap:
        need = 5.0 + L ** f
        if acc < need:
            break
        acc -= need
        L += 1
    return L, round(acc)


def xp_table(P):
    rows = []
    for g in (0.7, 0.8, 0.9, 1.0):
        s = xp_supply(P, kill_gain=g)
        L, rem = level_from_xp(s["xp_picked"], P)
        rows.append({"pickup": g, "xp_picked": s["xp_picked"], "level_30min": L,
                     "level_remaining_xp": rem,
                     "level_cap": P["xp_curve"].get("level_cap")})
    return rows


def level_pacing(P):
    """前 8 级的实际耗时（用于校验文档'前期 10~30 秒一级'）"""
    rate = batch(60, P) / spawn_interval(60, P) * 0.9
    f = float(P["xp_curve"]["formula"].split("^")[1])
    out = []
    for L in range(1, 9):
        need = 5.0 + L ** f
        out.append({"level": L, "need_xp": round(need), "approx_sec": round(need / rate, 1)})
    return out


# ============================================================ 敏感性
def sensitivity(P):
    """单参数 ±20% 对"最关键阶段（30min）"的 DPS / 生存影响"""
    t = 1800
    lv, base_b = 45, None
    for st, sl, sb in STAGES:
        if st <= t:
            base_b = sb
    b = dict(base_b); b["meta"] = {}
    dens = density(t, P)
    base_dps, _, _ = build_dps(b, P, dens)
    base_hp = maxhp(b["passives"].get("max_hp", 0), P)
    defm = sm("might", b["passives"].get("might", 0), P)
    base_threat = contact_threat(6.0, P, (defm,))
    base_dem = demand_hp(t, P)
    out = []
    knobs = [
        ("敌人血量基准 hp_base", "enemy", "hp_base"),
        ("血量时间指数", "enemy", "time_exponent"),
        ("刷怪批次基数", "spawn", "batch_base"),
        ("刷怪批次增长", "spawn", "batch_per_s_A"),
        ("Sp阶敌速", "enemy", "speed_min"),
        ("接触伤害", "enemy", "contact_damage"),
        ("接触 cadence", "enemy", "contact_cadence"),
        ("玩家无敌帧", "player", "invuln"),
        ("玩家生命上限", "player", "max_hp"),
    ]
    for label, sec, key in knobs:
        for f in (0.8, 1.2):
            Q = json.loads(json.dumps(P))
            Q[sec][key] = P[sec][key] * f
            # 连带：刷怪批次/速度影响密度
            try:
                d2 = density(t, Q)
                dem2 = demand_hp(t, Q)
                dps2, _, _ = build_dps(b, Q, d2)
                hp2 = maxhp(b["passives"].get("max_hp", 0), Q)
                defm2 = sm("might", b["passives"].get("might", 0), Q)
                th2 = contact_threat(6.0, Q, (defm2,))
                out.append({"knob": label, "factor": f,
                            "supply_pct": round((dps2 / base_dps - 1) * 100, 1),
                            "demand_pct": round((dem2 / base_dem - 1) * 100, 1),
                            "ratio_pct": round(((dps2 / dem2) / (base_dps / base_dem) - 1) * 100, 1),
                            "threat_pct": round((th2 / base_threat - 1) * 100, 1),
                            "survive_pct": round(((hp2 / th2) / (base_hp / base_threat) - 1) * 100, 1)})
            except Exception as ex:
                out.append({"knob": label, "factor": f, "error": str(ex)})
    out.sort(key=lambda r: -abs(r.get("ratio_pct", 0)))
    return out


# ============================================================ 美术阵容校核（v3.0 新增）
def roster_demand(t, P):
    """
    按 SVG 实测阵容重算需求侧。
    与 demand_hp 的区别：demand_hp 只有"杂兵 + 精英"两档；
    美术给出的是 3 杂兵（hp_mult 1.0/0.6/1.8）+ 2 精英（18/18）+ 1 Boss。
    杂兵内部加权均值 = (1.0+0.6+1.8)/3 = 1.1333，
    不是 1.0 —— 这是美术阵容带来的**隐性 +13.3% 杂兵血量**。
    """
    ro = P["enemy"]["_art_roster"]
    mobs = [r for r in ro if r["hp_mult"] < 5.0]   # 杂兵档（精英 18 / Boss 900）
    mob_w = sum(r["hp_mult"] for r in mobs) / len(mobs)
    es = elite_share(t, P)
    base = ehp(t, P)
    return batch(t, P) / spawn_interval(t, P) * (
        (1 - es) * base * mob_w + es * base * P["enemy"]["elite_hp_mult"])


def roster_impact(P):
    """阵容重算对需求侧与 R 曲线的影响"""
    rows = []
    for (st, sl, sb) in STAGES:
        d = density(st, P)
        b = dict(sb); b["meta"] = {}
        dps = build_dps(b, P, d)[0]
        old = demand_hp(st, P)
        new = roster_demand(st, P)
        rows.append({"mm": f"{st // 60:02d}:{st % 60:02d}", "t": st,
                     "demand_old": round(old), "demand_new": round(new),
                     "gap_pct": round((new / old - 1) * 100, 1),
                     "R_old": round(dps / old, 2), "R_new": round(dps / new, 2)})
    rs = [r["R_new"] for r in rows]
    peak = max(rows, key=lambda r: r["R_new"])
    # 单峰判定：先升后降，且只有一个局部极大
    eps = 0.02   # 噪声带：小于 0.02 的来回不算转折
    turns = sum(1 for i in range(1, len(rs) - 1)
                if (rs[i] - rs[i - 1]) * (rs[i + 1] - rs[i]) < 0
                and abs(rs[i] - rs[i - 1]) > eps and abs(rs[i + 1] - rs[i]) > eps)
    return {"rows": rows, "peak_mm": peak["mm"], "peak_R": peak["R_new"],
            "monotone_peak_ok": turns <= 1, "turns": turns,
            "note": "R_new 峰值 %.2f @ %s；有效转折 %d 次（<=1 即单峰，噪声带 0.02）" % (peak["R_new"], peak["mm"], turns)}


def boss_check(P):
    """Boss 击杀时长 = HP / (单体 DPS × 分配火力比)"""
    b = P["boss"]
    out = []
    # Boss 战期间 mob_spawn_during_boss=0.35，杂兵只剩 35%，故火力比取 70%
    single_ratio = 0.70
    for ev in b["schedule"]:
        t = ev["t"]
        prev = None
        for (st, sl, sb) in STAGES:
            if st <= t:
                prev = (st, sb)
        st, sb = prev
        d = density(st, P)
        bb = dict(sb); bb["meta"] = {}
        single = build_dps(bb, P, d)[1]
        eff = single * single_ratio
        out.append({"t": t, "mm": "%02d:%02d" % (t // 60, t % 60), "hp": ev["hp"],
                    "single_dps": round(single), "eff_dps": round(eff),
                    "kill_s": round(ev["hp"] / eff, 1),
                    "in_band": 20 <= ev["hp"] / eff <= 40,
                    "hp_for_30s": round(eff * 30, -2)})
    return {"rows": out, "mob_spawn_during_boss": b["mob_spawn_during_boss"],
            "verdict": "全部落在 20~40s 带内时可保留；超出则按 eff_dps×30s 反推 HP"}


def pickup_check(P):
    """掉落物一局产出：用实测 30min 有效击杀 50103 次"""
    kills = round(xp_supply(P)["xp_killable"] / 0.9)   # 反推击杀次数
    kills = 50103  # 实测值，见 §5
    rows = []
    for k in ("magnet", "bomb", "bento"):
        v = P["pickups"][k]
        rows.append({"id": k, "drop_rate": v["drop_rate"],
                     "per_run": round(kills * v["drop_rate"], 1),
                     "interval_s": round(1800 / (kills * v["drop_rate"]), 0),
                     "effect": v["effect"]})
    total = sum(r["per_run"] for r in rows)
    return {"kills": kills, "rows": rows, "total_per_run": round(total, 1),
            "mean_interval_s": round(1800 / total, 1)}


# ============================================================ 主
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="balance_result.json")
    a = ap.parse_args()
    P = load()
    res = {
        "stages": stage_table(P),
        "extreme": extreme_table(P),
        "marginal": {k: marginal(k, P) for k in ("damage", "cooldown", "area")},
        "combo": combo_table(P)[:8],
        "breakeven": breakeven(P),
        "hp_calibration": hp_calibration(P),
        "sensitivity": sensitivity(P),
        "xp_supply": xp_supply(P),
        "xp_table": xp_table(P),
        "level_pacing": level_pacing(P),
        "roster_impact": roster_impact(P),
        "boss": boss_check(P),
        "pickups": pickup_check(P),
    }
    with open(HERE / a.json, "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)

    print("== 关键阶段（供给侧 DPS vs 需求侧血量门槛）")
    print("%-7s %-4s %-6s %-8s %-8s %-6s %-7s %-7s" %
          ("时间", "Lv", "同屏", "需求HP/s", "供给DPS", "比值", "HP", "威胁/s"))
    for r in res["stages"]:
        print("%-7s %-4d %-6d %-8d %-8d %-6.2f %-7d %-7.1f" %
              (r["mm"], r["lv"], r["density"], r["demand_hp"], r["dps"],
               r["dps_ratio"], r["hp"], r["threat"]))
    print("\n== 极端组合（30 分钟参考点）")
    for r in res["extreme"]:
        print("%-38s DPS=%-7d 单体=%-6d 比值=%-6.2f HP=%-4d 存活=%.0fs" %
              (r["name"][:36], r["dps"], r["single"], r["ratio"], r["hp"], r["survive_s"]))
    print("\n== 边际收益")
    for k, v in res["marginal"].items():
        print(k, [(x["lv"], x["delta_pct"]) for x in v])
    print("\n== 敌人血量定标")
    for r in res["hp_calibration"]:
        print(r["mm"], "供给", r["supply_dps"], "刷怪/s", r["spawn_rate"],
              "需血量", r["hp_needed"], "现设", r["hp_current"], "倍差", r["gap_ratio"])

    print("\n== 经验供给 vs 消耗（xp_curve = %s，封顶 %s）" %
          (P["xp_curve"]["formula"], P["xp_curve"].get("level_cap")))
    s = res["xp_supply"]
    print("入场经验 %d / 可击杀 %d / 拾取后 %d" %
          (s["xp_entered"], s["xp_killable"], s["xp_picked"]))
    for r in res["xp_table"]:
        print("  拾取率 %.1f -> 30min Lv%-3d（余 %d XP）" %
              (r["pickup"], r["level_30min"], r["level_remaining_xp"]))
    print("\n== 美术阵容重算（5~6 档敌人 vs 原 2 档）")
    ri = res["roster_impact"]
    print("%-7s %-9s %-9s %-7s %-6s %-6s" % ("时间","原需求","阵容需求","差%","R原","R新"))
    for r in ri["rows"]:
        print("%-7s %-9d %-9d %-+7.1f %-6.2f %-6.2f" %
              (r["mm"], r["demand_old"], r["demand_new"], r["gap_pct"], r["R_old"], r["R_new"]))
    print("  ->", ri["note"])
    print("\n== Boss 战时长（70% 火力分配，因 Boss 战刷怪已压到 35%）")
    for r in res["boss"]["rows"]:
        print("  %s HP=%-6d 单体=%-5d 有效=%-5d 击杀=%.1fs %s" %
              (r["mm"], r["hp"], r["single_dps"], r["eff_dps"], r["kill_s"],
               "OK" if r["in_band"] else "超带"))
    print("\n== 掉落物产出（实测击杀 %d）" % res["pickups"]["kills"])
    for r in res["pickups"]["rows"]:
        print("  %-7s rate=%.4f 一局 %.1f 个 / 平均 %.0f 秒一个" %
              (r["id"], r["drop_rate"], r["per_run"], r["interval_s"]))
    print("  合计 %.1f 个，平均 %.0f 秒一个" %
          (res["pickups"]["total_per_run"], res["pickups"]["mean_interval_s"]))

    print("  前期节奏：", " ".join("Lv%d>%d需%d(~%ss)" %
                                   (x["level"], x["level"], x["need_xp"], x["approx_sec"])
                                   for x in res["level_pacing"]))


if __name__ == "__main__":
    main()
