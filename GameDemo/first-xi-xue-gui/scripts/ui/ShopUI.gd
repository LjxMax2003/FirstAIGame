extends CanvasLayer
class_name ShopUI

# 金币 Meta 商店（Step 12）。
#
# 【为什么只从结算界面进入】
# 局外加成在 Game._ready 里算进 GameManager.stats，中途买的东西本局不生效。
# 如果在暂停菜单里也能开店，就会出现"我买了攻击 +15% 但打起来没变"的错觉 ——
# 这是 meta 系统最常见的信任崩塌点。所以入口只放在结算界面：
# 买完 → 再来一局 → 立刻能感觉到。这也正是"再来一局"钩子的落点。
#
# 【布局为什么在代码里拼】
# 五行结构完全一样，差别只有图标/文案/价格。写进 .tscn 就是五份几乎相同的节点树，
# 以后加第六条线要改六处；拼出来只改 TRACKS 一处（和 UpgradeDB 的卡池同一个思路）。

signal closed

## 行高：五行 + 头尾正好塞进 720x1280 竖屏，不用滚动条（移动端滚动条很难点）
const ROW_H := 88.0

const COL_NAME := Color(0.96, 0.97, 1.0)
const COL_DESC := Color(0.66, 0.72, 0.84)
const COL_GOLD := Color(1.0, 0.84, 0.36)
const COL_MAX := Color(0.45, 0.90, 0.62)

@onready var mask: ColorRect = $Mask
@onready var center: CenterContainer = $Center
@onready var coins_label: Label = $Center/Panel/Margin/VB/Head/Coins
@onready var rows: VBoxContainer = $Center/Panel/Margin/VB/Rows
@onready var hint: Label = $Center/Panel/Margin/VB/Hint
@onready var close_btn: Button = $Center/Panel/Margin/VB/Close

## id -> 需要刷新的节点（不重建行，避免买一次整块 UI 闪一下）
var _cells: Dictionary = {}
## 打开前的暂停状态：从结算界面进来时树本来就是暂停的，关店后必须还原，
## 否则"关店 → 游戏在结算界面后面偷偷跑起来"（玩家会看到角色还在动）。
var _prev_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mask.visible = false
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_btn.pressed.connect(close)
	_build_rows()

func is_open() -> bool:
	return center.visible

## 商店打开时不希望被当成"游戏在跑" —— Game.toggle_pause 会先查这个
func open() -> void:
	if center.visible:
		return
	_prev_paused = get_tree().paused
	get_tree().paused = true
	mask.visible = true
	center.visible = true
	refresh()

func close() -> void:
	if not center.visible:
		return
	mask.visible = false
	center.visible = false
	get_tree().paused = _prev_paused
	closed.emit()

# ---------------------------------------------------------------- 构建
func _build_rows() -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	_cells.clear()
	for t in MetaSave.TRACKS:
		rows.add_child(_make_row(t))

func _make_row(t: Dictionary) -> PanelContainer:
	var id: String = String(t["id"])

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.17, 0.88)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.10)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)

	var icon := TextureRect.new()
	icon.texture = Art.tex(String(t["svg"]))
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 3)
	hb.add_child(col)

	# 名称和等级点放同一行：等级点是"这条线还有多长"的唯一表达，
	# 单独占一行会把行高撑到 100+，五条线就塞不进 720x1280 且不用滚动。
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)

	var name_label := Label.new()
	name_label.text = String(t["name"])
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", COL_NAME)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_label)

	var dots := Label.new()
	dots.add_theme_font_size_override("font_size", 15)
	dots.add_theme_color_override("font_color", COL_GOLD)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(dots)

	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", COL_DESC)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(desc)

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 2)
	hb.add_child(right)

	var price := Label.new()
	price.add_theme_font_size_override("font_size", 17)
	price.add_theme_color_override("font_color", COL_GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.custom_minimum_size = Vector2(118, 0)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(price)

	var buy := Button.new()
	buy.text = "购买"
	buy.custom_minimum_size = Vector2(118, 40)
	buy.add_theme_font_size_override("font_size", 17)
	buy.focus_mode = Control.FOCUS_NONE
	buy.pressed.connect(_on_buy.bind(id))
	right.add_child(buy)

	_cells[id] = {"desc": desc, "dots": dots, "price": price, "buy": buy, "row": row}
	return row

# ---------------------------------------------------------------- 刷新
func refresh() -> void:
	coins_label.text = "%d 枚" % MetaSave.coins
	for t in MetaSave.TRACKS:
		_refresh_cell(t)
	var n: int = MetaSave.affordable_count()
	if n > 0:
		hint.text = "现在有 %d 项买得起 · 加成立刻作用于下一局" % n
		hint.add_theme_color_override("font_color", COL_GOLD)
	else:
		hint.text = "铜钱来自每夜结算 · 灯灭也算"
		hint.add_theme_color_override("font_color", COL_DESC)

func _refresh_cell(t: Dictionary) -> void:
	var id: String = String(t["id"])
	var c: Dictionary = _cells.get(id, {})
	if c.is_empty():
		return
	var lv: int = MetaSave.level_of(id)
	var cap: int = MetaSave.max_level_of(id)
	var desc: Label = c["desc"] as Label
	var dots: Label = c["dots"] as Label
	var price: Label = c["price"] as Label
	var buy: Button = c["buy"] as Button

	# 数值预览直接算出来给玩家看，不写死文案 —— 改 step 时文案自动跟着变，
	# 不会出现"写着 +3% 实际 +2%"这种最伤信任的漂移。
	desc.text = _effect_text(id, lv, cap)
	dots.text = _dots(lv, cap)
	# 满级的点变绿：不用读右侧的"已满"两个字，眼睛扫过左侧就知道这条线走完了
	dots.add_theme_color_override("font_color", COL_MAX if lv >= cap else COL_GOLD)

	if lv >= cap:
		price.text = "已满"
		price.add_theme_color_override("font_color", COL_MAX)
		buy.text = "已满级"
		buy.disabled = true
		return
	var p: int = MetaSave.price_of(id)
	price.text = "%d 枚" % p
	var ok: bool = MetaSave.coins >= p
	price.add_theme_color_override("font_color", COL_GOLD if ok else Color(0.72, 0.45, 0.45))
	buy.text = "购买"
	buy.disabled = not ok

## 效果文案：显示"当前 → 下一级"，满级只显示当前。
func _effect_text(id: String, lv: int, cap: int) -> String:
	var t: Dictionary = MetaSave.track(id)
	if id == "revive":
		return "%s（现有 %d 次）" % [String(t.get("unit", "")), lv]
	var cur: float = MetaSave.mult_at(id, lv)
	if lv >= cap:
		return "当前 ×%.2f" % cur
	var nxt: float = MetaSave.mult_at(id, lv + 1)
	return "×%.2f → ×%.2f" % [cur, nxt]

func _dots(lv: int, cap: int) -> String:
	var s := ""
	for i in cap:
		s += "●" if i < lv else "○"
	return s

# ---------------------------------------------------------------- 交互
func _on_buy(id: String) -> void:
	if not MetaSave.buy(id):
		return
	refresh()
	# 买完抖一下，让"钱花出去了"这个动作有反馈（移动端没有声音时只能靠视觉）
	var c: Dictionary = _cells.get(id, {})
	if not c.is_empty():
		var row: PanelContainer = c["row"] as PanelContainer
		row.pivot_offset = row.size * 0.5
		var tw := create_tween()
		tw.tween_property(row, "modulate", Color(1.5, 1.3, 0.8), 0.08)
		tw.tween_property(row, "modulate", Color.WHITE, 0.22)

func _unhandled_key_input(event: InputEvent) -> void:
	if not center.visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_ENTER):
		close()
		get_viewport().set_input_as_handled()
