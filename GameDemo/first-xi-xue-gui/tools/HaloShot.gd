extends Node2D

# ============================================================================
# 迭代04 收尾（D-14）：花灯视觉圈与角色同心 —— 受击前 / 受击后两张截图 + 四向边距读数
# ----------------------------------------------------------------------------
# 【这条探针守的是用户报的那个现象】开脸花灯曾经把整个环绕角色 8 方位轮转
# （偏移 0.40R，迭代03 M-03）。玩家看到的是"环跑到右边去了，人还站在圈外，
# 但贴身的怪照样能打到人"。M-03 已撤回：判定圆心 / 视觉圆心 / 角色恒为同一点。
#
# 量的是"玩家身体中心 → 光环外沿"的距离，四向（左/右/上/下）都必须 ≈ halo_radius()。
# 期望值从 `halo_radius()` 取，不写死 190.4 —— 被动 / 精炼一变，探针跟着变。
#
# ⚠️ 不能加 --headless：要读真实渲染出来的像素。
#     godot --path . res://tools/HaloShot.tscn
#
# 为压掉干扰，只留玩家 + 光环：背景 / 地面 / 道具 / HUD / 掉落全部隐藏。
# 阈值：饱和度 s >= 0.45 且亮度 v >= 0.35 记为灯笼本体（暖雾底光会被排除）。
# ============================================================================

const GAME := "res://scenes/Game.tscn"
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
	for child in _game.get_node("World").get_children():
		if child != _player and child is CanvasItem:
			(child as CanvasItem).visible = false
	GameManager.started = true
	_weapons.set_process(false)   # 关自动开火：只手动脉冲

	var base: Vector2 = Vector2(0.0, -Player.ART_FOOT_OFFSET)

	await _equip(8, true)
	await _frames(4)
	var r: float = _weapons.halo_radius()
	print("\n===== 花灯同心视觉判读（期望半径 %.1f，容差 %.0f%%）=====" % [r, TOL * 100.0])

	# ① 受击前：四向边距都 ≈ R
	await _shot("halo_before", "受击前", r)

	# ② 受击瞬间：闪白 / 抖屏 / 击退全都发生，环必须仍以角色为圆心
	_player.take_damage(5.0, &"probe")
	await _frames(8)
	await _shot("halo_after_hit", "受击后（反馈进行中）", r)

	# ③ 结构断言：GarlicRing 节点局部位置恒为 base（视觉四层都以它原点为圆心）
	_check(_player.garlic_ring.position.is_equal_approx(base),
		"受击后 GarlicRing.position 仍是 %s（实测 %s）" % [str(base), str(_player.garlic_ring.position)])
	# ④ 结构断言：判定圆心与角色同点（fire_halo 每次都会先复位）
	_weapons.fire_halo(_player)
	await _frames(2)
	_check(_player.garlic_ring.position.is_equal_approx(base),
		"脉冲后 GarlicRing.position 仍是 %s（实测 %s）" % [str(base), str(_player.garlic_ring.position)])

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

func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
	else:
		_bad.append(msg)
	print("  %s %s" % ["ok  " if cond else "FAIL", msg])

# ---------------------------------------------------------------- 截图 + 量尺
func _shot(tag: String, title: String, expect_r: float) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://shots/%s.png" % tag)
	var c: Vector2 = _player.get_global_transform_with_canvas() * Vector2(0.0, -Player.ART_FOOT_OFFSET)
	var sx: float = float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var cx: int = int(round(c.x * sx))
	var cy: int = int(round(c.y * sx))
	print("\n[%s] 截图 res://shots/%s.png  body=(%d,%d)  scale=%.3f" % [title, tag, cx, cy, sx])
	# 四向各读一条边距：左 / 右沿水平轴，上 / 下沿垂直轴
	_edge(img, cx, cy, Vector2(-1, 0), sx, "左", expect_r)
	_edge(img, cx, cy, Vector2(1, 0), sx, "右", expect_r)
	_edge(img, cx, cy, Vector2(0, -1), sx, "上", expect_r)
	_edge(img, cx, cy, Vector2(0, 1), sx, "下", expect_r)

func _edge(img: Image, cx: int, cy: int, dir: Vector2, sx: float, label: String, expect_r: float) -> void:
	var hit: int = _scan(img, cx, cy, dir)
	var d: float = float(hit) / sx
	var ok: bool = absf(d - expect_r) / expect_r <= TOL
	if ok:
		_ok += 1
	else:
		_bad.append("%s %s 边距 %.1f / 期望 %.1f" % [label, label, d, expect_r])
	print("  %s %s 边距 %.1f / 期望 %.1f（偏差 %.1f%%）"
		% ["ok  " if ok else "FAIL", label, d, expect_r, absf(d - expect_r) / expect_r * 100.0])

## 从中心沿 dir 走到最后一颗"灯笼本体"像素，返回距离（像素，未换算）。
## 灯笼是离散贴图，轴线可能正好落在两只之间，所以在垂直方向 ±18px 的带内取最外那颗。
func _scan(img: Image, cx: int, cy: int, dir: Vector2) -> int:
	var limit: int = 330
	var start: int = 70   # 跳过玩家自己的像素
	var best: int = 0
	var horizontal: bool = absf(dir.x) > 0.5
	for band in range(-18, 19):
		var ox: int = cx + (band if not horizontal else 0)
		var oy: int = cy + (band if horizontal else 0)
		if oy < 0 or oy >= img.get_height() or ox < 0 or ox >= img.get_width():
			continue
		var lit_to: int = -1
		for i in range(start, limit):
			var px_x: int = cx + int(dir.x) * i + (band if not horizontal else 0)
			var px_y: int = cy + int(dir.y) * i + (band if horizontal else 0)
			if px_x < 0 or px_x >= img.get_width() or px_y < 0 or px_y >= img.get_height():
				break
			var px: Color = img.get_pixel(px_x, px_y)
			# 只认灯笼本体（高饱和 + 够亮）；低饱和的暖雾底光会铺到 ~1.6R，不能当圈边。
			if px.s >= 0.45 and px.v >= 0.35:
				lit_to = i
		if lit_to > best:
			best = lit_to
	return best
