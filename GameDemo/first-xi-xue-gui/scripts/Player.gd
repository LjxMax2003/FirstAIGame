extends CharacterBody2D
class_name Player

signal died
signal level_up

const BASE_SPEED := 220.0
# 相对拖拽：手指位移超过该像素才算"开始拖动"
const TOUCH_THRESHOLD := 8.0
# 方向向量达到满速所需的拖拽距离（像素），越大越接近"摇杆"手感
const TOUCH_FULL_TRAVEL := 70.0
# 水平分量超过该阈值才切换左右朝向，避免小幅抖动疯狂翻面
const FACING_LOCK := 0.45
# 纵向要比横向"明显更纵"才切背面，否则斜着走会在正/背两面之间每秒闪好几次
const FACING_VERTICAL_BIAS := 1.25
# 美术只给了正面 3 帧 + 背面 3 帧，没有侧面图：
# 上 = 背面帧；下 / 左 / 右 = 正面帧 + flip_h。
enum Facing { DOWN, UP, LEFT, RIGHT }
# 3 帧走 4 步（0→1→2→1）：直接 2→0 会看起来像丢了一帧
const WALK_SEQ: Array[int] = [0, 1, 2, 1]
# 步频基准（帧/秒），会按实际移速缩放 —— 后期速度被动点上后脚步不能还是开局节奏
const WALK_FPS := 7.5
# 横向移动时的身体倾斜（弧度，约 3°），比一味上下抖动更能读出"在冲刺"
const TILT_MAX := 0.055
const TILT_LERP := 12.0
const HURT_INVULN := 0.5
# 角色贴图 64x80，脚底在 y=78 附近；碰撞体只覆盖躯干，脚感更稳
const ART_FOOT_OFFSET := 18.0
# 靠近这些位置的点击视为"点 UI"，不当成移动手势（暂停按钮在右上角）
const PAUSE_BTN_SIZE := 56.0
const PAUSE_BTN_MARGIN := 14.0

var stats: Dictionary = {}
var level_upgrades: Dictionary = {}
var level := 1
var xp := 0
## 累计获得的经验（永不扣回）。xp 是"当前这条进度"，升级会把它扣走，
## 所以"这一局到底吃没吃过灯花"只能看这个总量 —— 引导提示与图鉴都用它。
var xp_total := 0
var xp_next := 5
var invuln_left := 0.0
var facing := 1
var facing_dir: int = Facing.DOWN
var moving := false
var elapsed := 0.0
var last_hit_time := -99.0
var hit_flash := 0.0

# ---------------------------------------------------------------- v5：回春 / 结界
## 当前护盾点数（先扣盾再扣血）。结界每 Stats.SHIELD_PERIOD 秒补到当前档位值。
var shield_hp := 0.0
var _shield_cd := 0.0
var _shield_ring: ColorRect
## 破盾闪光的剩余时间。大于 0 时环仍然可见（即使 shield_hp 已经归零），
## 否则"盾破"这一帧环就跟着消失，"碎了"这个信息根本来不及被看到。
var _shield_break := 0.0
## 护盾环直径。92 只比角色本体（64×80）大一圈，在满屏纸片里几乎看不出；
## 拉到 116 才读得出"我身上罩着一层东西"。
const SHIELD_RING_D := 116.0
const SHIELD_RING_COLOR := Color(0.58, 0.84, 1.0)
## 破盾闪光时长。0.26s ≈ 16 帧：够看清"一圈炸开"，又不会拖到下一次受击。
const SHIELD_BREAK_TIME := 0.26

var _drag_active := false
var _drag_index := -1
var _drag_origin := Vector2.ZERO
var _drag_dir := Vector2.ZERO
var _touch_pos := Vector2.ZERO
var _flash_left := 0.0
var _walk_phase := 0.0
var _walk_t := 0.0
var _tilt := 0.0
var _front_frames: Array[Texture2D] = []
var _back_frames: Array[Texture2D] = []

# ---------------------------------------------------------------- v5：主动技·震吼
## 子组件（不是全局态）：它只管"能不能放 / 放完冷却多少"，玩家管"往哪冲、无敌多久"。
var active_skill: ActiveSkill
var _dash_left := 0.0
var _dash_dir := Vector2.ZERO

@onready var art: Sprite2D = $Art
@onready var garlic_ring: GarlicRing = $GarlicRing

var shadow: Polygon2D

func _ready() -> void:
	# 注意：这里不能用 PROCESS_MODE_WHEN_PAUSED —— 那会让玩家在"未暂停"时反而不处理。
	# 玩家在暂停时必须静止（升级弹窗期间站住），所以用 INHERIT 跟随整树暂停。
	process_mode = Node.PROCESS_MODE_INHERIT
	GameManager.player = self
	xp_next = xp_for_level(1)
	garlic_ring.visible = false
	# 主动技在运行时挂上来：它没有任何 inspector 参数，
	# 单独做一个 .tscn 只会多一个需要维护的资源文件（而 uid 手写又容易把工程搞崩）。
	active_skill = ActiveSkill.new()
	active_skill.name = "ActiveSkill"
	add_child(active_skill)
	_load_frames()
	art.offset = Vector2(0.0, -ART_FOOT_OFFSET)
	# 影子在运行时生成：椭圆 + 半透明，避免为每张图另做一张阴影素材
	shadow = Shadow2D.make(self, Vector2(0.0, -1.0), 22.0, 7.0, 0.34)

## 预载 6 张角色帧（正面 3 + 背面 3）。
## 缺哪张就跳过哪张，绝不把 null 塞进数组 —— texture = null 会渲染成白块，
## 比"不同步"更容易被当成美术崩了。整组缺帧时退回场景自带的那张。
func _load_frames() -> void:
	_front_frames = _load_frame_list(Art.PLAYER_FRONT_FRAMES)
	_back_frames = _load_frame_list(Art.PLAYER_BACK_FRAMES)
	if not _front_frames.is_empty():
		art.texture = _front_frames[0]

func _load_frame_list(paths: Array[String]) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for p in paths:
		var t: Texture2D = Art.tex(p)
		if t != null:
			out.append(t)
	if out.is_empty():
		var fallback: Texture2D = art.texture
		if fallback == null:
			fallback = Art.tex(Art.PLAYER)
		out.append(fallback)
	return out

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not GameManager.started:
		velocity = Vector2.ZERO
		moving = false
		_update_anim(delta, 0.0)
		_update_feedback(delta, 0.0)
		return
	# 冲刺段：完全接管速度，忽略输入。持续时间严格由 start_dash 给的秒数决定，
	# 不留"再按一下续一秒"的口子（那就是无敌帧循环）。
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * ActiveSkill.DASH_SPEED
		move_and_slide()
		moving = true
		if _dash_dir.length_squared() > 0.0001:
			_apply_facing(_dash_dir)
		_update_anim(delta, 1.0)
		if invuln_left > 0.0:
			invuln_left -= delta
		_update_passives(delta)
		_update_feedback(delta, 1.0)
		return
	var dir := _input_dir()
	moving = dir.length_squared() > 0.0001
	velocity = dir * BASE_SPEED * float(stats.get("speed", 1.0))
	move_and_slide()
	if moving:
		_apply_facing(dir)
	_update_anim(delta, dir.length())
	if invuln_left > 0.0:
		invuln_left -= delta
	_update_passives(delta)
	_update_feedback(delta, dir.length())

## 两条 v5 生存被动。都放在玩家身上、用 delta 累积而不是计时器节点：
## 回春是连续量（每秒回血），结界是离散量（每 8s 补一个脉冲）。
##
## v7 改口径（v6 策划案 ③）：
##   结界不再是"每 12s 把盾刷满一档"，而是"每 8s 叠一层薄盾，盾池有硬上限"。
##   差别在于**短时间能挡、长时间不能无限挡** —— 刷满一档的模型里，
##   挨打和没挨打过的玩家下一脉冲拿到的盾一模一样，护盾等于永久免疫。
func _update_passives(delta: float) -> void:
	var regen: float = float(stats.get("regen", 0.0))
	if regen > 0.0 and is_alive():
		var cap: float = float(stats.get("max_hp", 1.0))
		stats["hp"] = minf(cap, float(stats.get("hp", 0.0)) + regen * delta)
	# pulse = 每个脉冲给多少；scap = 盾池能攒到多少。两者必须分开读，
	# 合成一个数就没法表达"脉冲薄、池子厚"。
	var pulse: float = float(stats.get("shield", 0.0))
	var scap: float = float(stats.get("shield_cap", 0.0))
	if pulse <= 0.0 or scap <= 0.0:
		if _shield_ring != null and _shield_ring.visible:
			_shield_ring.visible = false
		shield_hp = 0.0
		return
	_shield_cd -= delta
	if _shield_cd <= 0.0:
		_shield_cd = Stats.SHIELD_PERIOD
		# 叠加而不是刷新：这是 ③ 的全部意义所在。
		shield_hp = minf(scap, shield_hp + pulse)
	# 上限可能被"降级/改表"调小，每帧夹一次比在每处写入点夹更不容易漏
	shield_hp = minf(shield_hp, scap)
	if _shield_ring == null:
		# 一圈青光就够了：不新做贴图，用既有的 glow_aura shader
		_shield_ring = ShaderFX.add_aura(art, SHIELD_RING_D, SHIELD_RING_COLOR)
		_shield_ring.position.y += 2.0
		# glow_aura 默认是**实心光斑**（ring = 0）。贴在脚下像"人站在一盏灯上"，
		# 读不出"罩住我"；把它调成空心环、加亮一点，才是护盾该有的形状。
		var m := _shield_ring.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("ring", 0.72)
			m.set_shader_parameter("radius", 0.52)
			m.set_shader_parameter("softness", 0.42)
			m.set_shader_parameter("intensity", 1.25)
			# 呼吸幅度调小：护盾是常驻状态，不是"有东西要发生"的预警
			m.set_shader_parameter("pulse_amount", 0.10)
	# 破盾闪光优先级最高：盾已经归零也要让那一圈炸完，否则玩家只会看到"盾条突然没了"
	if _shield_break > 0.0:
		_shield_break = maxf(0.0, _shield_break - delta)
		var k: float = _shield_break / SHIELD_BREAK_TIME   # 1 → 0
		_shield_ring.visible = true
		# 向外炸开而不是收缩：收缩读作"被吸进去"，和"被打碎"是相反的意思
		_shield_ring.scale = Vector2.ONE * (1.0 + 0.55 * (1.0 - k))
		_shield_ring.modulate = Color(1.0, 1.0, 1.0, k)
	else:
		_shield_ring.scale = Vector2.ONE
		_shield_ring.modulate = Color.WHITE
		_shield_ring.visible = shield_hp > 0.0

func _input_dir() -> Vector2:
	# 键盘优先（桌面调试），否则走单指相对拖拽（移动端）
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		return dir.normalized()
	if _drag_active and _drag_dir != Vector2.ZERO:
		return _drag_dir
	return Vector2.ZERO

## 给主动技用的公开口径（它不该直接摸 _input_dir 这种私有实现）
func input_dir() -> Vector2:
	return _input_dir()

## 冲刺 + 无敌。时长由调用方给（震吼给 0.7s），这里不做任何延长。
func start_dash(dir: Vector2, seconds: float) -> void:
	if not GameManager.started:
		return
	_dash_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	_dash_left = clampf(seconds, 0.0, ActiveSkill.DASH_TIME)
	invuln_left = maxf(invuln_left, _dash_left)

## 四向朝向：只有"上"换背面帧，下 / 左 / 右共用正面帧 + flip_h。
## 斜向按主轴判定（竖向要 1.25 倍才切背面）。不这么收紧的话，斜走时
## 正面/背面会每秒互闪好几次 —— 那比"朝向不够精确"难看得多。
func _apply_facing(dir: Vector2) -> void:
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	if ay > ax * FACING_VERTICAL_BIAS:
		facing_dir = Facing.UP if dir.y < 0.0 else Facing.DOWN
	elif ax > FACING_LOCK:
		facing_dir = Facing.RIGHT if dir.x > 0.0 else Facing.LEFT
	# 左右翻面独立判定：背面帧镜像同样成立（灯笼与衣襟会跟着换边）
	if ax > FACING_LOCK:
		facing = 1 if dir.x > 0.0 else -1
	art.flip_h = facing < 0

## 走路帧：移动时按 0→1→2→1 循环，停下立即回第 1 帧。
## 步频随「输入强度 × 移速」缩放 —— 摇杆只推到 30% 时，脚步也该慢下来；
## 否则后期速度被动点满，角色会像在地面上滑行。
func _update_anim(delta: float, input_len: float) -> void:
	# 显式分支而不是三元：Array[Texture2D] 的三元会被推断成 Variant，类型化数组赋值会报错
	var frames: Array[Texture2D]
	if facing_dir == Facing.UP:
		frames = _back_frames
	else:
		frames = _front_frames
	if frames.is_empty():
		return
	if moving and input_len > 0.01:
		var spd: float = float(stats.get("speed", 1.0))
		_walk_t += delta * WALK_FPS * clampf(input_len * spd, 0.5, 1.8)
		var idx: int = WALK_SEQ[int(_walk_t) % WALK_SEQ.size()]
		art.texture = frames[mini(idx, frames.size() - 1)]
	else:
		_walk_t = 0.0
		art.texture = frames[0]

# ---------------------------------------------------------------- 输入
# 触摸统一走 InputEventScreenTouch / ScreenDrag。
# project.godot 开了 emulate_touch_from_mouse，桌面上鼠标左键也会变成 ScreenTouch，
# 所以这里不额外处理鼠标，避免同一操作被算两次。
func _unhandled_input(event: InputEvent) -> void:
	# 桌面调试：空格 = 震吼（移动端走 HUD 的按钮，那条路不经过这里）
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_SPACE:
			if active_skill != null:
				active_skill.try_cast()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# 只认第一根手指，多点触摸时忽略后来者（避免方向跳变）
			if _drag_active:
				return
			if _is_on_ui(touch.position):
				return
			_drag_active = true
			_drag_index = touch.index
			_drag_origin = touch.position
			_touch_pos = touch.position
			_drag_dir = Vector2.ZERO
		elif touch.index == _drag_index:
			_release_drag()
	elif event is InputEventScreenDrag and _drag_active:
		var drag := event as InputEventScreenDrag
		if drag.index != _drag_index:
			return
		_touch_pos = drag.position
		# 手指拖出太远时把锚点跟着走，避免"回不去"的粘滞感
		var offset: Vector2 = drag.position - _drag_origin
		if offset.length() > TOUCH_FULL_TRAVEL * 1.6:
			_drag_origin = drag.position - offset.normalized() * TOUCH_FULL_TRAVEL * 1.6
			offset = drag.position - _drag_origin
		if offset.length() > TOUCH_THRESHOLD:
			_drag_dir = (offset / TOUCH_FULL_TRAVEL).limit_length(1.0)

## 手指落在暂停按钮区域时不算移动手势。
## 注意：headless / 未渲染时 get_visible_rect().size 为 0，此时不能做任何过滤，
## 否则 (0-threshold, 0) 的矩形会吃掉全部触摸 —— 测试里会表现为"拖拽完全失灵"。
func _is_on_ui(screen_pos: Vector2) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x < PAUSE_BTN_SIZE * 2.0 or vp.y < PAUSE_BTN_SIZE * 2.0:
		return false
	var btn := Rect2(
		Vector2(vp.x - PAUSE_BTN_SIZE - PAUSE_BTN_MARGIN, PAUSE_BTN_MARGIN),
		Vector2(PAUSE_BTN_SIZE, PAUSE_BTN_SIZE)
	)
	return btn.has_point(screen_pos)

func _release_drag() -> void:
	_drag_active = false
	_drag_index = -1
	_drag_dir = Vector2.ZERO

func drag_origin() -> Vector2:
	return _drag_origin

func touch_offset() -> Vector2:
	if not _drag_active:
		return Vector2.ZERO
	return _touch_pos - _drag_origin

func is_dragging() -> bool:
	return _drag_active

# ---------------------------------------------------------------- 生命
## 上一次真的掉了血的伤害来源标签（v7 死因归纳用）：&"boss" / &"elite" / &"mob"，空 = 未知。
##
## 【为什么记"最后一次掉血"而不是"致命那一击"】
## 死亡那一帧必然伴随掉血（hp 从正变负），所以"最后一次掉血"就等于"致命那一击"，
## 不需要为它额外传一个 is_lethal 标记。而在屏蔽罩（结界）吃掉伤害时，
## 这里保持不动 —— 玩家没掉血，也就谈不上"被它打死"。
var last_hit_source: StringName = &""

func take_damage(amount: float, source: StringName = &"") -> void:
	if invuln_left > 0.0 or not GameManager.started:
		return
	# 被盾吃掉的伤害也要有声音：玩家看不到血条变化，只剩"挨了一下"这一个信息。
	# 盾吸收时压低 6 dB —— 听感是"隔着一层东西被撞"，而不是直接受伤。
	Audio.play_sfx("hurt", -6.0 if shield_hp >= amount else 0.0)
	# 结界先吃：盾没破之前血量一点不掉。无敌帧照常消耗 ——
	# 否则贴身时每个物理帧都会来一次结算，一层 105 的盾会在 0.1 秒内被磨光。
	var left: float = maxf(amount, 0.0)
	if shield_hp > 0.0:
		var absorbed: float = minf(shield_hp, left)
		shield_hp -= absorbed
		left -= absorbed
		if shield_hp <= 0.0:
			shield_hp = 0.0
			# 破盾的瞬间给一次更强的闪，读得出"盾没了，接下来要掉血"
			_flash_left = 0.22
			# 光环炸开一圈（尺寸/透明度由 _update_passives 每帧推进）
			_shield_break = SHIELD_BREAK_TIME
	stats["hp"] = float(stats["hp"]) - left
	invuln_left = HURT_INVULN
	if left > 0.0:
		_flash_left = 0.14
		last_hit_source = source
	hit_flash = 1.0
	last_hit_time = elapsed
	if float(stats["hp"]) <= 0.0:
		# 不要把 hp 强行压到 0：那会让"死亡 → 直接重开场景"这类复用路径一开始就是死血。
		# 死亡状态由 GameManager.started 表达，血量留成负数即可（UI 会 clamp）。
		GameManager.started = false
		velocity = Vector2.ZERO
		moving = false
		_release_drag()
		died.emit()

func is_alive() -> bool:
	return GameManager.started and float(stats.get("hp", 0.0)) > 0.0

func _update_feedback(delta: float, dir_len: float) -> void:
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta * 3.0)

	# 受击闪白 / 无敌帧闪烁（只改 modulate，不改贴图本身）
	if _flash_left > 0.0:
		_flash_left -= delta
		var k: float = 0.3 + 0.7 * absf(sin(_flash_left * 60.0))
		art.modulate = Color(1.0, k, k)
		if _flash_left <= 0.0:
			art.modulate = Color.WHITE
	elif invuln_left > 0.0:
		art.modulate = Color(1.0, 0.78, 0.78, 0.6 + 0.4 * absf(sin(invuln_left * 26.0)))
	else:
		art.modulate = Color.WHITE

	# 起伏 + 倾斜：帧动画负责"迈步"，这两项负责"重心"。
	# 起伏从 2.5px 收到 1.6px（与敌人同量级）—— 和逐帧动画叠在一起时，
	# 原来那个幅度看起来像在原地蹦，不像走路。
	if moving and dir_len > 0.01:
		_walk_phase += delta * 11.0
		art.position.y = -absf(sin(_walk_phase)) * 1.6
	else:
		_walk_phase = 0.0
		art.position.y = lerpf(art.position.y, 0.0, clampf(delta * 14.0, 0.0, 1.0))

	# 横向速度 → 身体倾斜（约 3°），停下回正。
	# 拖拽/摇杆玩家最容易读到的"我这一下按对了"就是这一下侧倾。
	var target_tilt := 0.0
	if moving:
		var top: float = BASE_SPEED * maxf(0.01, float(stats.get("speed", 1.0)))
		target_tilt = clampf(velocity.x / top, -1.0, 1.0) * TILT_MAX
	_tilt = lerpf(_tilt, target_tilt, clampf(delta * TILT_LERP, 0.0, 1.0))
	art.rotation = _tilt

	# 光环范围：**只跟花灯（halo）**。
	#
	# ⚠️ 这里曾经写成 `has_weapon("halo") or has_weapon("gong")`、半径取两者较大值，
	#    理由是"v5 铜锣也是光环型，画大的那个才不骗玩家"。
	#    实测下来这是个错误：铜锣是**每 1.8s 敲一下**的一次性爆发，却因此得到了一圈
	#    常驻的大圆环 + 边带 + 水波纹 —— 和花灯的领域圈长得一模一样，玩家彻底分不出
	#    哪个技能在打自己；而且常驻圈在暗示"一直有伤害"，与 1.8s 的节奏直接矛盾。
	#    现在铜锣的范围只由它自己的冲击波表达（fire_gong 里的 shockwave，半径同判定）。
	var weps: WeaponManager = GameManager.weapons
	var show_ring: bool = weps != null and GameManager.started and weps.has_weapon("halo")
	garlic_ring.visible = show_ring
	if show_ring:
		garlic_ring.set_radius(weps.halo_radius())
		# v6 满级觉醒：走马灯流光。等级从这里推进去而不是让 GarlicRing 自己去问
		# WeaponManager —— 圈是玩家的子节点，它不该知道全局武器表在哪。
		garlic_ring.set_awakened(weps.weapon_level("halo") >= WeaponDB.MAX_LEVEL)

func hp_ratio() -> float:
	var m: float = float(stats.get("max_hp", 1.0))
	if m <= 0.0:
		return 0.0
	return clampf(float(stats.get("hp", 0.0)) / m, 0.0, 1.0)

# ---------------------------------------------------------------- 经验
func gain_xp(amount: int) -> void:
	if not GameManager.started:
		return
	xp += amount
	xp_total += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = xp_for_level(level)
		level_up.emit()

func xp_for_level(level_at: int) -> int:
	return 5 + level_at * level_at
