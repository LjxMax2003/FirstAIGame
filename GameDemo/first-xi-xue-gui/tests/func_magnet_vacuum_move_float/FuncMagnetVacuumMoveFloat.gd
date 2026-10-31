extends Node

# =====================================================================
# 测试类型：功能测试（Functional Test）
# 目标引擎 / 版本：Godot 4（四端 QA 工程 · 银橙AI）
# 被测模块：GemPool / Gem（经验宝石） + PickupField（铜铃 = 磁铁，全图吸取经验）
# 关联缺陷：拾取「铜铃」后若玩家移动，部分经验宝石会"逃逸式漂浮"一段时间才被
#           收进袋（极端时长时间不收）。
#
# 缺陷机理（已定位，供修复参考，非测试断言本身）：
#   Gem.tick() 的强制吸取走的是「速度只累加、不直接指向玩家」的惯性吸附：
#       vel += to_player / d * pull * delta
#       vel = vel.limit_length(MAX_FLIGHT_SPEED)   # 1100 px/s
#   pull 在宝石远离玩家时仅为 FLIGHT_ACCEL(2600)，而维持贴身绕飞所需的向心加速度
#   约 V_c^2 / R。当 R > ~465px 且玩家在移动、给宝石注入切向分量时，pull < V_c^2/R，
#   宝石不被拉回、反而螺旋向外逃逸，于是"漂浮"在场上。
#   静止时宝石直冲玩家（径向速度≈1100），无切向分量，故不触发——与"仅移动时复现"一致。
#
# 复现思路（确定性，非概率，复现率 100%）：
#   ① 玩家四周铺一圈宝石，半径取 300px（<临界，移动也应被收）与 600px（>临界，
#      移动时可能逃逸）两档，各 8 方向，共 16 颗。
#   ② 在玩家脚下生成「铜铃」掉落物，由 PickupField 的真实拾取通路触发
#      gems.vacuum_all()——与玩家手动拾取同一条代码路径。
#   ③ 拾取的同一时刻起，让玩家持续移动（与 SmokeTest Step1 同一条输入通路：_drag_dir）。
#   ④ 轮询至 VACUUM_WINDOW，断言场上宝石数归零；超出 CLEAR_BOUND 即记为"漂浮一段时间"。
#
# 对照（阶段 A）：同样的全图吸取，但玩家静止 → 应在 CLEAR_BOUND 内清空，用于隔离变量。
#
# 预期（正确行为）：无论玩家是否移动，全图宝石都应被强制吸取并在 CLEAR_BOUND(1.5s) 内收进袋。
# 缺陷表现（阶段 B）：移动时 600px 档宝石逃逸漂浮 → remaining>0（主断言 FAIL）或
#          清空耗时 > CLEAR_BOUND（诊断断言 FAIL）。
#
# 运行：
#   godot --headless --path . res://tests/func_magnet_vacuum_move_float/FuncMagnetVacuumMoveFloat.tscn
# 退出码：0 = 全部通过（未复现缺陷）/ 1 = 存在失败（复现到缺陷）
# =====================================================================

const GAME_SCENE := "res://scenes/Game.tscn"

# ---- 复现参数（全部钉死，保证可复现）----
const N_DIRS := 8
const R_NEAR := 300.0            # < 逃逸临界半径，移动也应被收
const R_FAR  := 600.0            # > 逃逸临界半径，移动时可能逃逸漂浮
const VACUUM_WINDOW := 4.0       # 拾取后轮询上限（秒）
const CLEAR_BOUND := 1.5         # 正确行为下应在此时间内清空（秒）
const PLAYER_MOVE_DIR := Vector2(1.0, 0.0)   # 持续向右移动

var _fails: Array[String] = []
var _game: GameScene = null
var _player: Player = null
var _gems: GemPool = null
var _meta_backup: Dictionary = {}

func _ready() -> void:
	# 必须 PROCESS_MODE_ALWAYS：否则自动选卡/暂停等钩子会被冻结，逻辑帧不推进
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 备份真实存档，测试期间清零（阶段四 MetaSave 会被改），测完原样还回
	_meta_backup = MetaSave.snapshot()
	MetaSave.debug_set(0, {})
	await _boot()
	await _phase_control_no_move()
	await _phase_bug_move_floats()
	await _restore_and_report()

# ---------------------------------------------------------------- 启动
func _boot() -> void:
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_node("World/Player") as Player
	_gems = _game.get_node("World/GemPool") as GemPool
	# 让宝石/掉落物每帧驱动；GemPool._process 与 PickupField._process 都看这个标志
	GameManager.started = true

# ---------------------------------------------------------------- 公共前置
func _prep() -> void:
	get_tree().paused = false
	GameManager.started = true
	_player.set("invuln_left", 999999.0)
	_player.xp = 0
	_player.xp_next = 1 << 30          # 冻结经验条，避免拾取途中升级弹窗把整树暂停
	if _player.is_dragging():
		_player.set("_drag_active", false)
		_player.set("_drag_dir", Vector2.ZERO)
	_player.set("_drag_index", -1)
	_game.pickups.clear_all()
	_game.enemies.clear_all()
	await _wait_frames(2)

func _wait_frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	await _wait_frames(maxi(1, int(seconds * 60.0)))

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		_fails.append(msg)

# 在玩家四周铺一圈宝石（两档半径 × 8 方向），返回总数
func _spawn_ring() -> int:
	# 注意：GemPool._collect() 只把宝石塞回 inactive 并设为不可见，并不会把它从
	# active 移除（移除是在 GemPool._process 里随 tick 返回值做的）。这里要显式 erase，
	# 否则 count() 仍把残留算进去，下一轮铺宝石会叠加计数。
	for g in _gems.active.duplicate():
		_gems._collect(g)
		_gems.active.erase(g)
	var n := 0
	for r in [R_NEAR, R_FAR]:
		for k in N_DIRS:
			var ang: float = TAU * float(k) / float(N_DIRS)
			_gems.spawn(_player.global_position + Vector2.from_angle(ang) * r, 1)
			n += 1
	return n

# ---------------------------------------------------------------- 阶段 A：对照（静止）
func _phase_control_no_move() -> void:
	await _prep()
	print("\n[功能·对照] 铜铃全图吸取 + 玩家静止")
	var n := _spawn_ring()
	_check(_gems.count() == n, "场上铺好 %d 颗宝石（近/远两档各 %d 颗）" % [n, n / 2])

	_game.pickups.spawn(_player.global_position, "magnet")   # 真实拾取通路 → vacuum_all
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < VACUUM_WINDOW * 1000.0 and _gems.count() > 0:
		await _wait(0.1)
	var t := (Time.get_ticks_msec() - t0) / 1000.0
	_check(_gems.count() == 0,
		"静止时铜铃在 %.2fs 内把全图宝石收进袋（剩 %d 颗）" % [t, _gems.count()])
	_check(t <= CLEAR_BOUND,
		"静止时清空耗时 %.2fs ≤ 上限 %.1fs（验证吸取机制本身正常）" % [t, CLEAR_BOUND])

# ---------------------------------------------------------------- 阶段 B：缺陷复现（移动）
func _phase_bug_move_floats() -> void:
	await _prep()
	print("\n[功能·缺陷复现] 铜铃全图吸取 + 玩家持续移动")
	var n := _spawn_ring()
	_check(_gems.count() == n, "场上铺好 %d 颗宝石（近/远两档各 %d 颗）" % [n, n / 2])

	# 拾取的同一时刻起，玩家持续移动（与 SmokeTest Step1 同一条输入通路）
	_player.set("_drag_active", true)
	_player.set("_drag_index", 0)
	_player.set("_drag_dir", PLAYER_MOVE_DIR)

	# 真实拾取「铜铃」→ vacuum_all（与玩家手动拾取同路径）
	_game.pickups.spawn(_player.global_position, "magnet")

	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < VACUUM_WINDOW * 1000.0 and _gems.count() > 0:
		await _wait(0.1)
	var t := (Time.get_ticks_msec() - t0) / 1000.0
	var remaining := _gems.count()

	# 诊断：残余宝石离玩家多远（漂浮位置）
	var max_d := 0.0
	for g in _gems.active:
		max_d = maxf(max_d, g.global_position.distance_to(_player.global_position))

	# 收尾：停手，避免污染
	_player.set("_drag_active", false)
	_player.set("_drag_dir", Vector2.ZERO)
	_player.set("_drag_index", -1)

	# 主断言：移动时全图也应在窗口内清空（缺陷 → remaining>0）
	_check(remaining == 0,
		"移动时铜铃在 %.2fs 内把全图宝石收进袋（剩 %d 颗 / 最远 %.0fpx）"
		% [t, remaining, max_d])
	# 诊断断言：即便最终清空，也不应"漂浮一段时间"（正确行为 ≤ CLEAR_BOUND）
	if remaining == 0:
		_check(t <= CLEAR_BOUND,
			"移动时清空耗时 %.2fs ≤ 上限 %.1fs（超出即'漂浮一段时间'）" % [t, CLEAR_BOUND])

# ---------------------------------------------------------------- 还原 + 报告
func _restore_and_report() -> void:
	# 把真实存档原样还回（debug_set 内含 save()，磁盘上也是原样）
	MetaSave.debug_set(int(_meta_backup.get("coins", 0)),
		_meta_backup.get("levels", {}) as Dictionary)
	print("\n========== 功能测试：铜铃全图吸取 + 移动漂浮 ==========")
	if _fails.is_empty():
		print("全部通过 OK（未复现缺陷：移动时全图宝石均在 %.1fs 内收进袋）" % CLEAR_BOUND)
	else:
		for f in _fails:
			print("失败: ", f)
	await _wait(0.2)
	get_tree().quit(0 if _fails.is_empty() else 1)
