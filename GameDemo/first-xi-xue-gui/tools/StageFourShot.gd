extends Node

# 阶段四窗口渲染冒烟（真实窗口，非 headless）。
# 目的：
#   1) 证明金币商店五条线都画得出来，且"已满级 / 买得起 / 买不起"三种按钮状态同屏可分；
#   2) 证明结算面板的金币双行（本局 +N / 持有 M）与商店入口渲染正常；
#   3) 排除"截到一张纯黑图"的假成功（亮度采样）。
#
# 用法：godot --path . res://tools/StageFourShot.tscn
# 注意：这个脚本只做"渲染证据"，玩法与存档由 SmokeTest.tscn 覆盖。

const SHOTS := "user://"

var _game: GameScene

func _ready() -> void:
	await get_tree().process_frame
	_game = get_node_or_null("Game") as GameScene
	if _game == null:
		print("SHOT FAIL: Game 节点缺失")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.2).timeout

	var shop: ShopUI = _game.get_node("UI/ShopUI") as ShopUI

	# 造一个有信息量的存档状态：两条满级、两条买得起、一条买不起。
	# 全都 0 级或全都满级都会让截图看不出状态色差。
	MetaSave.debug_set(1430, {"damage": 5, "max_hp": 2, "cooldown": 1, "magnet": 3, "revive": 0})
	print("META coins=%d levels=%s affordable=%d" % [
		MetaSave.coins, str(MetaSave.levels), MetaSave.affordable_count()])

	# ---- 场景 1：结算面板（金币双行 + 商店入口提示）
	_game.kills = 1284
	_game.elapsed = 1147.0
	_game.elite_kills = 7
	_game.boss_kills = 1
	_game.evolutions = 2
	_game.coins_earned = 38
	_game.won = false
	var coins: int = _game.coin_reward()
	var total: int = MetaSave.add_coins(coins)
	_game.death_ui.show_result(_game.kills, _game.elapsed, 31, false, coins,
		_game.elite_kills, _game.boss_kills, _game.evolutions, total)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_shot("shot_stage4_settle.png", "结算入账")
	print("SETTLE +%d → 持有 %d" % [coins, total])

	# ---- 场景 2：商店本体（从结算界面点进商店的真实路径）
	_game.death_ui.get_node("Popup/Panel/VB/Shop").pressed.emit()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_shot("shot_stage4_shop.png", "金币商店")
	print("SHOP open=%s paused=%s" % [str(shop.is_open()), str(get_tree().paused)])

	# ---- 场景 3：买完一条，证明"点了就变"
	var before: int = MetaSave.coins
	var cells: Dictionary = shop.get("_cells")
	var buy: Button = (cells["cooldown"] as Dictionary)["buy"] as Button
	buy.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_shot("shot_stage4_bought.png", "购买后")
	print("BUY cooldown %d → %d  coins %d → %d" % [
		MetaSave.level_of("cooldown") - 1, MetaSave.level_of("cooldown"), before, MetaSave.coins])

	# 截图会污染玩家真实进度，退出前把存档恢复成"干净初始值"
	MetaSave.debug_set(0, {})
	get_tree().quit()

func _shot(name: String, label: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var out: String = SHOTS + name
	var err: int = img.save_png(out)
	print("SHOT [%s] %s err=%d size=%s" % [label, ProjectSettings.globalize_path(out), err, str(img.get_size())])
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum := 0.0
	var n := 0
	for x in range(int(w * 0.2), int(w * 0.8), 7):
		for y in range(int(h * 0.2), int(h * 0.8), 7):
			var c: Color = img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
			n += 1
	print("  AVG_LUMA %.4f over %d samples" % [sum / float(maxi(n, 1)), n])
