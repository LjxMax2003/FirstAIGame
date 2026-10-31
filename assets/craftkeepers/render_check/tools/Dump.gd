extends SceneTree

const CELL_W: int = 200
const CELL_H: int = 160
const COLS: int = 7


func _walk(dir: String, out: Array) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if not n.begins_with("."):
			var p: String = dir.path_join(n)
			if d.current_is_dir():
				_walk(p, out)
			elif n.ends_with(".svg"):
				out.append(p)
		n = d.get_next()
	d.list_dir_end()
	out.sort()


func _cell(items: Array, path: String, bg: Color) -> void:
	var rows: int = ceil(items.size() / float(COLS))
	var img: Image = Image.create(COLS * CELL_W, rows * CELL_H, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in items.size():
		var f: String = items[i][0]
		var t: Texture2D = items[i][1]
		var src: Image = t.get_image()
		src.convert(Image.FORMAT_RGBA8)
		var w: int = src.get_width()
		var h: int = src.get_height()
		if w > CELL_W - 8 or h > CELL_H - 8:
			var s: float = min(float(CELL_W - 8) / float(w), float(CELL_H - 8) / float(h))
			src.resize(maxi(1, int(w * s)), maxi(1, int(h * s)), Image.INTERPOLATE_LANCZOS)
		var x: int = (i % COLS) * CELL_W + int((CELL_W - src.get_width()) / 2.0)
		var y: int = floori(float(i) / float(COLS)) * CELL_H + int((CELL_H - src.get_height()) / 2.0)
		img.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))
	var err: int = img.save_png(path)
	print("sheet %s -> %s (%d cells)" % [path, "ok" if err == OK else str(err), items.size()])


func _big(items: Array, path: String, bg: Color) -> void:
	var n: int = maxi(items.size(), 1)
	var img: Image = Image.create(n * 372, 660, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in items.size():
		var t: Texture2D = items[i][1]
		var src: Image = t.get_image()
		src.convert(Image.FORMAT_RGBA8)
		src.resize(360, 640, Image.INTERPOLATE_LANCZOS)
		img.blend_rect(src, Rect2i(0, 0, 360, 640), Vector2i(i * 372 + 6, 10))
	var err: int = img.save_png(path)
	print("big %s -> %s" % [path, "ok" if err == OK else str(err)])


func _init() -> void:
	var files: Array = []
	_walk("res://art", files)
	print("svg found: %d" % files.size())
	var small: Array = []
	var big: Array = []
	for f in files:
		var t: Texture2D = load(f)
		if t == null:
			push_error("load failed: " + f)
			continue
		print("  %-52s %dx%d" % [f, t.get_width(), t.get_height()])
		if t.get_width() >= 700:
			big.append([f, t])
		else:
			small.append([f, t])
	_cell(small, "res://sheet_dark.png", Color(0.055, 0.086, 0.141))
	_cell(small, "res://sheet_light.png", Color(0.90, 0.86, 0.78))
	_big(big, "res://sheet_bg.png", Color(0.055, 0.086, 0.141))
	quit()
