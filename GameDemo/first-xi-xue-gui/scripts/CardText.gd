extends RefCounted
class_name CardText

# =====================================================================
# 卡面文案的唯一生成入口。
#
# 【为什么要生成，而不是在 WeaponDB 里手写 desc】
# 手写的 desc 只能描述"这把武器是什么"，说不出"这一级到底变了什么"——
# 而玩家做选择时真正要判断的正是后者。更危险的是手写文案会和数值各说一套：
# 改一次 dmg_per_level，文案就悄悄失真，而且没有任何测试会发现。
# 所以：文案一律从 WeaponDB / Stats 的**同一条公式**反推，数值一动文案自动跟着动。
#
# 【为什么连续量用百分比，而不是 "10 → 11"】
# 百分比对乘数免疫：伤害/范围的被动与局外成长在本级前后同比例缩放，比值不变。
# 所以"伤害 +10%"在任何被动状态下都是真话；写"10 → 11"只在裸装时成立。
# 离散量（发数）没法用百分比，直接写 "1 → 2"。
#
# 【与 LevelUpUI 的分工】
# 本类只管"文案说什么"，不管字号/排版。卡面 56px 高、12px 字 ≈ 4 行，
# 所以 MAX_LINES 是硬约束，超出必须裁掉——宁可少说一条，不能让字被切一半。
# =====================================================================

## 卡面描述区能放下的行数。
## 实测（tools/CardShot 的字体度量）：12px 字每行 17px，4 行需要 68px，
## 而描述区从 y=212 到卡底 280 只剩 68px —— 恰好贴边，且卡框右下角的印章会压住第 4 行。
## 所以硬上限是 **3 行**（51px，留 5px 余量）。原来按 4 行写，打铁花首得卡的
## "每次 2 发" 直接掉到卡外面去了（shots/shot_cards_weapon_bad.png）。
const MAX_LINES := 3

## 武器身上"会随等级变化"的轴，按展示优先级排列。
## 只列真正会变的字段：例如打铁花的发数恒为 2（count 字段每级都是常数），
## 所以它不在这里——写"发数 2 → 2"是噪音。
const AXES: Dictionary = {
	"whip": ["damage", "length"],
	"halo": ["damage", "radius"],
	"glowstick": ["damage", "cooldown", "count", "pierce"],
	"phone": ["damage", "orbit_radius"],
	"blade": ["damage", "cooldown"],
	"extinguisher": ["damage"],
	"gong": ["damage", "radius"],
	"inkline": ["damage", "cooldown", "pierce"],
	"print": ["damage", "radius"],
}

const AXIS_LABELS: Dictionary = {
	"damage": "伤害",
	"cooldown": "冷却",
	"count": "发数",
	"pierce": "穿透",
	"length": "横扫",
	"radius": "范围",
	"orbit_radius": "绕身",
}

## 被动：中文名 + 变化方向。方向单独存，避免"冷却 +5%"这种读起来像削弱的写法。
const STAT_LABELS: Dictionary = {
	"damage": {"name": "全部伤害", "sign": "+"},
	"cooldown": {"name": "全部冷却", "sign": "-"},
	"area": {"name": "全部范围", "sign": "+"},
	"speed": {"name": "移速", "sign": "+"},
	"magnet": {"name": "拾取范围", "sign": "+"},
	"max_hp": {"name": "生命上限", "sign": "+"},
	"might": {"name": "受击伤害", "sign": "-"},
	"regen": {"name": "每秒回血", "sign": "+"},
	"shield": {"name": "护盾吸收", "sign": "+"},
}

## 绝对量（不是百分比）的被动：血量 / 每秒回血 / 护盾点数
const ABS_KEYS: Array[String] = ["max_hp", "regen", "shield"]

# ---------------------------------------------------------------- 对外
## 武器卡：from_lv = 0 表示"第一次拿到"，其余表示升级
static func weapon_desc(id: String, from_lv: int, to_lv: int) -> String:
	var lines: Array[String] = []
	if from_lv <= 0:
		# 新武器要回答"它能干什么"，此时"提升多少"还不存在
		var flavor: String = String(WeaponDB.def(id).get("desc", ""))
		if flavor != "":
			lines.append(flavor)
		lines.append_array(weapon_base_lines(id))
	else:
		lines.append_array(weapon_delta_lines(id, from_lv, to_lv))
	if lines.is_empty():
		lines.append("威力小幅提升")
	return _clip(lines)

## 精炼卡：满级武器的二次投入。说清"这一层给谁加多少"，不占新卡位。
static func refine_desc(id: String, tier: int) -> String:
	var per: int = roundi(Stats.REFINE_STEP * 100.0)
	var total: int = roundi((Stats.refine_mult(tier) - 1.0) * 100.0)
	return _clip(["%s 伤害 +%d%%" % [WeaponDB.display_name(id), per], "本命累计 +%d%%" % total])

## 被动卡：描述"本级加多少 + 点完累计多少"。
## 等级由调用方传入，**不在这里反查 UpgradeDB** —— 否则 CardText ↔ UpgradeDB 会形成
## 静态类循环引用（UpgradeDB 也要调 CardText 生成 desc），GDScript 解析时会报找不到类。
static func stat_desc(id: String, to_lv: int) -> String:
	if to_lv > Stats.STAT_MAX:
		return "已至化境"
	return _clip(stat_lines(id, to_lv))

## 升到 to_lv 这一级，比上一级多了什么。空数组 = 这一级没有任何数值变化。
static func weapon_delta_lines(id: String, from_lv: int, to_lv: int) -> Array[String]:
	var out: Array[String] = []
	for axis in (AXES.get(id, []) as Array):
		var a: String = String(axis)
		var before: float = _axis_value(id, a, from_lv)
		var after: float = _axis_value(id, a, to_lv)
		if is_equal_approx(before, after):
			continue
		var label: String = String(AXIS_LABELS.get(a, a))
		if a == "count" or a == "pierce":
			# 发数 / 穿透是整数，百分比没有意义
			out.append("%s %d → %d" % [label, roundi(before), roundi(after)])
			continue
		var pct: int = roundi((after / maxf(before, 0.001) - 1.0) * 100.0)
		if pct == 0:
			continue
		out.append("%s %+d%%" % [label, pct])
	return out

## 新武器的"身板"：一级的绝对数值，让玩家知道拿到的是什么量级。
## 只出**一行** —— 首得卡还有两行风味文案，正好占满 3 行上限。
## 一行只有 128px（描述区被右下印章挤窄），"伤害 + 冷却 + 发数"三个都写会折行，
## 所以多发型武器优先写**发数**（结构性信息，看不出来就选错了），单发型写冷却。
static func weapon_base_lines(id: String) -> Array[String]:
	var d: Dictionary = WeaponDB.def(id)
	var dmg: int = roundi(WeaponDB.damage_at(id, 1, 1.0))
	var cnt: int = int(d.get("count", 0))
	if cnt > 1:
		return ["伤害 %d · 每次 %d 发" % [dmg, cnt]]
	return ["伤害 %d · 冷却 %.2fs" % [dmg, WeaponDB.cooldown_at(id, 1, 1.0)]]

## 被动升到 to_lv 这一级：本级增量 + 累计值
static func stat_lines(id: String, to_lv: int) -> Array[String]:
	var lab: Dictionary = STAT_LABELS.get(id, {"name": id, "sign": "+"})
	var name_cn: String = String(lab["name"])
	var sign_cn: String = String(lab["sign"])
	var per: float = _stat_amount(id, to_lv) - _stat_amount(id, to_lv - 1)
	var total: float = _stat_amount(id, to_lv)
	if id in ABS_KEYS:
		# 血量 / 回血 / 护盾是绝对点数，没有"百分比"这回事
		var total_line: String = "当前上限 %d" % roundi(total)
		if id == "regen":
			total_line = "累计 %.1f/s" % total
		elif id == "shield":
			# v7 起"每 8s 给多少"和"能攒到多少"是两个数，必须一起说。
			# 只说脉冲值，玩家会以为护盾条的上限就是脉冲值（画小了 3 倍）；
			# 只说上限，又看不出"点一级变快了多少"。一行里都得有。
			total_line = "每 %ds +%d · 上限 %d" % [
				roundi(Stats.SHIELD_PERIOD), roundi(total), roundi(Stats.shield_cap(to_lv))
			]
		var per_line: String
		if id == "regen":
			per_line = "%s %s%.1f/s" % [name_cn, sign_cn, absf(per)]
		else:
			per_line = "%s %s%d" % [name_cn, sign_cn, roundi(absf(per))]
		return [per_line, total_line]
	return [
		"%s %s%d%%" % [name_cn, sign_cn, roundi(absf(per))],
		"累计 %s%d%%" % [sign_cn, roundi(absf(total))],
	]

# ---------------------------------------------------------------- 内部
## 把某一级、某条轴的数值反推出来。全部复用 WeaponDB / 字段公式，不另写一套。
static func _axis_value(id: String, axis: String, lv: int) -> float:
	var d: Dictionary = WeaponDB.def(id)
	var l: int = maxi(lv, 1)
	match axis:
		"damage":
			# 传 1.0 表示"不含被动"：百分比本来就对乘数免疫，取裸值最稳定
			return WeaponDB.damage_at(id, l, 1.0)
		"cooldown":
			return WeaponDB.cooldown_at(id, l, 1.0)
		"count":
			# 只有糖画走这条（按两级 +1，封顶 4）。打铁花的 count 是常数，不在 AXES 里。
			return float(WeaponDB.count_at(id, l))
		"pierce":
			return float(WeaponDB.pierce_at(id, l))
		"length":
			return float(d.get("length", 0.0)) + float(d.get("length_per_level", 0.0)) * float(l - 1)
		"radius":
			return float(d.get("radius", 0.0)) + float(d.get("radius_per_level", 0.0)) * float(l - 1)
		"orbit_radius":
			return float(d.get("orbit_radius", 0.0)) + float(d.get("orbit_radius_per_level", 0.0)) * float(l - 1)
	return 0.0

## 被动的"人类方向"数值：增幅类返回增长百分比，减伤类返回减少百分比，血量返回绝对值。
## 统一成一个方向，外面才能用同一个 %s%d 模板拼字，不会出现"冷却 +5%"这种反读。
static func _stat_amount(id: String, lv: int) -> float:
	var v: float = Stats.value_at(id, lv)
	match id:
		"cooldown", "might":
			return (1.0 - v) * 100.0
		"max_hp", "regen", "shield":
			return v
		_:
			return (v - 1.0) * 100.0

static func _clip(lines: Array[String]) -> String:
	var kept: Array[String] = []
	for i in mini(lines.size(), MAX_LINES):
		kept.append(lines[i])
	return "\n".join(kept)
