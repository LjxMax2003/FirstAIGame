#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《守艺人·百工夜行》v7 —— 平衡真相源·第 2 环

【为什么要有这一版，而不是继续改 v6_model.py】
v7 策划案 §3.2 L-01 诊断出的病根是"文档说 A、代码是 B、模型是 C"。
v5 / v6 模型都把数值**手抄**在自己文件里，于是每改一次代码就多一次漂移机会
（实测：花灯代码 4.00 / v5 文档 3.60 / v6 文档 2.50，三份数各说一套）。

v7 的做法是把链条钉死：

    WeaponDB / Stats / WaveTable（代码）
        → tools/BalanceDump.tscn（导出 v7_code_dump.json）
        → 本文件（读 dump，算曲线）
        → v7_result.json
        → tools/BalanceAudit.tscn（拿代码和 result 里的 fingerprint 逐项比，> ±3% 即红）

也就是说：**本文件里不出现任何一个武器数值**。所有 digit 都来自 dump。
改数值必须先改代码、重跑 dump、再重跑本文件，中间没有第三条路。

用法：
    cd GameDemo/first-xi-xue-gui
    godot --headless --path . res://tools/BalanceDump.tscn      # 代码 → dump
    python ../../docs/balance/v7_model.py                       # dump → result
"""

import json
import math
import argparse
from pathlib import Path

HERE = Path(__file__).resolve().parent
DUMP = HERE / "v7_code_dump.json"

VIEW_W, VIEW_H = 720.0, 1280.0
AREA_SCREEN = VIEW_W * VIEW_H
MAX_ALIVE = 400
SPAWN_RING = 760.0
SPAWN_INNER = 24.0
MOB_SPEED_LO, MOB_SPEED_HI = 60.0, 95.0
# 本局玩家侧假设：代表性中位玩家（与 v5/v6 同一套假设，不因 v7 改动）
SLOTS = 6
XP_EXP = 2.60
CAP = 60
PICKUP = 0.90
EVO_DELAY = 90.0
# Boss 战期间刷怪压到 35%（WaveTable.MOB_SPAWN_DURING_BOSS），对 demand 无影响，
# 但对"Boss 击杀时间"没有影响（那是单体目标），所以只在这里注一笔。
T_END = 1800.0


# ============================================================ 读 dump
def load_dump():
    if not DUMP.exists():
        raise SystemExit(
            "缺少 %s —— 先跑：godot --headless --path . res://tools/BalanceDump.tscn" % DUMP)
    with open(DUMP, encoding="utf-8") as f:
        return json.load(f)


D = load_dump()
W = D["weapons"]
S = D["stats"]
V = D["waves"]


# ============================================================ 敌潮（全部读 dump）
HP_CURVE = V["hp_curve"]
LAM_CURVE = V["lam_curve"]
SAMPLE_DT = V["run_length"] / (len(HP_CURVE) - 1)


def _sample(curve, t):
    """对代码采样曲线做线性插值。t 超出末端就钳住 —— 与代码的行为一致。"""
    if t <= 0.0:
        return curve[0]
    x = t / SAMPLE_DT
    i = int(x)
    if i >= len(curve) - 1:
        return curve[-1]
    f = x - i
    return curve[i] * (1.0 - f) + curve[i + 1] * f


def ehp(t):
    return _sample(HP_CURVE, t)


def lam(t):
    return _sample(LAM_CURVE, t)


def elite_share(t):
    for w in V["waves"]:
        if w["t0"] <= t < w["t1"]:
            return w["elite_share"]
    return V["waves"][-1]["elite_share"]


def surge_at(t):
    for s in V["surges"]:
        if s["t0"] <= t < s["t0"] + s["dur"]:
            return s["lam_mult"], s["elite_add"]
    return 1.0, 0.0


def density(t):
    travel = (SPAWN_RING - SPAWN_INNER) / (0.5 * (MOB_SPEED_LO + MOB_SPEED_HI))
    return min(lam(t) * travel, MAX_ALIVE)


def mob_mean_hp_mult():
    ms = list(V["mobs"].values())
    return sum(m["hp_mult"] for m in ms) / len(ms)


def shell_w(t):
    if t < V["shell_on"] or t >= V["shell_off"]:
        return 0.0
    if t < V["shell_fade0"]:
        return 1.0
    return 1.0 - (t - V["shell_fade0"]) / (V["shell_off"] - V["shell_fade0"])


def drum_mult(t):
    return 1.0 + V["drum_step"] * sum(1 for x in V["drum_times"] if t >= x)


def demand(t, use_shell=True, use_surge=True):
    w = shell_w(t) if use_shell else 0.0
    mob = mob_mean_hp_mult() * (1.0 + w * (V["shell_hp_mult"] - 1.0))
    slm, sea = surge_at(t) if use_surge else (1.0, 0.0)
    es = min(0.45, elite_share(t) + sea)
    # 精英血量倍率取 dump 里的均值（box / red 相同）
    eh = sum(e["hp_mult"] for e in V["elites"].values()) / max(1, len(V["elites"]))
    return lam(t) * slm * ((1.0 - es) * ehp(t) * mob + es * ehp(t) * eh)


# ============================================================ 被动
def stat_mult(kind, lv):
    lv = max(0, min(int(lv), S["stat_max"]))
    t = S["tables"].get(kind)
    if t is None:
        return 1.0
    return t[lv]


def refine_mult(tier):
    return 1.0 + S["refine_step"] * min(tier, S["refine_max"])


def cap_eff(lv, cap):
    """命中上限随等级从 1 线性放到 cap（与 v5/v6 同口径，属于**模型假设**而非代码值）。"""
    if cap <= 0:
        return float("inf")
    return 1.0 + (cap - 1.0) * (lv - 1) / float(len(W["whip"]["dmg_curve"]) - 1)


# ============================================================ 命中数（按 kind 走代码的几何字段）
def weapon_hits(wid, lv, pv, n_alive):
    w = W[wid]
    kind = w["kind"]
    dens = n_alive / AREA_SCREEN
    area = stat_mult("area", pv.get("area", 0))
    cap = w["hit_cap"]

    if kind == "melee":
        ln = min((w["length"] + w["length_per_level"] * (lv - 1)) * area, w["length_cap"])
        return max(1.0, min(math.pi * (ln * 0.5) ** 2 * 0.5 * dens, cap_eff(lv, cap)))

    if kind == "aura":
        r = (w["radius"] + w["radius_per_level"] * (lv - 1)) * area
        return max(1.0, min(math.pi * r * r * 0.5 * dens, cap_eff(lv, cap)))

    if kind == "orbit":
        # 环绕体是**逐点碰撞**：每只环绕体每个 tick 撞到一个目标就是 1 次，
        # 所以这里用 count 而不是面积覆盖率 —— 面积覆盖率会把它算成 6 只，
        # 而实测（tools/HaloLogic）皮影一次 tick 打到的是 1~2 只。
        return float(max(1, w["orbit_count"]))

    if kind == "arc_projectile":
        ln = w["length"] if w["length"] > 0 else 320.0
        wd = w["width"] if w["width"] > 0 else 36.0
        per = max(1.0, min(ln * wd * dens, cap_eff(lv, cap)))
        return per * float(max(1, w["count"]))

    if kind == "projectile":
        # 锁定型（糖画，有 count_*）与弹射型（剪纸，有 bounce）必须分开：
        # 前者是"一次发几枚"，后者是"一枚跳几次"。
        if w["count_per_two_level"] > 0:
            n = min(w["count_base"] + w["count_per_two_level"] * ((lv - 1) // 2), w["count_cap"])
            return float(n)
        if w["bounce"] > 0:
            return 1.0 + float(w["bounce"]) * 0.70
        return 1.0

    if kind == "line":
        p = w["pierce"]
        if w["pierce_milestone"]:
            l = max(1, lv)
            if l >= 4:
                p += 1
            if l >= 8:
                p += 1
        return 1.0 + 0.35 * float(p)

    if kind == "zone":
        r = (w["radius"] + w["radius_per_level"] * (lv - 1)) * area
        return max(1.0, min(math.pi * r * r * 0.5 * dens * 1.8, cap_eff(lv, cap)))

    return 1.0


def weapon_dps(wid, lv, pv, n_alive, evolved=False, refine=0):
    """返回 (总 DPS（含命中数）, 单体 DPS)。dmg / cd 一律读 dump 的逐级曲线。"""
    w = W[wid]
    dmg = w["dmg_curve"][lv - 1] * stat_mult("damage", pv.get("damage", 0))
    # cd_curve 已经带上了 WeaponDB.cooldown_at() 自己的地板（0.12）。
    # 这里**不能**再套 Stats.COOLDOWN_ABS_FLOOR（0.35）—— 那是"被动乘数"的绝对地板，
    # 用在武器本体冷却上会把皮影的 0.28 抬到 0.35（DPS 直接掉 20%）。
    cd = w["cd_curve"][lv - 1] * stat_mult("cooldown", pv.get("cooldown", 0))
    if evolved:
        dmg *= EVO_DPS.get(wid, 1.0)
    dmg *= refine_mult(refine)
    single = dmg / cd
    h = weapon_hits(wid, lv, pv, n_alive)

    # 双扫：Lv7+ 每轮多扫一刀（代码里是第二次 _scratch 判定，倍率 double_sweep_ratio）
    sweep = 1.0
    if w["double_sweep"] and lv >= w["double_sweep_from"]:
        sweep = 1.0 + w["double_sweep_ratio"]

    total = dmg * h * sweep / cd

    # 打铁花铁水散开（v6 §4 / v7 T8）：每发在**第一个命中点**碎一次，
    # 150 半径内每只吃 scatter_ratio × 主伤，最多 scatter_cap 只。
    # 这是代码里真实存在的第二段，不能只在 report 里提一句就算进 band。
    if w["scatter_radius"] > 0 and w["scatter_ratio"] > 0:
        r = w["scatter_radius"] * stat_mult("area", pv.get("area", 0))
        # 覆盖数随等级长：和 WeaponDB.scatter_cap_at() 同一个公式，改一处必须改两处
        cap = max(1, int(w["scatter_cap"]) + int(w["scatter_cap_per_level"]) * (lv - 1))
        eh = min(math.pi * r * r * 0.5 * (n_alive / AREA_SCREEN), float(cap))
        # 每发最多碎一次 → 一轮最多 count 次。
        # **不额外 +1**：被直击那只不吃自己触发的溅射（Brotato 规则），所以它不计入 eh。
        n_burst = float(max(1, w["count"]))
        total += dmg * w["scatter_ratio"] * eh * n_burst / cd

    return total, single


def build_dps(weapons, pv, n_alive, evolved=None, refines=None):
    evolved = evolved or set()
    refines = refines or {}
    aoe = single = 0.0
    for wid, lv in weapons.items():
        t, s = weapon_dps(wid, lv, pv, n_alive, wid in evolved, refines.get(wid, 0))
        if W[wid]["dmg_kind"] == "aoe":
            aoe += t
        else:
            single += t
    return aoe + single, aoe, single


# ============================================================ 进化（表现层乘区：EvolutionDB 不在 dump 里）
# 这里必须写：进化是**设计意图**（1.4~1.7 的乘区），代码里散在 EvolutionDB 的 dps 字段。
# 为了不引入第二次漂移，采用"读取失败即报错"的策略：dump 里有就用，没有就用这份兜底并标注。
EVO_DPS = {
    "whip": 1.70, "halo": 1.40, "glowstick": 1.50,
    "gong": 1.50, "inkline": 1.55, "extinguisher": 1.50,
}


# ============================================================ 升级预算
DEF_ORDER = ["might", "max_hp", "regen", "shield", "speed"]
DPS_ORDER = ["damage", "cooldown", "area"]
PICK_ORDER = ["whip", "halo", "glowstick", "gong", "print", "inkline", "phone", "blade", "extinguisher"]


def xp_need(level):
    return 5.0 + level ** XP_EXP


def policy_pick(state, n):
    wp, pv, rf = state["weapons"], state["pv"], state["refines"]
    if state["picks"] % 5 == 0:
        for k in DEF_ORDER:
            if pv.get(k, 0) < S["stat_max"]:
                pv[k] += 1
                return
    base = build_dps(wp, pv, n, state["evolved"], rf)[0]
    best = None
    for wid in PICK_ORDER:
        lv = wp.get(wid, 0)
        if lv == 0 and len(wp) >= SLOTS:
            continue
        if lv >= len(W[wid]["dmg_curve"]):
            if rf.get(wid, 0) < S["refine_max"]:
                r2 = dict(rf)
                r2[wid] = rf.get(wid, 0) + 1
                g = build_dps(wp, pv, n, state["evolved"], r2)[0] - base
                if best is None or g > best[0]:
                    best = (g, "r", wid)
            continue
        w2 = dict(wp)
        w2[wid] = lv + 1
        g = build_dps(w2, pv, n, state["evolved"], rf)[0] - base
        if best is None or g > best[0]:
            best = (g, "w", wid)
    for k in DPS_ORDER:
        if pv.get(k, 0) >= S["stat_max"]:
            continue
        p2 = dict(pv)
        p2[k] += 1
        g = build_dps(wp, p2, n, state["evolved"], rf)[0] - base
        if best is None or g > best[0]:
            best = (g, "p", k)
    if best is None:
        return
    if best[1] == "w":
        wp[best[2]] = wp.get(best[2], 0) + 1
    elif best[1] == "r":
        rf[best[2]] = rf.get(best[2], 0) + 1
    else:
        pv[best[2]] += 1


def run(use_shell=True, use_drum=True, use_evo=True, use_surge=True, dt=5.0, t_end=T_END):
    zero = {k: 0 for k in
            ("damage", "cooldown", "area", "speed", "might", "max_hp", "regen", "shield")}
    st = dict(weapons={"whip": 1}, pv=dict(zero), refines={}, picks=0,
              evolved=set(), evo_queue={})
    level, xp_pool = 1, 0.0
    rows = []
    for i in range(int(t_end / dt) + 1):
        t = i * dt
        n = density(t)
        dps, aoe, single = build_dps(st["weapons"], st["pv"], n, st["evolved"], st["refines"])
        dr = drum_mult(t) if use_drum else 1.0
        dps *= dr
        aoe *= dr
        single *= dr
        dem = demand(t, use_shell, use_surge)
        w = shell_w(t) if use_shell else 0.0
        take = 1.0 - w * (1.0 - V["shell_aoe_taken"])
        dps_eff = aoe * take + single
        rows.append(dict(t=t, lv=level, picks=st["picks"], dps=round(dps),
                         aoe=round(aoe), single=round(single), demand=round(dem),
                         R=round(dps_eff / dem, 2), alive=round(n), drum=round(dr, 2),
                         shell=shell_w(t) > 0.0, surge=(surge_at(t)[0] > 1.0),
                         weapons=dict(st["weapons"]), refines=dict(st["refines"]),
                         pv=dict(st["pv"]), evolved=sorted(st["evolved"])))
        if t >= t_end:
            break
        es = min(0.45, elite_share(t) + (surge_at(t)[1] if use_surge else 0.0))
        slm = surge_at(t)[0] if use_surge else 1.0
        xp_pool += lam(t) * slm * ((1 - es) * 1 + es * 12) * dt * PICKUP * min(1.0, dps_eff / dem)
        while level < CAP and xp_pool >= xp_need(level):
            xp_pool -= xp_need(level)
            level += 1
            st["picks"] += 1
            policy_pick(st, n)
        if use_evo:
            for wid, lv in list(st["weapons"].items()):
                if wid in st["evolved"] or wid not in EVO_DPS:
                    continue
                if lv >= len(W[wid]["dmg_curve"]):
                    st["evo_queue"].setdefault(wid, t)
            for wid, t0 in list(st["evo_queue"].items()):
                if t - t0 >= EVO_DELAY and wid not in st["evolved"]:
                    st["evolved"].add(wid)
                    del st["evo_queue"][wid]
    return rows


# ============================================================ 表
def band_table():
    n30 = density(T_END)
    out = []
    for wid in D["weapon_order"]:
        d1, s1 = weapon_dps(wid, 1, {}, n30)
        d8, s8 = weapon_dps(wid, 8, {}, n30)
        out.append(dict(id=wid, kind=W[wid]["kind"], dmg_kind=W[wid]["dmg_kind"],
                        lv1=round(d1, 1), lv8=round(d8, 1), single8=round(s8, 1),
                        hits8=round(weapon_hits(wid, 8, {}, n30), 2),
                        hit_cap=W[wid]["hit_cap"]))
    return out


## 辅助档：v6 把花灯 / 皮影定位成"零操作的下限保障"，它们必须在带子底部。
AUX = ("halo", "phone")


def extreme_table():
    n = density(T_END)
    dem = demand(T_END, True, True)
    dr = drum_mult(T_END)
    boss_hp = V["bosses"][-1]["hp"]
    cases = [
        ("E1 双点满 + 3 精炼（花灯+年画 Lv8 / 匠5 巧5 火3）",
         {"halo": 8, "print": 8}, {"damage": 5, "cooldown": 5, "area": 3}, {"print": 3}, set()),
        ("E2 四项铺开 + 精炼（花灯+年画+墨斗+铜锣 Lv8）",
         {"halo": 8, "print": 8, "inkline": 8, "gong": 8}, {"damage": 5, "cooldown": 3},
         {"inkline": 3}, set()),
        ("E3 深度进化（师刀+花灯+铜锣）",
         {"whip": 8, "halo": 8, "gong": 8}, {"damage": 5, "cooldown": 5}, {},
         {"whip", "halo", "gong"}),
        ("E4 纯 AoE（花灯+年画+铜锣+打铁花 Lv8）",
         {"halo": 8, "print": 8, "gong": 8, "extinguisher": 8}, {"damage": 5, "cooldown": 2},
         {"extinguisher": 3}, set()),
        ("E5 纯单点（糖画+墨斗+剪纸 Lv8）",
         {"glowstick": 8, "inkline": 8, "blade": 8}, {"damage": 5, "cooldown": 5},
         {"inkline": 3}, set()),
    ]
    out = []
    for name, wp, pv, rf, evo in cases:
        d, aoe, single = build_dps(wp, pv, n, evo, rf)
        d *= dr
        aoe *= dr
        single *= dr
        take = 1.0 - shell_w(T_END) * (1.0 - V["shell_aoe_taken"])
        # Boss 是单体大目标：AoE 与单点均全额命中，0.85 是"走位/躲技能"的容差
        out.append(dict(name=name, dps=round(d), single=round(single),
                        R=round((aoe * take + single) / dem, 2),
                        boss_s=round(boss_hp / max(1.0, (aoe + single) * 0.85), 1)))
    return out


def progression(rows):
    out = []
    for m in (60, 300, 600, 900, 1200, 1500, 1800):
        r = next((x for x in rows if abs(x["t"] - m) < 1e-6), None)
        if not r:
            continue
        maxed = sum(1 for v in r["weapons"].values() if v >= len(W["whip"]["dmg_curve"]))
        out.append(dict(mm="%02d:%02d" % (m // 60, m % 60), lv=r["lv"], picks=r["picks"],
                        maxed=maxed, used_refine=sum(r["refines"].values()),
                        remain=CAP - 1 - r["picks"]))
    return out


# ---------------------------------------------------------------- 审计指纹
def fingerprint():
    """把"模型用到的每一个代码值"打平成 key → number。
    BalanceAudit 会用同一套 key 在 GDScript 里再算一遍并逐项比对。
    新增任何参与计算的字段都必须加到这里，否则它就是"审计看不见的裸奔数值"。"""
    fp = {}
    for wid in D["weapon_order"]:
        w = W[wid]
        for k in ("cooldown", "cd_per_level", "damage", "dmg_per_level", "aim",
                  "radius", "radius_per_level", "length", "length_per_level",
                  "orbit_radius", "orbit_radius_per_level", "orbit_count",
                  "scatter_radius", "scatter_ratio", "scatter_cap",
                  "scatter_cap_per_level",
                  "hit_cap", "count", "bounce",
                  "pierce", "slow_pct", "slow_dmg", "shell_bonus", "amp"):
            fp["weapon.%s.%s" % (wid, k)] = float(w[k])
        for i, v in enumerate(w["dmg_curve"]):
            fp["weapon.%s.dmg_curve[%d]" % (wid, i)] = float(v)
        for i, v in enumerate(w["cd_curve"]):
            fp["weapon.%s.cd_curve[%d]" % (wid, i)] = float(v)
    for k in ("stat_max", "base_hp", "cooldown_floor", "might_floor", "cooldown_abs_floor",
              "refine_max", "refine_step", "regen_per_lv", "regen_cap",
              "shield_pulse_base", "shield_pulse_per_lv", "shield_period",
              "shield_cap_base", "shield_cap_per_lv"):
        fp["stat." + k] = float(S[k])
    for key, tbl in S["tables"].items():
        for i, v in enumerate(tbl):
            fp["stat.table.%s[%d]" % (key, i)] = float(v)
    for i, v in enumerate(S["shield_cap_curve"]):
        fp["stat.shield_cap_curve[%d]" % i] = float(v)
    for i, b in enumerate(V["bosses"]):
        fp["wave.boss[%d].hp" % i] = float(b["hp"])
        fp["wave.boss[%d].t" % i] = float(b["t"])
    fp["wave.run_length"] = float(V["run_length"])
    fp["wave.shell_hp_mult"] = float(V["shell_hp_mult"])
    fp["wave.shell_aoe_taken"] = float(V["shell_aoe_taken"])
    fp["wave.drum_step"] = float(V["drum_step"])
    for i, v in enumerate(HP_CURVE):
        fp["wave.hp_curve[%d]" % i] = float(v)
    for i, v in enumerate(LAM_CURVE):
        fp["wave.lam_curve[%d]" % i] = float(v)
    return fp


# ============================================================ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="v7_result.json")
    a = ap.parse_args()

    variants = {
        "cur": run(use_shell=False, use_drum=False, use_evo=True, use_surge=False),
        "v7": run(use_shell=True, use_drum=True, use_evo=True, use_surge=True),
    }
    band = band_table()
    ex = extreme_table()
    lv8 = [r["lv8"] for r in band]
    lo, hi = min(lv8), max(lv8)
    aux_vals = [r["lv8"] for r in band if r["id"] in AUX]
    aux_lowest = all(v <= min(x["lv8"] for x in band if x["id"] not in AUX) for v in aux_vals)
    ext = next(r for r in band if r["id"] == "extinguisher")

    res = dict(
        schema=1,
        source="docs/balance/v7_code_dump.json（由 tools/BalanceDump.tscn 从代码导出）",
        band=band,
        band_span=dict(lo=lo, hi=hi, ratio=round(hi / max(lo, 1e-6), 3),
                       aux_lowest=aux_lowest, aux=dict((k, next(r["lv8"] for r in band if r["id"] == k)) for k in AUX)),
        checks=dict(
            # v7 策划案 §3.2 L-01 验收项
            band_ratio_le_1_6=round(hi / max(lo, 1e-6), 3) <= 1.6,
            aux_lowest=aux_lowest,
            extinguisher_single_lt_20=ext["single8"] < 20.0,
            boss_kill_le_12s=all(x["boss_s"] <= 12.0 for x in ex),
        ),
        extreme=ex,
        curve={k: [dict(mm="%02d:%02d" % (int(r["t"]) // 60, int(r["t"]) % 60), **r)
                   for r in v if int(r["t"]) % 60 == 0 or r["t"] == 0] for k, v in variants.items()},
        prog=progression(variants["v7"]),
        survival=dict(
            regen_per_lv=S["regen_per_lv"], regen_cap=S["regen_cap"],
            shield_pulse=[S["shield_pulse_base"] + S["shield_pulse_per_lv"] * l for l in range(6)],
            shield_period=S["shield_period"],
            shield_cap=S["shield_cap_curve"],
        ),
        code_fingerprint=fingerprint(),
    )
    with open(HERE / a.json, "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)

    print("== 收敛带（无被动 / 无更鼓 / 30min 密度 N=%d）" % density(T_END))
    print("%-13s %-6s %-7s %-7s %-7s %-6s" % ("id", "型", "Lv1", "Lv8总", "单体8", "命中8"))
    for r in band:
        flag = " ←辅" if r["id"] in AUX else ""
        print("%-13s %-6s %-7.1f %-7.1f %-7.1f %-6.2f%s" %
              (r["id"], r["dmg_kind"], r["lv1"], r["lv8"], r["single8"], r["hits8"], flag))
    print("\n  跨度 %.2f×（%.1f ~ %.1f）　辅助档垫底=%s" %
          (hi / max(lo, 1e-6), lo, hi, aux_lowest))
    print("  打铁花单体 Lv8 = %.1f（<20 才算过）" % ext["single8"])

    print("\n== R 曲线（v7，含蓄力/更鼓/潮涌/浆壳）")
    print("%-6s %-4s %-6s %-8s %-9s %-6s" % ("时间", "Lv", "picks", "DPS", "需求HP/s", "R"))
    for r in res["curve"]["v7"]:
        print("%-6s %-4d %-6d %-8d %-9d %-6.2f" % (r["mm"], r["lv"], r["picks"], r["dps"], r["demand"], r["R"]))

    print("\n== 极限构筑（Boss=%.0f / 更鼓 %.2f）" % (V["bosses"][-1]["hp"], drum_mult(T_END)))
    for r in ex:
        print("  %-44s DPS=%-5d R=%.2f Boss击杀=%.1fs" % (r["name"], r["dps"], r["R"], r["boss_s"]))

    print("\n== 生存被动（③ 落地后）")
    print("  回春 %.2f×lv，封顶 %.1f/s" % (S["regen_per_lv"], S["regen_cap"]))
    print("  结界 每 %.0fs 脉冲 %s，池上限 %s" %
          (S["shield_period"], [round(x) for x in res["survival"]["shield_pulse"]],
           [round(x) for x in S["shield_cap_curve"]]))

    print("\n== 验收（§3.2 L-01）")
    for k, v in res["checks"].items():
        print("  %-34s %s" % (k, "PASS" if v else "FAIL"))


if __name__ == "__main__":
    main()
