extends Node

# 技能向 FX 一览图：assets/shaders/fx/skill/ 下 6 个 shader 挂真实武器素材，渲一张对照图。
#
# 和 FxSheet.gd 是同一个思路（数据驱动 + SubViewport 1:1），区别在于：
#   1. 这里的 shader 大多是"时间驱动"的（progress / beat），所以每一格先钉死一个
#      快照参数再截，并且截图前**必须杀掉所有 tween** —— 否则 tween 会在下一帧把
#      progress 写回插值起点，截出来是一片空白。
#   2. cast_burst / slash_arc 走的是 ShaderFX 的公开 API（不是手搓材质），
#      这样这张图同时也在验证 API：如果 API 的 squash 尺寸换算写错了，
#      椭圆会被裁掉，图上直接看得出来。
#
# 用法：godot --path . res://tools/SkillSheet.tscn
#   产出 user://shot_skill_sheet.png（对比 docs/shaders/skill-preview.png）

const OUT := "user://shot_skill_sheet.png"

const CELL := Vector2(400.0, 260.0)
const COLS := 3

# 每格：title + 用回调建出来的层。回调返回的 Dictionary 会被 _freeze 收集，
# 截图前统一把里面的 uniform 再写一遍（覆盖 tween 的干扰）。
const DEMOS: Array = [
	{
		"title": "slash_arc  进度 0.28 / 0.65 / 1.0（收势）",
		"art": Art.WHIP_ARC,
		"fit": 320.0,
		"progress": [0.28, 0.65, 1.0],
		"pos": [Vector2(200.0, 130.0), Vector2(200.0, 130.0), Vector2(200.0, 130.0)],
	},
	{
		"title": "cast_burst  扩散 rays=10  squash(1.7,0.5)",
		"burst": {
			"size": Vector2(330.0, 190.0),
			"squash": Vector2(1.7, 0.5),
			"rays": 10,
			"color": Color(1.0, 0.86, 0.55),
			"progress": 0.42,
		},
	},
	{
		"title": "cast_burst  gather 收拢 rings=2",
		"burst": {
			"size": Vector2(240.0, 240.0),
			"squash": Vector2.ONE,
			"rays": 0,
			"gather": true,
			"rings": 2.0,
			"color": Color(0.86, 0.9, 1.0),
			"progress": 0.55,
		},
	},
	{
		"title": "skill_rank_rim  48px  Lv3 / 5 / 7 / 8 / 进化",
		"art": Art.KNIFE_BOXCUTTER,
		"fit": 80.0,
		"ranks": [3, 5, 7, 8, 8],
		"evolved": [false, false, false, false, true],
		"xs": [-120.0, -60.0, 0.0, 60.0, 120.0],
	},
	{
		"title": "skill_rank_rim  Lv8 大图",
		"art": Art.KNIFE_BOXCUTTER,
		"fit": 190.0,
		"ranks": [8],
		"evolved": [false],
		"xs": [0.0],
	},
	{
		"title": "aura_field  swirl=0.55 + 本体",
		"field": {"diameter": 230.0, "color": Color(1.0, 0.72, 0.35), "swirl": 0.55},
		"art": Art.HALO_RING,
		"fit": 150.0,
	},
	{
		"title": "area_ripple  同心扩散 rings=2 speed=1.6",
		"ripple": {
			"diameter": 232.0, "color": Color(1.0, 0.62, 0.30),
			"rings": 2.0, "speed": 1.6, "intensity": 0.55,
		},
		"art": Art.HALO_RING,
		"fit": 150.0,
	},
	{
		"title": "projectile_trail  stretch 0.3 / 0.55 / 0.85",
		"art": Art.BULLET_GLOWSTICK,
		"fit": 70.0,
		"stretch": [0.3, 0.55, 0.85],
		"xs": [-110.0, 0.0, 110.0],
	},
	{
		"title": "skill_rank_rim  Lv8 进化（大图）",
		"art": Art.KNIFE_BOXCUTTER,
		"fit": 190.0,
		"ranks": [8],
		"evolved": [true],
		"xs": [0.0],
	},
	{
		"title": "aura_field  beat 命中一跳",
		"field": {"diameter": 210.0, "color": Color(0.95, 0.55, 0.3), "swirl": -0.55, "beat": 0.8},
		"art": Art.HALO_RING,
		"fit": 130.0,
	},
]

## 截图前要强制写回的 uniform；key = 材质对象，value = 参数字典
var _freeze: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var rows: int = int(ceil(float(DEMOS.size()) / float(COLS)))
	var sv := SubViewport.new()
	sv.size = Vector2i(int(CELL.x * COLS), int(CELL.y * rows))
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	for i in DEMOS.size():
		var origin := Vector2(float(i % COLS) * CELL.x, float(i / COLS) * CELL.y)
		_build_cell(sv, origin, DEMOS[i], i)

	await get_tree().process_frame
	await get_tree().process_frame
	# 关键：先杀掉所有 tween，再把快照参数写回。
	# 不杀的话 tween_method 会在下一帧覆盖进度，截图正好抓到 ≈0 的那一帧（全空）。
	for tw in get_tree().get_processed_tweens():
		if tw != null and tw.is_valid():
			tw.kill()
	for mat in _freeze.keys():
		if not is_instance_valid(mat):
			continue
		var params: Dictionary = _freeze[mat]
		for key in params.keys():
			mat.set_shader_parameter(key, params[key])

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = sv.get_texture().get_image()
	var err: int = img.save_png(OUT)
	print("[SkillSheet] save=", err, " -> ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _build_cell(sv: SubViewport, origin: Vector2, demo: Dictionary, index: int) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.14) if index % 2 == 0 else Color(0.07, 0.08, 0.10)
	bg.position = origin
	bg.size = CELL - Vector2(2.0, 2.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(bg)

	var label := Label.new()
	label.text = demo["title"]
	label.position = origin + Vector2(10.0, 6.0)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	sv.add_child(label)

	var center := origin + Vector2(CELL.x * 0.5, CELL.y * 0.5 + 10.0)

	# --- 冲击环：走 API，顺带验证 squash 换算 ---
	if demo.has("burst"):
		var b: Dictionary = demo["burst"]
		var rect := ShaderFX.burst(
			sv,
			b["size"],
			b["color"],
			b["squash"],
			int(b["rays"]),
			bool(b.get("gather", false)),
			999.0  # 超长 duration：让 tween 几乎不动，截完立刻退出
		)
		# API 把 position 设成 -size/2，这里平移到位
		rect.position += center
		var mat := rect.material as ShaderMaterial
		var frozen := {"progress": b["progress"]}
		if b.has("rings"):
			frozen["rings"] = b["rings"]
		_freeze[mat] = frozen
		return

	# --- 范围水波纹：走 API ---
	if demo.has("ripple"):
		var rp: Dictionary = demo["ripple"]
		var node := ShaderFX.ripple(
			sv,
			float(rp["diameter"]), rp["color"],
			float(rp["rings"]), float(rp["speed"]), float(rp["intensity"])
		)
		node.position += center
		if demo.has("art"):
			_sprite(sv, demo["art"], center, demo["fit"])
		return

	# --- 能量场：走 API ---
	if demo.has("field"):
		var f: Dictionary = demo["field"]
		var node := ShaderFX.field(sv, f["diameter"], f["color"], f["swirl"])
		node.position += center
		if f.has("beat"):
			var fmat := node.material as ShaderMaterial
			_freeze[fmat] = {"beat": f["beat"]}
		if demo.has("art"):
			_sprite(sv, demo["art"], center, demo["fit"])
		return

	# --- 纯 sprite 类：弧光 / 环框 / 弹道 ---
	var xs: Array = demo.get("xs", [0.0])
	for k in xs.size():
		var at: Vector2 = center + Vector2(float(xs[k]), 0.0)
		var spr := _sprite(sv, demo["art"], at, demo["fit"])

		if demo.has("progress"):
			# 弧光：遮罩式，长 duration 让 tween 停在起点
			ShaderFX.slash(spr, 999.0, false, false)
			_freeze[spr.material as ShaderMaterial] = {"progress": float(demo["progress"][k])}
		elif demo.has("ranks"):
			ShaderFX.set_rank(spr, int(demo["ranks"][k]), bool(demo["evolved"][k]))
		elif demo.has("stretch"):
			# 弹道贴图太短，横向拉长才看得见尾巴
			spr.scale.x *= 3.6
			ShaderFX.set_trail(spr, 0, Color(1.0, 0.86, 0.55))
			_freeze[spr.material as ShaderMaterial] = {"stretch": float(demo["stretch"][k])}


## 建一个铺满 fit 的 sprite 并挂到 parent 下。
## 注意必须在这里 add_child —— 只 return 节点不挂上的话，图上就是一片空白，
## 而且不会报任何错（这个坑本项目工具里踩过一次）。
func _sprite(parent: Node, art: String, center: Vector2, fit: float) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = Art.tex(art)
	var tex_size: Vector2 = spr.texture.get_size()
	var longest: float = maxf(tex_size.x, tex_size.y)
	if longest > 0.0:
		spr.scale = Vector2.ONE * (fit / longest)
	spr.position = center
	parent.add_child(spr)
	return spr
