extends RefCounted
class_name EvolutionDB

# =====================================================================
# 进化配方表（Step 8）。
#
# 配方 = 指定武器 Lv8 + 指定被动 Lv>=1 在场 → 打死精英掉宝箱 → 开箱 → 进化。
# 这就是"可预期的惊喜"：玩家能规划，但拿到时仍有爆发感。
#
# 数值来自 数值平衡设计/params.json 的 evolution.forms 段（v3.1 定稿）。
# 【2026-10-30 文档对账】params.json 已标 ARCHIVED，本文件的 FORMS 就是现行真值；
# 改配方/倍率只改这里，不要去改 params.json（改那边不生效，只会制造第二份旧描述）。
#
# 【为什么倍率必须是 1.7 / 1.5 / 1.4 而不是更高】
# 硬约束是 X11 < X1：三把进化武器的 DPS/R 必须都低于六把未进化武器之和。
# 否则"少拿武器去进化"变成最优解，6 槽位设计就没意义了。
# 验算见 tools/SmokeTest.gd 的 test_evolution_dps_constraint。
#
# 【为什么进化必须在原武器上打标记，而不是新增一个武器 id】
# 进化若占新槽位，玩家为了进化要空出一格，等于"进化 = 少一把武器"，
# 和上一条约束直接对撞。标记法让槽位数不变，也符合"把手上的武器变强"。
# =====================================================================

## 进化形态 ID → 定义
const FORMS: Dictionary = {
	# 鞭弧 + 伤害 → 血鞭：范围一起涨，横扫更痛
	"evolve_whip": {
		"name": "火神开脸",
		"base": "whip",
		"req_passive": "damage",
		"dps_mult": 1.7,
		"area_mult": 1.5,
		"desc": "傩面满级 + 匠心",
		"svg": Art.WHIP_ARC,
	},
	# 荧光棒 + 冷却 → 圣魔杖：发数拉满，靠射速吃收益
	"evolve_glowstick": {
		"name": "龙凤呈祥",
		"base": "glowstick",
		"req_passive": "cooldown",
		"dps_mult": 1.5,
		"area_mult": 1.0,
		"desc": "糖画满级 + 巧手",
		"svg": Art.WAND_GLOWSTICK,
	},
	# 光环 + 范围 → 圣蒜：半径暴涨，减速不变强（避免变成永久定身）
	"evolve_halo": {
		"name": "走马灯",
		"base": "halo",
		"req_passive": "area",
		"dps_mult": 1.4,
		"area_mult": 1.6,
		"desc": "花灯满级 + 火候",
		"svg": Art.HALO_RING,
	},
	# ---------------------------------------------------------------- v5 新增三进化
	# 铜锣 + 火候 → 开市锣：半径与伤害一起涨，把"第二光环位"做成真正的大范围
	"evolve_gong": {
		"name": "开市锣",
		"base": "gong",
		"req_passive": "area",
		"dps_mult": 1.50,
		"area_mult": 1.50,
		"desc": "铜锣满级 + 火候",
		"svg": Art.GONG,
	},
	# 墨斗 + 匠心 → 龙筋墨线：单点头牌再抬一档，破壳仍靠它
	"evolve_inkline": {
		"name": "龙筋墨线",
		"base": "inkline",
		"req_passive": "damage",
		"dps_mult": 1.55,
		"area_mult": 1.10,
		"desc": "墨斗满级 + 匠心",
		"svg": Art.INKLINE,
	},
	# 打铁花 + 火候 → 百子千花：倍率之外还改**行为**（每 2 命中引爆一次），
	# 这是唯一一个"进化后机制变了"的形态，WeaponManager 的引爆分支要读它。
	"evolve_extinguisher": {
		"name": "百子千花",
		"base": "extinguisher",
		"req_passive": "area",
		"dps_mult": 1.50,
		"area_mult": 1.40,
		"desc": "打铁花满级 + 火候",
		"svg": Art.AXE_EXTINGUISHER,
		# v6 §4.3：进化不再靠"每 N 命中引爆一次"（那是引爆型时代的行为字段 `explode_every`）。
		# 铁水碎裂之后本来就会再迸一圈，进化只是让它**每次都多迸一圈内圈火星**
		# （WeaponManager._shatter 里 `if evolved.has("extinguisher")` 那段）。
		# 所以这里没有行为字段：机制差异在武器侧，进化侧只给倍率，反而更难漂移。
	},
}

## 武器满级才可进化
const REQUIRE_WEAPON_LEVEL := 8
## 配套被动至少 1 级
const REQUIRE_PASSIVE_LEVEL := 1

static func has_form(id: String) -> bool:
	return FORMS.has(id)

static func form(id: String) -> Dictionary:
	return FORMS.get(id, {})

## 该武器对应的进化形态 ID（没有则空串）
static func form_id_for(weapon_id: String) -> String:
	for key in FORMS.keys():
		var f: Dictionary = FORMS[key]
		if String(f.get("base", "")) == weapon_id:
			return String(key)
	return ""

## 该武器是否有进化路线
static func can_evolve(weapon_id: String) -> bool:
	return form_id_for(weapon_id) != ""

## 该武器依赖哪个被动
static func req_passive(weapon_id: String) -> String:
	var f: Dictionary = form(form_id_for(weapon_id))
	return String(f.get("req_passive", ""))

## 检查是否满足全部条件。
## weapon_lv / passive_lv 由调用方传入，避免本类反向依赖 WeaponManager。
static func meets_recipe(weapon_id: String, weapon_lv: int, passive_lv: int) -> bool:
	if not can_evolve(weapon_id):
		return false
	return weapon_lv >= REQUIRE_WEAPON_LEVEL and passive_lv >= REQUIRE_PASSIVE_LEVEL

## 已满级但还没进化的武器列表（宝箱开出来的候选）
static func candidates(owned: Dictionary, stats_levels: Dictionary, evolved: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in owned.keys():
		var wid: String = String(id)
		if evolved.has(wid):
			continue
		var lv: int = int(owned[wid])
		if not meets_recipe(wid, lv, int(stats_levels.get(req_passive(wid), 0))):
			continue
		out.append(wid)
	return out
