extends Control
class_name MainMenu

# =====================================================================
# 开始界面。五件事：新游戏 / 载入存档 / 商店 / 设置 / 退出。
#
# 【为什么"载入存档"字面上等于"新游戏"】
# 本作没有 mid-run 存档：一局的全部状态都活在 Game 树里（敌人池、武器等级、
# 经验、已进化的形态），要序列化它等于新写一套 run-save（属大改，另议）。
# 真正跨局持久化的只有 MetaSave —— 铜钱 + 五条成长线，而它
#   ① 在 autoload 的 _ready 里自动 load_save()
#   ② 在 Game._ready 里经 Stats.make_base() 乘进本局 stats
# 也就是说"带着传承开局"**已经是默认行为**，不需要玩家点一次"载入"。
# 所以这个按钮只承担两件事：告诉玩家"传承已经带上了"，以及在"什么都没有"时置灰，
# 避免他点了一下没反应、以为界面坏了。
#
# 【为什么置灰条件是"有没有进度"而不是文档写的 MetaSave.loaded】
# loaded 的含义是"这次启动读到了一个**已存在**的存档文件"。首次运行它是 false ——
# 但只要玩家打了一夜拿到铜钱，这次会话里 loaded 仍然是 false。
# 照抄 loaded 会让"我有 500 铜钱却灰着"成为可能。用进度本身判定，
# 首次运行（无铜钱无等级）依旧置灰，与文档口径一致。
# =====================================================================

const GAME_SCENE := "res://scenes/Game.tscn"
const SHOP_SCENE := "res://scenes/ui/ShopUI.tscn"

## 自动化验收钩子：非空时所有"离开菜单"的动作只回报意图，不真的切场景 / 退进程。
## 生产路径恒为空 Callable。删掉它测试会真的切场景，用例当场死掉。
var intent_hook: Callable = Callable()

@onready var btn_new: Button = $Col/BtnNew
@onready var btn_load: Button = $Col/BtnLoad
@onready var btn_shop: Button = $Col/BtnShop
@onready var btn_chars: Button = $Col/BtnChars
@onready var btn_codex: Button = $Col/BtnCodex
@onready var btn_settings: Button = $Col/BtnSettings
@onready var btn_quit: Button = $Col/BtnQuit
@onready var stats_label: Label = $Col/Stats
@onready var hint: Label = $Col/Hint

## 菜单自己开出来的那份商店。Game 场景里的那份是独立的，两者互不影响。
var _shop: ShopUI = null
## 设置面板。菜单里常驻一份（不进不出），比每次开关都 new 一次省事：
## 它自己管 visibility，反复 new 会在树上叠出多层全屏 mask。
var _settings: SettingsUI = null
## 三页开场。只在这里活一次，播完自己销毁。
var _intro: IntroUI = null
## 匠人选择面板（T9）。与设置面板同样常驻一份：它自带 mask，反复 new 会叠层。
var _chars: CharacterUI = null
## 图鉴面板（T12）。同上：常驻一份，别每次开关都 new。
var _codex: CodexUI = null

func _ready() -> void:
	# 从任何地方回到菜单都不该继承暂停（先在别处 pause 过再跳过来会点不动任何按钮）
	get_tree().paused = false
	btn_new.pressed.connect(_on_new_game)
	btn_load.pressed.connect(_on_load)
	btn_shop.pressed.connect(_on_shop)
	btn_chars.pressed.connect(_on_chars)
	btn_codex.pressed.connect(_on_codex)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)
	refresh()
	# 主菜单 BGM。从一局回来时 Audio 会自动交叉淡出战斗曲，
	# 所以这里不需要判断"是不是已经在播"——重复请求同一首会被 Audio 直接忽略。
	Audio.play_bgm("menu")

# ---------------------------------------------------------------- 文案
func refresh() -> void:
	var has: bool = has_progress()
	stats_label.text = progress_text()
	btn_load.disabled = not has
	if has:
		btn_load.text = "载入存档"
		hint.text = "传承开局自动带入 · 本作不保存单局进度"
	else:
		btn_load.text = "载入存档 · 无存档"
		hint.text = "还没有留下手艺 · 先守一夜，铜钱与传承会自动存下"
	# 把当前匠人写在按钮上：玩家的抱怨会是"我选了灯彩匠，怎么还是打铁花"，
	# 而不是"我要去哪儿换人"。让选择在菜单上一直可见，成本只有这五个字。
	var ch: Dictionary = CharacterDB.current()
	btn_chars.text = "匠人 · %s" % String(ch.get("name", "—"))
	# 图鉴按钮带进度：收集类入口不写进度，玩家就没有点进去的理由。
	# 有"本次新收录"时补一句，否则那几条新东西永远没人回来看。
	var fresh: int = CodexDB.fresh_count()
	btn_codex.text = "图鉴 · %s" % CodexDB.progress_line()
	if fresh > 0:
		btn_codex.text += " · 新 %d" % fresh

## 有没有任何跨局进度。铜钱 > 0 或任意一条成长线升过级都算。
func has_progress() -> bool:
	if MetaSave.coins > 0:
		return true
	for id in MetaSave.track_ids():
		if MetaSave.level_of(id) > 0:
			return true
	return false

## 一行摘要：手上多少铜钱 + 已升的成长线。
## 只在菜单里给一眼可读的量，不铺全部五条（那是商店的事）。
func progress_text() -> String:
	var parts: Array[String] = ["手上 %d 枚铜钱" % MetaSave.coins]
	var lv_parts: Array[String] = []
	for t in MetaSave.TRACKS:
		var id: String = String(t["id"])
		var lv: int = MetaSave.level_of(id)
		if lv > 0:
			lv_parts.append("%s Lv%d" % [String(t["name"]), lv])
	parts.append("尚无传承" if lv_parts.is_empty() else " · ".join(lv_parts))
	return "    ".join(parts)

# ---------------------------------------------------------------- 按钮
func _on_new_game() -> void:
	# 自动化验收只回报意图：开场会挡住这次场景切换，而用例要的是"意图有没有发出"。
	# 生产路径 intent_hook 恒为空，所以这条分支只服务测试，不会让玩家跳过开场。
	if intent_hook.is_valid() or MetaSave.intro_done:
		_leave("scene", GAME_SCENE)
		return
	_show_intro()

## 三页开场（L-07）。放在这里而不是 Game 里，理由见 IntroUI 顶部注释。
func _show_intro() -> void:
	if _intro != null and is_instance_valid(_intro):
		return
	_intro = IntroUI.new()
	_intro.name = "Intro"
	add_child(_intro)
	_intro.finished.connect(_on_intro_finished)
	_intro.open()

func _on_intro_finished() -> void:
	if _intro != null and is_instance_valid(_intro):
		_intro.queue_free()
	_intro = null
	_leave("scene", GAME_SCENE)

func _on_load() -> void:
	# 置灰时 Button 本来就不发 pressed，这里再挡一次是为了让"程序里强调"也不越界
	if btn_load.disabled:
		return
	_leave("scene", GAME_SCENE)

func _on_quit() -> void:
	_leave("quit", "")

## 离开菜单的唯一出口。
## 切场景前必须解除暂停：Game._ready 里有一串 started / paused 判定，
## 带着 paused=true 进去会让整局"画面在动、什么都打不出来"。
func _leave(kind: String, arg: String) -> void:
	if intent_hook.is_valid():
		intent_hook.call(kind, arg)
		return
	get_tree().paused = false
	if kind == "quit":
		get_tree().quit()
		return
	get_tree().change_scene_to_file(arg)

# ---------------------------------------------------------------- 匠人（T9）
## 选完立刻 refresh：按钮上的"匠人 · X"要跟着变，否则玩家关掉面板会以为没生效。
func _on_chars() -> void:
	if _chars == null or not is_instance_valid(_chars):
		_chars = CharacterUI.new()
		_chars.name = "CharsPanel"
		add_child(_chars)
		_chars.closed.connect(refresh)
	_chars.open()

## 给验收用：当前开着的角色面板（没有则 null）
func chars_instance() -> CharacterUI:
	return _chars

func _on_codex() -> void:
	if _codex == null or not is_instance_valid(_codex):
		_codex = CodexUI.new()
		_codex.name = "CodexPanel"
		add_child(_codex)
		_codex.closed.connect(refresh)
	_codex.open()

func codex_instance() -> CodexUI:
	return _codex

# ---------------------------------------------------------------- 设置
## 菜单里也放设置入口：玩家要调特效档位/震屏时，不该被迫先开一局再按 Esc。
## 面板关掉后 refresh() 一次 —— 因为里面可能刚清过存档，摘要和"载入存档"的置灰都要跟着变。
func _on_settings() -> void:
	if _settings == null or not is_instance_valid(_settings):
		_settings = SettingsUI.new()
		_settings.name = "SettingsPanel"
		add_child(_settings)
		_settings.closed.connect(refresh)
	_settings.open()

# ---------------------------------------------------------------- 商店
## 菜单里开商店 = instance 一份 ShopUI.tscn 挂到菜单上。
##
## 为什么不用 Game 场景里那份：那份的宿主是一棵正在跑的 Game 树（HUD 绑定、敌人池、
## 暂停优先级都连着它），菜单里根本没有这棵树。ShopUI 本身只依赖 MetaSave + Art
## 两个 autoload，所以独立 instance 一份就能跑，两条路径互不影响。
func _on_shop() -> void:
	if _shop != null and is_instance_valid(_shop):
		return
	var packed: PackedScene = load(SHOP_SCENE) as PackedScene
	if packed == null:
		push_error("MainMenu: 载入商店场景失败 %s" % SHOP_SCENE)
		return
	_shop = packed.instantiate() as ShopUI
	if _shop == null:
		push_error("MainMenu: 商店场景根节点不是 ShopUI")
		return
	add_child(_shop)
	_shop.closed.connect(_on_shop_closed)
	_shop.open()

## 关店即销毁这份实例：菜单里没有"一直挂着一份商店"的理由，
## 留着只会在下次开店时叠出第二层遮罩。
func _on_shop_closed() -> void:
	if _shop != null and is_instance_valid(_shop):
		_shop.queue_free()
	_shop = null
	# 商店买完可能改了铜钱/等级，菜单上的摘要要跟着变
	refresh()

## 给验收用：菜单里当前开着的商店（没有则 null）
func shop_instance() -> ShopUI:
	return _shop
