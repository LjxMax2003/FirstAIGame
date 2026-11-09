extends CanvasLayer
class_name CodexUI

# =====================================================================
# 百工图鉴（v7.1 / T12 · 策划案 §4.3 优先级 4）
#
# 【为什么是四个页签，不是一条长滚动】
# 36 条在 720x1280 上竖排要滚四屏多。滚动列表的问题是"看不到边"：
# 玩家滑到一半不知道还剩多少，收集欲就被磨掉了。四个页签各自 9 条封顶，
# 3x3 一屏装得下，页签上直接写"7/9" —— 进度是可数的。
#
# 【为什么未收录也显示名字】
# 名字不剧透玩法（"残面"听起来就是个谜），但它是**目标**。
# 如果连名字都藏起来，玩家只会看到九个"？"，不知道该期待什么。
# 藏起来的是说明与图：图用暗剪影，说明写"—— 尚未收录 ——"。
#
# 【为什么顶栏写"12 / 36"而不是百分比】
# 图鉴是收集，收集要能一个一个数。百分比把"还差几条"这件事模糊掉了。
# =====================================================================

signal closed

const PANEL_W := 668.0
const COLS := 3
const CARD_W := 196.0
# 卡高按"最长的说明"定：对手那 9 条是两段、最多四行。
## 按最短的（手艺，一行）定会让对手页文字贴底 —— 那是内容，不该被截。
const CARD_H := 200.0

const C_TEXT := Color(0.95, 0.92, 0.85)
const C_DIM := Color(0.60, 0.58, 0.54)
const C_GOLD := Color(1.0, 0.84, 0.44)
const C_HIDE := Color(0.44, 0.42, 0.40)

var _root: Control
var _title: Label
var _count: Label
var _grid: GridContainer
var _tabs: HBoxContainer
var _empty: Label
var _cards: Dictionary = {}
var _tab := CodexDB.KIND_WEAPON

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

	# 底：整屏的旧纸底（720x1280，和屏幕同尺寸，直接铺满不用拉伸）
	var bg := TextureRect.new()
	bg.name = "Bg"
	bg.texture = Art.tex(Art.CODEX_BG)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# 底图压暗：codex_bg 是"宣纸 + 红框 + 一枚大印"，本身很亮也很抢眼。
	# 不压的话卡片会像贴在一张亮纸上，正文的对比度全被底纹吃掉；
	# 压到 0.55 之后它就退成纸纹，面板才是主体。
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.03, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.07, 0.86)
	sb.border_color = Color(0.50, 0.36, 0.20, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# 标题：木牌底 + 匾上的字
	var sign_row := CenterContainer.new()
	sign_row.name = "SignRow"
	vb.add_child(sign_row)
	var sign := Control.new()
	sign.name = "Sign"
	sign.custom_minimum_size = Vector2(240.0, 80.0)
	sign_row.add_child(sign)
	var sign_bg := TextureRect.new()
	sign_bg.texture = Art.tex(Art.UI_WOOD_SIGN)
	sign_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sign_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sign_bg.stretch_mode = TextureRect.STRETCH_SCALE
	sign_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(sign_bg)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "百工图鉴"
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.16, 0.10, 0.06))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(_title)

	_count = Label.new()
	_count.name = "Count"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 14)
	_count.add_theme_color_override("font_color", C_GOLD)
	vb.add_child(_count)

	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 6)
	vb.add_child(_tabs)
	for k in CodexDB.KIND_ORDER:
		var b := Button.new()
		b.name = "Tab_%s" % k
		b.custom_minimum_size = Vector2(150.0, 44.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_on_tab.bind(k))
		_tabs.add_child(b)

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(_grid)

	# 页签为空时的兜底文案（理论上不会用到：四条轴都不为空，
	# 但没有它的话"某条轴真的空了"会表现成一片空白，看着像卡死）
	_empty = Label.new()
	_empty.name = "Empty"
	_empty.text = "这一类还没收录到东西"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", 14)
	_empty.add_theme_color_override("font_color", C_DIM)
	_empty.visible = false
	vb.add_child(_empty)

	var close_btn := Button.new()
	close_btn.name = "Close"
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.add_theme_font_size_override("font_size", 19)
	close_btn.add_theme_color_override("font_color", C_TEXT)
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)

func _make_card(e: Dictionary) -> Control:
	var id: String = String(e["id"])
	var card := PanelContainer.new()
	card.name = "Card_%s" % id
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 2)
	card.add_child(body)

	# 图与印章重叠放在一个 Control 里：印章要压在右上角，用容器做不到
	var art_box := Control.new()
	art_box.name = "ArtBox"
	art_box.custom_minimum_size = Vector2(CARD_W - 12.0, 84.0)
	body.add_child(art_box)

	var art := TextureRect.new()
	art.name = "Art"
	art.texture = Art.tex(String(e["svg"]))
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.add_child(art)

	var seal := TextureRect.new()
	seal.name = "Seal"
	seal.texture = Art.tex(Art.UI_SEAL)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.custom_minimum_size = Vector2(38.0, 38.0)
	seal.size = Vector2(38.0, 38.0)
	seal.position = Vector2(CARD_W - 60.0, 2.0)
	seal.pivot_offset = Vector2(19.0, 19.0)
	seal.rotation = deg_to_rad(-10.0)
	seal.modulate = Color(1.0, 0.86, 0.52, 0.95)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.add_child(seal)

	var name_l := Label.new()
	name_l.name = "Name"
	name_l.add_theme_font_size_override("font_size", 17)
	body.add_child(name_l)

	var tag_l := Label.new()
	tag_l.name = "Tag"
	tag_l.add_theme_font_size_override("font_size", 12)
	tag_l.add_theme_color_override("font_color", C_DIM)
	body.add_child(tag_l)

	var desc_l := Label.new()
	desc_l.name = "Desc"
	desc_l.add_theme_font_size_override("font_size", 12)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.custom_minimum_size = Vector2(0, 60)
	body.add_child(desc_l)

	_cards[id] = {"card": card, "art": art, "seal": seal,
		"name": name_l, "tag": tag_l, "desc": desc_l}
	return card

# ---------------------------------------------------------------- 刷新
func refresh() -> void:
	if _grid == null:
		return
	# 每次换页签都重建卡片：36 张卡的布局/状态全在一次 refresh 里定完，
	# 比"复用旧卡再逐张改可见性"少一类"上一页的卡忘了隐藏"的 bug。
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()

	var total: int = CodexDB.seen_count()
	_count.text = "已收录 %s" % CodexDB.progress_line()
	# 进度按页签拆开写：玩家能直接看出"还差的是哪一类"
	for k in CodexDB.KIND_ORDER:
		var b: Button = _tabs.get_node("Tab_%s" % k) as Button
		var on: bool = k == _tab
		b.text = "%s %d/%d" % [String(CodexDB.KIND_NAME[k]),
			CodexDB.seen_in(k), CodexDB.total_of(k)]
		b.add_theme_color_override("font_color", C_GOLD if on else C_TEXT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.15, 0.08, 0.95) if on else Color(0.11, 0.11, 0.12, 0.9)
		sb.border_color = C_GOLD if on else Color(0.33, 0.29, 0.23, 0.8)
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(4.0)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)

	var list: Array[Dictionary] = CodexDB.of_kind(_tab)
	_empty.visible = list.is_empty()
	for e in list:
		var card := _make_card(e)
		_grid.add_child(card)
		_paint(String(e["id"]))

func _paint(id: String) -> void:
	var parts: Dictionary = _cards.get(id, {})
	if parts.is_empty():
		return
	var e: Dictionary = CodexDB.entry(id)
	var seen: bool = CodexDB.is_seen(id)
	var card: PanelContainer = parts["card"]
	var art: TextureRect = parts["art"]
	var seal: TextureRect = parts["seal"]
	var name_l: Label = parts["name"]
	var tag_l: Label = parts["tag"]
	var desc_l: Label = parts["desc"]

	name_l.text = String(e.get("name", id))
	tag_l.text = String(e.get("tag", ""))
	if seen:
		art.modulate = Color.WHITE
		seal.visible = true
		name_l.add_theme_color_override("font_color", C_GOLD)
		desc_l.text = String(e.get("desc", ""))
		desc_l.add_theme_color_override("font_color", Color(0.80, 0.78, 0.74))
	else:
		# 未收录：只留剪影。0.14 实测太黑（Boss 那几张直接是一团黑），
		# 抬到 0.30 并往冷色偏一点 —— 轮廓认得出，细节仍然读不到。
		art.modulate = Color(0.30, 0.32, 0.38)
		seal.visible = false
		name_l.add_theme_color_override("font_color", C_HIDE)
		desc_l.text = "—— 尚未收录 ——"
		desc_l.add_theme_color_override("font_color", C_HIDE)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.11, 0.92) if seen else Color(0.09, 0.09, 0.10, 0.85)
	sb.border_color = Color(1.0, 0.84, 0.44, 0.55) if seen else Color(0.26, 0.24, 0.21, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(6.0)
	card.add_theme_stylebox_override("panel", sb)

func _on_tab(kind: String) -> void:
	_tab = kind
	refresh()

# ---------------------------------------------------------------- 开关
func open(kind: String = "") -> void:
	if kind != "":
		_tab = kind
	visible = true
	# 打开图鉴 = 一个明确的安全时机：把这一局攒下的收录写盘
	MetaSave.flush_codex()
	refresh()

func close() -> void:
	visible = false
	# 关掉才算"看过了"：玩家可能只是扫一眼就返回，
	# 但"新收录"的标记本来就是为了让他扫这一眼。
	CodexDB.clear_fresh()
	closed.emit()

func is_open() -> bool:
	return visible

func current_tab() -> String:
	return _tab

## 给验收用：某张卡的显示文本（不读内部字典、不碰私有字段）
func card_text(id: String, field: String) -> String:
	if not _cards.has(id):
		return ""
	var node: Node = (_cards[id] as Dictionary).get(field, null)
	return (node as Label).text if node is Label else ""

func card_seen_mark_visible(id: String) -> bool:
	if not _cards.has(id):
		return false
	var seal: Node = (_cards[id] as Dictionary).get("seal", null)
	return seal is TextureRect and (seal as TextureRect).visible
