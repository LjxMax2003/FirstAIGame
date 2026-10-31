extends RefCounted
class_name Stats

# =====================================================================
# 统一数值管线（Step 6 的核心）。
#
# 唯一的规则：**被动只改 GameManager.stats，武器只读 stats，谁也不直接改武器。**
# 所有公式集中在这个文件，不散落在 UpgradeDB / WeaponManager 里 —— 改一个数只改一处，
# 也保证自动化测试能逐级核对"第 L 级到底该是多少"。
#
# 数值口径来自 数值平衡设计/NUM_DESIGN.md §1.3（v3.1 定稿）；
# 与 数值平衡设计/params.json 的 stats 段一一对应。
# 【2026-10-30 文档对账】上两句是历史出处。params.json 已标 ARCHIVED、NUM_DESIGN 已标存档，
# **本文件的公式与常量就是现行真值**，调被动只改这里；BalanceAudit 会挡住漂移。
#
# 【Step 12 之后：两张表】
#   value_at()      —— 局内被动档位（Lv 0..5），纯函数，不含任何局外成长；
#   effective_at()  —— 上面的结果 × 局外 Meta 乘数（MetaSave.mult）。
# 所有写入口（apply_to / make_base）走 effective_at，所以"买了 Meta 就变强"
# 自动对所有被动等级、所有武器生效，不需要在武器侧加任何分支。
# 而测试与数值表仍然用 value_at 核对纯公式 —— 两边不会互相污染。
# =====================================================================

const STAT_MAX := 5
const BASE_HP := 100.0

# 冷却地板：再低会让每帧多次判定，既是数值 bug 也是性能 bug（params.json growth_rules 明令禁止）
const COOLDOWN_FLOOR := 0.40
# 力量地板：接触伤害最低压到 50%
const MIGHT_FLOOR := 0.50
# 冷却「连乘后」的绝对地板：局内最低 0.75 × meta 最低 0.85 = 0.6375，理论上还离得很远。
# 留着是因为 meta 步长一旦被调大（比如 -10%/级），这里必须有个硬闸，
# 否则是"每帧多次判定"的性能 bug，而不是数值偏差。
const COOLDOWN_ABS_FLOOR := 0.35

const STAT_KEYS: Array[String] = [
	"damage", "cooldown", "area", "speed", "magnet", "max_hp", "might",
	# ---- v5：两条"生存位"被动。它们是**绝对值**而不是乘数（每秒回多少血 / 护盾多少点），
	# 所以 value_at 直接给量，不走 base_value × 倍率 那套。
	"regen", "shield",
]

## ---- v7（v6 策划案 ③ 落地）：两条生存被动从"续航引擎"改成"涓流 + 累积"
##
## 【为什么改】
## v6 诊断：回春满级 +7.5/s，配 100 血池等于"每 13 秒白送一条命"，
## 玩家的最优解是站着不动等回血 —— 这直接抹掉"走位换血"这个核心抉择。
## 结界 30+15×lv 且每 12s **刷新**（不是叠加）意味着它永远是一层 105 的硬盾，
## 脉冲频率再高也没有意义。两条一起把"生存"变成了不需要操作也能过的选项。
##
## 【改法】
## 回春 = 涓流：+0.6×lv，且硬封顶 3.0/s（满级才 3，约为原来满级的 40%）。
## 结界 = 累积：每 8s 加 5+3×lv 点，**叠加**，但盾池有硬上限 30+6×lv。
##   频率翻倍 → 单脉冲变薄 → 短时间能挡一两下，长期不能无限挡。
##   盾池上限让它"够用但不够躺"。
##
## 数值逐字取自 v6_model.py 的 REGEN_* / SHIELD_* 段，改这里必须重跑 v7_model.py。
const REGEN_PER_LV := 0.60
const REGEN_CAP := 3.0
const SHIELD_BASE := 5.0
const SHIELD_PER_LV := 3.0
const SHIELD_PERIOD := 8.0
## 盾池硬上限：30 + 6×lv（满级 60，约等于原版"一层 105"的 57%）
const SHIELD_CAP_BASE := 30.0
const SHIELD_CAP_PER := 6.0

## 回春的每秒回血上限（给模型/审计读，避免它们各自抄一个 3.0）
static func regen_cap() -> float:
	return REGEN_CAP

## 第 lv 级结界的**盾池上限**。Lv0 = 0（没点过就不该有盾池）。
##
## 为什么要和 value_at("shield") 分开：那一档给的是"每个脉冲加多少"，
## 这一条给的是"能攒到多少"。合成一个数就没法表达"脉冲薄、池子厚"，
## 而那正是 ③ 的核心 —— 短时够挡、长时不能无限挡。
static func shield_cap(lv: int) -> float:
	var l: int = clampi(lv, 0, STAT_MAX)
	if l == 0:
		return 0.0
	return SHIELD_CAP_BASE + SHIELD_CAP_PER * float(l)

## 精炼：满级武器再投入的乘区。**武器级**，不进 value_at / effective_at ——
## 它只影响"这一把武器"，不是全局被动；混进全局会变成"精炼一把，全武器变强"。
const REFINE_MAX := 3
const REFINE_STEP := 0.06

static func refine_mult(tier: int) -> float:
	return 1.0 + REFINE_STEP * float(clampi(tier, 0, REFINE_MAX))

## 初始值（Lv0 时全部为 1.0，血量单独处理）
static func base_value(key: String) -> float:
	match key:
		"max_hp":
			return BASE_HP
		"regen", "shield":
			# Lv0 = 没有这条能力。返回 0 而不是 1.0：护盾/回血是绝对点数，
			# 返回 1.0 会让"没点被动"的玩家开局自带 1 点护盾，HUD 上会多出一条空盾。
			return 0.0
		_:
			return 1.0

## 某一被动升到 L 级后的属性值。L 取 0..STAT_MAX。
## 这是"纯局内"的公式出口：数值表和测试都用它核对，不含任何局外成长。
## 真正写进 stats 的是 effective_at()（= 本函数 × Meta），见下。
static func value_at(key: String, lv: int) -> float:
	var l: int = clampi(lv, 0, STAT_MAX)
	match key:
		"damage":
			return 1.0 + 0.10 * float(l)
		"cooldown":
			# 注意这是"冷却时间倍率"，越小越快；取倒数后才是 DPS 增益
			return maxf(COOLDOWN_FLOOR, 1.0 - 0.05 * float(l))
		"area":
			return 1.0 + 0.07 * float(l)
		"speed":
			return 1.0 + 0.08 * float(l)
		"magnet":
			return 1.0 + 0.25 * float(l)
		"max_hp":
			return BASE_HP + 20.0 * float(l)
		"might":
			return maxf(MIGHT_FLOOR, 1.0 - 0.07 * float(l))
		"regen":
			# 涓流：线性 +0.6/级，到满级 3.0 正好等于封顶值，封顶是防"以后有人把
			# REGEN_PER_LV 调大"时无声地破掉"站着不动也能回满"这条红线。
			return minf(REGEN_CAP, REGEN_PER_LV * float(l))
		"shield":
			# 这是**每个脉冲加多少盾**，不是盾池上限（上限见 shield_cap）。
			# Lv0 必须是 0：没点过结界就不该每 8s 白拿点盾。
			return 0.0 if l == 0 else SHIELD_BASE + SHIELD_PER_LV * float(l)
		_:
			return 1.0

## 局外乘数（Step 12）。只认 MetaSave 里存在的四条线（damage/cooldown/magnet/max_hp），
## 其余 key 一律 1.0 —— 所以没买任何东西时，本函数等同于不调用。
static func meta_mult(key: String) -> float:
	return MetaSave.mult(key)

## 局内 L 级 × 局外 Meta 乘数 = 真正写进 stats 的值。
## 这是阶段四唯一新增的公式出口；value_at 保持纯净给数值表/测试用。
static func effective_at(key: String, lv: int) -> float:
	var v: float = value_at(key, lv) * meta_mult(key)
	if key == "cooldown":
		return maxf(COOLDOWN_ABS_FLOOR, v)
	return v

## 把某个被动写到 stats 字典里。max_hp 变化要连带补血，否则点生命反而"血量比例"下降。
static func apply_to(s: Dictionary, key: String, lv: int) -> void:
	var v: float = effective_at(key, lv)
	if key == "max_hp":
		var old_max: float = float(s.get("max_hp", BASE_HP))
		var delta: float = v - old_max
		s["max_hp"] = v
		# 加血上限时把新加的那部分直接补上（不会超上限），避免玩家点了生命却觉得"没回血"
		s["hp"] = minf(v, float(s.get("hp", BASE_HP)) + maxf(delta, 0.0))
		return
	if key == "shield":
		# 盾池上限必须跟着等级一起写：只写脉冲值的话，HUD 会把"这档能攒到多少"
		# 读成"一次给多少"，护盾条的上限就永远画小了。
		# 它不吃局外乘数（MetaSave 没有 shield 这条线），所以直接给纯公式值。
		s["shield_cap"] = shield_cap(lv)
	s[key] = v

static func make_base() -> Dictionary:
	var d: Dictionary = {
		"hp": BASE_HP,
		"max_hp": BASE_HP,
		"damage": 1.0,
		"cooldown": 1.0,
		"area": 1.0,
		"speed": 1.0,
		"magnet": 1.0,
		"might": 1.0,
	}
	# 开局就要带上局外加成，否则"买了生命却要捡到第一颗宝石才生效"。
	for key in STAT_KEYS:
		d[key] = effective_at(key, 0)
	# 盾池上限单独一条：它不是 STAT_KEYS 的乘数项，而是 shield 这一档的伴生量。
	d["shield_cap"] = shield_cap(0)
	d["hp"] = float(d["max_hp"])
	return d

## 给 UI / 测试用的完整档位表
static func table(key: String) -> Array[float]:
	var out: Array[float] = []
	for l in range(STAT_MAX + 1):
		out.append(value_at(key, l))
	return out
