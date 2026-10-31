extends Node2D
class_name PickupField

# =====================================================================
# 三个掉落物（Step 10）：烤鸡 / 磁铁 / 炸弹。
#
# 数值全部来自 params.json pickups 段（v3.1）。
# 【2026-10-30 文档对账】params.json 已 ARCHIVED，本文件常量即现行真值。
#   magnet  drop_rate 0.0005 → 一局约 25 个（每 72 秒一个）
#   bomb    drop_rate 0.0002 → 一局约 10 个，但**必须限流**
#   bento   drop_rate 0.0003 → 一局约 15 个（每 120 秒一个）
#
# 【炸弹为什么必须限流】
# 10 个/局 = 每 3 分钟一次免费清屏。25~30 分钟是设计好的顶压期，
# 在那段拿到炸弹等于直接跳过压力。两条限制同时上：
#   ① Boss 战期间不掉落（Boss 战靠"必须停下来打"提供节奏）
#   ② 每局上限 4 个，超出后该次 roll 转成 1 颗橙色宝石（不浪费判定）
#
# 【磁铁为什么要单独计数】
# 一局 25 个磁铁会把实际拾取率从 0.9 推向 1.0，30 分钟等级从 Lv45 抬到 Lv47。
# 仍在合理带内，但会顶到上沿，所以 Game 里单独暴露 magnets_dropped 供试玩记录。
# =====================================================================

const CAP := 40
const PICKUP_R := 30.0
const MAX_LIFE := 24.0
## 落地后先"弹"一下再静止，和宝石的手感保持一致
const POP_TIME := 0.18

const DEFS: Dictionary = {
	"magnet": {
		"svg": Art.PICKUP_MAGNET,
		"label": "铜铃",
		"drop_rate": 0.0005,
	},
	"bomb": {
		"svg": Art.PICKUP_BOMB,
		"label": "爆竹",
		"drop_rate": 0.0002,
	},
	"bento": {
		"svg": Art.PICKUP_BENTO,
		"label": "糍粑",
		"drop_rate": 0.0003,
	},
}

const BOMB_PER_RUN_CAP := 4
const BENTO_HEAL_PCT := 0.30
const BOMB_DAMAGE := 99999.0

var active: Array[Sprite2D] = []
var _free: Array[Sprite2D] = []
var _age: Dictionary = {}
var _kind: Dictionary = {}
var _game: GameScene = null

func _ready() -> void:
	z_index = 2
	for _i in CAP:
		var s := Sprite2D.new()
		s.visible = false
		add_child(s)
		_free.append(s)

func bind(game: GameScene) -> void:
	_game = game

func count() -> int:
	return active.size()

# ---------------------------------------------------------------- 掉落
## 每次击杀调用一次：按 drop_rate roll 三件。返回掉出来的类型（没掉返回空串）。
## 注意这是"每次击杀"的概率，不是百分比 —— 初版误写 0.015 会一局掉 2255 个。
func roll_drop(pos: Vector2, game: GameScene) -> String:
	if game == null:
		return ""
	var r: float = randf()
	if r < _rate("magnet"):
		spawn(pos, "magnet")
		game.magnets_dropped += 1
		return "magnet"
	r -= _rate("magnet")
	if r < _rate("bomb"):
		# 限流：Boss 战不掉 + 每局上限
		if game.enemies.has_boss() or game.bombs_dropped >= BOMB_PER_RUN_CAP:
			# 超出转成一颗橙色宝石，不浪费这次判定，玩家也不会觉得"白打了"
			game.gems.spawn(pos, 12)
			return "bomb_overflow"
		game.bombs_dropped += 1
		spawn(pos, "bomb")
		return "bomb"
	r -= _rate("bomb")
	if r < _rate("bento"):
		spawn(pos, "bento")
		return "bento"
	return ""

static func _rate(kind: String) -> float:
	return float((DEFS[kind] as Dictionary).get("drop_rate", 0.0))

func spawn(pos: Vector2, kind: String) -> void:
	if not DEFS.has(kind):
		return
	var s: Sprite2D
	if not _free.is_empty():
		s = _free.pop_back()
	else:
		s = Sprite2D.new()
		add_child(s)
	s.texture = Art.tex(String((DEFS[kind] as Dictionary)["svg"]))
	s.position = pos
	s.visible = true
	s.modulate = Color.WHITE
	s.scale = Vector2.ONE * 0.2
	s.rotation = 0.0
	active.append(s)
	_age[s.get_instance_id()] = 0.0
	_kind[s.get_instance_id()] = kind
	# 掉落物是"必须被玩家注意到"的东西：落地扫一次光就够了。
	# 不设 auto_speed（常亮扫光）—— 满屏掉落时会变成一片噪音，反而看不出来哪个能捡。
	ShaderFX.sweep(s, 0.5, 0.05)

func clear_all() -> void:
	for s in active:
		_recycle(s)
	active.clear()
	_age.clear()
	_kind.clear()

func _recycle(s: Sprite2D) -> void:
	# 扫光可能还没播完就被回收（道具 24 秒寿命，很少，但炸弹清屏会一次性清光）。
	# 不清的话下一个复用出来的道具会带着中途的扫光材质出场。
	ShaderFX.clear(s)
	s.material = null
	s.visible = false
	s.scale = Vector2.ONE
	s.modulate = Color.WHITE
	_free.append(s)

# ---------------------------------------------------------------- 每帧
func _process(delta: float) -> void:
	if active.is_empty() or _game == null:
		return
	if not GameManager.started:
		return
	var pp: Vector2 = _game.player.global_position
	for i in range(active.size() - 1, -1, -1):
		var s: Sprite2D = active[i]
		var id: int = s.get_instance_id()
		var age: float = float(_age.get(id, 0.0)) + delta
		_age[id] = age
		# 弹出：0.18s 内 0.2 → 1.0，带一点过冲
		if age < POP_TIME:
			var t: float = age / POP_TIME
			s.scale = Vector2.ONE * (0.2 + 0.8 * t + 0.15 * sin(t * PI))
		else:
			s.scale = s.scale.lerp(Vector2.ONE, clampf(delta * 10.0, 0.0, 1.0))
			# 静止后轻微上下浮动，和宝箱区分开
			s.position.y += sin(age * 3.5) * delta * 6.0
		# 快消失时闪烁提醒
		if age > MAX_LIFE - 3.0:
			s.modulate.a = 0.35 + 0.65 * absf(sin(age * 9.0))
		if s.position.distance_to(pp) < PICKUP_R:
			var kind: String = String(_kind.get(id, ""))
			_pickup(kind, s.position)
			_age.erase(id)
			_kind.erase(id)
			active.remove_at(i)
			_recycle(s)
			continue
		if age >= MAX_LIFE:
			_age.erase(id)
			_kind.erase(id)
			active.remove_at(i)
			_recycle(s)

# ---------------------------------------------------------------- 效果
func _pickup(kind: String, pos: Vector2) -> void:
	match kind:
		"magnet":
			_game.gems.vacuum_all()
			# 文案只写真实效果：铜铃是"把已经掉的灯花全吸过来"，不是"给你经验"
			_game.hud.flash_evolve("铜铃 · 全图灯花归袋")
		"bomb":
			_detonate(pos)
			_game.hud.flash_evolve("爆竹 · 震散周身忘影")
		"bento":
			var stats: Dictionary = GameManager.stats
			var mx: float = float(stats.get("max_hp", 100.0))
			stats["hp"] = minf(mx, float(stats.get("hp", 0.0)) + mx * BENTO_HEAL_PCT)
			_game.hud.flash_evolve("糍粑 · 回血 %d%%" % int(BENTO_HEAL_PCT * 100.0))

## 炸弹：清掉屏内所有非 Boss 敌人。
## Boss 免疫是有意的 —— 否则炸弹在 Boss 战里变成"重开一颗"，节奏断点失效。
func _detonate(pos: Vector2) -> void:
	for e in _game.enemies.active.duplicate():
		if not e.alive or e.is_boss:
			continue
		# 只清"屏内"：取屏幕半径保守值，避免全图扫荡
		if e.global_position.distance_to(pos) > 700.0:
			continue
		e.take_damage(BOMB_DAMAGE)
