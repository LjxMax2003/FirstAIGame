extends Node

# =====================================================================
# 局外存档 + 金币商店数据（Step 12）。
#
# 【为什么单独一个 autoload，而不是塞进 GameManager】
#   GameManager.stats 是「本局数值」，每局 reset() 清空；这里是「跨局数值」，
#   必须活过重开、活过退出进程。混在一起最容易写出的 bug 就是
#   "重开一局把玩家花钱买来的加成清掉了"。
#
# 【Meta 与局内被动的关系：只乘，不加】
#   局内被动是 0..5 的固定档位（Stats.value_at），meta 是全局乘数：
#       最终值 = Stats.value_at(key, lv) × MetaSave.mult(key)
#   这样 meta 既撑不破局内的 5 级上限，也不会让某一件被动变成必选 ——
#   它只是把所有构筑的基线整体抬高一点。
#   params.json meta_shop._note 给的硬约束：meta 满级总乘数 1.15 × 1.176 = 1.35，
#   必须明显低于单把武器进化（2.4），否则"刷金币"会盖过"局内 Build"这个主玩法。
#
# 【数值来源】数值平衡设计/params.json → meta_shop.tracks（价格与步长逐条照抄，
#   改价只改这里；测试会断言这里和 params.json 对得上）。
#
# 【对 params.json 的一处有意改名】
#   params 里的 "might" 在局内管线（Stats.gd）里是「受到接触伤害 -7%」，是减伤；
#   而 meta 的 might 是「攻击 +3%」。同名不同义，直接沿用在代码里必然串味。
#   所以 meta 这条线改叫 "damage"，和局内 +10%/级的伤害被动同一条乘区 ——
#   这也正好满足 growth_rules「同区内加算，区间乘算」：meta 是独立的第二乘区。
# =====================================================================

const SAVE_PATH := "user://save.json"
const SAVE_VER := 1

## 复活后的无敌时长。给足是因为复活点必然在怪堆中央，
## 0.5s（普通受击无敌）会让玩家刚站起来就再死一次，等于白买。
const REVIVE_INVULN := 3.0

## 五条永久成长线。price 是"从 Lv L 升到 Lv L+1"的价格。
## svg 复用局内已有的图标，保证商店里看到的东西和局内认得的东西是同一张图。
const TRACKS: Array[Dictionary] = [
	{
		"id": "damage", "name": "匠心", "svg": Art.GEM_ORANGE,
		"unit": "全部手艺伤害 +3%", "step": 0.03, "levels": 5,
		"price": [200, 500, 1200, 3000, 7000],
	},
	{
		"id": "max_hp", "name": "底气", "svg": Art.PICKUP_BENTO,
		"unit": "生命上限 +10%", "step": 0.10, "levels": 5,
		"price": [150, 400, 1000, 2500, 6000],
	},
	{
		"id": "cooldown", "name": "巧手", "svg": Art.PICKUP_BOMB,
		"unit": "全部手艺冷却 -3%", "step": 0.03, "levels": 5,
		"price": [300, 700, 1600, 4000, 9000],
	},
	{
		"id": "magnet", "name": "听风", "svg": Art.PICKUP_MAGNET,
		"unit": "灯花拾取范围 +10%", "step": 0.10, "levels": 3,
		"price": [100, 300, 800],
	},
	{
		# 复活不做乘数，是"多一条命"：唯一一条会改变单局结构而不是数值的线，
		# 所以价格最贵（2500 起，等于 1~2 个完整胜利局）。
		"id": "revive", "name": "灯不灭", "svg": Art.CHEST,
		"unit": "血量归零时原地满血复活 1 次", "step": 1.0, "levels": 2,
		"price": [2500, 8000], "unit_short": "次",
	},
]

var coins: int = 0
## id -> 已买等级
var levels: Dictionary = {}
## 本局还剩几次复活（每局开局重置，不写进存档）
var revive_left: int = 0
## 存档是否成功载入过（false = 存档损坏或首次运行，UI 可以据此提示）
var loaded: bool = false

# ---------------------------------------------------------------- v7 首局引导（L-07 / T5）
## 三页开场是否看过。**只写存档、不随"清除进度"以外的场合复位** ——
## 它是"这个玩家已经知道这是什么游戏了"的凭据，不是本局状态。
var intro_done: bool = false
## 已出现过的一次性情境提示（id → true）。
## 用字典而不是位掩码：以后加第 6、第 7 条提示不需要改存档结构。
var seen_tips: Dictionary = {}

# ---------------------------------------------------------------- v7.1 角色解锁（T9）
## 五个"累计成就"计数。它们是角色解锁条件的唯一依据 ——
## 刻意**不**存 unlock 布尔表：存布尔表意味着规则一改，老存档里已经发出去的解锁
## 就永远收不回来；存原始计数，规则改完对老存档立即生效。
var won_runs: int = 0
var best_time: float = 0.0
var mini_boss_kills: int = 0
var coins_total: int = 0
## 当前选中的匠人 id。空串 = 还没选过，一律回落到默认（铁花匠）。
var char_id: String = ""

# ---------------------------------------------------------------- v7.1 图鉴（T12）
## 已收录条目：id → true。
## 【为什么是集合而不是"33 个 bool 字段"】图鉴会加条目（T19 的成就也要往里塞），
##   集合加一条只是多一个字符串；不存集合而是存"每条是否解锁"就得改存档结构、
##   还得处理"新加的条目不认识"的分支。
var codex_seen: Dictionary = {}
## 图鉴有未落盘的收录（见 note_codex 的注释）。
var _codex_dirty := false

func _ready() -> void:
	load_save()

# ---------------------------------------------------------------- 存档 IO
## 首次运行 / 存档损坏都算正常路径：给一份干净初始值并落盘，
## 让后面所有"读存档"的地方都不必再判空。
func load_save() -> void:
	coins = 0
	levels = {}
	for t in TRACKS:
		levels[String(t["id"])] = 0
	revive_left = 0
	loaded = false
	intro_done = false
	seen_tips = {}
	won_runs = 0
	best_time = 0.0
	mini_boss_kills = 0
	coins_total = 0
	char_id = ""
	codex_seen = {}

	if not FileAccess.file_exists(SAVE_PATH):
		save()
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("MetaSave: 无法打开存档 %s（error %d），使用初始值" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		# 存档被截断/手改坏了：不弹错误，直接从 0 开始，
		# 玩家最多丢一点金币，比"一进游戏就崩"好得多。
		push_warning("MetaSave: 存档内容不是合法 JSON，已重置")
		save()
		return
	var d: Dictionary = parsed as Dictionary
	coins = maxi(0, int(d.get("coins", 0)))
	var saved_levels: Variant = d.get("levels", {})
	if saved_levels is Dictionary:
		for t in TRACKS:
			var id: String = String(t["id"])
			var cap: int = int(t["levels"])
			levels[id] = clampi(int((saved_levels as Dictionary).get(id, 0)), 0, cap)
	intro_done = bool(d.get("intro_done", false))
	# 老存档（v7.0 及之前）没有这五个键：读不到就是 0，不会报错，也不会误发解锁。
	won_runs = maxi(0, int(d.get("won_runs", 0)))
	best_time = maxf(0.0, float(d.get("best_time", 0.0)))
	mini_boss_kills = maxi(0, int(d.get("mini_boss_kills", 0)))
	coins_total = maxi(0, int(d.get("coins_total", 0)))
	char_id = String(d.get("char_id", ""))
	var st: Variant = d.get("seen_tips", {})
	if st is Dictionary:
		seen_tips = (st as Dictionary).duplicate()
	# 老存档没有 codex_seen：读不到就是空集，图鉴从零开始，不报错
	var cx: Variant = d.get("codex_seen", {})
	if cx is Dictionary:
		codex_seen = (cx as Dictionary).duplicate()
	loaded = true

func save() -> void:
	var payload: Dictionary = {
		"v": SAVE_VER,
		"coins": coins,
		"levels": levels.duplicate(),
		"intro_done": intro_done,
		"seen_tips": seen_tips.duplicate(),
		"won_runs": won_runs,
		"best_time": best_time,
		"mini_boss_kills": mini_boss_kills,
		"coins_total": coins_total,
		"char_id": char_id,
		"codex_seen": codex_seen.duplicate(),
	}
	var tmp: String = SAVE_PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("MetaSave: 无法写入 %s（error %d）" % [tmp, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(payload))
	f.close()
	# 先写临时文件再改名：直接覆盖原文件时若中途崩溃，会留下一个半截 JSON，
	# 玩家的全部局外进度就没了。改名在同一分区上是原子的。
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	dir.rename(tmp, SAVE_PATH)

# ---------------------------------------------------------------- 查询
static func track(id: String) -> Dictionary:
	for t in TRACKS:
		if String(t["id"]) == id:
			return t
	return {}

static func track_ids() -> Array[String]:
	var out: Array[String] = []
	for t in TRACKS:
		out.append(String(t["id"]))
	return out

func level_of(id: String) -> int:
	return int(levels.get(id, 0))

func max_level_of(id: String) -> int:
	return int(track(id).get("levels", 0))

func is_maxed(id: String) -> bool:
	return level_of(id) >= max_level_of(id)

## 下一级价格；已满级返回 -1（而不是 0，避免"0 元可买"这种 UI 误判）。
func price_of(id: String) -> int:
	if is_maxed(id):
		return -1
	var prices: Array = track(id).get("price", [])
	var lv: int = level_of(id)
	if lv >= prices.size():
		return -1
	return int(prices[lv])

func can_afford(id: String) -> bool:
	var p: int = price_of(id)
	return p >= 0 and coins >= p

## 现在有几条线买得起（结算界面用它提示"能买东西了"）
func affordable_count() -> int:
	var n := 0
	for t in TRACKS:
		if can_afford(String(t["id"])):
			n += 1
	return n

# ---------------------------------------------------------------- 乘数
## 局外乘数。没买的线返回 1.0 —— 所以"没存档 = 行为和阶段三完全一致"。
## 冷却返回 < 1（越小越快），和 Stats.value_at("cooldown") 的口径保持一致。
func mult(id: String) -> float:
	var t: Dictionary = track(id)
	if t.is_empty():
		return 1.0
	var step: float = float(t.get("step", 0.0))
	var lv: int = level_of(id)
	match id:
		"cooldown":
			return 1.0 - step * float(lv)
		"revive":
			# 复活不是乘数（不是"1 的多少倍"），调用方请用 level_of("revive")
			return 1.0
		_:
			return 1.0 + step * float(lv)

## 「0 → 满」的总乘数，只给 UI 展示用（让玩家看得见"买满能强多少"）
func mult_at(id: String, lv: int) -> float:
	var t: Dictionary = track(id)
	if t.is_empty():
		return 1.0
	var step: float = float(t.get("step", 0.0))
	var cap: int = clampi(lv, 0, int(t.get("levels", 0)))
	if id == "cooldown":
		return 1.0 - step * float(cap)
	if id == "revive":
		return 1.0
	return 1.0 + step * float(cap)

# ---------------------------------------------------------------- 变更
## 入账。返回入账后的总余额（结算界面要显示"本局 +N，合计 M"）。
func add_coins(n: int) -> int:
	if n <= 0:
		return coins
	coins += n
	# coins_total 是"累计赚了多少"，只增不减（购买不回退）——
	# 它是糖画师的解锁条件，用当前余额判定会让玩家"一买东西进度倒退"。
	coins_total += n
	save()
	return coins

# ---------------------------------------------------------------- v7.1 角色进度
## 一局结束记一次（成功或失败都要记：best_time 对失败局同样有意义）。
## 放在 Game._finish 这个唯一的收口处调用，天然防重复记账。
func record_run(victory: bool, elapsed: float) -> void:
	if victory:
		won_runs += 1
	best_time = maxf(best_time, elapsed)
	save()

## 小 Boss 击杀 +1。三档小 Boss（通灵鼓 / 傩面 / 长夜灯）都走这一条。
func note_mini_boss_kill() -> void:
	mini_boss_kills += 1
	save()

## 选中的匠人。传空串表示回到默认。
func set_character(id: String) -> void:
	char_id = id
	save()

## 购买一级。失败（钱不够 / 已满级）返回 false 且不扣钱 —— 
## 宁可让 UI 静默失败，也不要出现"点了一下金币少了但等级没涨"。
func buy(id: String) -> bool:
	var p: int = price_of(id)
	if p < 0 or coins < p:
		return false
	coins -= p
	levels[id] = level_of(id) + 1
	save()
	return true

# ---------------------------------------------------------------- 单局生命周期
## 每局开局调用：把"本局可用次数"类的东西重置掉。
## 注意这里**不**重置 coins/levels —— 那是跨局资产。
func begin_run() -> void:
	revive_left = level_of("revive")

## 消耗一次复活。返回是否有得用。
func consume_revive() -> bool:
	if revive_left <= 0:
		return false
	revive_left -= 1
	return true

# ---------------------------------------------------------------- 调试 / 测试
## 整体覆盖（只在自动化测试与调试里用）。传 -1 表示不关心金币；
## new_levels 里没写的线会被**清零**——这样它既能"只改一条线"，也能完整还原一份快照。
## extra 用来还原 v7.1 的进度字段（won_runs / best_time / ... / char_id）。
## 不传就保持原样：V7Shell 这类老用例不关心它们，不该被强行清零。
func debug_set(new_coins: int, new_levels: Dictionary, extra: Dictionary = {}) -> void:
	if new_coins >= 0:
		coins = new_coins
	for t in TRACKS:
		var id: String = String(t["id"])
		levels[id] = clampi(int(new_levels.get(id, 0)), 0, int(t["levels"]))
	revive_left = level_of("revive")
	if not extra.is_empty():
		won_runs = maxi(0, int(extra.get("won_runs", 0)))
		best_time = maxf(0.0, float(extra.get("best_time", 0.0)))
		mini_boss_kills = maxi(0, int(extra.get("mini_boss_kills", 0)))
		coins_total = maxi(0, int(extra.get("coins_total", 0)))
		char_id = String(extra.get("char_id", ""))
		# 图鉴同样只在显式传了 codex 时才覆盖：截图/验收工具要能"摆一个
		# 收录了 N 条的中间态"，也要能"原样还原"。不传 = 不动。
		if extra.has("codex"):
			var c: Variant = extra["codex"]
			codex_seen = (c as Dictionary).duplicate() if c is Dictionary else {}
	save()

func snapshot() -> Dictionary:
	return {
		"coins": coins, "levels": levels.duplicate(),
		"won_runs": won_runs, "best_time": best_time,
		"mini_boss_kills": mini_boss_kills, "coins_total": coins_total,
		"char_id": char_id,
		# 键名故意和 debug_set 的 extra 对齐（"codex"）：这样
		#   MetaSave.debug_set(b["coins"], b["levels"], b)
		# 就是一次完整的还原，不需要调用方逐字段抄一遍 —— 抄漏的那个字段
		# 会静默留在"测试改过的值"上，下次跑就变成幽灵 bug。
		"codex": codex_seen.duplicate(),
	}

# ---------------------------------------------------------------- 引导标记
## 标记一条情境提示已经出现过，返回"这是不是第一次"。
## 返回值即"要不要显示"，把判重和记账合成一次调用 —— 分成两步必然有人只调一半。
func mark_tip(id: String) -> bool:
	if bool(seen_tips.get(id, false)):
		return false
	seen_tips[id] = true
	save()
	return true

func has_tip(id: String) -> bool:
	return bool(seen_tips.get(id, false))

# ---------------------------------------------------------------- 图鉴（T12）
## 收录一条。返回"是不是首次"（调用方据此决定弹不弹"新收录"）。
## 【为什么查字典就 return】这条会被每次击杀调用（300 同屏时每帧几十次），
## 命中的分支必须是"一次 has + 返回"，不能有 save / push 之类。
## 【为什么不在新收录时立刻 save】
##   一开始是立刻写的，跑 V5InGame 时抓到一个真问题：一局里前 9 只新怪会连着写 9 次盘，
##   而写盘是"写 tmp + remove + rename"三步同步 IO（存档在 user:// 上）。
##   那不是"偶尔卡一下"，是**战斗中可复现的掉帧源**，而且会拖歪依赖帧时序的断言
##   （实测师刀双扫那条用例因此稳定红）。所以改成标记脏位、在安全时机统一 flush。
## 【那什么时候 flush】结算（Game._finish）、打开图鉴、清档、以及窗口关闭/退出树。
##   这四处覆盖了"玩家会离开"的全部路径；进程被强杀才会丢，那本来也保不住。
func note_codex(id: String) -> bool:
	if id == "" or bool(codex_seen.get(id, false)):
		return false
	codex_seen[id] = true
	_codex_dirty = true
	return true

## 把攒下的图鉴收录落盘。可以随便多调 —— 没有脏位时是空操作。
func flush_codex() -> void:
	if not _codex_dirty:
		return
	_codex_dirty = false
	save()

func _notification(what: int) -> void:
	# 关窗 / 退出场景树时补一次：玩家拔电源那一瞬间谁也保不住，
	# 但"点右上角 ×"这种正常退出必须存上。
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE \
			or what == NOTIFICATION_PREDELETE:
		flush_codex()

func has_codex(id: String) -> bool:
	return bool(codex_seen.get(id, false))

## 设置里的"重看开场"：只清开场与提示，不动铜钱与传承。
func reset_intro() -> void:
	intro_done = false
	seen_tips = {}
	save()

## 设置里的"清除存档"：清掉全部局外进度（含引导标记），不碰 user://settings.cfg。
func reset_progress() -> void:
	coins = 0
	for t in TRACKS:
		levels[String(t["id"])] = 0
	revive_left = 0
	intro_done = false
	seen_tips = {}
	# 角色解锁进度也算局外进度：清档就是"从没玩过"，不该留着已解锁的匠人
	won_runs = 0
	best_time = 0.0
	mini_boss_kills = 0
	coins_total = 0
	char_id = ""
	codex_seen = {}
	save()

## 重新从磁盘读一遍：测试用它验证"写进去的东西真的落盘了"。
func reload_from_disk() -> void:
	load_save()

## 存档文件是否存在（验收用）
func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
