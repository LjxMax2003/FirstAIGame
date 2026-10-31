extends SceneTree

func _init() -> void:
	var raw: FileAccess = FileAccess.open("res://art_dbg/plan.json", FileAccess.READ)
	var plan: Dictionary = JSON.parse_string(raw.get_as_text())
	raw.close()
	for rel in plan:
		var cfg: Dictionary = plan[rel]
		var px: int = int(cfg["px"][0])
		var py: int = int(cfg["px"][1])
		print("\n== %s  @(%.0f, %.0f) 共 %d 层" % [rel, px, py, int(cfg["n"])])
		var rows: Array = []
		for i in int(cfg["n"]):
			var p: String = "res://%s/%02d.svg" % [cfg["dir"], i]
			var t: Texture2D = load(p)
			if t == null:
				continue
			var img: Image = t.get_image()
			img.convert(Image.FORMAT_RGBA8)
			var a: float = img.get_pixelv(Vector2i(px, py)).a
			if a > 0.01:
				rows.append([a, i])
		rows.sort_custom(func(x, y): return x[0] > y[0])
		var total: float = 0.0
		for r in rows:
			total = total + r[0] * (1.0 - total)
			print("   layer %d  alpha %.3f   累计 %.3f" % [int(r[1]), r[0], total])
	quit(0)
