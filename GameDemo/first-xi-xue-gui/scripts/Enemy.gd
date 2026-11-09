extends Node2D
class_name Enemy

signal died(pos: Vector2, xp: int, kind: String)
## 一次"值得冒一个数字"的伤害结算。由 EnemyPool 汇总后转给 Game → DamageNumbers。
##
## 注意它**不是每一下 take_damage 都 emit**：这里做了 0.22s 的聚合（见 DMG_POP_INTERVAL）。
## 满级 9 把武器打一只怪，一秒能结算十几次；逐次冒数字的后果是同屏 100 只时
## 每秒上百条飘字互相顶掉，屏幕糊成一片，反而没有一个数字读得出来。
signal damage_dealt(pos: Vector2, amount: float, big: bool)

const HIT_COLOR := Color(1.0, 0.78, 0.70)
## 减速染色（目前只有花灯会挂减速）。语义：**被灯火罩住了**。
##
## 为什么必须有这一层：花灯的伤害逻辑是"减速 + 对已减速的目标 +20% 伤"，
## 而不是纯伤害。在加上这个染色之前，"慢下来"这件事在画面上**零反馈** ——
## 玩家既看不出自己把影子留住了，也看不出为什么同一个技能一下 9.2、一下 11
## （那 20% 是白给在数据里的）。特效不表达机制，机制就等于不存在。
##
## 为什么用 modulate 而不是 shader：同屏最多 200 只小怪，给每只挂独立材质
## 会让它们全部掉出合批（v6_fx_art_plan.md §1.3 的红线）。modulate 不破批。
##
## 为什么选黄而不是暖白：受击闪白 HIT_COLOR 是 (1.0, 0.78, 0.70) 的暖白，
## 用同一色系会让"刚被打"和"正在变慢"糊成一种状态。这里把蓝通道压到 0.42，
## 偏琥珀黄，和闪白是两种色相，余光也能分开。
const SLOW_TINT := Color(1.0, 0.86, 0.42)
## 受击染色时长。原先是 0.09（≈5 帧），在满屏纸片里几乎看不出"这一下打中了"。
## 0.12 ≈ 7 帧，是"读得出来"和"不黏连"之间的那个值；
## 再长（0.18+）连续受击时会糊成常态红，染色就失去信号意义了。
const FLASH_TIME := 0.12
# 贴到玩家身上就不再继续挤（避免把玩家顶着走）
const STOP_DIST := 10.0
# 血量阈值：超过这个比例时血条不显示，避免刷屏
const HP_BAR_SHOW_MAX := 1.0
## 尸体最短占位时长（v5 起只做参数量级参考：真正的回收时长由下面的溶解时长决定）。
## 保留这个常量是因为冒烟测试用它做"多久之后尸体一定被回收"的时间下界。
const CORPSE_TIME := 0.20
## 精英 / Boss 的化墨时长。必须 >= 溶解动画长度，否则尸体会在"溶到一半"时被回收，
## 表现是敌人凭空消失而不是化开（池回收是瞬间的，没有过渡）。
const ELITE_DISSOLVE := 0.45
## 小怪化墨时长。比精英短 1/3：小怪是"被扫掉的"，不该和精英一样抢注意力。
## 但也不能用原来的 0.20（硬淡出）—— 那个时长里溶解只走到一半就被回收，
## 看起来像"闪一下就没了"，比不做溶解更糟。
const MOB_DISSOLVE := 0.30
## 伤害飘字的聚合窗口。同一个敌人在 0.22s 内被打的所有次数合成一个数字，
## 第一下立即冒（手感不能等），之后按窗口合并。
const DMG_POP_INTERVAL := 0.22

# ---------------------------------------------------------------- v9 受击位移（A2）
## 被打中时贴图沿来向偏移的像素。4px → <0.2px 约 16 帧（267ms）。
## 为什么是"位移"不是"非等比缩放"：位移不写 art.scale，不和 setup() 的出场缩放、
## _die() 的胀大抢同一个字段；且零破批成本（合批看的是 texture/material，不看 position）。
## 为什么只有小怪这段：精英/Boss 同屏 <10，它们用 ShaderFX.flash 已经足够，
## 再叠位移会让"大家伙"看起来轻浮。
const HIT_PUNCH_PX := 4.0
## 衰减系数必须乘性：天然"先快后慢"、末段一步归位。
## 线性减速会有一段匀速滑动，读起来像"被拖着走"而不是"被弹开又回来"。
const HIT_PUNCH_DECAY := 0.82
## 同一只敌人的命中音去重窗口。取 0.055 = 与 PresentationFX.QUIET_WINDOW 同量级：
## 两个窗口对齐时，"能听见的这一声"和"能顿的这一帧"落在同一个瞬间，
## 玩家的多通道反馈才是叠在一起的，而不是错开成两声两晃。
## 低于 0.04 就能听见"同一刀的多段伤害"在连响；高于 0.08 会吞掉二次命中的确认。
const HIT_SFX_GAP := 0.055

# ---------------------------------------------------------------- v9 击杀标点（A3）
## 溶解过程中"完全不透明"的那一段占比。前 1/3 不透明 → 玩家先看到形状炸开（胀），
## 再看到散掉（溶），因果顺序才对：是"被打碎"而不是"被擦掉"。
## 只改 alpha 曲线的形状，不改 MOB_DISSOLVE 的总时长（HudFxGap 用 [0.21,0.40] 锁死了它）。
const DEATH_HOLD_FRAC := 0.3333
## 先胀后塌。原 1.12 在 0.30s 的溶解里读不出"胀"，1.20 才有那一帧冲击。
## 上限取 1.28：再大就像"充气"而不是"被打爆"。
const DEATH_SCALE_UP := 1.20
const DEATH_SCALE_UP_TIME := 0.08
const DEATH_SCALE_DOWN := 0.82
## 击杀瞬间的结束白。刻意偏冷（B=1.0），与受击暖白 HIT_COLOR(1.0,0.78,0.70) 拉开色相 ——
## 否则玩家会把"打死了"和"打中了"读成同一件事。
const DEATH_COLOR := Color(0.0, 0.95, 1.0, 1.0)

var hp := 1.0
var max_hp := 1.0
var speed := 70.0
## 接触伤害由 Game 下发（params.json enemy.contact_damage = 6.0 × 敌人倍率）
var contact_damage := WaveTable.CONTACT_DAMAGE
var touch_radius := 16.0
var xp_value := 1
var kind := "cup"
var is_elite := false
## Boss：死神贴图 80×112，是全场唯一"要打的大家伙"，单独标记便于统计与免死判定
var is_boss := false
var size := 48.0
var alive := false
var grid_key := Vector2i(1 << 30, 1 << 30)

# ---------------------------------------------------------------- v5：浆壳 / 护盾
## 结壳兵：血 ×1.40、吃 AoE ×0.75、吃单点 ×1.0、吃墨斗 ×1.80。
## 只在 8–20min 的时间窗内上壳（由 Game 按 WaveTable.shell_w 决定），
## 所以它是"中期墙"，不是全程常驻的减伤。
var shelled := false
## 三帧行走（T10）。只有杂兵非结壳时才有内容；精英 / Boss / 结壳兵是空数组，
## 一律走原来的"轻微摇摆 + 上下浮"。
## ⚠️ 存的是 Texture2D 而不是路径：每 1/7 秒 load 一次路径，300 只就是每秒 2100 次
##    资源查找，比换帧本身贵两个数量级。
var _frames: Array[Texture2D] = []
var _frame_i := 0
var _frame_t := 0.0

var _hit_left := 0.0
## 飘字聚合：尚未结算出去的伤害，以及距离下次允许冒字还剩多久。
var _dmg_acc := 0.0
var _dmg_pop_left := 0.0
## 死亡后的淡出计时。到 0 时 EnemyPool 把这具"尸体"收回池子。
## 不能当场回收：死亡表现是"放大 + 淡出"，立刻 recycle 会让玩家看不到击杀反馈。
var _corpse_left := 0.0
## 光环减速：剩余时间 + 当前减速比例（0.15 = 慢 15%）
var _slow_left := 0.0
var _slow_pct := 0.0
## 当前贴图是否处于减速染色。只在**状态翻转**时改 modulate，不是每帧重设：
## 200 只小怪每帧各赋一次 modulate 是纯开销，而状态一秒只翻两次。
var _slow_tinted := false
var _walk := 0.0
var _pool_index := 0
var _player: Player = null
var _spawn_scale := 1.0
var _spawn_left := 0.0

# ---------------------------------------------------------------- v9 表现层状态
## 受击位移的当前值（像素向量）与方向。逐帧乘性衰减到 0。
## 之所以放在实体里而不是 PresentationFX：单例不能持有池化节点的引用（会悬空）。
var _punch := Vector2.ZERO
## 行走起伏的当前值（只影响贴图 y）。和 _punch 一起**合成**后写入 art.position，
## 绝不往 art.position 上累加 —— 累加会在贴图上留下永久漂移（见 _process 末尾）。
var _bob_y := 0.0
## 击杀"先胀后塌"的进度计时。_die() 起算，随 _process 推进。
var _die_t := 0.0
## 击杀后是否正在走"胀—塌"曲线。走完就交给溶解，不再改 scale。
var _dying := false
## 溶解期间是否已经调用过一次 dissolve_out（避免重复挂材质）。
var _dissolving := false
## 命中音去重窗口的剩余时间。每秒递减，见 _take_hit_sfx_token()。
var _hit_sfx_cd := 0.0

@onready var art: Sprite2D = $Art
@onready var hp_bar: HpBar = $HpBar

var shadow: Polygon2D

@onready var _pool: EnemyPool = get_parent() as EnemyPool

func pool_index() -> int:
	return _pool_index

func setup(pool_index: int, spawn_pos: Vector2, p_hp: float, p_speed: float, p_xp: int, p_kind: String, p_elite: bool, p_damage: float = WaveTable.CONTACT_DAMAGE, p_boss: bool = false, p_shelled: bool = false) -> void:
	_pool_index = pool_index
	global_position = spawn_pos
	# 结壳是**血量侧**的加成：先乘血，再走后面的 UI/血条，避免"血条满格但实际 1.4 倍"
	shelled = p_shelled and not p_elite and not p_boss
	max_hp = maxf(p_hp, 1.0) * (WaveTable.SHELL_HP_MULT if shelled else 1.0)
	hp = max_hp
	speed = p_speed
	xp_value = p_xp
	kind = p_kind
	is_elite = p_elite
	is_boss = p_boss
	contact_damage = p_damage

	# 按种类换贴图。美术已给出 48px 基础敌人 / 96px 精英 / 80x112 Boss，直接 1:1 用。
	var path: String = _art_for(p_kind, p_elite)
	# 结壳直接换成 _shell 变体图（T10）：
	# 叠加一层 shell_crust 的问题是把本体压成一片暗色，"这只怪长什么样"直接消失，
	# 玩家分不出"结壳的纸屑"和"结壳的纸鸢" —— 而这两种的解法完全不同（一个该换墨斗）。
	if shelled and Art.ENEMY_SHELL.has(p_kind):
		path = String(Art.ENEMY_SHELL[p_kind])
	art.texture = Art.tex(path)
	# 复用前先清掉上一次的特效状态（tween + meta）。不清的话，上一局被打断的溶解会
	# 接着在这一次播，新怪一出场就是半透明的。
	ShaderFX.clear(art)
	# 快速怪加青色描边：48px 下颜色先于细节被看见，这是"这只会不会咬到你"的唯一预警。
	# 只在 fast 上开，精英/Boss 一律置 null——描边会压低血条与受击闪色的层次。
	# 材质共用一份（不是每次 new）：池化后外敌同屏上百只，逐只 new 是纯浪费。
	art.material = _fast_outline_mat() if (p_kind == "fast" and not p_elite) else null
	var tex_size: Vector2 = art.texture.get_size()
	size = maxf(tex_size.x, tex_size.y)
	# Boss 的碰撞半径由 params.json 钉死 34（≈身体宽度一半），
	# 不能套用 size*0.36 —— 死神贴图 112 高会算出 40，比视觉还宽。
	touch_radius = WaveTable.BOSS_CONTACT_R if p_boss else size * 0.36
	# 脚底对齐：贴图底部留白约 4px，抬高让影子压在脚下
	art.offset = Vector2(0.0, -tex_size.y * 0.5 + 4.0)
	if shadow == null:
		shadow = Shadow2D.make(self, Vector2(0.0, 0.0), size * 0.34, size * 0.13, 0.28)
	else:
		Shadow2D.resize(shadow, size * 0.34, size * 0.13)
	hp_bar.setup(size, is_elite or p_boss)
	# Boss 血条常显（玩家必须随时知道自己还差多少打完）；普通敌人只在受伤后出现
	hp_bar.visible = is_elite or p_boss
	_setup_frames(p_kind, p_elite, p_boss)

	alive = true
	_hit_left = 0.0
	_dmg_acc = 0.0
	_dmg_pop_left = 0.0
	_corpse_left = 0.0
	_slow_left = 0.0
	_slow_pct = 0.0; _root_left = 0.0; _root_immune = 0.0; _root_tinted = false
	_slow_tinted = false
	_walk = randf() * TAU
	modulate = Color.WHITE
	art.modulate = Color.WHITE
	art.rotation = 0.0
	art.position = Vector2.ZERO
	art.flip_h = false
	# v9：补上 art.scale 的复位。此前这里漏了这一项 —— 上一具尸体的溶解胀大（1.12）
	# 会带进下一次复用，表现为"复活的怪比别的怪大一圈"。池化敌人必须把所有
	# 被表现层改过的 art 属性全部还原，这一条是 A2/A3 能安全落地的前提。
	art.scale = Vector2.ONE
	_punch = Vector2.ZERO
	_bob_y = 0.0
	_die_t = 0.0
	_dying = false
	_dissolving = false
	_hit_sfx_cd = 0.0
	_spawn_scale = 0.01
	_spawn_left = 0.18
	scale = Vector2.ONE * _spawn_scale
	_player = GameManager.player as Player
	if p_elite or p_boss:
		# 精英 / Boss 改用噪声溶解"从墨里渗出来"，替掉缩放弹入。
		# 两个同时上会互相打架：缩放把整只敌人（含血条）从 0 拉到 1，
		# 溶解又同时按噪声掏空它，看上去像画面在抖而不是"现身"。
		_spawn_scale = 1.0
		_spawn_left = 0.0
		scale = Vector2.ONE
		ShaderFX.spawn_in(art, 0.40)
	# 关键：deactivate() 里 set_process(false) 过，回收时必须重新打开，
	# 否则第二局/复用后的敌人会完全不移动、不结算接触伤害（对外表现＝"卡住不动"）。
	set_process(true)
	if _pool != null:
		_pool.report(self)

## 快速怪的描边材质：全工程共用一份。
## 每只敌人 new 一个 ShaderMaterial 只会白白吃掉同屏上百次分配，
## 而描边参数（颜色/宽度）对全场统一，没有"每只单独调"的需求。
static var _fast_mat: ShaderMaterial = null

static func _fast_outline_mat() -> ShaderMaterial:
	if _fast_mat == null:
		_fast_mat = ShaderMaterial.new()
		_fast_mat.shader = preload("res://assets/shaders/outline.gdshader")
	return _fast_mat

## 三帧行走的贴图组。只有"杂兵 + 非结壳"才装帧：
##   · 精英 / Boss 同屏个位数，帧动画是纯收益，但美术没给帧，不能自己造；
##   · 结壳兵在语义上是"沉重的壳"，三帧走起来反而像在跑 —— 单帧 + 壳本身更像墙。
## 相位随机错开：全屏敌人同拍换帧会读成一整块画面在闪，而不是"一群人在走"。
func _setup_frames(p_kind: String, p_elite: bool, p_boss: bool) -> void:
	_frames.clear()
	_frame_i = 0
	if p_elite or p_boss or shelled or not Art.ENEMY_FRAMES.has(p_kind):
		return
	for fp in Art.ENEMY_FRAMES[p_kind]:
		var t: Texture2D = Art.tex(String(fp))
		if t != null:
			_frames.append(t)
	_frame_t = randf() / Art.ENEMY_FRAME_FPS

## 按 7fps 推进帧。用"累减 + 积压归零"而不是 `int(total * fps) % 3`：
## 60fps 下每帧 16.7ms、帧长 142.9ms，两者不整除，累加的 float 会慢慢漂；
## 而掉帧（切后台 / 一次性 GC）时若让欠账继续累积，复活回来会看到敌人"跳帧快进"。
func _tick_frames(delta: float) -> void:
	_frame_t += delta
	var step: float = 1.0 / Art.ENEMY_FRAME_FPS
	if _frame_t < step:
		return
	_frame_t -= step
	if _frame_t > step:
		_frame_t = 0.0
	_frame_i = (_frame_i + 1) % _frames.size()
	art.texture = _frames[_frame_i]

static func _art_for(k: String, elite: bool) -> String:
	# v5 三种小 Boss：走 elite 通道（有血条、掉宝箱），贴图单独给。
	# 必须先判 kind：它们在数据上 is_elite=true，否则会被下面的精英分支吃掉贴图。
	match k:
		"drum":
			return Art.BOSS_DRUM
		"nuo":
			return Art.BOSS_NUO
		"lantern":
			return Art.BOSS_LANTERN
	# 三张精英素材各司其职：Boss 残面(80x112) / 傩面精英(96) / 墨渍精英(96)
	if elite:
		if k == "reaper":
			return Art.REAPER
		if k == "red":
			return Art.ELITE_RED
		return Art.ELITE_BOX
	match k:
		"bag":
			return Art.ENEMY_BAG
		"fast":
			return Art.ENEMY_CUP_FAST
		_:
			return Art.ENEMY_CUP

func _process(delta: float) -> void:
	if not alive or not GameManager.started:
		return
	if _player == null or not is_instance_valid(_player):
		_player = GameManager.player as Player
		if _player == null:
			return

	# 出生缩放：从 0 弹到 1，避免大量敌人"凭空出现"的突兀感
	if _spawn_left > 0.0:
		_spawn_left -= delta
		var t: float = clampf(1.0 - _spawn_left / 0.18, 0.0, 1.0)
		_spawn_scale = 0.6 + 0.4 * t + 0.18 * sin(t * PI)
		scale = Vector2.ONE * _spawn_scale
		if _spawn_left <= 0.0:
			scale = Vector2.ONE

	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()
	var move := Vector2.ZERO
	# 减速只压推进速度，不阻断接触判定 —— 被围住照样掉血（NUM_DESIGN §4.1）
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_pct = 0.0
	var move_speed: float = speed * (1.0 - clampf(_slow_pct, 0.0, 0.85))
	if dist > STOP_DIST:
		# 拥挤抑制：贴身圈一层已经挤满时不再往前顶。
		# 没有这一条，贴脸的敌人会在 STOP_DIST 那圈互相抵消推力，形成一层厚壳把玩家包死 ——
		# 外面刷再多也进不来，表现为"同屏数量卡在 150 上不去"，且视觉上是一坨重叠的怪。
		# 让前排停住、后排溢到外圈，同屏数量才能随刷怪率真正涨起来。
		var passive: float = 1.0
		if _pool != null and dist < STOP_DIST * 12.0:
			passive = 1.0 - _pool.crowding(self, size * 0.5) * 0.85
		move = to_player / maxf(dist, 0.001) * move_speed * passive
	# 轻量分离：只和网格邻居推开，避免叠成一坨
	if _pool != null:
		move += _pool.separation(self, size * 0.5) * move_speed * 0.65

	_advance(move, delta)
	if _pool != null:
		_pool.report(self)

	# 行走：有帧的走帧，没帧的用"轻微摇摆+上下浮"补足动感。
	# 两者不同时上 —— 三帧本身已经带位移暗示，再叠旋转会读成"在打颤"。
	if _frames.is_empty():
		_walk += delta * (5.0 + speed * 0.05)
		art.rotation = sin(_walk) * 0.07
		_bob_y = -absf(sin(_walk * 1.0)) * 1.6
	else:
		_tick_frames(delta)
	# 受击位移与行走起伏**合成后一次性赋值**，绝不在 art.position 上累加。
	# 旧写法 `art.position += _punch` 每帧叠加、衰减到 0 时也不减回去：
	# 单次受击永久残留 HIT_PUNCH_PX / (1 - HIT_PUNCH_DECAY) ≈ 22px 的偏移，
	# 池化敌人表现为"贴图与判定/影子错位"，而且多次受击会单向越漂越远。
	art.position = Vector2(_punch.x, _bob_y + _punch.y)
	if _punch != Vector2.ZERO:
		_punch *= pow(HIT_PUNCH_DECAY, delta * 60.0)
		if _punch.length() < 0.2:
			_punch = Vector2.ZERO

	if _hit_left > 0.0:
		_hit_left -= delta
		if _hit_left <= 0.0:
			# 闪白结束要回到**当前状态**的颜色，不是无条件回白：
			# 否则一只正在减速的怪被打一下就永久丢失染色（它不会再有状态翻转）。
			art.modulate = SLOW_TINT if _slow_left > 0.0 else Color.WHITE
	_sync_slow_tint()
	# 命中音去重窗口。和 _hit_left 分开走：闪白是 0.12s 的视觉，去重是 0.055s 的听觉，
	# 复用同一个字段会让"闪白还在但可以再响一声"变成不可能。
	if _hit_sfx_cd > 0.0:
		_hit_sfx_cd -= delta

	# 飘字聚合窗口收口：窗口内没再挨打，就把这期间累计的伤害一次冒出去
	if _dmg_pop_left > 0.0:
		_dmg_pop_left -= delta
		if _dmg_pop_left <= 0.0:
			_flush_damage(false)

	# 接触伤害：纯距离判定（移动端不走物理引擎）
	if dist < touch_radius + 16.0:
		_player.take_damage(contact_damage * float(GameManager.stats.get("might", 1.0)), _contact_source())

## 接触伤害的来源标签，只供结算界面归纳死因，不参与任何数值分支。
## 三档是玩家真能分辨的差别：一只大家伙按住 / 精英堵死 / 杂兵围死。
func _contact_source() -> StringName:
	if is_boss:
		return &"boss"
	if is_elite:
		return &"elite"
	return &"mob"

## 结壳兵的受击倍率。
## 抽成 typed 函数而不是在各处散写 if：倍率有三个来源（AoE 减免 / 墨斗破壳 / 铜锣微破壳），
## 散写一次就会漏一次，而且漏了不会报错，只会让"官方解"悄悄失效。
## weapon_type 传武器 id（&"inkline" 这种 StringName），空 = 未知来源（接触/震吼等，不吃减免）。
func damage_multiplier(weapon_type: StringName) -> float:
	if not shelled or weapon_type == &"":
		return 1.0
	var wid: String = String(weapon_type)
	var d: Dictionary = WeaponDB.def(wid)
	# ① 破壳专用倍率（墨斗 1.80）—— 有就**替换**减免，而不是叠在 0.75 上
	var bonus: float = float(d.get("shell_bonus", 0.0))
	if bonus > 0.0:
		return bonus
	# ② 通用 AoE 减免 0.75，带 amp 的武器（铜锣 0.12）在此基础上回收一点
	if WeaponDB.dmg_kind(wid) == "aoe":
		return WaveTable.SHELL_AOE_TAKEN + float(d.get("amp", 0.0))
	# ③ 单点不吃减免
	return 1.0

## 技能命中用：判定半径略小于视觉
func hit_radius() -> float:
	return size * 0.36

## 受击位移（A2）。dir 由攻击方给出（归一化方向），幅度是本类自己的常量 ——
## 让武器侧决定"打歪多少"会把表现耦合进攻武器数据。
## 位移不写 art.scale / 不挂材质，所以对合批零成本。
func hit_punch(dir: Vector2) -> void:
	if not alive or dir == Vector2.ZERO:
		return
	_punch = dir.normalized() * HIT_PUNCH_PX

## 命中音的去重：同一个敌人在极短时间内被打多次只发一次声。
## 不靠 Audio 的 gap 单独挡（那是全局节流，会让"不同敌人"也被吞），
## 敌人自己的窗口才能保证"每只挨第一下都有一声"。
## 用独立标记而不是比较 _hit_left：后者在 take_damage 里刚被赋成 FLASH_TIME，
## 拿它做判断会恒为真，等于每次命中都发声（实测直接把声部打满）。
func _take_hit_sfx_token() -> bool:
	if _hit_sfx_cd > 0.0:
		return false
	_hit_sfx_cd = HIT_SFX_GAP
	return true

## 击退：amount 是"身体尺寸的比例"（0.15 = 后退 15% 身位），不是像素 ——
## 这样 48px 杂兵和 96px 精英被撞开的手感是一致的。
func knock_back(dir: Vector2, amount: float) -> void:
	if not alive or amount <= 0.0 or dir == Vector2.ZERO:
		return
	global_position += dir.normalized() * amount * size

## 护盾（结界）是**玩家**的属性，不挂在敌人身上 —— 敌人只负责按武器类型给出倍率。

## 光环减速：多次命中时取更强者，不叠加（避免叠满被动把敌人钉死）
func apply_slow(pct: float, duration: float) -> void:
	if not alive:
		return
	_slow_pct = maxf(_slow_pct, pct)
	_slow_left = maxf(_slow_left, duration)

func is_slowed() -> bool:
	return _slow_left > 0.0

## 减速状态的可见化：只在翻转沿改一次 modulate（见 SLOW_TINT 的三段注释）。
## 受击闪白期间不抢：闪白是 0.12s 的"这一下打中了"，优先级高于"它现在是慢的"。
func _sync_slow_tint() -> void:
	var want: bool = _slow_left > 0.0
	if want == _slow_tinted:
		return
	_slow_tinted = want
	if _hit_left <= 0.0:
		art.modulate = SLOW_TINT if want else Color.WHITE

## weapon_type = 武器 id。结壳兵按它决定倍率（AoE 0.75 / 墨斗 1.80 / 铜锣 0.87 / 单点 1.0）。
## 不传 = 未知来源（震吼、环境伤害），按 1.0 结算。
func take_damage(dmg: float, weapon_type: StringName = &"") -> void:
	if not alive:
		return
	var amount: float = dmg * damage_multiplier(weapon_type)
	if amount <= 0.0:
		return
	hp -= amount
	_hit_left = FLASH_TIME
	# v9 A1：命中的"时间标点"。只有这里知道"打中了什么"，武器侧不知道，
	# 所以顿帧请求必须由 Enemy 发 —— 放 WeaponManager 会变成"每一发子弹都顿"。
	# 三重门（静默窗/占空比/取最大档）在 PresentationFX 内部处理，这里无脑请求即可。
	PresentationFX.request_hitstop(PresentationFX.TIER_HIT)
	# v9 A4：命中音按伤害类型分锐/钝。此前 9 把武器共用"击杀音"，
	# 打中时一声不响 —— 这是四条反馈通道里唯一完全空掉的一条。
	if not _take_hit_sfx_token():
		Audio.play_sfx("hit_aoe" if WeaponDB.dmg_kind(weapon_type) == "aoe" else "hit_single")
	# 只闪贴图本体：modulate 是整个节点的，会连血条一起染红
	if is_elite or is_boss:
		# 精英 / Boss 同屏 < 10，值这一次材质切换：整块压成暖白，比 modulate 的乘法提亮
		# 更容易在深色贴图上被看见（modulate 是乘的，暗部乘什么都还是暗）。
		ShaderFX.flash(art, ShaderFX.HIT_COLOR, FLASH_TIME)
	else:
		# 小怪同屏 50~200：挂独立材质会让它们掉出合批，等于每只多一次 draw call。
		# 48px 的纸片在满屏时本来就看不清那一帧闪光，不值得。
		art.modulate = HIT_COLOR
	if not hp_bar.visible and hp < max_hp * HP_BAR_SHOW_MAX:
		hp_bar.visible = true
	hp_bar.set_ratio(hp / max_hp)
	# 飘字：窗口一开始就冒（第一下不能等 0.22s，那会让打击感整个迟到），
	# 窗口内的后续命中只累加。
	# ⚠️ 顺序不能反：必须先判 hp <= 0 再判窗口。反过来的话，致命一击会先用
	#    普通档把数字冒掉、把 _dmg_acc 清零，_die() 里的强调档就什么都结不到了 ——
	#    表现是"打死了却从来不出红字"，而且不报错。
	_dmg_acc += amount
	if hp <= 0.0:
		_die()
		return
	if _dmg_pop_left <= 0.0:
		_flush_damage(false)

## 把累计伤害结成一个飘字事件。
## big = true 只用于击杀那一击 —— 本作没有暴击系统，就没有"暴击"这个概念可给。
## 硬造一个 randf() < 0.1 的假暴击会让玩家去找根本不存在的暴击来源，
## 而"这一下打死了"是他确实要看的信息，所以强调档绑定在击杀上。
func _flush_damage(big: bool) -> void:
	if _dmg_acc <= 0.0:
		return
	damage_dealt.emit(global_position, _dmg_acc, big)
	_dmg_acc = 0.0
	_dmg_pop_left = 0.0 if big else DMG_POP_INTERVAL

func _die() -> void:
	if not alive:
		return
	alive = false
	set_process(false)
	if _pool != null:
		_pool.forget(self)
	# 击杀这一击：把窗口里还没结出去的伤害并进来，一次冒个大的（朱红）。
	# 放在 died 之前，是为了让"数字"和"掉落"在同一帧起步 —— 数字先出、宝石后出，
	# 玩家的因果读法才是"我打死了它，所以掉了东西"。
	_flush_damage(true)
	# v9 A3：击杀标点。三档里最重的一档，但也必须过 K=8 的预算门 ——
	# 泼墨/铜铃一次扫掉 20 只时，如果 20 只都顿一次，画面会冻住（见 13-feel-tuning §3）。
	# 门在里面按"每帧最多 8 个致命事件"发牌，超出的一律不发，玩家只感到一次重顿。
	PresentationFX.request_hitstop(PresentationFX.TIER_KILL)
	# 死亡表现：急速放大 + 淡出，池回收时统一复位（不做 tween，省开销）
	hp_bar.visible = false
	_dying = true
	_die_t = 0.0
	if is_elite or is_boss:
		# 化墨散去。restore=false 是刻意的：池化敌人每次 setup() 都会重设 art.material，
		# 不必在回收前还一次。
		# ⚠️ 如果哪天改成"不重设材质"，这里必须改成 true —— 否则复用的敌人会带着
		#    progress = 0 出场，也就是"看不见的怪打你"。
		ShaderFX.dissolve_out(art, ELITE_DISSOLVE, false)
		_corpse_left = ELITE_DISSOLVE
	else:
		# 小怪也化墨散去，复用同一套 in-house 溶解（不新增 shader）。
		# 代价：这 DEATH_BUDGET 只里死掉的每一只都挂着一份独立材质、掉出合批。
		# 实测峰值约 10 具尸体同时在溶（击杀率 30/s × 0.3s），换来的
		# "被扫掉"的观感值这个钱；再往上（比如把时长拉到 0.6）就该改成
		# "只给最近 N 只走溶解、其余走硬淡出"了。
		ShaderFX.dissolve_out(art, MOB_DISSOLVE, false)
		_corpse_left = MOB_DISSOLVE
		# 先胀后塌（A3）。原 1.12 是"一步到位"的死相，读不出"被击中"这一下。
		# 曲线在 corpse_expired() 里按 DEATH_SCALE_UP_TIME 推到 DEATH_SCALE_UP，
		# 再线性收回到 DEATH_SCALE_DOWN —— 先在 0.08s 内胀（冲击），剩下的时间塌（散掉）。
		# ⚠️ 这里**不能**再把 modulate.a 置 0：那会让溶解直接看不见，
		#    表现和改动前一模一样（甚至更差，因为还多挂了份材质）。
	died.emit(global_position, xp_value, kind)

## EnemyPool 每帧问一次：这具尸体可以回收了吗。
## ⚠️ 死亡表现只能在这里推进，不能放 Enemy._process：_die() 里已经 set_process(false)，
##    Enemy 自己的帧循环到此为止。这也是为什么"先胀后塌"写在池子侧而不是实体侧。
## delta 已经被池子换成**真实时间**（见 EnemyPool._process 的 / time_scale）：
## 顿帧期间 Engine.time_scale < 1，若直接吃缩放后的 delta，尸体会在原地"卡住"，
## 表现是"打死的瞬间全场凝固"而不是"顿了一下然后继续"。
func corpse_expired(delta: float) -> bool:
	if alive:
		return false
	if _dying:
		_tick_death_curve(delta)
	if _corpse_left <= 0.0:
		return true
	_corpse_left -= delta
	return _corpse_left <= 0.0

## "先胀后塌"的缩放曲线。只改 scale（节点缩放，不是 art.scale），
## 所以不影响 setup() 里的出场缩放复位，也不会破合批（合批看 texture/material）。
## 用意：0~0.08s 胀到 1.20（这是"被打爆"的那一下），之后线性塌到 0.82（"散掉"）。
## 塌到 0.82 而不是 1.0：尸体应该"缩小着消失"，回到 1.0 会读成"变回原样"。
func _tick_death_curve(delta: float) -> void:
	_die_t += delta
	if _die_t <= DEATH_SCALE_UP_TIME:
		var up_t: float = _die_t / DEATH_SCALE_UP_TIME
		# ease-out（1-(1-t)^2）：前段快、后段稳，胀的那一下才有"顶住"的手感
		var e: float = 1.0 - pow(1.0 - up_t, 2.0)
		scale = Vector2.ONE * lerpf(1.0, DEATH_SCALE_UP, e)
		return
	if _corpse_left <= 0.0:
		_dying = false
		return
	# 剩余时间占比 → 从 DEATH_SCALE_UP 线性收到 DEATH_SCALE_DOWN
	var total_tail: float = maxf(_corpse_left + (_die_t - DEATH_SCALE_UP_TIME), 0.0001)
	var tail_t: float = clampf((_die_t - DEATH_SCALE_UP_TIME) / total_tail, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(DEATH_SCALE_UP, DEATH_SCALE_DOWN, tail_t)

# ---------------------------------------------------------------- 迭代03：糖水粘连（定身）
## 粘连染色。取 0.86 的轻压而不是满饱和：这个通道连血条一起染（见 _sync_root_tint 注释），
## 压太深会把血条读数吃掉。
const GLUE_TINT := Color(1.0, 0.96, 0.86)
## 同一只怪被粘过后的免疫窗口。没有它，单目标场景下糖画冷却 0.65s < 定身 1.0s，
## 会把同一只怪锁到死 —— 那正是 EvolutionDB 注释里明确要避免的形态。
const ROOT_IMMUNE := 2.5

var _root_left := 0.0
var _root_immune := 0.0
var _root_tinted := false

## 糖水粘连。返回 true 表示这次真的粘上了 ——
## 测试直接断返回值，不用去读私有字段，也让「免疫窗口生效」这件事可断言。
func apply_root(duration: float) -> bool:
	if not alive or _root_immune > 0.0:
		return false
	_root_left = maxf(_root_left, duration)
	_root_immune = ROOT_IMMUNE
	_sync_root_tint()
	return true

## 位移闸门。定身时连 _pool.separation 的分离推力一起吃掉 ——
## 只压推进速度的话，被粘住的怪仍会被身后同伴挤着走，读起来像「糖浆没粘住」。
## 倒计时放在这里而不是 _process 开头，是为了不新增行（见 M-05 §5.3 的「零行漂移」）。
func _advance(move: Vector2, delta: float) -> void:
	_root_immune = maxf(_root_immune - delta, 0.0)
	_root_left = maxf(_root_left - delta, 0.0)
	_sync_root_tint()
	if _root_left > 0.0:
		return
	global_position += move * delta

## 粘连的可见化。只在翻转沿写一次 —— 与 _sync_slow_tint 同一个理由：
## 200 只小怪每帧各赋一次 modulate 是纯开销，而状态一秒只翻两次。
## 用节点 modulate 而不是 art.modulate：后者是闪白与减速染色的通道，
## 抢同一个通道会互相抹掉。节点 modulate 全文件只在 setup 里写过，是空着的。
func _sync_root_tint() -> void:
	var want: bool = _root_left > 0.0
	if want == _root_tinted:
		return
	_root_tinted = want
	modulate = GLUE_TINT if want else Color.WHITE
