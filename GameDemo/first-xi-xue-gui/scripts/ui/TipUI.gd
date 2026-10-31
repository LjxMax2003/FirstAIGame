extends CanvasLayer
class_name TipUI

# =====================================================================
# 一次性情境提示（v7 策划案 L-07 / T5）。
#
# 【为什么是"木牌"而不是弹窗】
# 这是夜市里的东西。挂在 HUD 下缘、4 秒自己走掉、不暂停 —— 玩家的手可以一直按在
# 屏幕上。做成居中弹窗就得暂停、就得点"知道了"，而这条提示的全部目的是
# "在他正要做这件事的时候说一句"，不是拦下他。
#
# 【为什么用轮询而不是到处埋 emit】
# 全部 5 条都是"某个状态第一次成立"，而不是"某个函数被调用"：
#   · 灯花可以是磁铁吸来的，也可以是走上去捡的 —— 抓 gain_xp 会漏掉一条路径
#   · 血量 <50% 根本没有"事件"，只是一个持续状态
#   · "首次移动"同理，是一帧的 velocity，不是一个函数
# 轮询这 5 个事实每帧只花几次比较，却省掉在 Player / GemPool / Game 三处各埋一个
# 信号（埋漏一处就是"某条提示永远不出现"，而且没人会发现）。
#
# 【为什么宝箱要单独喂一个计数】
# 宝箱开的是 Game._open_chest()，它是个真事件（不是持续状态），而且外面
# 拿不到"开过几次"。Game 上那一个 chests_opened 就是给这里用的。
#
# 【为什么升级提示在选完卡之后才出现】
# 升级卡是模态的、layer 10，而这块木牌刻意压在它下面（layer 5）——
# 提示不该盖住玩家正在做的选择。代价是它来得晚了一拍：玩家选完才看到
# "三选一，决定这一夜的构筑"。这句仍然有用（它解释了刚才那一步是什么机制），
# 比把它做成第二个模态层盖在卡上更轻。
# =====================================================================

## 木牌宽度上限。文案只有一句，撑满屏幕宽会让它看起来像公告而不是摊位上的牌子。
const SIGN_W := 520.0
const HOLD := 4.0
const FADE := 0.28

const C_TEXT := Color(0.96, 0.92, 0.84)

## 五条提示。条件由 _condition() 按 id 分派，文案跟 id 放一起 —— 加第六条的
## 时候"条件"和"话"在同一屏内，不会出现改了文案忘了接条件这种半成品。
const TIPS: Array[Dictionary] = [
	{"id": "move", "text": "拖拽移动，出手是自动的。"},
	{"id": "gem", "text": "灯花是经验，靠近会自动拾取。"},
	{"id": "levelup", "text": "三选一，决定这一夜的构筑。"},
	{"id": "lowhp", "text": "震吼：冲刺 + 清开一圈，25 秒一次。"},
	{"id": "chest", "text": "满级武器 + 对应被动 = 进化。"},
]

var _root: Control
var _sign: TextureRect
var _label: Label
var _game: GameScene
var _player: Player
## 已排队的提示（id）。同时满足两条时排队播，不互相盖掉。
var _queue: Array[String] = []
## id → 文案。只在入队时写，出队时读。
var _text_of: Dictionary = {}
## 当前这条还剩多少秒；<= 0 且没在播则空转
var _left := 0.0
var _showing := false
var _fade_in := false

func _ready() -> void:
	# layer 5：在 HUD 元素之上、升级卡(10)/暂停(9)/结算(0→其实是最底)之下。
	# 它不是模态，任何时候都不该抢焦点。
	layer = 5
	_build()
	visible = false

func _build() -> void:
	# CanvasLayer 不是 CanvasItem，没有 modulate/position —— 淡入淡出必须落在一个
	# 根 Control 上。这一层看着多余，但少了它就只能给每个子节点各写一遍 alpha。
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_sign = TextureRect.new()
	_sign.name = "Sign"
	_sign.texture = Art.tex(Art.UI_WOOD_SIGN)
	_sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sign.stretch_mode = TextureRect.STRETCH_SCALE
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 贴 HUD 下缘：HUD 顶栏占着上面，摇杆在下面 —— 这块木牌落在两者之间的空处
	_sign.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sign.offset_left = -SIGN_W * 0.5
	_sign.offset_right = SIGN_W * 0.5
	_sign.offset_top = -300.0
	_sign.offset_bottom = -300.0 + SIGN_W * (80.0 / 240.0)
	_root.add_child(_sign)

	_label = Label.new()
	_label.name = "Label"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", C_TEXT)
	_label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02, 0.9))
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 木牌两侧是钉子/木纹，文字别压上去
	_label.offset_left = 34.0
	_label.offset_right = -34.0
	_sign.add_child(_label)

func bind(game: GameScene, player: Player) -> void:
	_game = game
	_player = player

# ---------------------------------------------------------------- 轮询
func _process(delta: float) -> void:
	# 这块木牌默认继承父节点的 PAUSABLE：升级卡/暂停/结算期间 _process 自然停住，
	# 4 秒的沙漏跟着一起停。玩家不会在选卡时错过提示 —— 这是不用 Timer 的理由。
	if _game != null and GameManager.started and Settings.tips:
		scan()
	advance(delta)

## 扫一遍 5 个条件，把新成立的排进队列。
## 对外公开是给测试用的：验收要用**同一条**时间轴推进，而不是另写一套 4 秒逻辑 ——
## 那样测的就不是玩家实际跑的那份代码了。
func scan() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for t in TIPS:
		var id: String = String(t["id"])
		if not _condition(id):
			continue
		# mark_tip 判重与记账合一：返回 false 说明"这一条已经出现过"，直接跳过。
		# 注意它同时写存档 —— 所以这里不需要再维护一份本局已显示表。
		if not MetaSave.mark_tip(id):
			continue
		_enqueue(id, String(t["text"]))

func _condition(id: String) -> bool:
	match id:
		"move":
			return _player.moving
		"gem":
			# 用累计经验而不是当前条：升级会把当前条扣回去，当前条为 0 不代表没吃过灯花
			return _player.xp_total > 0
		"levelup":
			return _player.level > 1
		"lowhp":
			var hp: float = float(_player.stats.get("hp", 0.0))
			var mx: float = float(_player.stats.get("max_hp", 0.0))
			return mx > 0.0 and hp > 0.0 and hp < mx * 0.5
		"chest":
			return _game != null and _game.chests_opened > 0
	return false

# ---------------------------------------------------------------- 播
func _enqueue(id: String, text: String) -> void:
	_text_of[id] = text
	if _showing:
		_queue.append(id)
		return
	_show(id)

func _show(id: String) -> void:
	if not _text_of.has(id):
		return
	_label.text = String(_text_of[id])
	_showing = true
	_left = HOLD
	visible = true
	_root.modulate.a = 0.0
	# 淡入不走 Tween：时间轴已经在 _process 里维护了，
	# 再引入第二套计时只会让"这段到底算不算暂停"变得可疑。
	_fade_in = true

## 推进时间轴：淡入 → 停留 HOLD → 淡出 → 下一条。
func advance(delta: float) -> void:
	if not _showing:
		return
	if _fade_in:
		_root.modulate.a = minf(1.0, _root.modulate.a + delta / FADE)
		if _root.modulate.a >= 1.0:
			_fade_in = false
	_left -= delta
	if _left <= 0.0:
		_root.modulate.a = maxf(0.0, _root.modulate.a - delta / FADE)
		if _root.modulate.a <= 0.0:
			_showing = false
			visible = false
			_next()

func _next() -> void:
	if _queue.is_empty():
		return
	var id: String = _queue.pop_front()
	_show(id)

# ---------------------------------------------------------------- 查询（测试用）
func is_showing() -> bool:
	return _showing

func current_text() -> String:
	return _label.text if _showing else ""

func queued_count() -> int:
	return _queue.size()

## 立刻收掉当前这条并开始下一条（切场景 / 重开时用）
func clear() -> void:
	_queue.clear()
	_text_of.clear()
	_showing = false
	_fade_in = false
	_left = 0.0
	visible = false
