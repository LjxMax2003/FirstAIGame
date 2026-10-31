#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v1 公式静态体检（不含模拟循环）：用解析式复算设计者的隐含意图，暴露量纲与结构问题。
输出：v1 问题清单 + 复算证据。
"""

import math
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


# ---------------- v1：文档口径的原始公式 ----------------
def whip_v1(L, area=1.0, cd=1.0, dmg=1.0, uptime=None):
    """v1 假设 uptime=1（全额命中），用于暴露最坏值；v1 问题清单中另给有效值"""
    c = 1.3 * cd
    length = (110 + 12 * (L - 1)) * area
    width = 64 * area
    dmg_ = 10.0 * dmg * L
    nps = 1.0 / c
    return dmg_, nps, length, width, dmg_ * nps


def garlic_v1(L, area=1.0, cd=1.0, dmg=1.0):
    c = 0.5 * cd
    r = (70 + 10 * (L - 1)) * area
    dmg_ = 4.0 * dmg * L
    return dmg_, 1.0 / c, r, dmg_ / c


def wand_v1(L, cd=1.0, dmg=1.0):
    c = (1.0 - 0.06 * (L - 1)) * cd
    count = min(1 + (L - 1) // 2, 4)
    dmg_ = 12.0 * dmg
    return dmg_, c, count, count / max(c, 0.01)


# ---------------- v2：修正公式 ----------------
def whip_v2(L, area=1.0, cd=1.0, dmg=1.0, uptime=0.85):
    c = 1.3 * cd
    length = (110 + 12 * (L - 1)) * area
    width = 64 * area
    dmg_ = (10.0 + 1.0 * (L - 1)) * dmg
    return dmg_, 1.0 / c, length, width, dmg_ / c * uptime


def garlic_v2(L, area=1.0, cd=1.0, dmg=1.0):
    c = 0.5 * cd
    r = (70 + 10 * (L - 1)) * area
    dmg_ = (4.0 + 1.0 * (L - 1)) * dmg
    return dmg_, 1.0 / c, r, dmg_ / c


def wand_v2(L, cd=1.0, dmg=1.0):
    c = max(0.15, (1.0 - 0.06 * (L - 1)) * cd)
    count = min(1 + (L - 1) // 2, 4)
    dmg_ = 12.0 * dmg
    return dmg_, c, count, dmg_ * count / c


def geo_share(L, step):
    """几何叠加：单属性 L 级对总 DPS 的占比（与 L 无关的常量占比）"""
    return step / (1.0 + step * (L - 1))


def main():
    report = {}

    # ---- 1. 三武器 Lv1 / Lv8 基础 DPS 对比（v1 vs v2）----
    rows = []
    for L in (1, 4, 8):
        w1 = whip_v1(L); g1 = garlic_v1(L); d1 = wand_v1(L)
        w2 = whip_v2(L); g2 = garlic_v2(L); d2 = wand_v2(L)
        rows.append({
            "L": L,
            "v1_whip_nps": round(w1[1], 3), "v1_whip_dmg": w1[0], "v1_whip_dps_uptime1": round(w1[4], 1),
            "v1_garlic_dps": round(g1[3], 1), "v1_wand_dps": round(d1[3], 1),
            "v2_whip_dps": round(w2[4], 1), "v2_garlic_dps": round(g2[3], 1), "v2_wand_dps": round(d2[3], 1),
        })
    report["weapon_dps_table"] = rows

    # ---- 2. 鞭子 vs 蒜环：Lv8 时的 AoE 深度倍数 ----
    area_lv8 = 1.0 + 0.10 * 4      # 蜡烛 cap 5 级
    cover_whip = 110 * 0.85        # 有效伤害直线长度（宽度方向只覆盖 1 层）
    cover_garlic = 2 * (70 + 10 * 7) * area_lv8   # 直径
    report["aoe_depth"] = {
        "whip_depth_m1": round(cover_whip / 48.0, 2),
        "garlic_depth_m1": round(cover_garlic / 48.0, 2),
        "ratio_garlic_over_whip": round((cover_garlic / 48.0) / (cover_whip / 48.0), 2),
        "_note": "m1 = 有效覆盖长度 / 单层队列厚度 48px(2×敌身)。蒜环等效命中数是鞭子的该倍数"
    }

    # ---- 3. 理论最高 DPS 乘数 ----
    dmg_cap = 1.0 + 0.10 * 5
    cd_cap = 1.0 - 0.08 * 5
    area_cap = 1.0 + 0.10 * 5
    meta_might = 1.0 + 0.03 * 5
    meta_cd = 1.0 - 0.03 * 5
    report["dps_multipliers"] = {
        "local_damage": dmg_cap, "local_cooldown": round(cd_cap, 3), "local_area": area_cap,
        "meta_might": meta_might, "meta_cooldown": round(1.0 / meta_cd, 3),
        "product_L1": round(dmg_cap / cd_cap, 3),
        "product_L4": round(dmg_cap / cd_cap * area_cap, 3),
        "product_max": round(dmg_cap / cd_cap * area_cap * meta_might / meta_cd, 3),
    }

    # ---- 4. 边际收益序列 ----
    def marginal(unit_fn, levels):
        series = []
        for L in range(1, levels + 1):
            series.append(unit_fn(L))
        out = []
        for i in range(1, len(series)):
            out.append({
                "from": i + 1, "to": i + 2,
                "delta_pct": round((series[i] - series[i - 1]) / series[i - 1] * 100, 1),
                "cum_pct": round((series[i] / series[0] - 1) * 100, 1),
            })
        return out

    # 单一属性在"其他属性不变"下的边际收益（用 DPS 单体乘数近似）
    def alone(kind, step, L):
        if kind == "cooldown":
            return 1.0 / (1.0 - step * (L - 1))
        if kind == "area":
            return 1.0 + step * (L - 1)
        return 1.0 + step * (L - 1)

    report["marginal_v1"] = {
        "damage": [[r["from"], r["delta_pct"], r["cum_pct"]] for r in marginal(lambda L: alone("damage", 0.10, L), 5)],
        "cooldown": [[r["from"], r["delta_pct"], r["cum_pct"]] for r in marginal(lambda L: alone("cooldown", 0.08, L), 5)],
        "area": [[r["from"], r["delta_pct"], r["cum_pct"]] for r in marginal(lambda L: alone("area", 0.10, L), 5)],
    }
    report["marginal_v2"] = {
        "damage": [[r["from"], r["delta_pct"], r["cum_pct"]] for r in marginal(lambda L: alone("damage", 0.10, L), 5)],
        "cooldown": [[r["from"], r["delta_pct"], r["cum_pct"]] for r in marginal(lambda L: alone("cooldown", 0.05, L), 5)],
        "area": [[r["from"], r["delta_pct"], r["cum_pct"]] for r in marginal(lambda L: alone("area", 0.07, L), 5)],
    }

    # ---- 5. 升级间隔复算（XP 曲线 5+n^2）----
    xp_curve = []
    cum = 0
    for n in range(1, 13):
        need = 5 + n * n
        cum += need
        xp_curve.append({"level_after": n, "to_next": need, "cum_xp": cum})
    report["xp_curve_v1"] = xp_curve

    # 经验来源：击杀 → XP（每杀 1 xp，精英 12xp）
    # 关键判断：30 分钟内需要的总 XP
    total_need = sum(5 + n * n for n in range(1, 46))
    report["xp_budget"] = {
        "xp_for_lv45": total_need,
        "kills_assumed_v1": 30 * 60 * 0.8,
        "_note": "v1 每杀 1xp + 精英 12xp；若 30 分钟平均 0.8 杀/秒，则总经验约 1440，只够到 Lv9"
    }

    # ---- 6. 蒜环推离 vs 接触节奏 ----
    report["garlic_knockback_check"] = {
        "pulse_cd": 0.5, "contact_cadence": 0.6,
        "_note": "原文档蒜环描述含'推开'；若推离距离 > 敌人 0.5s 内前进距离，则接触伤害几乎归零，蒜环成为无敌挂",
        "enemy_move_per_pulse_60": round(60 * 0.5, 1),
        "enemy_move_per_pulse_95": round(95 * 0.5, 1),
    }

    # ---- 7. 经验量与敌人血量量纲对比 ----
    report["hp_vs_xp"] = {
        "hp_base": 3.0, "whip_dmg_lv1": 10.0,
        "note": "v1 起步鞭子 10 伤害 / 杂兵 3 血 = 3 倍单发伤害；30 分钟敌人血量需 150~1000 才能匹配 v1 的 DPS 曲线"
    }

    print(json.dumps(report, ensure_ascii=False, indent=2))
    with open(HERE / "v1_check.json", "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
