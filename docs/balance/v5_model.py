#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《守艺人·百工夜行》v5 —— 局内可玩性 / 进程延展 / 局内自洽 重写模型

在 v4 基础上解决实机三大痛点：
  ① 10min 后可挂机        → 加「主动技框架」+「周期潮涌/小boss」持续威胁
  ② 技能 10min 基本升满    → 加「精炼」系统（Lv8 后再 pick 不浪费）+ 拉慢早期 XP、抬高 cap
  ③ 无局外加成无法通关     → 下调 Boss 血 / 延长更鼓至 1.40 / 精炼抬终局 DPS，使干净局内可独立击杀

数值仍以 R = 供给有效 DPS / 需求 HP-per-s 为口径，与 balance_model.py 一致。
输出 docs/balance/v5_result.json。
"""

import json
import math
import argparse
from pathlib import Path

HERE = Path(__file__).resolve().parent

VIEW_W, VIEW_H = 720.0, 1280.0
AREA_SCREEN = VIEW_W * VIEW_H

# ============================================================ 敌潮
HP_BASE, HP_REF, HP_EXP = 3.0, 1800.0, 1.62          # v5: 后期血指数略缓（助局内自洽）
SPAWN_IV = (1.1, 0.45, 600.0)
BATCH = (6.0, 0.01, 30)
ELITE_HP_MULT = 18.0
MOB_MEAN_HP_MULT = (1.0 + 0.6 + 1.8) / 3.0
MAX_ALIVE = 400
WAVES = [(0, 300, 0.00), (300, 600, 0.06), (600, 1200, 0.10), (1200, 1500, 0.14), (1500, 1800, 0.18)]
BOSS_T = 1800.0
BOSS_HP = 7000.0                                      # v5: 11000 → 7000（局内可独立击杀）

# ============================================================ 中期机制（沿用 v4）
SHELL_ON, SHELL_FADE0, SHELL_OFF = 480.0, 1020.0, 1200.0
SHELL_HP_MULT = 1.40
SHELL_AOE_TAKEN = 0.75
DRUM_STEP = 0.08
DRUM_TIMES = [300.0, 600.0, 1200.0, 1500.0, 1800.0]   # v5: 30min 再加一更 → 1.40
EVO_DELAY = 90.0

# ============================================================ v5 新增：周期潮涌（防挂机）
# (起始秒, 持续秒, 刷新倍率, 精英附加) —— 只做"尖峰"，不做"持续塌缩"
SURGES = [
    (600.0, 22.0, 1.35, 0.08),
    (900.0, 22.0, 1.40, 0.10),
    (1200.0, 22.0, 1.45, 0.12),
    (1500.0, 22.0, 1.50, 0.14),
    (1740.0, 45.0, 1.55, 0.16),
]

# ============================================================ v5 新增：精炼（进程延展）
MAX_WEAPON_LV = 8
MAX_REFINE = 3
REFINE_STEP = 0.06          # 每级精炼该武器 DPS +6%
SLOTS = 6
STAT_MAX = 5
CAP = 60                    # v5: 48 → 60（给精炼留预算）
XP_EXP = 2.60               # v5: 2.50 → 2.60（拉慢早期，避免 10min 升满）


def ehp(t):
    return HP_BASE * (1.0 + t / HP_REF) ** HP_EXP


def spawn_interval(t):
    a = min(1.0, t / SPAWN_IV[2])
    return SPAWN_IV[0] + (SPAWN_IV[1] - SPAWN_IV[0]) * a


def batch(t):
    return min(BATCH[0] + BATCH[1] * t, BATCH[2])


def lam(t):
    return batch(t) / spawn_interval(t)


def elite_share(t):
    for a, b, s in WAVES:
        if a <= t < b:
            return s
    return WAVES[-1][2]


def surge_at(t):
    for a, dur, lm, ea in SURGES:
        if a <= t < a + dur:
            return lm, ea
    return 1.0, 0.0


def density(t):
    travel = (760.0 - 24.0) / (0.5 * (60.0 + 95.0))
    return min(lam(t) * travel, MAX_ALIVE)


def shell_w(t):
    if t < SHELL_ON or t >= SHELL_OFF:
        return 0.0
    if t < SHELL_FADE0:
        return 1.0
    return 1.0 - (t - SHELL_FADE0) / (SHELL_OFF - SHELL_FADE0)


def shell_on(t):
    return shell_w(t) > 0.0


def drum_mult(t):
    return 1.0 + DRUM_STEP * sum(1 for x in DRUM_TIMES if t >= x)


def demand(t, use_shell=True, with_surge=True):
    w = shell_w(t) if use_shell else 0.0
    mob = MOB_MEAN_HP_MULT * (1.0 + w * (SHELL_HP_MULT - 1.0))
    slm, sea = surge_at(t)
    if not with_surge:
        slm, sea = 1.0, 0.0
    es = min(0.45, elite_share(t) + sea)
    return lam(t) * slm * ((1.0 - es) * ehp(t) * mob + es * ehp(t) * ELITE_HP_MULT)


# ============================================================ 武器表（吸收参考方案机制打磨）
WEAPONS = {
    "whip": dict(name="傩面·师刀", arche="sweep", kind="aoe", cd=1.30, dmg=11.0, per=1.20,
                 length=110.0, len_per=12.0, width=64.0, len_cap=260.0, cap=8,
                 double_sweep=True),                                   # v5: Lv7/8 扫两次（参考§4）
    "halo": dict(name="花灯", arche="aura", kind="aoe", cd=0.50, dmg=3.60, per=0.65,
                 radius=70.0, r_per=7.0, cap=10, slow=0.22, slow_dmg=0.20),  # v5: 减速 0.15→0.22 + 对减速敌 +20%
    "glowstick": dict(name="糖画", arche="locked", kind="single", cd=1.00, cd_per=0.05,
                      dmg=11.0, per=2.40, pierce=1, aim=0.88, cap_proj=4,
                      pierce_milestone=True),                          # v5: Lv4/8 各 +1 穿透
    "phone": dict(name="皮影", arche="orbit", kind="aoe", cd=1.10, dmg=11.0, per=1.30,
                  radius=58.0, r_per=5.0, count=2, cap=12, knock=0.15), # v5: 命中击退 0.15
    "blade": dict(name="剪纸", arche="bounce", kind="single", cd=0.85, cd_per=0.04,
                  dmg=10.0, per=2.60, bounce=3, aim=0.75,
                  bounce_falloff=True),                                 # v5: 同目标 2 跳后 -30%
    "extinguisher": dict(name="打铁花", arche="arc", kind="aoe", cd=1.60, dmg=13.0, per=2.0,
                         count=2, path_len=320.0, path_w=36.0, hit_cap=4,
                         explode_radius=76.0, explode_ratio=0.65),      # v5: 引爆型（参考§2）
    # ---------------- v4 新增，保留 ----------------
    "gong": dict(name="铜锣", arche="aura", kind="aoe", cd=1.80, dmg=14.0, per=2.00,
                 radius=150.0, r_per=10.0, cap=8, amp=0.12),
    "inkline": dict(name="墨斗", arche="line", kind="single", cd=0.90, cd_per=0.04,
                    dmg=16.0, per=8.00, pierce=1, aim=0.90, shell_bonus=1.80),
    "print": dict(name="木版年画", arche="zone", kind="aoe", cd=2.20, dmg=30.0, per=3.50,
                  radius=105.0, cap=6, delay=0.45, focus=1.8),
}

EVOLUTIONS = {
    "whip": dict(req="damage", dps=1.70, area=1.50, name="火神开脸"),
    "halo": dict(req="area", dps=1.40, area=1.60, name="走马灯"),
    "glowstick": dict(req="cooldown", dps=1.50, area=1.00, name="龙凤呈祥"),
    "gong": dict(req="area", dps=1.50, area=1.50, name="开市锣"),
    "inkline": dict(req="damage", dps=1.55, area=1.10, name="龙筋墨线"),
    "extinguisher": dict(req="area", dps=1.50, area=1.40, name="百子千花"),  # v5: 打铁花进化（参考§2.5）
}


def stat_mult(kind, lv):
    lv = max(0, int(lv))
    if kind == "damage":
        return 1.0 + 0.10 * min(lv, STAT_MAX)
    if kind == "cooldown":
        return max(0.40, 1.0 - 0.05 * min(lv, STAT_MAX))
    if kind == "area":
        return 1.0 + 0.07 * min(lv, STAT_MAX)
    if kind == "speed":
        return 1.0 + 0.08 * min(lv, STAT_MAX)
    if kind == "max_hp":
        return 100.0 + 20.0 * min(lv, STAT_MAX)
    if kind == "might":
        return max(0.50, 1.0 - 0.07 * min(lv, STAT_MAX))
    return 1.0


def cap_eff(lv, cap):
    return 1.0 + (cap - 1.0) * (lv - 1) / float(MAX_WEAPON_LV - 1)


def refine_mult(refine):
    return 1.0 + REFINE_STEP * min(refine, MAX_REFINE)


def weapon_hits(wid, lv, pv, n_alive):
    w = WEAPONS[wid]
    a = w["arche"]
    dens = n_alive / AREA_SCREEN
    if a == "sweep":
        ln = min((w["length"] + w["len_per"] * (lv - 1)) * stat_mult("area", pv.get("area", 0)), w["len_cap"])
        return max(1.0, min(math.pi * (ln * 0.5) ** 2 * 0.5 * dens, cap_eff(lv, w["cap"])))
    if a == "aura":
        r = (w["radius"] + w["r_per"] * (lv - 1)) * stat_mult("area", pv.get("area", 0))
        return max(1.0, min(math.pi * r * r * 0.5 * dens, cap_eff(lv, w["cap"])))
    if a == "orbit":
        r = (w["radius"] + w["r_per"] * (lv - 1)) * stat_mult("area", pv.get("area", 0))
        cnt = w["count"] + (1 if lv >= 4 else 0) + (1 if lv >= 7 else 0)
        return max(1.0, min(math.pi * r * r * 0.5 * dens + (cnt - 2) * 0.8, cap_eff(lv, w["cap"])))
    if a == "arc":
        per = max(1.0, min(w["path_len"] * w["path_w"] * dens, cap_eff(lv, w["hit_cap"])))
        return per * w["count"]
    if a == "locked":
        return float(min(1 + (lv - 1) // 2, w["cap_proj"]))
    if a == "bounce":
        return 1.0 + w["bounce"] * 0.70
    if a == "line":
        return 1.0 + 0.35 * w["pierce"]
    if a == "zone":
        return max(1.0, min(math.pi * w["radius"] ** 2 * 0.5 * dens * w["focus"], cap_eff(lv, w["cap"])))
    raise KeyError(a)


def weapon_dps(wid, lv, pv, n_alive, evo=False, refine=0):
    w = WEAPONS[wid]
    dmg = (w["dmg"] + w["per"] * (lv - 1)) * stat_mult("damage", pv.get("damage", 0))
    cd = w["cd"]
    if "cd_per" in w:
        cd = max(0.15, cd * (1 - w["cd_per"] * (lv - 1)))
    cd *= stat_mult("cooldown", pv.get("cooldown", 0))
    if evo:
        dmg *= EVOLUTIONS[wid]["dps"]
    dmg *= refine_mult(refine)
    h = weapon_hits(wid, lv, pv, n_alive)
    if w["arche"] in ("locked", "bounce", "line"):
        dmg *= w["aim"]
    # 注：打铁花引爆（explode_ratio）为"每发触发一次"的扎堆加伤，不并入稳态收敛带；
    # 其扎堆加成（约 +35~47%）在文档与 extreme_table 的 E4 中单独计入。
    return dmg * h / cd, dmg / cd


def build_dps(weapons, pv, n_alive, evolved=None, refines=None):
    evolved = evolved or set()
    refines = refines or {}
    aoe = single = 0.0
    for wid, lv in weapons.items():
        d, _ = weapon_dps(wid, lv, pv, n_alive, wid in evolved, refines.get(wid, 0))
        if WEAPONS[wid]["kind"] == "aoe":
            aoe += d
        else:
            single += d
    return aoe + single, aoe, single


# ============================================================ 升级预算与精炼
PICKUP = 0.90
DEF_ORDER = ["might", "max_hp", "regen", "shield", "speed"]
DPS_ORDER = ["damage", "cooldown", "area"]
PICK_ORDER = ["whip", "halo", "glowstick", "gong", "print", "inkline", "phone", "blade", "extinguisher"]


def xp_need(level, exp):
    return 5.0 + level ** exp


def policy_pick(state, n):
    """v5 代表性中位玩家：深 2 把主武器到 Lv8 + 满 3 输出被动，每 5 次给 1 次防御；
    武器 Lv8 后再 pick → 精炼（不浪费）。作为"下位中位/地板"演示预算延展。"""
    wp, pv, rf = state["weapons"], state["pv"], state["refines"]
    if state["picks"] % 5 == 0:
        for k in DEF_ORDER:
            if pv.get(k, 0) < STAT_MAX:
                pv[k] += 1
                return
    base = build_dps(wp, pv, n, state["evolved"], rf)[0]
    best = None
    for wid in PICK_ORDER:
        lv = wp.get(wid, 0)
        if lv == 0 and len(wp) >= SLOTS:
            continue
        if lv >= MAX_WEAPON_LV:
            if rf.get(wid, 0) < MAX_REFINE:
                w2 = dict(wp); w2[wid] = lv
                r2 = dict(rf); r2[wid] = rf.get(wid, 0) + 1
                g = build_dps(w2, pv, n, state["evolved"], r2)[0] - base
                if best is None or g > best[0]:
                    best = (g, "r", wid)
            continue
        w2 = dict(wp); w2[wid] = lv + 1
        g = build_dps(w2, pv, n, state["evolved"], rf)[0] - base
        if best is None or g > best[0]:
            best = (g, "w", wid)
    for k in DPS_ORDER:
        if pv.get(k, 0) >= STAT_MAX:
            continue
        p2 = dict(pv); p2[k] += 1
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


def run(exp=XP_EXP, cap=CAP, use_shell=True, use_drum=True, use_evo=True, use_surge=True,
         dt=5.0, t_end=1800.0):
    st = dict(weapons={"whip": 1}, pv={k: 0 for k in
              ("damage", "cooldown", "area", "speed", "might", "max_hp", "regen", "shield")},
              refines={}, picks=0, evolved=set(), evo_queue={})
    level, xp_pool = 1, 0.0
    rows = []
    for i in range(int(t_end / dt) + 1):
        t = i * dt
        n = density(t)
        dps, aoe, single = build_dps(st["weapons"], st["pv"], n, st["evolved"], st["refines"])
        dr = drum_mult(t) if use_drum else 1.0
        dps *= dr; aoe *= dr; single *= dr
        dem = demand(t, use_shell, use_surge)
        w = shell_w(t) if use_shell else 0.0
        take = 1.0 - w * (1.0 - SHELL_AOE_TAKEN)
        dps_eff = aoe * take + single
        rows.append(dict(t=t, lv=level, picks=st["picks"], dps=round(dps), aoe=round(aoe),
                         single=round(single), demand=round(dem), R=round(dps_eff / dem, 2),
                         alive=round(n), drum=round(dr, 2), shell=shell_on(t),
                         surge=(surge_at(t)[0] > 1.0),
                         weapons=dict(st["weapons"]), refines=dict(st["refines"]),
                         pv=dict(st["pv"]), evolved=sorted(st["evolved"])))
        if t >= t_end:
            break
        es = min(0.45, elite_share(t) + (surge_at(t)[1] if use_surge else 0.0))
        slm = surge_at(t)[0] if use_surge else 1.0
        xp_pool += lam(t) * slm * ((1 - es) * 1 + es * 12) * dt * PICKUP * min(1.0, dps_eff / dem)
        while level < cap and xp_pool >= xp_need(level, exp):
            xp_pool -= xp_need(level, exp)
            level += 1
            st["picks"] += 1
            policy_pick(st, n)
        if use_evo:
            for wid, lv in list(st["weapons"].items()):
                if wid in st["evolved"] or wid not in EVOLUTIONS:
                    continue
                if lv >= MAX_WEAPON_LV and st["pv"].get(EVOLUTIONS[wid]["req"], 0) >= 1:
                    st["evo_queue"].setdefault(wid, t)
            for wid, t0 in list(st["evo_queue"].items()):
                if t - t0 >= EVO_DELAY and wid not in st["evolved"]:
                    st["evolved"].add(wid)
                    del st["evo_queue"][wid]
    return rows


# ============================================================ 附加表
def growth(wid):
    n = density(1800)
    out = []
    for lv in range(1, 9):
        d, sg = weapon_dps(wid, lv, {}, n)
        out.append((lv, round(d), round(sg), round(weapon_hits(wid, lv, {}, n), 1)))
    return out


def extreme_table():
    n = density(1800)
    dem = demand(1800, True, True)
    dr = drum_mult(1800)
    cases = [
        ("E1 两项点满+3精炼（花灯+年画 Lv8 / 匠5 巧5 火3）",
         {"halo": 8, "print": 8}, {"damage": 5, "cooldown": 5, "area": 3}, {"print": 3}, set()),
        ("E2 四项铺开+精炼（花灯+年画+墨斗+铜锣 Lv8 / 匠5 巧3）",
         {"halo": 8, "print": 8, "inkline": 8, "gong": 8}, {"damage": 5, "cooldown": 3}, {"inkline": 3}, set()),
        ("E3 深度进化（师刀+花灯+铜锣 进化 / 匠5 巧5）",
         {"whip": 8, "halo": 8, "gong": 8}, {"damage": 5, "cooldown": 5}, {}, {"whip", "halo", "gong"}),
        ("E4 纯 AoE（花灯+年画+铜锣+打铁花 Lv8）",
         {"halo": 8, "print": 8, "gong": 8, "extinguisher": 8}, {"damage": 5, "cooldown": 2}, {"extinguisher": 3}, set()),
        ("E5 纯单点（糖画+墨斗+剪纸 Lv8）",
         {"glowstick": 8, "inkline": 8, "blade": 8}, {"damage": 5, "cooldown": 5}, {"inkline": 3}, set()),
    ]
    out = []
    for name, wp, pv, rf, evo in cases:
        d, aoe, single = build_dps(wp, pv, n, evo, rf)
        d *= dr; aoe *= dr; single *= dr
        w = shell_w(1800)
        take = 1.0 - w * (1.0 - SHELL_AOE_TAKEN)
        out.append(dict(name=name, dps=round(d), single=round(single),
                        R=round((aoe * take + single) / dem, 2),
                        # Boss 为单体大目标，AoE 与单点均全额命中（×0.85 容差）
                        boss=round(BOSS_HP / max(1.0, (aoe + single) * 0.85), 1)))
    return out


def pool_table():
    rows = []
    for label, nw, nstat in (("v3.1 池（6武×8 + 7被动×5）", 6, 7),
                             ("v5 池（9武×8 + 9被动×5 + 精炼）", 9, 9)):
        entries_open = (nw - 1) + nstat
        rows.append(dict(label=label, p_open=round(3.0 / entries_open * 100, 1),
                         p_mid=round(3.0 / (nw * 4 + nstat * 2) * 100, 1),
                         p_late=round(3.0 / max(1, nw - 6) * 100, 1) if nw > 6 else 0.0))
    return rows


def progression(rows):
    """进程延展检验：每个标记时刻，已满级武器数 / 已用精炼 pick / 剩余 pick"""
    out = []
    for m in (60, 300, 600, 900, 1200, 1500, 1800):
        r = next((x for x in rows if abs(x["t"] - m) < 1e-6), None)
        if not r:
            continue
        maxed = sum(1 for v in r["weapons"].values() if v >= MAX_WEAPON_LV)
        used_refine = sum(r["refines"].values())
        remain = CAP - 1 - r["picks"]
        out.append(dict(mm="%02d:%02d" % (m // 60, m % 60), lv=r["lv"], picks=r["picks"],
                        maxed=maxed, used_refine=used_refine, remain=remain))
    return out


MARKS = [0, 60, 300, 600, 900, 1200, 1500, 1800]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="v5_result.json")
    a = ap.parse_args()

    variants = {
        "cur": run(exp=2.00, cap=999, use_shell=False, use_drum=False, use_evo=True, use_surge=False),
        "v4": run(exp=2.50, cap=48, use_shell=True, use_drum=True, use_evo=True, use_surge=False),
        "v5_base": run(exp=XP_EXP, cap=CAP, use_shell=True, use_drum=True, use_evo=True, use_surge=False),
        "v5": run(exp=XP_EXP, cap=CAP, use_shell=True, use_drum=True, use_evo=True, use_surge=True),
    }

    band = []
    for wid, w in WEAPONS.items():
        n30 = density(1800)
        d1, _ = weapon_dps(wid, 1, {}, n30)
        d8, s8 = weapon_dps(wid, 8, {}, n30)
        band.append(dict(id=wid, name=w["name"], kind=w["kind"], arche=w["arche"],
                         lv1=round(d1), lv8=round(d8), single8=round(s8),
                         h8=round(weapon_hits(wid, 8, {}, n30), 1),
                         hitcap=w.get("cap", w.get("hit_cap", w.get("cap_proj")))))

    def rows_of(rows):
        out = []
        for m in MARKS:
            r = next((x for x in rows if abs(x["t"] - m) < 1e-6), None)
            if r:
                out.append(dict(mm="%02d:%02d" % (m // 60, m % 60), **r))
        return out

    res = dict(band=band, shell=dict(on=SHELL_ON, off=SHELL_OFF, hp=SHELL_HP_MULT, aoe=SHELL_AOE_TAKEN),
               drum=dict(step=DRUM_STEP, times=DRUM_TIMES),
               surges=[list(s) for s in SURGES], boss=dict(t=BOSS_T, hp=BOSS_HP),
               curve={k: rows_of(v) for k, v in variants.items()},
               prog=progression(variants["v5"]))
    with open(HERE / a.json, "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)

    print("== 武器收敛带（无被动 / 无更鼓 / 30min 密度 N=%d）" % density(1800))
    print("%-13s %-7s %-6s %-6s %-6s %-7s %-6s" % ("id", "名称", "型", "Lv1总", "Lv8总", "单体Lv8", "命中@Lv8"))
    for r in band:
        print("%-13s %-7s %-6s %-6d %-6d %-7d %-6.1f" % (r["id"], r["name"], r["kind"], r["lv1"], r["lv8"], r["single8"], r["h8"]))

    for k, label in (("cur", "现状（exp2.0 / 无上限 / 无浆壳 / 无潮涌）"),
                     ("v4", "v4（exp2.5 / cap48 / 浆壳 / 更鼓 / 无潮涌）"),
                     ("v5_base", "v5 基线（exp2.6 / cap60 / 浆壳 / 更鼓1.40 / 精炼 / 无潮涌）"),
                     ("v5", "v5 含潮涌（同基线 + 周期潮涌尖峰）")):
        print("\n== %s" % label)
        print("%-6s %-4s %-6s %-7s %-9s %-6s %-6s %-5s" % ("时间", "Lv", "picks", "DPS", "需求HP/s", "R", "更鼓", "潮"))
        for r in res["curve"][k]:
            print("%-6s %-4d %-6d %-7d %-9d %-6.2f %-6.2f %-5s" %
                  (r["mm"], r["lv"], r["picks"], r["dps"], r["demand"], r["R"], r["drum"], "★" if r["surge"] else ""))

    print("\n== 进程延展（v5）：标记时刻 已满级武器数 / 已用精炼 / 剩余 pick")
    for r in res["prog"]:
        print("  %s Lv%-2d pick%-2d 满级武器=%d 精炼=%d 剩余=%d" %
              (r["mm"], r["lv"], r["picks"], r["maxed"], r["used_refine"], r["remain"]))

    print("\n== 极限组合（v5，含更鼓 %.2f + 精炼 + Boss=%d）" % (drum_mult(1800), BOSS_HP))
    for r in extreme_table():
        print("  %-40s DPS=%-5d 单体=%-4d R=%.2f Boss击杀=%.1fs" %
              (r["name"], r["dps"], r["single"], r["R"], r["boss"]))

    print("\n== 抽取池")
    for r in pool_table():
        print("  %-30s 开局 %.1f%%  中期 %.1f%%  后期 %.1f%%" %
              (r["label"], r["p_open"], r["p_mid"], r["p_late"]))


if __name__ == "__main__":
    main()
