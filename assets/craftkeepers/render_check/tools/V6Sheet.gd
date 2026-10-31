extends SceneTree

## 《守艺人·百工夜行》v6 觉醒美术资产 —— Godot 4.7.2 headless 实机光栅校核
## 依据 docs/design/v6_fx_art_plan.md §8 + docs/design/v6_fx_art_manifest.json new_art
## 产出：v6_dark.png / v6_light.png / v6_silhouette.png / v6_ingame.png + 断言

const V6 := [
	{"p": "res://art6/ui/awaken_badge.svg", "w": 64, "h": 32, "cls": "ui", "id": "awaken_badge"},
	{"p": "res://art6/fx/molten_blob.svg", "w": 24, "h": 24, "cls": "hot", "id": "molten_blob"},
	{"p": "res://art6/weapons/ink_line_tex.svg", "w": 256, "h": 8, "cls": "tile", "id": "ink_line_tex"},
	{"p": "res://art6/fx/woodblock_seal.svg", "w": 160, "h": 160, "cls": "decal", "id": "woodblock_seal"},
]

const MOB := "res://art6/enemies/paper_scrap.svg"
const PLAYER := "res://art6/characters/shouyiren_front.svg"
const CARD := "res://art6/ui/ui_paper_card.svg"
const LADLE := "res://art6/weapons/iron_flower_ladle.svg"
const PRINT := "res://art6/weapons/woodblock_print.svg"
const INKLINE := "res://art6/weapons/inkline.svg"
const BADGE := "res://art6/ui/awaken_badge.svg"
const BLOB := "res://art6/fx/molten_blob.svg"
const SPARK := "res://art6/fx/gold_spark_fx.svg"
const LINE := "res://art6/weapons/ink_line_tex.svg"
const SEAL := "res://art6/fx/woodblock_seal.svg"

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


func _peak(img: Image, rect: Rect2i = Rect2i(0, 0, -1, -1)) -> Array:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := img.get_width() if rect.end.x < 0 else rect.end.x
	var y1 := img.get_height() if rect.end.y < 0 else rect.end.y
	var peak := 0.0
	var at := Vector2i(-1, -1)
	var sum := 0.0
	var n := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var a: float = img.get_pixelv(Vector2i(x, y)).a
			sum += a
			n += 1
			if a > peak:
				peak = a
				at = Vector2i(x, y)
	return [peak, at, (sum / float(max(1, n)))]


# ---------- 1. 实测画布（独立于生成器声明）----------
func _sizes() -> void:
	print("\n[1] 实测画布 = v6_fx_art_manifest.json new_art 的 size")
	for e in V6:
		var img: Image = _img(e["p"])
		if img == null:
			continue
		_chk(img.get_width() == e["w"] and img.get_height() == e["h"],
			"%-22s %dx%d（清单 %dx%d）" % [e["p"].get_file(), img.get_width(), img.get_height(), e["w"], e["h"]])


# ---------- 2. 边缘裁切：除墨线（左右要平铺）外，四边必须留透明余量 ----------
func _bleed() -> void:
	print("\n[2] 画布边缘未被裁（ThorVG 描边外凸 ~1px，裁了就是硬切边）")
	for e in V6:
		var img: Image = _img(e["p"])
		if img == null:
			continue
		var w := img.get_width()
		var h := img.get_height()
		var lr_ok: bool = (e["cls"] == "tile")  # 墨线左右贯通 = 平铺设计，允许出血
		var top := 0.0
		var bot := 0.0
		var lef := 0.0
		var rig := 0.0
		for x in w:
			top = maxf(top, img.get_pixelv(Vector2i(x, 0)).a)
			bot = maxf(bot, img.get_pixelv(Vector2i(x, h - 1)).a)
		for y in h:
			lef = maxf(lef, img.get_pixelv(Vector2i(0, y)).a)
			rig = maxf(rig, img.get_pixelv(Vector2i(w - 1, y)).a)
		_chk(top <= 0.02 and bot <= 0.02,
			"%-20s 上下边缘 %.3f/%.3f <=0.02" % [e["p"].get_file(), top, bot])
		if lr_ok:
			print("      %-20s 左右出血 %.3f/%.3f（平铺条，贯通设计，不判 FAIL）" % [e["p"].get_file(), lef, rig])
		else:
			_chk(lef <= 0.02 and rig <= 0.02,
				"%-20s 左右边缘 %.3f/%.3f <=0.02" % [e["p"].get_file(), lef, rig])


# ---------- 3. alpha 分级：角标要实、光团要中心亮、平铺条要实、雕版印要压得住地面 ----------
func _alpha() -> void:
	print("\n[3] alpha 分级断言")
	for e in V6:
		var img: Image = _img(e["p"])
		if img == null:
			continue
		var r: Array = _peak(img)
		var peak: float = r[0]
		var mean: float = r[2]
		var name: String = e["p"].get_file()
		match e["cls"]:
			"ui":
				_chk(peak >= 0.85, "%-20s 峰值 %.3f >=0.85（角标本体要读得出）" % [name, peak])
				_chk(mean <= 0.75, "%-20s 平均 %.3f <=0.75（盖在纸上的半透明朱印，卡面纸纹透得出来）" % [name, mean])
			"hot":
				_chk(peak >= 0.85, "%-20s 熔核峰值 %.3f >=0.85（加法混合下 alpha 即亮度）" % [name, peak])
				var ring_sum := 0.0
				var ring_peak := 0.0
				var ring_n := 0
				for y in img.get_height():
					for x in img.get_width():
						if Vector2(x - 11.5, y - 11.5).length() >= 9.0:
							var a: float = img.get_pixelv(Vector2i(x, y)).a
							ring_sum += a
							ring_n += 1
							ring_peak = maxf(ring_peak, a)
				var ring_mean: float = ring_sum / float(max(1, ring_n))
				_chk(ring_mean <= 0.16,
					"%-20s 外圈 r>=9 平均 %.3f <=0.16（光晕衰减软；峰值 %.2f 是甩出的铁水星子，允许）"
					% [name, ring_mean, ring_peak])
				var c0: Color = img.get_pixelv(Vector2i(10, 10))
				var c1: Color = img.get_pixelv(Vector2i(21, 3))
				var lum0: float = (c0.r * 0.3 + c0.g * 0.59 + c0.b * 0.11) * c0.a
				var lum1: float = (c1.r * 0.3 + c1.g * 0.59 + c1.b * 0.11) * c1.a
				_chk(lum0 > lum1, "中心亮度 %.3f > 边缘 %.3f（铁水团是核亮边暗，不是均匀橙饼）" % [lum0, lum1])
			"tile":
				_chk(peak >= 0.85, "%-20s 峰值 %.3f >=0.85（墨线要压得住地面）" % [name, peak])
			"decal":
				_chk(peak <= 0.85, "%-20s 峰值 %.3f <=0.85（雕版印叠在敌人与地面上，不能变成不透明方块）" % [name, peak])
				var core := 0.0
				for y in img.get_height():
					for x in img.get_width():
						if Vector2(x - 80.0, y - 80.0).length() <= 14.0:
							core = maxf(core, img.get_pixelv(Vector2i(x, y)).a)
				_chk(core >= 0.25, "%-20s 中心 r<=14 峰值 %.3f >=0.25（莲蓬要压得出来，不是空心圈）" % [name, core])
				print("      %-20s 平均 alpha %.3f" % [name, mean])


# ---------- 4. 墨线平铺契约：接缝跳变不得高于内部相邻列跳变 ----------
func _tileability() -> void:
	print("\n[4] ink_line_tex 横向平铺（周期 64，256 = 4 周期）")
	var img: Image = _img(LINE)
	var h := img.get_height()
	var seam := 0.0
	var inner := 0.0
	var worst := Vector2i(-1, -1)
	for y in h:
		var d_seam: float = absf(img.get_pixelv(Vector2i(255, y)).a - img.get_pixelv(Vector2i(0, y)).a)
		seam += d_seam
		for x in range(1, 256):
			var d: float = absf(img.get_pixelv(Vector2i(x, y)).a - img.get_pixelv(Vector2i(x - 1, y)).a)
			if d > inner:
				inner = d
				worst = Vector2i(x, y)
	seam /= float(h)
	# 同一条纹样周期内的最大相邻列跳变，就是「接缝处允许有的最大跳变」
	_chk(seam <= maxf(inner * 1.15, inner + 0.02),
		"接缝列均跳变 %.4f <= 内部最大跳变 %.4f @%s（平铺不露缝）" % [seam, inner, worst])
	# 周期一致性：x 与 x+64 的 alpha 应几乎相等
	var per := 0.0
	for y in h:
		for x in range(0, 192):
			per = maxf(per, absf(img.get_pixelv(Vector2i(x, y)).a - img.get_pixelv(Vector2i(x + 64, y)).a))
	_chk(per <= 0.08, "周期 64 自相似最大偏差 %.3f <=0.08（拉长/平铺后结节间距一致）" % per)
	# 上下留边：线本体不能贴死 0/7 行，否则平铺成一片糊
	_chk(img.get_pixelv(Vector2i(128, 0)).a <= 0.02 and img.get_pixelv(Vector2i(128, 7)).a <= 0.02,
		"首末行透明（线本体在 y1.5..6.5，Lv8 用 scale.y 加粗不会立刻糊成一条带）")


# ---------- 5. 角标对卡面的叠加契约（清单：叠在卡面右上角，非 Lv8 隐藏）----------
func _badge_on_card() -> void:
	print("\n[5] awaken_badge 叠 ui_paper_card 右上角的契约")
	var card: Image = _copy(_img(CARD))
	var badge: Image = _img(BADGE)
	_chk(card.get_width() == 200 and card.get_height() == 280,
		"卡面 200x280（角标按原生 64x32 贴，不缩放）")
	var bx := 124
	var by := 14
	_chk(bx + badge.get_width() <= card.get_width() and by + badge.get_height() <= card.get_height(),
		"角标矩形 x%d..%d / y%d..%d 在卡面内" % [bx, bx + badge.get_width(), by, by + badge.get_height()])
	# 卡面纸面范围（实测）：木框 4..196 / 6..276，纸面 8..192 / 10..272，圆角 rx 5~7
	print("      卡面四角实测 alpha：TL(8,10)=%.2f TR(191,10)=%.2f 纸内(124,14)=%.2f" % [
		card.get_pixelv(Vector2i(8, 10)).a, card.get_pixelv(Vector2i(191, 10)).a,
		card.get_pixelv(Vector2i(124, 14)).a])
	# 5a 角标落处卡面得有纸
	var under_min := 1.0
	var under_at := Vector2i(-1, -1)
	for y in badge.get_height():
		for x in badge.get_width():
			if badge.get_pixelv(Vector2i(x, y)).a > 0.25:
				var ua: float = card.get_pixelv(Vector2i(bx + x, by + y)).a
				if ua < under_min:
					under_min = ua
					under_at = Vector2i(bx + x, by + y)
	_chk(under_min >= 0.8, "角标覆盖处卡面最低 alpha %.2f >=0.8 @%s（贴得住，不悬在透明区）" % [under_min, under_at])
	# 5b 不与卡面图标窗（工程实测 x68..132 / y96..160）相交
	_chk(by + badge.get_height() <= 96 or bx >= 132,
		"角标 y%d..%d 与图标窗 y96..160 不相交（不压武器图标）" % [by, by + badge.get_height()])
	# 5c 卡面文字位（下半截）不被侵入
	_chk(bx >= 120, "角标 x 起点 %d >=120，只在右上，不侵入卡面正文区" % bx)
	var comp: Image = _copy(card)
	_put(comp, _copy(badge), bx, by)
	var rb: Array = _peak(comp, Rect2i(bx, by, badge.get_width(), badge.get_height()))
	_chk(rb[0] >= 0.9, "叠加后角标区峰值 %.3f >=0.90（在纸面上仍然跳出来）" % rb[0])


# ---------- 6. 拼版（深/浅底，原生尺寸）----------
func _sheets() -> void:
	print("\n[6] 原生尺寸拼版")
	for bg_name in ["dark", "light"]:
		var cols := 4
		var sheet: Image = Image.create(cols * 272, 2 * 272, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.055, 0.086, 0.141) if bg_name == "dark" else Color(0.90, 0.86, 0.78))
		for i in V6.size():
			var img: Image = _copy(_img(V6[i]["p"]))
			var cx: int = (i % cols) * 272 + int((272 - img.get_width()) / 2.0)
			var cy: int = int(i / cols) * 272 + int((272 - img.get_height()) / 2.0)
			_put(sheet, img, cx, cy)
			print("      %-22s -> 格 %d,%d" % [V6[i]["p"].get_file(), i % cols, int(i / cols)])
		# 第二行：对照组 —— 现用弹体 sugar_thread / gold_spark，看替换前后主题差
		_put(sheet, _copy(_img(SPARK)), 16, 300)
		_put(sheet, _copy(_img("res://art6/weapons/sugar_thread.svg")), 80, 340)
		_put(sheet, _copy(_img(BLOB)), 150, 300)
		_put(sheet, _copy(_img(LADLE)), 200, 380)
		_put(sheet, _scaled(SEAL, 160, 160), 300, 290)
		_put(sheet, _scaled(PRINT, 120, 120), 470, 310)
		var err := sheet.save_png("res://v6_%s.png" % bg_name)
		_chk(err == OK, "v6_%s.png（4 张主角 + 对照组）" % bg_name)


# ---------- 7. 小尺寸剪影 ----------
func _silhouette() -> void:
	print("\n[7] 实机尺度剪影")
	var sheet: Image = Image.create(560, 3 * 132 + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.93, 0.91, 0.86))
	# 行 1：角标 原生 / 0.75 / 0.5（卡面缩到 3/4 时角标是否还读得出）
	_put(sheet, _copy(_img(BADGE)), 8, 8)
	_put(sheet, _scaled(BADGE, 48, 24), 80, 12)
	_put(sheet, _scaled(BADGE, 32, 16), 140, 16)
	var s4: Image = _copy(_img(BADGE))
	_black(s4)
	_put(sheet, s4, 180, 8)
	# 行 2：铁水团 原生 24 / 放大 40 / 缩小 16
	_put(sheet, _copy(_img(BLOB)), 8, 70)
	_put(sheet, _scaled(BLOB, 40, 40), 44, 62)
	_put(sheet, _scaled(BLOB, 16, 16), 92, 74)
	# 行 2 右：墨线原生 256×8 与 Lv8 加粗 scale.y=1.75
	_put(sheet, _copy(_img(LINE)), 120, 78)
	_put(sheet, _scaled(LINE, 256, 14), 120, 96)
	# 行 3：墨线两段相接 = 平铺接缝的肉眼位（x=0 与 x=256 处）
	_put(sheet, _copy(_img(LINE)), 8, 170)
	_put(sheet, _copy(_img(LINE)), 264, 170)
	_put(sheet, _scaled(LINE, 512, 8), 8, 186)
	# 行 3 右下一：雕版印 160 原生 / 100（落点预显缩小态）
	_put(sheet, _copy(_img(SEAL)), 392, 210)
	var err := sheet.save_png("res://v6_silhouette.png")
	_chk(err == OK, "v6_silhouette.png")


func _black(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixelv(Vector2i(x, y))
			img.set_pixelv(Vector2i(x, y), Color(0, 0, 0, 1.0) if c.a > 0.18 else Color(0, 0, 0, 0))


# ---------- 8. 实机尺度合成（720 竖屏短边归一化）----------
func _ingame() -> void:
	print("\n[8] 实机尺度合成（720x1120 竖屏切片）")
	var W := 720
	var H := 1120
	var sheet: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.043, 0.067, 0.11))
	var player: Image = _scaled(PLAYER, 64, 80)
	var mob: Image = _scaled(MOB, 48, 48)

	# A：Lv8 三选一卡面 —— 第一张挂觉醒角标，后两张不挂（对照「非 Lv8 隐藏」）
	for i in 3:
		var card: Image = _scaled(CARD, 200, 280)
		var icon: String = ["res://art6/weapons/extinguisher_evolved.svg",
			"res://art6/weapons/gong.svg", "res://art6/weapons/woodblock_print.svg"][i]
		_put(card, _scaled(icon, 64, 64), 68, 96)
		if i == 0:
			_put(card, _copy(_img(BADGE)), 124, 14)
		if i == 1:
			_put(card, _copy(_img("res://art6/ui/refine_badge.svg")), 168, 8)
		_put(sheet, card, 20 + i * 216, 16)
	# B：打铁花 —— 铁水团飞向敌群（24 原生），碎裂点 molten_scatter 由 shader 出（此处留空）
	for m in [[120, 380], [210, 420], [60, 430], [260, 360]]:
		_put(sheet, mob, 20 + m[0], 320 + m[1])
	_put(sheet, _scaled(LADLE, 80, 80), 30, 360)
	_put(sheet, _copy(_img(BLOB)), 150, 400)
	_put(sheet, _scaled(BLOB, 24, 24), 240, 430)
	# C：墨斗 —— 龙筋墨线沿玩家→目标 拉长 460，Lv8 加粗版在下
	_put(sheet, player, 20, 500)
	_put(sheet, _scaled(LINE, 460, 8), 76, 524)
	for i in 4:
		_put(sheet, mob, 150 + i * 80, 508)
	_put(sheet, _scaled(LINE, 460, 14), 76, 588)
	# D：年画 —— 雕版印先落（落点预显），年画本体压在其上，旁边一只小怪
	var seal: Image = _copy(_img(SEAL))
	_put(sheet, seal, 500, 700)
	_put(sheet, _scaled(PRINT, 120, 120), 520, 720)
	_put(sheet, mob, 556, 780)
	_put(sheet, _scaled(SEAL, 100, 100), 330, 740)
	_put(sheet, _scaled(PRINT, 76, 76), 342, 752)
	# E：铜锣/花灯本体不重复出图，这里放「角标 + 徽标 + 光团」的 HUD 一条
	_put(sheet, _copy(_img(BADGE)), 20, 900)
	_put(sheet, _copy(_img("res://art6/ui/refine_badge.svg")), 90, 904)
	_put(sheet, _copy(_img(BLOB)), 120, 904)
	_put(sheet, _copy(_img(SPARK)), 150, 896)
	_put(sheet, _scaled("res://art6/weapons/lantern_halo.svg", 120, 120), 220, 860)
	var err := sheet.save_png("res://v6_ingame.png")
	_chk(err == OK, "v6_ingame.png")


func _init() -> void:
	_sizes()
	_bleed()
	_alpha()
	_tileability()
	_badge_on_card()
	_sheets()
	_silhouette()
	_ingame()
	print("\n== v6 校核：%s（fail=%d）" % ["ALL PASS" if fail_count == 0 else "HAS FAILURE", fail_count])
	quit(1 if fail_count > 0 else 0)
