extends Node

# ============================================================================
# 帧率上限 + vsync 组合的**节奏**对照（真窗口，必须带渲染跑）
# ----------------------------------------------------------------------------
# 为什么不能只看平均帧率：
#   平均 60fps 可以是"每帧 16.6ms"，也可以是"12.1ms / 18.2ms / 12.1ms 交替"。
#   后者在 165Hz 屏上必然出现：165 / 60 = 2.75 个 vblank，不是整数，
#   于是某些帧等 2 个 vblank、某些等 3 个 —— 平均 60，观感却是一顿一顿。
#   这正是"帧率数字看着正常、操作却觉得卡"的来源，所以本工具统计的是
#   **帧间隔的分布**（P50/P95/P99/max + 超差帧占比），而不是 fps。
#
# 三个组合各测一遍：
#   ① 不限帧 + vsync    （改动之前的状态：被钉在显示器刷新率 165Hz）
#   ② 限 60  + vsync    （只加限帧）
#   ③ 限 60  + 关 vsync （限帧并且让帧间隔自己均匀）
#
# 用法：godot --path . res://tools/FramePace.tscn
#   ⚠️ 不要加 --headless：headless 没有 vblank，三种组合测出来全一样。
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"
## 铺多少只敌人：取 20~25min 档的实测峰值量级（P5Soak 峰值 275）
const DENSITY := 260
## 每组采样时长（真实秒）
const SAMPLE_SEC := 4.0
## 预热：丢掉进场景、首次命中特效、着色器编译这些一次性开销
const WARMUP_SEC := 1.5
## 一帧"明显不对"的阈值：60fps 预算是 16.6ms，超过 25ms 就是掉了至少一帧
const BAD_MS := 25.0

var _game: GameScene
var _enemies: EnemyPool

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	await _fill()

	print("\n===== 帧节奏对照（刷新率 %.1f Hz，同屏 %d 只）=====" % [
		DisplayServer.screen_get_refresh_rate(), DENSITY])
	print("%-22s %-9s %-9s %-9s %-9s %-9s %-9s" % [
		"组合", "均ms", "P50", "P95", "P99", "最大", "超25ms"])

	await _run("① 不限帧 + vsync", 0, DisplayServer.VSYNC_ENABLED)
	await _run("② 限60 + vsync", 60, DisplayServer.VSYNC_ENABLED)
	await _run("③ 限60 + 关vsync", 60, DisplayServer.VSYNC_DISABLED)

	# 收尾：还原成游戏默认口径（限 60 + vsync 开）
	Engine.max_fps = GameManager.MAX_FPS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	get_tree().quit(0)

func _fill() -> void:
	_game.set("_spawn_left", 1e9)
	_game.set("_elite_left", 1e9)
	GameManager.stats["max_hp"] = 1e9
	GameManager.stats["hp"] = 1e9
	var player: Player = _game.get_node("World/Player") as Player
	for i in DENSITY:
		var ang: float = TAU * float(i) / float(DENSITY) + float(i % 7) * 0.05
		var dist: float = 180.0 + float(i % 5) * 90.0
		var kind: String = ["cup", "bag", "fast"][i % 3]
		_enemies.spawn(player.global_position + Vector2.from_angle(ang) * dist,
			1e9, 60.0, 1, kind, false, WaveTable.CONTACT_DAMAGE)
	await get_tree().process_frame

func _run(label: String, fps_cap: int, vsync: int) -> void:
	Engine.max_fps = fps_cap
	DisplayServer.window_set_vsync_mode(vsync)
	await _wait_s(WARMUP_SEC)
	var gaps: Array[float] = []
	var t_prev: int = Time.get_ticks_usec()
	var t_end: int = t_prev + int(SAMPLE_SEC * 1_000_000.0)
	while true:
		# 升级弹窗会把整树暂停，暂停里帧间隔没有意义 —— 直接选一张卡继续
		if _game.level_up_ui != null and _game.level_up_ui.is_open():
			get_tree().paused = false
			_auto_pick()
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		gaps.append(float(now - t_prev) / 1000.0)
		t_prev = now
		if now >= t_end:
			break
	gaps.sort()
	var n: int = gaps.size()
	var sum: float = 0.0
	var bad: int = 0
	for g in gaps:
		sum += g
		if g > BAD_MS:
			bad += 1
	print("%-22s %-9.2f %-9.2f %-9.2f %-9.2f %-9.2f %-9s" % [
		label, sum / float(n), _pct(gaps, 50.0), _pct(gaps, 95.0),
		_pct(gaps, 99.0), gaps[n - 1],
		"%d/%d" % [bad, n]])

func _pct(sorted_gaps: Array[float], p: float) -> float:
	if sorted_gaps.is_empty():
		return 0.0
	var idx: int = clampi(int(round(p / 100.0 * float(sorted_gaps.size()))) - 1, 0, sorted_gaps.size() - 1)
	return sorted_gaps[idx]

func _wait_s(seconds: float) -> void:
	var t_end: int = Time.get_ticks_usec() + int(seconds * 1_000_000.0)
	while Time.get_ticks_usec() < t_end:
		await get_tree().process_frame

func _auto_pick() -> void:
	var lvui: LevelUpUI = _game.level_up_ui
	if lvui == null:
		return
	var cards: HBoxContainer = lvui.get_node("Popup/VB/Cards") as HBoxContainer
	if cards.get_child_count() == 0:
		return
	for c in (cards.get_child(0) as Control).get_children():
		if c is Button:
			(c as Button).pressed.emit()
			return
