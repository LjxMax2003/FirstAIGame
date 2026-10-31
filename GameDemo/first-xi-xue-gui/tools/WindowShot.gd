extends Node

# 真实窗口渲染冒烟：开一个 720x1280 窗口跑若干帧，把当前画面截图存盘。
# 目的不是玩法验收，而是证明"渲染管线 + 场景装配在真机窗口下不崩、画面不是全黑"。

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	# 让玩家走一段，确保敌人、武器、宝石都至少出现过
	var player: Player = get_node_or_null("Game/World/Player")
	if player != null:
		player.set("_drag_active", true)
		player.set("_drag_index", 0)
		player.set("_drag_dir", Vector2(1.0, -0.2))
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var out := "user://shot_window.png"
	var err: int = img.save_png(out)
	print("SHOT ", ProjectSettings.globalize_path(out), " err=", err, " size=", img.get_size())
	# 采样中心区域亮度，排除"截到一张纯黑图"的假成功
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum := 0.0
	var n := 0
	for x in range(int(w * 0.2), int(w * 0.8), 7):
		for y in range(int(h * 0.2), int(h * 0.8), 7):
			var c: Color = img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
			n += 1
	print("AVG_LUMA %.4f over %d samples" % [sum / float(maxi(n, 1)), n])
	get_tree().quit()
