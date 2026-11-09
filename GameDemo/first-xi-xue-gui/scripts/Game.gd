extends Node2D
class_name GameScene

# 竖屏基准 720x1280（文档口径），移动端单指操作
const VIEW_W := 720.0
const VIEW_H := 1280.0

# ---- 刷怪：屏幕外圆环（半径取 760 = 竖屏可视边缘外一圈，见 params.json world._spawn_ring_note）
const SPAWN_RING := 760.0
# 宝箱：精英必掉一只。这是进化唯一入口，掉率不能随机（否则配方不可预期）。
const CHEST_PICKUP_R := 34.0
const CHEST_MAX := 6
# 单局时长：存活到这里判胜利
const RUN_LENGTH := WaveTable.RUN_LENGTH
## 五更鸡鸣演出：终局 Boss 和"判胜"在同一帧，原本 _win() 立刻把画面切成结算，
## 长夜灯一帧都看不到。这里在判胜与进结算之间插 2 秒过场。
## 注意：**不动胜利判定时点**（仍是 elapsed >= RUN_LENGTH），只延迟进结算。
const WIN_HOLD := 2.0

# ---- Boss 登场傩阵（T2 演出，每局最多 2 次）
## 直径取 1.6 倍碰撞直径：法阵要比 Boss 站的地方大一圈，才读得出"这是它的位置"。
const BOSS_CIRCLE_D := 300.0
## 法阵留存时长。比 Boss 的溶解出场（0.40s）长，让"画阵 → 现身"是一个连贯动作。
const BOSS_CIRCLE_LIFE := 1.6

# ---- 残面三现（v7.1 / T13 · 策划案 §4.3 优先级 5 / L-09）
# 三档真 Boss 是同一个反派的三次现身，**不换皮、只加层**：
#   一现 金光裂纹贴脸 → 二现 灯影吸魂环绕 → 三现 全屏傩面
# 【为什么不换三套 Boss 美术】三档在数据上是同一个 kind（reaper）、同一张图。
#   换图会让玩家以为"这是三个不同的对手"，还会把"它又来了，而且比上次更凶"
#   这条叙事直接抹掉。加层把这件事画出来，成本还低一个数量级。
# 【为什么 FX 挂在 Game 上，不挂 Boss 身上】Boss 是从池里复用的 Enemy：
#   给它挂子节点会和 setup() 的状态复位、"结壳不挂叠加层"的口径同时打架。
#   挂在场景里每帧跟随位置，Boss 一死就整组清掉。
const BOSS_FX_TEX: Array[String] = [
	Art.BOSS_MASK_GLOW, Art.BOSS_LANTERN_DRAIN, Art.BOSS_WARNING_RING,
]
## 每层：目标宽度（世界像素）、相对残面的纵向偏移、稳态透明度、
## 自转角速度（弧度/秒，负值反向）、呼吸幅度、**层高**。
## 三层宽度 96 < 300 < 980 是刻意的：一层比一层外扩，玩家从"脸上有东西"
## 逐步读到"整块屏幕被它占住"。
##
## 【层高为什么不是统一的】这是三现第一次做出来的最大翻车点：
##   boss_lantern_drain 的正中央是一个 r=24 的实心暗圆（"吸"的那个洞）。
##   把它盖在残面上面，等于给这张脸挖了个洞 —— 截图里只剩一团旋涡，看不出 Boss 是谁。
##   所以"环绕型"必须压在敌人**下面**：旋臂从脚边卷上来、洞被身体挡住，才读得出"它在吸"。
##   "贴脸型"（金光裂纹）一开始也想压在上面，实测更糟：mask_glow 的中心就是最亮的那团白，
##   盖上去之后残面的脸整块被吃掉，截图里只剩一个发光的圆球。所以三层全部压在敌人之下，
##   让光从身体四周溢出 —— 一现读作"脸背后透出来的金线"，脸本身始终清晰。
## tint 走 self_modulate（与 modulate.a 相乘），用来把三层的色温分开：
## 一现偏金（"金光"裂纹）、二现偏暖（灯影）、三现原色（红环）。
## 不染的话 mask_glow 的米白在暗底上会渲染成灰白，"金光"读不出来。
const BOSS_FX_SPEC: Array[Dictionary] = [
	{"w": 170.0, "dy": -60.0, "alpha": 0.78, "spin": 0.35, "pulse": 0.10, "z": -3,
		"tint": Color(1.0, 0.78, 0.38)},
	{"w": 340.0, "dy": -26.0, "alpha": 0.62, "spin": -0.55, "pulse": 0.06, "z": -3,
		"tint": Color(1.0, 0.90, 0.80)},
	{"w": 980.0, "dy": -46.0, "alpha": 0.34, "spin": 0.18, "pulse": 0.03, "z": -4,
		"tint": Color(1.0, 1.0, 1.0)},
]
## 三现的文案。idx 来自 WaveTable.BOSSES 的下标，不另设一套编号。
const BOSS_APPEAR_NAME: Array[String] = ["一现", "二现", "三现"]


# ---- 命中火花预算（令牌桶）
## 敌人的每一次聚合伤害事件都可以冒一个火花吗？不行。
## Enemy 侧已经按 0.22s 聚合过，但满级 9 把武器 + 同屏 100 只正在挨打时，
## 聚合后仍可能有 400+ 事件/秒。令牌桶把它压到 30/s（≈ 同时 4 颗火花），
## 观感上已经是"打到哪亮到哪"，而 FX 池（64 个精灵）不会被瞬间抽干。
## 击杀那一击不吃预算 —— 那是最该被看见的一次反馈，不能被节流掉。
const SPARK_RATE := 30.0
const SPARK_BURST := 6.0

@onready var player: Player = $World/Player
@onready var enemies: EnemyPool = $World/EnemyPool
@onready var gems: GemPool = $World/GemPool
@onready var weapons: WeaponManager = $World/Weapons
@onready var damage_numbers: DamageNumbers = $World/DamageNumbers
@onready var camera: Camera2D = $World/Player/Camera
@onready var ground: Ground = $World/Ground
@onready var props: PropField = $World/Props
@onready var bg: TextureRect = $BG
@onready var hud: HUD = $UI/HUD
@onready var level_up_ui: LevelUpUI = $UI/LevelUpUI
@onready var pause_ui: PauseUI = $UI/PauseUI
@onready var death_ui: DeathUI = $UI/DeathUI
@onready var pickups: PickupField = $World/Pickups
@onready var resources: ResourceField = $World/Resources
@onready var shop_ui: ShopUI = $UI/ShopUI

var elapsed := 0.0
var kills := 0
var elite_kills := 0
var boss_kills := 0
var evolutions := 0
## 本局是否已判胜利。胜利后停止刷怪、停止计时，但仍允许走完结算动画。
var won := false
## 本局金币是否已入账。_finish 只该结算一次（死亡和胜利两条路径不能各结一次），
## 否则玩家能靠"最后一击击杀 Boss 同时被打死"白拿双份金币。
var banked := false
## 五更鸡鸣演出剩余时间。-1 = 不在演出。
## 判胜后 GameManager.started 已置 false，所以这 2 秒里玩家本身是冻结 + 无敌的
## （Player._physics_process / take_damage 都守着 started），不会出现"赢了还被撞死"。
var _win_hold := -1.0
var _spawn_left := 0.6
var _elite_left := 0.0
## 上一次的 elapsed，用于"跨越时间点"判定（Boss 登场）
var _prev_t := 0.0
## 本局炸弹已掉落数量（params.json pickups.bomb._limit.per_run_cap = 4）
var bombs_dropped := 0
## 本局磁铁数量：NUM_DESIGN §10.7 要求单独记录，否则等级曲线会莫名偏高
var magnets_dropped := 0
## 本局开过的宝箱数。引导提示（L-07 第 5 条）需要一个外界读得到的"开过箱"事实，
## 宝箱不是持续状态（箱子一碰就没了），只能靠计数。
var chests_opened := 0
## 一次性情境提示层（L-07 的 5 条）。Game._ready 里创建并 bind。
var tips: TipUI = null
## v9 C1：环境层（暗角 / 远景视差 / 灯晕）。在代码里建，理由同 TipUI：
## 它自己是一整层 z_index 约定，场景里加节点会把"层级"拆成两处定。
var ambience: Ambience = null
## Ambience 当前是否处于低配档。按值比对用，避免每帧调 apply_quality。
var _amb_low := false
## 资源点拆解攒下的金币。结算时与击杀/时长奖励相加（见 coin_reward）
var coins_earned := 0

## 场上未拾取的宝箱（贴图 + 位置）。不走池子：同屏最多 6 只，直接建节点更简单。
var _chests: Array[Sprite2D] = []
## 残面三现的层（T13）。下标 0..2 就是"第几现已经挂上"。
var _boss_fx: Array[Sprite2D] = []
var _boss_fx_phase := -1
## 命中火花令牌。开局给满一格，避免"第一下打中却什么都没有"。
var _spark_tokens := SPARK_BURST

func _ready() -> void:
	# 相机平滑跟随：玩家恒居中，落点带轻微"追尾感"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	ground.bind(camera)
	props.bind(camera)
	_fit_background()
	GameManager.reset()
	GameManager.on_started()
	# 局外次数类资源（复活）每局重置；金币和永久等级是跨局资产，不在这里动
	MetaSave.begin_run()
	player.stats = GameManager.stats
	weapons.stats = GameManager.stats
	# 起始武器由所选匠人决定（T9）。只有"开局给哪把"不同，属性一律共用 Stats 基线 ——
	# 这是策划案 §4.3 的红线，CharacterDB 的注释里写了为什么不能有属性差。
	var starter: String = CharacterDB.starting_weapon()
	weapons.acquire(starter)
	# 辅助档起始 Lv2（花灯 / 皮影）。acquire 固定给 1 级，所以这里补到目标等级。
	var start_lv: int = CharacterDB.start_level()
	if start_lv > 1 and weapons.owned.has(starter):
		weapons.owned[starter] = start_lv
	GameManager.start_weapon = starter
	# 前三次三选一必出起始武器：错过两次就白选了，所以保底给 3 次而不是 1 次
	GameManager.pity_left = 3
	# 武器需要知道资源点：鞭弧/光环/手机环/子弹都要能拆可破坏物
	weapons.resources = resources
	# 主动技在 Player 下，但它需要的三个依赖（敌人池 / 武器 / 玩家）由场景注入，
	# 不让它自己 get_parent().get_node() —— 那样它就没法在测试里单独实例化。
	player.active_skill.bind(player, enemies, weapons)
	enemies.enemy_died.connect(_on_enemy_died)
	enemies.enemy_damage.connect(_on_enemy_damage)
	enemies.elite_died.connect(_on_elite_died)
	enemies.boss_died.connect(_on_boss_killed)
	player.died.connect(_on_player_died)
	hud.bind(player, self)
	level_up_ui.bind(player)
	pause_ui.bind(self)
	death_ui.bind_restart(self)
	death_ui.bind_shop(shop_ui)
	pickups.bind(self)
	resources.bind(self, camera)
	# 一次性情境提示（L-07）。在代码里建而不是塞进 Game.tscn：
	# 它自己是一整层 CanvasLayer，场景里加一个节点等于把"层级"这件事
	# 拆成"场景里定 60% + 代码里定 40%"，以后调优先级要两边看。
	tips = TipUI.new()
	tips.name = "Tips"
	add_child(tips)
	tips.bind(self, player)
	# v9 C1：环境层。挂在 $World 下 —— 它内部拆成两半：
	#   · Near(Node2D) 在 World 坐标系里，按 z_index=-6 排序
	#   · Screen(CanvasLayer) 自动脱离世界坐标，钉在屏幕上
	# 所以外部只需挂一次，两种坐标系由 Ambience 自己分派。
	ambience = Ambience.new()
	ambience.name = "Ambience"
	$World.add_child(ambience)
	ambience.bind(camera, get_viewport_rect().size)
	# v9 A1/A3：顿帧与震屏需要相机句柄。PresentationFX 不持有节点引用（会悬空），
	# 由这里注入，切场景时 reset_all 会清掉。
	PresentationFX.bind_camera(camera)
	PresentationFX.reset_all()
	# 开局先给一小波，避免前三秒空场
	_spawn_burst(4)
	# BGM 在场景真正开始跑之后才切换：主菜单曲的淡出与战斗曲的淡入
	# 由 Audio 用两个播放器交叉完成，不会出现一段静音。
	Audio.play_bgm("combat")

func _process(delta: float) -> void:
	# v9 C1：低配档切换的跟随。Settings.set_fx_level 只落盘、不发信号
	# （全工程没有"设置变更"广播，为一个弱引用不值得新造一套）。
	# 这里按值比对而不是每帧都调 apply_quality：后者会写 modulate.a，
	# 每帧写一次等于让脏矩持续存在。一个 bool 比较的开销可以忽略。
	if ambience != null:
		var low_now: bool = Settings.is_low()
		if low_now != _amb_low:
			_amb_low = low_now
			ambience.apply_quality(low_now)
	# 三现的光效要一直贴着残面走（它会追人），所以每帧同步一次。
	# 放在最前面：Boss 被打死时哪怕本帧已经进入判胜演出，也要先把光效清干净。
	_update_boss_fx(delta)
	# 判胜后的 2 秒演出：只推进倒计时，不刷怪、不计时、不开宝箱，等横幅播完再进结算。
	# ⚠️ 这段必须放在 started 判定**之前**：_win() 已经把 GameManager.started 置 false，
	# 放到后面会让 _win_hold 永远停在初值上，结算面板就永远不出现。
	if _win_hold >= 0.0:
		_win_hold -= delta
		if _win_hold <= 0.0:
			_win_hold = -1.0
			_finish(true)
		return
	if not GameManager.started or get_tree().paused or won:
		return
	_prev_t = elapsed
	elapsed += delta
	# 火花预算按真实时间回充（暂停时不回充：回来瞬间连放 6 颗毫无意义）
	_spark_tokens = minf(SPARK_BURST, _spark_tokens + SPARK_RATE * delta)
	# 更鼓 / 潮涌都读同一个时间轴。让 Game 每帧把 elapsed 同步给武器，
	# 而不是让武器自己累加 —— 暂停、升级弹窗、判胜演出都会让两边走偏。
	weapons.run_time = elapsed
	_check_boss()
	_check_mini_boss()
	_check_surge()
	# 胜利：撑到 30 分钟。先结算 Boss 击杀（终局 Boss 就是 1800s 那一档）
	if elapsed >= RUN_LENGTH:
		_win()
		return
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		# 潮涌只抬"刷出来的量"，不改敌人单体强度 —— 尖峰靠数量，不靠数值膨胀
		var n: int = int(round(float(WaveTable.batch_size(elapsed)) * WaveTable.surge_mult(elapsed)))
		_spawn_burst(maxi(n, 1))
		var iv: float = WaveTable.spawn_interval(elapsed)
		# Boss 战期间刷怪压到 35%，否则单体火力被杂兵抢光，Boss 战会拖成耐力测试
		if enemies.has_boss():
			iv /= WaveTable.MOB_SPAWN_DURING_BOSS
		_spawn_left = iv
	# 精英：不再用固定间隔，改由波次的 elite_share 决定概率
	_elite_left -= delta
	if _elite_left <= 0.0:
		_elite_left = 1.0
		# 潮涌期精英占比额外 +0.08~0.16（封顶 0.45：再高就没有"杂兵海"这个层次了）
		var share: float = minf(0.45, WaveTable.elite_share(elapsed) + WaveTable.surge_elite_add(elapsed))
		if randf() < share:
			_spawn_elite()
	_update_chests(delta)

# ---------------------------------------------------------------- 背景
## bg_city_dusk.svg 是 720x1280 的竖屏远眺图，只用作屏幕底层（不随相机滚动，
## 负责给"无限地面"外面套一圈城市剪影），缩放按视口尺寸铺满。
func _fit_background() -> void:
	if bg == null or bg.texture == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(VIEW_W, VIEW_H)
	bg.position = Vector2.ZERO
	bg.size = vp
	bg.stretch_mode = TextureRect.STRETCH_SCALE

# ---------------------------------------------------------------- 暂停 / 重开
func is_paused_by_player() -> bool:
	return pause_ui != null and pause_ui.is_open()

func toggle_pause() -> void:
	if not GameManager.started:
		return
	# 优先级：商店 > 结算 > 升级三选一 > 暂停菜单。
	# 结算/升级界面开着时不允许再叠一层暂停菜单，否则关掉一层后另一层还锁着，玩家会以为卡死。
	if shop_ui.is_open():
		return
	if death_ui.is_open():
		return
	if level_up_ui.is_open():
		return
	if pause_ui.is_open():
		pause_ui.close()
		hud.set_paused(false)
	else:
		pause_ui.open()
		hud.set_paused(true)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		# 商店开着时 ESC 是"关店"，不是"暂停"。商店叠在结算界面之上，
		# 这时候弹暂停菜单会变成三层叠加，关起来要点三次。
		if shop_ui.is_open():
			shop_ui.close()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_R and key.ctrl_pressed:
		restart()
		get_viewport().set_input_as_handled()

## 重开：先清掉所有暂停锁与上一局的池子状态，再重建整棵场景。
## 不能只 reset 数值——武器 owned、经验宝石、同屏敌人都是"上一局的残留"。
func restart() -> void:
	get_tree().paused = false
	var fresh: GameScene = (load("res://scenes/Game.tscn") as PackedScene).instantiate() as GameScene
	var host: Node = get_parent()
	if host == null:
		host = get_tree().root
	var idx: int = get_index()
	host.add_child(fresh)
	host.move_child(fresh, idx)
	# 只有本场景确实是 root 的直接子节点时才接管 current_scene；
	# 被挂在别的节点下（自动化测试）时 set_current_scene 会报错并拒绝。
	if host == get_tree().root and get_tree().current_scene == self:
		get_tree().current_scene = fresh
	queue_free()

# ---------------------------------------------------------------- 难度（Step 9：时间事件表）
# 所有数值转调 WaveTable，Game 只负责"什么时候问表"。这样调平衡不用碰场景逻辑。

func spawn_interval() -> float:
	return WaveTable.spawn_interval(elapsed)

func enemy_hp() -> float:
	return WaveTable.enemy_hp(elapsed)

func enemy_speed() -> float:
	return randf_range(60.0, 95.0)

func batch_size() -> int:
	return WaveTable.batch_size(elapsed)

func elite_share() -> float:
	return WaveTable.elite_share(elapsed)

func wave_note() -> String:
	return WaveTable.wave_note(elapsed)

## 敌人种类分布：前 30 秒纯杯子，2 分钟后才混入快速兵
func _pick_kind() -> String:
	return WaveTable.pick_mob(elapsed, randf())

func _spawn_burst(count: int) -> void:
	var base_hp: float = enemy_hp()
	var base_spd: float = enemy_speed()
	var base_ang: float = randf() * TAU
	for i in count:
		# 整圈均分 + 抖动，避免"一堆从同一个方向挤过来"
		var ang: float = base_ang + TAU * float(i) / float(maxi(count, 1)) + randf_range(-0.22, 0.22)
		var dist: float = SPAWN_RING * randf_range(0.92, 1.08)
		var pos: Vector2 = player.global_position + Vector2.from_angle(ang) * dist
		var kind: String = _pick_kind()
		var md: Dictionary = WaveTable.mob_def(kind)
		var hp: float = base_hp * float(md["hp_mult"])
		var spd: float = base_spd * float(md["speed_mult"])
		# 结壳：8–20min 的杂兵按 shell_w 概率上壳（血 ×1.40、吃 AoE ×0.75）。
		# 概率而不是全给，是为了让"溃散期"真的看得出来：屏幕上壳在变少，而不是一刀切。
		var shelled: bool = WaveTable.shelled_now(elapsed, randf())
		enemies.spawn(pos, hp, spd, int(md["xp"]), kind, false, WaveTable.CONTACT_DAMAGE, false, shelled)

## 精英从屏幕外单点刷入（不走 batch）：
## NUM_DESIGN §3.1 明确要求，否则纯 AOE 构筑能顺路覆盖精英刷新点，变成"永远差一口气"。
func _spawn_elite() -> void:
	var ang: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2.from_angle(ang) * SPAWN_RING
	var kind: String = WaveTable.pick_elite(elapsed)
	var ed: Dictionary = WaveTable.elite_def(kind)
	enemies.spawn(pos,
		enemy_hp() * float(ed["hp_mult"]),
		enemy_speed() * float(ed["speed_mult"]),
		int(ed["xp_mult"]),
		kind, true,
		WaveTable.CONTACT_DAMAGE * float(ed["dmg_mult"]))

## Boss 登场：用"跨越时间点"判定，避免每帧重复触发
func _check_boss() -> void:
	var b: Dictionary = WaveTable.boss_due(_prev_t, elapsed)
	if b.is_empty():
		return
	if enemies.has_boss():
		return
	var ang: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2.from_angle(ang) * (SPAWN_RING * 0.8)
	var idx: int = WaveTable.BOSSES.find(b)
	# 先画阵、再让残面从阵里渗出来 —— 否则屏幕外冒出一个大家伙，玩家只会觉得"突然被打"。
	# z_index = -4：压在 Props(-5) 之上、Resources(-3) 之下，法阵贴地但不盖住角色。
	var circle: ColorRect = ShaderFX.spawn_circle(self, BOSS_CIRCLE_D, Color(0.95, 0.72, 0.36))
	circle.z_index = -4
	circle.position = pos - circle.size * 0.5
	# 用节点自己的 tween 收尾，而不是 SceneTreeTimer：
	# 重开一局时法阵随场景一起销毁，tween 也跟着没了；SceneTreeTimer 会活下来，
	# 回调打在一个已释放的节点上，报 "Object not found"。
	var tw: Tween = circle.create_tween()
	tw.tween_interval(BOSS_CIRCLE_LIFE)
	tw.tween_callback(circle.queue_free)
	enemies.spawn(pos, float(b["hp"]), WaveTable.BOSS_SPEED, WaveTable.BOSS_XP_MULT,
		"reaper", true, WaveTable.CONTACT_DAMAGE * WaveTable.BOSS_DAMAGE_MULT, true)
	# 三现：idx 就是"第几现"（0/1/2），层数跟着它递增
	spawn_boss_visual(idx)
	hud.flash_boss("残面 %s  ·  %d/%d" % [BOSS_APPEAR_NAME[clampi(idx, 0, 2)],
		idx + 1, WaveTable.boss_count()])
	# 登场重音与红色横幅同一个时点：听到和看到必须是同一件事，
	# 晚 0.1s 就会读成"横幅先响、声音后补"。
	Audio.play_sfx("boss_spawn")
	# v9 A6：Boss 现身是"世界的重量换了"的时刻，给一次重震 + 一次长顿帧。
	# TIER_HEAVY 而非 TIER_KILL：这是"顿住看它出现"，不是"打中了"。
	PresentationFX.add_trauma(PresentationFX.ADD_BOSS)
	PresentationFX.request_hitstop(PresentationFX.TIER_HEAVY)

# ---------------------------------------------------------------- 残面三现（T13）
## 挂上第 phase 现所对应的全部层。一现只有 1 层，三现是 1+2+3 = 三层一起。
## 【为什么要 clear 再挂】同一局里三现是递增的，但重开一局 / 调试跳档时可能要求
## "直接看第三现"。先清后挂让这个函数是幂等的：调几次、按什么顺序调，结果都对。
func spawn_boss_visual(phase: int) -> void:
	clear_boss_visual()
	_boss_fx_phase = clampi(phase, 0, BOSS_FX_TEX.size() - 1)
	for i in _boss_fx_phase + 1:
		var spec: Dictionary = BOSS_FX_SPEC[i]
		var tex: Texture2D = Art.tex(BOSS_FX_TEX[i])
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.name = "BossFx%d" % i
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# 层高逐层写在 SPEC 里（见上面的注释）：贴脸的在敌人之上，
		# 环绕与地面环压在敌人之下，否则会把残面的脸挖掉。
		s.z_index = int(spec["z"])
		s.modulate = Color(1.0, 1.0, 1.0, 0.0)
		# 颜色走 self_modulate（与 modulate 相乘），这样淡入仍然只动 modulate.a
		s.self_modulate = spec.get("tint", Color.WHITE) as Color
		var base: float = float(spec["w"]) / maxf(tex.get_size().x, 1.0)
		s.set_meta("base_scale", base)
		s.set_meta("alpha", float(spec["alpha"]))
		s.set_meta("spin", float(spec["spin"]))
		s.set_meta("pulse", float(spec["pulse"]))
		s.set_meta("dy", float(spec["dy"]))
		s.set_meta("t", 0.0)
		# 入场：从 0.62 倍收着涨到目标尺寸，同时淡入。
		# 直接"啪"地出现会读成 UI 闪烁，而不是"光从面孔里渗出来"。
		s.scale = Vector2.ONE * base * 0.62
		add_child(s)
		_boss_fx.append(s)
		var tw: Tween = s.create_tween()
		tw.tween_property(s, "modulate:a", float(spec["alpha"]), 0.55) \
			.set_delay(0.08 * float(i)) \
			.set_ease(Tween.EASE_OUT)

func clear_boss_visual() -> void:
	for s in _boss_fx:
		if is_instance_valid(s):
			s.queue_free()
	_boss_fx.clear()
	_boss_fx_phase = -1

## 每帧：把光效钉在残面身上 + 自转 + 呼吸。
## Boss 一死或离场就整组清掉 —— 留着的话结算界面背后会浮着一圈红环。
func _update_boss_fx(delta: float) -> void:
	if _boss_fx.is_empty():
		return
	var b: Enemy = enemies.boss()
	if b == null or not b.alive:
		clear_boss_visual()
		return
	var anchor: Vector2 = b.global_position
	for s in _boss_fx:
		if not is_instance_valid(s):
			continue
		var t: float = float(s.get_meta("t")) + delta
		s.set_meta("t", t)
		s.global_position = anchor + Vector2(0.0, float(s.get_meta("dy")))
		s.rotation = float(s.get_meta("spin")) * t
		s.scale = Vector2.ONE * float(s.get_meta("base_scale")) \
			* (1.0 + float(s.get_meta("pulse")) * sin(t * 2.2))

## 小 Boss：12 / 18 / 24min 各一只，走 elite 通道（掉宝箱、有血条），
## 但**不压制刷怪率** —— 只有三档真 Boss 才该把 mob 压到 35%。
func _check_mini_boss() -> void:
	var b: Dictionary = WaveTable.mini_boss_due(_prev_t, elapsed)
	if b.is_empty():
		return
	var ang: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2.from_angle(ang) * (SPAWN_RING * 0.75)
	# 和小 Boss 同款法阵，但换成冷色：玩家要能"还没看清就分出这是硬点不是终局"
	var circle: ColorRect = ShaderFX.spawn_circle(self, BOSS_CIRCLE_D * 0.8, Color(0.62, 0.78, 0.95))
	circle.z_index = -4
	circle.position = pos - circle.size * 0.5
	var tw: Tween = circle.create_tween()
	tw.tween_interval(BOSS_CIRCLE_LIFE * 0.7)
	tw.tween_callback(circle.queue_free)
	enemies.spawn(pos, float(b["hp"]), WaveTable.BOSS_SPEED * 1.15,
		WaveTable.MINI_BOSS_XP, String(b["kind"]), true,
		WaveTable.CONTACT_DAMAGE * WaveTable.MINI_BOSS_DAMAGE_MULT, false, false)
	hud.flash_boss("%s 现身" % String(b["name"]))
	# 小 Boss 用同一个素材但压低 8 dB：玩家要能听出"又来了一个硬的"，
	# 但不能和终局残面的登场声一样重 —— 那会削弱真 Boss 的分量。
	Audio.play_sfx("boss_spawn", -8.0)
	# v9 A6：小 Boss 的神也要跟手。0.20 是终局 Boss（0.32）的 62% ——
	# 两者的差别必须能用身体读出来，否则"小 Boss"就只是"血少一点的 Boss"。
	PresentationFX.add_trauma(PresentationFX.ADD_MINI_BOSS)

## 潮涌：只做"预警 + 尖峰"，不改敌人单体数值。
## 预警是功能性的 —— 尖峰 R 会砸到 0.17~0.33，玩家必须提前决定"绕圈还是放震吼"。
func _check_surge() -> void:
	var s: Dictionary = WaveTable.surge_due(_prev_t, elapsed)
	if s.is_empty():
		return
	hud.flash_boss("%s  ·  潮涌" % String(s.get("note", "潮涌")))
	_show_surge_ring()
	# v9 A6：潮涌是"世界在推你"，震一下提醒回神。0.08 很轻 ——
	# 潮涌会连续触发，太重会让屏幕一直在抖，反而看不出哪里是重点。
	PresentationFX.add_trauma(PresentationFX.ADD_SURGE)

func _show_surge_ring() -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex(Art.FX_SURGE_RING)
	# 贴地法阵：压在 Props(-5) 之上、Boss 法阵(-4) 之下，不盖角色
	s.z_index = -4
	s.position = player.global_position
	s.modulate = Color(1.0, 0.55, 0.42, 0.0)
	add_child(s)
	# 从玩家脚下胀到"屏幕外一圈"：256px 源图 × 3.2 ≈ 820px，正好压到刷怪环
	s.scale = Vector2.ONE * 0.6
	var tw: Tween = s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * 3.2, 1.4)
	tw.tween_property(s, "modulate:a", 0.75, 0.25)
	tw.chain().tween_property(s, "modulate:a", 0.0, 1.15)
	tw.chain().tween_callback(s.queue_free)

func _on_enemy_died(pos: Vector2, xp: int, kind: String) -> void:
	kills += 1
	# 击杀声。满屏清怪时一秒可能几十次，节流与并行上限在 Audio 里统一做；
	# 这里只管"发生了一次击杀"这件事。
	Audio.play_sfx("enemy_die")
	gems.spawn(pos, xp)
	# 每次击杀掷一次掉落（磁铁/炸弹/烤鸡）。掉落物不吃 xp，所以顺序无所谓。
	pickups.roll_drop(pos, self)

## 敌人挨打：数字必冒，火花按预算冒。
##
## 为什么数字不做节流：那是"我这一下打掉了多少"的唯一读数。
## 为什么火花要节流：那是氛围，不是信息 —— 多到某个密度之后就只是噪音，
## 还要和 FX 池（弧光、引爆、进化共用同一个池子）抢精灵。
func _on_enemy_damage(pos: Vector2, amount: float, big: bool) -> void:
	damage_numbers.pop(pos, amount, big)
	if big:
		weapons.spawn_spark(pos, 1.35)
		return
	if _spark_tokens < 1.0:
		return
	_spark_tokens -= 1.0
	weapons.spawn_spark(pos, 0.62)

func _on_elite_died(pos: Vector2, kind: String) -> void:
	elite_kills += 1
	# 小 Boss 单独记一笔（角色解锁条件之一：击杀 3 只小 Boss）。
	# 判据用 WaveTable.MINI_BOSSES 里的 kind，而不是"is_elite"——
	# 墨渍/傩面精英也是 elite，把它们算进去等于把解锁条件降级成"杀 3 只精英"。
	for b in WaveTable.MINI_BOSSES:
		if String(b["kind"]) == kind:
			MetaSave.note_mini_boss_kill()
			break
	_drop_chest(pos)
	# v9 A6：精英被杀是一次"值得记住"的击杀，给中等冲击。
	PresentationFX.add_trauma(PresentationFX.ADD_ELITE)

## Boss 死亡单独走：掉宝箱 + 一串大宝石 + 一个饭盒
func _on_boss_killed(pos: Vector2) -> void:
	boss_kills += 1
	_drop_chest(pos)
	for i in 6:
		var off := Vector2.from_angle(TAU * float(i) / 6.0) * randf_range(30.0, 70.0)
		gems.spawn(pos + off, 20)
	pickups.spawn(pos + Vector2(0, 40), "bento")
	# v9 A6：击杀终局 Boss 是全场最重的一次。0.32 接近 traumas 的上沿（1.0 满值），
	# 但配合 0.85/s 的线性衰减，实际震感是"猛地一顿、0.4 秒内收敛"——
	# 不会像某些游戏那样震到看不清掉落。
	PresentationFX.add_trauma(PresentationFX.ADD_BOSS)
	PresentationFX.request_hitstop(PresentationFX.TIER_HEAVY)

func _on_player_died() -> void:
	# 死亡时如果升级卡还开着，先让卡回去，否则结算界面会被暂停锁挡住
	level_up_ui.close_all()
	pause_ui.close()
	hud.set_paused(false)
	# 局外「复活」先于结算：这是唯一一条能让单局不结束的 meta 线，
	# 也是花费最贵的一条（2500 起），必须给足仪式感（横幅 + 3 秒无敌）。
	if _try_revive():
		return
	_finish(false, death_cause())

## 死因归纳（v7 L-06）。
##
## 【为什么压成四类，而不是"显示凶手名字"】
## 玩家死时同屏通常有一百多只贴在一起，谁最后碰到的完全是偶然 ——
## 报出凶手名字是冷知识，帮不了下一局。有意义的区分是**局面结构**：
## 被 Boss 逮住 / 潮涌挤死 / 被杂兵围死 / 其他。玩家据此能改的东西才具体
## （别贴 Boss、潮涌期往空地跑、别贴边）。
##
## 【为什么潮涌优先于"被围"】
## 潮涌期死掉的玩家，死因几乎都是"怪突然变多"，而不是"某只怪特别狠"。
## 把时段信息盖在凶手信息之上，说的才是那一局真正的故事。
func death_cause() -> String:
	var src: String = String(player.last_hit_source)
	if src == "boss":
		return "Boss 贴身按住"
	if not WaveTable.surge_at(elapsed).is_empty():
		# v9 文案：原「潮涌里被挤灭」的「灭」字太狠且偏书面，玩家读不出画面。
		# 「挤倒」是玩家真能想象的动作（一群人在夜市里被推倒），也更符合本作"民俗街市"的调子。
		return "人潮里被挤倒"
	if src == "elite" or src == "mob":
		# v9 文案：把"没盾"这一档单独说出来。这是玩家唯一能立刻改的变量
		# （等结界回满再往里冲），比笼统的「被围住」有用得多。
		# 判据用 shield_hp <= 0.0 —— 这是结算那一刻的**真实状态**，
		# 不引入任何新字段。⚠️ 不能用 Player._shield_break：那是 0.32s 的闪光倒计时，
		# 不是"盾破了"的持久标记（见 Player.gd:56 注释），拿它判会永远为假。
		if player.shield_hp <= 0.0:
			return "没盾的时候被围住"
		return "被围住"
	return "力竭而倒"

## 消耗一次局外复活。返回 true = 本局继续。
##
## 【为什么在这里而不是 Player 里】
## Player 只知道自己没血了（take_damage → died），它不该知道"玩家花钱买过复活"。
## 局外资源属于 Game/元系统这一层，放在这里也保证重开一局时计数由 begin_run 统一重置。
func _try_revive() -> bool:
	if not MetaSave.consume_revive():
		return false
	GameManager.stats["hp"] = float(GameManager.stats["max_hp"])
	GameManager.started = true
	# 复活点必然在怪堆正中：无敌时间必须显著长于普通受击无敌（0.5s），
	# 否则玩家刚站起来就被同一个人再撞死一次 —— 那等于把 2500 金币丢进水里。
	player.invuln_left = MetaSave.REVIVE_INVULN
	player.hit_flash = 0.0
	hud.flash_revive("复活！  本局还剩 %d 次" % MetaSave.revive_left)
	return true

## 撑满 30 分钟：判胜利
## 注意这里**不再当场 _finish**：先播 2 秒"五更鸡鸣"，由 _process 的 _win_hold 收尾。
## 胜利判定时点没有变（仍旧是 elapsed >= RUN_LENGTH 那一帧），只是把"进结算"往后挪。
func _win() -> void:
	if won or not GameManager.started:
		return
	won = true
	GameManager.started = false
	player.velocity = Vector2.ZERO
	level_up_ui.close_all()
	pause_ui.close()
	hud.set_paused(false)
	# 判胜后还有 2 秒"五更鸡鸣"过场，这期间提示木牌也该退场：
	# 鸡鸣是全屏演出，木牌压在它上面会读成"这两件事是同一层信息"。
	if tips != null:
		tips.clear()
	hud.flash_dawn("五更鸡鸣")
	_win_hold = WIN_HOLD

func _finish(victory: bool, cause: String = "") -> void:
	if banked:
		return
	banked = true
	# 这一局收下的图鉴条目在这里统一落盘（战斗中不写盘，见 MetaSave.note_codex）。
	MetaSave.flush_codex()
	# 结算前必须收掉提示木牌。它的 _process 是 PAUSABLE，结算会把整棵树暂停 ——
	# 于是"死在提示正播的那 4 秒里"会让一块木牌永久冻在结算面板前面，
	# 挡住「回主菜单」。这不是理论问题，截图里能看到。
	if tips != null:
		tips.clear()
	var coins: int = coin_reward()
	# 入账放在 Game 而不是 DeathUI：结算界面是"展示层"，它被测试/调试直接调用时
	# 不该顺手改存档。这里只此一处写存档，天然防重复入账（banked 闸）。
	var total: int = MetaSave.add_coins(coins)
	# 角色解锁进度（T9）。放在 _finish 而不是 _on_player_died：
	# 判胜（撑到 30 分钟）和判负必须都走到这里，否则"通关一次"永远解不开灯彩匠。
	MetaSave.record_run(victory, elapsed)
	death_ui.show_result(kills, elapsed, player.level, victory, coins,
		elite_kills, boss_kills, evolutions, total, cause)

## 金币结算（Step 11）。
## 公式取"击杀为主、时长兜底"：纯击杀奖励会让挂机不动和猛冲一样收益，
## 纯时长奖励又会让"苟着不打"最优。两者相加，再给胜利一个 1.5 倍乘数。
## coins_earned 是资源点拆解累计的（Step 10），单独加，不进乘数 ——
## 否则"想刷金币就拆箱子"会盖过"活到最后"这个主目标。
func coin_reward() -> int:
	var base: int = int(float(kills) * 0.12) + int(elapsed / 12.0)
	base += elite_kills * 6 + boss_kills * 40
	if won:
		base = int(float(base) * 1.5)
	return maxi(base + coins_earned, 0)

# ---------------------------------------------------------------- 宝箱 / 进化（Step 8）
## 精英必掉宝箱。用 Art.CHEST，落地后原地浮动，玩家走过去自动开。
func _drop_chest(pos: Vector2) -> void:
	while _chests.size() >= CHEST_MAX:
		var old: Sprite2D = _chests.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var s := Sprite2D.new()
	s.texture = Art.tex(Art.CHEST)
	s.position = pos
	s.z_index = 2
	add_child(s)
	# 宝箱是进化的唯一入口，必须在一片蓝灰地面 + 满屏纸片怪里一眼被看见。
	# 用程序化光晕（零贴图）挂在箱子背后，随箱子上下浮动一起动。
	# 同屏上限 CHEST_MAX = 6，掉出合批的代价可忽略。
	var aura: ColorRect = ShaderFX.add_aura(s, 150.0, Color(1.0, 0.72, 0.35))
	aura.position.y += 8.0
	_chests.append(s)

func _update_chests(delta: float) -> void:
	if _chests.is_empty():
		return
	var pp: Vector2 = player.global_position
	for i in range(_chests.size() - 1, -1, -1):
		var s: Sprite2D = _chests[i]
		if not is_instance_valid(s):
			_chests.remove_at(i)
			continue
		# 轻微上下浮动：让地上的宝箱和普通掉落一眼可分
		s.position.y += sin(elapsed * 4.0) * delta * 8.0
		if s.position.distance_to(pp) < CHEST_PICKUP_R + 16.0:
			_chests.remove_at(i)
			s.queue_free()
			_open_chest()

## 开箱：有配方就进化，没有就退回成一次普通升级（不能给空手玩家一个废箱）
func _open_chest() -> bool:
	chests_opened += 1
	var cands: Array[String] = EvolutionDB.candidates(
		weapons.owned, player.level_upgrades, weapons.evolved)
	if cands.is_empty():
		# 没满足配方：补偿一次升级三选一，否则精英宝箱对新手等于空气。
		# 注意 player.level_up 是 signal 不是方法，这里必须用 gain_xp 触发升级流程。
		player.gain_xp(player.xp_next)
		# S-03：补偿也要有因果提示，否则玩家只看到"突然弹升级面板"
		hud.flash_evolve("箱中无脸 · 化为一枚灯花")
		return false
	var pick: String = cands[randi() % cands.size()]
	var form_id: String = EvolutionDB.form_id_for(pick)
	weapons.evolved[pick] = form_id
	evolutions += 1
	# 图鉴（T12）：开脸只在真的开成时才收录，所以挂在 pick 之后，
	# 不挂在 can_evolve_any() 上 —— "能开"和"开了"是两件事。
	CodexDB.unlock(form_id)
	weapons.spawn_evolve(player.global_position)
	# C-01：开脸瞬间轻轻推近再弹回（只动 camera.zoom，不抢震屏的 camera.offset）
	PresentationFX.pull_zoom(1.06, 0.35)
	hud.flash_evolve("开脸！ %s" % String(EvolutionDB.form(form_id).get("name", pick)))
	# 开脸是单局里最重的一次正反馈（横幅、特效都上了），声音也要同级；
	# 复用升级音但抬 2 dB，和"多了一张卡"区分开。
	Audio.play_sfx("levelup", 2.0)
	return true

## 调试 / 测试用：不走宝箱直接查配方是否满足
func can_evolve_any() -> bool:
	return not EvolutionDB.candidates(weapons.owned, player.level_upgrades, weapons.evolved).is_empty()

func chest_count() -> int:
	return _chests.size()

# ---------------------------------------------------------------- 给 HUD / 调试用
func alive_enemies() -> int:
	return enemies.alive_count()

func gem_count() -> int:
	return gems.count()
