extends Node

# P5-T5.4 补测：分辨「帧预算真超了」还是「探针口径有偏」，并把成本归因到具体系统。
#
# 【为什么需要这个工具】
# `P5Perf` 在 400 只同屏时报 process=52ms/帧（≈19fps），但 physics 只有 0.24ms。
# 这两个数字互相矛盾：400 只敌人的移动 + 分离若是真吃 52ms，它必须落在 process 或 physics
# 其中一处；现在是一处爆炸、另一处几乎为零，说明得先确认数字本身站不站得住。
#
# 本工具做三件事：
#   ① 用**真实墙钟帧率**校准 TIME_PROCESS。headless 无 vsync、无 max_fps，
#      帧循环是紧循环，所以 fps 与 process 耗时应当互为倒数。若 fps≈19 则数字是真的；
#      若 fps 明显更高，则 TIME_PROCESS 里混进了不属于本帧的东西，P5Perf 的门禁要改口径。
#   ② 按 0/100/200/300/400 阶梯扫，看增长是线性还是超线性（超线性 = 藏了 O(n²)）。
#   ③ 在 400 档做归因：关掉敌人 _process / 只放挂 shader 的 fast / 只放不挂 shader 的 cup。
#      最后一条直接回答「换皮（描边 shader）有没有引入性能回退」。
#
# 用法：godot --headless --path . res://tools/P5PerfScale.tscn

const GAME_SCENE := "res://scenes/Game.tscn"
const STEPS: Array[int] = [0, 100, 200, 300, 400]
const TARGET := 400
## 每档实测时长（真实秒）。headless 帧循环很快，1.5s 足够覆盖上百帧。
const MEASURE_SEC := 1.5
## 预热时长：丢掉刚生成时的扩容/首次调用开销
const SETTLE_SEC := 0.3

var _game: GameScene
var _player: Player
var _enemies: EnemyPool
var _lvui: LevelUpUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 摘掉 GameManager 上的 60 上限：本工具要量的是不限帧下的真实帧耗时
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

	# 与 P5Perf 保持一致：停刷怪、玩家不死、六把武器全开 —— 差异只来自同屏数量
	_game.set("_spawn_left", 1e9)
	_game.set("_elite_left", 1e9)
	GameManager.stats["max_hp"] = 1e9
	GameManager.stats["hp"] = 1e9
	for id in WeaponDB.ORDER:
		if not _game.weapons.has_weapon(id):
			_game.weapons.acquire(id)
		_game.weapons.owned[id] = 6

	print("\n========== T5.4 补测：真实帧率 × 同屏规模 ==========")
	print("%-8s %-9s %-13s %-13s %-8s" % ["同屏", "真实fps", "process均值", "process P95", "帧数"])
	var rows: Array[Dictionary] = []
	for n in STEPS:
		await _reset_to(n)
		var r: Dictionary = await _measure()
		r["n"] = n
		rows.append(r)
		print("%-8d %-9.1f %-13.2f %-13.2f %-8d" % [n, r["fps"], r["p_avg"], r["p_p95"], r["frames"]])

	# ---- 增长形态：用 400 / 200 的 process 均值比判断线性还是超线性
	var r200: Dictionary = _row_of(rows, 200)
	var r400: Dictionary = _row_of(rows, 400)
	var ratio: float = float(r400["p_avg"]) / maxf(float(r200["p_avg"]), 0.001)
	print("\n200→400 的 process 均值放大 %.2f 倍（线性应≈2.0，明显更大则存在超线性项）" % ratio)

	# ---- 归因：400 档，逐个关掉系统看差值
	print("\n---------- 400 档归因 ----------")
	print("%-22s %-11s %-9s" % ["变体", "process均值", "真实fps"])
	await _reset_to(TARGET)
	var base: Dictionary = await _measure()
	print("%-22s %-11.2f %-9.1f" % ["① 全开（基线）", base["p_avg"], base["fps"]])

	await _reset_to(TARGET)
	for e in _enemies.active:
		e.set_process(false)
	var no_ep: Dictionary = await _measure()
	print("%-22s %-11.2f %-9.1f" % ["② 敌人 _process 关", no_ep["p_avg"], no_ep["fps"]])

	var one_fast: Dictionary = await _reset_to_kind(TARGET, "fast")
	print("%-22s %-11.2f %-9.1f" % ["③ 全 fast（挂描边）", one_fast["p_avg"], one_fast["fps"]])
	var one_cup: Dictionary = await _reset_to_kind(TARGET, "cup")
	print("%-22s %-11.2f %-9.1f" % ["④ 全 cup（无描边）", one_cup["p_avg"], one_cup["fps"]])

	# ---- 结论
	print("\n---------- 判定 ----------")
	var fps_check: float = float(base["fps"])
	var proc_check: float = float(base["p_avg"])
	var implied_fps: float = 1000.0 / maxf(proc_check, 0.001)
	var consistent: bool = absf(fps_check - implied_fps) / maxf(implied_fps, 0.001) < 0.35
	print("① process 均值 %.2fms 反推 %.1ffps，实测 %.1ffps → %s" % [
		proc_check, implied_fps, fps_check, "两者一致，数字可信" if consistent else "两者背离，口径需复核"])

	var shader_delta: float = float(one_fast["p_avg"]) - float(one_cup["p_avg"])
	print("③④ 描边 shader 的 process 差值 %+.2fms（%.1f%%）→ %s" % [
		shader_delta, shader_delta / maxf(float(one_cup["p_avg"]), 0.001) * 100.0,
		"换皮未引入 CPU 开销" if absf(shader_delta) < float(one_cup["p_avg"]) * 0.1 else "换皮可能有开销，需细查"])

	var enemy_share: float = (float(base["p_avg"]) - float(no_ep["p_avg"])) / maxf(float(base["p_avg"]), 0.001) * 100.0
	print("② 敌人每帧逻辑占 process 的 %.1f%%，其余 %.1f%% 在武器/掉落/UI" % [
		enemy_share, 100.0 - enemy_share])

	get_tree().quit(0)

## 重置到恰好 n 只：先全回收，再补足。所有档位用同一套回收/生成路径，避免残留影响
func _reset_to(n: int) -> void:
	var old: Array[Enemy] = _enemies.active.duplicate()
	for e in old:
		_enemies.forget(e)
		_enemies.deactivate(e)
	await get_tree().process_frame
	for i in n:
		_spawn_one(i, "cup" if i % 3 == 0 else ("bag" if i % 3 == 1 else "fast"), n)

func _reset_to_kind(n: int, kind: String) -> Dictionary:
	var old: Array[Enemy] = _enemies.active.duplicate()
	for e in old:
		_enemies.forget(e)
		_enemies.deactivate(e)
	await get_tree().process_frame
	for i in n:
		_spawn_one(i, kind, n)
	return await _measure()

func _spawn_one(i: int, kind: String, total: int) -> void:
	# 与 P5Perf 同一套环形铺开：保证每档的初始几何一致，可比
	var ang: float = TAU * float(i) / float(maxi(total, 1)) + float(i % 7) * 0.05
	var dist: float = 180.0 + float(i % 5) * 90.0
	_enemies.spawn(_player.global_position + Vector2.from_angle(ang) * dist,
		1e9, 60.0, 1, kind, false, WaveTable.CONTACT_DAMAGE)

func _measure() -> Dictionary:
	await _wait_s(SETTLE_SEC)
	var t0: int = Time.get_ticks_usec()
	var frames: int = 0
	var ps: Array[float] = []
	while true:
		if _lvui.is_open():
			get_tree().paused = false
			_auto_pick()
		await get_tree().process_frame
		frames += 1
		ps.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		if float(Time.get_ticks_usec() - t0) / 1000000.0 >= MEASURE_SEC:
			break
	var wall: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	return {
		"fps": float(frames) / maxf(wall, 0.001),
		"p_avg": _avg(ps),
		"p_p95": _pct(ps, 0.95),
		"frames": frames,
		"wall": wall,
	}

func _row_of(rows: Array[Dictionary], n: int) -> Dictionary:
	for r in rows:
		if int(r["n"]) == n:
			return r
	return {"p_avg": 0.0, "fps": 0.0}

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
