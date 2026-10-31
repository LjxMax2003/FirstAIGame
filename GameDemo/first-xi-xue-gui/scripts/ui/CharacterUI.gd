extends CanvasLayer
class_name CharacterUI

# =====================================================================
# 匠人选择（v7.1 / T9 · 策划案 §4.3 优先级 1）
#
# 【为什么是一列 5 张卡，而不是 5 宫格立绘墙】
# 720x1280 竖屏，五行卡正好把"立绘 + 定位 + 起始武器 + 解锁条件"四件事各放一行；
# 换成宫格就得把解锁条件压成一行小字，而解锁条件是这张卡里最该被读到的部分
# （它是玩家下一局的动机）。空间不够时，先牺牲立绘尺寸，不能牺牲条件文案。
#
# 【为什么锁着的角色也画出来】
# 藏起来等于"玩家不知道自己错过了什么"。锁着的卡显示灰色立绘 + 条件 + 进度，
# 这是唯一能把"再打一局"变成具体目标的界面。
#
# 【为什么选中立刻落盘，而不是点"确定"】
# 这个面板没有"取消"语义：选了就是选了，下次开局生效。多一个确定按钮只是在
# 问玩家"你确定你刚才点的是你想点的那个吗"，而卡片上的高亮已经回答了这个问题。
# =====================================================================

signal closed

const PANEL_W := 660.0
const CARD_H := 168.0
const ART_SIZE := Vector2(112.0, 140.0)

const C_TEXT := Color(0.96, 0.93, 0.86)
const C_DIM := Color(0.62, 0.60, 0.56)
const C_GOLD := Color(1.0, 0.84, 0.44)
const C_LOCK := Color(0.55, 0.52, 0.50)

var _root: Control
var _cards: Dictionary = {}

func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var mask := ColorRect.new()
	mask.color = Color(0.02, 0.02, 0.04, 0.9)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(mask)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.09, 0.98)
	sb.border_color = Color(0.50, 0.36, 0.20, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "选一位匠人"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_GOLD)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "只有起手的手艺不同，属性完全一样"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", C_DIM)
	vb.add_child(sub)

	for e in CharacterDB.all():
		var card := _make_card(e)
		vb.add_child(card)

	var close_btn := Button.new()
	close_btn.name = "Close"
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(0, 54)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", C_TEXT)
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)

func _make_card(e: Dictionary) -> Button:
	var id: String = String(e["id"])
	# 整张卡就是一个 Button：点哪儿都算选中，不用再给立绘挂一个子按钮
	var card := Button.new()
	card.name = "Card_%s" % id
	card.custom_minimum_size = Vector2(0, CARD_H)
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_on_pick.bind(id))

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var art := TextureRect.new()
	art.name = "Art"
	art.texture = Art.tex(String(e["svg"]))
	art.custom_minimum_size = ART_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

	var col := VBoxContainer.new()
	col.name = "Text"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var name_l := Label.new()
	name_l.name = "Name"
	name_l.add_theme_font_size_override("font_size", 21)
	col.add_child(name_l)

	var role_l := Label.new()
	role_l.name = "Role"
	role_l.add_theme_font_size_override("font_size", 13)
	role_l.add_theme_color_override("font_color", C_DIM)
	col.add_child(role_l)

	var line_l := Label.new()
	line_l.name = "Line"
	line_l.add_theme_font_size_override("font_size", 13)
	line_l.add_theme_color_override("font_color", Color(0.78, 0.76, 0.72))
	line_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_l.custom_minimum_size = Vector2(0, 34)
	col.add_child(line_l)

	var lock_l := Label.new()
	lock_l.name = "Lock"
	lock_l.add_theme_font_size_override("font_size", 13)
	col.add_child(lock_l)

	_cards[id] = {"card": card, "name": name_l, "role": role_l,
		"line": line_l, "lock": lock_l, "art": art}
	return card

# ---------------------------------------------------------------- 状态
func refresh() -> void:
	var cur: String = CharacterDB.current_id()
	for e in CharacterDB.all():
		var id: String = String(e["id"])
		var parts: Dictionary = _cards[id]
		var unlocked: bool = CharacterDB.is_unlocked(id)
		var sel: bool = id == cur
		var weapon: String = String(e["weapon"])
		var lv: int = CharacterDB.start_level(id)
		var role: String = String(e["role"])
		# 辅助档把 Lv2 写进定位行：否则玩家看不出"为什么这个角色起手就 2 级"
		if lv > 1:
			role += " · 起手 Lv2"
		(parts["role"] as Label).text = "%s · %s" % [role, WeaponDB.display_name(weapon)]
		(parts["line"] as Label).text = String(e["line"])
		(parts["name"] as Label).text = (String(e["name"]) + "（已选）") if sel else String(e["name"])
		if unlocked:
			(parts["name"] as Label).add_theme_color_override("font_color",
				C_GOLD if sel else C_TEXT)
			(parts["lock"] as Label).text = ""
			(parts["art"] as TextureRect).modulate = Color.WHITE
		else:
			(parts["name"] as Label).add_theme_color_override("font_color", C_LOCK)
			(parts["lock"] as Label).text = "未解锁 · %s  %s" % [String(e["unlock"]["text"]),
				CharacterDB.progress_text(id)]
			(parts["lock"] as Label).add_theme_color_override("font_color", C_LOCK)
			# 锁着的立绘压成灰：不是变暗到看不见，而是"看得出是谁但读不出颜色"
			(parts["art"] as TextureRect).modulate = Color(0.34, 0.34, 0.38)
		var card: Button = parts["card"]
		var normal := _style(sel, unlocked)
		var hot := _style(sel, true) if sel else _style(false, true)
		card.add_theme_stylebox_override("normal", normal)
		card.add_theme_stylebox_override("hover", hot)
		card.add_theme_stylebox_override("pressed", normal)
		card.add_theme_stylebox_override("focus", normal)

func _style(selected: bool, unlocked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(0.22, 0.17, 0.10, 0.95)
		sb.border_color = C_GOLD
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.14, 0.13, 0.13, 0.9) if unlocked else Color(0.10, 0.10, 0.11, 0.9)
		sb.border_color = Color(0.34, 0.30, 0.24, 0.8)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(2.0)
	return sb

# ---------------------------------------------------------------- 交互
func _on_pick(id: String) -> void:
	if not CharacterDB.is_unlocked(id):
		# 锁着就什么也不做，但把进度重刷一遍 —— 玩家点一下至少能得到"还差多少"的反馈
		refresh()
		return
	MetaSave.set_character(id)
	refresh()

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

## 给验收用：某张卡的显示文本（不读内部字典）
func card_text(id: String, field: String) -> String:
	if not _cards.has(id):
		return ""
	var parts: Dictionary = _cards[id]
	var node: Node = parts.get(field, null)
	return (node as Label).text if node is Label else ""
