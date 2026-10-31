extends Node

# P5-T5.4：密度压力下的帧预算（性能基线）。
#
# 【为什么不用 Performance.TIME_PROCESS 当门禁】
# 初版用的是 `Performance.get_monitor(TIME_PROCESS)`，在 400 同屏报出 52ms/帧（≈19fps）。
# 但同一份数据里 physics 只有 0.24ms，且**关掉全部敌人的每帧逻辑后 TIME_PROCESS 几乎不动**
# （43.35 → 43.56ms），真实帧率却从 33.8 涨到 90.7 —— 一个数字在测到 2.7 倍性能变化时纹丝不动，
# 它就不是帧耗时的可信代理。实测还发现：100 同屏时 TIME_PROCESS 报 13.41ms，
# 而真实帧率 136fps 意味着每帧只有 7.3ms —— 亏空近一倍。
# 结论：TIME_PROCESS 在本工程的 headless 循环里系统性偏高，不能当绝对值门禁。
#
# 改用**墙钟帧间隔**：相邻两帧之间的真实时间差，玩家感受到的就是它，且不依赖任何引擎内部上报。
# TIME_PROCESS 保留为旁证列，只用于横向对比，不参与判定。
#
# 【为什么不和"换皮前"比 fps】
# 换皮前没有任何 fps 记录，拿"记忆中的数字"当基线不可复现；而且 fps 会被 vsync 钉住。
# 改成可复现的绝对值验收：扫描同屏数量 → 找出"还能守住 60fps"的最大同屏数（前沿），
# 再和实际一局的峰值同屏（P5Soak 实测）对照。前沿 ≥ 峰值才算过。
#
# 用法：godot --headless --path . res://tools/P5Perf.tscn

const GAME_SCENE := "res://scenes/Game.tscn"
## 扫描档位：从 100 到设计上限 400（params.json spawn.max_alive）
const STEPS: Array[int] = [100, 150, 200, 250, 300, 350, 400]
## 60fps 的单帧预算
const BUDGET_MS := 16.6
## 每档实测时长（真实秒）
## 1.2s 在 400 同屏只有约 105 帧样本，P95 就是"第 5 差的帧" —— 机器上任何一次后台抖动
## （输入法、杀毒扫描、另一个 godot 进程收尾）都会把它整根抬起来：同一份代码连跑两次，
## 实测 P95 在 10.85~17.66ms 之间飘。2.5s 把样本量翻倍，P95 才勉强可用。
const MEASURE_SEC := 2.5
## 预热：丢掉前若干帧的一次性开销（资源/着色器/首次调用）
const SETTLE_SEC := 0.4
## 策划案 §13.2 承诺的"同屏 300~500 不掉帧"下限
const PROMISED_MIN := 300
## 实测峰值同屏（来自 P5Soak 的「峰值 同屏 N」，每轮长跑后回填）
## 2026-10-27 实测：1800s 整局峰值 275（Boss 战期间 223~227，20~25min 档 150 上下）
const PEAK_FROM_SOAK := 275

var _game: GameScene
var _player: Player
var _enemies: EnemyPool
var _lvui: LevelUpUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ⚠️ 本工具测的是"不限帧时的真实单帧耗时"，必须先把游戏给自己上的 60 上限摘掉
	# （GameManager._ready 会设 Engine.max_fps = 60，autoload 先于本场景跑）。
	# 不摘的话每一档都会被钉在 16.7ms，前沿永远是 400，"余量还剩多少"这个信息就没了。
	Engine.max_fps = 0
	await get_tree().process_frame
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_node("World/Player") as Player
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	_lvui = _game.get_node("UI/LevelUpUI") as LevelUpUI

	# 停掉时间推进带来的刷怪，只保留自己铺的这一批；玩家不死，变量收敛到"敌人 + 武器"
	_game.set("_spawn_left", 1e9)
	_game.set("_elite_left", 1e9)
	GameManager.stats["max_hp"] = 1e9
	GameManager.stats["hp"] = 1e9
	# 六把武器全开、等级拉高：压力主要来自"每帧命中判定 × 同屏数"
	for id in WeaponDB.ORDER:
		if not _game.weapons.has_weapon(id):
			_game.weapons.acquire(id)
		_game.weapons.owned[id] = 6

	print("\n========== T5.4 帧预算扫描（60fps = %.1fms） ==========" % BUDGET_MS)
	print("%-8s %-11s %-11s %-11s %-9s %-11s" % [
		"同屏", "帧间隔均", "帧间隔P50", "帧间隔P95", "真实fps", "TIME_PROCESS"])
	var rows: Array[Dictionary] = []
	for n in STEPS:
		await _reset_to(n)
		var r: Dictionary = await _measure()
		r["n"] = n
		rows.append(r)
		print("%-8d %-11.2f %-11.2f %-11.2f %-9.1f %-11.2f" % [
			n, r["avg"], r["p50"], r["p95"], r["fps"], r["tp"]])

	# ---- 60fps 前沿：P95 仍 ≤ 预算的最大同屏数
	var frontier: int = 0
	for r in rows:
		if float(r["p95"]) <= BUDGET_MS:
			frontier = maxi(frontier, int(r["n"]))
	print("\n60fps 前沿：同屏 %d 只（P95 帧间隔仍 ≤ %.1fms）" % [frontier, BUDGET_MS])
	if frontier < int(STEPS[STEPS.size() - 1]):
		var over: Dictionary = rows[rows.size() - 1]
		print("设计上限 %d 只时 P95 %.2fms（%.1ffps），超预算 %.0f%%" % [
			int(over["n"]), over["p95"], over["fps"],
			(float(over["p95"]) / BUDGET_MS - 1.0) * 100.0])

	var ok := true
	ok = _assert(frontier >= PROMISED_MIN, "60fps 前沿覆盖策划案承诺下限（%d ≥ %d）" % [frontier, PROMISED_MIN]) and ok
	if PEAK_FROM_SOAK > 0:
		ok = _assert(frontier >= PEAK_FROM_SOAK,
			"60fps 前沿覆盖实测峰值同屏（%d ≥ %d）" % [frontier, PEAK_FROM_SOAK]) and ok
	else:
		print("  --   未回填 PEAK_FROM_SOAK，跳过「实测峰值」对照（先跑 P5Soak）")

	print("\n==== T5.4 结论：%s ====" % ("PASS" if ok else "FAIL"))
	print("注：headless 无渲染，以上是**逻辑帧**耗时；GPU/draw call 成本需在真机上看。")
	get_tree().quit(0 if ok else 1)

func _reset_to(n: int) -> void:
	var old: Array[Enemy] = _enemies.active.duplicate()
	for e in old:
		_enemies.forget(e)
		_enemies.deactivate(e)
	await get_tree().process_frame
	for i in n:
		var ang: float = TAU * float(i) / float(maxi(n, 1)) + float(i % 7) * 0.05
		var dist: float = 180.0 + float(i % 5) * 90.0
		var kind: String = ["cup", "bag", "fast"][i % 3]
		_enemies.spawn(_player.global_position + Vector2.from_angle(ang) * dist,
			1e9, 60.0, 1, kind, false, WaveTable.CONTACT_DAMAGE)

## 量真实帧间隔：每次 await 之后记录与上一帧的墙钟差。
## 这是玩家真正感受到的量，且不依赖引擎内部上报。
func _measure() -> Dictionary:
	await _wait_s(SETTLE_SEC)
	var gaps: Array[float] = []
	var tps: Array[float] = []
	var t_prev: int = Time.get_ticks_usec()
	var t0: int = t_prev
	var frames: int = 0
	while true:
		if _lvui.is_open():
			get_tree().paused = false
			_auto_pick()
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		gaps.append(float(now - t_prev) / 1000.0)
		tps.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		t_prev = now
		frames += 1
		if float(now - t0) / 1000000.0 >= MEASURE_SEC:
			break
	var wall: float = float(t_prev - t0) / 1000000.0
	return {
		"avg": _avg(gaps), "p50": _pct(gaps, 0.50), "p95": _pct(gaps, 0.95),
		"fps": float(frames) / maxf(wall, 0.001), "tp": _avg(tps),
	}

func _wait_s(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()

func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(float(a.size()), 1.0)

func _pct(a: Array[float], q: float) -> float:
	var b: Array[float] = a.duplicate()
	b.sort()
	if b.is_empty():
		return 0.0
	return b[clampi(int(float(b.size() - 1) * q), 0, b.size() - 1)]

func _auto_pick() -> void:
	var cards: HBoxContainer = _lvui.get_node("Popup/VB/Cards") as HBoxContainer
	if cards.get_child_count() == 0:
		return
	for c in (cards.get_child(0) as Control).get_children():
		if c is Button:
			(c as Button).pressed.emit()
			return

func _assert(cond: bool, msg: String) -> bool:
	print("  %s %s" % ["ok  " if cond else "FAIL", msg])
	return cond
