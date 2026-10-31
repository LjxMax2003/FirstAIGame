extends Node2D
class_name DamageNumbers

# ============================================================================
# 伤害飘字 —— 池化的世界层数字
# ----------------------------------------------------------------------------
# 为什么是 Node2D（挂在 World 下）而不是 CanvasLayer：
#   本作有跟随玩家的 Camera2D（position_smoothing 开启），**世界坐标 ≠ 屏幕坐标**。
#   挂在 World 下，Label 直接继承相机变换，pop() 收的就是敌人自己的 global_position，
#   一次换算都不用写。挂在 CanvasLayer 就要走 canvas_transform 反算，
#   而算错的表现是"数字整体朝一个方向漂走"——它不报错，只是看起来像鬼故事。
#
# 为什么每帧手推而不是 create_tween：
#   一次 AoE 能在一帧里弹二十几条。200 条 Tween 抢同一条 SceneTree 时间线，
#   比 200 次浮点加法贵得多；而且"池满时抢最老的一条"要求精确到帧的控制权。
#   这和 WeaponManager 的 Fx 池是同一套思路（那边的注释有完整理由）。
#
# 为什么上限是"抢最老"而不是"丢弃最新"：
#   满屏混战时，玩家真正在看的永远是**刚刚这一下**。丢弃新消息会让最该被看见的
#   那个数字消失，而抢掉一条已经在淡出、alpha 只剩 0.2 的旧数字几乎看不出来。
#
# 为什么分"普通/强调"两个池，而不是弹出时改字号改颜色：
#   这一条是被 P5Perf 打出来的。`add_theme_font_size_override` /
#   `add_theme_color_override` 会触发 NOTIFICATION_THEME_CHANGED → Label 重建
#   文字缓冲、重新整形（shaping）并更新最小尺寸。同屏 400 只、9 把武器乱打时，
#   聚合后仍有上千次/秒的 pop，等于每秒上千次重排版 —— 实测把 400 同屏的 P50
#   从 9.7ms 抬到 12.6ms。
#   改为两个池：普通池和强调池的样式在 _ready 里各设一次，之后 pop() 只写
#   text / position / modulate，零主题写入。
# ============================================================================

## 普通档槽位。40 条 × 0.52s ≈ 可持续 77 条/秒，
## 而敌人侧做了 0.22s 聚合（见 Enemy.DMG_POP_INTERVAL），单个敌人最多 4.5 条/秒，
## 也就是足以覆盖"同屏 17 只正在挨打"且互不顶掉。
const POOL_SMALL := 44
## 强调档（击杀）槽位。击杀峰值约 30 次/秒，0.6s 生命周期 → 同时约 18 条，
## 16 条足够覆盖且不会因为抢池把红字挤成白字。
const POOL_BIG := 16
const POOL_SIZE := POOL_SMALL + POOL_BIG
## 单条飘字的总时长。0.52s 是"读得完但不拖沓"的上限：
## 再长会在人堆里叠成一片，再短则来不及读（60fps 下 0.52s ≈ 31 帧）。
const LIFE := 0.52
## 整体上飘距离（像素）。配合 _process 里的 2t 积分，整条曲线是先快后慢。
const RISE := 30.0
## 生命周期最后这段开始淡出。前 0.28s 保持满不透明，读得清楚才谈得上"看得见"。
const FADE_FROM := 0.24
## 弹出时的收束时长（1.35 → 1.0）。不加这一下，数字像"贴"上去的而不是"弹"出来的。
const PUNCH_TIME := 0.10
## 文本框尺寸。Label 居中排版需要一块固定宽的画布，否则居中是按字形边界算的，
## 位数一变数字就会左右横跳。
const BOX := Vector2(140.0, 44.0)
## 出生高度：抬到敌人头顶上方（敌人本体 48px 高，中心到头顶约 24px）。
const SPAWN_LIFT := 34.0
## 水平抖动，避免同一只敌人连续两次的飘字完全重叠。
const JITTER := 9.0

## 暖白 #FFE9C2：普通命中。取剪纸的宣纸底色，和朱红/暖铜是同一套色板。
const COLOR_HIT := Color(1.0, 0.914, 0.761)
## 朱红 #FF5C38：强调档（本作没有暴击系统，强调档 = **击杀那一击**，见 Enemy.damage_dealt）。
const COLOR_BIG := Color(1.0, 0.361, 0.220)
const SIZE_HIT := 19
const SIZE_BIG := 27

## 一条正在飞的飘字。用内部类而不是并行数组：
## 字段语义各不相同，塞进四个 PackedFloat32Array 只会让 _process 更难读。
class Pop:
	var node: Label
	var left := 0.0
	var total := 1.0
	## 整条生命周期的总位移（不是速度）。_process 里按 2t 积分，走完正好等于它。
	var drift := Vector2.ZERO
	## 弹出时的起始缩放，PUNCH_TIME 内收敛到 1.0
	var scale_from := 1.0
	## 所属档位。回收时必须还回**自己那一档**的空闲表 —— 样式是跟着 Label 走的。
	var big := false

var _pops_small: Array[Pop] = []
var _pops_big: Array[Pop] = []
var _free_small: Array[Label] = []
var _free_big: Array[Label] = []

func _ready() -> void:
	# 预热：池子必须在这里一次性建满。等到战斗中第一次命中才 new Label，
	# 那一下就正好落在"人最多、帧最紧"的时刻（字体首次排版也在那一帧）。
	_make_pool(POOL_SMALL, false, _free_small)
	_make_pool(POOL_BIG, true, _free_big)

func _make_pool(count: int, big: bool, into: Array[Label]) -> void:
	for _i in count:
		var lb := Label.new()
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 深色敌人贴图 + 满屏纸片，没有描边的数字是读不出来的
		lb.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 0.92))
		lb.add_theme_constant_override("outline_size", 4)
		lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		lb.add_theme_constant_override("shadow_offset_x", 1)
		lb.add_theme_constant_override("shadow_offset_y", 2)
		# 字号与颜色只在**这里**设一次；pop() 里绝不能再写主题（见文件头）。
		lb.add_theme_font_size_override("font_size", SIZE_BIG if big else SIZE_HIT)
		lb.add_theme_color_override("font_color", COLOR_BIG if big else COLOR_HIT)
		lb.size = BOX
		lb.pivot_offset = BOX * 0.5
		lb.visible = false
		add_child(lb)
		into.append(lb)

## 在世界坐标 world_pos 处弹一个数字。
##
## @param amount 这一跳的伤害量（已含结壳倍率 —— 玩家看到的必须是他真实打出去的数）
## @param big    true = 强调档（击杀那一击）：字号 19→27、颜色暖白→朱红
func pop(world_pos: Vector2, amount: float, big := false) -> void:
	if amount <= 0.0:
		return
	var lb: Label = _take(big)
	if lb == null:
		return

	var jx: float = randf_range(-JITTER, JITTER)
	var jy: float = randf_range(-4.0, 4.0)

	lb.text = _fmt(amount)
	# 位置以文本框中心为准（Label 的 position 是左上角，所以减半个 BOX）
	lb.position = world_pos + Vector2(jx - BOX.x * 0.5, jy - SPAWN_LIFT - BOX.y * 0.5)
	lb.modulate = Color.WHITE
	lb.scale = Vector2.ONE
	lb.visible = true

	var p := Pop.new()
	p.node = lb
	# 强调档多留 15% 时间：它信息量更大（这是击杀），也该稍微多留一会儿
	p.total = LIFE * (1.15 if big else 1.0)
	p.left = p.total
	p.drift = Vector2(jx * 1.3, -RISE * (1.25 if big else 1.0))
	p.scale_from = 1.35 if big else 1.22
	p.big = big
	if big:
		_pops_big.append(p)
	else:
		_pops_small.append(p)

## 取一个可用 Label。优先本档空闲表，池满则抢本档最老的一条（它已经淡到接近看不见）。
func _take(big: bool) -> Label:
	var free_list: Array[Label] = _free_big if big else _free_small
	if not free_list.is_empty():
		return free_list.pop_back()
	var in_flight: Array[Pop] = _pops_big if big else _pops_small
	if in_flight.is_empty():
		return null
	# pop_front 是最老的一条（数组按加入顺序追加）。O(n) 只在池满时发生，n ≤ 44。
	return in_flight.pop_front().node

func _process(delta: float) -> void:
	_advance(_pops_small, delta)
	_advance(_pops_big, delta)

func _advance(pops: Array[Pop], delta: float) -> void:
	var i: int = pops.size() - 1
	while i >= 0:
		var p: Pop = pops[i]
		p.left -= delta
		if p.left <= 0.0:
			p.node.visible = false
			p.node.scale = Vector2.ONE
			# 还回**自己那一档**的空闲表：样式是跟着 Label 走的，
			# 把强调档的 Label 还进普通池，下一次普通的命中就会冒出一个朱红大字。
			if p.big:
				_free_big.append(p.node)
			else:
				_free_small.append(p.node)
			pops.remove_at(i)
		else:
			var t: float = p.left / p.total          # 1 → 0
			# ∫2t dt 在 [0,1] 上正好等于 1：总位移精确等于 drift，先快后慢
			p.node.position += p.drift * delta * t * 2.0
			p.node.modulate.a = clampf(p.left / FADE_FROM, 0.0, 1.0)
			var age: float = p.total - p.left
			if age < PUNCH_TIME:
				var k: float = 1.0 - age / PUNCH_TIME
				p.node.scale = Vector2.ONE * (1.0 + (p.scale_from - 1.0) * k)
		i -= 1

## 数字格式：1 以上取整（战斗中没人去读小数），1 以下保留一位 —
## 衰减尾声的 AoE 可能只有 0.4 点，显示成 "0" 会让玩家以为"打了没反应"。
static func _fmt(amount: float) -> String:
	if amount < 1.0:
		return "%.1f" % amount
	return "%d" % int(round(amount))

# ---------------------------------------------------------------- 给测试/调试
## 当前在飞的条数（含正在淡出的）
func active_count() -> int:
	return _pops_small.size() + _pops_big.size()

## 池子实际持有的 Label 总数。冒烟测试用它断言"没有越弹越多"。
func label_count() -> int:
	return get_child_count()

## 空闲槽位数（普通档 + 强调档）。用来确认回收把 Label 还回了正确的池。
func free_count() -> int:
	return _free_small.size() + _free_big.size()
