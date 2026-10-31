extends SceneTree

# 临时诊断：逐个对比旧/新贴图的"有效像素包围盒"，量化换皮后视觉尺寸是否漂移。
# 判定半径仍按 size（=画布尺寸）算，所以画布里画得越小，视觉与判定就越不匹配。
# 跑完即删。

const PAIRS := {
	"player_front": ["res://assets/art/characters/player_front.svg", "res://assets/art_shouyiren/characters/shouyiren_front.svg"],
	"mob_base": ["res://assets/art/enemies/enemy_cup.svg", "res://assets/art_shouyiren/enemies/paper_scrap.svg"],
	"mob_fast": ["res://assets/art/enemies/enemy_cup_fast.svg", "res://assets/art_shouyiren/enemies/broken_kite.svg"],
	"mob_heavy": ["res://assets/art/enemies/enemy_bag.svg", "res://assets/art_shouyiren/enemies/broken_puppet.svg"],
	"elite_box": ["res://assets/art/enemies/enemy_elite_box.svg", "res://assets/art_shouyiren/enemies/ink_blob_elite.svg"],
	"elite_red": ["res://assets/art/enemies/enemy_elite_red.svg", "res://assets/art_shouyiren/enemies/faceless_nuo_elite.svg"],
	"boss": ["res://assets/art/enemies/enemy_reaper.svg", "res://assets/art_shouyiren/enemies/lost_visage.svg"],
	"gem_small": ["res://assets/art/items/gem_blue.svg", "res://assets/art_shouyiren/items/light_bloom.svg"],
	"gem_big": ["res://assets/art/items/gem_orange.svg", "res://assets/art_shouyiren/items/gold_spark.svg"],
	"chest": ["res://assets/art/items/chest.svg", "res://assets/art_shouyiren/items/craft_box.svg"],
	"coin": ["res://assets/art/items/coin.svg", "res://assets/art_shouyiren/items/copper_coin.svg"],
}

func _init() -> void:
	print("%-12s %-18s %-18s %s" % ["slot", "old bbox(画布)", "new bbox(画布)", "有效高度变化"])
	for k in PAIRS:
		var a: Vector4 = _bbox(String(PAIRS[k][0]))
		var b: Vector4 = _bbox(String(PAIRS[k][1]))
		print("%-12s %-18s %-18s %s" % [k, _fmt(a), _fmt(b), _delta(a, b)])
	quit()

## 返回 (有效宽, 有效高, 画布宽, 画布高)
func _bbox(path: String) -> Vector4:
	var t: Texture2D = load(path) as Texture2D
	if t == null:
		return Vector4(-1, -1, -1, -1)
	var img: Image = t.get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var minx := w
	var maxx := -1
	var miny := h
	var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.25:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return Vector4(0, 0, w, h)
	return Vector4(maxx - minx + 1, maxy - miny + 1, w, h)

func _fmt(v: Vector4) -> String:
	return "%dx%d / %dx%d" % [int(v.x), int(v.y), int(v.z), int(v.w)]

func _delta(a: Vector4, b: Vector4) -> String:
	if a.y <= 0 or b.y <= 0:
		return "-"
	return "%+.0f%%（高）%+.0f%%（宽）" % [(b.y / a.y - 1.0) * 100.0, (b.x / a.x - 1.0) * 100.0]
