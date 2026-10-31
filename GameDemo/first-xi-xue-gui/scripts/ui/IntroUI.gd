extends CanvasLayer
class_name IntroUI

# =====================================================================
# 三页开场（v7 策划案 L-07 / T5）。只播一次，可跳过。
#
# 【为什么放在主菜单侧，而不是 Game._ready() 里】
# 三个理由，按重要性排：
#   ① 它讲的是"你接下来要做什么"，所以必须在**开局之前**说完。挂在 Game 上会先
#      刷出敌人再盖遮罩，玩家第一眼看到的是一个已经在跑的世界被压住 —— 观感像卡了。
#   ② 直接跑 Game.tscn 的自动化验收（SmokeTest / V5InGame / V7Shell / 各种截图工具）
#      不该被迫先点掉三页画。挂在菜单侧，这些工具一行都不用改。
#   ③ 它不改 GameManager.started，也就不必暂停整棵树 —— 少一个"开场没关干净
#      导致这一局开不了枪"的失败模式。
#
# 【为什么"跳过"也算看过了】
# 算看过。玩家按过跳过就是明确表态；下次再糊一遍是打断而不是提醒。
# 真想再看有设置里的「重看开场」，那条路把标记清回来。
#
# 【文案从哪来】
# docs/theme/craftkeepers/design.md §3.2–3.5：忘影是"没人记得的那部分"，
# 守艺人是**归色**而不是杀。三页文案必须守住这一条 —— 一句"杀光它们"
# 就会把这套叙事拆掉。
# =====================================================================

signal finished

const C_TEXT := Color(0.94, 0.92, 0.86)
const C_DIM := Color(0.70, 0.70, 0.74)
const C_TITLE := Color(0.92, 0.76, 0.44)

## 页面表。texture 用 Art 常量，改图不用回来改这里。
const PAGES: Array[Dictionary] = [
	{
		"tex": Art.INTRO_1,
		"line": "师父把百工灯交到我手上，只说了一句：\n撑到五更鸡鸣。",
	},
	{
		"tex": Art.INTRO_2,
		"line": "子时一过，摊上残留的手艺余温会站起来走动。\n没人记得的那部分，就成了忘影。",
	},
	{
		"tex": Art.INTRO_3,
		"line": "我不是去杀它们。\n我是去把手艺的颜色，还给这条街。",
	},
]

var _art: TextureRect
var _line: Label
var _index_label: Label
var _next_btn: Button
var _page := 0

func _ready() -> void:
	# layer 35：压在设置(30)之上、确认层(40)之下。开场是对局外的一次性演出，
	# 优先级高于设置面板（玩家在开场里点不到设置，也不该点得到）。
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	var mask := ColorRect.new()
	mask.name = "Mask"
	mask.color = Color(0.02, 0.02, 0.03, 1.0)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

	# 插画本身是 720×1280 竖屏全幅，铺满即可（KEEP_ASPECT_COVERED：宁可裁边不留黑边）
	_art = TextureRect.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_art)

	# 底部压一层渐变黑，保证文案在任何一页画上都读得清
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -420.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.02, 0.04, 0.66)
	add_child(shade)

	_line = Label.new()
	_line.name = "Line"
	_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_line.offset_left = 56.0
	_line.offset_right = -56.0
	_line.offset_top = -300.0
	_line.offset_bottom = -130.0
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 22)
	_line.add_theme_color_override("font_color", C_TEXT)
	_line.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_line.add_theme_constant_override("outline_size", 4)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)

	_index_label = Label.new()
	_index_label.name = "Index"
	# 页码夹在文案（底 -130）和按钮（顶 -84）之间那条 46px 的缝里。
	# 早先给的是 -96~-64，正好压在按钮头上 —— 静态断言测不出来，只有截图能看见。
	_index_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_index_label.offset_top = -122.0
	_index_label.offset_bottom = -90.0
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index_label.add_theme_font_size_override("font_size", 14)
	_index_label.add_theme_color_override("font_color", C_DIM)
	_index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_index_label)

	_next_btn = _btn("继续")
	_next_btn.name = "Next"
	_next_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_btn.offset_left = -110.0
	_next_btn.offset_right = 110.0
	_next_btn.offset_top = -84.0
	_next_btn.offset_bottom = -24.0
	_next_btn.pressed.connect(next)
	add_child(_next_btn)

	# 「跳过」放在角上而不是底部：它和"继续"是两种意图，并排放会让拇指误触
	var skip := _btn("跳过")
	skip.name = "Skip"
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -116.0
	skip.offset_right = -24.0
	skip.offset_top = 28.0
	skip.offset_bottom = 76.0
	skip.add_theme_font_size_override("font_size", 15)
	skip.add_theme_color_override("font_color", C_DIM)
	skip.pressed.connect(skip_all)
	add_child(skip)

func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", C_TITLE)
	b.add_theme_color_override("font_hover_color", Color(1, 0.94, 0.76))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.08, 0.09, 0.82)
	normal.border_color = Color(0.72, 0.55, 0.28, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hot := StyleBoxFlat.new()
	hot.bg_color = Color(0.24, 0.18, 0.12, 0.94)
	hot.border_color = Color(0.96, 0.78, 0.42, 0.95)
	hot.set_border_width_all(1)
	hot.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("focus", normal)
	return b

# ---------------------------------------------------------------- 对外
func open() -> void:
	_page = 0
	visible = true
	_render()

func is_open() -> bool:
	return visible

func page_index() -> int:
	return _page

func page_count() -> int:
	return PAGES.size()

## 翻页。最后一页按"继续"= 开始这一夜。
func next() -> void:
	if _page >= PAGES.size() - 1:
		_finish()
		return
	_page += 1
	_render()

## 跳过 = 直接看完剩下的（标记同样算看过）。
func skip_all() -> void:
	_finish()

func _finish() -> void:
	visible = false
	MetaSave.intro_done = true
	MetaSave.save()
	finished.emit()

func _render() -> void:
	var p: Dictionary = PAGES[_page]
	_art.texture = Art.tex(String(p["tex"]))
	_line.text = String(p["line"])
	_index_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	_next_btn.text = "开始这一夜" if _page >= PAGES.size() - 1 else "继续"

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		skip_all()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE or key.keycode == KEY_KP_ENTER:
		next()
	get_viewport().set_input_as_handled()
