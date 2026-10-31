extends Node

# 局外经济测算（Step 12 的配套工具，不是玩法代码）。
#
# 解决的问题：STAGE4.md §3 里"全满约 7~8 个胜利局"是**手算的估算**，
# 估算一旦和实现漂移，商店定价就会变成拍脑袋。这个工具把三件事钉在同一个来源上：
#   ① 刷怪量 —— 直接积分 WaveTable（游戏实际用的表），不是另写一套公式；
#   ② 金币   —— 直接调 Game.coin_reward()，不是复制一份公式；
#   ③ 价格   —— 直接读 MetaSave.TRACKS。
# 于是"改一个数看结果"不需要改这个文件。
#
# 用法：godot --headless --path . res://tools/EconomyProbe.tscn
#
# 【必须承认的两个假设】
#   1. 击杀比例 R：玩家实际杀掉的入场比例。取 NUM_DESIGN §5.1 的口径（约 0.62），
#      并把 0.42 / 0.74 作为新手 / 熟练的上下界一起打印 —— 单点数字没有意义。
#   2. Boss 战时长 30 秒（params.json 的设计目标）。Boss 在场时刷怪被压到 35%，
#      这段时间的入场量要扣掉，否则会高估金币。

const DT := 0.05
## params.json boss 段的设计目标：一只 Boss 打 30 秒
const BOSS_FIGHT_S := 30.0
## 击杀比例的三个档位：新手 / 模型均值 / 熟练
const KILL_RATIOS: Array[float] = [0.42, 0.62, 0.74]

var _game: GameScene

func _ready() -> void:
	await get_tree().process_frame
	_game = get_node_or_null("Game") as GameScene
	if _game == null:
		print("PROBE FAIL: Game 节点缺失")
		get_tree().quit(1)
		return
	# 冻结局面：这个工具只借用 coin_reward()/MetaSave，不需要游戏跑起来
	await get_tree().process_frame
	GameManager.started = false
	get_tree().paused = true

	var total: float = WaveTable.RUN_LENGTH
	var spawns: float = _spawn_integral(0.0, total)
	var boss_loss: float = _boss_window_loss()
	var elites: float = _elite_integral(0.0, total)
	print("\n========== 局外经济测算（数据源：WaveTable + Game.coin_reward + MetaSave） ==========")
	print("刷怪积分 0~%.0fs：入场 %.0f 只 → Boss 战压制扣减 %.0f 只 → 实际 %.0f 只" % [
		total, spawns, boss_loss, spawns - boss_loss])
	print("精英 %.0f 只 / Boss %d 只 / 单局时长 %.0f 秒" % [elites, WaveTable.BOSSES.size(), total])
	print("全表买满需要 %d 金币" % _all_tracks_cost())

	# ---------- 1) 完整胜利局
	print("\n--- 完整胜利局（撑满 30 分钟，胜利 ×1.5） ---")
	print("%-8s %-12s %-12s %-20s %-12s" % [
		"击杀比例", "击杀数", "金币", "单线买满(攻击 11900)", "全表买满(49250)"])
	var win_coins: Array[int] = []
	for r in KILL_RATIOS:
		var kills: int = int((spawns - boss_loss) * r)
		var coins: int = _reward(kills, total, int(elites * r), WaveTable.BOSSES.size(), true)
		win_coins.append(coins)
		print("%-8.2f %-12d %-12d %-22s %-12s" % [
			r, kills, coins,
			"%.2f 局" % (float(_track_cost("damage")) / float(coins)),
			"%.2f 局" % (float(_all_tracks_cost()) / float(coins)),
		])

	# ---------- 2) 中途死亡：钩子成不成立看的是这个
	print("\n--- 中途死亡（失败无乘数；前 5 分钟无精英）---")
	print("%-10s %-12s %-10s %-10s %-16s" % [
		"存活时长", "击杀数(0.62)", "金币", "能买什么", "距离首购还差"])
	for t_mark in [300.0, 600.0, 900.0, 1200.0, 1500.0]:
		var s: float = _spawn_integral(0.0, t_mark) - _boss_window_loss(t_mark)
		var e: float = _elite_integral(0.0, t_mark)
		var kills: int = int(s * 0.62)
		var coins: int = _reward(kills, t_mark, int(e * 0.62), _bosses_before(t_mark), false)
		print("%-10s %-12d %-10d %-10s %-16s" % [
			"%d:%02d" % [int(t_mark) / 60, int(t_mark) % 60], kills, coins,
			_affordable_summary(coins),
			("%d 局" % int(ceilf(float(_price_of("max_hp", 0)) / float(maxi(coins, 1)))))
				if coins < _price_of("max_hp", 0) else "已够",
		])

	# ---------- 3) 五条线各自的"回本局数"（按模型均值胜局）
	print("\n--- 每条线买满要几个胜利局（按击杀比例 0.62 = %d 金币/局）---" % win_coins[1])
	for t in MetaSave.TRACKS:
		var id: String = String(t["id"])
		print("  %-6s %-4s 合计 %-7d → %.2f 局（首级 %d 金币 → %.2f 局）" % [
			String(t["name"]), "%d 级" % int(t["levels"]), _track_cost(id),
			float(_track_cost(id)) / float(win_coins[1]),
			_price_of(id, 0), float(_price_of(id, 0)) / float(win_coins[1])])

	# ---------- 4) 与 params.json 的口径差
	# params.meta_shop.coins_per_kill = 0.05，而 Step 11 落地的 coin_reward() 用 0.12。
	# 这里把两套口径并排算一遍，让"要不要改"变成一个看得见的决定，而不是一个隐藏的漂移。
	_report_params_gap(int((spawns - boss_loss) * 0.62), int(elites * 0.62))

	get_tree().quit()

## 对照 params.json 的 coins_per_kill，看同一局能拿多少、多久买满
func _report_params_gap(kills: int, elites: int) -> void:
	var per_kill: float = 0.05
	var base: int = int(float(kills) * per_kill) + int(WaveTable.RUN_LENGTH / 12.0)
	base += elites * 6 + WaveTable.BOSSES.size() * 40
	var coins_params: int = int(float(base) * 1.5)
	var coins_live: int = _reward(kills, WaveTable.RUN_LENGTH, elites, WaveTable.BOSSES.size(), true)
	var cost: float = float(_all_tracks_cost())
	print("\n--- 口径对照：params.json meta_shop.coins_per_kill = %.2f（Step 11 实装是 0.12）---" % per_kill)
	print("  同一胜利局（%d 击杀 / %d 精英）：params 口径 %d 金币 → %.1f 局买满；实装口径 %d 金币 → %.1f 局买满" % [
		kills, elites, coins_params, cost / float(maxi(coins_params, 1)),
		coins_live, cost / float(maxi(coins_live, 1))])
	print("  params 的 meta_shop.reach_run = 10：实装比设计目标快 %.0f%%，params 口径慢 %.0f%%（两边都不在 10 上）" % [
		(1.0 - (cost / float(maxi(coins_live, 1))) / 10.0) * 100.0,
		((cost / float(maxi(coins_params, 1))) / 10.0 - 1.0) * 100.0])

# ---------------------------------------------------------------- 积分
## 刷怪量积分：复刻 Game._process 的"计时器到点刷一批"，
## 用 DT 步进而不是解析解，避免以后 spawn_interval 改成非连续函数时这里悄悄失真。
func _spawn_integral(t0: float, t1: float) -> float:
	var t: float = t0
	var left: float = 0.6
	var acc: float = 0.0
	while t < t1:
		left -= DT
		if left <= 0.0:
			acc += float(WaveTable.batch_size(t))
			left = WaveTable.spawn_interval(t)
		t += DT
	return acc

## 精英：Game 每 1 秒掷一次，概率 = 当前波次的 elite_share
func _elite_integral(t0: float, t1: float) -> float:
	var t: float = t0
	var acc: float = 0.0
	while t < t1:
		acc += WaveTable.elite_share(t) * DT
		t += DT
	return acc

## Boss 在场期间刷怪被压到 35%，这段"本该入场却没入场"的量要扣掉
func _boss_window_loss(until_t: float = 1e9) -> float:
	var loss: float = 0.0
	for b in WaveTable.BOSSES:
		var bt: float = float(b["t"])
		if bt > until_t:
			continue
		var rate: float = float(WaveTable.batch_size(bt)) / WaveTable.spawn_interval(bt)
		loss += rate * BOSS_FIGHT_S * (1.0 - WaveTable.MOB_SPAWN_DURING_BOSS)
	return loss

func _bosses_before(t: float) -> int:
	var n := 0
	for b in WaveTable.BOSSES:
		if float(b["t"]) <= t:
			n += 1
	return n

# ---------------------------------------------------------------- 金币 / 商店
## 直接调游戏里的结算函数，保证测的就是玩家拿到的
func _reward(kills: int, seconds: float, elites: int, bosses: int, victory: bool) -> int:
	_game.kills = kills
	_game.elapsed = seconds
	_game.elite_kills = elites
	_game.boss_kills = bosses
	_game.coins_earned = 0
	_game.won = victory
	return _game.coin_reward()

func _price_of(id: String, lv: int) -> int:
	var t: Dictionary = MetaSave.track(id)
	var prices: Array = t.get("price", [])
	if lv < 0 or lv >= prices.size():
		return 0
	return int(prices[lv])

func _track_cost(id: String) -> int:
	var sum := 0
	var cap: int = MetaSave.max_level_of(id)
	for i in cap:
		sum += _price_of(id, i)
	return sum

func _all_tracks_cost() -> int:
	var sum := 0
	for t in MetaSave.TRACKS:
		sum += _track_cost(String(t["id"]))
	return sum

## 这一笔金币能买下哪些"首级"
func _affordable_summary(coins: int) -> String:
	var parts: Array[String] = []
	for t in MetaSave.TRACKS:
		var id: String = String(t["id"])
		var p: int = _price_of(id, 0)
		if p > 0 and coins >= p:
			parts.append(String(t["name"]))
	if parts.is_empty():
		return "什么都买不起"
	return "/".join(parts)
