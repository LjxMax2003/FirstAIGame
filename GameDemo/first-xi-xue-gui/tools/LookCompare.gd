extends Node2D

# ============================================================================
# 铜锣 / 花灯 视觉对照探针（一次性诊断工具，不是回归套件）
# ----------------------------------------------------------------------------
# 目的：回答"玩家分不分得出这两个技能"。
# 三个状态各拍一帧，同一批敌人、同一位置、同一帧率：
#   A 只开花灯（常驻环形领域）
#   B 只敲铜锣（一次性爆发）
#   C 两个同时（真实战斗里最常见的情况）
#
# ⚠️ 不能加 --headless：要真实渲染才能截到画面。
#    godot --path . res://tools/LookCompare.tscn
# ============================================================================

const GAME := "res://scenes/Game.tscn"
const DIR := "user://look_"

var _game: GameScene
var _player: Player
var _weapons: WeaponManager
var _enemies: EnemyPool

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 摘掉 60 帧上限：本工具要精确控制"第几帧"截图
	Engine.max_fps = 0
	await get_tree().process_frame

	_game = (load(GAME) as PackedScene).instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame

	_player = _game.get_node("World/Player") as Player
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool

	# 停掉自动刷怪与玩家掉血，只留我们摆的东西
	_game.set("_spawn_left", 1e9)
	_game.set("_elite_left", 1e9)
	GameManager.stats["max_hp"] = 1e9
	GameManager.stats["hp"] = 1e9
	_player.stats["hp"] = 1e9
	_player.stats["max_hp"] = 1e9

	# 只留这两把武器，别的全下掉（不然弧光/糖丝/墨线会把对照糊掉）
	for id in WeaponDB.ORDER:
		if id != "halo" and id != "gong":
			_weapons.owned.erase(id)
	_weapons.owned["halo"] = 8
	_weapons.owned["gong"] = 8

	var base: Vector2 = _player.global_position
	var rad: float = _weapons.halo_radius()
	print("[对照] halo_radius = %.1f  gong_radius = %.1f" % [rad, _weapons.gong_radius()])

	# 一圈炮灰：用来标定范围（也能看出环到底扫到哪）
	for i in 8:
		var ang: float = TAU * float(i) / 8.0 + 0.35
		var e: Enemy = _enemies.spawn(base + Vector2.from_angle(ang) * rad * 0.78,
			99999.0, 0.0, 1, "cup", false)
		e.visible = true

	# 武器每帧都开，但用 _cd 压住，让它们不会自己乱放
	_weapons.set_process(false)

	await _shot("A_halo", "只开花灯")
	await _shot("B_gong", "只敲铜锣")
	await _shot("C_both", "两个同时")

	print("[对照] 完成，三张图都存到 ", ProjectSettings.globalize_path("user://"))
	get_tree().quit()

func _gong_radius() -> float:
	var d: Dictionary = WeaponDB.def("gong")
	var lv: int = 8
	return (float(d.get("radius", 150.0)) + float(d.get("radius_per_level", 10.0)) * float(lv - 1)) \
		* _player.stats_value("area")

# ---------------------------------------------------------------- 三个状态

func _shot(tag: String, title: String) -> void:
	# 花灯只能靠**摘掉武器**来关：改 garlic_ring.visible 没用，
	# Player 每帧按 has_weapon("halo") 重新设一次，赋值会被静默覆盖。
	if tag == "B_gong":
		_weapons.owned.erase("halo")
		if _player.garlic_ring != null:
			_player.garlic_ring.visible = false
	else:
		_weapons.owned["halo"] = 8
	await _frames(6)

	if tag == "B_gong" or tag == "C_both":
		# 手动敲一次。fire_gong 会自己扣 cd，不影响下次
		_weapons.fire_gong(_player)
		# 等 0.16s = 冲击波（0.30s）的 progress 0.53，环正好扩到范围中段，
		# 也是最像"正在响"的一帧。
		# ⚠️ 不能用 _frames(n) 数帧：max_fps=0 + vsync 下每帧只有 6ms，
		#    9 帧才 54ms，环还没长出来就被锣面盖住了（这个坑实测踩过）。
		await get_tree().create_timer(0.16).timeout
	else:
		# 花灯的波纹是 shader TIME 驱动的，等够 0.35s 让至少一圈推出去
		await get_tree().create_timer(0.35).timeout

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = DIR + tag + ".png"
		img.save_png(path)
		print("[截图] %s → %s" % [title, ProjectSettings.globalize_path(path)])
	return

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
