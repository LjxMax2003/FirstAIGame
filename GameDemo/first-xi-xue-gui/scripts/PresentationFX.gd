extends Node

# v9 表现层唯一「写字台」。
#
# 【为什么是 Autoload】引擎的 Autoload 先于主场景入树，所以本节点 _process 比
#   Game._process 更早执行。这个顺序是刻意的：顿帧写 time_scale 必须发生在
#   Game 累加 elapsed 之前，否则本帧的 elapsed 仍按旧 time_scale 走，产生 1 帧漂移。
#   改成非 Autoload（挂到 Game 下）会让每一段顿帧都少生效一帧。
#
# 【唯一写入者】Engine.time_scale / camera.offset / camera.zoom 全项目只有这里写。
#   其他脚本一律通过本类的方法请求，禁止直接写那三个属性 —— 两处各写一份必然打架。
#
# 【不持有实体引用】punch 只接收「谁 + 方向」，具体位移由实体自己在下一帧合成。
#   原因：敌人是池化复用的，单例持有节点引用会在回收后变成悬空引用。

## 顿帧三档。真值与依据见 docs/design/13-feel-tuning.md §2.1。
const TIER_NONE := 0
const TIER_HIT := 1
const TIER_KILL := 2
const TIER_HEAVY := 3

## 三档的「最深时间缩放」与「总时长」。
## 时间缩放不设到 0：完全停帧会让"敌人集体僵住"，玩家读成卡顿而不是打击。
const SCALE_HIT := 0.72
const SCALE_KILL := 0.55
const SCALE_HEAVY := 0.35
const DUR_HIT := 0.022
const DUR_KILL := 0.045
const DUR_HEAVY := 0.090
## 前 55% 停最深值（这就是"黏住"的读数窗口），后 45% 线性拉回 1.0。
## 选它而不是缓动，是因为线性收尾必然精确回到 1.0，可断言、无残差。
const DWELL_FRAC := 0.55

## 静默窗：同一窗口内的重复请求只取最大档，不追加时长。
## 一轮横扫打中 8 只 → 只顿 1 次。55ms 的依据是它 ≥ 3 帧（防同帧抖动）
## 且 < 0.22s（飘字聚合窗），不会把两次独立事件并成一次。
const QUIET_WINDOW := 0.055
## 占空比门：最近 1 秒内累计顿帧不得超过这个时长。
## 没有它，实测占空比会达到 1111%（全程慢放）。它是 A1 能成立的前提，不是优化。
const DUTY_CAP := 0.012
## 击杀那一下不吃静默窗（最该被看见的一次反馈），但仍受占空比门约束。

## 震屏：offset = noise * MAX_OFFSET * trauma²。
## 平方是分级器 —— 小 trauma 被压到不可感知（0.1 → 0.06px），大 trauma 保满幅。
const MAX_OFFSET_PX := 6.0
const TRAUMA_DECAY := 0.85
const ADD_MOB_KILL := 0.010
const ADD_ELITE := 0.10
const ADD_MINI_BOSS := 0.20
const ADD_BOSS := 0.32
const ADD_HURT := 0.14
const ADD_SURGE := 0.08

## 推镜只允许 ≥ 1.0：Ground._draw 的铺砖余量按视口算，zoom < 1 会露地面边缘。
const ZOOM_HIT := 1.000
const ZOOM_KILL := 1.004
const ZOOM_HEAVY := 1.010
const ZOOM_RETURN := 0.10

var _camera: Camera2D = null

var _ts_left := 0.0
var _ts_total := 0.0
var _ts_scale := 1.0
## 静默窗剩余。> 0 时普通命中请求直接丢弃。
var _quiet_left := 0.0
## 最近 1 秒内的顿帧占用量（秒），按真实时间滚动窗口。
var _duty_used := 0.0

var _trauma := 0.0
var _shake_t := 0.0
var _noise := FastNoiseLite.new()

var _zoom_mul := 1.0
var _zoom_left := 0.0
var _zoom_total := 0.0

## 自动化测试用（同 MainMenu.intent_hook 的做法）：测试工具在 _ready 里关掉它，
## 否则顿帧会把 create_timer 拉长、把 P95 帧时间打乱，测出来的数是假的。
## 生产路径恒为 true，这是唯一为测试新增的接口。
var enabled := true

func _ready() -> void:
	# ALWAYS：暂停/升级弹窗期间也要能推进衰减 —— 否则暂停时进入顿帧，
	# 恢复后画面会先"卡住"半秒再正常，那是明显的 bug 而不是表现。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = 20261105
	_noise.frequency = 0.85
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

## Game._ready 注入相机。测不到相机时本类所有镜头效果静默跳过，不影响玩法。
func bind_camera(cam: Camera2D) -> void:
	_camera = cam
	_trauma = 0.0

func is_bound() -> bool:
	return is_instance_valid(_camera)

# ---------------------------------------------------------------- 顿帧

## 请求一次顿帧。返回 true = 这次真的生效了（便于测试断言）。
## 三重门缺一不可：同帧取最大档 → 静默窗吞重复 → 占空比门丢超额。
func request_hitstop(tier: int) -> bool:
	if not enabled or tier <= TIER_NONE:
		return false
	# 暂停/弹窗期间不顿帧：那时候世界本来就停了，再压 time_scale 会让
	# "恢复瞬间"出现一段无法解释的慢动作。
	if get_tree() != null and get_tree().paused:
		return false
	var dur: float = _tier_duration(tier)
	if dur <= 0.0:
		return false
	# 门②：普通命中在静默窗内直接丢弃。击杀/重击要参与"取最大档"的覆盖，
	# 不能被一次普通命中的静默窗挡在门外 —— 否则打死精英时的重击会被吞掉。
	if tier == TIER_HIT and _quiet_left > 0.0:
		return false
	# 门③：占空比。超了就不顿，不排队 —— 排队会在密集期后补放一串，
	# 表现成"怪都死了画面还在卡"。
	if _duty_used + dur > DUTY_CAP:
		return false
	# 门①：已有更大或等长的顿帧在跑时，不缩短它，只把终点记成两者的较大值。
	var left: float = _ts_left
	var prev_scale: float = _ts_scale
	if left <= 0.0:
		_ts_total = dur
	elif dur > left:
		_ts_total = maxf(_ts_total, dur)
	_ts_left = maxf(left, dur)
	# 更深的时间缩放覆盖更浅的；反之不覆盖（"重"不能被"轻"打断）。
	_ts_scale = minf(prev_scale if left > 0.0 else 1.0, _tier_scale(tier))
	_quiet_left = maxf(_quiet_left, QUIET_WINDOW)
	_duty_used = minf(DUTY_CAP * 4.0, _duty_used + dur)
	return true

func _tier_duration(tier: int) -> float:
	match tier:
		TIER_HIT:
			return DUR_HIT
		TIER_KILL:
			return DUR_KILL
		TIER_HEAVY:
			return DUR_HEAVY
	return 0.0

func _tier_scale(tier: int) -> float:
	match tier:
		TIER_HIT:
			return SCALE_HIT
		TIER_KILL:
			return SCALE_KILL
		TIER_HEAVY:
			return SCALE_HEAVY
	return 1.0

## 顿帧期间本帧实际生效的 time_scale（只读查询，给测试与 HUD 用）。
func current_time_scale() -> float:
	return _ts_scale if _ts_left > 0.0 else 1.0

func is_hitstopping() -> bool:
	return _ts_left > 0.0

# ---------------------------------------------------------------- 震屏 / 推镜

## trauma 是截断累加的：同帧 50 只同时死也只加到上限 1.0，不会"地震"。
func add_trauma(amount: float) -> void:
	if not enabled or amount <= 0.0:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func trauma() -> float:
	return _trauma

## 短时推镜。只允许放大（zoom ≥ 1.0）。
func pull_zoom(mul: float, seconds: float) -> void:
	if not enabled:
		return
	if mul <= 1.0:
		return
	if mul > _zoom_mul:
		_zoom_mul = mul
		_zoom_total = maxf(0.001, seconds)
		_zoom_left = _zoom_total

## 局结束时调用：清掉所有残留。camera.offset 不会被 Game._ready 重设，
## 不清的话下一局开局镜头会停在偏移位置。
func reset_all() -> void:
	_ts_left = 0.0
	_ts_total = 0.0
	_ts_scale = 1.0
	_quiet_left = 0.0
	_duty_used = 0.0
	_trauma = 0.0
	_zoom_mul = 1.0
	_zoom_left = 0.0
	_zoom_total = 0.0
	Engine.time_scale = 1.0
	if is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
		_camera.zoom = Vector2.ONE

# ---------------------------------------------------------------- 每帧

func _process(delta: float) -> void:
	# delta 本身就是被 time_scale 缩过的。本类所有计时器都必须走真实时间，
	# 否则顿帧期间"恢复计时"也会跟着变慢，形成自我延长（一次 45ms 会拖成上百 ms）。
	var real_dt: float = delta / maxf(Engine.time_scale, 0.01) if Engine.time_scale > 0.0 else delta
	_tick_hitstop(real_dt)
	_tick_trauma(real_dt)
	_tick_zoom(real_dt)
	# 占空比窗口每秒回退一次；用真实时间，才能表达"每秒最多顿 12ms"这个语义。
	_duty_used = maxf(0.0, _duty_used - real_dt)

func _tick_hitstop(dt: float) -> void:
	_quiet_left = maxf(0.0, _quiet_left - dt)
	if _ts_left <= 0.0:
		if Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
		_ts_scale = 1.0
		return
	_ts_left = maxf(0.0, _ts_left - dt)
	if _ts_left <= 0.0:
		Engine.time_scale = 1.0
		_ts_scale = 1.0
		return
	# 时间轴反推：t 从 0 递增到 _ts_total。
	var t: float = _ts_total - _ts_left
	var dwell: float = _ts_total * DWELL_FRAC
	if t < dwell:
		Engine.time_scale = _ts_scale
	else:
		var tail: float = _ts_total - dwell
		var k: float = (t - dwell) / tail if tail > 0.0001 else 1.0
		Engine.time_scale = lerpf(_ts_scale, 1.0, clampf(k, 0.0, 1.0))

func _tick_trauma(dt: float) -> void:
	if not is_instance_valid(_camera):
		return
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * dt)
	_shake_t += dt
	# 双门：设置里的开关 且 不是低特效档。低配档第一批该牺牲的就是震屏。
	var on: bool = Settings.shake and not Settings.is_low()
	var w: float = _trauma * _trauma
	if not on or w <= 0.0:
		if _camera.offset != Vector2.ZERO:
			_camera.offset = Vector2.ZERO
		return
	# 噪声是连续的（不是逐帧随机），所以镜头是"抖动"不是"闪烁"。
	var nx: float = _noise.get_noise_2d(_shake_t * 60.0, 0.0)
	var ny: float = _noise.get_noise_2d(0.0, _shake_t * 60.0)
	_camera.offset = Vector2(nx, ny) * MAX_OFFSET_PX * w

func _tick_zoom(dt: float) -> void:
	if not is_instance_valid(_camera):
		return
	if _zoom_left > 0.0:
		_zoom_left = maxf(0.0, _zoom_left - dt)
	var target: float = 1.0
	if _zoom_left > 0.0 and _zoom_total > 0.0:
		# 推近很快（前 30%），回弹慢（后 70%）—— 冲击在前、余韵在后。
		var t: float = 1.0 - _zoom_left / _zoom_total
		var k: float = minf(1.0, t / 0.3)
		target = lerpf(1.0, _zoom_mul, k)
	else:
		_zoom_mul = 1.0
	# 硬下限 1.0：Ground 的铺砖余量按视口算，缩小会露出地面边缘。
	target = maxf(1.0, target)
	var z: float = _camera.zoom.x
	_camera.zoom = Vector2(maxf(1.0, lerpf(z, target, 0.55)), maxf(1.0, lerpf(z, target, 0.55)))

# ---------------------------------------------------------------- 测试钩子

func debug_disable() -> void:
	enabled = false
	reset_all()

func debug_enable() -> void:
	enabled = true
