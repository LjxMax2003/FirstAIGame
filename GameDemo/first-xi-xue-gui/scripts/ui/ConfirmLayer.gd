extends CanvasLayer
class_name ConfirmLayer

# =====================================================================
# 通用二次确认层（v7 策划案 L-06）。
# 设置面板的「清除存档」与暂停菜单的「回主菜单」共用这一份实现。
#
# 【为什么抽成一层，而不是各自写一份】
# 二次确认里真正需要被决定的只有三件事：遮罩浓度、危险色、按钮顺序。
# 复制一份的代价不是多写 80 行，而是**以后改危险色只改到一处** ——
# 于是玩家会在设置里看到红的"确定"、在暂停里看到灰的"确定"，
# 而两次确认的后果都是不可逆的。这类不一致不会报错，只会慢慢磨掉信任。
#
# 【为什么 layer 固定 40】
# 它必须永远压住"发起它的那个面板"：
#   DeathUI 0 < PauseUI 9 < LevelUpUI 10 < SettingsUI 30 < ConfirmLayer 40
# 宿主自己写 layer 的话，同一份控件在两个宿主里就会有两种叠放结果 ——
# 那正是"确认框被面板盖住、点不到"这种 bug 的来源。
#
# 【为什么"算了"在左、"确定"在右】
# 右位是习惯里的"前进"，左位是"收回手"。危险动作必须把"算了"放在
# 拇指从右往左划时**先撞到**的那一格。
# =====================================================================

signal confirmed
signal cancelled

const PANEL_W := 460.0

const C_TEXT := Color(0.94, 0.92, 0.86)
const C_DANGER := Color(0.95, 0.44, 0.38)

var _text: Label
var _yes: Button
var _no: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

# ---------------------------------------------------------------- 搭 UI
func _build() -> void:
	var mask := ColorRect.new()
	mask.name = "Mask"
	mask.color = Color(0.02, 0.02, 0.04, 0.88)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.08, 0.98)
	sb.border_color = Color(0.72, 0.32, 0.28, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	_text = Label.new()
	_text.name = "Text"
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 18)
	_text.add_theme_color_override("font_color", C_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_text)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)

	_no = _btn("算了", C_TEXT)
	_no.name = "No"
	_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_no.pressed.connect(_on_no)
	row.add_child(_no)

	# 函数名叫 _btn 而不是 _toggle：这里不是开关，用完即弃的一颗按钮。
	_yes = _btn("确定", C_DANGER)
	_yes.name = "Yes"
	_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_yes.pressed.connect(_on_yes)
	row.add_child(_yes)

func _btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.9))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.13, 0.12, 0.95)
	normal.border_color = Color(0.5, 0.36, 0.28, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hot := StyleBoxFlat.new()
	hot.bg_color = Color(0.30, 0.19, 0.15, 0.98)
	hot.border_color = Color(0.95, 0.62, 0.5, 0.95)
	hot.set_border_width_all(1)
	hot.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("focus", normal)
	return b

# ---------------------------------------------------------------- 对外
## 弹出确认。yes_text 允许调用方把"确定"写成具体动作（"放弃本局"），
## 因为"确定"三个字本身不携带任何后果信息。
func ask(text: String, yes_text: String = "确定") -> void:
	_text.text = text
	_yes.text = yes_text
	visible = true

## 收起但**不**发 confirmed。取消路径统一走这里。
func dismiss() -> void:
	if not visible:
		return
	visible = false
	cancelled.emit()

func is_showing() -> bool:
	return visible

# ---------------------------------------------------------------- 内部
func _on_yes() -> void:
	visible = false
	confirmed.emit()

func _on_no() -> void:
	dismiss()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		dismiss()
		get_viewport().set_input_as_handled()
