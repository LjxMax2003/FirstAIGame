#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《守艺人·百工夜行》v4 技能扩充 + 中期难度 —— 解析式模型（定稿）

用途：为 docs/design/skills-and-midgame-v4.md 生成全部表格数字。
口径与 docs/balance/balance_model.py 一致（R = 供给 DPS / 需求 HP-per-s）。
本脚本只新增 v4 需要的机制，不改旧脚本：

  1. 命中数上限随等级成长 cap_eff（Lv1 = 1 → Lv8 = cap）
     修掉旧表"低等级 AoE 在高密度下直接撞上限"（灭火器 Lv1 就有 100 DPS 的根因）
  2. 真实等级预算：1 级 = 1 pick，武器 8 级 / 被动 5 级 / 6 武器槽
     旧表"6 武器 Lv8 + 5 被动满"需要 73 pick，48 级上限下不存在
  3. 浆壳兵：8~23 分钟杂兵结壳（血量 ×1.40，吃 AoE 仅 0.75 倍）
  4. 更鼓强化：每跨一更全局伤害 +8%（不占 pick 的时间门控战力）
  5. 进化：不占 pick，条件满足后 90 秒兑现（等宝箱）

运行：
    python v4_model.py
    python v4_model.py --json v4_result.json
"""

import json
import math
import argparse
from pathlib import Path

HERE = Path(__file__).resolve().parent

VIEW_W, VIEW_H = 720.0, 1280.0
AREA_SCREEN = VIEW_W * VIEW_H

# ============================================================ 敌潮（沿用 v3.1）
HP_BASE, HP_REF, HP_EXP = 3.0, 1800.0, 1.70
SPAWN_IV = (1.1, 0.45, 600.0)
BATCH = (6.0, 0.01, 30)
ELITE_HP_MULT = 18.0
MOB_MEAN_HP_MULT = (1.0 + 0.6 + 1.8) / 3.0     # 美术阵容隐性 +13.3%
MAX_ALIVE = 400
WAVES = [(0, 300, 0.00), (300, 600, 0.06), (600, 1200, 0.10), (1200, 1500, 0.14), (1500, 1800, 0.18)]

# ============================================================ v4 中期机制
SHELL_ON, SHELL_FADE0, SHELL_OFF = 480.0, 1020.0, 1200.0   # 8:00 结壳 / 17:00 起崩 / 20:00 全散
SHELL_HP_MULT = 1.40                     # 结壳期杂兵血量倍率
SHELL_AOE_TAKEN = 0.75                   # 结壳期吃 AoE 的倍率
DRUM_STEP = 0.08                         # 每跨一更全局伤害 +8%
DRUM_TIMES = [300.0, 600.0, 1200.0, 1500.0]
EVO_DELAY = 90.0                         # 满足条件后多久拿到宝箱


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


def density(t):
    travel = (760.0 - 24.0) / (0.5 * (60.0 + 95.0))
    return min(lam(t) * travel, MAX_ALIVE)


def shell_w(t):
    """结壳强度 0~1：8min 起满强度，20~25min 线性退到 0"""
    if t < SHELL_ON or t >= SHELL_OFF:
        return 0.0
    if t < SHELL_FADE0:
        return 1.0
    return 1.0 - (t - SHELL_FADE0) / (SHELL_OFF - SHELL_FADE0)


def shell_on(t):
    return shell_w(t) > 0.0


def drum_mult(t):
    return 1.0 + DRUM_STEP * sum(1 for x in DRUM_TIMES if t >= x)


def demand(t, use_shell=True):
    w = shell_w(t) if use_shell else 0.0
    mob = MOB_MEAN_HP_MULT * (1.0 + w * (SHELL_HP_MULT - 1.0))
    es = elite_share(t)
    return lam(t) * ((1.0 - es) * ehp(t) * mob + es * ehp(t) * ELITE_HP_MULT)


# ============================================================ 武器表 v4
WEAPONS = {
    "whip": dict(name="傩面·师刀", arche="sweep", kind="aoe", cd=1.30, dmg=11.0, per=1.20,
                 length=110.0, len_per=12.0, width=64.0, len_cap=260.0, cap=8),
    "halo": dict(name="花灯", arche="aura", kind="aoe", cd=0.50, dmg=3.60, per=0.65,
                 radius=70.0, r_per=7.0, cap=10, slow=0.15),
    "glowstick": dict(name="糖画", arche="locked", kind="single", cd=1.00, cd_per=0.05,
                      dmg=11.0, per=2.40, pierce=1, aim=0.88, cap_proj=4),
    "phone": dict(name="皮影", arche="orbit", kind="aoe", cd=1.10, dmg=11.0, per=1.30,
                  radius=58.0, r_per=5.0, count=2, cap=12),
    "blade": dict(name="剪纸", arche="bounce", kind="single", cd=0.85, cd_per=0.04,
                  dmg=10.0, per=2.60, bounce=3, aim=0.75),
    "extinguisher": dict(name="打铁花", arche="arc", kind="aoe", cd=1.60, dmg=15.0, per=1.80,
                         count=2, path_len=320.0, path_w=36.0, hit_cap=4),
    # ---------------- v4 新增 ----------------
    "gong": dict(name="铜锣", arche="aura", kind="aoe", cd=1.80, dmg=14.0, per=2.00,
                 radius=150.0, r_per=10.0, cap=8, amp=0.12),
    "inkline": dict(name="墨斗", arche="line", kind="single", cd=0.90, cd_per=0.04,
                    dmg=16.0, per=8.00, pierce=1, aim=0.90, shell_bonus=1.80),
    "print": dict(name="木版年画", arche="zone", kind="aoe", cd=2.20, dmg=30.0, per=3.50,
                  radius=105.0, cap=6, delay=0.45, focus=1.8),
}

MAX_WEAPON_LV = 8
SLOTS = 6
STAT_MAX = 5

EVOLUTIONS = {
    "whip": dict(req="damage", dps=1.70, area=1.50, name="火神开脸"),
    "halo": dict(req="area", dps=1.40, area=1.60, name="走马灯"),
    "glowstick": dict(req="cooldown", dps=1.50, area=1.00, name="龙凤呈祥"),
    "gong": dict(req="area", dps=1.50, area=1.50, name="开市锣"),
    "inkline": dict(req="damage", dps=1.55, area=1.10, name="龙筋墨线"),
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
    """命中数上限随等级成长：Lv1 = 1，Lv8 = cap"""
    return 1.0 + (cap - 1.0) * (lv - 1) / float(MAX_WEAPON_LV - 1)


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


def weapon_dps(wid, lv, pv, n_alive, evo=False):
    w = WEAPONS[wid]
    dmg = (w["dmg"] + w["per"] * (lv - 1)) * stat_mult("damage", pv.get("damage", 0))
    cd = w["cd"]
    if "cd_per" in w:
        cd = max(0.15, cd * (1 - w["cd_per"] * (lv - 1)))
    cd *= stat_mult("cooldown", pv.get("cooldown", 0))
    if evo:
        dmg *= EVOLUTIONS[wid]["dps"]
    h = weapon_hits(wid, lv, pv, n_alive)
    if w["arche"] in ("locked", "bounce", "line"):
        dmg *= w["aim"]
    return dmg * h / cd, dmg / cd


def build_dps(weapons, pv, n_alive, evolved=None):
    evolved = evolved or set()
    aoe = single = 0.0
    for wid, lv in weapons.items():
        d, _ = weapon_dps(wid, lv, pv, n_alive, wid in evolved)
        if WEAPONS[wid]["kind"] == "aoe":
            aoe += d
        else:
            single += d
    return aoe + single, aoe, single


# ============================================================ 升级预算
PICKUP = 0.90
DEF_ORDER = ["might", "max_hp", "regen", "shield", "speed"]
DPS_ORDER = ["damage", "cooldown", "area"]
PICK_ORDER = ["whip", "halo", "glowstick", "gong", "print", "inkline", "phone", "blade", "extinguisher"]


def xp_need(level, exp):
    return 5.0 + level ** exp


def policy_pick(state, n):
    """中位玩家：80% 的 pick 给 DPS 最优，20% 给防御（might → max_hp）"""
    wp, pv = state["weapons"], state["pv"]
    if state["picks"] % 5 == 0:
        for k in DEF_ORDER:
            if pv.get(k, 0) < STAT_MAX:
                pv[k] += 1
                return
    base = build_dps(wp, pv, n)[0]
    best = None
    for wid in PICK_ORDER:
        lv = wp.get(wid, 0)
        if lv >= MAX_WEAPON_LV or (lv == 0 and len(wp) >= SLOTS):
            continue
        w2 = dict(wp)
        w2[wid] = lv + 1
        g = build_dps(w2, pv, n)[0] - base
        if best is None or g > best[0]:
            best = (g, "w", wid)
    for k in DPS_ORDER:
        if pv.get(k, 0) >= STAT_MAX:
            continue
        p2 = dict(pv)
        p2[k] += 1
        g = build_dps(wp, p2, n)[0] - base
        if best is None or g > best[0]:
            best = (g, "p", k)
    if best is None:
        return
    if best[1] == "w":
        wp[best[2]] = wp.get(best[2], 0) + 1
    else:
        pv[best[2]] += 1


def run(exp, cap, use_shell=True, use_drum=True, use_evo=True, dt=5.0, t_end=1800.0):
    st = dict(weapons={"whip": 1},
              pv={k: 0 for k in ("damage", "cooldown", "area", "speed", "might", "max_hp", "regen", "shield")},
              picks=0)
    level, xp_pool = 1, 0.0
    evolved, evo_queue = set(), {}
    rows = []
    for i in range(int(t_end / dt) + 1):
        t = i * dt
        n = density(t)
        dps, aoe, single = build_dps(st["weapons"], st["pv"], n, evolved)
        dr = drum_mult(t) if use_drum else 1.0
        dps *= dr
        aoe *= dr
        single *= dr
        dem = demand(t, use_shell)
        w = shell_w(t) if use_shell else 0.0
        take = 1.0 - w * (1.0 - SHELL_AOE_TAKEN)
        dps_eff = aoe * take + single
        rows.append(dict(t=t, lv=level, picks=st["picks"], dps=round(dps), aoe=round(aoe),
                         single=round(single), demand=round(dem), R=round(dps_eff / dem, 2),
                         alive=round(n), drum=round(dr, 2), shell=shell_on(t),
                         weapons=dict(st["weapons"]), pv=dict(st["pv"]), evolved=sorted(evolved)))
        if t >= t_end:
            break
        es = elite_share(t)
        xp_pool += lam(t) * ((1 - es) * 1 + es * 12) * dt * PICKUP * min(1.0, dps_eff / dem)
        while level < cap and xp_pool >= xp_need(level, exp):
            xp_pool -= xp_need(level, exp)
            level += 1
            st["picks"] += 1
            policy_pick(st, n)
        if use_evo:
            for wid, lv in list(st["weapons"].items()):
                if wid in evolved or wid not in EVOLUTIONS:
                    continue
                if lv >= MAX_WEAPON_LV and st["pv"].get(EVOLUTIONS[wid]["req"], 0) >= 1:
                    evo_queue.setdefault(wid, t)
            for wid, t0 in list(evo_queue.items()):
                if t - t0 >= EVO_DELAY and wid not in evolved:
                    evolved.add(wid)
                    del evo_queue[wid]
    return rows


# ============================================================ 附加表
def growth(wid):
    """单把武器 Lv1~Lv8 的总 DPS / 单体 DPS（无被动，30min 密度）"""
    n = density(1800)
    out = []
    for lv in range(1, 9):
        d, sg = weapon_dps(wid, lv, {}, n)
        out.append((lv, round(d), round(sg), round(weapon_hits(wid, lv, {}, n), 1)))
    return out


def extreme_table():
    """真实预算下的极限组合（48 级 = 47 pick）"""
    n = density(1800)
    dem = demand(1800, True)
    cases = [
        ("E1 两项点满（2 武器 Lv8 + 匠5 巧5 火3）",
         {"halo": 8, "print": 8}, {"damage": 5, "cooldown": 5, "area": 3}, set(), 1.32),
        ("E2 四项铺开（4 武器 Lv8 + 匠5 巧3）",
         {"halo": 8, "print": 8, "inkline": 8, "gong": 8}, {"damage": 5, "cooldown": 3}, set(), 1.32),
        ("E3 深度进化（3 进化 + 匠5 巧5）",
         {"whip": 8, "halo": 8, "gong": 8}, {"damage": 5, "cooldown": 5}, {"whip", "halo", "gong"}, 1.32),
        ("E4 纯 AoE（花灯+年画+铜锣+打铁花）",
         {"halo": 8, "print": 8, "gong": 8, "extinguisher": 8}, {"damage": 5, "cooldown": 2}, set(), 1.32),
        ("E5 纯单点（糖画+墨斗+剪纸）",
         {"glowstick": 8, "inkline": 8, "blade": 8}, {"damage": 5, "cooldown": 5}, set(), 1.32),
    ]
    out = []
    for name, wp, pv, evo, dr in cases:
        d, aoe, single = build_dps(wp, pv, n, evo)
        d *= dr
        aoe *= dr
        single *= dr
        w = shell_w(1800)
        take = 1.0 - w * (1.0 - SHELL_AOE_TAKEN)
        out.append(dict(name=name, dps=round(d), single=round(single),
                        R=round((aoe * take + single) / dem, 2), picks=sum(wp.values()) + sum(pv.values())))
    return out


def pool_table():
    """三选一抽到"指定一张卡"的概率（pool = 剩余可选条目）"""
    rows = []
    for label, nw, nstat in (("v3.1 池（6 武器 × 8 + 7 被动 × 5）", 6, 7),
                             ("v4 池（9 武器 × 8 + 9 被动 × 5）", 9, 9)):
        # 满级态：所有已持有武器 Lv8、被动 Lv5 → 只剩"未持有新武器"
        entries_all = nw * 7 + nstat * 4
        # 开局：1 武器 Lv1 → 池 = 8 武器新 + 9 被动 = 17 条目（武器新卡按 1 条目算）
        entries_open = (nw - 1) + nstat
        rows.append(dict(label=label, entries_open=entries_open,
                         p_open=round(3.0 / entries_open * 100, 1),
                         p_mid=round(3.0 / (nw * 4 + nstat * 2) * 100, 1),
                         p_late=round(3.0 / max(1, nw - 6) * 100, 1) if nw > 6 else 0.0))
    return rows


def boss_check():
    """Boss 击杀时长：HP / (0.7 × 单体 DPS)"""
    rows = []
    for t, hp in ((900, 2800), (1500, 6100), (1800, 11000)):
        pass
    return rows


MARKS = [0, 60, 300, 600, 900, 1200, 1500, 1800]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="v4_result.json")
    a = ap.parse_args()

    variants = {
        "cur": run(2.00, 999, use_shell=False, use_drum=False, use_evo=True),
        "v31": run(2.25, 48, use_shell=False, use_drum=False, use_evo=True),
        "v4_xp": run(2.50, 48, use_shell=False, use_drum=False, use_evo=True),
        "v4": run(2.50, 48, use_shell=True, use_drum=True, use_evo=True),
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
               curve={k: rows_of(v) for k, v in variants.items()})
    with open(HERE / a.json, "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)

    print("== 武器收敛带（无被动、无更鼓、30min 密度 N=%d）" % density(1800))
    print("%-13s %-7s %-6s %-6s %-6s %-7s %-6s %-6s" %
          ("id", "名称", "伤害型", "Lv1总", "Lv8总", "Lv8单体", "h@Lv8", "上限"))
    for r in band:
        print("%-13s %-7s %-6s %-6d %-6d %-7d %-6.1f  %s" %
              (r["id"], r["name"], r["kind"], r["lv1"], r["lv8"], r["single8"], r["h8"], r["hitcap"]))

    for k, label in (("cur", "现状（代码：exp2.0 / 无上限 / 无浆壳）"),
                     ("v31", "v3.1 文档（exp2.25 / cap48）"),
                     ("v4_xp", "v4 只改 XP（exp2.50 / cap48）"),
                     ("v4", "v4 完整（+浆壳 +更鼓）")):
        print("\n== %s" % label)
        print("%-6s %-4s %-6s %-7s %-9s %-6s %-6s" % ("时间", "Lv", "picks", "DPS", "需求HP/s", "R", "更鼓"))
        for r in res["curve"][k]:
            print("%-6s %-4d %-6d %-7d %-9d %-6.2f %-6.2f" %
                  (r["mm"], r["lv"], r["picks"], r["dps"], r["demand"], r["R"], r["drum"]))

    print("\n== v4 新武器成长表（无被动，30min 密度）")
    for wid in ("gong", "inkline", "print"):
        g = growth(wid)
        print("  %-6s %s" % (WEAPONS[wid]["name"],
              "  ".join("Lv%d:%d/%d(h%.1f)" % (lv, d, s2, h) for lv, d, s2, h in g)))

    print("\n== 真实预算极限组合（47 pick）")
    for r in extreme_table():
        print("  %-34s picks=%-3d DPS=%-5d 单体=%-4d R=%.2f" %
              (r["name"], r["picks"], r["dps"], r["single"], r["R"]))

    print("\n== 抽取池：三选一抽到某个指定条目的概率")
    for r in pool_table():
        print("  %-34s 开局 %.1f%%  中期 %.1f%%  后期 %.1f%%" %
              (r["label"], r["p_open"], r["p_mid"], r["p_late"]))

    last = res["curve"]["v4"][-1]
    print("\n== v4 30min 构筑：Lv%d picks=%d 武器=%s" % (last["lv"], last["picks"], last["weapons"]))
    print("   被动=%s 已进化=%s 单体DPS=%d" % (last["pv"], last["evolved"], last["single"]))


if __name__ == "__main__":
    main()
