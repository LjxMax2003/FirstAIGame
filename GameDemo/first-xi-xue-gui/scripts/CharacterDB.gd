extends RefCounted
class_name CharacterDB

# =====================================================================
# 五匠人（v7.1 / T9 · 策划案 §4.3「优先级 1：角色选择」）
#
# 【红线：只有起始武器不同，没有属性差异】
#   五个角色共用同一份 Stats 基线、同一套局内成长、同一个初始血量与移速。
#   这条不是"暂时不做"，而是设计约束：一旦角色自带属性，卡池的每一张卡都要按
#   "你选了谁"重算一遍平衡，v7 的收敛带（1.55×）当天就失效。
#   所以这里的数据结构里**故意没有** hp / speed / damage 这类字段 ——
#   想加的人必须先把这条注释删掉，那是个显式决定，不是顺手加个字段。
#
# 【辅助档为什么起始 Lv2】
#   用 docs/balance/v7_model.py 实测（裸装、同屏 60）的开局总 DPS：
#       phone 57.1 / extinguisher 32.9 / blade 31.0 / inkline 21.6 / print 13.6
#       glowstick 12.0 / gong 7.8 / whip 7.7 / halo 5.0（最低）
#   五把起始武器分别落在 5.0 ~ 57.1，跨度 11×。辅助档（花灯 5.0 / 皮影 57.1）
#   的两端都不是"稍微弱一点"，而是一个开局接近无伤、一个开局就能推。
#   起始 Lv2 的实测增益（Lv2/Lv1）：halo ×1.18、phone ×1.11 —— 它**缓解不了**这个跨度，
#   只是把辅助档的成长起点抬一格（少一次抽卡机会的补偿）。
#   真正的收敛要等 M2 的面具架/局内卡池调权，不在 T9 的范围里。
#   ⚠️ 这一条是"已知的开局强度不均"，不要用"反正都给了 Lv2"来假装它不存在。
# =====================================================================

const DEFAULT_ID := "forge"

const ENTRIES: Array[Dictionary] = [
	{
		"id": "forge", "name": "铁花匠", "svg": Art.CHAR_FORGE,
		"weapon": "extinguisher", "role": "主输出·群",
		"line": "一勺铁水泼出去，落在地上才炸开。",
		"unlock": {"kind": "default", "text": "默认"},
	},
	{
		"id": "lantern", "name": "灯彩匠", "svg": Art.CHAR_LANTERN,
		"weapon": "halo", "role": "辅助·控场", "aux": true,
		"line": "灯不落地，火不熄；脚边那一圈就是你的地盘。",
		"unlock": {"kind": "won", "n": 1, "text": "通关一次"},
	},
	{
		"id": "paper", "name": "剪纸婆婆", "svg": Art.CHAR_PAPER,
		"weapon": "blade", "role": "链击",
		"line": "剪一只鹊，它会自己找下一个。",
		"unlock": {"kind": "time", "sec": 600.0, "text": "单局存活 10 分钟"},
	},
	{
		"id": "shadow", "name": "皮影班主", "svg": Art.CHAR_SHADOW,
		"weapon": "phone", "role": "辅助·击退", "aux": true,
		"line": "影子绕着你转，谁凑近谁后退。",
		"unlock": {"kind": "miniboss", "n": 3, "text": "击杀 3 只小 Boss"},
	},
	{
		"id": "sugar", "name": "糖画师", "svg": Art.CHAR_SUGAR,
		"weapon": "glowstick", "role": "主输出·锁定",
		"line": "一勺糖丝，只认最近的那只。",
		"unlock": {"kind": "coins", "n": 5000, "text": "累计 5000 铜钱"},
	},
]

static func all() -> Array[Dictionary]:
	return ENTRIES

static func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if String(e["id"]) == id:
			return e
	return {}

## 当前选中的角色。存档里是空串 / 已失效 / 未解锁时一律回落默认 ——
## 玩家不该因为"清过档"而开不了一局。
static func current_id() -> String:
	var id: String = MetaSave.char_id
	if id == "" or entry(id).is_empty():
		return DEFAULT_ID
	if not is_unlocked(id):
		return DEFAULT_ID
	return id

static func current() -> Dictionary:
	return entry(current_id())

static func starting_weapon(id: String = "") -> String:
	var e: Dictionary = entry(id) if id != "" else current()
	return String(e.get("weapon", "whip"))

## 辅助档起始 Lv2。判据写在数据里（aux 字段），不在调用点判名字。
static func start_level(id: String = "") -> int:
	var e: Dictionary = entry(id) if id != "" else current()
	return 2 if bool(e.get("aux", false)) else 1

## 解锁判定。**读原始计数**（MetaSave 的五个累计值），不读存档里的布尔表 ——
## 规则改完对所有老存档立即生效，也不会出现"后悔改不回去"的解锁残留。
static func is_unlocked(id: String) -> bool:
	var e: Dictionary = entry(id)
	if e.is_empty():
		return false
	var u: Dictionary = e["unlock"]
	match String(u.get("kind", "")):
		"default":
			return true
		"won":
			return MetaSave.won_runs >= int(u.get("n", 1))
		"time":
			return MetaSave.best_time >= float(u.get("sec", 600.0))
		"miniboss":
			return MetaSave.mini_boss_kills >= int(u.get("n", 3))
		"coins":
			return MetaSave.coins_total >= int(u.get("n", 5000))
	return false

## 解锁条件的当前进度文案。已解锁返回空串（UI 不需要再写一遍条件）。
## 给数字而不是百分比：玩家看得懂"3/5 只"，看不懂"60%"。
static func progress_text(id: String) -> String:
	if is_unlocked(id):
		return ""
	var e: Dictionary = entry(id)
	if e.is_empty():
		return ""
	var u: Dictionary = e["unlock"]
	match String(u.get("kind", "")):
		"won":
			return "%d / %d 次" % [MetaSave.won_runs, int(u.get("n", 1))]
		"time":
			return "%d / %d 分" % [int(MetaSave.best_time / 60.0), int(float(u.get("sec", 600.0)) / 60.0)]
		"miniboss":
			return "%d / %d 只" % [MetaSave.mini_boss_kills, int(u.get("n", 3))]
		"coins":
			return "%d / %d" % [MetaSave.coins_total, int(u.get("n", 5000))]
	return ""
