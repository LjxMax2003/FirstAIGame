extends SceneTree

# 校核用：把 L1 的 5 个母图 + 各自 2 张帧图放大 4 倍排成条带，并给出帧间差异像素占比。
const ZOOM: int = 4
const GAP: int = 6
const GROUPS: Array = [
	"characters/shouyiren_front.svg",
	"characters/shouyiren_back.svg",
	"enemies/paper_scrap.svg",
	"enemies/broken_kite.svg",
	"enemies/broken_puppet.svg",
]


func _tex_img(path: String) -> Image:
	var t: Texture2D = load(path)
	if t == null:
		push_error("load failed: " + path)
		return null
	var src: Image = t.get_image()
	src.convert(Image.FORMAT_RGBA8)
	return src


func _diff(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return -1.0
	var n: int = 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixelv(Vector2i(x, y)) != b.get_pixelv(Vector2i(x, y)):
				n += 1
	return 100.0 * float(n) / float(a.get_width() * a.get_height())


func _init() -> void:
	var per_row: Array = []
	var row_h: int = 0
	for g in GROUPS:
		var stem: String = g.get_basename()
		var files: Array = [g, stem + "_2.svg", stem + "_3.svg"]
		files = files.map(func(rel): return "res://art/" + rel)
		var imgs: Array = []
		for f in files:
			var im: Image = _tex_img(f)
			imgs.append(im)
			if im != null:
				row_h = maxi(row_h, im.get_height())
		per_row.append([files, imgs])

	var cols: int = 3
	var cell_w: int = 0
	for r in per_row:
		for im in r[1]:
			if im != null:
				cell_w = maxi(cell_w, im.get_width())
	var cw: int = cell_w * ZOOM + GAP
	var ch: int = row_h * ZOOM + GAP
	var img: Image = Image.create(cols * cw + GAP, per_row.size() * ch + GAP, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.055, 0.086, 0.141))

	for ri in per_row.size():
		var base: Image = per_row[ri][1][0]
		for ci in cols:
			var src: Image = per_row[ri][1][ci]
			if src == null:
				continue
			var big: Image = src.duplicate()
			big.resize(src.get_width() * ZOOM, src.get_height() * ZOOM, Image.INTERPOLATE_LANCZOS)
			img.blend_rect(big, Rect2i(0, 0, big.get_width(), big.get_height()), Vector2i(GAP + ci * cw, GAP + ri * ch))
			if ci > 0:
				var d: float = _diff(base, src)
				print("%-22s frame%d  diff=%.1f%%" % [per_row[ri][0][ci].get_file(), ci, d])

	var err: int = img.save_png("res://frames_l1.png")
	print("framesheet -> %s (%dx%d)" % ["ok" if err == OK else str(err), img.get_width(), img.get_height()])
	quit()
