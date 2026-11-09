extends Node2D
class_name EnemyPool

signal enemy_died(pos: Vector2, xp: int, kind: String)
## kind 是给「小 Boss 击杀计数」用的（角色解锁条件之一）：
## 三档小 Boss 走的是同一条 elite 通道，不给 kind 就分不清「杀了只墨渍」和「杀了通灵鼓」。
signal elite_died(pos: Vector2, kind: String)
signal boss_died(pos: Vector2)
## 敌人挨打的汇总出口。池子在 _ready 里给每只 Enemy 连一次，
## 之后 Game 只连这一个信号 —— 否则池化复用的敌人需要"每刷一只连一次"，
## 漏连一次就是"那只怪永远不冒数字"，而且不会报错。
signal enemy_damage(pos: Vector2, amount: float, big: bool)

# 文档口径：同屏 300~500 只不掉帧。池子按 540 预分配（含精英）。
const CAP := 540
# 同屏存活上限。params.json spawn.max_alive = 400（"文档 300~500 → 取 400"）。
# 注意这是"存活上限"，不是"应该达到的数量"——实际同屏数由刷怪率与击杀率共同决定。
var max_alive := 400
# 分离检测用空间网格，避免 O(n²)。格宽略大于两只敌人的重叠判定半径。
const GRID_CELL := 40.0
const MAX_NEIGHBORS := 5

var active: Array[Enemy] = []
var inactive: Array[Enemy] = []

var _grid: Dictionary = {}
## separation() 的复用缓冲。
##
## 原来是"每个邻居 new 一个 [d, vx, vy] 数组 + sort_custom"：400 只 × 约 5 个邻居 × 60fps
## ≈ 每秒 12 万次数组分配（144fps 下 29 万次）。GDScript 的数组分配是真实开销，
## 而且 sort_custom 每次都要构造 Callable —— 这是"人一多就一顿一顿"的主要来源之一。
## 改成在三个定长数组里做插入排序：全程零分配，语义完全不变（取最近 MAX_NEIGHBORS 个求和）。
var _near_d2 := PackedFloat32Array()
var _near_x := PackedFloat32Array()
var _near_y := PackedFloat32Array()

func _ready() -> void:
	# 分离缓冲一次分配好，之后每帧只改写下标，不再申请内存
	_near_d2.resize(MAX_NEIGHBORS)
	_near_x.resize(MAX_NEIGHBORS)
	_near_y.resize(MAX_NEIGHBORS)
	var scene: PackedScene = preload("res://scenes/Enemy.tscn")
	for _i in CAP:
		var e: Enemy = scene.instantiate() as Enemy
		e.visible = false
		e.set_process(false)
		e.died.connect(_on_enemy_died.bind(e))
		e.damage_dealt.connect(_on_enemy_damage)
		add_child(e)
		inactive.append(e)

# ---------------------------------------------------------------- 生成 / 回收
## Boss 需要预留池位：max_alive 是"杂兵上限"，Boss 独占一格，
## 否则后期同屏 420 只时 Boss 会 spawn 失败 —— 表现就是"横幅弹了但死神没出现"。
const BOSS_RESERVE := 3

func spawn(pos: Vector2, hp: float, speed: float, xp: int, kind: String, elite: bool = false, damage: float = WaveTable.CONTACT_DAMAGE, boss: bool = false, shelled: bool = false) -> Enemy:
	var limit: int = max_alive if not boss else max_alive + BOSS_RESERVE
	if active.size() >= limit or inactive.is_empty():
		return null
	var e: Enemy = inactive.pop_back()
	e.visible = true
	e.setup(active.size(), pos, hp, speed, xp, kind, elite, damage, boss, shelled)
	active.append(e)
	return e

## 当前存活的 Boss（没有则 null）。Game 用它决定"要不要压刷怪率 / 掉不掉炸弹"。
func boss() -> Enemy:
	for e in active:
		if e.alive and e.is_boss:
			return e
	return null

func has_boss() -> bool:
	return boss() != null

func _on_enemy_damage(pos: Vector2, amount: float, big: bool) -> void:
	enemy_damage.emit(pos, amount, big)

func _on_enemy_died(pos: Vector2, xp: int, kind: String, e: Enemy) -> void:
	enemy_died.emit(pos, xp, kind)
	# 图鉴（T12）：杂兵 / 精英 / Boss 都走同一条 died 信号，所以记录只放在这里。
	# 放在下面那两条分支里会漏掉杂兵；放在 Game 的三个回调里会写三遍，改两处漏一处。
	CodexDB.unlock(kind)
	# 精英/Boss 死讯单独广播：宝箱掉落（进化入口）只认这两条，不跟普通敌人混在一起。
	# 注意这时候 e 已经被 _die() 置 alive=false 并 forget 过，但字段还在，读标记是安全的。
	if e == null:
		return
	if e.is_boss:
		boss_died.emit(pos)
	elif e.is_elite:
		elite_died.emit(pos, e.kind)

func deactivate(e: Enemy) -> void:
	var idx: int = active.find(e)
	if idx >= 0:
		active.remove_at(idx)
	e.visible = false
	e.set_process(false)
	e.alive = false
	modulate_free(e)
	# hate: 不复位会让下一只复用这具尸体的敌人在第一帧被 separation 推到旧格位
	e.grid_key = Vector2i(1 << 30, 1 << 30)
	inactive.append(e)

func modulate_free(e: Enemy) -> void:
	e.modulate = Color.WHITE
	e.scale = Vector2.ONE
	# 贴图本体的染色、位移、缩放都要复位，否则复用时第一帧还带着上一具尸体的状态：
	#   · modulate 不复位 → 第一帧还是红的
	#   · art.scale 不复位 → 上一具尸体没走完的"先胀后塌"会带进来，表现为
	#     "复活的怪比别的怪大一圈"（这是 v9 之前就存在的债，一直被 1.12 的固定放大掩盖着）
	#   · art.position 不复位 → 上一次受击位移的残余会让它在出生帧偏出去 4px
	var a: Sprite2D = e.get_node("Art") as Sprite2D
	a.modulate = Color.WHITE
	a.scale = Vector2.ONE
	a.position = Vector2.ZERO

func clear_all() -> void:
	for e in active.duplicate():
		deactivate(e)
	active.clear()
	_grid.clear()

## 回收尸体。
## 这一条之前是缺的 —— Enemy._die() 只置 alive=false + forget()，没人把它搬回 inactive，
## 于是 active 只增不减：420 只上限撑到就再也刷不出怪，Boss 也永远 spawn 失败。
## 放在 EnemyPool 自己 _process 里做，而不是让 Enemy 自己 deactivate：
## Enemy 的 _process 在死亡时已被关掉，问不到它。
func _process(delta: float) -> void:
	if active.is_empty():
		return
	# v9：尸体的时间走**真实时间**，不吃 Engine.time_scale。
	# 顿帧（PresentationFX 把 time_scale 压到 0.35~0.72）期间，若用缩放后的 delta，
	# 0.045s 的吨帧会变成"尸体的溶解也一起慢下来"，连带 MOB_DISSOLVE 的 0.30s
	# 被拉长成 0.3/time_scale —— HudFxGap 用 [0.21,0.40] 锁死了这个时长，会被打穿。
	# 除以 max(time_scale, 0.01) 而不是判 if：判 if 会在 time_scale=0 时除零。
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	var i: int = active.size() - 1
	while i >= 0:
		var e: Enemy = active[i]
		if e.corpse_expired(real_delta):
			deactivate(e)
		i -= 1

func alive_count() -> int:
	var n: int = 0
	for e in active:
		if e.alive:
			n += 1
	return n

# ---------------------------------------------------------------- 分离网格
func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / GRID_CELL)), int(floor(pos.y / GRID_CELL)))

## 敌人移动后自报新格位：谁移动谁更新，避免"池子刷新早于敌人移动"的整帧滞后
func report(e: Enemy) -> void:
	var key: Vector2i = cell_of(e.global_position)
	if e.grid_key == key:
		return
	_remove_from(e, e.grid_key)
	e.grid_key = key
	if _grid.has(key):
		var bucket: Array = _grid[key]
		bucket.append(e)
	else:
		_grid[key] = [e]

func forget(e: Enemy) -> void:
	_remove_from(e, e.grid_key)
	e.grid_key = Vector2i(1 << 30, 1 << 30)

func _remove_from(e: Enemy, key: Vector2i) -> void:
	if not _grid.has(key):
		return
	var bucket: Array = _grid[key]
	var idx: int = bucket.find(e)
	if idx >= 0:
		bucket.remove_at(idx)
	if bucket.is_empty():
		_grid.erase(key)

## 贴身拥挤度：返回 (0..1)，1 = 已经挤满。
## 用于让"已经贴到玩家身上"的敌人不要再往前顶 —— 没有这一条，
## 所有贴脸敌人会在 STOP_DIST 那一圈互相抵消，形成一层厚壳把玩家包死。
func crowding(e: Enemy, radius: float) -> float:
	var key: Vector2i = e.grid_key
	var r: float = maxf(radius, 8.0)
	var r2: float = r * r
	var n: int = 0
	for gx in range(key.x - 1, key.x + 2):
		for gy in range(key.y - 1, key.y + 2):
			var k := Vector2i(gx, gy)
			if not _grid.has(k):
				continue
			for other in _grid[k]:
				if other == e:
					continue
				var d2: float = e.global_position.distance_squared_to(other.global_position)
				if d2 < 0.01 or d2 > r2:
					continue
				n += 1
	return clampf(float(n) / float(MAX_NEIGHBORS), 0.0, 1.0)

## 返回单位化的分离推力（长度 0~1，已按重叠程度衰减）
## 只累加**最近**的 MAX_NEIGHBORS 个邻居 —— 与原来"全收进来再按距离排序取前 N"等价，
## 但全程零分配。距离用平方比较，`sqrt` 只在实际入选时才做一次。
func separation(e: Enemy, radius: float) -> Vector2:
	var key: Vector2i = e.grid_key
	var r: float = maxf(radius, 8.0)
	var r2: float = r * r
	var n: int = 0
	var last: int = MAX_NEIGHBORS - 1
	var px: float = e.global_position.x
	var py: float = e.global_position.y
	for gx in range(key.x - 1, key.x + 2):
		for gy in range(key.y - 1, key.y + 2):
			var k: Vector2i = Vector2i(gx, gy)
			if not _grid.has(k):
				continue
			for other in _grid[k]:
				if other == e:
					continue
				var dx: float = px - other.global_position.x
				var dy: float = py - other.global_position.y
				var d2: float = dx * dx + dy * dy
				if d2 < 0.01 or d2 > r2:
					continue
				# 缓冲已满且比里面最远的还远 → 连 sqrt 都不用算，直接丢
				if n == MAX_NEIGHBORS and d2 >= _near_d2[last]:
					continue
				var d: float = sqrt(d2)
				var vx: float = dx / d * (1.0 - d / r)
				var vy: float = dy / d * (1.0 - d / r)
				# 插入排序：最多 MAX_NEIGHBORS 格，天然有序，不需要 sort_custom
				var j: int = last if n == MAX_NEIGHBORS else n
				while j > 0 and _near_d2[j - 1] > d2:
					_near_d2[j] = _near_d2[j - 1]
					_near_x[j] = _near_x[j - 1]
					_near_y[j] = _near_y[j - 1]
					j -= 1
				_near_d2[j] = d2
				_near_x[j] = vx
				_near_y[j] = vy
				if n < MAX_NEIGHBORS:
					n += 1
	if n == 0:
		return Vector2.ZERO
	var out := Vector2.ZERO
	for i in n:
		out.x += _near_x[i]
		out.y += _near_y[i]
	return out

func nearest(from: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_d: float = max_dist * max_dist
	for e in active:
		if not e.alive:
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## 美工刀弹射用：最近但不在排除列表（已命中过）里的敌人
func nearest_except(from: Vector2, max_dist: float, exclude: Array[int]) -> Enemy:
	var best: Enemy = null
	var best_d: float = max_dist * max_dist
	for e in active:
		if not e.alive or exclude.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## 找最近的 [param n] 个活敌人，按距离从近到远写入 [param out]。
##
## 打铁花用：每发铁水团各自朝一个最近目标飞，而不是绕圈均分。
## 距离超过 [param max_dist] 的目标不取 —— 宁可少打几发，也不要"对着空气泼"。
## 用插入排序而不是全量排序：同屏 300 只时 n 只有 2~3，O(n·m) 远小于 sort。
func nearest_n(from: Vector2, n: int, max_dist: float, out: Array[Enemy]) -> void:
	out.clear()
	var max_d2: float = max_dist * max_dist
	for e in active:
		if not e.alive:
			continue
		var d2: float = from.distance_squared_to(e.global_position)
		if d2 > max_d2:
			continue
		# 从后往前找插入位，保持 out 按距离升序
		var at: int = out.size()
		while at > 0 and from.distance_squared_to(out[at - 1].global_position) > d2:
			at -= 1
		if at >= n:
			continue  # 比已收的 n 个都远，丢掉
		out.insert(at, e)
		if out.size() > n:
			out.resize(n)

## 找出与指定圆重叠的所有敌人（距离判定，不碰物理引擎）
func query_circle(center: Vector2, radius: float, out: Array[Enemy]) -> void:
	out.clear()
	var r2: float = radius * radius
	for e in active:
		if not e.alive:
			continue
		var rr: float = radius + e.hit_radius()
		if center.distance_squared_to(e.global_position) <= maxf(r2, rr * rr):
			out.append(e)
