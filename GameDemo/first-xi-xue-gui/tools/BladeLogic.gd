extends Node2D

# ============================================================================
# 剪纸（blade）弹射封顶探针（迭代01 D-2 / IT-06）：
#   场上 6 只 cup 直线排列（间距 < bounce_range），单发剪纸打头一只：
#     B-2  最多命中 4 只（首发 1 + 弹射 3），第 5、6 只不掉血
#     B-3  第 3、4 只受伤 < 第 2 只（bounce_falloff 衰减仍生效）
#     B-4  弹射耗尽后弹体从 _bullets 回收（不残留）
#     B-5  bounces_left 归零后旋转仍跟 vel.angle()，不突然自转
#          （防"直接递减 b.bounce"的错误实现 —— bounce 是旋转/衰减的类型判据）
#
# 不截图、纯逻辑断言，可无头跑：
#   godot --headless --path . res://tools/BladeLogic.tscn
# ============================================================================

const GAME := "res://scenes/Game.tscn"

var _game: GameScene
var _player: Player
var _weapons: WeaponManager
var _enemies: EnemyPool

var _ok := 0
var _bad: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 测的是判定逻辑，不是帧率：摘掉 60 上限，用 delta 累加计时（与 HaloLogic 同口径）
	Engine.max_fps = 0
	await get_tree().process_frame

	_game = (load(GAME) as PackedScene).instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame

	_player = _game.get_node("World/Player") as Player
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool

	# 停掉自动刷怪，并把玩家血量拉到无敌：本探针只关心剪纸，别被杂兵打断
	_game.set("_spawn_left", 1e9)
	_game.set("_elite_left", 1e9)
	GameManager.stats["max_hp"] = 1e9
	GameManager.stats["hp"] = 1e9
	_player.stats["hp"] = 1e9
	_player.stats["max_hp"] = 1e9

	print("\n===== 剪纸弹射封顶探针（迭代01 D-2 / IT-06）=====")
	await _case_bounce_cap()

	print("\n---------- 汇总 ----------")
	if _bad.is_empty():
		print("全部通过 OK（%d 条断言）" % _ok)
	else:
		for f in _bad:
			print("失败: ", f)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if _bad.is_empty() else 1)

# ---------------------------------------------------------------- 断言基座
func _check(ok: bool, msg: String) -> void:
	if ok:
		_ok += 1
		print("  ok   ", msg)
	else:
		_bad.append(msg)
		print("  FAIL ", msg)

func _pick(pos: Vector2, ename: String) -> Enemy:
	var e: Enemy = _enemies.spawn(pos, 99999.0, 0.0, 1, "cup", false)
	if e != null:
		e.name = "probe_" + ename
	return e

# ---------------------------------------------------------------- B-2 ~ B-5（共用一发的飞行链）
func _case_bounce_cap() -> void:
	print("\n[B] 6 只 cup 直线排列，单发剪纸打头一只")
	_enemies.clear_all()
	_weapons.clear_bullets()
	# 只手动触发**一发**，不把 blade 挂进 owned：
	# 挂了 owned 会被 _tick_cd 按 0.9s 冷却连发，第二发会在第一发弹射链没走完时进场，
	# 逐只伤害归因就被污染了。不挂 owned 时 weapon_level 缺省按 Lv1 算，
	# bounce=3 / bounce_falloff 等参数全部照常从 WeaponDB 读，与被测链路一致。
	for id in WeaponDB.ORDER:
		_weapons.owned.erase(id)
	await _frames(2)

	var p: Vector2 = _player.global_position
	var d: Dictionary = WeaponDB.def("blade")
	var bounce_r: float = float(d.get("bounce_range", 260.0))
	# 间距 120：小于 bounce_range（每跳都够得到下一只），
	# 大于"命中半径 + 弹体半径"的两倍（不会同帧咬到两只）。
	var gap: float = 120.0
	_check(gap < bounce_r, "布阵前提：间距 %.0f < bounce_range %.0f" % [gap, bounce_r])
	var line: Array[Enemy] = []
	var spawn_ok := true
	for i in 6:
		var e: Enemy = _pick(p + Vector2(200.0 + gap * float(i), 0.0), "blade%d" % i)
		if e == null:
			spawn_ok = false
		else:
			line.append(e)
	_check(spawn_ok and line.size() == 6, "6 只 cup 已生成（%d）" % line.size())
	if line.size() < 6:
		return
	await _frames(2)
	var hp0: Array[float] = []
	for e in line:
		hp0.append(e.hp)

	# 走正式开火通道打一发（含 bounces_left 初始化）
	_weapons.fire_projectile(_player, "blade")
	_check(_weapons._bullets.size() == 1, "单发已生成（_bullets = %d）" % _weapons._bullets.size())
	if _weapons._bullets.is_empty():
		return
	var shot: WeaponManager.Bullet = _weapons._bullets[0]
	_check(shot.bounces_left == shot.bounce and shot.bounce == int(d.get("bounce", 3)),
		"出膛时 bounces_left(%d) == bounce(%d)（类型判据与计次分离）" % [shot.bounces_left, shot.bounce])

	# 跑 2.0s：首段约 0.5s + 3 跳各约 0.32s + 余量。逐帧采样旋转偏差（B-5）。
	var max_dev := 0.0
	var t := 0.0
	while t < 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		for b in _weapons._bullets:
			if b.id == "blade" and b.vel.length() > 1.0 and b.node != null:
				var dev: float = absf(wrapf(b.node.rotation - b.vel.angle(), -PI, PI))
				max_dev = maxf(max_dev, dev)

	# ---- B-2：命中数封顶 ----
	var hurt: Array[float] = []
	for i in 6:
		hurt.append(hp0[i] - line[i].hp)
	print("  逐只受伤：%s" % str(_fmt(hurt)))
	_check(hurt[0] > 0.01 and hurt[1] > 0.01 and hurt[2] > 0.01 and hurt[3] > 0.01,
		"B-2a：单发命中前 4 只（首发 1 + 弹射 3）")
	_check(hurt[4] < 0.01 and hurt[5] < 0.01,
		"B-2b：第 5、6 只不掉血（%.2f / %.2f，弹射 3 次封顶）" % [hurt[4], hurt[5]])
	# ---- B-3：衰减仍生效 ----
	_check(hurt[2] < hurt[1] - 0.01 and hurt[3] < hurt[1] - 0.01,
		"B-3：第 3、4 只受伤（%.2f / %.2f）< 第 2 只（%.2f），bounce_falloff 仍生效" % [hurt[2], hurt[3], hurt[1]])
	# ---- B-4：弹体回收 ----
	_check(not _weapons._bullets.has(shot), "B-4：弹射耗尽后弹体已从 _bullets 回收（剩 %d 发）" % _weapons._bullets.size())
	# ---- B-5：旋转不突变 ----
	_check(max_dev < 0.35,
		"B-5：全程 |rotation - vel.angle()| 最大 %.3f rad < 0.35（归零后无自转突变）" % max_dev)

# ---------------------------------------------------------------- 小工具
func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

func _fmt(a: Array[float]) -> Array[String]:
	var out: Array[String] = []
	for v in a:
		out.append("%.2f" % v)
	return out
