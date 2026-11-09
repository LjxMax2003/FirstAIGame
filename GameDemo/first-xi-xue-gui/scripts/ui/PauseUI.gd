extends CanvasLayer
class_name PauseUI

# =====================================================================
# 暂停菜单（v7 策划案 L-06）。
#
# 【为什么只有"升级弹窗没开着"时才允许暂停】
# 两个暂停界面互相打脸：升级卡开着时按 Esc，原本会让整棵树 paused，
# 而升级卡自己也要用暂停来表达"世界停住了"，于是恢复时谁先解除暂停就成了竞态。
#
# 【层级】DeathUI 0 < PauseUI 9 < LevelUpUI 10 < SettingsUI 30 < ConfirmLayer 40
# 设置面板刻意压在暂停菜单之上而不是替换它：关掉设置必须回到原来那个暂停菜单，
# 而不是"回到游戏"。做成兄弟层就不用为"关设置后恢复游戏还是恢复暂停"写状态机。
#
# 【为什么"回主菜单"要二次确认，而"重守一夜"不要】
# 重开在结算前没有损失（本局本来就没入账）；回主菜单会真的丢掉这一夜。
# 确认成本必须和损失成正比。
# =====================================================================

const MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var mask: ColorRect = $Mask
@onready var popup: CenterContainer = $Popup
@onready var resume_btn: Button = $Popup/VB/Resume
@onready var restart_btn: Button = $Popup/VB/Restart
@onready var settings_btn: Button = $Popup/VB/Settings
@onready var menu_btn: Button = $Popup/VB/Menu

var _game_ref: GameScene
## 设置面板按需创建一次，之后反复开关（每次 new 会在树上留下第二份 mask）
var _settings: SettingsUI = null
var _confirm: ConfirmLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mask.visible = false
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume_btn.pressed.connect(close)
	restart_btn.pressed.connect(_on_restart)
	settings_btn.pressed.connect(_on_settings)
	menu_btn.pressed.connect(_on_menu)
	# v9 F1：三个"离开暂停"的按钮都要有声，用 ui_click（轻，不代表确认）。
	# 接在 pressed 上而不是单独包一层 _on_xxx：那就是这四项各自的第一件事。
	for b in [resume_btn, restart_btn, settings_btn, menu_btn]:
		(b as Button).pressed.connect(_blip)

	_settings = SettingsUI.new()
	_settings.name = "SettingsPanel"
	add_child(_settings)

	_confirm = ConfirmLayer.new()
	_confirm.name = "Confirm"
	_confirm.confirmed.connect(_leave_to_menu)
	add_child(_confirm)

func bind(game: GameScene) -> void:
	_game_ref = game

## 按钮轻响。单独一个函数而不是在四处各写一行 Audio.play_sfx：
## 之后要改那个音（或调 gain）只改这里一处，不会漏。
func _blip() -> void:
	Audio.play_sfx("ui_click")

func is_open() -> bool:
	return popup.visible

func open() -> void:
	if popup.visible:
		return
	mask.visible = true
	popup.visible = true
	get_tree().paused = true

func close() -> void:
	# 关暂停时顺手收掉设置与确认：留着它们在树上，
	# 下一次 open() 会看到一个"遮罩还在、但树已经不再 paused"的死面板。
	if _settings != null:
		_settings.close()
	if _confirm != null:
		_confirm.dismiss()
	mask.visible = false
	popup.visible = false
	if get_tree().paused:
		get_tree().paused = false

func _on_restart() -> void:
	close()
	if _game_ref != null:
		_game_ref.restart()

func _on_settings() -> void:
	if _settings != null:
		_settings.open()

func _on_menu() -> void:
	_confirm.ask("回主菜单会放弃本局：\n这一夜的铜钱与手艺都不会留下。\n确定吗？", "放弃本局")

## 离开这一局。必须先 close() 解除暂停 ——
## 带着 paused=true 切场景，MainMenu 虽然会自己复位，但那一帧的输入全被吞掉。
func _leave_to_menu() -> void:
	close()
	get_tree().change_scene_to_file(MENU_SCENE)

func _unhandled_key_input(event: InputEvent) -> void:
	if not popup.visible:
		return
	# 设置或确认层在上时，Esc/Enter 归它们，不能顺手把"接着守"按掉
	if _settings != null and _settings.is_open():
		return
	if _confirm != null and _confirm.is_showing():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_ENTER):
		close()
		get_viewport().set_input_as_handled()
