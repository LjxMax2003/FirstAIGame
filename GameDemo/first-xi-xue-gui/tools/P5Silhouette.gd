extends Control

# P5-T5.3：48px 剪影可辨识度（人工判定的**素材**，不是判定本身）。
#
# 按 `美术资产映射.md §5.2` 的剪影测试：6 种敌人缩到 48×48、填纯黑，
# 能区分「纸屑 / 纸鸢 / 傀儡 / 墨渍 / 残面傩 / Boss」。
#
# 【为什么要用 SubViewport 而不是直接截主窗口】
# 主窗口是 720×881，但 stretch 让 canvas 变成 1046×1280 —— 画 48 单位实际只出 33 像素。
# 那样测的就不是"48px 能不能分清"，而是"33px 能不能分清"，结论会偏严。
# SubViewport 固定 720×400 且 1 canvas 单位 = 1 输出像素，尺寸才真是 48。
#
# 【AI 不能替人做这一步】48px 下"能不能一眼分开"是感知问题，不是像素统计问题。
# 这个工具只负责把三个变量钉死，让不同人看到的是同一张图：
#   ① 尺寸严格 48×48；② 纯黑填充（只剩轮廓）；③ 同一背景色。
# 上排是**真实判定尺寸**，下排是 2 倍放大，只用于"看清它原本长什么样"。
#
# 用法：godot --path . res://tools/P5Silhouette.tscn

const OUT_1X := "user://shot_p5_silhouette.png"
const OUT_2X := "user://shot_p5_silhouette_zoom.png"
## 判定尺寸：映射文档钉死 48
const CELL := 48.0
## 下排放大倍数（仅用于辨认，不参与判定；2× 是为了整行塞进 720 宽）
const ZOOM := 2.0
const BG := Color(0.93, 0.91, 0.87)
const INK := Color(0.24, 0.20, 0.17)

const ITEMS := [
	{"path": Art.ENEMY_CUP, "name": "纸屑"},
	{"path": Art.ENEMY_CUP_FAST, "name": "纸鸢"},
	{"path": Art.ENEMY_BAG, "name": "傀儡"},
	{"path": Art.ELITE_BOX, "name": "墨渍"},
	{"path": Art.ELITE_RED, "name": "残面傩"},
	{"path": Art.REAPER, "name": "Boss"},
]

var _sv: SubViewport
## 上排（真实 48px）每一格的屏幕区域，供两两 IoU 复用
var _cells: Array[Rect2i] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_sv = SubViewport.new()
	_sv.size = Vector2i(720, 400)
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sv)

	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(720, 400)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sv.add_child(bg)

	_label("48px 剪影可辨识度", Vector2(0, 26), Vector2(720, 26), 18, INK)
	_label("上排 = 判定尺寸（真实 48×48）　下排 = 2× 放大，仅供辨认",
		Vector2(0, 54), Vector2(720, 20), 13, Color(0.38, 0.33, 0.28))
	_label("判定问题：只看上排，能否在 1 秒内把 6 个轮廓两两分开？",
		Vector2(0, 76), Vector2(720, 20), 13, Color(0.38, 0.33, 0.28))

	# ---- 上排：真实判定尺寸
	var n: int = ITEMS.size()
	var gap := 30.0
	var row_w: float = float(n) * CELL + float(n - 1) * gap
	var x0: float = (720.0 - row_w) * 0.5
	var y1 := 122.0
	for i in n:
		var it: Dictionary = ITEMS[i]
		var x: float = x0 + float(i) * (CELL + gap)
		_cells.append(Rect2i(Vector2i(int(x), int(y1)), Vector2i(int(CELL), int(CELL))))
		_cell(String(it["path"]), Vector2(x, y1), CELL, false)
		_label(String(it["name"]), Vector2(x - 12.0, y1 + CELL + 6.0), Vector2(CELL + 24.0, 16.0),
			12, INK)

	# ---- 下排：2× 放大（只用于辨认）
	var cell2: float = CELL * ZOOM
	var gap2 := 18.0
	var row_w2: float = float(n) * cell2 + float(n - 1) * gap2
	var x2: float = (720.0 - row_w2) * 0.5
	var y2 := 232.0
	for i in n:
		var it: Dictionary = ITEMS[i]
		var x: float = x2 + float(i) * (cell2 + gap2)
		_cell(String(it["path"]), Vector2(x, y2), cell2, true)
		_label(String(it["name"]), Vector2(x - 12.0, y2 + cell2 + 5.0), Vector2(cell2 + 24.0, 16.0),
			12, INK)

	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw

	var img: Image = _sv.get_texture().get_image()
	var err: int = img.save_png(OUT_1X)
	print("SILHOUETTE %s err=%d size=%s（1 单位 = 1 像素）" % [
		ProjectSettings.globalize_path(OUT_1X), err, str(img.get_size())])

	# 只裁上排（含标签）= 判定区。看这张，避免被放大版带偏
	var cx: int = maxi(0, int(x0) - 12)
	var cy: int = maxi(0, int(y1) - 10)
	var cw: int = mini(720 - cx, int(row_w) + 24)
	var ch: int = mini(400 - cy, int(CELL) + 34)
	var crop: Image = img.get_region(Rect2i(cx, cy, cw, ch))
	# 4× 最近邻放大存一份，方便在任意看图器里逐轮廓检查
	var big: Image = crop.duplicate()
	big.resize(cw * 4, ch * 4, Image.INTERPOLATE_NEAREST)
	var err2: int = big.save_png(OUT_2X)
	print("SILHOUETTE_48 %s err=%d size=%s" % [
		ProjectSettings.globalize_path(OUT_2X), err2, str(big.get_size())])

	_report_iou(img)

	get_tree().quit()

## 两两 IoU（交并比）：把"6 个轮廓能不能分开"从纯主观变成**有排序的主观**。
## AI 仍然不替人判定"1 秒内能不能认出"，但可以先告出"最像的是哪一对"，
## 让人只看那一对就够了，而不是对着 15 对平均用力。
## 阈值参考：IoU > 0.75 基本等于同一块墨团；0.55~0.75 需要靠细节区分；< 0.4 轮廓本身就能分开。
func _report_iou(img: Image) -> void:
	var masks: Array[PackedByteArray] = []
	for rc in _cells:
		var w: int = rc.size.x
		var h: int = rc.size.y
		var m := PackedByteArray()
		m.resize(w * h)
		for y in h:
			for x in w:
				# 背景是米白（亮度 ~0.91），剪影与投影都是近黑；0.55 是两者之间的大空档
				var c: Color = img.get_pixel(rc.position.x + x, rc.position.y + y)
				m[y * w + x] = 1 if c.get_luminance() < 0.55 else 0
		masks.append(m)

	var pairs: Array = []
	for i in masks.size():
		for j in range(i + 1, masks.size()):
			var inter := 0
			var uni := 0
			for k in masks[i].size():
				var a: int = masks[i][k]
				var b: int = masks[j][k]
				if a == 1 or b == 1:
					uni += 1
				if a == 1 and b == 1:
					inter += 1
			var iou: float = float(inter) / float(maxi(uni, 1))
			pairs.append({"a": String(ITEMS[i]["name"]), "b": String(ITEMS[j]["name"]), "iou": iou})
	pairs.sort_custom(func(p, q): return float(p["iou"]) > float(q["iou"]))

	print("\n---------- 剪影两两 IoU（从高到低，越高越像）----------")
	for p in pairs:
		print("  %-6s vs %-6s  IoU %.3f%s" % [
			String(p["a"]), String(p["b"]), float(p["iou"]),
			"   ← 优先人工确认" if float(p["iou"]) > 0.70 else ""])
	var worst: Dictionary = pairs[0]
	print("最像的一对：%s / %s（IoU %.3f）—— 人工过目时只需重点看这一对" % [
		String(worst["a"]), String(worst["b"]), float(worst["iou"])])


## 纯黑填充：modulate 把 RGB 乘成 0，alpha 保留 —— 得到的正是"只剩轮廓"的剪影
func _cell(path: String, pos: Vector2, side: float, border: bool) -> void:
	if border:
		# 放大版加一条极淡的框，只为让 6 格边界清楚，不影响轮廓本身
		var b := ColorRect.new()
		b.color = Color(0.82, 0.80, 0.76)
		b.position = pos - Vector2(1, 1)
		b.size = Vector2(side + 2.0, side + 2.0)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sv.add_child(b)
	var t := TextureRect.new()
	t.texture = Art.tex(path)
	# ⚠️ 顺序有讲究：必须**先**设 expand_mode，再设 size。
	# 反过来的话，size 会被当时的"最小尺寸 = 贴图尺寸"夹住（96/160 的精英与 Boss
	# 会撑成原尺寸、把相邻格子和标签全压掉），之后再改 expand_mode 也收不回来。
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = Vector2(side, side)
	t.modulate = Color(0, 0, 0, 1)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sv.add_child(t)

func _label(text: String, pos: Vector2, sz: Vector2, font_size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sv.add_child(l)
