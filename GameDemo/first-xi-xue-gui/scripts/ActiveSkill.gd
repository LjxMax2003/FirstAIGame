extends Node
class_name ActiveSkill

# =====================================================================
# 主动技·傩面替身·震吼（v5 防挂机核心）
#
# 【为什么是一个 Player 下的子组件，而不是塞进 Game.gd】
# 它需要知道"玩家在哪、朝哪冲、当前构筑打多少"，这些都是玩家自己的状态。
# 塞进 Game 会变成全局态：Game 要反向读玩家的输入方向、读武器 DPS，
# 而"谁拥有这份状态"一旦变模糊，重开一局就必然残留（本工程已经踩过池化残留的坑）。
# 这里只把"放过了"这件事通过信号上行，CD 计时由自己持有。
#
# 【为什么伤害是"当前单体 DPS 的 250%"而不是一个固定数】
# 固定数在 5min 是清屏、在 25min 是挠痒。读构筑算出来，它才会一直"够用但不无敌"。
# 纯 AoE 构筑的单体 DPS 可能是 0 —— 这时回落到总 DPS 的 30%，
# 否则这类构筑会拿到一个 0 伤害的主动技（等于没有这个按键）。
#
# 【无敌 0.7s 是严格上限】
# 冲刺 + 无敌是脱围工具，不是无敌帧循环。0.7s < 25s CD 的 3%，
# 想靠它站桩是不可能的；但足够从"贴脸一圈"里冲出去半个身位。
# =====================================================================

## 放出来了（Game / HUD 用它做提示音与演出，不参与 CD）
signal cast

const COOLDOWN := 25.0
## 爆发半径：比花灯 Lv8（119）大一圈，比铜锣 Lv8（220）相当 —— 是"扫开身边一层"
const RADIUS := 220.0
## 无敌 + 冲刺时长。严格 ≤0.7s，改大就是改设计边界。
const DASH_TIME := 0.7
const DASH_SPEED := 620.0
## 伤害 = 当前单体 DPS × 2.5
const DAMAGE_RATIO := 2.5
## 纯 AoE 构筑的回落系数（没有单点武器时，按总 DPS 的 30% 结算）
const AOE_FALLBACK := 0.30

## 剩余冷却（秒）。HUD 直接读它画冷却遮罩。
var cd_left := 0.0

var _player: Player
var _pool: EnemyPool
var _weapons: WeaponManager
var _scratch: Array[Enemy] = []
var _ring: ColorRect

func bind(player: Player, pool: EnemyPool, weapons: WeaponManager) -> void:
	_player = player
	_pool = pool
	_weapons = weapons

func _ready() -> void:
	# 跟随整树暂停：升级三选一期间不该偷偷回 CD
	process_mode = Node.PROCESS_MODE_INHERIT

func _process(delta: float) -> void:
	if cd_left > 0.0:
		cd_left = maxf(0.0, cd_left - delta)

func is_ready() -> bool:
	return cd_left <= 0.0 and GameManager.started and _player != null and _pool != null

## HUD 画冷却用：1 = 刚放完，0 = 可用
func cd_ratio() -> float:
	return clampf(cd_left / COOLDOWN, 0.0, 1.0)

## 当前这一发的伤害。读动态构筑，永不写死。
func burst_damage() -> float:
	if _weapons == null:
		return 0.0
	var single: float = _weapons.single_dps()
	if single <= 0.0:
		single = _weapons.total_dps() * AOE_FALLBACK
	return maxf(single, 1.0) * DAMAGE_RATIO

## 尝试释放。返回 false = 还在 CD / 不在局内（HUD 用返回值决定要不要播按下反馈）。
func try_cast() -> bool:
	if not is_ready():
		return false
	cd_left = COOLDOWN
	var pos: Vector2 = _player.global_position
	var dmg: float = burst_damage()
	# 爆发：范围内的敌人各吃一次。传 &""（未知来源）——
	# 震吼不是武器，不受浆壳的 AoE 减伤影响（否则"破围"这一下对结壳兵最不痛，很反直觉）。
	_pool.query_circle(pos, RADIUS, _scratch)
	for e in _scratch:
		e.take_damage(dmg)
	# 脱围：朝当前摇杆方向冲。没有输入时朝"离玩家最近的敌人"的反方向，
	# 否则原地放技能会被围死 —— 那是"按了键还是死"，比没这个键更糟。
	var dir: Vector2 = _player.input_dir()
	if dir == Vector2.ZERO:
		var near: Enemy = _pool.nearest(pos, RADIUS)
		dir = (pos - near.global_position).normalized() if near != null else Vector2.DOWN
	_player.start_dash(dir, DASH_TIME)
	_play_fx(pos)
	cast.emit()
	return true

func _play_fx(pos: Vector2) -> void:
	# 两圈：外圈是"吼开的范围"（纯环，读得对），内圈是"替身炸开"的暖色
	ShaderFX.burst_ellipse(self, pos, RADIUS * 2.0, RADIUS * 2.0, Color(1.0, 0.42, 0.30), 12, 0.38)
	ShaderFX.burst_ellipse(self, pos, RADIUS * 1.1, RADIUS * 1.1, Color(1.0, 0.86, 0.55), 0, 0.24)
	if _ring == null:
		_ring = ShaderFX.add_aura(_player.art, 190.0, Color(1.0, 0.45, 0.32))
		_ring.visible = false
	_ring.visible = true
	_ring.modulate.a = 0.9
	var tw: Tween = _ring.create_tween()
	tw.tween_property(_ring, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void: _ring.visible = false)
