extends SceneTree

## 《守艺人·百工夜行》v5 新增 12 张资产 —— Godot 4.7.2 headless 实机光栅校核
## 依据 docs/design/art_assets_manifest.json §「constraints」+ v4 校核口径 §7.2
## 产出：v5_dark.png / v5_light.png / v5_silhouette.png / v5_ingame.png + 断言

const V5 := [
	{"p": "res://art5/weapons/gong.svg", "w": 96, "h": 96, "cls": "world", "id": "weapon_gong"},
	{"p": "res://art5/weapons/inkline.svg", "w": 220, "h": 16, "cls": "world", "id": "weapon_inkline"},
	{"p": "res://art5/weapons/woodblock_print.svg", "w": 120, "h": 120, "cls": "world", "id": "weapon_print"},
	{"p": "res://art5/items/passive_regen.svg", "w": 64, "h": 64, "cls": "card", "id": "passive_regen"},
	{"p": "res://art5/items/passive_shield.svg", "w": 64, "h": 64, "cls": "card", "id": "passive_shield"},
	{"p": "res://art5/ui/skill_roar.svg", "w": 96, "h": 96, "cls": "ui", "id": "ui_skill_roar"},
	{"p": "res://art5/enemies/shell_crust.svg", "w": 48, "h": 48, "cls": "overlay", "id": "enemy_shell_crust"},
	{"p": "res://art5/weapons/gong_evolved.svg", "w": 96, "h": 96, "cls": "world", "id": "weapon_gong_evolved"},
	{"p": "res://art5/weapons/inkline_evolved.svg", "w": 220, "h": 18, "cls": "world", "id": "weapon_inkline_evolved"},
	{"p": "res://art5/weapons/extinguisher_evolved.svg", "w": 80, "h": 80, "cls": "world", "id": "weapon_extinguisher_evolved"},
	{"p": "res://art5/fx/surge_ring.svg", "w": 256, "h": 256, "cls": "ground", "id": "fx_surge_telegraph"},
	{"p": "res://art5/ui/refine_badge.svg", "w": 24, "h": 24, "cls": "ui", "id": "ui_refine_badge"},
]

const MOB := "res://art5/enemies/paper_scrap.svg"
const PLAYER := "res://art5/characters/shouyiren_front.svg"
const CARD := "res://art5/ui/ui_paper_card.svg"
const LADLE := "res://art5/weapons/iron_flower_ladle.svg"

var fail_count: int = 0
var cache: Dictionary = {}


func _img(p: String) -> Image:
	if cache.has(p):
		return cache[p]
	var t: Texture2D = load(p)
	if t == null:
		print("ASSERT FAIL load: " + p)
		fail_count += 1
		return null
	var img: Image = t.get_image()
	img.convert(Image.FORMAT_RGBA8)
	cache[p] = img
	return img


func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("  ok    %s" % msg)
	else:
		print("  FAIL  %s" % msg)
		fail_count += 1


func _copy(img: Image) -> Image:
	var c: Image = img.duplicate()
	c.convert(Image.FORMAT_RGBA8)
	return c


func _scaled(p: String, w: int, h: int) -> Image:
	var src: Image = _copy(_img(p))
	src.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return src


func _put(sheet: Image, img: Image, x: int, y: int) -> void:
	sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, y))


func _peak(img: Image) -> Array:
	var peak := 0.0
	var at := Vector2i(-1, -1)
	var solid := 0
	for y in img.get_height():
		for x in img.get_width():
			var a: float = img.get_pixelv(Vector2i(x, y)).a
			if a > peak:
				peak = a
				at = Vector2i(x, y)
			if a >= 0.5:
				solid += 1
	return [peak, at, solid]


# ---------- 1. 实测画布（独立于生成器声明）----------
func _sizes() -> void:
	print("\n[1] 实测画布 = 清单 suggested_path 的 size_hint")
	for e in V5:
		var img: Image = _img(e["p"])
		if img == null:
			continue
		_chk(img.get_width() == e["w"] and img.get_height() == e["h"],
			"%-26s %dx%d（清单 %dx%d）" % [e["p"].get_file(), img.get_width(), img.get_height(), e["w"], e["h"]])


# ---------- 2. alpha：实体贴图要够实、地面预警层要够虚 ----------
func _alpha() -> void:
	print("\n[2] alpha 峰值（实体 >=0.85；地面预警 <=0.85 且中心留空）")
	for e in V5:
		var img: Image = _img(e["p"])
		if img == null:
			continue
		var r: Array = _peak(img)
		var peak: float = r[0]
		if e["cls"] == "ground":
			_chk(peak <= 0.85, "%-24s 峰值 %.3f <=0.85 @%s" % [e["p"].get_file(), peak, r[1]])
			var hole := 0.0
			for y in img.get_height():
				for x in img.get_width():
					if Vector2(x - 128.0, y - 128.0).length() <= 26.0:
						var a: float = img.get_pixelv(Vector2i(x, y)).a
						if a > hole:
							hole = a
			_chk(hole <= 0.06, "%-24s 中心 r<=26 最大 alpha %.3f <=0.06（涌怪要站在圈里）" % [e["p"].get_file(), hole])
			var ext := 0.0
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixelv(Vector2i(x, y)).a >= 0.05:
						var d: float = Vector2(x - 128.0, y - 128.0).length()
						if d > ext:
							ext = d
			# ThorVG 圆弧描边会多边形化外凸 ~1px，外缘必须留透明余量，否则被画布裁掉
			_chk(ext <= 127.6, "%-24s 外缘 r=%.1f <=127.6（不被画布裁）" % [e["p"].get_file(), ext])
		elif e["cls"] == "overlay":
			_chk(peak >= 0.85, "%-24s 壳层峰值 %.3f >=0.85（叠在母图上要读得出「厚壳」）" % [e["p"].get_file(), peak])
		else:
			_chk(peak >= 0.85, "%-24s 峰值 %.3f >=0.85 @%s" % [e["p"].get_file(), peak, r[1]])
		_chk(r[2] > 0, "%-24s 实心像素 %d 个" % [e["p"].get_file(), r[2]])


# ---------- 3. 浆壳 overlay 的对齐契约（清单 note：锚点/朝向必须与 paper_scrap 一致）----------
func _overlay_contract() -> void:
	print("\n[3] shell_crust 叠加契约（对 paper_scrap）")
	var base: Image = _img(MOB)
	var ov: Image = _img("res://art5/enemies/shell_crust.svg")
	_chk(base.get_width() == ov.get_width() and base.get_height() == ov.get_height(),
		"画布与母图一致 %dx%d（overlay 直接叠，不需要工程侧对位）" % [ov.get_width(), ov.get_height()])
	# 3a 眼窗必须让开：母图双眼 x[16.9,31.1] y[21.6,28.4]
	var eye_peak := 0.0
	var eye_at := Vector2i(-1, -1)
	for y in range(22, 29):
		for x in range(17, 32):
			var a: float = ov.get_pixelv(Vector2i(x, y)).a
			if a > eye_peak:
				eye_peak = a
				eye_at = Vector2i(x, y)
	_chk(eye_peak <= 0.02, "眼窗 x17..31 / y22..28 最大 alpha %.3f <=0.02 @%s（不把母图眼洞糊掉）" % [eye_peak, eye_at])
	# 3b 不得越出母图轮廓
	var outside := 0
	var worst := Vector2i(-1, -1)
	for y in ov.get_height():
		for x in ov.get_width():
			if ov.get_pixelv(Vector2i(x, y)).a > 0.05 and base.get_pixelv(Vector2i(x, y)).a < 0.05:
				outside += 1
				worst = Vector2i(x, y)
	_chk(outside <= 24, "越出母图轮廓的像素 %d 个（<=24 抗锯齿容差），最差 @%s" % [outside, worst])
	# 3c 脚底不动：碰撞体/走路帧按脚底对齐，overlay 不能加东西
	var foot := 0.0
	for y in range(45, 48):
		for x in ov.get_width():
			var a2: float = ov.get_pixelv(Vector2i(x, y)).a
			if a2 > foot:
				foot = a2
	_chk(foot <= 0.02, "脚底 y45..47 最大 alpha %.3f <=0.02（脚底与碰撞体不跳）" % foot)


# ---------- 4. 进化形态要和本体区分得开 ----------
func _evolution_diff() -> void:
	print("\n[4] 进化 vs 本体 可辨识差（同尺度中心对齐取公共区）")
	var pairs := [
		["res://art5/weapons/gong.svg", "res://art5/weapons/gong_evolved.svg", 0.08],
		["res://art5/weapons/inkline.svg", "res://art5/weapons/inkline_evolved.svg", 0.08],
		[LADLE, "res://art5/weapons/extinguisher_evolved.svg", 0.10],
	]
	for pr in pairs:
		var a: Image = _copy(_img(pr[0]))
		var b: Image = _copy(_img(pr[1]))
		if pr[0] == LADLE:
			a = _scaled(LADLE, 80, 80)
		var w: int = min(a.get_width(), b.get_width())
		var h: int = min(a.get_height(), b.get_height())
		var ox: int = int((a.get_width() - w) / 2)
		var oy: int = int((a.get_height() - h) / 2)
		var diff := 0
		var total := w * h
		for y in h:
			for x in w:
				var ca: Color = a.get_pixelv(Vector2i(ox + x, oy + y))
				var cb: Color = b.get_pixelv(Vector2i(x, y))
				var d: float = absf(ca.a - cb.a)
				if d < 0.25:
					d = 0.0
				var lum: float = absf(
					(ca.r * 0.3 + ca.g * 0.59 + ca.b * 0.11) * ca.a
					- (cb.r * 0.3 + cb.g * 0.59 + cb.b * 0.11) * cb.a)
				if d > 0.0 or lum > 0.12:
					diff += 1
		var ratio: float = diff / float(total)
		_chk(ratio >= float(pr[2]), "%s vs %s 差异占比 %.1f%%（>=%.0f%%，玩家一眼看得出进化过）"
			% [pr[0].get_file().get_basename(), pr[1].get_file().get_basename(), ratio * 100.0, float(pr[2]) * 100.0])


# ---------- 5. 拼版（深/浅底，原生尺寸）----------
func _sheets() -> void:
	print("\n[5] 原生尺寸拼版")
	for bg_name in ["dark", "light"]:
		var cols := 4
		var rows: int = int(ceil(V5.size() / float(cols)))
		var sheet: Image = Image.create(cols * 272, rows * 272, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.055, 0.086, 0.141) if bg_name == "dark" else Color(0.90, 0.86, 0.78))
		for i in V5.size():
			var img: Image = _copy(_img(V5[i]["p"]))
			var cx: int = (i % cols) * 272 + int((272 - img.get_width()) / 2.0)
			var cy: int = int(i / cols) * 272 + int((272 - img.get_height()) / 2.0)
			_put(sheet, img, cx, cy)
			print("      %-26s -> 格 %d,%d" % [V5[i]["p"].get_file(), i % cols, int(i / cols)])
		_chk(sheet.save_png("res://v5_%s.png" % bg_name) == OK, "v5_%s.png（%d 格）" % [bg_name, V5.size()])


# ---------- 6. 剪影：卡面 40px / HUD 徽标 24px / 敌人 48px ----------
func _silhouette() -> void:
	print("\n[6] 小尺寸剪影（卡面 40px、徽标 24px、脚底 48px）")
	var sheet: Image = Image.create(13 * 52 + 8, 3 * 132 + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.93, 0.91, 0.86))
	var row1 := ["res://art5/items/passive_regen.svg", "res://art5/items/passive_shield.svg",
		"res://art5/ui/skill_roar.svg", "res://art5/weapons/gong.svg",
		"res://art5/weapons/gong_evolved.svg", "res://art5/weapons/woodblock_print.svg",
		"res://art5/weapons/extinguisher_evolved.svg", "res://art5/weapons/iron_flower_ladle.svg"]
	for i in row1.size():
		var s: Image = _scaled(row1[i], 40, 40)
		_black(s)
		_put(sheet, s, 8 + i * 52, 8)
	# 行 1 右：徽标 24px 原生
	for i in 3:
		var s2: Image = _copy(_img("res://art5/ui/refine_badge.svg"))
		_black(s2)
		_put(sheet, s2, 8 + (i + 8) * 52 + 8, 8 + 8)
	# 行 2：母图 / 壳层 / 叠加后 三级 48px（壳层单独看只是「一块壳」，叠加后才是浆壳兵）
	_put(sheet, _scaled(MOB, 48, 48), 8, 68)
	_put(sheet, _scaled("res://art5/enemies/shell_crust.svg", 48, 48), 68, 68)
	var comp: Image = _scaled(MOB, 48, 48)
	_put(comp, _scaled("res://art5/enemies/shell_crust.svg", 48, 48), 0, 0)
	_put(sheet, comp, 128, 68)
	_put(sheet, _scaled(MOB, 96, 96), 196, 44)
	var comp2: Image = _scaled(MOB, 96, 96)
	_put(comp2, _scaled("res://art5/enemies/shell_crust.svg", 96, 96), 0, 0)
	_put(sheet, comp2, 300, 44)
	# 行 3：墨线两根原生高（16 / 18），看线在浅色底是否断得开
	_put(sheet, _scaled("res://art5/weapons/inkline.svg", 220, 16), 8, 176)
	_put(sheet, _scaled("res://art5/weapons/inkline_evolved.svg", 220, 18), 8, 200)
	_put(sheet, _scaled("res://art5/weapons/inkline.svg", 440, 32), 240, 176)
	var err := sheet.save_png("res://v5_silhouette.png")
	_chk(err == OK, "v5_silhouette.png")


func _black(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixelv(Vector2i(x, y))
			img.set_pixelv(Vector2i(x, y), Color(0, 0, 0, 1.0) if c.a > 0.18 else Color(0, 0, 0, 0))


# ---------- 7. 实机尺度合成（720 竖屏短边归一化）----------
func _ingame() -> void:
	print("\n[7] 实机尺度合成（720x1280 竖屏切片）")
	var W := 720
	var H := 1000
	var sheet: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.043, 0.067, 0.11))
	var player: Image = _scaled(PLAYER, 64, 80)
	var mob: Image = _scaled(MOB, 48, 48)
	var shelled: Image = _scaled(MOB, 48, 48)
	_put(shelled, _scaled("res://art5/enemies/shell_crust.svg", 48, 48), 0, 0)

	# A：铜锣本体绕玩家（判定半径 150，贴图原生 96）+ 浆壳兵群
	for m in [[110, 130], [180, 220], [70, 230], [240, 160], [150, 60]]:
		_put(sheet, mob if m[0] % 2 == 0 else shelled, 30 + m[0], 20 + m[1])
	_put(sheet, _scaled("res://art5/weapons/gong.svg", 96, 96), 30 + 214, 20 + 96)
	_put(sheet, _scaled("res://art5/weapons/gong_evolved.svg", 96, 96), 30 + 60, 20 + 40)
	_put(sheet, player, 30 + 148, 20 + 132)

	# B：木版年画落点（原生 120 砸在 105 半径区中心）+ 潮涌地面预警 300px
	var ring: Image = _scaled("res://art5/fx/surge_ring.svg", 300, 300)
	_put(sheet, ring, 400, 40)
	for m in [[455, 95], [530, 150], [430, 175], [565, 95], [500, 205]]:
		_put(sheet, shelled, m[0], m[1])
	_put(sheet, _scaled("res://art5/weapons/woodblock_print.svg", 120, 120), 490, 130)
	_put(sheet, player, 490, 210)

	# C：墨斗弹道原生 220×16 横穿敌群（飞行轴=长度方向）
	_put(sheet, _scaled("res://art5/weapons/inkline.svg", 440, 32), 20, 400)
	for i in 5:
		_put(sheet, shelled if i % 2 == 0 else mob, 110 + i * 88, 392)
	_put(sheet, player, 20, 376)
	# 进化龙筋墨线（更粗 + 描金 + 龙首）
	_put(sheet, _scaled("res://art5/weapons/inkline_evolved.svg", 440, 36), 20, 452)

	# D：打铁花本体 vs 百子千花（同尺度并排，看「繁密金红」）
	_put(sheet, _scaled(LADLE, 80, 80), 500, 430)
	_put(sheet, _scaled("res://art5/weapons/extinguisher_evolved.svg", 80, 80), 590, 430)

	# E：三选一卡面 —— 卡框 + 64×64 被动图标 + 卡角精炼徽标
	for i in 3:
		var card: Image = _scaled(CARD, 200, 280)
		var icon: String = ["res://art5/items/passive_regen.svg",
			"res://art5/items/passive_shield.svg", "res://art5/weapons/gong.svg"][i]
		_put(card, _scaled(icon, 64, 64), 68, 96)
		if i == 0:
			_put(card, _copy(_img("res://art5/ui/refine_badge.svg")), 168, 8)
		_put(sheet, card, 20 + i * 216, 540)

	# F：HUD 主动技按钮 96 原生 + 徽标 24 原生（右下摇杆位）
	_put(sheet, _copy(_img("res://art5/ui/skill_roar.svg")), 600, 880)
	_put(sheet, _copy(_img("res://art5/ui/refine_badge.svg")), 566, 880)
	_put(sheet, _scaled("res://art5/ui/skill_roar.svg", 40, 40), 600, 950)
	var err := sheet.save_png("res://v5_ingame.png")
	_chk(err == OK, "v5_ingame.png")


func _init() -> void:
	_sizes()
	_alpha()
	_overlay_contract()
	_evolution_diff()
	_sheets()
	_silhouette()
	_ingame()
	print("\n== v5 校核：%s（fail=%d）" % ["ALL PASS" if fail_count == 0 else "HAS FAILURE", fail_count])
	quit(1 if fail_count > 0 else 0)
