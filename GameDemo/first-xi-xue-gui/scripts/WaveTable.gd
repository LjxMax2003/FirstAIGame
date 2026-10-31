extends RefCounted
class_name WaveTable

# =====================================================================
# 时间驱动波次表（Step 9）。
#
# 阶段二之前，刷怪难度是一条 lerp 插值 —— 能跑，但"5 分钟"和"6 分钟"没有区别，
# 玩家感知不到节奏。阶段三把它换成**时间事件表**：
#   0~5min   杂兵熟悉期（无精英）
#   5~10min  密度爬升（精英 6%）
#   10~20min 精英 + 大波（精英 10%）
#   20~25min 精英压制（14%）
#   25~30min 精英 18% + Boss 终局
#
# 数值全部来自 数值平衡设计/params.json 的 waves / boss / enemy 段（v3.1 定稿）。
# 【2026-10-30 文档对账】params.json 已标 ARCHIVED，本文件的常量就是现行真值；
# 调波次/血量/Boss 时间只改这里，改 params.json 不生效。
#
# 【两张表的分工】
#   WAVES  —— 决定"刷多少、刷多快、精英占比"
#   BOSSES —— 决定"什么时候必须停下来打一个大家伙"
# 两者独立，因为 Boss 不该被精英占比波次稀释：它登场时必须把杂兵刷怪压到 35%，
# 否则"单体火力被杂兵抢"的惩罚会失控（params.json boss.mob_spawn_note）。
# =====================================================================

## 单局总时长：存活到这里判胜利
const RUN_LENGTH := 1800.0

## 波次分段。elite_share 是"这一波里精英出现的概率"，
## 注意它不等于"同屏占比"——精英活得比杂兵久，实际同屏占比会更高。
const WAVES: Array[Dictionary] = [
	{"t0": 0.0, "t1": 300.0, "elite_share": 0.0, "note": "0~5min 杂兵熟悉期"},
	{"t0": 300.0, "t1": 600.0, "elite_share": 0.06, "note": "5~10min 密度爬升"},
	{"t0": 600.0, "t1": 1200.0, "elite_share": 0.10, "note": "10~20min 精英 + 大波"},
	{"t0": 1200.0, "t1": 1500.0, "elite_share": 0.14, "note": "20~25min 精英压制"},
	{"t0": 1500.0, "t1": 1800.0, "elite_share": 0.18, "note": "25~30min 精英 18% + Boss 终局"},
]

## 三级 Boss。血量是"按 70% 火力 / 30 秒击杀"反推的，不是拍的。
const BOSSES: Array[Dictionary] = [
	{"t": 900.0, "hp": 2800.0, "note": "15min 首次登场：验证玩家是否已有单体输出能力"},
	{"t": 1500.0, "hp": 6100.0, "note": "25min 第二次：中期战力检验"},
	{"t": 1800.0, "hp": 7000.0, "note": "30min 终局 Boss（v5：11000→7000，干净局内可独立击杀）"},
]

## Boss 战期间刷怪率压到 35%
const MOB_SPAWN_DURING_BOSS := 0.35
## Boss 基础参数
const BOSS_SPEED := 52.0
const BOSS_DAMAGE_MULT := 3.0
const BOSS_XP_MULT := 100
const BOSS_CONTACT_R := 34.0

# =====================================================================
# v5 中期机制：浆壳 / 更鼓 / 潮涌 / 小 Boss
#
# 这三条解决的是"10min 后可挂机"：
#   浆壳  = 中期墙（8–20min，纯 AoE 流被压到 R≈0.53–0.63，墨斗是官方解）
#   更鼓  = 确定性成长（每更 +8%，30min 收在 1.40，替代局外硬托）
#   潮涌  = 周期尖峰（22–45s，只做尖峰不做持续塌缩，逼一次主动操作）
# 数值逐条对齐 docs/balance/v5_model.py，改这里必须同时回填模型重跑。
# =====================================================================

## 浆壳：8min 上壳 → 17min 起线性溃散 → 20min 消失
const SHELL_ON := 480.0
const SHELL_FADE0 := 1020.0
const SHELL_OFF := 1200.0
## 结壳兵血 ×1.40；吃 AoE ×0.75（单点不吃减免，墨斗 ×1.80 是官方解）
const SHELL_HP_MULT := 1.40
const SHELL_AOE_TAKEN := 0.75

## 壳强度 0..1。0 = 不上壳；1 = 满强度。
static func shell_w(t: float) -> float:
	if t < SHELL_ON or t >= SHELL_OFF:
		return 0.0
	if t < SHELL_FADE0:
		return 1.0
	return 1.0 - (t - SHELL_FADE0) / (SHELL_OFF - SHELL_FADE0)

## 这一帧刷出来的杂兵要不要上壳（溃散期按概率上，读得出"壳在掉"）
static func shelled_now(t: float, r: float) -> bool:
	return r < shell_w(t)

## 更鼓：每过一更，全场手艺 +8%（乘在最终伤害上）。
## 30min 时间轴收在 1.40 —— 这是"局内可独立通关"的确定性成长项，
## 不是难度开关（它抬的是玩家，不是敌人）。
const DRUM_STEP := 0.08
const DRUM_TIMES: Array[float] = [300.0, 600.0, 1200.0, 1500.0, 1800.0]

static func drum_mult(t: float) -> float:
	var n: int = 0
	for x in DRUM_TIMES:
		if t >= x:
			n += 1
	return 1.0 + DRUM_STEP * float(n)

## 当前是第几更（0..5），HUD/演出用
static func drum_index(t: float) -> int:
	var n: int = 0
	for x in DRUM_TIMES:
		if t >= x:
			n += 1
	return n

## 周期潮涌：只做尖峰，尖峰之间回稳态（否则会变成"全程塌缩"，那是难度开关不是节奏）
## {t0, dur, lam_mult(刷新倍率), elite_add(精英附加), note}
const SURGES: Array[Dictionary] = [
	{"t0": 600.0, "dur": 22.0, "lam_mult": 1.35, "elite_add": 0.08, "note": "一更潮涌"},
	{"t0": 900.0, "dur": 22.0, "lam_mult": 1.40, "elite_add": 0.10, "note": "二更潮涌"},
	{"t0": 1200.0, "dur": 22.0, "lam_mult": 1.45, "elite_add": 0.12, "note": "三更潮涌"},
	{"t0": 1500.0, "dur": 22.0, "lam_mult": 1.50, "elite_add": 0.14, "note": "四更潮涌"},
	{"t0": 1740.0, "dur": 45.0, "lam_mult": 1.55, "elite_add": 0.16, "note": "终局前长潮"},
]

## 返回当前生效的潮涌（没有则空字典）
static func surge_at(t: float) -> Dictionary:
	for s in SURGES:
		var a: float = float(s["t0"])
		if t >= a and t < a + float(s["dur"]):
			return s
	return {}

## 刷怪率倍率（1.0 = 无潮涌）
static func surge_mult(t: float) -> float:
	var s: Dictionary = surge_at(t)
	return float(s.get("lam_mult", 1.0)) if not s.is_empty() else 1.0

## 精英占比附加（叠加在波次的 elite_share 上，封顶 0.45 由调用方处理）
static func surge_elite_add(t: float) -> float:
	var s: Dictionary = surge_at(t)
	return float(s.get("elite_add", 0.0)) if not s.is_empty() else 0.0

## "这一帧刚好进入潮涌"——给 HUD 预警和地面法阵用（跨越判定，不会重复触发）
static func surge_due(prev_t: float, t: float) -> Dictionary:
	for s in SURGES:
		var a: float = float(s["t0"])
		if prev_t < a and t >= a:
			return s
	return {}

## 小 Boss：12 / 18 / 24min 各一只。血量刻意低于三档真 Boss（2800/6100/7000），
## 定位是"打断节奏的硬点"而不是通关门槛 —— 按当期 DPS 约 3~5s 击杀。
## 走 elite 通道（is_elite=true）：掉宝箱、有血条，但**不压制刷怪率**
## （只有真 Boss 才该把 mob 压到 35%，否则潮涌的尖峰会被一起压平）。
const MINI_BOSSES: Array[Dictionary] = [
	{"t": 720.0, "kind": "drum", "hp": 900.0, "name": "更鼓傀", "svg": Art.BOSS_DRUM},
	{"t": 1080.0, "kind": "nuo", "hp": 1600.0, "name": "无面傩", "svg": Art.BOSS_NUO},
	{"t": 1440.0, "kind": "lantern", "hp": 2400.0, "name": "长夜灯", "svg": Art.BOSS_LANTERN},
]
## 小 Boss 的接触伤害倍率（比精英 2.2 更痛，但不该一击秒人）
const MINI_BOSS_DAMAGE_MULT := 2.6
const MINI_BOSS_XP := 40

static func mini_boss_due(prev_t: float, t: float) -> Dictionary:
	for b in MINI_BOSSES:
		var bt: float = float(b["t"])
		if prev_t < bt and t >= bt:
			return b
	return {}

## 杂兵接触伤害基准（params.json enemy.contact_damage = 6.0）##
## 【为什么是 6 不是 10】
## params.json enemy._fixed_contact 明确推翻了初版的 10：
##   10 伤 / 0.6s 节奏 × 100HP × 0.5s 无敌 → 1 敌 6 秒死、2 敌 3 秒死，满级也最多撑 9 秒。
## 这与"擦边求生、30 分钟一局"直接冲突。改成 6 之后：
##   1 敌 10 秒死、2 敌 5 秒死 —— 正好给"走位换血"留出 2~3 个抉择窗口。
const CONTACT_DAMAGE := 6.0
## 接触伤害节奏（params.json enemy.contact_cadence = 0.6）
## 注意：当前 Player 用 invuln 计时做节拍，这里是文档口径的对齐值，
## 改动节奏时必须两处一起改，否则实际 DPS 会和表算的对不上。
const CONTACT_CADENCE := 0.6

# ---------------------------------------------------------------- 刷怪节奏
## 刷怪间隔：1.1 → 0.45，前 600 秒线性收紧
static func spawn_interval(t: float) -> float:
	var k: float = clampf(t / 600.0, 0.0, 1.0)
	return lerpf(1.1, 0.45, k)

## 单批数量：6 + 0.01t，封顶 30
static func batch_size(t: float) -> int:
	return mini(int(6.0 + 0.01 * t), 30)

## 敌人血量：3 × (1 + t/1800)^1.70
## 基准 1800 不是随手取的：ref=1250 会让 R 曲线变成双峰且全程 <0.6，割草期消失。
static func enemy_hp(t: float) -> float:
	return 3.0 * pow(1.0 + t / 1800.0, 1.70)

## 当前波次索引（0..WAVES.size()-1）
static func wave_index(t: float) -> int:
	for i in WAVES.size():
		var w: Dictionary = WAVES[i]
		if t < float(w["t1"]):
			return i
	return WAVES.size() - 1

static func wave(t: float) -> Dictionary:
	return WAVES[wave_index(t)]

## 当前精英出现概率（来自波次表，不随时间连续插值）
static func elite_share(t: float) -> float:
	return float(wave(t).get("elite_share", 0.0))

static func wave_note(t: float) -> String:
	return String(wave(t).get("note", ""))

# ---------------------------------------------------------------- 敌人阵容
## 三种杂兵的血量/速度倍率。
## 均值 (1.0 + 0.6 + 1.8)/3 = 1.1333，即美术阵容自带 +13.3% 需求侧，
## 这一条已经算进 NUM_DESIGN §9.1 的 R 曲线（峰值 0.74 → 0.71）。
const MOB_DEFS: Dictionary = {
	"cup": {"hp_mult": 1.0, "speed_mult": 1.0, "xp": 1},
	"fast": {"hp_mult": 0.6, "speed_mult": 1.7, "xp": 1},
	"bag": {"hp_mult": 1.8, "speed_mult": 0.8, "xp": 1},
}

## 两种精英：箱精英更耐打，红精英更痛。
## params.json 明确要求"既然美术给了两版精英，就该有两种精英而不是同一精英换色"。
const ELITE_DEFS: Dictionary = {
	"box": {"hp_mult": 18.0, "speed_mult": 0.80, "dmg_mult": 1.6, "xp_mult": 12},
	"red": {"hp_mult": 18.0, "speed_mult": 0.85, "dmg_mult": 2.2, "xp_mult": 12},
}

static func mob_def(kind: String) -> Dictionary:
	return MOB_DEFS.get(kind, MOB_DEFS["cup"])

static func elite_def(kind: String) -> Dictionary:
	return ELITE_DEFS.get(kind, ELITE_DEFS["box"])

## 杂兵种类分布：随时间从"纯杯子"过渡到"三色混编"。
## 前 30 秒只有杯子 —— 玩家要先学会"敌人在哪"，再学"哪种敌人更快"。
static func pick_mob(t: float, r: float) -> String:
	if t < 30.0:
		return "cup"
	if t < 120.0:
		# 只加肉盾，不加快速兵：快速兵在玩家还不熟走位时出现会变成"莫名暴毙"
		return "cup" if r < 0.82 else "bag"
	if r < 0.50:
		return "cup"
	if r < 0.75:
		return "bag"
	return "fast"

## 精英种类：10 分钟后开始出现红精英（高伤害变体）
static func pick_elite(t: float) -> String:
	if t < 600.0:
		return "box"
	return "box" if randf() < 0.55 else "red"

# ---------------------------------------------------------------- Boss
## 返回 t 时刻应该登场的 Boss（没有则空字典）。
## 用"上一帧还没到、这一帧到了"的跨越判定，避免重复触发。
static func boss_due(prev_t: float, t: float) -> Dictionary:
	for b in BOSSES:
		var bt: float = float(b["t"])
		# 终局 Boss 在 RUN_LENGTH 那一帧登场，判定用 >=
		if prev_t < bt and t >= bt:
			return b
	return {}

static func boss_count() -> int:
	return BOSSES.size()

## Boss 血量（按登场档位取，不再套用杂兵血量倍率）
static func boss_hp(index: int) -> float:
	if index < 0 or index >= BOSSES.size():
		return 0.0
	return float(BOSSES[index]["hp"])
