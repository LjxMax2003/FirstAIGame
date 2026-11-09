extends CanvasLayer
class_name LevelUpUI

# 升级三选一：全树暂停 → 弹 3 张卡 → 选完恢复。
# 卡框用 ui_paper_card.svg（200x280，宣纸浅底），内容用色块 + 武器图标贴图。
# ⚠️ 换皮后卡面是**浅底**，文字必须用墨色；原先的白/浅灰配色在宣纸上看不清（对比度 ≈1.1:1）。
#    若要把卡框切回旧深底 ui_card_frame.svg，这个文件的配色必须同步回滚，否则变成"深底黑字"。

# 连续升级（一次捡一堆宝石）用 _pending 排队，不吞卡也不重复弹。
#
# 暂停安全阀：Godot 的 get_tree().paused 是全局开关，一旦"暂停了却没人能点"整局就死锁
# （LevelUpUI 自己的 process_mode 是 ALWAYS，所以它以为还活着，其实游戏已经卡死）。
# 因此这里三件事同时做：①UI 根节点必须拦截 mouse_filter；②_mask 不拦截，让点击穿透到卡片；
# ③_pending 归零即无条件解除暂停，不依赖任何外部调用。

const CARD_W := 200.0
const CARD_H := 280.0
const CARD_GAP := 12.0
# 卡面（宣纸浅底）专用配色：保留"金=武器 / 青=被动"的色相识别，整体压暗到能读。
const ACCENT_WEAPON := Color(0.62, 0.38, 0.06)
const ACCENT_STAT := Color(0.10, 0.40, 0.38)
const INK_NAME := Color(0.13, 0.10, 0.08)
const INK_DESC := Color(0.32, 0.26, 0.20)
# ---------------------------------------------------------------- 迭代04 表现参数
## 战场降调：0.58 亮度 + 6% 偏蓝（b > r），读成"被夜色压下去"而不是"屏幕坏了"。
const WORLD_DIM := Color(0.58, 0.56, 0.66)
## 两侧卡倾角。>4° 时 12px 描述字开始难读（Label 会跟着 rotation 一起转）。
const TILT_DEG := 3.2
## 两侧卡缩放。<0.94 时 12px 落到可读阈值以下，读成"糊了"不是"远了"。
const SIDE_SCALE := 0.965
## 悬停放大。>1.08 会盖住邻卡（卡间距只有 12px）。
const HOVER_SCALE := 1.055
## 七条动画时长（秒）。入场总 0.43s，出场总 0.27s（含 0.05s 收尾停顿）。
const K_ENTER_MASK := 0.16
const K_ENTER_TITLE := 0.22
const K_ENTER_CARD := 0.26
const K_ENTER_STAGGER := 0.055
const K_EXIT_WIN := 0.16
const K_EXIT_LOSE := 0.18
const K_EXIT_HOLD := 0.05

@onready var mask: ColorRect = $Mask
@onready var vignette: TextureRect = $Vignette
@onready var popup: CenterContainer = $Popup
@onready var title: Label = $Popup/VB/Title
@onready var cards: HBoxContainer = $Popup/VB/Cards
@onready var hint: Label = $Popup/VB/Hint

var _pending := 0
var _frame: Texture2D = null
var _icons: Dictionary = {}
## 输入锁（本轮唯一死锁源）：入场 / 出场动画期间为 true，close_all 必须复位。
var _picking := false
## 标题只在第一批入场播一次 —— 连升多级时反复入场会读成"页面在刷新"。
var _first_show := true
## 当前批的 tween。close_all 要 kill 掉，否则会在停用后的节点上继续改属性。
var _tw: Tween = null
## 战场是否已降调（防重复写）。
var _dimmed := false
## 扫光渐变纹理缓存：三张卡共用一个 Texture2D。
var _gloss_cache: Texture2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# CanvasLayer 本身没有 mouse_filter；拦截输入靠下面各 Control 子节点的设置
	mask.visible = false
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = Art.tex(Art.UI_CARD_FRAME)
	# 武器卡的图标由 WeaponDB 统一给出，加武器不用再回来改这里
	for id in WeaponDB.ORDER:
		_icons[id] = Art.tex(WeaponDB.svg(id))
	# 被动卡的图标：走 Art.STAT_ICON 统一表（图鉴读的是同一份，改图只改一处）
	for sid in Art.STAT_ICON.keys():
		_icons[String(sid)] = Art.tex(String(Art.STAT_ICON[sid]))

func bind(player: Player) -> void:
	if not player.level_up.is_connected(_on_level_up):
		player.level_up.connect(_on_level_up)

func _on_level_up() -> void:
	_pending += 1
	if not get_tree().paused:
		_show_next()

func is_open() -> bool:
	return popup.visible

func pending() -> int:
	return _pending

## 收起所有卡片并恢复游戏。卡池抽空、重开、死亡、异常退出都走这里。
##
## ⚠️ 这里的 `_picking = false` 是整轮唯一的死锁安全阀：
##    出场动画期间若玩家死亡 / 重开，close_all 被调用而 _picking 没复位，
##    下一次 _on_pick 会永远在首行早退 —— 界面上三张卡点不动，整局卡死。
func close_all() -> void:
	_pending = 0
	_picking = false
	_first_show = true
	_kill_tween()
	_clear_cards()
	mask.visible = false
	vignette.visible = false
	popup.visible = false
	_dim_world(false)
	if get_tree().paused:
		get_tree().paused = false

func _clear_cards() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()

func _show_next() -> void:
	_clear_cards()
	if _pending <= 0:
		close_all()
		return

	_pending -= 1
	get_tree().paused = true
	# 升级音在卡面出现的同时播。连升多级时由这里逐张播，天然不会叠成一串。
	Audio.play_sfx("levelup")

	var options: Array[Dictionary] = UpgradeDB.draw(UpgradeDB.CARD_COUNT)
	if options.is_empty():
		# 卡池抽空：直接回满血，递归处理剩余排队次数，避免卡在暂停界面
		GameManager.stats["hp"] = GameManager.stats["max_hp"]
		_show_next()
		return
	title.text = "手艺精进  Lv %d" % GameManager.player.level
	hint.text = "选一张手艺卡或心法卡 · 还有 %d 次待处理" % _pending if _pending > 0 else "选一张手艺卡或心法卡"
	for option in options:
		cards.add_child(_make_card(option))
	# 入场动画（遮罩淡入 / 标题落位 / 三张卡错峰弹起）全部在 _enter() 里。
	# ⚠️ 必须放在卡片入树之后：_enter 内部要先等一帧让 HBoxContainer 排好版，
	#    提前调用会读到空容器并直接早退（三张卡就永远没有入场动画）。
	_enter()

func _make_card(entry: Dictionary) -> Control:
	var def: Dictionary = entry["def"]
	var id: String = String(def["id"])
	var is_new: bool = bool(entry["is_new"])
	var is_weapon: bool = UpgradeDB.is_weapon(id)
	var accent: Color = ACCENT_WEAPON if is_weapon else ACCENT_STAT
	# 这张卡将要插进 cards 的第几位。add_child 之前算，等于"即将插入的下标"。
	var order: int = cards.get_child_count()

	var root := Control.new()
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.size = Vector2(CARD_W, CARD_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 伪3D 的三层装饰必须在卡面之前入树，否则会把文字盖住。
	_decorate(root)

	# 卡框贴图
	var frame := TextureRect.new()
	frame.texture = _frame
	frame.size = Vector2(CARD_W, CARD_H)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_new:
		frame.modulate = Color(1.25, 1.15, 0.85)
	root.add_child(frame)

	# 图标：卡框内圈圆心在 (100, 90)，半径 52
	var icon := TextureRect.new()
	icon.texture = _icons.get(id, _frame)
	icon.position = Vector2(100.0 - 34.0, 90.0 - 34.0)
	icon.size = Vector2(68.0, 68.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	var kind := Label.new()
	# 卡面标签：武器 → 手艺，被动 → 心法（真值表 §0）。
	# 新解锁保留一个"新"字：原来写"新武器"，只换 noun 会让"这张是新拿到的"
	# 这条信息消失；13px × 4 字约 52px，卡宽 200 装得下。
	if is_weapon:
		kind.text = "手艺 · 新" if is_new else "手艺"
	else:
		kind.text = "心法 %d/%d" % [int(entry["new_level"]), UpgradeDB.STAT_MAX]
	# 精炼卡：不是"升级"也不是"新武器"，标签必须单独一句，
	# 否则玩家会以为这把武器还能继续涨等级（它已经 Lv8 了）。
	var refine: int = int(entry.get("refine", 0))
	if refine > 0:
		kind.text = "精炼 %d/%d" % [refine, UpgradeDB.REFINE_MAX]
	kind.add_theme_font_size_override("font_size", 13)
	kind.add_theme_color_override("font_color", accent)
	kind.position = Vector2(0.0, 12.0)
	kind.size = Vector2(CARD_W, 20.0)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kind)

	var name_label := Label.new()
	name_label.text = String(def["name"])
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", INK_NAME)
	name_label.position = Vector2(0.0, 182.0)
	name_label.size = Vector2(CARD_W, 30.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)

	var lv_label := Label.new()
	lv_label.text = "Lv 1" if is_new else "Lv %d → %d" % [int(entry["new_level"]) - 1, int(entry["new_level"])]
	if refine > 0:
		lv_label.text = "精炼 %d → %d（Lv%d 满级）" % [refine - 1, refine, WeaponDB.MAX_LEVEL]
	# 满级武器补一句"等宝箱"：让玩家知道 8 级不是终点，进化才是。
	# 满级后分三态，避免"已开脸"的武器还被提示"满级可开脸"。
	if is_weapon and refine <= 0 and int(entry["new_level"]) >= WeaponDB.MAX_LEVEL:
		var req: String = EvolutionDB.req_passive(id)
		var wm: WeaponManager = GameManager.weapons as WeaponManager
		var pl: Player = GameManager.player as Player
		if wm != null and wm.is_evolved(id):
			lv_label.text = "Lv %d · 已开脸" % WeaponDB.MAX_LEVEL
		elif req != "" and pl != null and int(pl.level_upgrades.get(req, 0)) >= EvolutionDB.REQUIRE_PASSIVE_LEVEL:
			lv_label.text = "Lv %d · 待宝箱开脸" % WeaponDB.MAX_LEVEL
		elif req != "":
			lv_label.text = "Lv %d · 开脸需「%s」" % [WeaponDB.MAX_LEVEL, UpgradeDB.stat_name(req)]
		else:
			lv_label.text = "Lv %d · 已至尽头" % WeaponDB.MAX_LEVEL
	lv_label.add_theme_font_size_override("font_size", 14)
	lv_label.add_theme_color_override("font_color", accent)
	lv_label.position = Vector2(0.0, 160.0)
	lv_label.size = Vector2(CARD_W, 20.0)
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lv_label)

	var desc := Label.new()
	# 描述一律由 CardText 从数值公式反推：
	#   武器升级 → "伤害 +12% / 发数 1 → 2"（这一级真的变了什么）
	#   武器首得 → 风味 + 一级身板（"伤害 16 · 冷却 1.60s / 每次 2 发"）
	#   被动     → "全部伤害 +10% / 累计 +30%"
	# 手写文案说过"身前一片"，却从来不说升这一级能多打多少 —— 那正是玩家要判断的东西。
	var lv_to: int = int(entry["new_level"])
	if refine > 0:
		desc.text = CardText.refine_desc(id, refine)
	elif is_weapon:
		desc.text = CardText.weapon_desc(id, lv_to - 1, lv_to)
	else:
		desc.text = CardText.stat_desc(id, lv_to)
	# ⚠️ 描述区宽度受卡框的**右下印章**约束：印章占 x∈[155,181]、y∈[237,263]，
	# 而卡内可用区是 x∈[18,182] —— 居中对齐时任何宽过 155-18 的行都会压到印章下面。
	# 所以这里窄到 128px 并改左对齐（数字列表左对齐本身也更好读）。
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", INK_DESC)
	desc.position = Vector2(24.0, 212.0)
	desc.size = Vector2(128.0, 56.0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(desc)

	# 交互层：整张卡都可点（Button 默认 MOUSE_FILTER_STOP，点击不会穿透到摇杆）
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", _hover_style())
	btn.add_theme_stylebox_override("pressed", _hover_style())
	btn.pressed.connect(_on_pick.bind(order))
	btn.pressed.connect(_blip_hover)
	btn.mouse_entered.connect(_hover.bind(root, true))
	btn.mouse_exited.connect(_hover.bind(root, false))
	root.add_child(btn)

	root.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
	# 入场动画不再在这里播：三张卡的错峰由 _enter() 统一驱动，
	# 否则「谁先动」这件事分散在两次调用里，改时序要改两处。
	root.set_meta("entry", entry)
	root.set_meta("card_index", order)
	return root

func _hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	# 0.06 而不是 v9 的 0.14：叠上本轮新增的扫光与投影后，0.14 会把卡面文字冲淡。
	s.bg_color = Color(0.35, 0.55, 0.85, 0.06)
	s.set_corner_radius_all(12)
	return s

## 悬停/按下时的轻响。和 _on_pick 的 ui_confirm 分工：
## 这个只是"手摸到了"，按下才"决定了"。两个都存在，玩家才不会觉得界面是死板。
func _blip_hover() -> void:
	Audio.play_sfx("ui_click", -4.0)

## 键盘 1/2/3 与会话按钮都收敛到这里。`index` 是卡片在 HBoxContainer 中的下标，
## 真正要 apply 的那份 entry 存在卡根节点的 meta 里（见 _make_card 末尾）。
## ⚠️ `_picking` 必须在这里同步早退：动画期间连点三次，只有第一次能过。
func _on_pick(index: int) -> void:
	if _picking:
		return
	if index < 0 or index >= cards.get_child_count():
		return
	# v9 F1：选卡是全流程里唯一"玩家做了决定"的界面动作，必须有声。
	# 用 ui_confirm 而不是 ui_click —— 这是确认，不是点一下看看。
	Audio.play_sfx("ui_confirm")
	_pick_async(index)

## 键盘 1/2/3 也能选卡：桌面与自动化测试都靠这条路径，不依赖鼠标坐标
func _unhandled_key_input(event: InputEvent) -> void:
	if not popup.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var idx: int = -1
	match key.keycode:
		KEY_1, KEY_KP_1:
			idx = 0
		KEY_2, KEY_KP_2:
			idx = 1
		KEY_3, KEY_KP_3:
			idx = 2
	if idx < 0 or idx >= cards.get_child_count():
		return
	var root: Control = cards.get_child(idx) as Control
	for c in root.get_children():
		if c is Button:
			(c as Button).pressed.emit()
			get_viewport().set_input_as_handled()
			return

# =====================================================================
# 迭代04 表现层（只动视觉与输入锁，不碰 UpgradeDB / GameManager 的任何数值）
# =====================================================================

## 伪3D 的三层装饰：投影 ×3 / 侧面厚度 / 扫光。
## 三者全部复用卡框贴图（Art.UI_CARD_FRAME），用 modulate 染色 ——
## 轮廓与卡面天然吻合，不用画第二套形状，也不会出现"圆角卡片配直角影子"。
##
## ⚠️ 必须在 root.add_child(frame) 之【前】调用，否则会盖住卡面与文字。
## ⚠️ 只加 TextureRect / Control，绝不把 Label 包进任何容器 ——
##    tools/CardShot.gd 靠"Label 是卡根直接子节点"定位文字（:115 / :168），
##    包一层就让它静默跳过，117 张卡的断言会全部变成假绿。
func _decorate(root: Control) -> void:
	if _frame == null:
		return
	var shadows: Array[TextureRect] = []
	# 投影三层：offset 递减、alpha 递减，模拟软边（TextureRect 没有模糊）。
	# 为什么不做成"一层大阴影"：单层边缘是硬切，在深色墨幕上会读成"卡片描了一圈黑边"。
	for spec in [
		{"y": 24.0, "s": 1.05, "a": 0.26},
		{"y": 17.0, "s": 1.03, "a": 0.14},
		{"y": 11.0, "s": 1.01, "a": 0.07},
	]:
		var sh := TextureRect.new()
		sh.texture = _frame
		sh.size = Vector2(CARD_W, CARD_H)
		sh.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_SCALE
		sh.modulate = Color(0.02, 0.015, 0.01, float(spec["a"]))
		sh.position = Vector2(0.0, float(spec["y"]))
		sh.scale = Vector2.ONE * float(spec["s"])
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.set_meta("shadow", true)
		sh.set_meta("base_a", float(spec["a"]))
		sh.set_meta("base_y", float(spec["y"]))
		root.add_child(sh)
		shadows.append(sh)

	# 侧面厚度：同轮廓、深褐（与卡框描边 #3B2617 同色系）、偏移 (3,9)。
	# 卡面会盖住它大部分，只露出右/下一条 3~9px 的深边 —— 那就是"这张纸有厚度"。
	var spine := TextureRect.new()
	spine.texture = _frame
	spine.size = Vector2(CARD_W, CARD_H)
	spine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spine.stretch_mode = TextureRect.STRETCH_SCALE
	spine.modulate = Color(0.22, 0.15, 0.10)
	spine.position = Vector2(3.0, 9.0)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spine)

	# 扫光：装在一个裁到「纸面区」的容器里。不裁剪的话，斜白条会扫到相邻卡上。
	# 容器尺寸 = 卡框内纸面 (8,10) 起 184×262，与 ui_paper_card.svg 的 rect 对齐。
	var box := Control.new()
	box.position = Vector2(8.0, 10.0)
	box.size = Vector2(184.0, 262.0)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var gloss := TextureRect.new()
	gloss.texture = _gloss_tex()
	gloss.size = Vector2(96.0, 380.0)
	gloss.pivot_offset = Vector2(48.0, 190.0)
	gloss.rotation = deg_to_rad(18.0)
	gloss.position = Vector2(-150.0, -70.0)
	gloss.modulate = Color(1.0, 0.98, 0.92, 0.0)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.set_meta("gloss", true)
	box.add_child(gloss)

	root.set_meta("shadows", shadows)
	root.set_meta("gloss_ref", gloss)

## 扫光用的横向渐变（白 → 透明 → 白的两头对称，中间实）。
## 缓存一份：三张卡共用同一个 Texture2D，不重复生成。
func _gloss_tex() -> Texture2D:
	if _gloss_cache != null:
		return _gloss_cache
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 96
	t.height = 8
	_gloss_cache = t
	return t

## 三张卡的静置姿态。**只返回渲染变换，不返回 position** ——
## HBoxContainer 每次 sort 都会用自己的布局值覆写子节点 position，
## 把"两侧卡下移 10px"写进静态姿态，会在下一次容器重排时被无声抹掉
## （表现是"有时候歪、有时候不歪"，只在窗口尺寸变化那一下出现，极难复现）。
func _pose(index: int, total: int) -> Dictionary:
	if total <= 1:
		return {"rot": 0.0, "scale": 1.0}
	var mid: float = float(total - 1) * 0.5
	var off: float = (float(index) - mid) / maxf(mid, 1.0)     # -1 .. +1
	return {
		"rot": deg_to_rad(TILT_DEG) * off,
		"scale": 1.0 - (1.0 - SIDE_SCALE) * absf(off),
	}

## 入场：遮罩淡入 → 标题落位 → 三张卡错峰弹起 → 提示淡入，总 0.42s。
##
## ⚠️ 第一行的 await 不能省：cards.add_child() 只是 queue_sort()，
##    容器在【下一帧】才排好版。早于它读 position 得到的是 0，
##    会做出"三张卡从屏幕左上角飞进来"的错动画。
## ⚠️ 整个动画跑在 get_tree().paused == true 下。这依赖 LevelUpUI 在 _ready 首行设了
##    PROCESS_MODE_ALWAYS；把那一行改掉，全场动画会静止在定格画面。
func _enter() -> void:
	mask.visible = true
	vignette.visible = true
	popup.visible = true
	if cards.get_child_count() <= 0:
		return
	_picking = true

	await get_tree().process_frame
	if cards.get_child_count() <= 0:
		# 期间被 close_all() / CardShot 的 _clear_cards() 清掉了，直接退。
		_picking = false
		return
	var n: int = cards.get_child_count()

	_dim_world(true)
	_kill_tween()
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(mask, "color:a", 0.80, K_ENTER_MASK).from(0.0)
	_tw.tween_property(vignette, "modulate:a", 1.0, K_ENTER_MASK).from(0.0)

	# 连升多级时标题不重复入场：每次闪一下会读成"页面在刷新"。
	if _first_show:
		_first_show = false
		var ty: float = title.position.y
		title.position.y = ty - 26.0
		title.modulate.a = 0.0
		_tw.tween_property(title, "position:y", ty, K_ENTER_TITLE) \
			.set_delay(0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(title, "modulate:a", 1.0, K_ENTER_TITLE).set_delay(0.04)
	else:
		title.modulate.a = 1.0

	hint.modulate.a = 0.0
	_tw.tween_property(hint, "modulate:a", 1.0, 0.18).set_delay(0.24)

	for i in n:
		var c: Control = cards.get_child(i) as Control
		if c == null:
			continue
		var p: Dictionary = _pose(i, n)
		# rest 必须从容器已排好的当前值读，不能硬算 i*(CARD_W+CARD_GAP)：
		# 硬算会在 separation 或卡宽改动时静默错位。
		var rest: Vector2 = c.position
		c.set_meta("rest_y", rest.y)
		c.set_meta("rest_pose", p)
		var d: float = 0.06 + K_ENTER_STAGGER * float(i)
		c.position = rest + Vector2(0.0, 64.0)
		c.rotation = 0.0
		c.scale = Vector2(0.90, 0.90)
		c.modulate.a = 0.0
		_tw.tween_property(c, "position", rest, K_ENTER_CARD) \
			.set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(c, "rotation", float(p["rot"]), K_ENTER_CARD) \
			.set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(c, "scale", Vector2.ONE * float(p["scale"]), K_ENTER_CARD) \
			.set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(c, "modulate:a", 1.0, 0.14).set_delay(d)

	await _tw.finished
	_picking = false

## 升级时把战场压低一档。0.58 亮度 + 6% 偏蓝（b > r）读成"被夜色压下去"，
## 而不是"屏幕坏了"。
## 只改 modulate，不动 scale —— 动 scale 会带着 Camera2D 一起抖，玩家会以为卡了。
func _dim_world(on: bool) -> void:
	if on == _dimmed:
		return
	var w: CanvasItem = _world()
	if w == null:
		return
	_dimmed = on
	var tw: Tween = create_tween()
	tw.tween_property(w, "modulate", WORLD_DIM if on else Color.WHITE, 0.22)

## LevelUpUI 挂在 $UI（CanvasLayer）下，$UI 的父是 Game。
## 用函数式取值而不是写死 "../../World"：节点改名时路径字符串会静默返回 null，
## 这里能提前 return，不会把 null 传给 tween 报一串错。
func _world() -> CanvasItem:
	var g: Node = get_parent().get_parent()
	if g == null:
		return null
	return g.get_node_or_null("World") as CanvasItem

## 出场 → 结算 → 下一批。
## 为什么结算放在动画之后：UpgradeDB.apply 会改武器等级并让 HUD 的手艺槽刷新，
## 先结算再动画 = 玩家会看到"卡还在飞、HUD 已经变了"。
func _pick_async(index: int) -> void:
	_picking = true
	await _exit(index)
	_picking = false
	if not popup.visible:
		return
	var e: Dictionary = _entry_of(index)
	if not e.is_empty():
		UpgradeDB.apply(e)
	_show_next()

## 从卡片的 meta 读回 entry。用 meta 而不是让 _on_pick 直接 bind entry：
## 出场动画需要知道"第几张"，绑 index 才能算出谁该翻面、谁该倒。
func _entry_of(index: int) -> Dictionary:
	if index < 0 or index >= cards.get_child_count():
		return {}
	var c: Control = cards.get_child(index) as Control
	if c == null:
		return {}
	return c.get_meta("entry", {}) as Dictionary

## 出场：选中的翻面抽走，落选的两张向外倒。总 0.22s + 0.05s 停顿。
## 为什么落选卡是"倒"而不是淡出：三张牌摊在桌上，抽走一张、另外两张被带得晃一下 ——
## 这是"桌上有三张实体牌"这个设定唯一自洽的收场。纯淡出会退回"三张贴纸"。
func _exit(win: int) -> void:
	if cards.get_child_count() <= 0:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.set_parallel(true)
	for i in cards.get_child_count():
		var c: Control = cards.get_child(i) as Control
		if c == null:
			continue
		var p: Dictionary = c.get_meta("rest_pose", {"rot": 0.0, "scale": 1.0})
		var ry: float = float(c.get_meta("rest_y", c.position.y))
		if i == win:
			# 绕 Y 轴翻成一条线。scale.x → 0 在 2D 里就是"转到侧面"，
			# 是本项目能做的、最接近翻牌的效果，且一帧成本为零。
			# 不做真 3D 翻转：本项目没有卡背资产，翻过来是空白，比不翻更假。
			_tw.tween_property(c, "scale:x", 0.02, K_EXIT_WIN) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_tw.tween_property(c, "position:y", ry - 50.0, K_EXIT_WIN) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_tw.tween_property(c, "modulate:a", 0.0, 0.08).set_delay(K_EXIT_WIN - 0.08)
		else:
			# 方向取它原本歪的那一侧：看起来像"被抽走那张带倒的"，而不是"两边对称倒下"。
			# ⚠️ rotation 的单位是弧度：rest 本身是弧度，+14° 必须再 deg_to_rad。
			var side: float = 1.0 if float(p["rot"]) >= 0.0 else -1.0
			_tw.tween_property(c, "rotation", float(p["rot"]) + side * deg_to_rad(14.0), K_EXIT_LOSE) \
				.set_delay(0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_tw.tween_property(c, "position:y", ry + 36.0, K_EXIT_LOSE) \
				.set_delay(0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_tw.tween_property(c, "modulate:a", 0.0, 0.12).set_delay(0.10)
	# 墨幕随卡一起撤（handoff §7.3 未列，主件 §3 的出场表亦未列）。
	# 不撤会有两处硬切：①单次升级结束时 close_all 把遮罩瞬间隐藏；
	# ②连升下一批 _enter 的 .from(0.0) 会把 0.80 的遮罩瞬间归零再淡入（战场闪一下）。
	# 时长压在 0.22s 内，不延长 §5.2 的出场总时长 0.27s。
	_tw.tween_property(mask, "color:a", 0.0, 0.20).set_delay(0.02)
	_tw.tween_property(vignette, "modulate:a", 0.0, 0.20).set_delay(0.02)
	await _tw.finished
	# 停顿给"抽走"一个收尾。暂停态下 create_timer 默认 process_always = true，照走。
	await get_tree().create_timer(K_EXIT_HOLD).timeout

func _kill_tween() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null

## 悬停：转正 + 抬高 + 投影变淡拉长 + 扫光。
##
## "影子变淡变长"是伪 3D 里最关键的一步，比放大本身更能读出"离地了" ——
## 真实世界物体抬起来，投影会更远、更虚、更淡。只放大不换影子，读起来是"贴纸被拉大"。
func _hover(card: Control, on: bool) -> void:
	if _picking or card == null:
		return
	var p: Dictionary = card.get_meta("rest_pose", {"rot": 0.0, "scale": 1.0})
	var ry: float = float(card.get_meta("rest_y", card.position.y))
	var dur: float = 0.10 if on else 0.14
	var tw: Tween = card.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "rotation", 0.0 if on else float(p["rot"]), dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE * (HOVER_SCALE if on else float(p["scale"])), dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position:y", ry - 12.0 if on else ry, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var shadows: Array = card.get_meta("shadows", [])
	for node in shadows:
		var sh: TextureRect = node as TextureRect
		if sh == null:
			continue
		var ba: float = float(sh.get_meta("base_a", 0.2))
		var by: float = float(sh.get_meta("base_y", 0.0))
		tw.tween_property(sh, "modulate:a", ba * (0.55 if on else 1.0), dur)
		tw.tween_property(sh, "position:y", by * (1.35 if on else 1.0), dur)

	if not on:
		return
	# 扫光：只在进入时播一次。每次移入都重播会像"有人在反复擦屏幕"。
	var g: TextureRect = card.get_meta("gloss_ref", null) as TextureRect
	if g == null:
		return
	g.position = Vector2(-150.0, -70.0)
	var gt: Tween = card.create_tween()
	gt.set_parallel(true)
	gt.tween_property(g, "modulate:a", 0.18, 0.06)
	gt.tween_property(g, "position:x", 190.0, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	gt.chain().tween_property(g, "modulate:a", 0.0, 0.10)
