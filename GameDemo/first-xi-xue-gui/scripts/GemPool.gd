extends Node2D
class_name GemPool

# 宝石是"贴脸吸进来"手感的关键：落地弹一下 → 静止自转 → 进磁吸圈后加速飞入
const CAP := 400
const MAGNET_BASE := 90.0

var active: Array[Gem] = []
var inactive: Array[Gem] = []

var _player: Player = null

func _ready() -> void:
	var scene: PackedScene = preload("res://scenes/Gem.tscn")
	for _i in CAP:
		var g: Gem = scene.instantiate() as Gem
		g.visible = false
		add_child(g)
		inactive.append(g)

func spawn(pos: Vector2, value: int) -> void:
	if inactive.is_empty():
		return
	var g: Gem = inactive.pop_back()
	g.setup(pos, value)
	g.visible = true
	active.append(g)

func _process(delta: float) -> void:
	if active.is_empty():
		return
	if not GameManager.started:
		return
	if _player == null or not is_instance_valid(_player):
		_player = GameManager.player as Player
		if _player == null:
			return
	var pp: Vector2 = _player.global_position
	var magnet_r: float = MAGNET_BASE * float(GameManager.stats.get("magnet", 1.0))
	var i: int = active.size() - 1
	while i >= 0:
		var g: Gem = active[i]
		if g.tick(delta, pp, magnet_r):
			_collect(g)
			active.remove_at(i)
		i -= 1

func _collect(g: Gem) -> void:
	_recycle(g)
	if _player != null and is_instance_valid(_player):
		_player.gain_xp(g.value)

## 只回收视觉与池位，**不给经验**。清场路径必须走这个 ——
## 清场不是"拾取"，白给经验会把测试里的等级/曲线悄悄推高。
func _recycle(g: Gem) -> void:
	g.visible = false
	inactive.append(g)

## 清空场上所有宝石（重开 / 测试铺场 / 截图前清场）。
## ⚠️ 必须在这里 erase：`_collect()` 只把宝石塞回 inactive 并隐藏，
##    从 active 移除是 `_process` 里随 tick 返回值做的。外部只调 _collect
##    会让 count() 继续把已经收掉的宝石算进去（tests/ 里就踩过这条）。
func clear_all() -> void:
	for g in active:
		_recycle(g)
	active.clear()

## 磁铁道具（铜铃）/ 结算前的"全图吸取"：把屏幕上所有灯花都拉过来。
## ⚠️ 不能靠调 age 实现 —— 吸引条件看的是距离，age 只控制"落地后 0.12s 才启动吸附"。
##    必须置 forced，让它绕过磁吸半径（magnet_r）这一条距离闸。
func vacuum_all() -> void:
	for g in active:
		g.forced = true

func count() -> int:
	return active.size()
