extends CanvasLayer
class_name LevelUpUI

# 升级三选一：全树暂停 → 弹 3 张卡 → 选完恢复。
# 卡框用 ui_paper_card.svg（200x280，宣纸浅底），内容用色块 + 武器图标贴图。
# ⚠️ 换皮后卡面是**浅底**，文字必须用墨色；原先的白/浅灰配色在宣纸上看不清（对比度 ≈1.1:1）。
#    若要把卡框切回旧深底 ui_card_frame.svg，这个文件的配色必须同步回滚，否则变成"深底黑字"。

# 连续升级（一次捡一堆宝石）用 _pending 排队，不吞卡也不重复弹。
#
# 暂停安全阀：Godot 的 get_tree().paused 是全局开关，一旦"暂停了却没人能点"整局就死锁
# （LevelUpUI 自己的 process_mode 是 ALWAYS，所以它以为还活着，其实游戏已经卡死）。
# 因此这里三件事同时做：①UI 根节点必须拦截 mouse_filter；②_mask 不拦截，让点击穿透到卡片；
# ③_pending 归零即无条件解除暂停，不依赖任何外部调用。

const CARD_W := 200.0
const CARD_H := 280.0
const CARD_GAP := 12.0
# 卡面（宣纸浅底）专用配色：保留"金=武器 / 青=被动"的色相识别，整体压暗到能读。
const ACCENT_WEAPON := Color(0.62, 0.38, 0.06)
const ACCENT_STAT := Color(0.10, 0.40, 0.38)
const INK_NAME := Color(0.13, 0.10, 0.08)
const INK_DESC := Color(0.32, 0.26, 0.20)

@onready var mask: ColorRect = $Mask
@onready var popup: CenterContainer = $Popup
@onready var title: Label = $Popup/VB/Title
@onready var cards: HBoxContainer = $Popup/VB/Cards
@onready var hint: Label = $Popup/VB/Hint

var _pending := 0
var _frame: Texture2D = null
var _icons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# CanvasLayer 本身没有 mouse_filter；拦截输入靠下面各 Control 子节点的设置
	mask.visible = false
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = Art.tex(Art.UI_CARD_FRAME)
	# 武器卡的图标由 WeaponDB 统一给出，加武器不用再回来改这里
	for id in WeaponDB.ORDER:
		_icons[id] = Art.tex(WeaponDB.svg(id))
	# 被动卡的图标：走 Art.STAT_ICON 统一表（图鉴读的是同一份，改图只改一处）
	for sid in Art.STAT_ICON.keys():
		_icons[String(sid)] = Art.tex(String(Art.STAT_ICON[sid]))

func bind(player: Player) -> void:
	if not player.level_up.is_connected(_on_level_up):
		player.level_up.connect(_on_level_up)

func _on_level_up() -> void:
	_pending += 1
	if not get_tree().paused:
		_show_next()

func is_open() -> bool:
	return popup.visible

func pending() -> int:
	return _pending

## 收起所有卡片并恢复游戏。卡池抽空、重开、异常退出都走这里，保证不会留下"暂停但无人可点"
func close_all() -> void:
	_pending = 0
	_clear_cards()
	mask.visible = false
	popup.visible = false
	if get_tree().paused:
		get_tree().paused = false

func _clear_cards() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()

func _show_next() -> void:
	_clear_cards()
	if _pending <= 0:
		close_all()
		return

	_pending -= 1
	get_tree().paused = true
	mask.visible = true
	popup.visible = true

	var options: Array[Dictionary] = UpgradeDB.draw(UpgradeDB.CARD_COUNT)
	if options.is_empty():
		# 卡池抽空：直接回满血，递归处理剩余排队次数，避免卡在暂停界面
		GameManager.stats["hp"] = GameManager.stats["max_hp"]
		_show_next()
		return
	title.text = "手艺精进  Lv %d" % GameManager.player.level
	hint.text = "选一张传承卡 · 还有 %d 次待处理" % _pending if _pending > 0 else "选一张传承卡"
	for option in options:
		cards.add_child(_make_card(option))

func _make_card(entry: Dictionary) -> Control:
	var def: Dictionary = entry["def"]
	var id: String = String(def["id"])
	var is_new: bool = bool(entry["is_new"])
	var is_weapon: bool = UpgradeDB.is_weapon(id)
	var accent: Color = ACCENT_WEAPON if is_weapon else ACCENT_STAT

	var root := Control.new()
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.size = Vector2(CARD_W, CARD_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 卡框贴图
	var frame := TextureRect.new()
	frame.texture = _frame
	frame.size = Vector2(CARD_W, CARD_H)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_new:
		frame.modulate = Color(1.25, 1.15, 0.85)
	root.add_child(frame)

	# 图标：卡框内圈圆心在 (100, 90)，半径 52
	var icon := TextureRect.new()
	icon.texture = _icons.get(id, _frame)
	icon.position = Vector2(100.0 - 34.0, 90.0 - 34.0)
	icon.size = Vector2(68.0, 68.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	var kind := Label.new()
	# 卡面标签：武器 → 传承，被动 → 口诀（真值表 §0）。
	# 新解锁保留一个"新"字：原来写"新武器"，只换 noun 会让"这张是新拿到的"
	# 这条信息消失；13px × 4 字约 52px，卡宽 200 装得下。
	if is_weapon:
		kind.text = "传承 · 新" if is_new else "传承"
	else:
		kind.text = "口诀 %d/%d" % [int(entry["new_level"]), UpgradeDB.STAT_MAX]
	# 精炼卡：不是"升级"也不是"新武器"，标签必须单独一句，
	# 否则玩家会以为这把武器还能继续涨等级（它已经 Lv8 了）。
	var refine: int = int(entry.get("refine", 0))
	if refine > 0:
		kind.text = "精炼 %d/%d" % [refine, UpgradeDB.REFINE_MAX]
	kind.add_theme_font_size_override("font_size", 13)
	kind.add_theme_color_override("font_color", accent)
	kind.position = Vector2(0.0, 12.0)
	kind.size = Vector2(CARD_W, 20.0)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kind)

	var name_label := Label.new()
	name_label.text = String(def["name"])
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", INK_NAME)
	name_label.position = Vector2(0.0, 182.0)
	name_label.size = Vector2(CARD_W, 30.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)

	var lv_label := Label.new()
	lv_label.text = "Lv 1" if is_new else "Lv %d → %d" % [int(entry["new_level"]) - 1, int(entry["new_level"])]
	if refine > 0:
		lv_label.text = "精炼 %d → %d（Lv%d 满级）" % [refine - 1, refine, WeaponDB.MAX_LEVEL]
	# 满级武器补一句"等宝箱"：让玩家知道 8 级不是终点，进化才是
	if is_weapon and refine <= 0 and int(entry["new_level"]) >= WeaponDB.MAX_LEVEL and EvolutionDB.can_evolve(id):
		lv_label.text = "Lv %d · 满级可传承" % WeaponDB.MAX_LEVEL
	lv_label.add_theme_font_size_override("font_size", 14)
	lv_label.add_theme_color_override("font_color", accent)
	lv_label.position = Vector2(0.0, 160.0)
	lv_label.size = Vector2(CARD_W, 20.0)
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lv_label)

	var desc := Label.new()
	# 描述一律由 CardText 从数值公式反推：
	#   武器升级 → "伤害 +12% / 发数 1 → 2"（这一级真的变了什么）
	#   武器首得 → 风味 + 一级身板（"伤害 16 · 冷却 1.60s / 每次 2 发"）
	#   被动     → "全部伤害 +10% / 累计 +30%"
	# 手写文案说过"身前一片"，却从来不说升这一级能多打多少 —— 那正是玩家要判断的东西。
	var lv_to: int = int(entry["new_level"])
	if refine > 0:
		desc.text = CardText.refine_desc(id, refine)
	elif is_weapon:
		desc.text = CardText.weapon_desc(id, lv_to - 1, lv_to)
	else:
		desc.text = CardText.stat_desc(id, lv_to)
	# ⚠️ 描述区宽度受卡框的**右下印章**约束：印章占 x∈[155,181]、y∈[237,263]，
	# 而卡内可用区是 x∈[18,182] —— 居中对齐时任何宽过 155-18 的行都会压到印章下面。
	# 所以这里窄到 128px 并改左对齐（数字列表左对齐本身也更好读）。
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", INK_DESC)
	desc.position = Vector2(24.0, 212.0)
	desc.size = Vector2(128.0, 56.0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(desc)

	# 交互层：整张卡都可点（Button 默认 MOUSE_FILTER_STOP，点击不会穿透到摇杆）
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", _hover_style())
	btn.add_theme_stylebox_override("pressed", _hover_style())
	btn.pressed.connect(_on_pick.bind(entry))
	root.add_child(btn)

	root.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
	return root

func _hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.35, 0.55, 0.85, 0.14)
	s.set_corner_radius_all(12)
	return s

func _on_pick(entry: Dictionary) -> void:
	UpgradeDB.apply(entry)
	_show_next()

## 键盘 1/2/3 也能选卡：桌面与自动化测试都靠这条路径，不依赖鼠标坐标
func _unhandled_key_input(event: InputEvent) -> void:
	if not popup.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var idx: int = -1
	match key.keycode:
		KEY_1, KEY_KP_1:
			idx = 0
		KEY_2, KEY_KP_2:
			idx = 1
		KEY_3, KEY_KP_3:
			idx = 2
	if idx < 0 or idx >= cards.get_child_count():
		return
	var root: Control = cards.get_child(idx) as Control
	for c in root.get_children():
		if c is Button:
			(c as Button).pressed.emit()
			get_viewport().set_input_as_handled()
			return
