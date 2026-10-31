extends SceneTree

# ============================================================================
# v6 觉醒美术「登记 + 可加载」校验（docs/design/v6_fx_art_plan.md §8 新增检查 3）
# ----------------------------------------------------------------------------
# 用法：godot --headless --path . --script res://tools/V6Art.gd
#
# 只读、不开一局。管三件事：
#   ① 4 张新 svg 有没有进 Art.ALL_PATHS —— 清单 §1.6 明写「漏接会静默通过」，
#      因为资源守卫是「正向」的（只遍历 ALL_PATHS 里的路径），不登记就永远不测。
#   ② 路径能不能真 load 出来（换图写错一个字 = 运行时白块）。
#   ③ 实测画布尺寸 = 清单 new_art[].size（贴图按 1:1 原生用，尺寸错 = 显示尺度错）。
# 接线后的行为断言（角标只在 Lv8 显示 / 铁水团换图 / 同屏合批不回退）要等调用点
# 接上，归 V5InGame 那一层的局内测试补，本脚本不越界。
# ============================================================================

const EXPECT := [
	{"path": Art.AWAKEN_BADGE, "file": "awaken_badge.svg", "w": 64, "h": 32, "status": "must"},
	{"path": Art.MOLTEN_BLOB, "file": "molten_blob.svg", "w": 24, "h": 24, "status": "recommended"},
	{"path": Art.INK_LINE_TEX, "file": "ink_line_tex.svg", "w": 256, "h": 8, "status": "recommended"},
	{"path": Art.WOODBLOCK_SEAL, "file": "woodblock_seal.svg", "w": 160, "h": 160, "status": "recommended"},
]

# v6 §1.2 红线：本轮零新武器本体美术。9 把武器的 svg 必须还指向原图。
const WEAPON_STEMS := ["nuo_blade_arc", "lantern_halo", "sugar_thread", "shadow_puppet",
	"paper_cut_bird", "iron_flower_ladle", "gong", "inkline", "woodblock_print"]

var fails: int = 0


func _chk(cond: bool, msg: String) -> void:
	print("  %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		fails += 1


func _init() -> void:
	print("\n[1] v6 新美术登记 / 可加载 / 实测画布")
	for e in EXPECT:
		var p: String = String(e["path"])
		_chk(p in Art.ALL_PATHS, "%-18s 已登记进 ALL_PATHS（%s）" % [e["file"], e["status"]])
		_chk(p.begins_with("res://assets/art_shouyiren/"), "%-18s 落在非遗美术目录内" % e["file"])
		var tex: Texture2D = Art.tex(p)
		if tex == null:
			_chk(false, "%-18s Art.tex 加载失败" % e["file"])
			continue
		var img: Image = tex.get_image()
		_chk(img.get_width() == int(e["w"]) and img.get_height() == int(e["h"]),
			"%-18s 实测 %dx%d = 清单 %dx%d" % [e["file"], img.get_width(), img.get_height(), e["w"], e["h"]])
		# 非空断言：SVG 导入失败会给出全透明图，尺寸对但没内容
		var solid := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixelv(Vector2i(x, y)).a > 0.5:
					solid += 1
		_chk(solid > 0, "%-18s 实心像素 %d 个（不是空图）" % [e["file"], solid])

	print("\n[2] 零新武器本体（v6 §1.2 红线：9 把武器 svg 未被换掉）")
	# 武器图有两处：本体 svg 与弹道 bullet_svg（sugar_thread 属于后者），一起收。
	var stems: Array[String] = []
	var stolen := 0
	for wid in WeaponDB.DEFS:
		var d: Dictionary = WeaponDB.DEFS[wid]
		for key in ["svg", "bullet_svg"]:
			if not d.has(key):
				continue
			var svg := String(d[key])
			var stem := svg.get_file().get_basename()
			stems.append(stem)
			if stem in ["awaken_badge", "molten_blob", "ink_line_tex", "woodblock_seal"]:
				stolen += 1
	_chk(stolen == 0, "WeaponDB 的本体/弹道 svg 无一指向 v6 新图")
	var missing: Array[String] = []
	for stem in WEAPON_STEMS:
		if stem not in stems:
			missing.append(stem)
	_chk(missing.is_empty(), "9 把武器本体贴图仍在 WeaponDB 里挂好（缺：%s）" % ", ".join(missing))

	print("\n== v6 美术登记：%s（fail=%d）" % ["ALL PASS" if fails == 0 else "HAS FAILURE", fails])
	quit(1 if fails > 0 else 0)
