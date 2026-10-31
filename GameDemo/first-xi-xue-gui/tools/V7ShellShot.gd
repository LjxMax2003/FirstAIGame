extends Node

# ============================================================================
# v7 产品壳截图（T4 / T5）。**不能加 --headless**：
# RenderingServer.frame_post_draw 在 dummy 渲染器下不触发，会静默挂死。
#
# 用法：godot --path . res://tools/V7ShellShot.tscn
# 产物：user://shot_*.png（终端会打印绝对路径）
#
# 这张sheet 存在的理由是"断言测不出难看"：
# V7Shell 能证明按钮接上了、能证明文案对，但证明不了
# "设置面板在 720×1280 下被裁掉半行"、"暂停菜单多两个按钮后溢出屏幕"。
# 所以每个新面板都截一张，人眼过一遍。
# ============================================================================

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const PAUSE_SCENE := "res://scenes/ui/PauseUI.tscn"
const GAME_SCENE := "res://scenes/Game.tscn"

func _ready() -> void:
	await get_tree().process_frame
	# 开场与提示都按"首次"的状态截，否则截出来的是空画面
	MetaSave.intro_done = false
	MetaSave.seen_tips = {}

	await _shot_menu()
	await _shot_settings()
	await _shot_intro()
	await _shot_pause()
	await _shot_result()

	print("DONE")
	get_tree().quit()

# ---------------------------------------------------------------- 主菜单
func _shot_menu() -> void:
	var m: MainMenu = (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	add_child(m)
	await get_tree().create_timer(0.4).timeout
	await _snap("shot_menu")
	m.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 设置面板
func _shot_settings() -> void:
	var m: MainMenu = (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	add_child(m)
	await get_tree().process_frame
	m.btn_settings.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	await _snap("shot_settings")
	# 再来一张二次确认层
	m._settings._on_clear_save()
	await get_tree().create_timer(0.3).timeout
	await _snap("shot_settings_confirm")
	m.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 开场
func _shot_intro() -> void:
	var intro: IntroUI = IntroUI.new()
	add_child(intro)
	await get_tree().process_frame
	intro.open()
	await get_tree().create_timer(0.35).timeout
	await _snap("shot_intro_1")
	intro.next()
	await get_tree().create_timer(0.25).timeout
	await _snap("shot_intro_2")
	intro.next()
	await get_tree().create_timer(0.25).timeout
	await _snap("shot_intro_3")
	intro.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 暂停菜单
func _shot_pause() -> void:
	var p: PauseUI = (load(PAUSE_SCENE) as PackedScene).instantiate() as PauseUI
	add_child(p)
	await get_tree().process_frame
	p.open()
	await get_tree().create_timer(0.3).timeout
	await _snap("shot_pause")
	p._on_menu()
	await get_tree().create_timer(0.3).timeout
	await _snap("shot_pause_confirm")
	p.close()
	p.queue_free()
	get_tree().paused = false
	await get_tree().process_frame

# ---------------------------------------------------------------- 结算 + 提示
func _shot_result() -> void:
	var g: GameScene = (load(GAME_SCENE) as PackedScene).instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	g.set_process(false)

	# 木牌提示（不暂停）：先截这一张，再让结算盖上去
	g.tips.scan()
	if not g.tips.is_showing():
		# 兜底：直接把一次真实的入队走出来，保证截图里一定有这块木牌
		g.tips._enqueue("move", "拖拽移动，出手是自动的。")
		g.tips._show("move")
	await get_tree().create_timer(0.5).timeout
	await _snap("shot_tip")

	# 走真实入口 _finish（而不是直接 show_result）：
	# 它才是"先收木牌再弹结算"那条链，截出来的才是玩家真会看到的那一帧。
	g.kills = 412
	g.elapsed = 743.0
	g.player.level = 21
	g.elite_kills = 3
	g.boss_kills = 1
	g.evolutions = 2
	g._finish(false, "潮涌里被挤灭")
	await get_tree().create_timer(0.4).timeout
	await _snap("shot_result")

	g.queue_free()
	get_tree().paused = false
	await get_tree().process_frame

# ---------------------------------------------------------------- 截图
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var out := "user://%s.png" % name
	var err: int = img.save_png(out)
	# 亮度采样：排除"截到一张纯黑图"的假成功
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum := 0.0
	var n := 0
	for x in range(int(w * 0.1), int(w * 0.9), 9):
		for y in range(int(h * 0.1), int(h * 0.9), 9):
			var c: Color = img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
			n += 1
	print("SHOT %-24s err=%d %s  luma=%.4f" % [name, err,
		ProjectSettings.globalize_path(out), sum / float(maxi(n, 1))])
