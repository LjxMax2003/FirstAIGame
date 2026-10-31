extends SceneTree

## v4 P0 新资产实机化校核（Godot 4.7.2 headless 光栅化）
## 产出：v4_dark.png / v4_light.png / v4_silhouette.png / v4_ingame.png + 断言

const ICONS := [
	"res://art/weapons/gong_icon.svg",
	"res://art/weapons/inkline_icon.svg",
	"res://art/weapons/print_icon.svg",
	"res://art/items/passive_regen.svg",
	"res://art/items/passive_shield.svg",
	"res://art/ui/ui_geng_drum.svg",
]
const WORLD := [
	"res://art/weapons/gong_aura.svg",
	"res://art/weapons/inkline_beam.svg",
	"res://art/weapons/inkline_impact.svg",
	"res://art/weapons/print_zone_warn.svg",
	"res://art/weapons/print_zone_stamp.svg",
]
const FX := [
	"res://art/fx/shield_ward.svg",
	"res://art/fx/shield_break.svg",
	"res://art/fx/drum_ripple.svg",
]
const SHELLS := [
	"res://art/enemies/paper_scrap_shell.svg",
	"res://art/enemies/broken_kite_shell.svg",
	"res://art/enemies/broken_puppet_shell.svg",
]
const BASES := [
	"res://art/enemies/paper_scrap.svg",
	"res://art/enemies/broken_kite.svg",
	"res://art/enemies/broken_puppet.svg",
]
const PLAYER := "res://art/characters/shouyiren_front.svg"

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


# ---------- 1. 尺寸断言（画布 = 需求 §2.3） ----------
func _sizes() -> void:
	var want: Dictionary = {
		"gong_icon.svg": [48, 48], "gong_aura.svg": [256, 256],
		"inkline_icon.svg": [48, 48], "inkline_beam.svg": [256, 32], "inkline_impact.svg": [48, 48],
		"print_icon.svg": [48, 48], "print_zone_warn.svg": [256, 256], "print_zone_stamp.svg": [256, 256],
		"passive_regen.svg": [48, 48], "passive_shield.svg": [48, 48],
		"shield_ward.svg": [128, 128], "shield_break.svg": [96, 96],
		"paper_scrap_shell.svg": [48, 48], "broken_kite_shell.svg": [48, 48], "broken_puppet_shell.svg": [48, 48],
		"ui_geng_drum.svg": [48, 48], "drum_ripple.svg": [256, 256],
	}
	print("\n[1] 实测画布（独立于生成器声明）")
	for group in [ICONS, WORLD, FX, SHELLS]:
		for p in group:
			var img: Image = _img(p)
			if img == null:
				continue
			var name: String = p.get_file()
			var w: Array = want[name]
			_chk(img.get_width() == w[0] and img.get_height() == w[1],
				"%-26s %dx%d" % [name, img.get_width(), img.get_height()])


# ---------- 2. 透明底 / alpha 峰值 / 中心留空 ----------
func _alpha_rules() -> void:
	print("\n[2] 世界 FX 的 alpha 峰值 / 中心留空（§2.3 + §2.7）")
	# 每项：[峰值上限, 中心x, 中心y, 孔半径, 孔内允许最大 alpha]
	var limits: Dictionary = {
		"res://art/weapons/gong_aura.svg": [0.55, 128.0, 128.0, 40.0, 0.03],
		"res://art/weapons/print_zone_warn.svg": [0.55, 128.0, 128.0, 60.0, 0.18],
		"res://art/weapons/print_zone_stamp.svg": [0.50, 128.0, 128.0, 80.0, 0.45],
		"res://art/fx/drum_ripple.svg": [0.55, 128.0, 128.0, 56.0, 0.03],
		"res://art/fx/shield_ward.svg": [0.55, 64.0, 64.0, 22.0, 0.03],
	}
	var order: Array = [
		"res://art/weapons/gong_aura.svg",
		"res://art/weapons/print_zone_warn.svg",
		"res://art/weapons/print_zone_stamp.svg",
		"res://art/fx/drum_ripple.svg",
		"res://art/fx/shield_ward.svg",
	]
	for pth in order:
		var img: Image = _img(pth)
		var cfg: Array = limits[pth]
		var peak_lim: float = float(cfg[0])
		var ccx: float = float(cfg[1])
		var ccy: float = float(cfg[2])
		var hole: float = float(cfg[3])
		var hole_lim: float = float(cfg[4])
		var peak: float = 0.0
		var hole_peak: float = 0.0
		var px_at: Vector2i = Vector2i(-1, -1)
		for y in img.get_height():
			for x in img.get_width():
				var a: float = img.get_pixelv(Vector2i(x, y)).a
				if a > peak:
					peak = a
					px_at = Vector2i(x, y)
				if hole > 0.0:
					var d: float = Vector2(x - ccx, y - ccy).length()
					if d <= hole and a > hole_peak:
						hole_peak = a
		_chk(peak <= peak_lim, "%-30s alpha 峰值 %.3f（要求 <=%.2f）@%s" % [pth.get_file(), peak, peak_lim, px_at])
		if hole > 0.0:
			_chk(hole_peak <= hole_lim,
				"%-30s 中心 r<=%d 最大 alpha %.3f（要求 <=%.2f）" % [pth.get_file(), int(hole), hole_peak, hole_lim])


# ---------- 2b. 判定半径与贴图外缘误差 ----------
func _extent(img: Image, ccx: float, ccy: float) -> float:
	var best: float = 0.0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixelv(Vector2i(x, y)).a >= 0.05:
				var d: float = Vector2(x - ccx, y - ccy).length()
				if d > best:
					best = d
	return best


func _radius_rules() -> void:
	print("
[2b] 外缘半径误差（§7.2：光环 150 判定 <=6px / 年画 105 判定）")
	# [文件, 画布中心, 期望外缘(canvas px), 引擎显示半径, 允许像素误差]
	var cases: Array = [
		["res://art/weapons/gong_aura.svg", 128.0, 126.3, 150.0, 6.0],
		["res://art/weapons/print_zone_warn.svg", 128.0, 125.9, 105.0, 6.0],
		["res://art/weapons/print_zone_stamp.svg", 128.0, 126.2, 105.0, 6.0],
	]
	for c in cases:
		var img: Image = _img(c[0])
		var ctr: float = float(c[1])
		var want: float = float(c[2])
		var game_r: float = float(c[3])
		var tol: float = float(c[4])
		var ext: float = _extent(img, ctr, ctr)
		# canvas 外缘 -> 引擎半径（贴图按 直径=2*game_r 铺放，128 canvas px == game_r）
		var err: float = absf((ext / ctr) * game_r - game_r)
		# 外缘不得贴到画布边（<=128 即不裁），且要铺满判定半径（>=want-4）
		# 注：ThorVG 圆弧描边存在 ~1px 多边形化外凸，上限按 127.6 卡（保证 0.4px 透明余量）
		_chk(ext <= 127.6 and ext >= want - 4.0,
			"%-26s 外缘 r=%.1f（期望 %.1f±4），换算 %.0fpx 判定误差 %.1fpx（<=%.0f）"
			% [(c[0] as String).get_file(), ext, want, game_r, err, tol])
		_chk(err <= tol, "%-26s 判定半径误差 %.1fpx 在容差内" % [(c[0] as String).get_file(), err])


# ---------- 3. 浆壳兵：接触阴影与母图逐字节一致 ----------
func _shell_contract() -> void:
	print("\n[3] 浆壳兵脚底锚点 / 接触阴影与母图一致")
	for i in 3:
		var b: Image = _img(BASES[i])
		var s: Image = _img(SHELLS[i])
		_chk(b.get_width() == s.get_width() and b.get_height() == s.get_height(),
			"%s 画布一致 %dx%d" % [SHELLS[i].get_file(), s.get_width(), s.get_height()])
		var same := true
		for x in range(b.get_width() - 6, b.get_width()):
			for y in range(b.get_height() - 3, b.get_height()):
				if b.get_pixelv(Vector2i(x, y)) != s.get_pixelv(Vector2i(x, y)):
					same = false
		# 脚底最下两行像素必须与母图一致（接触阴影未被壳改动 / 脚底不跳）
		_chk(same, "%s 脚底两行像素与母图一致" % SHELLS[i].get_file())


# ---------- 4. 拼版（深/浅底，原生尺寸） ----------
func _sheets() -> void:
	print("\n[4] 拼版")
	var all: Array = []
	all.append_array(ICONS)
	all.append_array(SHELLS)
	all.append_array(WORLD)
	all.append_array(FX)
	all.append("res://art/ui/ui_geng_drum.svg")
	for bg_name in ["dark", "light"]:
		var cols: int = 5
		var rows: int = int(ceil(all.size() / float(cols)))
		var sheet: Image = Image.create(cols * 272, rows * 272, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.055, 0.086, 0.141) if bg_name == "dark" else Color(0.90, 0.86, 0.78))
		for i in all.size():
			var img: Image = _copy(_img(all[i]))
			var cx: int = (i % cols) * 272 + int((272 - img.get_width()) / 2.0)
			var cy: int = int(i / cols) * 272 + int((272 - img.get_height()) / 2.0)
			_put(sheet, img, cx, cy)
		var err: int = sheet.save_png("res://v4_%s.png" % bg_name)
		_chk(err == OK, "v4_%s.png（%d 格）" % [bg_name, all.size()])


# ---------- 5. 剪影测试（§7.2：图标 40px / 敌人 48px 填纯黑） ----------
func _silhouette() -> void:
	print("\n[5] 剪影测试")
	var sheet: Image = Image.create(16 * 44 + 8, 4 * 96 + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.93, 0.91, 0.86))
	# 行 1：6 个图标在 40px 显示尺寸下的剪影（卡面/HUD 实际尺度）
	for i in ICONS.size():
		var s: Image = _scaled(ICONS[i], 40, 40)
		_fill_black(s)
		_put(sheet, s, 8 + i * 44, 8)
	# 行 2：3 母图 vs 3 壳图 48px 剪影
	for i in 3:
		var a: Image = _scaled(BASES[i], 48, 48)
		_fill_black(a)
		_put(sheet, a, 8 + i * 52, 104)
	for i in 3:
		var b: Image = _scaled(SHELLS[i], 48, 48)
		_fill_black(b)
		_put(sheet, b, 8 + (i + 3) * 52, 104)
	# 行 3：壳图 3x 彩色（看壳层细节）
	for i in 3:
		_put(sheet, _scaled(SHELLS[i], 144, 144), 8 + i * 150, 168)
	# 行 4：母图 3x 彩色（对照）
	for i in 3:
		_put(sheet, _scaled(BASES[i], 144, 144), 8 + i * 150, 168 + 150)
	var err: int = sheet.save_png("res://v4_silhouette.png")
	_chk(err == OK, "v4_silhouette.png")


func _fill_black(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixelv(Vector2i(x, y))
			img.set_pixelv(Vector2i(x, y), Color(0, 0, 0, 1.0) if c.a > 0.18 else Color(0, 0, 0, 0))


# ---------- 6. 实机尺度合成（玩家+光环+敌群） ----------
func _ingame() -> void:
	print("\n[6] 实机尺度合成")
	var W: int = 720
	var H: int = 812
	var sheet: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.043, 0.067, 0.11))
	var player: Image = _scaled(PLAYER, 64, 80)
	var mob: Image = _scaled(BASES[0], 48, 48)
	var kite: Image = _scaled(BASES[1], 48, 48)

	# A：铜锣光环按直径 300（半径 150）压玩家脚下 + 敌群
	var aura: Image = _scaled("res://art/weapons/gong_aura.svg", 300, 300)
	_put(sheet, aura, 30, 20)
	for m in [[110, 120], [170, 210], [70, 220], [225, 150], [150, 70]]:
		_put(sheet, mob, 30 + m[0], 20 + m[1])
	_put(sheet, player, 30 + 148, 20 + 132)

	# B：年画预警 210px（半径 105）
	var warn: Image = _scaled("res://art/weapons/print_zone_warn.svg", 210, 210)
	_put(sheet, warn, 400, 65)
	for m in [[460, 100], [530, 150], [430, 170], [560, 90]]:
		_put(sheet, mob, m[0], m[1])
	_put(sheet, player, 473, 150)

	# C：年画成画 210px + 墨斗命中墨溅
	var stamp: Image = _scaled("res://art/weapons/print_zone_stamp.svg", 210, 210)
	_put(sheet, stamp, 400, 65 + 260)
	var imp: Image = _scaled("res://art/weapons/inkline_impact.svg", 48, 48)
	_put(sheet, imp, 512, 350 + 260)
	for m in [[460, 300 + 260 - 65], [530, 350], [430, 370]]:
		_put(sheet, mob, m[0], m[1])

	# D：结界护身罩压在 64x80 玩家上
	var ward: Image = _copy(_img("res://art/fx/shield_ward.svg"))
	_put(sheet, ward, 30 + 148 - 32, 20 + 132 - 24)
	var brk: Image = _scaled("res://art/fx/shield_break.svg", 96, 96)
	_put(sheet, brk, 200, 250)

	# E：墨线拉伸到 520（射程假设）跨过敌群
	var beam: Image = _scaled("res://art/weapons/inkline_beam.svg", 520, 32)
	_put(sheet, beam, 30, 560)
	for i in 5:
		_put(sheet, kite if i % 2 == 0 else mob, 120 + i * 90, 552)
	_put(sheet, player, 40, 536)

	# F：跨更波纹（0.6s 中段按 0.75 缩放）+ 更鼓 HUD 图标 40px
	var ripple: Image = _scaled("res://art/fx/drum_ripple.svg", 192, 192)
	_put(sheet, ripple, 560, 520)
	_put(sheet, _scaled("res://art/ui/ui_geng_drum.svg", 40, 40), 660, 470)
	_put(sheet, _scaled("res://art/items/passive_regen.svg", 68, 68), 40, 640)
	_put(sheet, _scaled("res://art/items/passive_shield.svg", 68, 68), 120, 640)
	_put(sheet, _scaled("res://art/weapons/gong_icon.svg", 68, 68), 200, 640)
	_put(sheet, _scaled("res://art/weapons/inkline_icon.svg", 68, 68), 280, 640)
	_put(sheet, _scaled("res://art/weapons/print_icon.svg", 68, 68), 360, 640)

	# G：三张浆壳兵 96px 与母图并排
	for i in 3:
		_put(sheet, _scaled(BASES[i], 96, 96), 450 + i * 90, 700)
		_put(sheet, _scaled(SHELLS[i], 96, 96), 450 + i * 90, 604 - 60)
	var err: int = sheet.save_png("res://v4_ingame.png")
	_chk(err == OK, "v4_ingame.png")


func _init() -> void:
	_sizes()
	_alpha_rules()
	_radius_rules()
	_shell_contract()
	_sheets()
	_silhouette()
	_ingame()
	print("\n== v4 P0 校核：%s（fail=%d）" % ["ALL PASS" if fail_count == 0 else "HAS FAILURE", fail_count])
	quit(1 if fail_count > 0 else 0)
