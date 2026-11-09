extends Node

# 迭代04 升级选卡界面核对：8 条机械断言 + 4 张视觉留档。
# 【为什么必须实测】入场/出场/悬停全是 tween，静态读代码只能证明"写了"，
# 证明不了"同一帧里三张卡各在什么位姿"、"连点三次会不会 apply 三次"。
# 【用法】godot --path . res://tools/LevelUpShot.tscn   （需要窗口，headless 无渲染）

const OUT_DIR := "res://shots/"

var _game: GameScene
var _ui: LevelUpUI
var _passes := 0
var _fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/Game.tscn") as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.started = false
	_ui = _game.level_up_ui

	print("\n========== 迭代04 升级选卡界面核对 ==========")
	await _case_enter()
	await _case_hover()
	await _case_exit()
	await _case_input_lock()
	await _case_full_level()

	print("\n---------- 结论 ----------")
	print("  PASS %d / FAIL %d" % [_passes, _fails.size()])
	for f in _fails:
		print("  FAIL %s" % f)
	print("\n==== 升级界面核对：%s ====" % ("PASS" if _fails.is_empty() else "FAIL"))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  ok   %s" % label)
	else:
		_fails.append(label)
		print("  FAIL %s" % label)

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(OUT_DIR + file)
	print("SHOT %s err=%d" % [ProjectSettings.globalize_path(OUT_DIR + file), err])

func _open() -> void:
	_ui._on_level_up()
	await get_tree().process_frame

## 等若干帧。动画敏感的地方一律按帧等 —— 截图回读会阻塞主线程，
## 墙钟（create_timer）与 tween 的推进不再同步（实测墙钟 0.19s 时动画只走了 0.115s）。
func _wait_anim(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

## 等本批入场 tween 收尾（_enter 在 tween.finished 之后才把 _picking 放行）。
func _wait_pick_idle(frames: int = 120) -> void:
	for i in frames:
		if not _ui._picking:
			return
		await get_tree().process_frame

## 断言 1~3：层级 / 入场起三卡近乎透明 / 入场收尾全部归位。
func _case_enter() -> void:
	_open()
	_ok(_ui.layer > 10, "UI-01 层级 > 10（实测 %d）" % _ui.layer)
	await _wait_anim(1)
	for c in _ui.cards.get_children():
		_ok((c as Control).modulate.a < 0.35, "UI-04 入场起 卡 alpha=%.2f < 0.35" % (c as Control).modulate.a)
	await _shot("ui_lv_enter_0.png")
	await _wait_pick_idle()
	var total: int = _ui.cards.get_child_count()
	for i in total:
		var c: Control = _ui.cards.get_child(i) as Control
		var pose: Dictionary = c.get_meta("rest_pose", {"rot": 0.0, "scale": 1.0})
		_ok(absf(c.modulate.a - 1.0) < 0.01, "UI-04 入场收尾 卡%d alpha=1.0（%.2f）" % [i, c.modulate.a])
		_ok(absf(c.rotation - float(pose["rot"])) < 0.002, "UI-04 入场收尾 卡%d 回正（%.3f°）" % [i, rad_to_deg(c.rotation)])
	# 断言 3：静止位姿（两侧 ±3.2° / 0.965，中间 0° / 1.0）
	if total >= 3:
		var c0: Control = _ui.cards.get_child(0) as Control
		var c1: Control = _ui.cards.get_child(1) as Control
		var c2: Control = _ui.cards.get_child(2) as Control
		_ok(absf(rad_to_deg(c0.rotation) + LevelUpUI.TILT_DEG) < 0.2, "UI-03 左卡倾角 %.2f° ≈ -3.2°" % rad_to_deg(c0.rotation))
		_ok(absf(c0.scale.x - LevelUpUI.SIDE_SCALE) < 0.002, "UI-03 左卡缩放 %.3f ≈ 0.965" % c0.scale.x)
		_ok(absf(c1.rotation) < 0.002 and absf(c1.scale.x - 1.0) < 0.002, "UI-03 中间卡不转不缩")
		_ok(absf(rad_to_deg(c2.rotation) - LevelUpUI.TILT_DEG) < 0.2, "UI-03 右卡倾角 %.2f° ≈ +3.2°" % rad_to_deg(c2.rotation))
		_ok(absf(c2.scale.x - LevelUpUI.SIDE_SCALE) < 0.002, "UI-03 右卡缩放 %.3f ≈ 0.965" % c2.scale.x)
	# 战场降调（UI-02b）
	var w: Node = _ui._world()
	var dimmed: bool = w != null and (w as CanvasItem).modulate != Color.WHITE
	_ok(dimmed, "UI-02b 战场已降调（modulate=%s）" % (str((w as CanvasItem).modulate) if w != null else "null"))
	await _shot("ui_lv_idle.png")
	# 交接收据要的两个数（handoff §14）：三张卡局部底边 y 必须相等（HBox 保证），
	# 投影最大间距 = 最上层投影底边 − 卡底边（用来核对"影子拉得够不够长"）。
	var bottoms: Array[float] = []
	var gap_max: float = 0.0
	for c in _ui.cards.get_children():
		var cc: Control = c as Control
		bottoms.append(cc.position.y + LevelUpUI.CARD_H)
		var shadows: Array = cc.get_meta("shadows", [])
		if shadows.size() > 0:
			var sh: TextureRect = shadows[0] as TextureRect
			var sh_bottom: float = (sh.position.y + sh.pivot_offset.y) \
				+ (sh.size.y - sh.pivot_offset.y) * sh.scale.y
			gap_max = maxf(gap_max, sh_bottom - LevelUpUI.CARD_H)
	print("  几何：三卡底边 y=%s ；投影最大间距 %.1fpx" % [str(bottoms), gap_max])

## 断言：悬停 → 转正 + 抬高 12px + 放大 1.055× + 投影变淡拉长。
func _case_hover() -> void:
	if _ui.cards.get_child_count() < 1:
		_ok(false, "UI-06 无卡可悬停")
		return
	var c: Control = _ui.cards.get_child(0) as Control
	var pose: Dictionary = c.get_meta("rest_pose", {"rot": 0.0, "scale": 1.0})
	var ry: float = float(c.get_meta("rest_y", c.position.y))
	var shadows: Array = c.get_meta("shadows", [])
	_ui._hover(c, true)
	await _wait_anim(10)
	_ok(absf(c.scale.x - LevelUpUI.HOVER_SCALE) < 0.01, "UI-06 悬停缩放 %.3f ≈ 1.055" % c.scale.x)
	_ok(absf(c.rotation) < 0.002, "UI-06 悬停转正（%.3f°）" % rad_to_deg(c.rotation))
	_ok(absf(c.position.y - (ry - 12.0)) < 0.5, "UI-06 悬停上移 12px（y=%.1f / rest=%.1f）" % [c.position.y, ry])
	if shadows.size() > 0:
		var sh: TextureRect = shadows[0] as TextureRect
		var ba: float = float(sh.get_meta("base_a", 0.0))
		var by: float = float(sh.get_meta("base_y", 0.0))
		_ok(absf(sh.modulate.a - ba * 0.55) < 0.02, "UI-06 悬停投影变淡 a=%.3f ≈ %.3f" % [sh.modulate.a, ba * 0.55])
		_ok(absf(sh.position.y - by * 1.35) < 0.5, "UI-06 悬停投影拉长 y=%.1f ≈ %.1f" % [sh.position.y, by * 1.35])
	await _shot("ui_lv_hover.png")
	_ui._hover(c, false)
	await _wait_anim(12)
	_ok(absf(c.scale.x - float(pose["scale"])) < 0.01, "UI-06 移出恢复静止缩放 %.3f" % c.scale.x)
	_ok(absf(c.position.y - ry) < 0.5, "UI-06 移出恢复静止高度（y=%.1f）" % c.position.y)

## 断言：出场 0.20s 被选卡缩到 0.02、其余卡旋转 >8°、0.50s 后全收。
func _case_exit() -> void:
	var total: int = _ui.cards.get_child_count()
	if total < 1:
		_ok(false, "UI-05 无卡可出场")
		return
	var pick := 1 if total >= 2 else 0
	_ui._on_pick(pick)
	# 截图取 t≈0.12（handoff §9.2）：再晚就只剩两张已淡出的落选卡，看不出"翻面/带倒"。
	await _wait_anim(4)
	await _shot("ui_lv_exit.png")
	# 断言取"出场 tween 收尾那一帧"，不靠墙钟窗口：截图回读会阻塞主线程，
	# SceneTreeTimer 与 Tween 的推进不再同步（实测墙钟 0.19s 时动画只走了 0.115s）。
	var tw: Tween = _ui._tw
	if tw != null and tw.is_valid():
		await tw.finished
	if _ui.cards.get_child_count() <= pick:
		_ok(false, "UI-05 出场收尾时卡片已不在（无法断言翻面）")
	else:
		var win: Control = _ui.cards.get_child(pick) as Control
		_ok(win.scale.x < 0.05, "UI-05 出场收尾 被选卡缩到 %.3f < 0.05" % win.scale.x)
		for i in total:
			if i == pick:
				continue
			var c: Control = _ui.cards.get_child(i) as Control
			_ok(absf(rad_to_deg(c.rotation)) > 8.0, "UI-05 出场收尾 卡%d 旋转 %.1f° > 8°" % [i, rad_to_deg(c.rotation)])
	await _wait_anim(30)
	_ok(not _ui.mask.visible and not _ui.popup.visible, "UI-05 出场结束后弹出层已收起")
	_ok(not get_tree().paused, "UI-05 出场结束后解除暂停")
	var w: Node = _ui._world()
	_ok(w == null or (w as CanvasItem).modulate == Color.WHITE, "UI-02b 出场后战场恢复原色")

## 断言：`_picking` 期间连点 3 次只生效 1 次。
func _case_input_lock() -> void:
	_open()
	await _wait_pick_idle()
	var pl: Player = GameManager.player as Player
	var wm: WeaponManager = GameManager.weapons as WeaponManager
	var before: int = _sum_levels(pl, wm)
	var card: Control = _ui.cards.get_child(0) as Control
	var btn: Button = null
	for c in card.get_children():
		if c is Button:
			btn = c as Button
	if btn == null:
		_ok(false, "UI-05 卡片没有按钮，无法测试连点")
		return
	btn.pressed.emit()
	btn.pressed.emit()
	btn.pressed.emit()
	await get_tree().create_timer(0.50).timeout
	var after: int = _sum_levels(pl, wm)
	_ok(after - before == 1, "UI-05 连点 3 次只 apply 1 次（%d → %d）" % [before, after])

func _sum_levels(pl: Player, wm: WeaponManager) -> int:
	var n := 0
	for v in pl.level_upgrades.values():
		n += int(v)
	for v in wm.owned.values():
		n += int(v)
	for v in wm.refines.values():
		n += int(v)
	return n

## 断言：满级武器三态卡的文字位置仍为 y=212（_decorate 不能把文字挤走）。
func _case_full_level() -> void:
	_ui.close_all()
	await get_tree().process_frame
	var wid := "phone"
	for from_lv in [WeaponDB.MAX_LEVEL - 1, WeaponDB.MAX_LEVEL - 1, WeaponDB.MAX_LEVEL - 1]:
		var def: Dictionary = {
			"id": wid,
			"kind": "weapon",
			"name": UpgradeDB.display_name(wid),
			"desc": "",
		}
		var entry: Dictionary = {"def": def, "new_level": int(from_lv) + 1, "is_new": false}
		_ui.cards.add_child(_ui._make_card(entry))
	await get_tree().process_frame
	for card in _ui.cards.get_children():
		var desc: Label = null
		for c in (card as Control).get_children():
			if c is Label and (c as Label).position.y >= 200.0:
				desc = c as Label
		if desc != null:
			_ok(absf(desc.position.y - 212.0) < 0.5, "UI-03 满级三态描述 Label y=%.1f（应 212）" % desc.position.y)
	_ui.close_all()
