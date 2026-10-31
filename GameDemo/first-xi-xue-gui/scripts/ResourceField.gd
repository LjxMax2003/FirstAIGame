extends Node2D
class_name ResourceField

# =====================================================================
# 场景资源点（Step 10）：可破坏物。
#
# 设计意图不是"多一个金币来源"，而是**让走位路线产生策略选择**：
# 资源点散布在场地里，玩家要决定"绕过去打掉"还是"只顾跑"。
# 打掉它有收益（金币 + 偶尔掉落物），但停下来就要挨追。
#
# 实现选择：
# - 无限地图上按世界格哈希**确定性生成**，和 PropField 同一套思路 ——
#   走回去还是同一批资源点，不会闪烁。但被打掉的资源点要记住，否则走开再回来又长出来。
# - 不走物理体，纯距离判定（项目统一约定）。
# - 被拆掉后按 `RESPAWN` 秒在**别的格子**重新生成，避免"清完一片就永远空"。
# =====================================================================

const CELL := 520.0
const RADIUS := 2
## 每格最多几个资源点（0~2 个）
const PER_CELL := 2
## 命中判定半径
const HIT_R := 26.0
## 资源点血量：早期一把鞭弧能拆掉，后期也是几下的事（它不是敌人，不该耗时间）
const HP := 30.0
## 拆掉给的金币
const COIN := 1
## 拆掉有概率掉一个掉落物
const DROP_CHANCE := 0.18

var _camera: Camera2D = null
var _game: GameScene = null
## 已拆掉的资源点：key = "cx,cy,k" → 重生成时间戳
var _broken: Dictionary = {}
## 场上存活的资源点：key → {pos, hp, node}
var _alive: Dictionary = {}
var _texs: Array[Texture2D] = []
var _t := 0.0

func _ready() -> void:
	z_index = -3
	# 资源点直接用场景摆件贴图：项目里没有"墓碑/树"，用消防栓/垃圾桶当可拆物最合乎美术
	_texs = [Art.tex(Art.PROP_HYDRANT), Art.tex(Art.PROP_TRASH), Art.tex(Art.PROP_VENDING)]

func bind(game: GameScene, cam: Camera2D) -> void:
	_game = game
	_camera = cam

func count() -> int:
	return _alive.size()

func _process(delta: float) -> void:
	if _camera == null or _game == null:
		return
	if not GameManager.started:
		return
	_t += delta
	_sync_cells()
	_prune_broken()

## 按玩家周围格子同步资源点：进视野的生成，远处的回收（不销毁生成记录，走回来会原样恢复）
func _sync_cells() -> void:
	# 用**玩家位置**而不是相机位置做锚点。
	#
	# 【为什么不能用相机】
	# 相机开了 position_smoothing，它的中心点比玩家滞后几百毫秒 —— 瞬移/被顶开时
	# 两者会差出好几格。用相机当锚点，会出现"生成范围跟着相机飘，回收范围按相机算，
	# 而玩家已经走远了"的错位，最终表现为走回来少了几个资源点。
	# 玩家位置是权威值，且资源点的设计语义本来就是"玩家周围有什么"。
	var center: Vector2 = _game.player.global_position if _game != null else _camera.get_screen_center_position()
	var cc := Vector2i(int(floor(center.x / CELL)), int(floor(center.y / CELL)))
	# 视野外一圈：RADIUS + 1，保证玩家走过去时资源点已经在场。
	# 生成与回收必须用同一个半径，否则中间会留一圈"回收了却不会再生成"的环。
	var reach: int = RADIUS + 1
	for cx in range(cc.x - reach, cc.x + reach + 1):
		for cy in range(cc.y - reach, cc.y + reach + 1):
			for k in PER_CELL:
				var key: String = "%d,%d,%d" % [cx, cy, k]
				if not _alive.has(key) and not _broken.has(key):
					_spawn_at(key, cx, cy, k)
	# 回收：把超出这一圈的清掉（玩家瞬移时会留下）
	for key in _alive.keys():
		var info: Dictionary = _alive[key]
		var pos: Vector2 = info["pos"]
		var kx: int = int(floor(pos.x / CELL))
		var ky: int = int(floor(pos.y / CELL))
		if absi(kx - cc.x) > reach or absi(ky - cc.y) > reach:
			_despawn(String(key))

func _hash(cx: int, cy: int, salt: int) -> int:
	return absi(cx * 73856093 ^ cy * 19349663 ^ salt * 83492791)

func _spawn_at(key: String, cx: int, cy: int, k: int) -> void:
	# 不是每格都有：哈希决定 0~2 个，避免整片网格感
	var n: int = _hash(cx, cy, 1) % 3
	if k >= n:
		return
	var fx: float = float(_hash(cx, cy, 2 + k) % 1000) / 1000.0
	var fy: float = float(_hash(cx, cy, 3 + k) % 1000) / 1000.0
	var pos := Vector2(
		float(cx) * CELL + fx * CELL,
		float(cy) * CELL + fy * CELL
	)
	var idx: int = _hash(cx, cy, 5 + k) % _texs.size()
	var s := Sprite2D.new()
	s.texture = _texs[idx]
	s.position = pos
	s.scale = Vector2.ONE * 0.75
	add_child(s)
	_alive[key] = {"pos": pos, "hp": HP, "node": s}

func _despawn(key: String) -> void:
	if not _alive.has(key):
		return
	var info: Dictionary = _alive[key]
	var s: Node = info["node"]
	if is_instance_valid(s):
		s.queue_free()
	_alive.erase(key)

func _prune_broken() -> void:
	if _broken.is_empty():
		return
	for key in _broken.keys():
		if _t >= float(_broken[key]):
			_broken.erase(key)

# ---------------------------------------------------------------- 受击
## 武器命中检测入口：返回 true 表示这一发打到了资源点
## 注意顺序必须是"先判敌人、再判资源点"，否则资源点会抢走本该打敌人的伤害。
func try_hit(center: Vector2, radius: float, dmg: float) -> bool:
	if _alive.is_empty():
		return false
	for key in _alive.keys():
		var info: Dictionary = _alive[key]
		var pos: Vector2 = info["pos"]
		if center.distance_to(pos) > radius + HIT_R:
			continue
		var hp: float = float(info["hp"]) - dmg
		info["hp"] = hp
		# 受击闪烁：只改 modulate，和敌人一致。
		# 注意顺序：先闪再判死。如果先 _break（里面会 queue_free），
		# 再挂 0.1s 的复位计时器，计时器触发时精灵已经 free 了。
		var s: Node = info["node"]
		if hp <= 0.0:
			_break(String(key), pos)
		elif is_instance_valid(s):
			(s as Sprite2D).modulate = Color(1.4, 1.1, 1.0)
			_flash_later(String(key))
		return true
	return false

func _flash_later(key: String) -> void:
	# 只把 key（String）传给计时器，不传节点引用。
	#
	# 【为什么不用 bind/lambda 传节点】
	# 资源点被打掉时 _despawn 会 queue_free 掉精灵，而 0.1s 后的复位回调仍然持有
	# 那个已释放的引用。Godot 对"已 free 对象作为绑定参数"的处理会抛
	#   Cannot convert argument 1 from Object to Object / Lambda capture was freed
	# 传 String 就完全绕开这个问题：回调触发时节点可能已经没了，
	# 用 key 重新查一次 _alive，查不到就什么都不做。
	var t: SceneTreeTimer = get_tree().create_timer(0.1)
	t.timeout.connect(_reset_flash.bind(key))

func _reset_flash(key: String) -> void:
	if not _alive.has(key):
		return
	var s: Node = (_alive[key] as Dictionary)["node"]
	if is_instance_valid(s):
		(s as Sprite2D).modulate = Color.WHITE

func _break(key: String, pos: Vector2) -> void:
	_despawn(key)
	# 拆掉后 25~45 秒在别处重生成：够长到"这一片暂时是空的"，
	# 又短到一局里能重复经过同一个区域还看到东西。
	_broken[key] = _t + randf_range(25.0, 45.0)
	if _game == null:
		return
	_game.coins_earned += COIN
	_game.weapons.spawn_spark(pos, 1.1)
	if randf() < DROP_CHANCE:
		_game.pickups.spawn(pos, ["magnet", "bomb", "bento"][randi() % 3])
