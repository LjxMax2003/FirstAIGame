extends RefCounted
class_name WeaponDB

# =====================================================================
# 数据驱动武器定义。
#
# 新增一把武器 = 在 DEFS 里加一条 + 在 WeaponManager 里加一个 fire_xxx。
# 数值全部集中在这张表里，不再散落成 WeaponManager 顶部的 const 常量。
#
# 【两套来源，各自负责什么】
#   · 既有 6 把（whip/halo/glowstick/phone/blade/extinguisher）：
#     沿用 v3.1 手感值，v5 只**加机制字段**（引爆/加伤/里程碑/击退/衰减/双扫）。
#     这些手感值不是"拍的"——它们决定了打击节奏，重调属于单独一轮平衡，
#     不在本次重写的动作清单里（见 docs/design/v5_ai_playbook.md §6 Phase 1）。
#   · v5 新增 3 把（gong/inkline/print）：
#     参数**逐字取自** docs/balance/v5_model.py 的 WEAPONS 段，不手拍。
#     模型里的 `aim` 是"命中折损"（锁定/弹射/直线在数值模型里按命中率折价）。
#     游戏里这些弹道一旦锁定就必中，若把 aim 藏在结算里，卡面会写 16 实际打 14.4，
#     正好违反上一轮"文案必须等于实际效果"的要求。所以 aim 直接乘进 damage_at()：
#     卡面显示的每击伤害 = 真正落下去的伤害。
# =====================================================================

const MAX_LEVEL := 8

## 每把武器的完整定义。字段含义见下方注释。
const DEFS: Dictionary = {
	# ---------------------------------------------------------- 傩面·师刀（whip）
	"whip": {
		"name": "傩面·师刀",
		"kind": "melee",
		"dmg_kind": "aoe",
		"svg": Art.WHIP_ARC,
		"desc": "傩面怒目，师刀横扫\n身前一片",
		"cooldown": 1.30,
		"damage": 10.0,
		"dmg_per_level": 1.0,
		"length": 110.0,
		"length_per_level": 12.0,
		"width": 64.0,
		# 长度上限：防止鞭子长过半个屏幕后结构性清屏（params.json length_cap）
		"length_cap": 260.0,
		# v5：Lv7/Lv8 扫两次（各 60% 伤）—— 用"次数"替代已经撞帽的"长度"继续成长
		"double_sweep": true,
		"double_sweep_from": 7,
		"double_sweep_ratio": 0.60,
	},
	# ---------------------------------------------------------- 花灯（halo）
	# v7（v6 策划案 ① 落地）：4.00 / 0.80 → 2.50 / 0.45。
	#
	# 为什么必须往下调，而不是"再给它加个机制"：花灯是**零操作**的最强项 ——
	# 站在圈里不动就自动灼烧 + 减速 + 对减速目标 +20%，玩家的最优解是"围着怪绕圈"。
	# 上一轮实测代码比 v5 文档还高（4.0 vs 3.6），也就是这个问题被持续放大。
	# 现在把它定位成**控制位**：DPS 让给操作型（剪纸/墨斗/糖画），
	# 自己保留"减速 + 对减速目标加成"这条独有语义。
	# 收敛带验收靠 docs/balance/v7_model.py 的 band，不靠手感。
	"halo": {
		"name": "花灯",
		"kind": "aura",
		"dmg_kind": "aoe",
		"svg": Art.HALO_RING,
		"desc": "灯晕灼烧贴身忘影\n光让影子变慢",
		"cooldown": 0.50,
		"damage": 2.50,
		"dmg_per_level": 0.45,
		"radius": 70.0,
		"radius_per_level": 7.0,
		# 原案"推开敌人"会让接触伤害恒为 0（无声无敌挂），改为减速
		"slow_pct": 0.22,
		"slow_duration": 0.60,
		# v5：对**已被减速**的敌人 +20% 伤 —— 奖励"把怪留在圈里"，而不是远程抢击杀
		"slow_dmg": 0.20,
	},
	# ---------------------------------------------------------- 糖画（glowstick）
	"glowstick": {
		"name": "糖画",
		"kind": "projectile",
		"dmg_kind": "single",
		"svg": Art.WAND_GLOWSTICK,
		"bullet_svg": Art.BULLET_GLOWSTICK,
		"desc": "糖丝自动锁定\n拉丝穿透",
		"cooldown": 1.00,
		"cd_per_level": 0.05,
		"damage": 12.0,
		# 关键：没有这条，Lv8 荧光棒仍不如鞭弧 Lv1（NUM_DESIGN §4.2）。
		# v7 band 对齐：3.0 → 1.95。3.0 让 Lv8 总 DPS 冲到 203（带子上沿 1.55 倍），
		# 单体 DPS 更是全场第一 —— 锁定 + 穿透 + 高成长三件事叠在一起就过强了。
		# 保留 Lv1 的 12（新玩家第一把不能弱），只压成长斜率。
		"dmg_per_level": 1.95,
		"count_base": 1,
		"count_per_two_level": 1,
		"count_cap": 4,
		"pierce": 1,
		# v5：穿透里程碑 —— Lv4 / Lv8 各 +1，而不是每级线性给
		"pierce_milestone": true,
		"bullet_speed": 430.0,
		"bullet_radius": 16.0,
		"range": 520.0,
	},
	# ---------------------------------------------------------- 皮影（phone）
	# v7（v6 策划案 ① 落地）：每级伤害 0.80 → 0.90（基础 8.0 不动）。
	#
	# 皮影和花灯是一对：都是"零操作也能造成伤害"的自动档。v6 把它们定位成
	# **下限保障**（新手第一夜的可用构筑），所以只下调成长斜率、不动基础值 ——
	# 保 Lv1 的手感（新玩家第一把武器不能弱），削 Lv8 的上限（老玩家不能靠它躺完 30 分钟）。
	"phone": {
		"name": "皮影",
		"kind": "orbit",
		"dmg_kind": "aoe",
		"svg": Art.PHONE_ORBIT,
		"desc": "皮影武将绕身巡游\n撞上就疼",
		"cooldown": 0.28,
		"damage": 8.0,
		"dmg_per_level": 0.90,
		"orbit_radius": 58.0,
		"orbit_radius_per_level": 5.0,
		"orbit_count": 2,
		"orbit_speed": 2.4,
		"hit_radius": 18.0,
		# v5：命中给一次短促击退（顿一下，读得出"撞"）
		"knock": 0.15,
	},
	# ---------------------------------------------------------- 剪纸（blade）
	"blade": {
		"name": "剪纸",
		"kind": "projectile",
		"dmg_kind": "single",
		"svg": Art.KNIFE_BOXCUTTER,
		"bullet_svg": Art.KNIFE_BOXCUTTER,
		"desc": "纸鹊寻敌\n一命中就弹向下一只",
		"cooldown": 0.90,
		"cd_per_level": 0.04,
		"damage": 9.0,
		# v7 band 对齐：1.5 → 2.15。原来 Lv8 总 DPS 93 掉在收敛带下沿 15%，
		# 而它并不是辅助档（辅助档只有花灯/皮影），属于"被低估的操作型"。
		"dmg_per_level": 2.15,
		"bounce": 3,
		"pierce": 0,
		"bullet_speed": 380.0,
		"bullet_radius": 14.0,
		"range": 480.0,
		"bounce_range": 260.0,
		# v5：第 2 跳之后每次 -30%（防两怪互弹到死）
		"bounce_falloff": true,
		"bounce_falloff_after": 2,
		"bounce_falloff_ratio": 0.70,
		# 弹射距离随火候缩放（原来固定 260，范围被动对它完全无效）
		"bounce_range_scaled": true,
	},
	# ---------------------------------------------------------- 打铁花（extinguisher）
	"extinguisher": {
		"name": "打铁花",
		"kind": "arc_projectile",
		"dmg_kind": "aoe",
		"svg": Art.AXE_EXTINGUISHER,
		"bullet_svg": Art.AXE_EXTINGUISHER,
		# 机制换了，卡面就得跟着说"撞地散开"。
		# 旧句"穿透所有目标"在散布半径 150 面前是**误导**：真正的群清来自碎开的一片，
		# 不是穿透那几发。玩家按卡面预判范围，写错就是让他站错位置。
		"desc": "铁水泼洒\n撞地散成火星",
		"cooldown": 1.60,
		"damage": 16.0,
		# v7 band 对齐：2.0 → 0.9。打铁花是带子上沿里最离谱的一个（246，是辅助档的 2.4 倍）：
		# 扇形 2 发 × 每发最多穿 4 只 × 落点再炸一片，三重乘区叠起来。
		# Lv1 保持 16 不动（默认起始武器之一，开局手感不能削），只削成长。
		"dmg_per_level": 0.9,
		"arc_height": 180.0,
		"count": 2,
		# v7 T8：1 = 撞到第一只就碎、弹体消失。
		# v5 的 4（穿透）是"引爆型"留下的：那时落点只炸一个 76 小圈，直射是主要伤害来源。
		# 散开半径提到 150 之后，穿透再留着就会让"直射 8 次 + 碎一片"叠成 282.5（v7_model 实测），
		# 而且和 v6 §4.1 的原话"撞到第一只实体即碎裂"直接矛盾 —— 碎了的铁水团不该继续飞。
		"hit_cap": 1,
		"bullet_speed": 300.0,
		"bullet_radius": 18.0,
		"range": 320.0,
		# v6 §4 / v7 T8：铁水散开（替换原"引爆型"）。
		# 撞到第一只实体 → 碎开半径 150 的一大片，圈内每只只吃 0.40× 主伤。
		# 这是"大范围小伤害"：群怪越多越值、单点/Boss 几乎无效 —— 主题与定位都由这一条决定。
		"scatter_radius": 150.0,
		# v6 写的是 0.40。**这里刻意偏离**，因为 v6 的模型把散开项算小了：
		# 真正跑下来 0.40 会让散开独占 60% 总 DPS（直射反而成了次要），
		# 而且 Lv8 冲到 282.5，收敛带（102~158）直接崩。
		# 0.28 是"每只吃一小口、整圈都掉血"的读数：散开 ≈ 直射的 4 倍。
		"scatter_ratio": 0.28,
		# 散开能覆盖几只，**随等级长**：Lv1 四只 → Lv8 十八只（几何上限约 15，实际封在 15）。
		# 用"覆盖数成长"而不是"把 dmg_per_level 拉到 4.5"，是因为后者会让卡面写成
		# 「+4.5/级」这种一眼假的大数，而前者对应玩家的真实感受：圈子没变大，但溅到的人变多了。
		"scatter_cap": 4,
		"scatter_cap_per_level": 2,
	},
	# ---------------------------------------------------------- 铜锣（gong，v5 新增）
	"gong": {
		"name": "铜锣",
		"kind": "aura",
		"dmg_kind": "aoe",
		"svg": Art.GONG,
		"desc": "铜锣一响，声波荡开\n近了就震得慌",
		"cooldown": 1.80,
		"damage": 14.0,
		"dmg_per_level": 2.00,
		"radius": 150.0,
		"radius_per_level": 10.0,
		"hit_cap": 8,
		# 对结壳敌人 +12% 伤（轻微破壳）—— 第二光环位，补花灯之外的覆盖
		"amp": 0.12,
	},
	# ---------------------------------------------------------- 墨斗（inkline，v5 新增）
	"inkline": {
		"name": "墨斗",
		"kind": "line",
		"dmg_kind": "single",
		"svg": Art.INKLINE,
		"bullet_svg": Art.INKLINE,
		"desc": "墨线绷直\n一线穿透",
		"cooldown": 0.90,
		"cd_per_level": 0.04,
		"damage": 16.0,
		"dmg_per_level": 8.00,
		"pierce": 1,
		# 模型口径的命中折损，已并入 damage_at（见文件头）
		"aim": 0.90,
		# 浆壳兵的官方解：对结壳敌人 ×1.80
		"shell_bonus": 1.80,
		"bullet_speed": 700.0,
		"bullet_radius": 14.0,
		"range": 640.0,
	},
	# ---------------------------------------------------------- 木版年画（print，v5 新增）
	"print": {
		"name": "木版年画",
		"kind": "zone",
		"dmg_kind": "aoe",
		"svg": Art.WOODBLOCK_PRINT,
		"desc": "雕版从天而落\n压出一片",
		"cooldown": 2.20,
		"damage": 30.0,
		"dmg_per_level": 3.50,
		"radius": 105.0,
		"hit_cap": 6,
		# 延迟落点：按下后在目标处悬 0.45s 再砸（给敌人"逃"的机会，读得出重量）
		"delay": 0.45,
		"role": "zone",
	},
}

const ORDER: Array[String] = [
	"whip", "halo", "glowstick", "phone", "blade", "extinguisher",
	"gong", "inkline", "print",
]

static func has_weapon(id: String) -> bool:
	return DEFS.has(id)

static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})

static func display_name(id: String) -> String:
	return String((DEFS.get(id, {}) as Dictionary).get("name", id))

static func svg(id: String) -> String:
	return String((DEFS.get(id, {}) as Dictionary).get("svg", ""))

## 这件武器是范围伤还是单点伤。浆壳兵的受击倍率按这个分（AoE ×0.75 / 单点 ×1.0）。
static func dmg_kind(id: String) -> String:
	return String((DEFS.get(id, {}) as Dictionary).get("dmg_kind", "aoe"))

## 这件武器的结构类型（melee / aura / projectile / orbit / arc_projectile / line / zone）。
## WeaponManager 按它决定冷却通道：环绕类（orbit）不走开火冷却 _cd（迭代01 D-1-F1）。
## 单独一个取值器，而不是各调用点就地 def(id).get("kind") —— 字符串键散写是事故源。
static func kind_of(id: String) -> String:
	return String((DEFS.get(id, {}) as Dictionary).get("kind", ""))

## 模型口径的命中折损（只对锁定/弹射/直线三种有；其余 1.0）
static func aim_at(id: String) -> float:
	return float((DEFS.get(id, {}) as Dictionary).get("aim", 1.0))

## 该武器在第 lv 级的冷却秒数（含被动冷却乘数 cooldown_mult）
## cd_per_level 是**每级百分比**（-4% 这种），不是"每级减 0.04 秒"。
## v5 起改为乘法：v5_model.py 的 `cd = cd * (1 - cd_per*(lv-1))` 就是这个口径，
## 线性减在长冷却武器上会算出完全不同的数（墨斗 0.90 vs 木版年画 2.20 不能用同一步长）。
static func cooldown_at(id: String, lv: int, cooldown_mult: float) -> float:
	var d: Dictionary = def(id)
	var base_cd: float = float(d.get("cooldown", 1.0))
	var per: float = float(d.get("cd_per_level", 0.0))
	var raw: float = base_cd * (1.0 - per * float(maxi(lv, 1) - 1))
	# 与模型一致的地板 0.15；再乘被动后仍不低于 0.12（避免每帧多次判定）
	return maxf(maxf(raw, 0.15) * cooldown_mult, 0.12)

## 该武器在第 lv 级的**实际每击伤害**（已含 aim 折损；不含被动与进化乘数）。
static func damage_at(id: String, lv: int, damage_mult: float) -> float:
	var d: Dictionary = def(id)
	var base: float = float(d.get("damage", 1.0))
	var per: float = float(d.get("dmg_per_level", 0.0))
	return (base + per * float(maxi(lv, 1) - 1)) * damage_mult * aim_at(id)

## 发数曲线：min(base + per * floor((L-1)/2), cap)
static func count_at(id: String, lv: int) -> int:
	var d: Dictionary = def(id)
	var base: int = int(d.get("count_base", 1))
	var per: int = int(d.get("count_per_two_level", 0))
	var cap: int = int(d.get("count_cap", 1))
	return mini(base + per * ((maxi(lv, 1) - 1) / 2), cap)

## 穿透次数：Lv4 / Lv8 各 +1 的里程碑（不是线性给）。
## 单独一个函数而不是塞进 count_at —— count 是"一次泼几发"，pierce 是"一条穿几个"，
## 两个轴一起改会让卡面文案永远说不清"这一级到底变了什么"。
static func pierce_at(id: String, lv: int) -> int:
	var d: Dictionary = def(id)
	var p: int = int(d.get("pierce", 1))
	if not bool(d.get("pierce_milestone", false)):
		return p
	var l: int = maxi(lv, 1)
	if l >= 4:
		p += 1
	if l >= 8:
		p += 1
	return p

## 铁水散开能覆盖几只：Lv1 四只，每级 +2，几何密度自己会封顶（约 15 只）。
## 单独一个函数而不是在 WeaponManager 里就地算 —— 模型 / 审计都要同一个口径，
## 三处各写一遍就是下一个漂移源。
static func scatter_cap_at(id: String, lv: int) -> int:
	var d: Dictionary = def(id)
	if d.is_empty():
		return 0
	var base: int = int(d.get("scatter_cap", 0))
	if base <= 0:
		return 0
	return maxi(1, base + int(d.get("scatter_cap_per_level", 0)) * (maxi(lv, 1) - 1))

## 新武器首次获得的延迟：错开首轮齐射，避免多把武器同一帧爆发
static func first_delay(id: String) -> float:
	match id:
		"whip":
			return 0.10
		"halo":
			return 0.15
		"glowstick":
			return 0.30
		"phone":
			return 0.22
		"blade":
			return 0.34
		"gong":
			return 0.26
		"inkline":
			return 0.12
		"print":
			return 0.40
		_:
			return 0.20
