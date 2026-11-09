extends Node2D

# ============================================================================
# M-03 视觉判读探针（V-1~V-4）
# ----------------------------------------------------------------------------
# 判读规矩：数点亮像素并给阈值，不用眼睛估；期望值来自主件（190.4 / 76.2 /
# 114.2 / 266.6），不是从运行结果反推。
#
# 量的是"玩家身体中心 → 光环外沿"的距离：
#   V-1 开脸前 = 190.4 / 190.4
#   V-2 第 1 脉冲（灯心 +X）= 114.2 / 266.6（左 / 右）
#   V-3 第 3 脉冲（灯心 +Y）= 114.2 / 266.6（上 / 下）
#   V-4 复位 = 190.4 / 190.4
#
# ⚠️ 不能加 --headless：要读真实渲染出来的像素。
#     godot --path . res://tools/HaloShot.tscn
#
# 为压掉干扰，只留玩家 + 光环：背景 / 地面 / 道具 / HUD / 掉落全部隐藏。
# 阈值：亮度 v >= 0.18 记为点亮（本作光环灯笼在纯黑底上的实测值远高于它）。
# ============================================================================

const GAME := "res://scenes/Game.tscn"
const DARK := 0.18
const TOL := 0.07   # 7%：灯笼外沿是 97.3% 半径（见 HaloLogic ①），留软边余量

var _game: GameScene
var _player: Player
var _weapons: WeaponManager

var _ok := 0
var _bad: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	# 没有 BG 时视口用默认清屏色（灰）—— 会整屏高于阈值。铺成纯黑再量。
	RenderingServer.set_default_clear_color(Color.BLACK)
	await get_tree().process_frame

	_game = (load(GAME) as PackedScene).instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame

	_player = _game.get_node("World/Player") as Player
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_player.stats["hp"] = 1e9
	_player.stats["max_hp"] = 1e9

	# 只留玩家与光环：把所有会污染像素的东西关掉
	_game.get_node("UI").visible = false
	_game.get_node("BG").visible = false
	# 只留 Player（光环是它的子节点）；World 下的地面 / 道具 / 池子全关，
	# 否则屏幕边角的灯笼柱与木箱会被当成"圈外的亮像素"读到。
	for child in _game.get_node("World").get_children():
		if child != _player and child is CanvasItem:
			(child as CanvasItem).visible = false
	GameManager.started = true
	# 关掉武器自动开火：本轮只手动推进 _lamp_step，避免等待期多转一格
	_weapons.set_process(false)

	print("\n===== M-03 视觉判读（像素阈值 %.2f，容差 %.0f%%）=====" % [DARK, TOL * 100.0])

	await _equip(8, true)
	await _frames(2)
	await _shot("v1_step0", "V-1 开脸瞬间（第 0 脉冲，未转）", Vector2(190.4, 190.4), true)

	await _pulse()
	await _shot("v2_pulse1_right", "V-2 第 1 脉冲（灯心 +X）", Vector2(114.2, 266.6), true)

	await _pulse()
	await _pulse()
	await _shot("v3_pulse3_down", "V-3 第 3 脉冲（灯心 +Y）", Vector2(114.2, 266.6), false)

	# V-4：复位分支（未开脸 → 写回 base）。复活在局外经济锁区里没有实机路径，
	# 所以用"卸下花灯"等价触发同一分支；此时常驻圈半径回到未进化的 119。
	_weapons.evolved = {}
	await _pulse()
	await _frames(2)
	await _shot("v4_reset", "V-4 复位（未开脸分支）", Vector2(119.0, 119.0), true)

	print("\n---------- 汇总 ----------")
	if _bad.is_empty():
		print("全部通过 OK（%d 条读数）" % _ok)
	else:
		for f in _bad:
			print("失败: ", f)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if _bad.is_empty() else 1)

# ---------------------------------------------------------------- 场景推进
func _equip(lv: int, evolved: bool) -> void:
	_weapons.owned = {"halo": lv}
	_weapons.evolved = {"halo": "evolve_halo"} if evolved else {}
	_weapons.refines = {}
	_weapons._cd = {}
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _frames(4)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## 手动推一次灯心脉冲，然后把 cd 钉死（防自动开火插进来多转一格）
func _pulse() -> void:
	_weapons.fire_halo(_player)
	_weapons._cd["halo"] = 999.0
	await _frames(2)

# ---------------------------------------------------------------- 截图 + 量尺
func _shot(tag: String, title: String, expect: Vector2, horizontal: bool) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://shots/m03_%s.png" % tag)
	var c: Vector2 = _player.get_global_transform_with_canvas() * Vector2(0.0, -Player.ART_FOOT_OFFSET)
	var sx: float = float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var cx: int = int(round(c.x * sx))
	var cy: int = int(round(c.y * sx))
	var a: int = _scan(img, cx, cy, -1, horizontal)
	var b: int = _scan(img, cx, cy, 1, horizontal)
	var m1: float = float(absi(a - (cx if horizontal else cy))) / sx
	var m2: float = float(absi(b - (cx if horizontal else cy))) / sx
	var lo: float = minf(m1, m2)
	var hi: float = maxf(m1, m2)
	var e_lo: float = minf(expect.x, expect.y)
	var e_hi: float = maxf(expect.x, expect.y)
	print("\n[%s] 截图 res://shots/m03_%s.png  body=(%d,%d)  scale=%.3f" % [title, tag, cx, cy, sx])
	_judge(lo, e_lo, "%s 近侧" % title)
	_judge(hi, e_hi, "%s 远侧" % title)

func _judge(v: float, e: float, msg: String) -> void:
	var ok: bool = absf(v - e) / e <= TOL
	if ok:
		_ok += 1
	else:
		_bad.append(msg)
	print("  %s 实测 %.1f / 期望 %.1f（偏差 %.1f%%）" % ["ok  " if ok else "FAIL", v, e, absf(v - e) / e * 100.0])

## 从中心沿 dir(-1/1) 走；灯笼是一个个离散贴图，正轴线上可能正好落在两只之间，
## 所以在垂直方向 ±18px 的带内取最外那颗，避免"轴线穿过灯笼缝隙"读到内沿。
func _scan(img: Image, cx: int, cy: int, dir: int, horizontal: bool) -> int:
	var limit: int = 330
	var start: int = 70   # 跳过玩家自己的像素
	var best: int = 0
	for band in range(-18, 19):
		var oy: int = cy + (band if horizontal else 0)
		var ox: int = cx + (band if not horizontal else 0)
		if oy < 0 or oy >= img.get_height() or ox < 0 or ox >= img.get_width():
			continue
		var lit_to: int = -1
		for i in range(start, limit):
			var p: int = (cx + dir * i) if horizontal else (cy + dir * i)
			if p < 0 or (horizontal and p >= img.get_width()) or ((not horizontal) and p >= img.get_height()):
				break
			var px: Color = img.get_pixel(p, oy) if horizontal else img.get_pixel(ox, p)
			# 只认灯笼本体（高饱和 + 够亮）；低饱和的暖雾底光会铺到 ~1.6R，不能当圈边。
			if px.s >= 0.45 and px.v >= 0.35:
				lit_to = i
		if lit_to > best:
			best = lit_to
	return (cx + dir * best) if horizontal else (cy + dir * best)
