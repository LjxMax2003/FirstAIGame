extends Node

# 卡面文案核对：把 CardText 生成的每一张卡都真的造出来，量"文字需要多高、多宽"。
#
# 【为什么不靠肉眼】
# 描述区只有 56px 高、且右下角还有一个 26×26 的印章（x∈[155,181], y∈[237,263]）。
# 12px 字每行 17px，4 行就 68px —— 差一点点就被卡框或印章吃掉半行，
# 截图不放大根本看不出来。所以这里直接用字体度量判定，截图只用来给人确认观感。
#
# 【覆盖范围】
# 不是抽几张样本，而是 9 把武器 × 8 级（含首得）+ 9 个被动 × 5 级，共 117 张全扫。
# 文案是生成出来的，就必须做到"每一级都成立"，不能只在抽查的那几级成立。
# 迭代02 加了第 4 张截图：满级武器三态（缺被动 / 待宝箱开脸 / 已开脸）。
#
# 用法：godot --path . res://tools/CardShot.tscn   （需要窗口，headless 无渲染）

const OUT_DIR := "user://"
## 描述区设计高度，与 LevelUpUI._make_card 里的 desc.size.y 一致
const DESC_H := 56.0
## 描述区设计宽度，与 LevelUpUI._make_card 里的 desc.size.x 一致
const DESC_W := 128.0
## 卡面高度，与 LevelUpUI.CARD_H 一致
const CARD_H := 280.0
## 印章左边缘：文字右端超过它就会压到印章上
const SEAL_X := 155.0
## 描述区左边缘
const DESC_X := 24.0

var _game: GameScene
var _bad: Array[String] = []
var _checked := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/Game.tscn") as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.started = false

	print("\n========== 卡面文案渲染核对 ==========")

	# 两张给人看的截图：一张武器（含首得 3 行上限 + 唯一出现"发数"的一级），一张被动
	await _shot("shot_cards_weapon.png", [
		{"id": "extinguisher", "from": 0},
		{"id": "glowstick", "from": 2},
		{"id": "whip", "from": 1},
	])
	await _shot("shot_cards_stat.png", [
		{"id": "might", "from": 0},
		{"id": "max_hp", "from": 0},
		{"id": "damage", "from": 0},
	])
	# 迭代02 S-02：满级武器三态（缺被动 / 待宝箱 / 已开脸）各一张，验"还差什么"能读且不压印章
	await _shot_evolve_states()

	print("\n========== 全量扫描（每级都要成立） ==========")
	await _sweep()

	print("\n---------- 结论 ----------")
	print("  共核对 %d 张卡" % _checked)
	if _bad.is_empty():
		print("  ok   全部卡面文案未溢出描述区、未压印章")
	else:
		for b in _bad:
			print("  FAIL %s" % b)
	print("\n==== 卡面核对：%s ====" % ("PASS" if _bad.is_empty() else "FAIL"))
	get_tree().quit(0 if _bad.is_empty() else 1)

func _shot(file: String, specs: Array) -> void:
	_game.level_up_ui._on_level_up()
	await get_tree().process_frame
	_game.level_up_ui._clear_cards()
	for s in specs:
		_game.level_up_ui.cards.add_child(_card_of(String(s["id"]), int(s["from"])))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(OUT_DIR + file)
	print("\nSHOT %s err=%d" % [ProjectSettings.globalize_path(OUT_DIR + file), err])
	for card in _game.level_up_ui.cards.get_children():
		_measure(card as Control)
	_game.level_up_ui.close_all()

## 迭代02 S-02：满级（Lv8）卡的三态必须"说清还差什么"。
## 三张卡分别是：缺夜行 / 已有夜行等宝箱 / 已开脸。除了截图，还把 lv 标签的
## 实际字宽与卡宽比较 —— 它是居中 200px，最坏情况会顶到右下印章。
func _shot_evolve_states() -> void:
	var pl: Player = GameManager.player as Player
	var wm: WeaponManager = GameManager.weapons as WeaponManager
	_game.level_up_ui._on_level_up()
	await get_tree().process_frame
	_game.level_up_ui._clear_cards()
	var row: HBoxContainer = _game.level_up_ui.cards
	# ① 满级但缺夜行 → "开脸需「夜行」"
	pl.level_upgrades.erase("speed")
	wm.evolved.erase("phone")
	row.add_child(_card_of("phone", WeaponDB.MAX_LEVEL - 1))
	# ② 已有夜行 Lv1 → "待宝箱开脸"
	pl.level_upgrades["speed"] = 1
	row.add_child(_card_of("phone", WeaponDB.MAX_LEVEL - 1))
	# ③ 已开脸 → "已开脸"
	wm.evolved["phone"] = "evolve_phone"
	row.add_child(_card_of("phone", WeaponDB.MAX_LEVEL - 1))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var file := "shot_cards_evolve_states.png"
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(OUT_DIR + file)
	print("\nSHOT %s err=%d" % [ProjectSettings.globalize_path(OUT_DIR + file), err])
	for card in row.get_children():
		var lv: Label = null
		for c in (card as Control).get_children():
			if c is Label and (c as Label).position.y >= 150.0 and (c as Label).position.y < 175.0:
				lv = c as Label
		if lv == null:
			continue
		var font: Font = lv.get_theme_font("font")
		var fsize: int = lv.get_theme_font_size("font_size")
		var w: float = font.get_string_size(lv.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		print("  满级卡「%s」宽 %.0fpx / 卡宽 %.0f" % [lv.text, w, LevelUpUI.CARD_W])
		if w > LevelUpUI.CARD_W - 8.0:
			_bad.append("满级三态「%s」宽 %.0fpx 超出卡宽 %.0f" % [lv.text, w, LevelUpUI.CARD_W])
	# 复位：探针不能把 speed / evolved 留在内存里影响后面的全量扫描
	pl.level_upgrades.erase("speed")
	wm.evolved.erase("phone")
	_game.level_up_ui.close_all()

## 全量：每张卡单独造、单独量、单独销毁（HBox 里同时放 83 张会互相挤压尺寸）
func _sweep() -> void:
	for id in WeaponDB.ORDER:
		for from_lv in range(0, WeaponDB.MAX_LEVEL):
			await _measure_one(id, from_lv)
	for sd in UpgradeDB.STAT_DEFS:
		var key: String = String(sd["id"])
		for from_lv in range(0, Stats.STAT_MAX):
			await _measure_one(key, from_lv)

func _measure_one(id: String, from_lv: int) -> void:
	_game.level_up_ui._on_level_up()
	await get_tree().process_frame
	_game.level_up_ui._clear_cards()
	var card: Control = _card_of(id, from_lv)
	_game.level_up_ui.cards.add_child(card)
	await get_tree().process_frame
	_measure(card)
	_game.level_up_ui._clear_cards()
	_game.level_up_ui.close_all()
	await get_tree().process_frame

func _card_of(id: String, from_lv: int) -> Control:
	var def: Dictionary = {
		"id": id,
		"kind": "weapon" if UpgradeDB.is_weapon(id) else "stat",
		"name": UpgradeDB.display_name(id),
		"desc": "",
	}
	var entry: Dictionary = {"def": def, "new_level": from_lv + 1, "is_new": from_lv == 0}
	return _game.level_up_ui._make_card(entry)

## 找出卡里的描述 Label（y 最大、含换行的那个），用字体度量判定是否越界
func _measure(card: Control) -> void:
	var desc: Label = null
	var name_lbl: Label = null
	var lv_lbl: Label = null
	for c in card.get_children():
		if c is not Label:
			continue
		var l: Label = c as Label
		# 卡内 Label 纵向分布：kind 12 / lv 160 / name 182 / desc 212。
		# 必须按区间判，只写 ">150" 会让 lv 与 name 互相覆盖。
		if l.position.y >= 200.0:
			desc = l
		elif l.position.y >= 175.0:
			name_lbl = l
		elif l.position.y >= 150.0:
			lv_lbl = l
	if desc == null:
		return
	_checked += 1

	var font: Font = desc.get_theme_font("font")
	var fsize: int = desc.get_theme_font_size("font_size")
	var need: Vector2 = font.get_multiline_string_size(
		desc.text, HORIZONTAL_ALIGNMENT_LEFT, DESC_W, fsize)
	var title: String = "%s %s ｜ %s" % [
		lv_lbl.text if lv_lbl != null else "?",
		name_lbl.text if name_lbl != null else "?",
		desc.text.replace("\n", " ／ ")]

	# ⚠️ 不能拿 desc.size 当"可用空间"：Label 会被自身最小尺寸撑大（4 行时实测涨到 101），
	#    用它比较等于拿被撑开的口袋量东西，永远不溢出。一律对设计值判定。
	if need.y > DESC_H + 0.5:
		_bad.append("%s → 文案 %d 行 %.0fpx 超过描述区 %.0fpx" % [
			title, desc.text.split("\n").size(), need.y, DESC_H])
	if DESC_X + need.x > SEAL_X:
		_bad.append("%s → 最宽一行 %.0fpx 会压到右下印章（可用 %.0fpx）" % [
			title, need.x, SEAL_X - DESC_X])
	if desc.position.y + need.y > CARD_H + 0.5:
		_bad.append("%s → 文字底边 %.0f 越出卡面 %.0f" % [title, desc.position.y + need.y, CARD_H])
