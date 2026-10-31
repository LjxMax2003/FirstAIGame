extends Node

# P5-T5.2：30 分钟长跑（时间压缩版，headless 也能跑）。
#
# 解决的问题：真实的 30 分钟一局没法反复跑，而"换皮后会不会崩/漏/掉帧"必须整局验证。
# 做法是把 Engine.time_scale 调大，让 1800 游戏秒在几分钟真实时间内跑完。
#
# 【为什么 time_scale 只敢给 5，不是 30】
# `_process` 的 elapsed 吃 delta，会等比例压缩；但 `_physics_process` 是固定 60Hz 步长，
# 时间缩放会把它变成 1/60×scale 秒一步。scale 太大时 move_and_slide 单步位移超过碰撞半径，
# 敌人会"穿模"——那不是性能问题，是物理失真，测出来的东西也就没意义了。
# 5 倍是"能明显压缩、又不至于穿透"的折中（敌人单步 ~8px vs 半径 17px），
# 1800 游戏秒 ≈ 6 分钟真实时间。要更快请改 WALL_CAP 而不是无脑拉 scale。
#
# 【玩家为什么是"打不死的"】
# 本工具验的是系统不崩、池子不漏、帧率不塌，不是难度。每帧把血顶回上限可以保证跑到 1800s，
# 从而一定触发终局演出；接触伤害的计算路径仍然每帧在走，没有绕过。
# ⚠️ 只在开局设一次高血量是无效的：升级会重算 max_hp 并把 hp 夹回上限，
#    第一次实测就是这么在 614s 被磨死的（那时 Boss 还没登场）。
#
# 用法：godot --headless --path . res://tools/P5Soak.tscn
#      （加 --path . res://tools/P5Soak.tscn 之外的参数：--fixed-fps 不影响本工具）

const GAME_SCENE := "res://scenes/Game.tscn"
## 时间压缩倍率。改大之前先读文件头的说明。
## 5 倍时敌人单步位移约 8px（半径 17px），仍在安全区；10 倍会到 16px，接近穿模。
const TIME_SCALE := 5.0
## 采样间隔（游戏秒）：每 150 游戏秒打一行，正好落在五更边界附近，便于和更次对照
const SAMPLE_EVERY := 150.0
## 保险丝：真实时间上限。到了就停，避免 time_scale 被引擎干预时无限等。
const WALL_CAP := 900.0

var _game: GameScene
var _player: Player
var _enemies: EnemyPool
var _lvui: LevelUpUI
var _deathui: DeathUI
var _meta_backup: Dictionary = {}

var _t_wall0 := 0.0
var _next_sample := SAMPLE_EVERY
var _peak_alive := 0
var _peak_gems := 0
var _peak_chests := 0
var _fps_sum := 0.0
var _fps_n := 0
var _fps_min := 9999.0
var _picks := 0
var _rows: Array[String] = []
var _errors: Array[String] = []
## quit() 之后引擎还会再跑一两帧，别让那些帧继续访问已释放的节点
var _done := false

func _ready() -> void:
	# 暂停时也要继续：升级弹窗会把整树暂停，自动选卡钩子必须在暂停里仍能跑
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 长跑用 time_scale 压缩真实时间，若再被 60fps 上限钉住，整轮会慢到没有意义
	Engine.max_fps = 0
	await get_tree().process_frame
	_meta_backup = MetaSave.snapshot()
	MetaSave.debug_set(0, {})

	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_node("World/Player") as Player
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	_lvui = _game.get_node("UI/LevelUpUI") as LevelUpUI
	_deathui = _game.get_node("UI/DeathUI") as DeathUI

	# 打不死的玩家：真正生效的做法在 _process 里（每帧顶血）。
	# 这里只是把开局那几帧也护住，免得第一个采样点之前就被磨死。
	GameManager.stats["hp"] = float(GameManager.stats["max_hp"])
	_player.invuln_left = 0.0

	print("\n========== T5.2 30 分钟长跑（time_scale=%.0fx） ==========" % TIME_SCALE)
	print("%-8s %-6s %-7s %-7s %-8s %-7s %-7s %-8s %-6s" % [
		"游戏时", "更次", "击杀", "同屏", "灯花", "宝箱", "Boss", "fps", "内存MB"])
	Engine.time_scale = TIME_SCALE
	_t_wall0 = Time.get_ticks_msec() / 1000.0

func _process(_delta: float) -> void:
	# _enemies 也要判空：add_child(_game) 之后到取到各节点之间会跨两帧，
	# 那两帧里 _game 已存在但 _enemies 还是 null（会刷出两条假报错，淹没真问题）
	if _game == null or _enemies == null or _done:
		return
	# 打不死的玩家：**每帧**把血顶回上限。
	# 只在开局设一次 hp=1e6 是无效的 —— 升级时 Stats 会重算 max_hp 并把 hp 夹回上限，
	# 第一次实测就是这么在 614s 被磨死的（那时 Boss 还没登场，整局白跑）。
	GameManager.stats["hp"] = float(GameManager.stats["max_hp"])

	# 升级弹窗：必须立刻消费掉，否则 game tree 一直暂停，后面全是假象
	if _lvui != null and _lvui.is_open():
		get_tree().paused = false
		if _auto_pick():
			_picks += 1

	var alive: int = _enemies.alive_count()
	_peak_alive = maxi(_peak_alive, alive)
	_peak_gems = maxi(_peak_gems, _game.gem_count())
	_peak_chests = maxi(_peak_chests, _game.chest_count())
	var f: float = Engine.get_frames_per_second()
	if f > 0.0:
		_fps_sum += f
		_fps_n += 1
		# 头 5 游戏秒不参与"最低帧"统计：那几帧里场景刚建完，被首帧编译拖慢是正常的
		if _game.elapsed > 5.0:
			_fps_min = minf(_fps_min, f)

	# 终局：判胜 → 2 秒演出 → 结算面板。整条链在这里收尾
	if _deathui != null and _deathui.is_open():
		_finish_run("结算面板已打开")
		return

	if _game.elapsed >= _next_sample:
		_sample()
		_next_sample += SAMPLE_EVERY

	var wall: float = Time.get_ticks_msec() / 1000.0 - _t_wall0
	if wall > WALL_CAP:
		_finish_run("触发真实时间保险丝 %.0fs（游戏内只到 %.0fs）" % [wall, _game.elapsed])

func _sample() -> void:
	var wi: int = WaveTable.wave_index(_game.elapsed)
	var mem: float = float(OS.get_static_memory_usage()) / 1048576.0
	var row := "%-8s %-6s %-7d %-7d %-8d %-7d %-7d %-8.0f %-6.1f" % [
		"%02d:%02d" % [int(_game.elapsed) / 60, int(_game.elapsed) % 60],
		HUD.GENG_NAMES[wi].substr(0, 2),
		_game.kills, _enemies.alive_count(), _game.gem_count(),
		_game.chest_count(), _game.boss_kills,
		Engine.get_frames_per_second(), mem]
	_rows.append(row)
	print(row)

func _auto_pick() -> bool:
	var cards: HBoxContainer = _lvui.get_node("Popup/VB/Cards") as HBoxContainer
	if cards.get_child_count() == 0:
		return false
	for c in (cards.get_child(0) as Control).get_children():
		if c is Button:
			(c as Button).pressed.emit()
			return true
	return false

func _finish_run(reason: String) -> void:
	if _game == null or _done:
		return
	_done = true
	Engine.time_scale = 1.0
	var wall: float = Time.get_ticks_msec() / 1000.0 - _t_wall0
	_sample()

	print("\n---------- 汇总 ----------")
	print("结束原因：%s" % reason)
	print("游戏时长 %.1fs / 真实耗时 %.1fs（压缩比 %.1fx）" % [_game.elapsed, wall, _game.elapsed / maxf(wall, 0.001)])
	print("击杀 %d ｜ 传承 %d ｜ 精英 %d ｜ Boss %d ｜ 自动选卡 %d 次" % [
		_game.kills, _game.evolutions, _game.elite_kills, _game.boss_kills, _picks])
	print("峰值 同屏 %d / 灯花 %d / 宝箱 %d" % [_peak_alive, _peak_gems, _peak_chests])
	print("帧率 均值 %.1f / 最低 %.0f（headless 无渲染，只作相对参考）" % [
		_fps_sum / maxf(float(_fps_n), 1.0), _fps_min])

	# ---- 判定（这些是 T5.2 观察清单里能自动判的部分）
	var ok := true
	ok = _assert(_game.elapsed >= WaveTable.RUN_LENGTH - 1.0, "撑满 1800s（实际 %.1fs）" % _game.elapsed) and ok
	ok = _assert(_game.won, "终局 won = true") and ok
	ok = _assert(_deathui.is_open(), "终局 2 秒演出后进入结算面板") and ok
	ok = _assert(_game.boss_kills >= 2, "Boss 至少击杀 2 只（实际 %d）" % _game.boss_kills) and ok
	ok = _assert(_peak_alive >= 100, "同屏峰值 ≥100（实际 %d）" % _peak_alive) and ok
	ok = _assert(_picks > 0, "跑动中确实触发过升级并自动选卡（%d 次）" % _picks) and ok
	ok = _assert(_enemies.alive_count() <= _enemies.max_alive + EnemyPool.BOSS_RESERVE,
		"同屏未越界（%d ≤ %d）" % [_enemies.alive_count(), _enemies.max_alive + EnemyPool.BOSS_RESERVE]) and ok

	var title: Label = _deathui.get_node("Popup/Panel/VB/Title") as Label
	print("结算标题「%s」（应为「五更鸡鸣」）" % title.text)
	ok = _assert(title.text == "五更鸡鸣", "终局标题是「五更鸡鸣」") and ok

	# 存档还原：这一局是造出来的，不能把金币写进玩家真实存档
	MetaSave.debug_set(int(_meta_backup.get("coins", 0)), _meta_backup.get("levels", {}))
	print("存档已还原：coins=%d" % MetaSave.coins)

	print("\n==== T5.2 结论：%s ====" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

func _assert(cond: bool, msg: String) -> bool:
	print("  %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		_errors.append(msg)
	return cond
