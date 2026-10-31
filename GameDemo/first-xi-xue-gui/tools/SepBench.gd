extends Node

# ============================================================================
# 分离算法的分配开销对照（微基准）
# ----------------------------------------------------------------------------
# 为什么需要这个工具，而不是看 P5Perf：
#   P5Perf 测的是**整帧**，而分离只是其中一小块。同一份代码连跑两次，P95 帧间隔
#   都能从 10.85ms 飘到 17.66ms（±40%），信号完全被机器噪声吃掉。
#   要回答"这次改写到底有没有用"，只能把被改的那段单独摘出来计时。
#
# 对照的是什么：
#   旧实现 = 每个邻居 new 一个 [d, vx, vy] 数组 → sort_custom → 取前 N 求和
#   新实现 = 三个定长 PackedFloat32Array 里做插入排序 → 取前 N 求和
#   两者**语义完全等价**（tools 下有一份 2 万随机用例的等价性验证记录），
#   差别只在分配：旧版每次调用分配 M 个数组 + 1 个 Callable，新版零分配。
#
# 用法：godot --headless --path . res://tools/SepBench.tscn
# ============================================================================

const MAX_NEIGHBORS := 5
## 一轮计时里调用多少次（够长时间稳定，又不至于跑太久）
const ITERS := 20000
## 参与测试的邻居数量：3×3 网格内的候选量级（格宽 40px、敌人半径 12px）
const SIZES: Array[int] = [6, 9, 12, 18, 24]

var _neighbors: Array[Vector2] = []

func _ready() -> void:
	print("\n===== 分离算法：旧（每邻居分配数组 + 排序） vs 新（定长插入排序） =====")
	print("%-8s %-14s %-14s %-10s %-10s" % ["候选数", "旧 µs/次", "新 µs/次", "加速比", "新省分配"])
	for n in SIZES:
		_make_neighbors(n)
		# 各跑一遍丢弃结果：第一次调用要预热 sqrt/数组，不预热会把冷启动算进去
		_old()
		_new()
		var t_old: float = _time_old()
		var t_new: float = _time_new()
		print("%-8d %-14.3f %-14.3f %-10s %-10s" % [
			n, t_old, t_new,
			"%.2f×" % (t_old / maxf(t_new, 0.0001)),
			"%d 个数组" % n,
		])
	print("\n注：只计「距离筛选之后」的那段。网格 3×3 扫描两种实现一样，属于未改动部分。")
	get_tree().quit(0)

## 造一批"贴着原点"的邻居偏移：模拟贴身人群，距离都在半径内
func _make_neighbors(n: int) -> void:
	_neighbors.clear()
	for i in n:
		var ang: float = TAU * float(i) / float(n)
		var d: float = 6.0 + 10.0 * float(i % 3)
		_neighbors.append(Vector2.from_angle(ang) * d)

func _time_old() -> float:
	var t0: int = Time.get_ticks_usec()
	for _i in ITERS:
		_old()
	return float(Time.get_ticks_usec() - t0) / float(ITERS)

func _time_new() -> float:
	var t0: int = Time.get_ticks_usec()
	for _i in ITERS:
		_new()
	return float(Time.get_ticks_usec() - t0) / float(ITERS)

# --- 旧实现（原样保留，作为对照基线，不要"顺手优化"它，那就没有对照意义了）---
func _old() -> Vector2:
	var r: float = 16.0
	var r2: float = r * r
	var buf: Array = []
	for o in _neighbors:
		var dx: float = -o.x
		var dy: float = -o.y
		var d2: float = dx * dx + dy * dy
		if d2 < 0.01 or d2 > r2:
			continue
		var d: float = sqrt(d2)
		buf.append([d, dx / d * (1.0 - d / r), dy / d * (1.0 - d / r)])
	if buf.is_empty():
		return Vector2.ZERO
	buf.sort_custom(_closer_first)
	var out := Vector2.ZERO
	var used: int = mini(buf.size(), MAX_NEIGHBORS)
	for i in used:
		var item: Array = buf[i]
		out.x += float(item[1])
		out.y += float(item[2])
	return out

func _closer_first(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0])

# --- 新实现（与 EnemyPool.separation 的内核一致）---
var _nd := PackedFloat32Array()
var _nx := PackedFloat32Array()
var _ny := PackedFloat32Array()

func _new() -> Vector2:
	if _nd.size() != MAX_NEIGHBORS:
		_nd.resize(MAX_NEIGHBORS)
		_nx.resize(MAX_NEIGHBORS)
		_ny.resize(MAX_NEIGHBORS)
	var r: float = 16.0
	var r2: float = r * r
	var n: int = 0
	var last: int = MAX_NEIGHBORS - 1
	for o in _neighbors:
		var dx: float = -o.x
		var dy: float = -o.y
		var d2: float = dx * dx + dy * dy
		if d2 < 0.01 or d2 > r2:
			continue
		if n == MAX_NEIGHBORS and d2 >= _nd[last]:
			continue
		var d: float = sqrt(d2)
		var vx: float = dx / d * (1.0 - d / r)
		var vy: float = dy / d * (1.0 - d / r)
		var j: int = last if n == MAX_NEIGHBORS else n
		while j > 0 and _nd[j - 1] > d2:
			_nd[j] = _nd[j - 1]
			_nx[j] = _nx[j - 1]
			_ny[j] = _ny[j - 1]
			j -= 1
		_nd[j] = d2
		_nx[j] = vx
		_ny[j] = vy
		if n < MAX_NEIGHBORS:
			n += 1
	if n == 0:
		return Vector2.ZERO
	var out := Vector2.ZERO
	for i in n:
		out.x += _nx[i]
		out.y += _ny[i]
	return out
