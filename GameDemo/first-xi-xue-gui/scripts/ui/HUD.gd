extends Control
class_name HUD

# 顶部：暂停 / 等级 / 更次·时间 / 经验条 / 血量条 / 归色·同屏·灯花·铜钱 / 手艺槽
# 底部：虚拟摇杆（单指相对拖拽的可视化）
# 受击：全屏红边淡出，给"擦边求生"明确的危险反馈

const JOY_MAX := 56.0
## 受伤红边的强度上限。原先它是"整屏纯红 ColorRect 的 alpha"，换成边缘侵蚀后
## 只有视口四边那圈被填色，同样的数值看上去会淡得多，所以这里相应上调。
const HURT_ALPHA := 0.62
## 血量数字在这些阈值下的颜色。低血变朱红是**唯一**一处必须靠颜色说话的读数：
## 玩家在满屏纸片里不会去读数字，但"这行字变红了"是余光能抓到的。
const LOW_HP_RATIO := 0.30
const HP_COLOR_NORMAL := Color(1.0, 1.0, 1.0, 0.97)
const HP_COLOR_WARN := Color(1.0, 0.42, 0.34, 1.0)

## 五更命名：与 WaveTable.WAVES 的 5 段边界严格对齐（0/300/600/1200/1500/1800）。
## 不新增任何时间常量——更次只是给已有的 5 段换标签。
## ⚠️ 本表长度必须等于 WaveTable.WAVES.size()，下标直接来自 wave_index()。
const GENG_NAMES: Array[String] = ["一更·戌时", "二更·亥时", "三更·子时", "四更·丑时", "五更·寅时"]
# 武器槽图标：直接用 weapons/*.svg，和场景里看到的特效是同一张图
const WEAPON_ICONS := {
	"whip": Art.WHIP_ARC,
	"halo": Art.HALO_RING,
	"glowstick": Art.WAND_GLOWSTICK,
	"phone": Art.PHONE_ORBIT,
	"blade": Art.KNIFE_BOXCUTTER,
	"extinguisher": Art.AXE_EXTINGUISHER,
	"gong": Art.GONG,
	"inkline": Art.INKLINE,
	"print": Art.WOODBLOCK_PRINT,
}

@onready var xp_bar: TextureProgressBar = $Top/Col/XPBar
@onready var hp_bar: TextureProgressBar = $Top/Col/HPBar
## 三条读数。数字**叠在条上居中**而不是排在条右边：
## 竖屏 720 宽已经被 16px 边距吃满，条本身占满整行，右边根本没有位置。
## 叠在条上还有个副作用是好的 —— 数字随条一起被同一条 9-patch 框住，读起来是"一个仪表"。
@onready var xp_label: Label = $Top/Col/XPBar/XPNum
@onready var hp_label: Label = $Top/Col/HPBar/HPNum
@onready var shield_bar: TextureProgressBar = $Top/Col/ShieldBar
@onready var shield_label: Label = $Top/Col/ShieldBar/ShieldNum
@onready var level_label: Label = $Top/Col/Row/Level
@onready var timer_label: Label = $Top/Col/Row/Timer
@onready var timer_small: Label = $Top/Col/Row/TimerSmall
@onready var pause_btn: Button = $Top/Col/Row/Pause
@onready var info: Label = $Top/Col/Info
@onready var fps: Label = $FPS
@onready var joy: Node2D = $Joystick
@onready var knob: Sprite2D = $Joystick/Knob
@onready var hurt: ColorRect = $Hurt
@onready var weapon_row: HBoxContainer = $Top/Col/Weapons

var _player: Player
var _game: GameScene
## 受伤红边材质。Hurt 节点的颜色由 shader 决定，每帧只推 max_alpha。
var _hurt_mat: ShaderMaterial = null
var _slots: Dictionary = {}
var _signature: String = ""
var _banner: Label = null
var _banner_left := 0.0
var _banner_color := Color(1.0, 0.86, 0.42)
## 血量数字当前是否处于"低血"配色。缓存它是为了只在跨越阈值时改一次主题覆盖。
var _hp_warn := false
# ---- v5 主动技按钮（右下角，独立于摇杆：竖屏单指在左下/中部拖，右下留一个拇指按键）
var _skill_btn: TextureButton = null
var _skill_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	joy.visible = false
	hurt.color = Color.WHITE
	# 受伤反馈：整屏均匀泛红读作"屏幕坏了"，从四边侵蚀进来才读作"我快不行了"。
	# 成本一样（都是一个全屏 ColorRect），所以没有保留纯红版的理由。
	# 注意 hurt.color 必须是纯白：ColorRect 的 color 是顶点色，会乘进 shader 输出，
	# 留着红色就成了"红 × 红"。
	_hurt_mat = ShaderFX.hurt_setup(hurt)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.texture = Art.tex(Art.GEM_BLUE)
	pause_btn.pressed.connect(_on_pause_pressed)
	_setup_hp_fill()
	_setup_banner()
	_setup_skill_button()

## 进化横幅：屏幕中上方弹一行金字。用 Label 而不是场景节点，
## 是因为它只有"显示 1.6 秒然后淡出"这一种用法，为它单独做一个 .tscn 不划算。
func _setup_banner() -> void:
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	_banner.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 150.0
	_banner.offset_bottom = 200.0
	add_child(_banner)

func flash_evolve(text: String) -> void:
	_show_banner(text, Color(1.0, 0.86, 0.42), 1.6)

## Boss 登场：红色横幅 + 更长的停留时间。
## Boss 是单局里唯一"玩家必须立刻改变行为"的事件，横幅要是和捡到烤鸡一样闪 1.6 秒就没了，
## 玩家会以为那只是一次普通掉落。
func flash_boss(text: String) -> void:
	_show_banner(text, Color(1.0, 0.34, 0.30), 3.0)

## 五更鸡鸣（判胜演出）：暖金 + 与 WIN_HOLD 同长。
## 复用 flash_boss 会把这句"天亮"染成危险红——同一块横幅，红色代表"快跑"，
## 这里必须换成结算标题同色系的金，玩家才不会在天亮那一秒以为自己要死。
func flash_dawn(text: String) -> void:
	_show_banner(text, Color(1.0, 0.86, 0.42), 2.0)

## 复活：青色 + 2.4 秒。
## 用青色而不是进化金/受击红：这是"局外买来的东西起作用了"的独有反馈，
## 和局内成长（金）与危险（红）都区分开，玩家一眼能认出钱花在哪了。
func flash_revive(text: String) -> void:
	_show_banner(text, Color(0.42, 0.92, 0.86), 2.4)

func _show_banner(text: String, color: Color, hold: float) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner_color = color
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.modulate = Color.WHITE
	_banner_left = hold

## 血条不能靠 tint 染 ui_bar_fill.svg：那张图主色是 #6FD8FF，
## 相乘只会在 0..1 里越乘越暗，红色永远出不来（实测得到脏蓝紫）。
## 这里直接生成一条纯红渐变，纵向做"上亮下暗"，保留原图那种圆柱高光感。
func _setup_hp_fill() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.62, 0.60),
		Color(0.93, 0.32, 0.32),
		Color(0.80, 0.16, 0.20),
		Color(0.62, 0.09, 0.14),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 32
	hp_bar.texture_progress = t
	hp_bar.tint_progress = Color.WHITE

func bind(player: Player, game: GameScene) -> void:
	_player = player
	_game = game
	xp_bar.max_value = float(player.xp_next)
	_sync_weapon_row(true)

func _process(_delta: float) -> void:
	if _banner != null and _banner.visible:
		_banner_left -= _delta
		# 最后 0.6s 淡出，避免硬切
		_banner.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0)
		if _banner_left <= 0.0:
			_banner.visible = false
	if _player == null:
		return
	xp_bar.max_value = float(_player.xp_next)
	xp_bar.value = float(_player.xp)
	# 经验数字：百分比没有意义（玩家想知道"还差几次拾取"），所以给绝对值。
	# 注意 xp 是**当前等级内**的经验（gain_xp 会把它减去 xp_next），不是累计。
	xp_label.text = "%d / %d" % [_player.xp, _player.xp_next]
	var hp_now: float = maxf(0.0, float(_player.stats["hp"]))
	var hp_max: float = maxf(1.0, float(_player.stats["max_hp"]))
	hp_bar.max_value = hp_max
	hp_bar.value = hp_now
	# 血量必须给数字：条只能读"大概还剩多少"，而"我还能挨几下"是按点数算的
	# （接触伤害 6 点起），没有数字玩家只能靠猜。
	hp_label.text = "%d / %d" % [int(ceilf(hp_now)), int(round(hp_max))]
	# 低血变色只在**跨越阈值那一帧**写一次主题覆盖：
	# add_theme_color_override 每帧调用会持续标脏主题并触发重排版，是 HUD 里最容易写出的隐形热点。
	var warn: bool = hp_now <= hp_max * LOW_HP_RATIO
	if warn != _hp_warn:
		_hp_warn = warn
		hp_label.add_theme_color_override("font_color", HP_COLOR_WARN if warn else HP_COLOR_NORMAL)
	_update_shield()
	level_label.text = "Lv %d" % _player.level
	# 更次是主标题（26px），时间退成右侧小字（15px）——策划案 §9.4「更次 + 小字时间」。
	# 更次一律问 WaveTable.wave_index()，不在这里写 if-else：HUD 与刷怪必须同一份边界，
	# 在 HUD 里硬编码 300/600/1200/1500 就是给以后调波次埋雷。
	var t: int = int(_game.elapsed)
	var left: int = int(maxf(WaveTable.RUN_LENGTH - _game.elapsed, 0.0))
	var wi: int = clampi(WaveTable.wave_index(_game.elapsed), 0, GENG_NAMES.size() - 1)
	timer_label.text = GENG_NAMES[wi]
	# 剩余秒数不能省：30 分钟是本作唯一主目标，玩家盯"剩 18:00"比盯"已过 12:00"
	# 更能撑住最后 5 分钟（Step 3 就定下的决定，换皮不推翻，只降字号让位给更次）。
	timer_small.text = "%02d:%02d  ·  剩 %02d:%02d" % [t / 60, t % 60, left / 60, left % 60]
	info.text = "归色 %d    同屏 %d    灯花 %d    铜钱 %d" % [
		_game.kills, _game.alive_enemies(), _game.gem_count(), _game.coin_reward()]
	if _game.evolutions > 0:
		info.text += "    开脸 %d" % _game.evolutions
	if _game.enemies.has_boss():
		info.text = "BOSS 在场    " + info.text
	fps.text = "%d fps" % Engine.get_frames_per_second()
	# 受伤红边：hit_flash 本身就是一条连续衰减曲线（Player 每帧 -3/s），
	# 所以这里每帧直接写 uniform，不用 tween —— 两条动画抢同一个参数会一顿一顿。
	ShaderFX.hurt_drive(hurt, HURT_ALPHA * _player.hit_flash)
	_update_joystick()
	_sync_weapon_row(false)
	_update_skill_button()

func _on_pause_pressed() -> void:
	if _game != null:
		_game.toggle_pause()

# ---------------------------------------------------------------- 血 / 经验 / 护盾
## 护盾条 + 护盾数字。只有买了「结界」被动才会出现（stats["shield"] > 0）。
##
## 为什么用 visible 控制，而不是永远画一条空条：
## 空条会被读成"我有一个用光的护盾"，而没买被动的玩家根本不该知道这个格子的存在。
## VBoxContainer 会**跳过** visible=false 的子节点，所以隐藏时它不占布局 ——
## 没买被动的玩家看到的 HUD 与改动前逐像素一致（不会多出 14px 空隙）。
func _update_shield() -> void:
	# 条的上限是**盾池上限**（30+6×lv），不是每脉冲给的量（5+3×lv）。
	# v7 起这两者是不同的数：拿脉冲值当上限会把 60 的池子画成 20，
	# 玩家会以为"盾一次就满"，然后困惑于为什么还能继续攒。
	var smax: float = float(_player.stats.get("shield_cap", 0.0))
	var want: bool = smax > 0.0
	if shield_bar.visible != want:
		shield_bar.visible = want
	if not want:
		return
	# 护盾当前值是 Player 的运行时状态（先扣盾再扣血），不是 stats 里的
	# —— stats["shield_cap"] 只是"最多能攒到多少"，两者混用会显示成"永远是满的"。
	var now: float = clampf(_player.shield_hp, 0.0, smax)
	shield_bar.max_value = smax
	shield_bar.value = now
	shield_label.text = "%d / %d" % [int(ceilf(now)), int(round(smax))]

# ---------------------------------------------------------------- 主动技按钮
## 为什么是独立按钮而不是"双击/长按摇杆"：
## 摇杆是"按住拖动"的连续手势，双击会与"拖一下再停"混淆；长按会吃掉走位。
## 竖屏右手拇指本来就有空位（左下走位），给它一个固定按键最不容易误触。
func _setup_skill_button() -> void:
	_skill_btn = TextureButton.new()
	_skill_btn.name = "SkillBtn"
	_skill_btn.texture_normal = Art.tex(Art.UI_SKILL_ROAR)
	_skill_btn.ignore_texture_size = true
	_skill_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# 右下角：96x96，离屏幕边 20px，抬高到摇杆上方 —— 落在"暂停按钮正下方"这条拇指弧上
	_skill_btn.anchor_left = 1.0
	_skill_btn.anchor_top = 1.0
	_skill_btn.anchor_right = 1.0
	_skill_btn.anchor_bottom = 1.0
	_skill_btn.offset_left = -116.0
	_skill_btn.offset_top = -196.0
	_skill_btn.offset_right = -20.0
	_skill_btn.offset_bottom = -100.0
	_skill_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_btn.pressed.connect(_on_skill_pressed)
	add_child(_skill_btn)

	_skill_label = Label.new()
	_skill_label.add_theme_font_size_override("font_size", 22)
	_skill_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	_skill_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_skill_label.add_theme_constant_override("shadow_offset_x", 2)
	_skill_label.add_theme_constant_override("shadow_offset_y", 2)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_label.anchor_left = 1.0
	_skill_label.anchor_top = 1.0
	_skill_label.anchor_right = 1.0
	_skill_label.anchor_bottom = 1.0
	_skill_label.offset_left = -116.0
	_skill_label.offset_top = -196.0
	_skill_label.offset_right = -20.0
	_skill_label.offset_bottom = -100.0
	add_child(_skill_label)

func _on_skill_pressed() -> void:
	if _player == null or _player.active_skill == null:
		return
	# 放不出来时给一次"按下无效"的反馈：不弹窗、不报错，只让按钮闪一下，
	# 否则玩家会以为按钮坏了（CD 遮罩是暗的，摸鱼时很容易看漏）。
	if not _player.active_skill.try_cast():
		_skill_btn.modulate = Color(1.0, 0.6, 0.6, 1.0)

func _update_skill_button() -> void:
	if _skill_btn == null or _player == null or _player.active_skill == null:
		return
	var sk: ActiveSkill = _player.active_skill
	var r: float = sk.cd_ratio()
	if r <= 0.0:
		# 可用：常态亮 + 极轻的呼吸，保证在满屏纸片里能被余光扫到
		_skill_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_skill_label.text = ""
	else:
		_skill_btn.modulate = Color(0.55, 0.55, 0.60, 0.75)
		_skill_label.text = "%d" % int(ceilf(sk.cd_left))

## 暂停按钮可直接从外部改文案（Game 负责真正的暂停状态）
func set_paused(paused: bool) -> void:
	pause_btn.text = "▶" if paused else "II"

func _update_joystick() -> void:
	if not _player.is_dragging():
		joy.visible = false
		return
	joy.visible = true
	joy.position = _player.drag_origin()
	var offset: Vector2 = _player.touch_offset()
	knob.position = offset.limit_length(JOY_MAX)
	var full: float = clampf(offset.length() / JOY_MAX, 0.0, 1.0)
	knob.modulate = Color(1.0, 1.0, 1.0, 0.45 + 0.5 * full)
	knob.scale = Vector2.ONE * (0.8 + 0.3 * full)
	knob.rotation = 0.0

## 已持有武器槽：一排小图标 + 等级，让 Build 状态一眼可见。
## 只在武器集合或等级变化时重建，避免每帧 free 节点。
func _sync_weapon_row(force: bool) -> void:
	var weps: Dictionary = _game.weapons.owned
	var keys: Array = weps.keys()
	keys.sort()
	var sig_parts: Array[String] = []
	for id in keys:
		# 进化会改名但不改等级，签名里必须带上进化标记，否则槽位不会刷新成进化配色；
		# 精炼同理（Lv8 之后再 pick 只改精炼层数，等级签名不会变）
		sig_parts.append("%s:%d:%s:%d" % [String(id), int(weps[id]),
			_game.weapons.evolution_of(String(id)), _game.weapons.refine_tier(String(id))])
	# 开脸数必须进签名：它不在武器/等级里，漏了会让"开脸徽章"在进化后不刷新
	var sig: String = ",".join(sig_parts) + "|evo:%d" % _game.evolutions
	if not force and sig == _signature:
		return
	_signature = sig
	for c in weapon_row.get_children():
		weapon_row.remove_child(c)
		c.queue_free()
	_slots.clear()
	for id in keys:
		var wid: String = String(id)
		var evolved: bool = _game.weapons.is_evolved(wid)
		var box := Control.new()
		box.custom_minimum_size = Vector2(46, 46)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 半透明圆角底板：没有它，图标会和地面纹理糊在一起，看不出"这是一个槽位"
		var plate := Panel.new()
		plate.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.055, 0.078, 0.129, 0.62)
		# 进化槽描金边：不靠文字，一眼能从人堆里认出来
		sb.border_color = Color(1.0, 0.80, 0.35, 0.95) if evolved else Color(1.0, 1.0, 1.0, 0.14)
		sb.set_border_width_all(2 if evolved else 1)
		sb.set_corner_radius_all(8)
		plate.add_theme_stylebox_override("panel", sb)
		box.add_child(plate)
		var ic := TextureRect.new()
		# 进化后优先用专属贴图（只有 gong/inkline/extinguisher 有），
		# 没有独立图的进化回落到本体图 —— 槽位仍然靠金边 + MAX 读"满"。
		var icon_path: String = Art.evolved_weapon_svg(wid) if evolved else ""
		if icon_path == "":
			icon_path = String(WEAPON_ICONS.get(wid, Art.GEM_BLUE))
		ic.texture = Art.tex(icon_path)
		# expand_mode = IGNORE_SIZE 让贴图不再参与最小尺寸计算；
		# 但父级 box 是普通 Control（不排版子节点），所以尺寸必须显式给，否则会退回贴图原尺寸。
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_position(Vector2(3, 3), false)
		ic.set_size(Vector2(40, 40), false)
		box.add_child(ic)
		ic.set_position(Vector2(3, 3), false)
		ic.set_size(Vector2(40, 40), false)
		# 等级外框：槽位里那个 12px 的数字在战斗中根本不会被读，
		# 颜色才是前注意特征 —— 余光扫一眼就知道哪把变成金/朱红了。
		# Lv1~2 故意不出框（新手期画面越干净越好），进化态额外有 9Hz 呼吸。
		# 必须放在 set_size 之后：框宽要按"显示 40px vs 源图分辨率"换算。
		ShaderFX.set_rank(ic, int(weps[id]), evolved)
		var lv := Label.new()
		lv.add_theme_font_size_override("font_size", 12)
		lv.add_theme_color_override("font_color", Color(1, 0.87, 0.5))
		lv.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lv.add_theme_constant_override("shadow_offset_x", 1)
		lv.add_theme_constant_override("shadow_offset_y", 1)
		lv.position = Vector2(30, 28)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 进化后显示 MAX 而不是 8：玩家看到"满"就知道这条路走完了
		lv.text = "MAX" if evolved else "%d" % int(weps[id])
		box.add_child(lv)
		# 精炼徽标：Lv8 之后再投入的层数。不写在等级里（"8·2"在 46px 槽位读不出来），
		# 改成角标 —— 玩家的判读是"这格满了但有金饰"，而不是去数数字。
		# v6：挪到**左上**，把右上让给觉醒徽记（两者都只在 Lv8+ 出现，会撞车）。
		var rt: int = _game.weapons.refine_tier(wid)
		if rt > 0:
			var badge := TextureRect.new()
			badge.texture = Art.tex(Art.UI_REFINE_BADGE)
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.position = Vector2(0, 0)
			badge.size = Vector2(20, 20)
			box.add_child(badge)
			var rl := Label.new()
			rl.text = "%d" % rt
			rl.add_theme_font_size_override("font_size", 11)
			rl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
			rl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			rl.add_theme_constant_override("shadow_offset_x", 1)
			rl.add_theme_constant_override("shadow_offset_y", 1)
			rl.position = Vector2(7, 3)
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(rl)
		# 觉醒徽记（v6 §3.2 必须项）：只有 Lv8 才出现。
		# 进化形态一定在 Lv8（EvolutionDB.REQUIRE_WEAPON_LEVEL = 8），所以按等级判一遍就够，
		# 不用再 or 一个 evolved —— 两条判断题会让"进化了但等级掉了"这种不存在的情况多一种写法。
		# 不新开 Control 层：直接叠在槽位卡面右上角（清单 §6 的 HUD 约束）。
		if int(weps[id]) >= WeaponDB.MAX_LEVEL:
			var aw := TextureRect.new()
			aw.name = "AwakenBadge"
			aw.texture = Art.tex(Art.AWAKEN_BADGE)
			aw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			aw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			aw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# 源图 64×32 → 26×13：46px 的槽位里再大就会盖住武器图标本身，
			# 而图标是"这是哪把武器"的唯一凭据，不能被角标吃掉。
			aw.position = Vector2(20, 0)
			aw.size = Vector2(26, 13)
			box.add_child(aw)
		weapon_row.add_child(box)
		_slots[id] = lv

	# U-01 常驻开脸徽章：分母读 EvolutionDB.FORMS.size()，配方增减时自动跟上，
	# 不在 UI 里硬编码 9。与 46px 槽位同高，金色 + 黑描边，不拦截鼠标
	# （否则它会吃掉右侧 52px 的触摸区，把摇杆/技能键的落点变窄）。
	var evo_badge := Label.new()
	evo_badge.name = "EvolutionBadge"
	evo_badge.text = "开脸 %d/%d" % [_game.evolutions, EvolutionDB.FORMS.size()]
	evo_badge.custom_minimum_size = Vector2(52, 46)
	evo_badge.add_theme_font_size_override("font_size", 13)
	evo_badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	evo_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	evo_badge.add_theme_constant_override("outline_size", 3)
	evo_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evo_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	evo_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_row.add_child(evo_badge)
