extends Node

# ============================================================================
# v6 觉醒「看一眼」交付图 —— 真实入口截屏，不参与断言
# ----------------------------------------------------------------------------
# 用法：godot --path . res://tools/V6Look.tscn      ← **不能加 --headless**
#
# 为什么还要单独一个工具（V6Fx 已经数过像素了）：
#   像素断言只能证明"有光、没烧白、贴着边"，证明不了"在实战画面里读得出"。
#   星星点点的火星在纯黑画布上很清楚，铺到深蓝地面 + 一堆纸片怪上可能完全糊掉。
#   三张图分别对应 v6 三个最容易翻车的点：
#     A 花灯 Lv8：走马灯 + 加宽的边带，会不会把玩家自己盖掉
#     B 打铁花炸开：火星团在怪堆里还剩多少可读性（半径只有 76）
#     C 年画落地：雕版印记从天而降的"盖下去"有没有发生
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"

var _game: GameScene
var _player: Player
var _weapons: WeaponManager
var _enemies: EnemyPool


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	await get_tree().process_frame
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_node("World/Player") as Player
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	_game.set_process(false)
	_enemies.clear_all()
	GameManager.stats = Stats.make_base()
	_player.stats = GameManager.stats
	_weapons.stats = GameManager.stats

	await _shot_halo_awaken()
	await _shot_molten()
	await _shot_print()
	await _shot_hud()

	print("\n[v6 look] 完成")
	get_tree().quit()


func _ring(n: int, radius: float) -> void:
	for i in n:
		var a: float = TAU * float(i) / float(n)
		_enemies.spawn(_player.global_position + Vector2.from_angle(a) * radius,
			999999.0, 0.0, 1, "cup", false, 0.0, false, false)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://v6_look_%s.png" % tag)
	print("  SHOT %s" % tag)


# ---------------------------------------------------------------- A 花灯 Lv8
func _shot_halo_awaken() -> void:
	print("\n[A] 花灯 Lv8 走马灯 + 加宽边带")
	_enemies.clear_all()
	_weapons.owned = {"halo": WeaponDB.MAX_LEVEL}
	_weapons.evolved = {}
	# 一圈杂兵站在判定半径 0.8 处：既能看出圈有多大，也能看出内部还在烧
	_ring(12, _weapons.halo_radius() * 0.8)
	await get_tree().create_timer(0.55).timeout
	await _shot("halo8")

	# 对照：Lv7（没有走马灯），用来证明"满级那一刻真的变了"
	_weapons.owned = {"halo": WeaponDB.MAX_LEVEL - 1}
	await get_tree().create_timer(0.4).timeout
	await _shot("halo7")


# ---------------------------------------------------------------- B 打铁花
func _shot_molten() -> void:
	print("\n[B] 打铁花：铁水撞散")
	_enemies.clear_all()
	await get_tree().create_timer(0.45).timeout   # 等上一用例的"灯晕一跳"自然消亡
	_weapons.owned = {"extinguisher": 5}
	# 一簇杂兵挤在落点上（铁水团撞第一只就碎）
	var at: Vector2 = _player.global_position + Vector2(0.0, -140.0)
	for i in 9:
		var a: float = TAU * float(i) / 9.0
		_enemies.spawn(at + Vector2.from_angle(a) * (18.0 + 12.0 * float(i % 3)),
			999999.0, 0.0, 1, "cup", false, 0.0, false, false)
	await get_tree().process_frame
	# 直接调碎裂入口而不是"发射→等它飞过去"：
	# 铁水团速度 300px/s、cd 1.4s，靠等时间抓帧会拍到还在飞的弹体
	# （第一版就是这样，图里只有一堆伤害数字，没有火星）。
	var b := WeaponManager.Bullet.new()
	b.id = "extinguisher"
	b.dmg = 40.0
	b.pos = at
	b.hits_done = 1
	_weapons._shatter(b, _enemies.active[0])
	# 0.10s：火星刚推开一半，是"散开"最可读的一帧
	await get_tree().create_timer(0.10).timeout

	await _shot("molten")


# ---------------------------------------------------------------- C 年画落地
func _shot_print() -> void:
	print("\n[C] 年画：雕版从天而降")
	_enemies.clear_all()
	await get_tree().create_timer(0.45).timeout
	_weapons.owned = {"print": 6}
	for i in 6:
		_enemies.spawn(_player.global_position + Vector2(0.0, -150.0)
			+ Vector2.from_angle(TAU * float(i) / 6.0) * 34.0,
			999999.0, 0.0, 1, "cup", false, 0.0, false, false)
	await get_tree().process_frame
	_weapons.fire_print(_player)
	# 0.30s：雕版刚落到一半（delay 0.45），"从天而降"最好读的一帧
	await get_tree().create_timer(0.30).timeout
	await _shot("seal")


# ---------------------------------------------------------------- D HUD 角标
func _shot_hud() -> void:
	print("\n[D] HUD 槽位：觉醒徽记只在 Lv8")
	_enemies.clear_all()
	await get_tree().create_timer(0.45).timeout
	# 三格并排：Lv7（无徽记）/ Lv8（有徽记）/ 进化（有徽记 + 金边）
	_weapons.owned = {"whip": 7, "gong": WeaponDB.MAX_LEVEL, "extinguisher": 8}
	_weapons.evolved = {"extinguisher": "evolve_extinguisher"}
	await get_tree().create_timer(0.25).timeout
	await _shot("hud")
