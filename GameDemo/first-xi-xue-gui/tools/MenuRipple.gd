extends Node

# =====================================================================
# 验收：开始界面（T1/T2/T3/T3.4）+ 范围伤害水波纹（T4/T5）
#
# 用法（**不能加 --headless**：像素占比统计与截图都依赖真实渲染）
#   godot --path . res://tools/MenuRipple.tscn
# 产出：
#   user://shot_main_menu.png   菜单版式
#   user://shot_area_ripple.png 花灯波纹在实战里的样子（皮影已不再画波纹）
#
# 写这个套件踩到的两件事，先说在前面：
# 1) 按钮不能"点了就真执行" —— 新游戏会 change_scene_to_file，测试的宿主节点跟着一起
#    被换掉，用例当场死掉；退出更直接 get_tree().quit()。所以 MainMenu 留了 intent_hook：
#    非空时只回报意图。生产路径恒为空，删掉它测试就会真的离开菜单。
# 2) 商店 open() 会把整树暂停。菜单是 inherit 的，暂停后按钮全不收输入 —— 这不是 bug，
#    正是"模态"该有的行为。但它意味着**关店之后必须复检 paused**，否则后面所有
#    await 出来的状态都是冷冻的假象。
# =====================================================================

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Game.tscn"
const SHOT_MENU := "user://shot_main_menu.png"
const SHOT_SHOP := "user://shot_main_menu_shop.png"
const SHOT_GAME := "user://shot_area_ripple.png"

var _fails: Array[String] = []
var _menu: MainMenu = null
var _game: GameScene = null
var _player: Player = null
var _weapons: WeaponManager = null
var _enemies: EnemyPool = null
## intent_hook 收到的 (kind, arg)
var _intents: Array = []
var _meta_backup: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	_meta_backup = MetaSave.snapshot()
	await _tick(2)
	await _case_entry()
	await _case_buttons()
	await _case_load_gate()
	await _case_shop()
	await _shot_menu()
	await _shot_shop()
	# 菜单截图拍完再放它走，否则会挡住后面的战斗画面
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null
	await _tick(2)
	await _case_ripple_api()
	await _case_ripple_render()
	await _boot_game()
	await _case_halo_ripple()
	await _case_orbit_ripple()
	await _shot_game()
	await _report()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		_fails.append(msg)

## 等 n 个"物理 + 渲染"帧。两种循环都要推，_ready 里靠它、HUD 刷新靠 process
func _tick(n := 1) -> void:
	for _i in n:
		await get_tree().physics_frame
		await get_tree().process_frame

func _shader_of(m: Material) -> String:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader != null:
			return sm.shader.resource_path
	return ""

# ---------------------------------------------------------------- A 入口
func _case_entry() -> void:
	print("\n[A] 入口场景")
	var ms: String = String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(ms == MENU_SCENE, "project.godot 的入口是主菜单（%s）" % ms)
	_check(ResourceLoader.exists(MENU_SCENE), "MainMenu.tscn 存在")
	var packed: PackedScene = load(MENU_SCENE) as PackedScene
	_check(packed != null, "MainMenu.tscn 可作为 PackedScene 载入")
	if packed == null:
		return
	_menu = packed.instantiate() as MainMenu
	_check(_menu != null, "主菜单根节点是 Control（脚本 MainMenu）")
	if _menu == null:
		return
	# 菜单必须能在**没有 Game 树**的情况下独立跑起来（T1 验收项）
	add_child(_menu)
	await _tick(3)
	_check(_menu.anchor_right == 1.0 and _menu.anchor_bottom == 1.0,
		"菜单全屏锚定（anchor_right/bottom = 1.0）")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_check(absf(_menu.size.x - vp.x) <= 2.0 and absf(_menu.size.y - vp.y) <= 2.0,
		"菜单铺满视口 %.0fx%.0f（实际 %.0fx%.0f）" % [vp.x, vp.y, _menu.size.x, _menu.size.y])
	_check(_menu.shop_instance() == null, "刚进菜单时没有商店实例")

# ---------------------------------------------------------------- B 四按钮
func _case_buttons() -> void:
	print("\n[B] 四按钮接线")
	var btns: Array[Button] = [_menu.btn_new, _menu.btn_load, _menu.btn_shop, _menu.btn_quit]
	var names: Array[String] = ["新游戏", "载入存档", "打开商店", "退出游戏"]
	var all_ok := true
	for i in btns.size():
		var b: Button = btns[i]
		if b == null or not b.is_visible_in_tree() or b.size.y < 40.0:
			all_ok = false
			print("       ↳ %s 不可见或过小" % names[i])
	_check(all_ok, "四个按钮都可见且可点（最小高度 ≥ 40）")

	_intents.clear()
	_menu.intent_hook = func(kind: String, arg: String) -> void: _intents.append([kind, arg])
	_check(_menu.intent_hook.is_valid(), "测试钩子已装上（生产路径恒为空 Callable）")

	_menu.btn_new.emit_signal("pressed")
	_check(_intents.size() == 1 and String(_intents[0][0]) == "scene" \
		and String(_intents[0][1]) == GAME_SCENE,
		"「新游戏」→ 切到 %s" % GAME_SCENE)

	_intents.clear()
	_menu.btn_quit.emit_signal("pressed")
	_check(_intents.size() == 1 and String(_intents[0][0]) == "quit",
		"「退出游戏」→ 退出进程（测试里只回报意图）")

	# 真路径不能真的跑，但至少断言它指向的是对的东西
	_check(_menu.GAME_SCENE == GAME_SCENE and _menu.SHOP_SCENE == "res://scenes/ui/ShopUI.tscn",
		"菜单里的场景常量指向 Game.tscn / ShopUI.tscn")

# ---------------------------------------------------------------- C 载入存档门槛
func _case_load_gate() -> void:
	print("\n[C] 载入存档语义（T3.4 默认实现）")
	MetaSave.debug_set(0, {})
	_menu.refresh()
	_check(_menu.has_progress() == false, "清零后判定为「没有进度」")
	_check(_menu.btn_load.disabled, "无进度时「载入存档」置灰")
	_check(_menu.btn_load.text.contains("无存档"), "置灰时按钮文案点明原因（%s）" % _menu.btn_load.text)

	MetaSave.debug_set(500, {"damage": 1})
	_menu.refresh()
	_check(_menu.has_progress(), "有铜钱/等级后判定为「有进度」")
	_check(not _menu.btn_load.disabled, "有进度时「载入存档」可用")
	_check(_menu.btn_load.text == "载入存档", "可用时文案回到「载入存档」（%s）" % _menu.btn_load.text)
	_check(_menu.stats_label.text.contains("500"), "摘要显示铜钱数（%s）" % _menu.stats_label.text)
	_check(_menu.stats_label.text.contains("匠心"), "摘要显示已升的成长线（%s）" % _menu.stats_label.text)

	_intents.clear()
	_menu.btn_load.emit_signal("pressed")
	_check(_intents.size() == 1 and String(_intents[0][1]) == GAME_SCENE,
		"「载入存档」也进 Game.tscn（本作无单局存档，差异只是文案）")

# ---------------------------------------------------------------- D 商店
func _case_shop() -> void:
	print("\n[D] 菜单开商店（T3）")
	_menu.btn_shop.emit_signal("pressed")
	await _tick(3)
	var shop: ShopUI = _menu.shop_instance()
	_check(shop != null and is_instance_valid(shop), "菜单能实例出一份商店")
	_check(shop != null and shop.is_open(), "商店处于打开状态")
	_check(get_tree().paused, "商店打开时整树暂停（模态）")
	_check(shop != null and shop.get_parent() == _menu, "商店挂在菜单下（不依赖 Game 树）")

	# 重复点不能叠第二份遮罩
	_menu.btn_shop.emit_signal("pressed")
	await _tick(2)
	var n := 0
	for c in _menu.get_children():
		if c is ShopUI:
			n += 1
	_check(n == 1, "重复点「打开商店」不会叠出第二份（实际 %d 份）" % n)

	if shop != null and is_instance_valid(shop):
		shop.close()
	await _tick(3)
	_check(_menu.shop_instance() == null, "关店后引用被清掉")
	_check(not is_instance_valid(shop), "关店后实例真的被释放（没有留一层死遮罩）")
	_check(not get_tree().paused, "关店后解除暂停")

	# 结算界面那条旧路径不受影响：它 bind 的是 Game 场景里那份实例
	_check(ResourceLoader.exists("res://scenes/ui/ShopUI.tscn"), "ShopUI.tscn 仍是独立场景（结算界面复用同一份）")

# ---------------------------------------------------------------- E 波纹 API
func _case_ripple_api() -> void:
	print("\n[E] ShaderFX.ripple 三件套")
	var r: ColorRect = ShaderFX.ripple(self, 200.0, Color(1.0, 0.62, 0.30))
	_check(r != null, "ripple() 返回节点")
	if r == null:
		return
	_check(r.get_parent() == self, "波纹挂到传入的父节点下")
	var sp: String = _shader_of(r.material)
	_check(sp.ends_with("area_ripple.gdshader"), "材质用的是 area_ripple.gdshader（%s）" % sp.get_file())
	_check(r.size == Vector2(200.0, 200.0), "边长 = 传入直径（%.0f）" % r.size.x)
	_check(r.position == Vector2(-100.0, -100.0), "以父节点原点为中心（position = -size/2）")
	_check(r.color == Color.WHITE, "节点顶点色纯白（blend_add 会把它当乘数）")
	_check(r.mouse_filter == Control.MOUSE_FILTER_IGNORE, "不拦鼠标（盖在场上也不影响点击）")

	var mat: ShaderMaterial = r.material as ShaderMaterial
	_check(mat.get_shader_parameter("rect_size") == Vector2(200.0, 200.0),
		"rect_size 与节点尺寸同步（短边归一化的依据）")

	ShaderFX.ripple_resize(r, 300.0)
	_check(r.size == Vector2(300.0, 300.0) and r.position == Vector2(-150.0, -150.0),
		"ripple_resize 改尺寸并保持居中")
	_check(mat.get_shader_parameter("rect_size") == Vector2(300.0, 300.0),
		"ripple_resize 同步 rect_size（漏了会变成椭圆）")

	ShaderFX.ripple_pulse(r)
	_check(is_equal_approx(float(mat.get_shader_parameter("pulse")), 1.0),
		"ripple_pulse 立刻把 pulse 推到 1")
	await _tick(8)
	_check(float(mat.get_shader_parameter("pulse")) < 0.9, "pulse 会自行衰减（不是常亮）")

	# 防御：挂错材质不能崩（调用点在 beat() 里，崩了整局就停了）
	var plain := ColorRect.new()
	plain.color = Color.WHITE
	add_child(plain)
	ShaderFX.ripple_pulse(plain)
	_check(_shader_of(plain.material) == "", "ripple_pulse 对非波纹节点安全跳过（不篡改材质）")

	r.queue_free()
	plain.queue_free()
	await _tick(1)

# ---------------------------------------------------------------- F 波纹像素占比
func _case_ripple_render() -> void:
	print("\n[F] 水波纹渲染（可见像素占比 / 不过曝）")
	if DisplayServer.get_name() == "headless":
		print("  skip headless 不渲染，像素统计无意义")
		return
	var sv := SubViewport.new()
	sv.size = Vector2i(256, 256)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var bg := ColorRect.new()
	bg.size = Vector2(256.0, 256.0)
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(bg)
	# 默认参数（intensity 0.55 / rings 2 / speed 1.6）—— 验的就是"开箱能不能看"
	var r: ColorRect = ShaderFX.ripple(sv, 240.0)
	r.position = Vector2(8.0, 8.0)
	await _tick(3)
	await RenderingServer.frame_post_draw

	var img: Image = sv.get_texture().get_image()
	var lit := 0
	var hot := 0
	var tot := 0
	for y in range(0, 256, 2):
		for x in range(0, 256, 2):
			tot += 1
			var px: Color = img.get_pixel(x, y)
			if maxf(px.r, maxf(px.g, px.b)) > 0.05:
				lit += 1
			if px.r > 0.97 and px.g > 0.97 and px.b > 0.97:
				hot += 1
	var ratio: float = float(lit) / float(maxi(tot, 1))
	var hot_ratio: float = float(hot) / float(maxi(tot, 1))
	_check(ratio >= 0.15 and ratio <= 0.55,
		"默认参数可见像素 %.1f%%（要求 15%%~55%%）" % (ratio * 100.0))
	_check(hot_ratio < 0.02, "没有大面积过曝纯白（%.2f%%）" % (hot_ratio * 100.0))
	sv.queue_free()
	await _tick(1)

# ---------------------------------------------------------------- G 花灯
func _boot_game() -> void:
	MetaSave.debug_set(0, {})
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await _tick(3)
	_player = _game.get_node("World/Player") as Player
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	# 冻住 Game 的刷怪 / 计时：本套件只关心波纹，不要被"半秒后刷出 4 只怪"干扰
	_game.set_process(false)
	_enemies.clear_all()
	await _tick(1)

func _case_halo_ripple() -> void:
	print("\n[G] 花灯：波纹是第二层，不是替换边带")
	var gr: GarlicRing = _player.garlic_ring
	_weapons.acquire("halo")
	await _tick(4)
	_check(gr.visible, "装备花灯后光环可见")

	var rp: ColorRect = gr.get("_ripple") as ColorRect
	var field: ColorRect = gr.get("_field") as ColorRect
	var ring: Sprite2D = gr.get_node_or_null("Ring") as Sprite2D
	_check(rp != null, "GarlicRing 上挂了波纹层")
	_check(field != null and ring != null, "原来的能量场边带与光圈贴图都还在（没有被替换）")
	if rp == null or field == null or ring == null:
		return

	_check(rp.get_index() > field.get_index(), "波纹画在能量场之后（先边界后内部）")
	_check(rp.get_index() < ring.get_index(), "波纹画在光圈之前（光圈=边界，不许被盖）")
	_check(_shader_of(rp.material).ends_with("area_ripple.gdshader"), "波纹用的是 area_ripple")
	_check(_shader_of(field.material).ends_with("aura_field.gdshader"), "边带仍用 aura_field")

	var want: float = _weapons.halo_radius() * 2.0
	_check(absf(rp.size.x - want) <= 0.5,
		"波纹直径 = 判定直径 %.0f（实际 %.0f）" % [want, rp.size.x])

	var mat: ShaderMaterial = rp.material as ShaderMaterial
	_check(float(mat.get_shader_parameter("pulse")) <= 0.0, "平时 pulse 为 0（只有命中才跳）")
	gr.beat()
	_check(float(mat.get_shader_parameter("pulse")) > 0.9, "beat() 把波纹 pulse 推到 1")
	_check(gr.pulse > 0.9, "beat() 原有的光圈脉冲没有被波纹顶掉")

	# 升级加范围后波纹要跟着长，否则"看得见的圈"和"打得中的圈"会分家
	_weapons.owned["halo"] = 8
	await _tick(4)
	var want8: float = _weapons.halo_radius() * 2.0
	_check(absf(rp.size.x - want8) <= 0.5,
		"升到 Lv8 后波纹跟着变宽 %.0f（实际 %.0f）" % [want8, rp.size.x])

# ---------------------------------------------------------------- H 皮影
## 皮影的"绕身"只由影人本体表达，**不画水波纹轨迹圈**。
##
## 这条曾经是反向的（断言"装备皮影后生成一圈 area_ripple"）。删掉的理由不是省性能，
## 是视觉语言撞车：花灯的范围场也是同心波纹，两个技能同时在身上时，
## 玩家看到的是一片"到处在荡的圈"，反而分不清哪个才是花灯的判定范围。
## 所以这里锁死"没有波纹"，防止以后有人"顺手补一个轨道提示"把它加回来。
func _case_orbit_ripple() -> void:
	print("\n[H] 皮影：只留影人本体，不画水波纹")
	_weapons.acquire("phone")
	await _tick(6)

	var rings := 0
	for c in _weapons.get_children():
		if c is ColorRect:
			rings += 1
	_check(rings == 0, "装备皮影后不再生成任何波纹节点（实际 %d 个 ColorRect）" % rings)
	_check(_weapons.get("_orbit_ring") == null, "轨迹圈字段与节点都已移除（不留孤儿）")

	var sprites: Array = _weapons.get("_orbit_sprites") as Array
	var n: int = 0 if sprites == null else sprites.size()
	_check(n > 0, "环绕体照旧生成（%d 个）" % n)
	if n == 0:
		return
	var s: Sprite2D = sprites[0]
	_check(s.visible, "环绕体可见 —— 轨道由它自己的运动表达")
	var p0: Vector2 = s.global_position
	await _tick(24)
	var moved: float = s.global_position.distance_to(p0)
	_check(moved > 2.0, "环绕体仍在飞（24 帧位移 %.1f px）" % moved)
	# 环绕半径仍然只由数据表决定（没有轨迹圈之后，半径没有任何"画出来"的锚点，
	# 这里至少保证本体确实落在那个半径上）
	var d: Dictionary = WeaponDB.def("phone")
	var r: float = float(d.get("orbit_radius", 58.0)) * _weapons.stat("area")
	var off: float = s.global_position.distance_to(_player.global_position)
	_check(absf(off - r) <= 1.5, "环绕体落在半径 %.0f 上（实际 %.1f）" % [r, off])

	_weapons.owned.erase("phone")
	await _tick(3)
	_check(not s.visible, "卸下皮影后环绕体隐藏")

# ---------------------------------------------------------------- 截图
func _shot_menu() -> void:
	if DisplayServer.get_name() == "headless":
		print("\n[截图] headless 下跳过")
		return
	if _menu == null or not is_instance_valid(_menu):
		return
	# 给一点进度，让摘要行不是空的（"手上 0 枚铜钱 尚无传承"看不出排版对不对）
	MetaSave.debug_set(1280, {"damage": 2, "max_hp": 1, "revive": 1})
	_menu.refresh()
	await _tick(3)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(SHOT_MENU)
	print("\n[截图] 菜单 → ", ProjectSettings.globalize_path(SHOT_MENU))

## 菜单开商店的样子（T3 的视觉证据：商店真的能独立挂在菜单上）
func _shot_shop() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _menu == null or not is_instance_valid(_menu):
		return
	_menu.btn_shop.emit_signal("pressed")
	await _tick(4)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(SHOT_SHOP)
	print("[截图] 菜单商店 → ", ProjectSettings.globalize_path(SHOT_SHOP))
	var s: ShopUI = _menu.shop_instance()
	if s != null and is_instance_valid(s):
		s.close()
	await _tick(3)

func _shot_game() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# 摆一屏"正在被光环烧"的画面：花灯 Lv8 + 皮影环绕。
	# 只放 6 只——这是给人看的对照图，塞满 11 只会把地面和波纹全糊掉，
	# 那张图就只剩下"一堆怪"（第一版就是这样，什么都看不清）。
	_weapons.owned["halo"] = 8
	_weapons.acquire("phone")
	var base: Vector2 = _player.global_position
	var rad: float = _weapons.halo_radius()
	for i in 6:
		var ang: float = TAU * float(i) / 6.0 + 0.4
		var e: Enemy = _enemies.spawn(base + Vector2.from_angle(ang) * rad * 0.62,
			99999.0, 0.0, 1, "cup", false)
		e.visible = true
	_weapons.set_process(true)
	await get_tree().create_timer(0.45).timeout
	_weapons.set_process(false)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(SHOT_GAME)
	print("[截图] 花灯波纹 → ", ProjectSettings.globalize_path(SHOT_GAME))

# ---------------------------------------------------------------- 收尾
func _report() -> void:
	MetaSave.debug_set(int(_meta_backup.get("coins", 0)),
		_meta_backup.get("levels", {}) as Dictionary)
	print("\n========== 开始界面 & 范围水波纹 验收 ==========")
	if _fails.is_empty():
		print("全部通过 OK")
	else:
		for f in _fails:
			print("失败: ", f)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _fails.is_empty() else 1)
