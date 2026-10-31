extends Node

# ============================================================================
# v6 两个新 shader 的 Pixel 级验收（docs/design/v6_fx_art_plan.md §8 新增检查 1）
# ----------------------------------------------------------------------------
# 用法：godot --path . res://tools/V6Fx.tscn          ← **不能加 --headless**
#       本工具靠 RenderingServer.frame_post_draw 取图，dummy driver 下那个信号不触发，
#       进程会静默挂死（上一轮 FxInGame 就是这么挂了 8 分钟）。
#
# 为什么必须"数像素"而不是看图：
#   这两个 shader 的错法不是编译失败，而是**能编译但看不见**（intensity 被 env 吃掉、
#   band 落到节点外、走马灯整片糊成实心圈）。截图只能证明"我看到了"，断言才能证明
#   "下一版还看得见"。清单 §8 要求：可见像素 > 20% 且无纯白过曝。
#
# 与 V6Art.gd 的分工：
#   V6Art.gd（--headless --script）  管资源：登记 / 可加载 / 画布尺寸 / 零新武器本体
#   V6Fx.tscn（真实渲染）            管像素：可见性 / 不过曝 / 贴边不占中心 / 在流动
#   接线行为（角标只在 Lv8 / 弹体换图 / 合批不回退）归 V5InGame 那一层。
# ============================================================================

const BOX := 300.0            # 铁水节点边长 = 2 × 150 半径（清单 §3.1）
const VIEW_BIG := 720.0       # 走马灯：720 = 竖屏短边，按它归一化才是线上尺寸
const VIEW_TILE := 900.0      # 铁水：留出边距，能看出"火星有没有被节点矩形切掉"

var fails: int = 0
var _sv: SubViewport
var _holder: Node2D
## 背景色的亮度基线。**所有"可见"判定都相对它**：
## 深蓝底本身就有 0.077 的亮度，拿绝对阈值 0.03 去判会得到"整屏都可见"的假绿。
var _base_lum := 0.0


func _chk(cond: bool, msg: String) -> void:
	print("  %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	await get_tree().process_frame
	print("\n===== v6 新 shader 像素验收 =====")
	await _case_molten()
	await _case_lantern()
	await _shot_compare()

	print("\n---------- 断言 ----------")
	if fails == 0:
		print("  ok   molten_scatter / lantern_stream 全部达标")
	print("\n==== v6 新 shader 像素验收：%s（fail=%d）====\n" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 工具
## 新建一块纯黑画布。每次都重建：SubViewport 的旧孩子不清掉，会拍到上一个用例的残影。
func _canvas(edge: float) -> void:
	if _sv != null:
		_sv.queue_free()
		_sv = null
	await get_tree().process_frame
	_sv = SubViewport.new()
	_sv.size = Vector2i(int(edge), int(edge))
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 深蓝近黑：和游戏地面同色系。纯黑会把"很暗的橙"也判成可见，
	# 到了真实场景里却看不见 —— 那种自欺欺人的验收不如不做。
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.078, 0.129)
	bg.size = Vector2(edge, edge)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# z_index -10 而不是 -1：铁水节点自带 -2（要压在怪之下），
	# 背景只要高过它就会把整片火星盖住 —— 这个坑第一次跑就踩了，画面全黑还以为是 shader 坏了。
	bg.z_index = -10
	_sv.add_child(bg)
	_holder = Node2D.new()
	_holder.position = Vector2(edge, edge) * 0.5
	_sv.add_child(_holder)
	add_child(_sv)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var probe: Image = _sv.get_texture().get_image()
	_base_lum = _lum(probe.get_pixel(4, 4))


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return _sv.get_texture().get_image()


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## 统计一块方形区域：可见像素比例 / 纯白过曝比例 / 平均亮度
func _stats(img: Image, origin: Vector2i, edge: int) -> Dictionary:
	var vis := 0
	var white := 0
	var total := 0
	var sum := 0.0
	for y in range(origin.y, mini(origin.y + edge, img.get_height())):
		for x in range(origin.x, mini(origin.x + edge, img.get_width())):
			var c: Color = img.get_pixel(x, y)
			var l: float = _lum(c)
			total += 1
			sum += l
			if l > _base_lum + 0.02:
				vis += 1
			if c.r > 0.985 and c.g > 0.985 and c.b > 0.985:
				white += 1
	return {
		"vis": float(vis) / maxf(float(total), 1.0),
		"white": float(white) / maxf(float(total), 1.0),
		"mean": sum / maxf(float(total), 1.0),
	}


# ---------------------------------------------------------------- 用例 1：铁水火星
func _case_molten() -> void:
	print("\n[1] molten_scatter 铁水散开（半径 150 / 节点 300）")
	await _canvas(VIEW_TILE)
	# center 传**画布坐标**（= 画布中心），不是 holder 的本地原点：
	# molten_scatter 内部用的是 global_position（同 burst_ellipse 的口径），
	# 传 Vector2.ZERO 会把整片火星画到左上角去，看起来像"shader 没生效"。
	var fx: ColorRect = ShaderFX.molten_scatter(
		_holder, Vector2(VIEW_TILE, VIEW_TILE) * 0.5, BOX * 0.5, WeaponManager.MOLTEN_COLOR)
	await get_tree().process_frame
	await get_tree().process_frame
	# 手工把 pulse 钉在 0.8（播到中段）：验收要可复现，不能"看运气抓到哪一帧"
	var mat: ShaderMaterial = fx.material as ShaderMaterial
	_chk(mat != null and mat.shader == ShaderFX.SHADER_MOLTEN_SCATTER,
		"节点挂的是 molten_scatter（不是退回 cast_burst）")
	mat.set_shader_parameter("pulse", 0.8)
	_chk(is_equal_approx(float(mat.get_shader_parameter("rect_size").x), BOX),
		"rect_size 跟着节点尺寸写成 %.0f（短边归一化的前提）" % BOX)

	var img: Image = await _grab()
	img.save_png("user://v6_molten.png")
	var o := Vector2i(int((VIEW_TILE - BOX) * 0.5), int((VIEW_TILE - BOX) * 0.5))
	var s: Dictionary = _stats(img, o, int(BOX))
	print("  可见 %.1f%%   纯白 %.2f%%   平均亮度 %.3f" % [
		float(s["vis"]) * 100.0, float(s["white"]) * 100.0, float(s["mean"])])
	# §8 新增检查 1：可见像素 > 20%
	_chk(float(s["vis"]) > 0.20, "可见像素 %.1f%% > 20%%（一片火星，不是一条环）" % (float(s["vis"]) * 100.0))
	# 过曝：加法混合下最容易的错法就是把 intensity 拉太高，整片烧成纯白
	_chk(float(s["white"]) < 0.01, "纯白过曝像素 %.2f%% < 1%%（没有烧成白饼）" % (float(s["white"]) * 100.0))
	# 火星必须**不到边**：到了边就说明被节点矩形裁掉了，玩家会看到一条直线切面
	var edge_col: Dictionary = _stats(img, Vector2i(o.x, o.y + int(BOX) - 3), int(BOX))
	_chk(float(edge_col["vis"]) < 0.06, "节点最外 3px 行可见 %.1f%%（火星没被矩形切边）" % (float(edge_col["vis"]) * 100.0))
	# 中段应该有"熔核"：中心比外圈亮，否则读不出"铁水团刚砸开"
	var core: Dictionary = _stats(img, Vector2i(o.x + 105, o.y + 105), 90)
	var outer: Dictionary = _stats(img, Vector2i(o.x, o.y), int(BOX))
	_chk(float(core["mean"]) > float(outer["mean"]),
		"中心亮 %.3f > 全域均值 %.3f（熔核比火星云更热）" % [float(core["mean"]), float(outer["mean"])])


# ---------------------------------------------------------------- 用例 2：走马灯
func _case_lantern() -> void:
	print("\n[2] lantern_stream 走马灯流光（直径 400，短边 720）")
	await _canvas(VIEW_BIG)
	var d := 400.0
	var ring: ColorRect = ShaderFX.lantern_stream(_holder, d, Color(1.0, 0.78, 0.32))
	var mat: ShaderMaterial = ring.material as ShaderMaterial
	_chk(mat != null and mat.shader == ShaderFX.SHADER_LANTERN_STREAM, "节点挂的是 lantern_stream")
	_chk(absf(ring.size.x - d) < 0.5, "直径 = %.0f（和花灯判定直径同源）" % d)

	var img_a: Image = await _grab()
	img_a.save_png("user://v6_lantern.png")
	var c0 := Vector2i(int(VIEW_BIG * 0.5), int(VIEW_BIG * 0.5))
	# 中心 160×160 必须干净：玩家就站在圆心，盖住他等于毁掉走位
	var mid: Dictionary = _stats(img_a, c0 - Vector2i(80, 80), 160)
	_chk(float(mid["mean"]) < _base_lum + 0.01,
		"圆心 160px 区平均亮度 %.4f ≈ 底色 %.4f（不侵占 inner 里侧）" % [float(mid["mean"]), _base_lum])

	# 亮带：沿环取一整圈采样，数"够亮"的样本比例
	var r_band: float = d * 0.5 * 0.85      # inner 0.80 + band 0.10/2 ≈ 0.85
	var lit := 0
	var samples := 0
	for i in 360:
		var a: float = TAU * float(i) / 360.0
		var px := Vector2i(c0) + Vector2i(int(cos(a) * r_band), int(sin(a) * r_band))
		var c: Color = img_a.get_pixel(px.x, px.y)
		samples += 1
		if _lum(c) > _base_lum + 0.03:
			lit += 1
	var lit_ratio: float = float(lit) / float(samples)
	print("  环上采样亮度达标 %.1f%%" % (lit_ratio * 100.0))
	_chk(lit_ratio > 0.80, "整圈 %.0f%% 有光（是连续流光，不是一小段）" % (lit_ratio * 100.0))

	# 流动：0.35s 后同一圈采样必须变过。不变就是"静止装饰环"，
	# 而那正是 aura_field 的边带已经在做的事 —— 加它就没有意义了。
	await get_tree().create_timer(0.35).timeout
	var img_b: Image = await _grab()
	var moved := 0
	for i in 360:
		var a: float = TAU * float(i) / 360.0
		var px := Vector2i(c0) + Vector2i(int(cos(a) * r_band), int(sin(a) * r_band))
		if absf(_lum(img_b.get_pixel(px.x, px.y)) - _lum(img_a.get_pixel(px.x, px.y))) > 0.02:
			moved += 1
	print("  0.35s 后环上变化 %.0f%%" % (float(moved) / float(samples) * 100.0))
	_chk(moved > samples / 10, "环上 %.1f%% 的采样点亮度变了（亮带在走）" % (float(moved) / float(samples) * 100.0))


# ---------------------------------------------------------------- 输出对照图
func _shot_compare() -> void:
	# 一张并排图：左铁水、右走马灯。给报告用，不参与断言。
	var a := Image.load_from_file("user://v6_molten.png")
	var b := Image.load_from_file("user://v6_lantern.png")
	if a == null or b == null:
		return
	var h: int = 480
	a.resize(h, h, Image.INTERPOLATE_LANCZOS)
	b.resize(h, h, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(h * 2 + 12, h, false, Image.FORMAT_RGB8)
	out.fill(Color(0.04, 0.05, 0.07))
	out.blit_rect(a, Rect2i(0, 0, h, h), Vector2i(0, 0))
	out.blit_rect(b, Rect2i(0, 0, h, h), Vector2i(h + 12, 0))
	out.save_png("user://v6_fx_pair.png")
	print("\n[图] %s" % ProjectSettings.globalize_path("user://v6_fx_pair.png"))
