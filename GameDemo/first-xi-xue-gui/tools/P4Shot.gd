extends Node

# P4 UI 换皮的**渲染证据**（真实窗口，非 headless）。
# 不是玩法验收——玩法与文案断言由 SmokeTest.tscn 覆盖（286 项）。
# 这里只回答"该看见的字，是否真的出现在屏幕上"，并把关键 Label 的 text 打出来，
# 让"截图好看"和"字符串对得上"两件事互为证据。
#
# 覆盖方案 P4 出口的四类目视项：
#   1) HUD 显示更次（一更·戌时 … 五更·寅时），且 300/600/1200/1500 四个边界与波次同步跳变；
#   2) 结算双标题：灯灭了 / 五更鸡鸣；
#   3) 商店标题变成「百工谱」；
#   4) 暂停（歇口气）与升级卡（传承 / 口诀）。
#
# 用法：godot --path . res://tools/P4Shot.tscn

const SHOTS := "user://"

## 更次采样点：每个波次取 1 个代表点，另外补 4 个"边界前一帧"验证跳变时机。
## 边界取自 WaveTable.WAVES（0/300/600/1200/1500/1800），这里只**引用**不复制常量。
const GENG_SAMPLES: Array[float] = [10.0, 310.0, 610.0, 1210.0, 1510.0]
const GENG_EDGES: Array[float] = [299.5, 300.5, 599.5, 600.5, 1199.5, 1200.5, 1499.5, 1500.5]

var _game: GameScene
var _player: Player
var _sc := 1.0

func _ready() -> void:
	await get_tree().process_frame
	_game = get_node_or_null("Game") as GameScene
	if _game == null:
		print("SHOT FAIL: Game 节点缺失")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.6).timeout
	_player = _game.get_node("World/Player") as Player
	_player.set("invuln_left", 1e9)

	# 冻结本局：started=false 之后 Game._process 直接 return，
	# elapsed 不会再被 delta 推走 —— 这是能"定格在 1210s"拍更次的前提。
	GameManager.started = false
	# 让信息行看起来像真的一局，而不是全 0 的默认值
	_game.kills = 431
	_game.evolutions = 2
	# 灯花离玩家 300px（远超磁吸半径），否则拍之前就被吸走了
	for i in 26:
		var ang: float = TAU * float(i) / 26.0
		_game.gems.spawn(_player.global_position + Vector2.from_angle(ang) * 300.0, 3)

	await _shoot_geng()
	await _shoot_result(false, "shot_p4_result_lose.png", "结算：灯灭了")
	await _shoot_result(true, "shot_p4_result_win.png", "结算：五更鸡鸣")
	await _shoot_shop()
	await _shoot_cards()
	await _shoot_pause()

	get_tree().quit()

# ---------------------------------------------------------------- 更次
## 边界表：打印"每个边界前后各自的更次"，用文本证明跳变点落在 300/600/1200/1500，
## 而不是靠肉眼看图猜。
func _shoot_geng() -> void:
	print("\n==== 更次边界（WaveTable = 0/300/600/1200/1500/1800） ====")
	var bad := 0
	for t in GENG_EDGES:
		_game.elapsed = t
		await get_tree().process_frame
		# 不是拿 wave_index 自己跟自己比，而是比"HUD 上真的显示的那串字"
		# 和"按波次表应该显示的更次"——验的是接线，不是纯函数。
		var want: String = HUD.GENG_NAMES[WaveTable.wave_index(t)]
		var got: String = _game.hud.timer_label.text
		var mark: String = "ok" if want == got else "MISMATCH"
		if want != got:
			bad += 1
		print("  t=%7.1f  波次 %d  %-6s  want「%s」 got「%s」" % [t, WaveTable.wave_index(t), mark, want, got])
	print("  边界自查 bad=%d" % bad)

	for i in GENG_SAMPLES.size():
		var t: float = GENG_SAMPLES[i]
		_game.elapsed = t
		await get_tree().process_frame
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var img := _grab()
		var name := "shot_p4_geng_%d.png" % (i + 1)
		_save(_crop_top(img), name, "更次 @%.0fs" % t)
		print("  HUD 更次「%s」  小字「%s」" % [_game.hud.timer_label.text, _game.hud.timer_small.text])
		print("  HUD 信息「%s」" % _game.hud.info.text)

# ---------------------------------------------------------------- 结算
func _shoot_result(victory: bool, name: String, label: String) -> void:
	get_tree().paused = false
	# elapsed 定在 1800：胜利局的面板必须显示 30:00 / 30:00
	_game.elapsed = WaveTable.RUN_LENGTH
	_game.death_ui.show_result(1432, WaveTable.RUN_LENGTH, 38, victory, 286, 7, 3, 2, 7412)
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img := _grab()
	_save(img, name, label)
	var title: Label = _game.death_ui.get_node("Popup/Panel/VB/Title") as Label
	var info: Label = _game.death_ui.get_node("Popup/Panel/VB/Info") as Label
	var coins: Label = _game.death_ui.get_node("Popup/Panel/VB/Coins") as Label
	var total: Label = _game.death_ui.get_node("Popup/Panel/VB/Total") as Label
	var shop: Button = _game.death_ui.get_node("Popup/Panel/VB/Shop") as Button
	print("  TITLE「%s」 COINS「%s」 TOTAL「%s」 SHOP「%s」" % [title.text, coins.text, total.text, shop.text])
	print("  INFO → %s" % info.text.replace("\n", " ⏎ "))
	get_tree().paused = false
	_game.death_ui.get_node("Popup").visible = false
	_game.death_ui.get_node("Mask").visible = false
	await get_tree().process_frame

# ---------------------------------------------------------------- 商店（百工谱）
func _shoot_shop() -> void:
	MetaSave.coins = 3600
	_game.shop_ui.open()
	# 买两级"匠心"，让行内出现满级点 / 价格 / 已满级三种状态，版面才有压力
	MetaSave.levels["damage"] = 2
	MetaSave.levels["revive"] = MetaSave.max_level_of("revive")
	_game.shop_ui.refresh()
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img := _grab()
	_save(img, "shot_p4_shop.png", "百工谱（3 行有等级 / 1 行满级）")
	var title: Label = _game.shop_ui.get_node("Center/Panel/Margin/VB/Head/Title") as Label
	var coins: Label = _game.shop_ui.get_node("Center/Panel/Margin/VB/Head/Coins") as Label
	var sub: Label = _game.shop_ui.get_node("Center/Panel/Margin/VB/Sub") as Label
	var hint: Label = _game.shop_ui.get_node("Center/Panel/Margin/VB/Hint") as Label
	print("  SHOP TITLE「%s」 COINS「%s」" % [title.text, coins.text])
	print("  SUB「%s」" % sub.text)
	print("  HINT「%s」" % hint.text)
	_game.shop_ui.close()

# ---------------------------------------------------------------- 升级卡（传承 / 口诀）
func _shoot_cards() -> void:
	_game.level_up_ui._on_level_up()
	await get_tree().process_frame
	_game.level_up_ui._clear_cards()
	var want: Array[String] = ["whip", "halo", "damage"]
	var entries: Array[Dictionary] = []
	for d in UpgradeDB.all_defs():
		if String(d["id"]) in want:
			entries.append({"def": d, "new_level": UpgradeDB.current_level(String(d["id"])) + 1, "is_new": false})
	for e in entries:
		_game.level_up_ui.cards.add_child(_game.level_up_ui._make_card(e))
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var img := _grab()
	_save(img, "shot_p4_cards.png", "升级卡：两门手艺 + 一条口诀")
	# 卡面标签是 Label.new() 动态加的，按"文字内容"反查，把 传承/口诀 打出来
	var tags: Array[String] = []
	for c in _game.level_up_ui.cards.get_children():
		for child in c.get_children():
			if child is Label:
				var s: String = (child as Label).text
				if s.begins_with("传承") or s.begins_with("口诀"):
					tags.append(s)
	print("  LEVELUP TITLE「%s」 HINT「%s」" % [_game.level_up_ui.title.text, _game.level_up_ui.hint.text])
	print("  CARD TAGS %s" % str(tags))
	_game.level_up_ui.close_all()

# ---------------------------------------------------------------- 暂停（歇口气）
func _shoot_pause() -> void:
	get_tree().paused = false
	GameManager.started = true
	_game.pause_ui.open()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := _grab()
	_save(img, "shot_p4_pause.png", "暂停：歇口气 / 接着守 / 重守一夜")
	var t: Label = _game.pause_ui.get_node("Popup/VB/Title") as Label
	var r: Button = _game.pause_ui.get_node("Popup/VB/Resume") as Button
	var s: Button = _game.pause_ui.get_node("Popup/VB/Restart") as Button
	print("  PAUSE「%s」/「%s」/「%s」" % [t.text, r.text, s.text])
	_game.pause_ui.close()
	get_tree().paused = false

# ---------------------------------------------------------------- 工具
func _grab() -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	_sc = float(img.get_width()) / get_viewport().get_visible_rect().size.x
	return img

func _save(img: Image, name: String, label: String) -> void:
	if img == null:
		print("SHOT FAIL [%s] 空图" % label)
		return
	var err: int = img.save_png(SHOTS + name)
	print("SHOT [%s] %s err=%d size=%s" % [label, ProjectSettings.globalize_path(SHOTS + name), err, str(img.get_size())])

## 只截 HUD 顶部条：更次是 26px 字，全屏图里太小，裁出来放大 2 倍才能一眼比对
func _crop_top(img: Image) -> Image:
	var h: int = mini(img.get_height(), int(170.0 * _sc))
	var crop: Image = img.get_region(Rect2i(0, 0, img.get_width(), h))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return crop
