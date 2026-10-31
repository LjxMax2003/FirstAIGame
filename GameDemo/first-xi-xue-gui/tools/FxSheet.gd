extends Node

# FX 效果一览图：把 assets/shaders/fx/ 下 7 个 shader 挂到真实素材上，渲一张对照图。
#
# 为什么要有这个工具：
#   shader 的错法通常不是"编译不过"，而是"能编译但看不见 / 方向反了 / 边缘被裁白"。
#   这个场景把每个效果钉在固定参数上，让"改完到底有没有变好"是一次看图，不是靠感觉。
#
# 用 SubViewport 而不是截主窗口：主窗口走 stretch，canvas 尺寸会被缩放，
# 看到的就不是 720x1280 下的真实粗细。这里 1 canvas 单位 = 1 输出像素。
#
# 用法：godot --path . res://tools/FxSheet.tscn
#   产出 user://shot_fx_sheet.png（与 reports/ 里的验收图同一套流程）
#
# 说明：本文件与 assets/shaders/fx/ 的实跑校验在独立工程里做过（Godot 4.6 stable / mobile 后端），
#       在正式工程内只需确认 Art.tex() 能取到图，渲染逻辑本身没有额外依赖。

const OUT := "user://shot_fx_sheet.png"

const CELL := Vector2(400.0, 260.0)
const COLS := 3

const SHADER_DIR := "res://assets/shaders/fx/"

## 每格 = 若干层，层可以是 sprite（挂素材）或 rect（纯着色块）
const DEMOS: Array = [
	{
		"title": "hit_flash  amount 0 / 1",
		"layers": [
			{"type": "sprite", "art": Art.ENEMY_CUP, "shader": "hit_flash.gdshader",
				"params": {"amount": 0.0}, "pos": Vector2(115, 120), "fit": 150.0},
			{"type": "sprite", "art": Art.ENEMY_CUP, "shader": "hit_flash.gdshader",
				"params": {"amount": 1.0}, "pos": Vector2(285, 120), "fit": 150.0},
		],
	},
	{
		"title": "hit_flash + outline(2)  idle / hit",
		"layers": [
			{"type": "sprite", "art": Art.ENEMY_CUP_FAST, "shader": "hit_flash.gdshader",
				"params": {"amount": 0.0, "outline_width": 2.0}, "pos": Vector2(115, 120), "fit": 150.0},
			{"type": "sprite", "art": Art.ENEMY_CUP_FAST, "shader": "hit_flash.gdshader",
				"params": {"amount": 1.0, "outline_width": 2.0}, "pos": Vector2(285, 120), "fit": 150.0},
		],
	},
	{
		"title": "dissolve_spawn  progress 0.55（出现）",
		"layers": [
			{"type": "sprite", "art": Art.ELITE_BOX, "shader": "dissolve_spawn.gdshader",
				"params": {"progress": 0.55, "direction": 0.6}, "pos": Vector2(200, 120), "fit": 170.0},
		],
	},
	{
		"title": "dissolve_spawn  progress 0.38（消失）",
		"layers": [
			{"type": "sprite", "art": Art.ELITE_BOX, "shader": "dissolve_spawn.gdshader",
				"params": {"progress": 0.38, "direction": 0.6, "edge_color": Color(0.45, 0.9, 1.0)},
				"pos": Vector2(200, 120), "fit": 170.0},
		],
	},
	{
		"title": "sprite_glow  coin",
		"layers": [
			{"type": "sprite", "art": Art.COIN, "shader": "sprite_glow.gdshader",
				"params": {"intensity": 1.8, "falloff": 1.0}, "pos": Vector2(200, 120), "fit": 140.0},
		],
	},
	{
		"title": "glow_aura + 主角",
		"layers": [
			{"type": "rect", "shader": "glow_aura.gdshader",
				"params": {"radius": 0.42, "softness": 0.55, "intensity": 1.2},
				"size": Vector2(250, 250), "pos": Vector2(75, 5)},
			{"type": "sprite", "art": Art.PLAYER, "shader": "hit_flash.gdshader",
				"params": {"amount": 0.0}, "pos": Vector2(200, 120), "fit": 150.0},
		],
	},
	{
		"title": "shine_sweep  progress 0.55 / hardness 0.8",
		"layers": [
			{"type": "sprite", "art": Art.COIN, "shader": "shine_sweep.gdshader",
				"params": {"progress": 0.55, "hardness": 0.8, "intensity": 1.3},
				"pos": Vector2(200, 120), "fit": 140.0},
		],
	},
	{
		"title": "magic_circle  appear 1.0",
		"layers": [
			{"type": "rect", "shader": "magic_circle.gdshader",
				"params": {"appear": 1.0, "rings": 3, "star_points": 8, "orbs": 6},
				"size": Vector2(240, 240), "pos": Vector2(80, 10)},
		],
	},
	{
		"title": "hurt_vignette  max_alpha 0.85",
		"layers": [
			{"type": "rect", "shader": "hurt_vignette.gdshader",
				"params": {"max_alpha": 0.85, "screen_size": CELL},
				"size": CELL, "pos": Vector2.ZERO},
		],
	},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var sv := SubViewport.new()
	sv.size = Vector2i(int(CELL.x * COLS), int(CELL.y * 3.0))
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	for i in DEMOS.size():
		var origin := Vector2(float(i % COLS) * CELL.x, float(i / COLS) * CELL.y)
		_build_cell(sv, origin, DEMOS[i], i)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = sv.get_texture().get_image()
	var err: int = img.save_png(OUT)
	print("[FxSheet] save=", err, " -> ", ProjectSettings.globalize_path(OUT))
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

	for layer in demo["layers"]:
		sv.add_child(_build_layer(origin, layer))


func _build_layer(origin: Vector2, layer: Dictionary) -> Node:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + String(layer["shader"]))
	var params: Dictionary = layer.get("params", {})
	for key in params.keys():
		mat.set_shader_parameter(key, params[key])

	if layer["type"] == "sprite":
		var spr := Sprite2D.new()
		spr.texture = Art.tex(layer["art"])
		var tex_size: Vector2 = spr.texture.get_size()
		var longest: float = maxf(tex_size.x, tex_size.y)
		if longest > 0.0:
			spr.scale = Vector2.ONE * (float(layer.get("fit", 140.0)) / longest)
		spr.position = origin + Vector2(layer["pos"]) + Vector2(0.0, 18.0)
		spr.material = mat
		return spr

	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.size = Vector2(layer.get("size", Vector2(240.0, 240.0)))
	rect.position = origin + Vector2(layer.get("pos", Vector2.ZERO))
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	return rect
