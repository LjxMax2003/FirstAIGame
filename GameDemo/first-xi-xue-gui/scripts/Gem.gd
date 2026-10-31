extends Sprite2D
class_name Gem

# 一颗经验宝石：落地弹一下 → 静止自转 → 进磁吸圈后收缩加速飞向玩家
const MAGNET_DELAY := 0.12
const FLIGHT_ACCEL := 2600.0
const MAX_FLIGHT_SPEED := 1100.0
const PICKUP_R := 22.0
# 5 点以上算大宝石，用橙色贴图，视觉上一眼能分辨
const BIG_THRESHOLD := 5

var value := 1
var vel := Vector2.ZERO
var age := 0.0
var spin := 0.0
var flying := false
var base_scale := 1.0
## 强制吸取：磁铁道具（铜铃）与结算前扫袋用。
## 置位后不受磁吸半径限制，一路飞向玩家。
## ⚠️ 必须有这个标志位：原先 `vacuum_all()` 只是把 age 调大，而吸引条件判断的是**距离**，
##    跟 age 无关 —— 结果铜铃从上线起就是颗死道具（点了没有任何反应）。
var forced := false

func setup(pos: Vector2, xp: int) -> void:
	position = pos
	value = xp
	texture = Art.tex(Art.GEM_ORANGE if xp >= BIG_THRESHOLD else Art.GEM_BLUE)
	base_scale = 1.15 if xp >= BIG_THRESHOLD else 0.95
	# 落地朝随机方向弹一下，让掉落有"手感"而不是原地出现
	vel = Vector2.from_angle(randf() * TAU) * randf_range(50.0, 110.0)
	age = 0.0
	spin = randf_range(1.4, 2.6)
	flying = false
	# 池复用必须清掉：否则上一颗被吸取过的宝石会把"强制吸取"带给下一颗新掉的宝石
	forced = false
	scale = Vector2.ONE * (base_scale * 1.3)
	rotation = randf() * TAU
	modulate = Color.WHITE
	# 只有大灯花（>=5 点）发光：既让玩家一眼看出"这颗值钱"，也把发光对象数量
	# 天然压到同屏个位数 —— 发光材质会让 CanvasItem 掉出普通合批。
	# 用的是全场共用材质（set_group_glow），所以同尺寸的灯花之间仍然能合批。
	ShaderFX.set_group_glow(self, xp >= BIG_THRESHOLD)

## 由 GemPool 每帧驱动：返回 true 表示已被拾取
func tick(delta: float, player_pos: Vector2, magnet_r: float) -> bool:
	age += delta
	var to_player: Vector2 = player_pos - position
	var d: float = to_player.length()
	# 飞行中放宽拾取半径：吸力把速度顶到 1100，帧率掉到 40 时单帧位移 27px 已经超过
	# PICKUP_R(22)，硬判会从玩家身上"擦过去"再绕回来。放宽一倍即可盖住这个跨步。
	if d < PICKUP_R * (2.0 if flying else 1.0):
		return true
	if age > MAGNET_DELAY and (forced or d < magnet_r):
		flying = true
		var dir: Vector2 = to_player / maxf(d, 0.001)
		# 越近吸力越强。这里必须 clamp：强制吸取时 d 可能远大于 magnet_r，
		# 不夹会让 (1 - d/magnet_r) 变成负数，把宝石往**反方向**推。
		var near: float = clampf(1.0 - d / magnet_r, 0.0, 1.0)
		var pull: float = FLIGHT_ACCEL * (1.0 + 1.4 * near)
		# 【为什么是"投影到径向"而不是 vel += dir * pull * delta】
		# 纯累加只在"宝石本来就朝玩家飞"时才收敛：速度方向要靠加速度慢慢掰回来，
		# 能掰过来的条件是 R < v²/a。v 顶到 MAX_FLIGHT_SPEED(1100)、a 只有 2600 时
		# R 上限是 465px；而铜铃（force）正是从全图之外把这些宝石拉过来的 —— 它们
		# 带着满速和一大截切向分量进场，于是绕着玩家转圈，永远进不了 PICKUP_R，
		# 表现就是"漂浮一会儿"（玩家移动时 100% 复现，静止时无切向分量所以正常）。
		# 把速度投影到径向再累加：切向分量当场丢弃，方向每帧都严格指向玩家，
		# 轨迹退化成纯追逐，distance 单调递减 —— 任何半径都不存在绕飞轨道。
		# 这也顺带解释了下面放宽拾取半径的前提：径向单帧步长必须小于它。
		var speed: float = maxf(vel.dot(dir), 0.0) + pull * delta
		vel = dir * minf(speed, MAX_FLIGHT_SPEED)
		spin = 0.0
	else:
		flying = false
		vel *= maxf(0.0, 1.0 - 6.0 * delta)
		spin = 2.2
	position += vel * delta
	rotation += spin * delta
	if flying:
		# 飞入时略微收缩，配合加速度形成"被吸进去"的挤压感
		var k: float = clampf(0.65 + d / 300.0, 0.65, 1.0)
		scale = Vector2(base_scale, base_scale) * k
	else:
		scale = scale.lerp(Vector2(base_scale, base_scale), clampf(delta * 8.0, 0.0, 1.0))
	return false
