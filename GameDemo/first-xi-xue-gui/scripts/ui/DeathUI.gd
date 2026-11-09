extends CanvasLayer
class_name DeathUI

# 单局结算（Step 11）+ 局外入账与商店入口（Step 12）。
#
# 设计要点：
# - 胜利和失败共用一套 Panel，只换标题色/标题文案。分成两个场景会让"重开"按钮
#   在两份 UI 里各接一次信号，是重复代码。
# - 金币是本局唯一跨局产出，必须**显著**放在标题下面，而不是塞进信息行中间 ——
#   玩家结算时只扫标题和金币数字，中间那些明细是给记录用的。
# - Step 12 之后金币行拆成两行：大字「本局 +N」是即时反馈，小字「持有 M」是长期账本。
#   合成一行（"◆ N（共 M）"）在 540px 宽的面板里会挤成一条看不清的小字。

## 胜利标题色：暖金（和进化横幅一致的色系）
const WIN_COLOR := Color(1.0, 0.86, 0.42)
## 失败标题色：暗红（不是纯红，纯红会像报错提示）
const LOSE_COLOR := Color(0.95, 0.42, 0.40)
const TOTAL_COLOR := Color(0.72, 0.78, 0.90)

const MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var title: Label = $Popup/Panel/VB/Title
@onready var info: Label = $Popup/Panel/VB/Info
@onready var restart: Button = $Popup/Panel/VB/Restart
@onready var shop: Button = $Popup/Panel/VB/Shop
@onready var quit: Button = $Popup/Panel/VB/Quit

var _game: GameScene
var _coins: Label = null
var _total: Label = null
var _shop: ShopUI = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Mask.visible = false
	$Mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Popup.visible = false
	$Popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	restart.pressed.connect(_on_restart)
	quit.pressed.connect(_on_quit)
	shop.pressed.connect(_on_shop)
	_setup_coins()

## 金币区：插在标题和 Info 之间。
## 用 Label 而不是改 .tscn，是因为三处布局（面板高度/VB 间距）都已在场景里调过，
## 加一个节点比改场景最小侵入。
func _setup_coins() -> void:
	var vb: Node = $Popup/Panel/VB
	_coins = Label.new()
	_coins.name = "Coins"
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins.add_theme_font_size_override("font_size", 34)
	_coins.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	_coins.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_coins.add_theme_constant_override("shadow_offset_x", 2)
	_coins.add_theme_constant_override("shadow_offset_y", 2)
	_coins.visible = false
	vb.add_child(_coins)

	_total = Label.new()
	_total.name = "Total"
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total.add_theme_font_size_override("font_size", 15)
	_total.add_theme_color_override("font_color", TOTAL_COLOR)
	_total.visible = false
	vb.add_child(_total)

	# 挪到 Title 之后、Info 之前
	var idx: int = title.get_index() + 1
	vb.move_child(_coins, idx)
	vb.move_child(_total, idx + 1)

func bind_restart(game: GameScene) -> void:
	_game = game

## 商店由 Game 注入（不在这里 load 场景：同一棵 UI 树里只能有一个商店实例，
## 自己 load 会造出第二个，买完两边余额显示不一致）。
## 关店回调在这里连一次就好：如果在按钮回调里连，连点两下就会连两条。
func bind_shop(shop_ui: ShopUI) -> void:
	_shop = shop_ui
	if _shop != null and not _shop.closed.is_connected(_refresh_shop_hint):
		_shop.closed.connect(_refresh_shop_hint)

func is_open() -> bool:
	return $Popup.visible

## Step 11 结算入口。
## 参数刻意全部显式传入而不是从 _game 读：胜利时 Game 会先把 GameManager.started 置 false，
## 从 _game 反读会踩到"结算时数值已冻结"的时序问题，也更容易在测试里构造。
##
## banked：入账后的总余额。默认 -1 表示"调用方没走存档"（旧测试路径），
## 此时只显示本局金币、不显示持有量 —— 免得 UI 凭空编一个余额出来。
##
## cause：死因归纳（v7 L-06），只对失败有意义。空字符串 = 不显示这一行。
func show_result(kills: int, elapsed: float, level: int, victory: bool,
		coins: int, elite_kills: int, boss_kills: int, evolutions: int,
		banked: int = -1, cause: String = "") -> void:
	get_tree().paused = true
	$Mask.visible = true
	$Popup.visible = true

	var t: int = int(elapsed)
	title.text = "五更鸡鸣" if victory else "灯灭了"
	title.add_theme_color_override("font_color", WIN_COLOR if victory else LOSE_COLOR)

	if _coins != null:
		_coins.visible = true
		# 用 "+N" 而不是 "N"：结算界面出现的那一下，玩家需要确认"钱进账了"，
		# 加号比数字本身更像一次入账动作。
		# 前缀写"铜钱"而不是沿用旧版的 ◆：换皮后货币有名字了，光一个菱形图标
		# 新玩家读不出这是铜钱（真值表 §0 也要求结算文案统一用铜钱）。
		_coins.text = "铜钱 %d" % coins if coins <= 0 else "铜钱 +%d" % coins
	if _total != null:
		_total.visible = banked >= 0
		_total.text = "手上 %d 枚" % banked
	_refresh_shop_hint()

	var lines: Array[String] = []
	# 死因放在明细第一行：玩家扫过标题和铜钱之后，第一个想知道的就是"我怎么死的"。
	# 单独做一行大字会抢掉铜钱的视觉重量（结算里铜钱是唯一的正向反馈，不能让位）。
	if not victory and cause != "":
		lines.append("死因  %s" % cause)
	lines.append("撑住  %02d:%02d / %02d:00" % [t / 60, t % 60, int(WaveTable.RUN_LENGTH) / 60])
	lines.append("归色  %d 只" % kills)
	lines.append("等级  Lv %d" % level)
	# 精英/Boss/开脸只在非零时显示：一局全 0 的"精英 0  Boss 0"只会让面板变吵
	var extra: Array[String] = []
	if elite_kills > 0:
		extra.append("精英 %d" % elite_kills)
	if boss_kills > 0:
		extra.append("Boss %d" % boss_kills)
	if evolutions > 0:
		extra.append("开脸 %d" % evolutions)
	if not extra.is_empty():
		lines.append("  ".join(extra))
	var ws: String = _weapon_summary()
	if ws != "":
		lines.append("")
		lines.append(ws)
	info.text = "\n".join(lines)

func _weapon_summary() -> String:
	if _game == null:
		return ""
	var weps: Dictionary = _game.weapons.owned
	if weps.is_empty():
		return ""
	var parts: Array[String] = []
	for id in weps.keys():
		parts.append("%s Lv%d" % [UpgradeDB.display_name(String(id)), int(weps[id])])
	return "手艺：" + " · ".join(parts)

func _on_restart() -> void:
	# 迭代03 U-02：结算面板原本全静音，重开这一下没有任何反馈。
	Audio.play_sfx("ui_click")
	get_tree().paused = false
	if _game != null:
		_game.restart()
	else:
		get_tree().reload_current_scene()

func _on_shop() -> void:
	if _shop == null:
		return
	_shop.open()

## 商店按钮的文案随"买得起几项"变化：结算界面是玩家唯一会主动看一眼金币的地方，
## 把"能买东西了"直接写在按钮上，比让玩家自己算便宜多少金币有用得多。
func _refresh_shop_hint() -> void:
	if shop == null:
		return
	var n: int = MetaSave.affordable_count()
	shop.text = "百工谱" if n <= 0 else "百工谱  ·  %d 项买得起" % n

## 不再是 get_tree().quit()：v7 要求"退出"只回主菜单，不杀进程。
## 杀进程等于把玩家踢出游戏 —— 想再守一夜得重新双击一次 exe，
## 而这一步在桌面端是纯粹的摩擦，在移动端则根本不存在（进程由系统管）。
func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _unhandled_key_input(event: InputEvent) -> void:
	if not $Popup.visible:
		return
	# 商店开着时，回车/空格归商店（关店），不能顺手把"再守一夜"按掉
	if _shop != null and _shop.is_open():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
		_on_restart()
		get_viewport().set_input_as_handled()
