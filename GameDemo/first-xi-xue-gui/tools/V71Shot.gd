extends Node

# ============================================================================
# v7.1 内容纵深 · 世界侧眼见为实（**不能加 --headless**）
#
# 用法：godot --path . res://tools/V71Shot.tscn -- shot=t11
# 产出：user://v71_street.png（夜市街区全貌）/ v71_gate.png（牌楼近景）
#
# 【为什么世界侧要单独一个截图工具】
# 置景（T11）与残面三现（T13）都是"纯视觉、数值上不可断言"的改动：
# SmokeTest 能证明贴图路径能 load，证明不了牌楼是不是摆在了怪堆正中间。
#
# 【为什么先关 _process 再截】
# 波次会持续往场上丢怪，截图里会混进不相干的敌人；关掉之后场景才是静态的。
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"

var _g: GameScene

func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			only = a.substr(5)
	await get_tree().process_frame
	# 角色面板在主菜单里（不在局内），走另一条路径，开完面板就退出 ——
	# 别为了截一张 UI 图去建一整局游戏。
	if only == "chars":
		await _shot_chars()
		print("DONE")
		get_tree().quit()
		return
	if only == "codex":
		await _shot_codex()
		print("DONE")
		get_tree().quit()
		return
	_g = (load(GAME_SCENE) as PackedScene).instantiate() as GameScene
	add_child(_g)
	await get_tree().process_frame
	await get_tree().process_frame

	_g.set_process(false)
	# 武器自己也有 _process：只停 Game 的话"打铁花"会继续往残面身上泼，
	# 截图里 boss 脸上永远糊着一团火花 —— 第一次截三现就是这么翻车的。
	# 主动技同理（它的 _process 管冷却与计时）。
	_g.weapons.set_process(false)
	var skill: Node = _g.player.get_node_or_null("ActiveSkill")
	if skill != null:
		skill.set_process(false)
	_g.enemies.clear_all()
	_g.gems.clear_all()
	_g.pickups.clear_all()
	_g.hud.visible = false
	await get_tree().process_frame

	if only == "" or only == "t11":
		await _shot_street()

	if only == "" or only == "t10":
		await _shot_frames()

	if only == "" or only == "boss":
		await _shot_boss_phases()

	if only == "aim":
		await _shot_extinguisher_aim()

	print("DONE")
	get_tree().quit()

# ---------------------------------------------------------------- T9 角色面板
## 两张：一张"刚打开"（默认匠人已选 + 四个锁着的带进度），一张"点了灯彩匠之后"
## （高亮必须跟着走 —— 这是唯一能证明"点了真的生效"的画面证据）。
##
## 【为什么要临时改存档】全零存档只会看到"1 个亮 + 4 个灰 0/1"，
## 进度文案（`1 / 3 只` 这种）根本没机会渲染。所以先摆一个"打了半局"的中间态，
## 截完立刻按备份还原 —— 截图工具不许在玩家存档上留下任何痕迹。
func _shot_chars() -> void:
	var backup: Dictionary = MetaSave.snapshot()
	MetaSave.debug_set(0, {}, {
		"won_runs": 1, "best_time": 372.0, "mini_boss_kills": 2,
		"coins_total": 1840, "char_id": "",
	})
	var menu: Node = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	menu.call("_on_chars")
	await get_tree().create_timer(0.25).timeout
	await _snap("v71_chars")

	# 点灯彩匠（已解锁）：高亮应当从铁花匠挪过去
	var panel: Node = menu.call("chars_instance")
	if panel != null:
		(panel as CharacterUI)._on_pick("lantern")
		await get_tree().create_timer(0.2).timeout
		await _snap("v71_chars_pick")

	MetaSave.debug_set(int(backup["coins"]), backup["levels"], {
		"won_runs": int(backup["won_runs"]), "best_time": float(backup["best_time"]),
		"mini_boss_kills": int(backup["mini_boss_kills"]),
		"coins_total": int(backup["coins_total"]), "char_id": String(backup["char_id"]),
	})

# ---------------------------------------------------------------- T13 残面三现
## 三张：一现 / 二现 / 三现。验收口径是"三档登场各有一张不同截图可辨认"，
## 所以三张必须用同一个机位、同一个残面位置 —— 只让"层"变，别让机位变，
## 否则看的人分不清"是演出更强了"还是"镜头换了"。
func _shot_boss_phases() -> void:
	_move_player_to(Vector2.ZERO)
	var boss: Enemy = _g.enemies.spawn(Vector2(0.0, -110.0), 99999.0, 0.0, 1, "reaper",
		true, 0.0, true)
	# 等溶解登场跑完（ShaderFX.spawn_in 0.40s）：不等的话残面还是半透明的
	await get_tree().create_timer(0.45).timeout
	for phase in 3:
		_g.spawn_boss_visual(phase)
		# 淡入 0.55s + 第三层的 0.16s 延迟，给足 0.8s 再按快门
		await get_tree().create_timer(0.80).timeout
		# set_process(false) 之后 _process 不跑，位置得自己推一次：
		# 不推的话三层全叠在世界上原点 (0,0)，截出来是屏幕正中一团光
		_g._update_boss_fx(0.016)
		await get_tree().process_frame
		await _snap("v71_boss_%d" % (phase + 1))
	_g.clear_boss_visual()

# ---------------------------------------------------------------- T12 图鉴
## 两张：一张"收录了三分之二"的手艺页（同时能看出已收录 / 未收录两种卡面），
## 一张"对手"页（靠击杀解锁的那一类，排版和图标密度与武器不同）。
##
## 【为什么要摆中间态】全空只会看到九张"尚未收录"，看不出收录态长什么样；
## 全满又看不出边界。三分之二正好能同时验两种卡面，也顺带验页签数字。
func _shot_codex() -> void:
	var backup: Dictionary = MetaSave.snapshot()
	var mid: Dictionary = backup.duplicate()
	var seen: Dictionary = {}
	for id in ["whip", "halo", "glowstick", "phone", "blade", "extinguisher", "gong",
			"evolve_whip", "evolve_halo",
			"damage", "cooldown", "area", "magnet",
			"cup", "fast", "bag"]:
		seen[id] = true
	mid["codex"] = seen
	MetaSave.debug_set(int(mid["coins"]), mid["levels"], mid)

	var menu: Node = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	menu.call("_on_codex")
	await get_tree().create_timer(0.25).timeout
	await _snap("v71_codex")

	var ui: CodexUI = menu.call("codex_instance")
	if ui != null:
		ui.open(CodexDB.KIND_FOE)
		await get_tree().create_timer(0.2).timeout
		await _snap("v71_codex_foe")

	MetaSave.debug_set(int(backup["coins"]), backup["levels"], backup)
	CodexDB.clear_fresh()

# ---------------------------------------------------------------- T11 置景
func _shot_street() -> void:
	# 街区以世界原点为中心，玩家开局就在这里
	_move_player_to(Vector2.ZERO)
	await get_tree().create_timer(0.35).timeout
	await _snap("v71_street")

	# 牌楼在北边 (-430)，把相机挪过去看它有没有被地面裁掉
	_move_player_to(Vector2(0.0, -300.0))
	await get_tree().create_timer(0.35).timeout
	await _snap("v71_gate")

# ---------------------------------------------------------------- T10 行走帧
## 三帧 + 结壳变体排成对照表：3 行（纸屑 / 纸鸢 / 纸偶）× 4 列（帧 0/1/2 / 结壳）。
## 把每只的 process 关掉，帧才停得住 —— 否则 7fps 会在我按快门之前切走。
## 前三列直接写 art.texture，而不是"等它自己走到第 N 帧"：
## 截图要的是"这三张画的是同一只吗"，不是"7fps 是不是真的 7fps"（后者归断言管）。
# ---------------------------------------------------------------- 打铁花锁定
## 两张对照：东/北各放一只敌人，看两发铁水团是不是"一东一北"。
## 只看代码分不清"朝最近敌人"和"恰好好看"，必须看画面。
func _shot_extinguisher_aim() -> void:
	if _g == null:
		return
	_move_player_to(Vector2.ZERO)
	_g.weapons.owned = {"extinguisher": 1}
	_g.weapons._cd["extinguisher"] = 999.0   # 先别自动放，下面手动放一次
	# 两只放在玩家正东 / 正北，距离 260，肉眼可分
	_g.enemies.spawn(Vector2(260.0, 0.0), 99999.0, 0.0, 1, "cup", false, 0.0, false, false)
	_g.enemies.spawn(Vector2(0.0, -260.0), 99999.0, 0.0, 1, "cup", false, 0.0, false, false)
	await get_tree().create_timer(0.30).timeout   # 让登场缩放跑完
	_g.weapons.fire_extinguisher(_g.player)
	# 推 0.18s：弹体从出生点飞出一小段，方向才看得出来（刚出手时还叠在脚下）
	_g.weapons.update_bullets(0.18)
	await get_tree().process_frame
	await _snap("v71_aim_2targets")

	# 对照组：只有一只在东 —— 两发都该朝东、只是散开一点
	_g.enemies.clear_all()
	_g.weapons.clear_bullets()
	_g.enemies.spawn(Vector2(260.0, 0.0), 99999.0, 0.0, 1, "cup", false, 0.0, false, false)
	await get_tree().create_timer(0.30).timeout
	_g.weapons.fire_extinguisher(_g.player)
	_g.weapons.update_bullets(0.18)
	await get_tree().process_frame
	await _snap("v71_aim_1target")

func _shot_frames() -> void:
	_move_player_to(Vector2.ZERO)
	# 拉近 1.6 倍：48px 的杂兵在 720 宽下只有指甲盖大，看不清三帧差别。
	# 缩放后可视世界半宽 225、半高 400，下面 4 列 × 3 行正好铺满。
	_g.camera.zoom = Vector2.ONE * 1.6
	const KINDS: Array[String] = ["cup", "fast", "bag"]
	var made: Array[Enemy] = []
	for row in KINDS.size():
		for col in 4:
			var pos := Vector2(-150.0 + float(col) * 100.0, -180.0 + float(row) * 180.0)
			var e: Enemy = _g.enemies.spawn(pos, 99999.0, 0.0, 1, KINDS[row],
				false, 0.0, false, col == 3)
			if e != null:
				made.append(e)
	# 先让登场缩放跑完（0.18s 从 0.01 拉到 1）。**不能**一 spawn 就 set_process(false)：
	# 那只会在 scale=0.01 时把这批敌人冻住，截出来是一张空街 —— 第一次就这么翻车了。
	await get_tree().create_timer(0.30).timeout
	var i := 0
	for row in KINDS.size():
		for col in 4:
			if i >= made.size():
				break
			var e: Enemy = made[i]
			i += 1
			e.set_process(false)
			if col < 3 and e._frames.size() == 3:
				e.art.texture = e._frames[col]
	await get_tree().create_timer(0.1).timeout
	await _snap("v71_frames")

func _move_player_to(pos: Vector2) -> void:
	_g.player.global_position = pos
	var cam: Camera2D = _g.camera
	cam.global_position = pos
	# 相机有平滑（position_smoothing_speed=9），直接写位置会被下一帧拉回去
	cam.reset_smoothing()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var out := "user://%s.png" % name
	var err: int = img.save_png(out)
	print("SHOT %-14s err=%d %s" % [name, err, ProjectSettings.globalize_path(out)])
