extends CanvasLayer
class_name SettingsUI

# =====================================================================
# 设置面板（v7 策划案 L-06 / T4）。主菜单和暂停菜单共用同一份实现。
#
# 【为什么整份 UI 用代码搭，而不是再做一个 .tscn】
# 面板里 90% 是"一行标题 + 一个两态开关"，节点结构完全同构。
# 写成 .tscn 意味着 6 段几乎一样的 Button 配置要手抄 6 遍（字号/边距/配色各一次），
# 以后改一次间距要改 6 处 —— 这类重复正是"UI 越做越不一致"的来源。
# 这里用 _row() / _toggle() 两个工厂函数生成，样式只有一处定义。
#
# 【为什么"清除存档"要二次确认，而"重看开场"不要】
# 后者最坏结果是再看一遍三页画；前者不可逆地抹掉玩家几小时的铜钱与传承。
# 确认成本必须和损失成正比。
#
# 【确认层为什么在 ConfirmLayer 里而不是这里】
# 暂停菜单的"回主菜单"要的是同一个东西。两份实现意味着危险色/按钮顺序
# 会在两处各自漂移，而这两处的后果都不可逆。
# =====================================================================

signal closed

const PANEL_W := 480.0
const BTN_H := 56.0
const ROW_GAP := 12.0

const C_TITLE := Color(1.0, 0.86, 0.42)
const C_TEXT := Color(0.94, 0.92, 0.86)
const C_DIM := Color(0.66, 0.66, 0.70)
const C_ON := Color(0.42, 0.86, 0.68)
const C_OFF := Color(0.72, 0.52, 0.42)
const C_DANGER := Color(0.95, 0.44, 0.38)

var _mask: ColorRect
var _root: VBoxContainer
var _confirm: ConfirmLayer

# 开关按钮引用：刷新文案时按 id 找
var _fx_full: Button
var _fx_low: Button
var _shake_btn: Button
var _tips_btn: Button
var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_val: Label
var _sfx_val: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

# ---------------------------------------------------------------- 搭 UI
func _build() -> void:
	_mask = ColorRect.new()
	_mask.name = "Mask"
	_mask.color = Color(0.02, 0.03, 0.07, 0.80)
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mask)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.09, 0.97)
	sb.border_color = Color(0.72, 0.55, 0.28, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	_root = VBoxContainer.new()
	_root.name = "VB"
	_root.add_theme_constant_override("separation", ROW_GAP)
	panel.add_child(_root)

	var t := Label.new()
	t.text = "设置"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", C_TITLE)
	_root.add_child(t)

	var sub := Label.new()
	sub.text = "这台机器的偏好 · 与存档分开保存"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", C_DIM)
	_root.add_child(sub)
	_root.add_child(_rule())

	# ---- 特效档位：两个互斥按钮而不是一个开关。
	# 用"完整 / 低配"两个词而不是"高 / 低"：后者玩家不知道"低"到底少了什么。
	_root.add_child(_label("特效"))
	var fx_row := HBoxContainer.new()
	fx_row.name = "FxRow"
	fx_row.add_theme_constant_override("separation", 10)
	_fx_full = _toggle("完整", func() -> void: _set_fx(Settings.Fx.FULL))
	_fx_low = _toggle("低配", func() -> void: _set_fx(Settings.Fx.LOW))
	fx_row.add_child(_fx_full)
	fx_row.add_child(_fx_low)
	_root.add_child(fx_row)
	_root.add_child(_hint("低配会关掉皮影残像、走马灯、铁水火星与摊位装饰。\n花灯波纹和铜锣冲击环始终保留：它们是判定范围的唯一读数。"))

	# ---- 震屏
	var shake_row := HBoxContainer.new()
	shake_row.add_theme_constant_override("separation", 10)
	var sl := _label("震屏")
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shake_row.add_child(sl)
	_shake_btn = _toggle("开", _on_shake)
	shake_row.add_child(_shake_btn)
	_root.add_child(shake_row)

	# ---- 情境提示
	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 10)
	var tl := _label("情境提示")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_row.add_child(tl)
	_tips_btn = _toggle("开", _on_tips)
	tip_row.add_child(_tips_btn)
	_root.add_child(tip_row)

	# ---- 音量：音乐 / 音效两条总线各一条滑条。
	# 拖动立即生效（游戏音正在播，滑条必须能当场听出大小），松手即写盘。
	_root.add_child(_label("音量"))
	_root.add_child(_vol_row("音乐", true))
	_root.add_child(_vol_row("音效", false))

	_root.add_child(_rule())

	_root.add_child(_action("重看开场", _on_replay_intro))
	_root.add_child(_action("清除存档", _on_clear_save, C_DANGER))

	var close_btn := _action("返回", close, C_TEXT)
	_root.add_child(close_btn)

	# ---- 二次确认层（ConfirmLayer 自己带 layer 40，永远压在面板之上）
	_confirm = ConfirmLayer.new()
	_confirm.name = "Confirm"
	_confirm.confirmed.connect(_on_clear_confirmed)
	add_child(_confirm)

# ---------------------------------------------------------------- 控件工厂
func _rule() -> Control:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 1)
	r.color = Color(0.72, 0.55, 0.28, 0.30)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", C_TEXT)
	return l

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", C_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb

func _toggle(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H * 0.78)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.9))
	b.add_theme_stylebox_override("normal", _style(Color(0.15, 0.13, 0.12, 0.95), Color(0.5, 0.4, 0.26, 0.7)))
	b.add_theme_stylebox_override("hover", _style(Color(0.24, 0.19, 0.14, 0.98), Color(0.92, 0.74, 0.4, 0.95)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.30, 0.23, 0.15, 1.0), Color(1, 0.85, 0.5, 1.0)))
	b.add_theme_stylebox_override("focus", _style(Color(0.15, 0.13, 0.12, 0.0), Color(0.6, 0.5, 0.3, 0.4)))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

func _action(text: String, cb: Callable, color: Color = C_TEXT) -> Button:
	var b := _toggle(text, cb)
	b.custom_minimum_size = Vector2(0, BTN_H)
	b.add_theme_color_override("font_color", color)
	return b

## 一行音量：标题 + 滑条 + 百分比。
## 百分比必须给：滑条只能读"大概三分之一"，而玩家调音量时想知道的是"到底多大声"。
func _vol_row(text: String, music: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "VolMusic" if music else "VolSfx"
	row.add_theme_constant_override("separation", 10)
	var l := _label(text)
	l.custom_minimum_size = Vector2(64, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.music_volume if music else Settings.sfx_volume
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 30)
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(52, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", C_DIM)
	row.add_child(v)
	if music:
		_music_slider = s
		_music_val = v
	else:
		_sfx_slider = s
		_sfx_val = v
	# 先摆好初值再连信号，避免构建过程中白写一次盘
	s.value_changed.connect(func(val: float) -> void: _on_volume(music, val))
	_update_vol_label(music, s.value)
	return row

func _update_vol_label(music: bool, v: float) -> void:
	var l: Label = _music_val if music else _sfx_val
	if l != null:
		l.text = "%d%%" % int(round(clampf(v, 0.0, 1.0) * 100.0))

func _on_volume(music: bool, v: float) -> void:
	if music:
		Settings.set_music_volume(v)
	else:
		Settings.set_sfx_volume(v)
	Audio.apply_volumes()
	_update_vol_label(music, v)

# ---------------------------------------------------------------- 状态刷新
func refresh() -> void:
	if _fx_full == null:
		return
	_fx_full.add_theme_color_override("font_color", C_ON if Settings.fx_level == Settings.Fx.FULL else C_DIM)
	_fx_low.add_theme_color_override("font_color", C_ON if Settings.fx_level == Settings.Fx.LOW else C_DIM)
	_shake_btn.text = "开" if Settings.shake else "关"
	_shake_btn.add_theme_color_override("font_color", C_ON if Settings.shake else C_OFF)
	_tips_btn.text = "开" if Settings.tips else "关"
	_tips_btn.add_theme_color_override("font_color", C_ON if Settings.tips else C_OFF)
	if _music_slider != null:
		_music_slider.set_value_no_signal(Settings.music_volume)
		_update_vol_label(true, Settings.music_volume)
	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(Settings.sfx_volume)
		_update_vol_label(false, Settings.sfx_volume)

# ---------------------------------------------------------------- 动作
func _set_fx(v: int) -> void:
	Settings.set_fx_level(v)
	refresh()

func _on_shake() -> void:
	Settings.set_shake(not Settings.shake)
	refresh()

func _on_tips() -> void:
	Settings.set_tips(not Settings.tips)
	refresh()

func _on_replay_intro() -> void:
	# 只清引导标记，铜钱与传承一点不动
	MetaSave.reset_intro()
	_flash("开场与提示已重置 · 下一局会重新出现")

func _on_clear_save() -> void:
	# 设置里只有这一处危险动作，所以确认回调可以直接写死，
	# 不需要像通用弹窗那样挂一个 _pending Callable —— 少一层间接就少一处状态残留。
	_confirm.ask("清除存档后，铜钱与五条传承线都会归零，\n且无法恢复。确定吗？", "确定清除")

func _on_clear_confirmed() -> void:
	MetaSave.reset_progress()
	_flash("存档已清除 · 铜钱与传承归零")

# ---------------------------------------------------------------- 确认层
func is_confirming() -> bool:
	return _confirm != null and _confirm.is_showing()

## 一行轻提示：直接改副标题，不新建节点（设置面板不是需要 toast 的场合）
func _flash(text: String) -> void:
	var sub: Node = _root.get_child(1)
	if sub is Label:
		(sub as Label).text = text
		var tw: Tween = create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func() -> void:
			if is_instance_valid(sub):
				(sub as Label).text = "这台机器的偏好 · 与存档分开保存")

# ---------------------------------------------------------------- 开关面板
func open() -> void:
	visible = true
	if _confirm != null:
		_confirm.dismiss()
	refresh()

func close() -> void:
	if is_confirming():
		_confirm.dismiss()
		return
	# 已经关着就不要再发 closed：宿主（暂停菜单）在切换时也会调一次，
	# 重复发信号会让"关设置后刷新主菜单"这类回调跑两遍。
	if not visible:
		return
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
