extends Node

# ============================================================================
# 技能向 FX 落地验收 —— 调**真实的 fire_* / beat() / HUD 重建**，再断言材质
# ----------------------------------------------------------------------------
# 与另两个工具的分工（别混）：
#   SkillSheet   证明"5 个 shader 能编译、参数对、画面不是黑的"——挂孤立节点。
#   SkillInGame  证明"接进游戏了"——出手那一帧真的挂了 slash_arc / cast_burst，
#                弹道真的挂了 projectile_trail，武器槽真的换成了 skill_rank_rim。
#
# 为什么必须有这一层：本包第一次交付时 7 个 shader 全绿、游戏里一个都看不见，
# 原因就是"调用点数为 0"，而孤立渲染的对照图完全看不出来。
#
# 用法：godot --path . res://tools/SkillInGame.tscn
#   产出 user://skill_*.png，控制台打印 PASS/FAIL 断言。
# ============================================================================

const ZOOM_CLOSE := 1.35      # 贴判定框的椭圆要看清边界，拉近看
const ZOOM_HUD := 1.0
const ZOOM_BULLET := 3.0      # 弹体源图只有 32px，看拖尾必须贴近看
const WARMUP := 2.0

var game: GameScene
var _bad: Array[String] = []
var _weapons: WeaponManager = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().create_timer(WARMUP).timeout
	game = $Game
	_weapons = game.get_node("World/Weapons") as WeaponManager
	game.camera.zoom = Vector2.ONE * ZOOM_CLOSE
	print("\n===== 技能向 FX 落地验收（真实代码路径）=====")

	await _case_whip()
	await _case_projectile()
	await _case_projectile_blade()
	await _case_pool()
	await _case_halo()
	await _case_slots()

	print("\n---------- 断言 ----------")
	if _bad.is_empty():
		print("  ok   5 个技能向效果全部走真实路径生效")
	else:
		for b in _bad:
			print("  FAIL %s" % b)
	print("\n==== 技能向 FX 落地验收：%s ====\n" % ("PASS" if _bad.is_empty() else "FAIL"))
	get_tree().quit(0 if _bad.is_empty() else 1)


# --- 用例 -------------------------------------------------------------------

## 横扫：弧光遮罩 + 冲击环贴判定框
func _case_whip() -> void:
	print("\n[傩面·师刀] 弧光扫出 + 椭圆冲击环")
	# 仓库留空 → _process 里的 _tick_cd 没有可 tick 的武器，不会自动开火。
	# 这样每个用例拍到的都是"我这行调用产生的唯一一个特效"，不会被自动开火污染。
	_weapons.owned.clear()
	var p: Vector2 = game.player.global_position
	game.enemies.spawn(p + Vector2(150.0, 0.0), 9999.0, 0.0, 5, "red", false)

	_weapons.fire_whip(game.player)
	_lock("whip")
	await get_tree().process_frame

	var arc: Sprite2D = _find_fx(Art.WHIP_ARC)
	_check(arc != null, "fire_whip() 产出了弧光精灵")
	if arc != null:
		_check(_shader_of(arc).ends_with("slash_arc.gdshader"),
			"弧光应挂 slash_arc，实际 %s" % _shader_of(arc))
		var m := arc.material as ShaderMaterial
		if m != null:
			_check(float(m.get_shader_parameter("progress")) <= 0.35,
				"弧光起手时 progress 应接近 0（扫出还没发生），实际 %.2f"
				% float(m.get_shader_parameter("progress")))

	var ring: ColorRect = _find_burst()
	_check(ring != null, "fire_whip() 产出了冲击环节点")
	if ring != null:
		_check(_shader_of(ring).ends_with("cast_burst.gdshader"),
			"冲击环应挂 cast_burst，实际 %s" % _shader_of(ring))
		var m2 := ring.material as ShaderMaterial
		if m2 != null:
			# 期望值必须**从武器表独立算**，不能拿节点自身尺寸反推 ——
			# 第一版就是"节点 × 0.9 和节点比"，恒成立，把 3.4 倍的尺寸错误放过去了。
			var wd: Dictionary = WeaponDB.def("whip")
			var want_long: float = float(wd["length"]) * 2.0      # lv1、无被动：横扫跨度
			var want_short: float = float(wd["width"])           # 判定宽度
			var sq: Vector2 = m2.get_shader_parameter("squash")
			_check(absf(sq.y - want_short / want_long) < 0.02,
				"冲击环扁率应贴矩形判定（短/长 %.3f，期望 %.3f）"
				% [sq.y, want_short / want_long])
			# shader 里环半径 = 0.9 × 节点边（spread 默认 0.9）
			var got_long: float = ring.size.x * 0.9
			_check(absf(got_long - want_long) < want_long * 0.06,
				"椭圆长轴 %.0fpx 对齐横扫跨度 %.0fpx" % [got_long, want_long])
			_check(ring.size.x * 0.9 >= got_long * 0.99,
				"椭圆落在节点内（节点 %.0fpx）—— 否则长轴两端会被裁平" % ring.size.x)
			_check(int(m2.get_shader_parameter("rays")) == 0,
				"横扫冲击环是纯环、不带径向光条（rays=%d）" % int(m2.get_shader_parameter("rays")))
	# 0.03s 时进度约 0.45（TRANS_QUAD + EASE_OUT 起手很快），是"环正在扩散"的代表帧
	await get_tree().create_timer(0.03).timeout
	await _shot("whip_slash")
	await get_tree().create_timer(0.06).timeout
	await _shot("whip_slash_late")
	await get_tree().create_timer(0.05).timeout


## 糖画：弹道拖尾 + 弹体指向飞行方向（原来在自转）
func _case_projectile() -> void:
	print("\n[糖画] 弹道拖尾")
	_weapons.owned.clear()
	var p: Vector2 = game.player.global_position
	game.enemies.spawn(p + Vector2(110.0, 0.0), 9999.0, 0.0, 5, "red", false)
	await get_tree().process_frame
	# 糖丝本体的源图只有 32x16，1.35 倍镜下不足 50px，"有没有拖尾"根本分辨不出来。
	# 这里拉到 3 倍近景，并且把目标放近，让弹体留在画面里。
	game.camera.zoom = Vector2.ONE * ZOOM_BULLET
	_weapons.fire_projectile(game.player, "glowstick")
	_lock("glowstick")
	await get_tree().process_frame

	var b: WeaponManager.Bullet = _find_bullet("glowstick")
	_check(b != null, "fire_projectile(\"glowstick\") 产出了弹道")
	if b != null:
		_check(_shader_of(b.node).ends_with("projectile_trail.gdshader"),
			"糖丝应挂 projectile_trail，实际 %s" % _shader_of(b.node))
		var m := b.node.material as ShaderMaterial
		if m != null:
			_check(int(m.get_shader_parameter("axis")) == 0,
				"糖丝拖尾朝 +X（axis=%d）" % int(m.get_shader_parameter("axis")))
		var rot0: float = b.node.rotation
		await get_tree().create_timer(0.12).timeout
		_check(absf(b.node.rotation - rot0) < 0.02,
			"挂了拖尾的弹体不能自转（0.12s 内 rotation %.3f → %.3f）"
			% [rot0, b.node.rotation])
	await _shot("glowstick_trail")
	var lit: float = await _trail_gain(b.node)
	_check(lit > 400.0, "糖丝拖尾实际点亮 %.0f 个像素（<400 就等于看不见）" % lit)
	game.camera.zoom = Vector2.ONE * ZOOM_CLOSE


## 剪纸：弹射弹道也要拖尾（它的 rotation 每帧对齐速度）
func _case_projectile_blade() -> void:
	print("\n[剪纸] 弹射拖尾")
	_weapons.owned.clear()
	var p: Vector2 = game.player.global_position
	game.enemies.spawn(p + Vector2(-110.0, 30.0), 9999.0, 0.0, 5, "red", false)
	await get_tree().process_frame
	game.camera.zoom = Vector2.ONE * ZOOM_BULLET
	_weapons.fire_projectile(game.player, "blade")
	_lock("blade")
	await get_tree().process_frame
	var b: WeaponManager.Bullet = _find_bullet("blade")
	_check(b != null, "fire_projectile(\"blade\") 产出了弹道")
	if b != null:
		_check(_shader_of(b.node).ends_with("projectile_trail.gdshader"),
			"纸鹊应挂 projectile_trail，实际 %s" % _shader_of(b.node))
	await get_tree().create_timer(0.05).timeout
	await _shot("blade_trail")
	var lit2: float = await _trail_gain(b.node)
	_check(lit2 > 400.0, "纸鹊拖尾实际点亮 %.0f 个像素" % lit2)
	game.camera.zoom = Vector2.ONE * ZOOM_CLOSE


## 池化精灵不能带着上一轮的材质出来
func _case_pool() -> void:
	print("\n[池] 复用精灵必须剥净材质")
	# ① 弹道回收：拖尾材质必须还回去，否则池里 128 个精灵就是 128 个独立材质（永久掉合批）
	var b: WeaponManager.Bullet = _find_bullet("blade")
	if b != null:
		var node: Sprite2D = b.node
		_weapons._release_bullet(node)
		_check(node.material == null, "回收弹道后材质被还原（实际 %s）" % _shader_of(node))
	# ② 特效池混用：弧光精灵挂过 slash 遮罩后，如果直接拿去当火花，
	#    progress 停在半路会把火花遮成"完全不可见"，而且不报错。
	var arc: Sprite2D = _weapons._take_fx(Art.WHIP_ARC)
	ShaderFX.slash(arc, 0.12, false, false)
	_check(arc.material != null, "弧光精灵挂上了遮罩")
	_weapons._push_fx(arc, 0.01, 1.0, 1.0)
	await get_tree().create_timer(0.05).timeout
	var spark: Sprite2D = _weapons._take_fx(Art.FX_SPARK)
	_check(spark.material == null,
		"复用出来的火花精灵不带旧遮罩（实际 %s）" % _shader_of(spark))


## 花灯：光环能量场 + 命中一跳
func _case_halo() -> void:
	print("\n[花灯] 领域能量场 + 命中跳")
	game.camera.zoom = Vector2.ONE * ZOOM_HUD
	_weapons.owned.clear()
	_weapons.owned["halo"] = 3
	_weapons._cd["halo"] = 999.0
	# 这个用例要看清"场"，不能让受伤红边把整屏染红（敌人就刷在脚下）
	game.player.set("invuln_left", 999.0)
	game.player.garlic_ring.visible = true
	game.player.garlic_ring.set_radius(_weapons.halo_radius())
	await get_tree().process_frame

	var ring: GarlicRing = game.player.garlic_ring
	var field: ColorRect = _find_field(ring)
	_check(field != null, "光环背后有 aura_field 能量场节点")
	if field != null:
		_check(_shader_of(field).ends_with("aura_field.gdshader"),
			"能量场应挂 aura_field，实际 %s" % _shader_of(field))
		var r: float = _weapons.halo_radius()
		_check(absf(field.size.x - r * 2.0) < 1.5,
			"能量场尺寸跟判定半径一致（%.0f vs 判定直径 %.0f）" % [field.size.x, r * 2.0])
		_check(ring.get_child(0) == field,
			"能量场排在子节点首位（在光圈之下，否则会糊掉判定边界）")
	# 命中一跳：只在该次光环真的烧到东西时才放
	var p: Vector2 = game.player.global_position
	game.enemies.spawn(p + Vector2(30.0, 0.0), 9999.0, 0.0, 5, "red", false)
	await get_tree().process_frame
	_weapons.fire_halo(game.player)
	_lock("halo")
	var m: ShaderMaterial = null
	if field != null:
		m = field.material as ShaderMaterial
	if m != null:
		_check(float(m.get_shader_parameter("beat")) > 0.8,
			"命中后 beat 被推到 1（实际 %.2f）" % float(m.get_shader_parameter("beat")))
	await get_tree().create_timer(0.08).timeout
	await _shot("halo_field")


## 武器槽：等级外框（含"框宽必须按贴图分辨率换算"）
func _case_slots() -> void:
	print("\n[武器槽] 等级外框")
	_weapons.owned.clear()
	# 花灯源图 256px、糖画源图 48px —— 两者在槽位里都只显示 40px，
	# 正好用来验 rim_width 的换算（同一个屏幕粗细 = 不同的纹素数）
	_weapons.owned["halo"] = 8
	_weapons.owned["glowstick"] = 3
	game.hud._sync_weapon_row(true)
	await get_tree().process_frame

	var ic_halo: TextureRect = _find_slot_icon(Art.HALO_RING)
	var ic_glow: TextureRect = _find_slot_icon(Art.WAND_GLOWSTICK)
	_check(ic_halo != null and ic_glow != null, "两个武器槽图标都在")
	if ic_halo != null and ic_glow != null:
		_check(_shader_of(ic_halo).ends_with("skill_rank_rim.gdshader"),
			"武器槽图标应挂 skill_rank_rim，实际 %s" % _shader_of(ic_halo))
		var mh := ic_halo.material as ShaderMaterial
		var mg := ic_glow.material as ShaderMaterial
		if mh != null and mg != null:
			_check(int(mh.get_shader_parameter("rank")) == 8,
				"Lv8 花灯 rank=%d" % int(mh.get_shader_parameter("rank")))
			_check(int(mg.get_shader_parameter("rank")) == 3,
				"Lv3 糖画 rank=%d" % int(mg.get_shader_parameter("rank")))
			var wh: float = float(mh.get_shader_parameter("rim_width"))
			var wg: float = float(mg.get_shader_parameter("rim_width"))
			# 同一个屏幕粗细 → 纹素数比值应约等于源图分辨率比值 256/48 ≈ 5.33
			var want: float = 256.0 / 48.0
			_check(absf(wh / maxf(wg, 0.001) - want) < 0.5,
				"框宽按源图分辨率换算（256px/48px 的纹素比 %.2f，期望 %.2f）—— 不换算的话花灯那格是一根看不见的细线"
				% [wh / maxf(wg, 0.001), want])
		# 客观验分级语义：同一个图标换成 rank 1 / 8 各量一次，亮度差就是框本身。
		# 只看着图判"有没有框"不可靠 —— 花灯的图标本身就是一圈金环。
		var box: Rect2 = ic_halo.get_global_rect().grow(4.0)
		ShaderFX.set_rank(ic_halo, 1)
		await RenderingServer.frame_post_draw
		var l1: float = _luma(_grab(), box)
		ShaderFX.set_rank(ic_halo, 8)
		await RenderingServer.frame_post_draw
		var l8: float = _luma(_grab(), box)
		_check(l8 > l1 * 1.08,
			"Lv1~2 不出框、Lv8 出朱红粗框（同格亮度 %.0f → %.0f）" % [l1, l8])
	await _shot("slots_rank")


# --- 工具 -------------------------------------------------------------------

func _lock(id: String) -> void:
	# 手动开过一次火之后，fire_* 已经把冷却重置成正常值，这里再压住，
	# 免得后面几个用例的截图被自动开火叠上第二发。
	_weapons._cd[id] = 999.0


## 拖尾到底画出来没有？—— 冻住弹体，数"有拖尾那一帧比无拖尾多亮出来的像素数"。
## 为什么不用"区域平均亮度"：尾巴很细，框一放大就被地面稀释
##   （160x80 → +17%，320x120 → +7%，同一发弹、同一个 shader，纯粹是分母变了）。
## 数像素与框的大小无关，读起来也直白："这层光实际占了多大的面积"。
func _trail_gain(node: Sprite2D) -> float:
	_weapons.set_process(false)   # 冻住 update_bullets，两帧的像素位置才一致
	var center: Vector2 = node.get_global_transform_with_canvas().origin
	var box := Rect2(center - Vector2(120.0, 45.0), Vector2(240.0, 90.0))
	await RenderingServer.frame_post_draw
	var with_trail: Image = _grab()
	ShaderFX.clear_trail(node)
	node.material = null
	await RenderingServer.frame_post_draw
	var without: Image = _grab()
	_weapons.set_process(true)
	return float(_lit_pixels(with_trail, without, box, 0.06))


## 两张图在 box 内"变亮超过 threshold（r+g+b 之和）"的像素个数
func _lit_pixels(a: Image, b: Image, box: Rect2, threshold: float) -> int:
	var x0: int = clampi(int(box.position.x), 0, a.get_width() - 1)
	var y0: int = clampi(int(box.position.y), 0, a.get_height() - 1)
	var x1: int = clampi(int(box.end.x), 0, a.get_width())
	var y1: int = clampi(int(box.end.y), 0, a.get_height())
	var n := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var d: float = (ca.r - cb.r) + (ca.g - cb.g) + (ca.b - cb.b)
			if d > threshold:
				n += 1
	return n


func _grab() -> Image:
	return get_viewport().get_texture().get_image()


## 区域内的总亮度（r+g+b）。只看可见像素，透明处不参与。
func _luma(img: Image, box: Rect2) -> float:
	var x0: int = clampi(int(box.position.x), 0, img.get_width() - 1)
	var y0: int = clampi(int(box.position.y), 0, img.get_height() - 1)
	var x1: int = clampi(int(box.end.x), 0, img.get_width())
	var y1: int = clampi(int(box.end.y), 0, img.get_height())
	var sum := 0.0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c: Color = img.get_pixel(x, y)
			sum += c.r + c.g + c.b
	return sum


func _find_fx(path: String) -> Sprite2D:
	for f in _weapons._fx:
		var n: Sprite2D = (f as WeaponManager.Fx).node
		if n != null and n.visible and n.texture != null and n.texture.resource_path == path:
			return n
	return null


func _find_burst() -> ColorRect:
	for c in _weapons.get_children():
		if c is ColorRect and _shader_of(c).ends_with("cast_burst.gdshader"):
			return c as ColorRect
	return null


func _find_bullet(id: String) -> WeaponManager.Bullet:
	for b in _weapons._bullets:
		if (b as WeaponManager.Bullet).id == id:
			return b as WeaponManager.Bullet
	return null


func _find_field(ring: GarlicRing) -> ColorRect:
	for c in ring.get_children():
		if c is ColorRect and _shader_of(c).ends_with("aura_field.gdshader"):
			return c as ColorRect
	return null


func _find_slot_icon(tex_path: String) -> TextureRect:
	for box in game.hud.weapon_row.get_children():
		for c in box.get_children():
			if c is TextureRect and (c as TextureRect).texture != null:
				if (c as TextureRect).texture.resource_path == tex_path:
					return c as TextureRect
	return null


func _shader_of(n: CanvasItem) -> String:
	if n == null or n.material == null:
		return "<null>"
	var m := n.material as ShaderMaterial
	if m == null or m.shader == null:
		return "<non-shader>"
	return m.shader.resource_path.get_file()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   %s" % msg)
	else:
		print("  FAIL %s" % msg)
		_bad.append(msg)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := "user://skill_%s.png" % tag
	var err: int = img.save_png(path)
	print("  SHOT %-16s err=%d size=%s" % [tag, err, str(img.get_size())])
