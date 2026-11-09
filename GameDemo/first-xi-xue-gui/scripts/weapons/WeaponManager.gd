extends Node2D
class_name WeaponManager

# =====================================================================
# 武器只吃参数（冷却 / 伤害 / 数量 / 范围），玩家零按键。
# 数值全部走 WeaponDB（Step 7 数据驱动）+ GameManager.stats（Step 6 统一管线）：
#   - WeaponDB 提供"这把武器第 L 级长什么样"
#   - stats 提供"玩家当前所有被动乘成什么样"
# 武器自己不存任何成长常量。
#
# 进化（Step 8）：进化形态不是新武器 id，而是在原武器上打一个 evolve 标记，
# 读数值时把 dps_mult / area_mult 乘进去 —— 这样玩家看到的还是同一把武器，
# 武器槽数量不变，符合"进化是把手上的武器变强"的设计意图。
# =====================================================================

const FX_CAP := 64
const BULLET_CAP := 128

## 铜锣冲击波的颜色：金属被敲响的**白热反光**，不是烛火的橙。
## 花灯（halo）是 Color(1.0, 0.5, 0.18) 的暖橙 + Color(1.0, 0.78, 0.42) 的边带，
## 两者同时在场时如果铜锣也用暖橙，就只剩"一大圈橙"（实测截图确认过）。
## G 通道拉到 0.97、B 通道 0.82，色相往白金推，和烛火橙在暗蓝底上直接分开。
const GONG_WAVE_COLOR := Color(1.0, 0.97, 0.82)

## 打铁花铁水的颜色（v6 §4）。橙红而不是纯橙：
## B 卡在 0.10，和花灯的暖金（B 0.42）、铜锣的白金（B 0.82）在色相上完全分开 ——
## 三个"以玩家为中心"的圆形范围表现必须一眼能分辨，这是本工程反复踩过的坑。
const MOLTEN_COLOR := Color(1.0, 0.48, 0.10)
## 铜锣命中时的火星颜色：银白（"命中泛金属光"，v6 §6）。
## 走 art.modulate 而不是挂 hit_flash shader —— 铜锣一次最多打 8 只，
## 逐只挂独立材质就是 8 次 draw call，与 T0 合批红线直接冲突。
const GONG_SPARK_COLOR := Color(1.0, 0.96, 0.88)
## 剪纸弹射点的纸花颜色：纸色（比金粉淡），和糖画的金色迸裂区分开
const PAPER_BLOOM_COLOR := Color(1.0, 0.93, 0.80)

var owned: Dictionary = {}
## 已进化的武器：{ weapon_id: form_id }
var evolved: Dictionary = {}
## 精炼层数：{ weapon_id: tier(0..3) }。武器级乘区，不占卡位、不进 Stats 全局公式。
var refines: Dictionary = {}
var stats: Dictionary = {}
## 本局已经跑了多久（由 Game 每帧同步）。更鼓是时间驱动的全局乘区，
## 武器只读这个数，不自己去累加 —— 否则暂停/升级弹窗期间两边会走偏。
var run_time := 0.0
## 场景资源点（可拆物）。武器命中时顺带判一次 —— 顺序在敌人之后，
## 保证资源点永远不会抢走本该打敌人的伤害。
var resources: ResourceField = null
var _side := 1
var _cd: Dictionary = {}
var _orbit_angle := 0.0
## 环绕物（kind == "orbit"）自己的伤害节拍（迭代01 D-1-F1 / IT-03）。
## 不复用 _cd：_cd 的语义是"离下次开火还有多久"，而环绕物从不"开火"，
## 它只有"多久结算一次接触伤害"。同一个键被两套系统各写一次就是上次的 bug 根因。
var _orbit_cd := 0.0
var _bullets: Array[Bullet] = []
var _zones: Array[Zone] = []
var _fx: Array[Fx] = []
var _fx_free: Array[Sprite2D] = []
var _bullet_free: Array[Sprite2D] = []
var _scratch: Array[Enemy] = []
var _orbit_sprites: Array[Sprite2D] = []
## 皮影残像：与 _orbit_sprites 一一对应的压暗孪生精灵（no material，合批安全）。
var _orbit_ghosts: Array[Sprite2D] = []
## 屏幕光晕的冷却（秒）。打铁花一次泼两发，两团光叠加会过曝；
## 用一个短冷却把"同时碎的两发"合并成一次屏幕闪光。只在 _shatter 里读写。
var _glow_left := 0.0

@onready var _pool: EnemyPool = get_parent().get_node("EnemyPool") as EnemyPool

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.weapons = self
	var spark: Texture2D = Art.tex(Art.FX_SPARK)
	for _i in FX_CAP:
		var s := Sprite2D.new()
		s.texture = spark
		s.visible = false
		add_child(s)
		_fx_free.append(s)

func _process(delta: float) -> void:
	if not GameManager.started or get_tree().paused:
		return
	var player: Node2D = GameManager.player
	if player == null:
		return
	for id in owned.keys():
		var wid: String = String(id)
		_tick_cd(wid, delta)
	if _glow_left > 0.0:
		_glow_left = maxf(0.0, _glow_left - delta)
	_update_orbits(delta, player)
	update_bullets(delta)
	_update_zones(delta)
	update_fx(delta)

func _tick_cd(id: String, delta: float) -> void:
	# 环绕类武器没有"开火"概念，不进开火冷却通道（迭代01 D-1-F1）：
	# 它的伤害节拍由 _update_orbits 里的 _orbit_cd 单独递减与重置。
	if WeaponDB.kind_of(id) == "orbit":
		return
	var left: float = float(_cd.get(id, 0.0)) - delta
	_cd[id] = left
	if left <= 0.0:
		fire(id, GameManager.player)

# ---------------------------------------------------------------- 背包
func acquire(id: String) -> void:
	if owned.has(id) or not WeaponDB.has_weapon(id):
		return
	owned[id] = 1
	# 环绕类武器不写 _cd（写了会被 _tick_cd 当开火冷却递减，而它根本没有开火分支）；
	# 首轮伤害节拍由 _orbit_cd 承担（迭代01 D-1-F1 / IT-03）
	if WeaponDB.kind_of(id) == "orbit":
		_orbit_cd = WeaponDB.first_delay(id)
	else:
		_cd[id] = WeaponDB.first_delay(id)
	# 图鉴（T12）：「拿到过」就是收录条件。挂在 acquire 而不是卡片点击上 ——
	# 进化、宝箱、起始武器都会走到这里，只有 acquire 是"拥有"的唯一入口。
	CodexDB.unlock(id)

func level_of(id: String) -> int:
	return int(owned.get(id, 0))

func has_weapon(id: String) -> bool:
	return owned.has(id)

func weapon_level(id: String) -> int:
	return int(owned.get(id, 0))

func stat(key: String) -> float:
	return float(stats.get(key, 1.0))

## 全工程唯一的"角色中心"口径（迭代04 收尾 D-15）。
##
## 坐标约定：
##   · 玩家 / 敌人的节点 origin 都在**脚底**（贴图靠 art.offset 上抬）；
##   · 可见身体中心 = origin + (0, -ART_FOOT_OFFSET)；
##   · 所有"以玩家为圆心"的技能（花灯判定、铜锣震波、皮影轨道）一律用本函数。
## 视觉与判定必须同源：视觉圈画在身体中心，判定圈也从身体中心量，
## 否则会在半径边界上出现"看着在圈外却被打到 / 看着在圈里却没吃到"。
## 敌人一侧仍按各自 origin（脚底）参与距离判定 —— 与皮影轨道沿用的既有口径一致，
## 相对半径（≥70px）的 18px 偏差在边界容差（hit_radius ≥17px）内。
func _visual_center(player: Node2D) -> Vector2:
	return player.global_position + Vector2(0.0, -Player.ART_FOOT_OFFSET)

func is_evolved(id: String) -> bool:
	return evolved.has(id)

func evolution_of(id: String) -> String:
	return String(evolved.get(id, ""))

## 进化倍率：没进化就是 1.0，进化了读配方表
func _dps_mult(id: String) -> float:
	if not evolved.has(id):
		return 1.0
	var form: Dictionary = EvolutionDB.form(String(evolved[id]))
	return float(form.get("dps_mult", 1.0))

func _area_mult(id: String) -> float:
	if not evolved.has(id):
		return 1.0
	var form: Dictionary = EvolutionDB.form(String(evolved[id]))
	return float(form.get("area_mult", 1.0))

## 贴图出口：进化了且进化图确实存在就换图，否则回落普通图。
## 三把 v5 新武器共用一个出口，避免"进化了但还是老图"的分支各写一遍。
func _weapon_tex(id: String, fallback: String) -> String:
	if not evolved.has(id):
		return fallback
	var evo: String = Art.evolved_weapon_svg(id)
	return evo if evo != "" else fallback

# ---------------------------------------------------------------- 精炼 / 更鼓
## 精炼层数（0..3）
func refine_tier(id: String) -> int:
	return int(refines.get(id, 0))

func set_refine(id: String, tier: int) -> void:
	refines[id] = clampi(tier, 0, Stats.REFINE_MAX)

func refine_mult(id: String) -> float:
	return Stats.refine_mult(refine_tier(id))

## 更鼓乘区：每过一更全场手艺 +8%，30min 收在 1.40。
## 它乘在**最终伤害**上（和被动、进化、精炼同一层），因为它代表"这一夜越深，手上的活越顺"，
## 不是某把武器的特性。
func drum_mult() -> float:
	return WaveTable.drum_mult(run_time)

## 统一伤害出口：基础伤害 × 被动 × 进化 × 精炼 × 更鼓。
## 所有 fire_xxx 都必须走这里 —— 散写的话，以后加一个乘区就要改十几处，而且必漏。
func weapon_damage(id: String, lv: int) -> float:
	return WeaponDB.damage_at(id, lv, stat("damage")) \
		* _dps_mult(id) * refine_mult(id) * drum_mult()

## 显示名：进化后显示进化名
func display_name(id: String) -> String:
	if evolved.has(id):
		var form: Dictionary = EvolutionDB.form(String(evolved[id]))
		if not form.is_empty():
			return String(form.get("name", WeaponDB.display_name(id)))
	return WeaponDB.display_name(id)

## 光环的实际判定半径（玩家脚下的光圈与之一致）
func halo_radius() -> float:
	var lv: int = maxi(weapon_level("halo"), 1)
	var d: Dictionary = WeaponDB.def("halo")
	var base: float = float(d.get("radius", 70.0))
	var per: float = float(d.get("radius_per_level", 7.0))
	var r: float = (base + per * float(lv - 1)) * stat("area") * _area_mult("halo")
	return r

## 铜锣的实际判定半径（第二光环位）。Player 用它在两者并存时画大的那个圈。
func gong_radius() -> float:
	var lv: int = maxi(weapon_level("gong"), 1)
	var d: Dictionary = WeaponDB.def("gong")
	var base: float = float(d.get("radius", 150.0))
	var per: float = float(d.get("radius_per_level", 10.0))
	return (base + per * float(lv - 1)) * stat("area") * _area_mult("gong")

# ---------------------------------------------------------------- 构筑 DPS（主动技读它）
## 当前构筑的**单体** DPS：只算单点武器，每把按"每击伤害 / 冷却"累计。
## 这正是 v5_model.py 里 `single` 的口径（dmg/cd，不含命中数）——
## 主动技"250% 单体 DPS"必须和模型说同一个数，否则两边的强度无法对照。
func single_dps() -> float:
	var sum: float = 0.0
	for id in owned.keys():
		var wid: String = String(id)
		if WeaponDB.dmg_kind(wid) != "single":
			continue
		var lv: int = maxi(int(owned[wid]), 1)
		var cd: float = maxf(WeaponDB.cooldown_at(wid, lv, stat("cooldown")), 0.12)
		sum += weapon_damage(wid, lv) / cd
	return sum

## 粗口径总 DPS（每把按"单发伤害 × 发数 / 冷却"）。只给主动技的"纯 AoE 回落"用，
## 不参与任何平衡验收 —— 精确的命中数只有 Enemy 排布才知道。
func total_dps() -> float:
	var sum: float = 0.0
	for id in owned.keys():
		var wid: String = String(id)
		var lv: int = maxi(int(owned[wid]), 1)
		var cd: float = maxf(WeaponDB.cooldown_at(wid, lv, stat("cooldown")), 0.12)
		var n: int = 1
		if wid == "glowstick":
			n = WeaponDB.count_at(wid, lv)
		elif wid == "extinguisher":
			n = int(WeaponDB.def(wid).get("count", 2))
		sum += weapon_damage(wid, lv) * float(maxi(n, 1)) / cd
	return sum

# ---------------------------------------------------------------- 统一入口
## 按 id 分发到具体武器。新增武器只需在 WeaponDB 加数据 + 这里加一行。
func fire(id: String, player: Node2D) -> void:
	match id:
		"whip":
			fire_whip(player)
		"halo":
			fire_halo(player)
		"glowstick":
			fire_projectile(player, "glowstick")
		"blade":
			fire_projectile(player, "blade")
		"extinguisher":
			fire_extinguisher(player)
		"gong":
			fire_gong(player)
		"inkline":
			fire_inkline(player)
		"print":
			fire_print(player)
		# 皮影（phone）没有开火分支：它是持续环绕，伤害节拍走 _orbit_cd（迭代01 D-1-F1）

# ---------------------------------------------------------------- 鞭弧
func fire_whip(player: Node2D) -> void:
	var lv: int = maxi(weapon_level("whip"), 1)
	var d: Dictionary = WeaponDB.def("whip")
	_cd["whip"] = WeaponDB.cooldown_at("whip", lv, stat("cooldown"))
	var area_mul: float = stat("area") * _area_mult("whip")
	var length: float = (float(d.get("length", 110.0))
		+ float(d.get("length_per_level", 12.0)) * float(lv - 1)) * area_mul
	length = minf(length, float(d.get("length_cap", 260.0)))
	var width: float = float(d.get("width", 64.0)) * area_mul
	var dmg: float = weapon_damage("whip", lv)

	var p: Vector2 = player.global_position
	var sign_x: float = 1.0 if _side > 0 else -1.0
	var x0: float = p.x if _side > 0 else p.x - length
	var x1: float = p.x + length if _side > 0 else p.x
	_side = -_side
	var y0: float = p.y - width * 0.5
	var y1: float = p.y + width * 0.5

	# 距离判定：矩形区间内即命中（不建物理体）
	_sweep_rect(x0, x1, y0, y1, dmg)
	# 资源点：用矩形中心 + 半长做近似圆判定。只在有资源点时才走，零开销。
	if resources != null:
		var mid := Vector2((x0 + x1) * 0.5, p.y)
		resources.try_hit(mid, maxf(length * 0.5, width * 0.5), dmg)

	# v5：Lv7/Lv8 扫两次（各 60% 伤）。
	# 为什么用"次数"而不是继续加长度：length_cap 260 在 Lv7 就撞帽了，
	# 再长会变成半个屏幕的结构性清屏；而"再补一刀"既读得出"这把刀更快了"，
	# 又不会改判定几何 —— 第二刀复用同一个矩形，只是把伤害乘 0.6 再来一次。
	# 错开 0.12s：同一帧打两次只会看到一次火花，读不出"扫了两下"。
	# ⚠️ 这里不能用 await —— fire_* 必须保持同步，await 会把它变成协程，
	#    _tick_cd 的调用点会拿到一个未完成的协程，第二刀就静默丢了。
	var dbl_from: int = int(d.get("double_sweep_from", 7))
	if bool(d.get("double_sweep", false)) and lv >= dbl_from:
		var ratio: float = float(d.get("double_sweep_ratio", 0.60))
		if evolved.has("whip"):
			# 迭代03 M-02 火神开脸：回手第二刀改竖劈，与第一刀成十字。
			# 竖劈的"长"取横扫的 length、"宽"取横扫的 width —— 判定旋转 90°，
			# 不改任何数，只改几何朝向。玩家开脸后会突然能打到贴身上下的怪。
			var vx0: float = p.x - width * 0.5
			var vx1: float = p.x + width * 0.5
			var vy0: float = p.y - length * 0.5
			var vy1: float = p.y + length * 0.5
			_delay_sweep(vx0, vx1, vy0, vy1, dmg * ratio)
			_delay_arc_v(p, length, width, lv)
		else:
			_delay_sweep(x0, x1, y0, y1, dmg * ratio)
			# 第二刀的**视觉**。原先是只补判定不补画面 —— 玩家血条对面掉了，屏幕上一片安静，
			# 读起来像"数字 bug"而不是"又扫了一刀"。v6 §5 要求 slash_arc 双段，就是这个缺口。
			_delay_arc(p, length, width, sign_x, lv)

	var arc: Sprite2D = _take_fx(Art.WHIP_ARC)
	arc.position = Vector2(p.x + sign_x * length * 0.30, p.y + width * 0.06)
	arc.rotation = 0.0
	arc.flip_h = sign_x < 0.0
	arc.scale = Vector2(0.9, 1.15) * (length / 115.0)
	arc.modulate = Color(1.0, 1.0, 1.0, 0.95)
	_push_fx(arc, 0.16, 1.55, 1.15)

	# ① 扫出：原先是整条弧瞬间出现，读不出"挥"这个动作。
	# 遮罩式 shader 只挡掉"还没扫到"的部分，nuo_blade_arc.svg 的笔触原样保留。
	# flip 传 false —— 方向已经由上面的 flip_h 翻转，这里再翻会翻回去（双重翻转 = 不动）。
	# restore 传 false —— arc 是池化精灵，_take_fx 取出时会自己剥材质，省一次赋值。
	ShaderFX.slash(arc, 0.12, false, false)

	# ② 出招冲击环：压成椭圆贴住矩形判定。
	# 画成正圆会读成"圆形范围"，而实际命中区是 length × width 的矩形，
	# 玩家按圆环去预判走位就会错。长轴 = 整个横扫跨度，短轴 = 判定宽度。
	# rays 传 0（纯环）：扁率 0.29 时径向光条会被压成十几条横线，
	# 和弧光叠在一起读作"速度线"，反而看不出范围。
	ShaderFX.burst_ellipse(
		self, Vector2((x0 + x1) * 0.5, p.y), length * 2.0, width,
		Color(1.0, 0.84, 0.52), 0, 0.26
	)

## 矩形横扫判定（师刀一次挥击的几何）
func _sweep_rect(x0: float, x1: float, y0: float, y1: float, dmg: float) -> void:
	for e in _pool.active:
		if not e.alive:
			continue
		var ep: Vector2 = e.global_position
		var r: float = e.hit_radius()
		if ep.x >= x0 - r and ep.x <= x1 + r and ep.y >= y0 - r and ep.y <= y1 + r:
			e.take_damage(dmg, &"whip")
			spawn_spark(ep, 0.8)

## 第二刀：0.12s 后用节点自己的 tween 补一次判定。
## 用 create_tween（绑定本节点）而不是 SceneTreeTimer —— 重开一局时 tween 随场景销毁，
## 不会在已释放的节点上回调（那会报 Object not found）。
func _delay_sweep(x0: float, x1: float, y0: float, y1: float, dmg: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(_sweep_rect.bind(x0, x1, y0, y1, dmg))

## 第二刀的弧光：晚 0.12s、反向挥（flip=true）、略小一点。
## 为什么反向而不是同向再来一次：同向连挥两下，两帧弧光几乎完全重合，
## 加法混合下只是"更亮一次"；反向才有"回手补一刀"的形状。
func _delay_arc(p: Vector2, length: float, width: float, sign_x: float, lv: int) -> void:
	var tw: Tween = create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(_second_arc.bind(p, length, width, sign_x, lv))

func _second_arc(p: Vector2, length: float, width: float, sign_x: float, lv: int) -> void:
	var arc: Sprite2D = _take_fx(Art.WHIP_ARC)
	arc.position = Vector2(p.x + sign_x * length * 0.24, p.y + width * 0.12)
	arc.rotation = 0.0
	arc.flip_h = sign_x > 0.0    # 与第一刀相反
	arc.scale = Vector2(0.9, 1.15) * (length / 115.0) * 0.92
	# Lv8 觉醒「怒目傩面」：第二刀染暗红，读作"另一张脸补的"。
	# 只在这把武器满级时上色 —— 平时两刀同色，才不会让 Lv7 就看起来像满级。
	# 迭代03 M-08：开脸后不再染红 —— "开脸"是另一条视觉通道（spawn_evolve 的暖红），
	# 两条同时染红会让玩家以为"红=满级"就是开脸。
	arc.modulate = Color(1.0, 0.54, 0.48, 0.95) \
		if lv >= WeaponDB.MAX_LEVEL and not evolved.has("whip") \
		else Color(1.0, 1.0, 1.0, 0.95)
	_push_fx(arc, 0.16, 1.55, 1.15)
	ShaderFX.slash(arc, 0.12, true, false)

# ---------------------------------------------------------------- 光环
func fire_halo(player: Node2D) -> void:
	var lv: int = maxi(weapon_level("halo"), 1)
	_cd["halo"] = WeaponDB.cooldown_at("halo", lv, stat("cooldown"))
	var radius: float = halo_radius()
	var dmg: float = weapon_damage("halo", lv)
	var d: Dictionary = WeaponDB.def("halo")
	var slow_pct: float = float(d.get("slow_pct", 0.22))
	var slow_dur: float = float(d.get("slow_duration", 0.6))
	# v5：对"已经慢下来"的敌人 +20% 伤。
	# 读的是**命中前**的减速状态 —— 先判再上减速，否则第一下就吃到加成，
	# 等于变成"花灯无条件 +20%"，那就不需要把怪留在圈里了。
	var slow_bonus: float = float(d.get("slow_dmg", 0.20))
	# 迭代04 收尾（D-15）：判定圆心 = 可见环圆心 = 角色身体中心（_visual_center）。
	var center: Vector2 = _visual_center(player)
	_pool.query_circle(center, radius, _scratch)
	if not _scratch.is_empty():
		for e in _scratch:
			var dealt: float = dmg * (1.0 + slow_bonus) if e.is_slowed() else dmg
			e.take_damage(dealt, &"halo")
			# 减速而不是推开：推开会让敌人永远进不了贴身判定，等于无声无敌
			e.apply_slow(slow_pct, slow_dur)
		var p: Player = player as Player
		if p != null:
			p.garlic_ring.beat()
		# 灯晕"跳一下"：只在**真的烧到东西**时才放，不是每次冷却都放。
		# 光环 cd 只有 0.5s，若每次都放，画面会变成常亮的环——反而看不出命中。
		# rays = 0：纯环不带光条，和"灼烧"的语义一致，光条读起来像"爆炸"。
		# 与判定圆同源（center 就是 _visual_center 的返回值），不再另加偏移。
		ShaderFX.burst_ellipse(
			self, center, radius * 2.0, radius * 2.0,
			Color(1.0, 0.78, 0.32), 0, 0.28
		)
	if resources != null:
		resources.try_hit(center, radius, dmg)

# ---------------------------------------------------------------- 弹道类（荧光棒 / 美工刀）
func fire_projectile(player: Node2D, id: String) -> void:
	var lv: int = maxi(weapon_level(id), 1)
	var d: Dictionary = WeaponDB.def(id)
	var range_px: float = float(d.get("range", 500.0))
	var target: Enemy = _pool.nearest(player.global_position, range_px)
	if target == null:
		# 没有目标就短冷却重试，避免空转浪费一整个周期
		_cd[id] = 0.25
		return
	_cd[id] = WeaponDB.cooldown_at(id, lv, stat("cooldown"))
	var count: int = WeaponDB.count_at(id, lv) if id == "glowstick" else int(d.get("count", 1))
	var dmg: float = weapon_damage(id, lv)
	var tex_path: String = String(d.get("bullet_svg", d.get("svg", "")))
	var speed: float = float(d.get("bullet_speed", 420.0))
	# 弹射距离随火候缩放：原来固定 260，点满范围被动对它完全无效（"范围"读起来像假的）
	var bounce_r: float = float(d.get("bounce_range", 240.0))
	if bool(d.get("bounce_range_scaled", false)):
		bounce_r *= stat("area") * _area_mult(id)
	for i in count:
		var dir: Vector2 = (target.global_position - player.global_position).normalized()
		if count > 1:
			dir = dir.rotated(deg_to_rad(9.0 * float(i) - 4.5 * float(count - 1)))
		var node: Sprite2D = _take_bullet(tex_path)
		var b := Bullet.new()
		b.id = id
		b.pos = player.global_position + dir * 22.0 + Vector2(0.0, -12.0)
		b.vel = dir * speed
		b.life = 1.5
		b.dmg = dmg
		# 穿透里程碑：Lv4 / Lv8 各 +1（不是每级线性给）
		b.pierce = WeaponDB.pierce_at(id, lv)
		b.bounce = int(d.get("bounce", 0))
		# 剩余弹射次数独立计次（迭代01 D-2-F1）：bounce 是类型判据不能动，计次走这里
		b.bounces_left = b.bounce
		b.bounce_range = bounce_r
		b.radius = float(d.get("bullet_radius", 12.0))
		b.node = node
		node.global_position = b.pos
		node.rotation = dir.angle()
		node.scale = Vector2(1.0, 1.0) if id != "glowstick" else Vector2(1.15, 1.15)
		# 糖丝的弹体是一根"线"，它的卖点就是"拉丝穿透"（见 WeaponDB 的 desc）。
		# 原先让它自转 6 rad/s，读起来只是根转着的短棒；改成沿飞行方向摆正 + 拖尾，
		# 才真的看得出"糖丝被拉出去"。打铁花的罐子是抛投物，自转是对的，保持不动。
		if id == "glowstick":
			b.spin = 0.0
			ShaderFX.set_trail(node, 0, Color(1.0, 0.9, 0.62))
			# 糖丝源图只有 32x16，默认尾长（贴图 55%）落在 48px 的弹体上只有约 17px，
			# 实际量出来只让画面亮 16% —— "拉丝"这个词读不出来。拉到 0.85 才是"被拉出去"。
			# intensity 1.2 仍在文档 §5 的红线内（>1.5 会烧成白条）。
			var tm: ShaderMaterial = node.material as ShaderMaterial
			if tm != null:
				tm.set_shader_parameter("stretch", 0.85)
				tm.set_shader_parameter("intensity", 1.2)
		elif id == "blade":
			# 弹射时 rotation 每帧对齐 velocity，贴图的本地 +X 就是飞行方向
			ShaderFX.set_trail(node, 0, Color(1.0, 0.86, 0.55))
		_bullets.append(b)

# ---------------------------------------------------------------- 打铁花（抛射溅射）
## 每发铁水团**各自朝一个最近目标**飞。
##
## 改这里之前是 `base_ang = randf() * TAU` 然后 360/count 均分 —— 两个后果都很难看：
##   ① 永远背靠背 180°，和场上敌人毫无关系，玩家读不出"它是冲着谁去的"；
##   ② 偶尔整组朝空地泼，2 发全废，而卡面写的是"铁水泼洒"（暗示有方向）。
## 现在按距离取最近 count 只，一只一发；场上不足 count 只时多余的弹体
## **朝已有目标的角度散开一点补足**（数量契约不变：卡面/DPS 都按 count 算）。
func fire_extinguisher(player: Node2D) -> void:
	var lv: int = maxi(weapon_level("extinguisher"), 1)
	var d: Dictionary = WeaponDB.def("extinguisher")
	_cd["extinguisher"] = WeaponDB.cooldown_at("extinguisher", lv, stat("cooldown"))
	var count: int = maxi(int(d.get("count", 2)), 1)
	var dmg: float = weapon_damage("extinguisher", lv)
	var speed: float = float(d.get("bullet_speed", 300.0))
	var origin: Vector2 = player.global_position
	# 搜索半径：弹体寿命 × 速度，再加上溅射半径 —— 再远的敌人打不到，
	# 锁定它等于让这一发白飞。这里不用无限远，避免"追着屏幕外的怪泼"。
	var reach: float = speed * 1.9 + float(d.get("scatter_radius", 150.0))
	_pool.nearest_n(origin, count, reach, _scratch)
	# 角度来源：有目标就取目标方向；一个都没有才退回均分（此时没有"最近敌人"可言）
	var angles: Array[float] = []
	for e in _scratch:
		angles.append((e.global_position - origin).angle())
	if angles.is_empty():
		var fallback: float = randf() * TAU
		for i in count:
			angles.append(fallback + TAU * float(i) / float(count))
	else:
		# 目标不足 count 只：以平均方向为轴，把差额对称摊开（±18°、±36°…）
		# 不重新随机，否则同一次开火的两发会指向完全无关的地方
		var base: Vector2 = Vector2.ZERO
		for a in angles:
			base += Vector2.from_angle(a)
		var mean: float = base.angle() if base.length() > 0.001 else angles[0]
		var filled: int = angles.size()
		var k: int = 0
		for i in range(filled, count):
			# 交替左右：1 → -18°, 2 → +18°, 3 → -36°…
			k += 1
			var step: float = deg_to_rad(18.0) * float((k + 1) / 2)
			angles.append(mean + (step if (k % 2) == 1 else -step))
	# v6：弹体换成 molten_blob（熔核 + 外晕）。
	# 原来抛的是**铁花勺**（iron_flower_ladle）——那是武器本体，不是扔出去的东西；
	# 截图里读起来像"把整把勺子甩了出去"，和"泼铁水"完全不是一回事。
	# 只在**演出层**换图，不动 WeaponDB：数据表里的 svg 仍然是武器本体，
	# 卡面/槽位/进化图都靠它，换过去会让三处一起变成弹体。
	var bullet_tex: String = Art.MOLTEN_BLOB
	var bullet_edge: float = float(d.get("bullet_radius", 18.0)) * 2.0
	for i in count:
		var ang: float = angles[i]
		var dir: Vector2 = Vector2.from_angle(ang)
		var node: Sprite2D = _take_bullet(bullet_tex)
		var b := Bullet.new()
		b.id = "extinguisher"
		b.pos = origin + dir * 20.0
		b.vel = dir * speed
		b.life = 1.9
		b.dmg = dmg
		# 抛射全穿，但每个目标只结算一次
		b.pierce = 9999
		b.hit_cap = int(d.get("hit_cap", 4))
		b.radius = float(d.get("bullet_radius", 18.0))
		b.node = node
		node.global_position = b.pos
		node.rotation = ang + TAU * 0.25
		# 源图 24×24：按判定直径折算，弹体的视觉尺寸才等于它的碰撞尺寸
		node.scale = Vector2.ONE * (bullet_edge / 24.0)
		_bullets.append(b)


# ---------------------------------------------------------------- 铜锣（大半径声波）
## 第二光环位：比花灯大得多、慢得多，吃"满级 8 目标"的上限。
## 与花灯的分工是节奏而非范围 —— 花灯每 0.5s 磨一次，铜锣每 1.8s 砸一片。
func fire_gong(player: Node2D) -> void:
	var lv: int = maxi(weapon_level("gong"), 1)
	var d: Dictionary = WeaponDB.def("gong")
	_cd["gong"] = WeaponDB.cooldown_at("gong", lv, stat("cooldown"))
	# 铜锣是本作唯一有专属音效的武器：这一声"咚"就是它的判定读数的一部分，
	# 所以放在冷却写入之后、命中结算之前 —— 空敲也要响，否则玩家会以为技能没触发。
	Audio.play_sfx("gong")
	var radius: float = (float(d.get("radius", 150.0))
		+ float(d.get("radius_per_level", 10.0)) * float(lv - 1)) * stat("area") * _area_mult("gong")
	var dmg: float = weapon_damage("gong", lv)
	var cap: int = int(d.get("hit_cap", 8))
	# 判定圆心与震波 / 锣面同源（_visual_center，D-15）：否则画在身体中部、
	# 判在脚底，半径边界上会出现 18px 的"看着在圈外却被打到"。
	var center: Vector2 = _visual_center(player)
	_pool.query_circle(center, radius, _scratch)
	if _scratch.is_empty():
		if resources != null:
			resources.try_hit(center, radius, dmg)
		return
	for e in _nearest_n(center, cap):
		# 铜锣自带 amp=0.12（对结壳敌人 +12%），倍率由 Enemy.damage_multiplier 按 id 判
		e.take_damage(dmg, &"gong")
		# 命中泛"金属光"：白色火花（不是暖金）。
		# 走 modulate 而不是 hit_flash shader —— 一敲最多 8 只，逐只挂独立材质
		# 就是 8 次 draw call，和 T0 合批红线直接冲突（v6 §6 的"金属光"在这里兑现）。
		spawn_spark(e.global_position, 0.7, GONG_SPARK_COLOR)
	if resources != null:
		resources.try_hit(center, radius, dmg)
	# ---- 视觉：一声"咚"，不是一个圈在"烧" ----
	# 铜锣和花灯都是"以玩家为中心的一圈暖色"，叠在一起时肉眼分不开（实测过）。
	# 拉开靠三件事，缺一件就会重新糊回去：
	#   ① 形状：铜锣带径向声波刺 + 一圈回震向内收；花灯是光滑环且只往外推
	#   ② 色相：铜锣是金属被敲响的白热反光（近白暖金）；花灯是烛火的橙
	#   ③ 尺寸：铜锣半径约为花灯的 1.8 倍，一次性炸到边界就没了
	# 圆心与判定同源（_visual_center）：震波画在脚底会读成"圈歪了"。
	ShaderFX.shockwave(self, center, radius * 2.0, GONG_WAVE_COLOR, 16, 0.30)
	# Lv8 觉醒：每脉冲再外扩**一圈**声波环（v6 §6「锣面震波实化为扩散金环」）。
	# 只加环、不加伤害 —— 这是"满级"的视觉读法，不是第二个结算口。
	# 半径 1.26×：比主波远一档，两圈同屏时一眼能数出"荡了两下"；
	# 若与主波同半径，加法混合会让它糊进第一圈里，等于没加。
	# 迭代03 M-08：开脸后这一圈让位给"回响"（_gong_echo 的第二圈）。
	# 否则开脸那一下同屏三圈（满级外扩 + 主波 + 回响），读不出"回响"是新东西。
	if lv >= WeaponDB.MAX_LEVEL and not evolved.has("gong"):
		ShaderFX.burst_ellipse(
			self, center, radius * 2.0 * 1.26, radius * 2.0 * 1.26,
			Color(1.0, 0.86, 0.46), 20, 0.34, 0.16
		)
	# 锣面本体：这是"铜锣"这个技能唯一的实体，也是玩家认出它的锚点。
	# （旧的写法把它塞进 _push_fx 的线性淡出，第一帧就开始掉 alpha，等于只闪了一下）
	var face: Sprite2D = _take_fx(_weapon_tex("gong", Art.GONG))
	# 落到玩家之下（Player 在 z = -1）：锣面是不透明的实心圆盘，
	# 盖在头上会让人"看不见自己在哪" —— 走位信息比这个特效重要得多。
	face.z_index = -2
	# 用 global_position 而不是 position：face 是 WeaponManager 的子节点，
	# 若 Weapons 自身有位移（当前在原点但不保证永远），局部坐标会偏。
	# 圆心与判定同源（_visual_center）：锣面画在脚底会读成"圈歪了"。
	face.global_position = center
	face.rotation = randf_range(-0.05, 0.05)
	face.flip_h = false
	# 范围直径的 0.42。这个数是被"看得见声波"卡住的：
	# 再大一点（0.62 试过）锣面就有 270px，把刚炸出来、还在它身下的小半径声波
	# 整个挡住 —— 玩家只看到一个大金盘，看不到"咚"。
	face.scale = Vector2.ONE * (radius * 2.0 / 96.0 * 0.42)
	# 纯白不压暗：锣面是玩家认出"这是铜锣"的唯一实体，得比那圈冷白声波更亮
	face.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_ring_face_anim(face)
	if evolved.has("gong"):
		# 迭代03 M-06 开市锣：锣声有回响 —— 0.28s 后原地再响一次，45% 伤 + 短控。
		# 用 tween 而不是 await：fire_* 必须保持同步（与 :303-304 同一个理由）。
		var tw: Tween = create_tween()
		tw.tween_interval(0.28)
		tw.tween_callback(_gong_echo.bind(center, radius, dmg * 0.45, cap))

# ---------------------------------------------------------------- 墨斗（直线穿透）
## 单点头牌 + 浆壳兵官方解。射出一道笔直墨线，穿透 pierce_at 个目标。
func fire_inkline(player: Node2D) -> void:
	var lv: int = maxi(weapon_level("inkline"), 1)
	var d: Dictionary = WeaponDB.def("inkline")
	var range_px: float = float(d.get("range", 640.0))
	var target: Enemy = _pool.nearest(player.global_position, range_px)
	if target == null:
		_cd["inkline"] = 0.25
		return
	_cd["inkline"] = WeaponDB.cooldown_at("inkline", lv, stat("cooldown"))
	var dir: Vector2 = (target.global_position - player.global_position).normalized()
	var speed: float = float(d.get("bullet_speed", 700.0))
	# v6：墨线换成 ink_line_tex（可平铺的"龙筋"长条，256×8）。
	# 原来用的是武器本体 inkline.svg（一把墨斗），射出来读作"扔了把工具"。
	# 这里只在**弹道**换图，卡面/槽位仍是本体图。
	# 进化形态有自己的专属图（龙筋墨斗），优先用它；未进化才是可平铺的龙筋长条。
	# 不这样兜一刀的话，进化后弹道会被"统一成新图"，玩家刚看到的进化贴图又消失了。
	var ink_tex: String = _weapon_tex("inkline", Art.INK_LINE_TEX)
	var node: Sprite2D = _take_bullet(ink_tex)
	var b := Bullet.new()
	b.id = "inkline"
	b.pos = player.global_position + dir * 26.0
	b.vel = dir * speed
	# 生命周期 = 射程 / 速度：墨线不会飞出屏幕外还在结算
	b.life = range_px / maxf(speed, 1.0)
	b.dmg = weapon_damage("inkline", lv)
	b.pierce = WeaponDB.pierce_at("inkline", lv)
	# 迭代03 M-07：龙筋绷得更长 —— 开脸后多穿一只（2 只 → 3 只）。
	# inkline 在 WeaponDB 里没有 pierce_milestone（只有 "pierce": 1），
	# 所以 pierce_at 对它恒返回 1、Lv8 也不会自然涨。这里补的是"进化给的"，不是"等级给的"。
	if evolved.has("inkline"):
		b.pierce += 1
	b.radius = float(d.get("bullet_radius", 14.0))
	b.spin = 0.0
	b.node = node
	node.global_position = b.pos
	node.rotation = dir.angle()
	# 源图 256×8：x 压到 0.72（约 184px，接近原 220px 的手感），
	# y 随等级加粗 —— 这就是 v6 §6「Lv8 墨线变粗」，不改判定（半径由 WeaponDB 定）。
	node.scale = Vector2(0.72, 1.0 + 0.12 * float(lv - 1))
	_bullets.append(b)

# ---------------------------------------------------------------- 木版年画（延迟落点）
## 高基础伤 + 0.45s 延迟：给敌人"逃"的机会，才读得出"这是砸下来的重物"。
## 落点选"最密处"而不是"最近处" —— focus 的语义是扎堆越狠打得越狠。
func fire_print(player: Node2D) -> void:
	var lv: int = maxi(weapon_level("print"), 1)
	var d: Dictionary = WeaponDB.def("print")
	var radius: float = float(d.get("radius", 105.0)) * stat("area") * _area_mult("print")
	var range_px: float = float(d.get("range", 640.0))
	var center: Vector2 = Vector2.INF
	_pool.query_circle(player.global_position, range_px, _scratch)
	if _scratch.is_empty():
		_cd["print"] = 0.25
		return
	# 候选 = 离玩家最近的 12 只；在候选里选"身边 radius 内敌人最多"的那个当落点
	var cand: Array[Enemy] = _nearest_n(player.global_position, 12)
	var best_n: int = -1
	for c in cand:
		var n: int = 0
		for e in _scratch:
			if c.global_position.distance_squared_to(e.global_position) <= radius * radius:
				n += 1
		if n > best_n:
			best_n = n
			center = c.global_position
	_cd["print"] = WeaponDB.cooldown_at("print", lv, stat("cooldown"))
	_push_zone(center, radius, weapon_damage("print", lv), float(d.get("delay", 0.45)))

## 落点区：先显影、到点再结算。用节点自己的 tween 做倒计时（不轮询 state）。
func _push_zone(pos: Vector2, radius: float, dmg: float, delay: float) -> void:
	var s: Sprite2D = _take_fx(Art.WOODBLOCK_PRINT)
	s.global_position = pos
	s.rotation = 0.0
	s.flip_h = false
	# 目标直径 / 源图 120px：雕版本身要和落点区一样大，否则玩家判断不了范围
	s.scale = Vector2.ONE * (radius * 2.0 / 120.0)
	s.modulate = Color(1.0, 0.96, 0.88, 0.0)
	var z := Zone.new()
	z.pos = pos
	z.radius = radius
	z.dmg = dmg
	z.node = s
	z.total = maxf(delay, 0.05)
	z.left = z.total
	_zones.append(z)
	# 影：0 → 0.85 渐显，落点会砸下来的一瞬间才满
	var tw: Tween = s.create_tween()
	tw.tween_property(s, "modulate:a", 0.85, z.total)
	# v6 §5：雕版印记"从天而降压出浮雕光印"。
	# 单独一层 seal（阴刻印，160×160）从上方 64px 落下来 —— 这是**非 shader** 的
	# 位移+淡入，比再写一个 shader 便宜，而且"砸下来"这件事本来就是运动，不是图案。
	# 它和 zone 的 woodblock_print 叠在一起，才读得出"整版盖下去"。
	_drop_seal(pos, radius, z.total)

## 雕版从天而降：起手在上方、略大、透明，落到落点时正好与判定圈同大。
## 用池化精灵 + 自己的 tween（同 _ring_face_anim 的口径）：_push_fx 的 alpha
## 从第一帧就开始掉，做不出"落下来"的过程。
func _drop_seal(pos: Vector2, radius: float, delay: float) -> void:
	var seal: Sprite2D = _take_fx(Art.WOODBLOCK_SEAL)
	var base: float = radius * 2.0 / 160.0
	seal.global_position = pos + Vector2(0.0, -64.0)
	seal.rotation = 0.0
	seal.flip_h = false
	seal.z_index = -2          # 压在怪与玩家之下，只在地面上留一枚印
	seal.scale = Vector2.ONE * base * 1.22
	seal.modulate = Color(1.0, 0.95, 0.82, 0.0)
	var tw: Tween = seal.create_tween()
	tw.set_parallel(true)
	tw.tween_property(seal, "position:y", pos.y, maxf(delay, 0.06)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(seal, "scale", Vector2.ONE * base, maxf(delay, 0.06))
	tw.tween_property(seal, "modulate:a", 0.85, maxf(delay, 0.06) * 0.75)
	tw.set_parallel(false)
	tw.tween_interval(0.06)
	tw.tween_property(seal, "modulate:a", 0.0, 0.16)
	tw.tween_callback(_recycle_fx.bind(seal))

func _update_zones(delta: float) -> void:
	var i: int = _zones.size() - 1
	while i >= 0:
		var z: Zone = _zones[i]
		z.left -= delta
		if z.left <= 0.0:
			_land_zone(z)
			_zones.remove_at(i)
		else:
			# 悬停期轻微下压：读得出"要砸了"
			var t: float = 1.0 - z.left / z.total
			z.node.scale = Vector2.ONE * (z.radius * 2.0 / 120.0) * (0.86 + 0.14 * t)
		i -= 1

func _land_zone(z: Zone) -> void:
	_pool.query_circle(z.pos, z.radius, _scratch)
	for e in _scratch:
		e.take_damage(z.dmg, &"print")
		spawn_spark(e.global_position, 1.0)
		if evolved.has("print"):
			# 迭代03 M-04 门神镇宅：落点把这一片"镇"住 —— 圈内敌人被拖慢 4s。
			# 只给减速不给持续伤害：DOT 是 new system（Enemy 没有 DOT 字段），
			# 而 apply_slow 是现成的，语义也正好是"守着不让人走快"。
			# 4s 比落点间隔长（cd ≈ 1.0s），所以同一片区域会被反复刷新 —— 这是有意的。
			e.apply_slow(0.30, 4.0)
	if resources != null:
		resources.try_hit(z.pos, z.radius, z.dmg)
	ShaderFX.burst_ellipse(
		self, z.pos, z.radius * 2.0, z.radius * 2.0,
		Color(1.0, 0.72, 0.38), 8, 0.30
	)
	# 落点不再叠 magic_circle（2026-11 实测反馈：法阵纹样读作"魔法阵"，
	# 与年画的雕版/盖章语义违和）。落地的"砸"由上面的放射光条 +
	# 雕版贴图淡出 + 印章落下（_drop_seal）承担。
	# 落点贴图直接淡出并归还池子（不挂在 _fx 里：它已经播完渐显，不需要缩放收尾）
	var s: Sprite2D = z.node
	var tw: Tween = s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.12)
	tw.tween_callback(_recycle_fx.bind(s))

## 从"已查询出的圆内敌人"里按距离取前 n 个。
## 不做全量 sort：同屏 400 只时每 1.8s 排一次 400 元素纯属浪费，取前 8 用选择更直接。
func _nearest_n(center: Vector2, n: int) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var pool: Array = _scratch.duplicate()
	for _i in mini(n, pool.size()):
		var best: int = -1
		var best_d: float = INF
		for j in pool.size():
			var e: Enemy = pool[j]
			var dd: float = center.distance_squared_to(e.global_position)
			if dd < best_d:
				best_d = dd
				best = j
		if best < 0:
			break
		out.append(pool[best])
		pool.remove_at(best)
	return out


# ---------------------------------------------------------------- 手机环（环绕）
func _update_orbits(delta: float, player: Node2D) -> void:
	if not owned.has("phone"):
		_hide_orbits()
		return
	var lv: int = maxi(weapon_level("phone"), 1)
	var d: Dictionary = WeaponDB.def("phone")
	var area_mul: float = stat("area") * _area_mult("phone")
	var radius: float = (float(d.get("orbit_radius", 58.0))
		+ float(d.get("orbit_radius_per_level", 5.0)) * float(lv - 1)) * area_mul
	# N-01：满堂彩（evolve_phone）的 orbit_count_bonus 让影人 2 → 3。
	# 数量加成只从进化表读，不在武器表里再写一份，避免两个乘区重复计算。
	var bonus: int = 0
	var form_id: String = evolution_of("phone")
	if form_id != "":
		bonus = int(EvolutionDB.form(form_id).get("orbit_count_bonus", 0))
	var count: int = int(d.get("orbit_count", 2)) + bonus
	var dmg: float = weapon_damage("phone", lv)
	var hit_r: float = float(d.get("hit_radius", 18.0))
	# v5：命中给一次短促击退（0.15 = 按敌人尺寸比例后退，不是固定像素）
	var knock: float = float(d.get("knock", 0.0))
	_orbit_angle += float(d.get("orbit_speed", 2.4)) * delta

	_ensure_orbit_sprites(count)
	# 轨道圆心对齐身体中部：影人绕脚踝转会读成"绕的不是我"（实测截图反馈）。
	# 判定随环绕物位置一起走（hit 半径容错 ≫ 上移量），不另开口。
	var p: Vector2 = _visual_center(player)
	# 这里**不画**轨迹圈。皮影的"绕身"由影人本体表达：它们一直在动，
	# 玩家自己就能看出轨道。原先铺一圈 area_ripple 作为轨迹提示，结果是
	# 同屏出现"花灯式的波纹"——两个技能的视觉语言撞在一起，反而把花灯的
	# 范围场读糊了（用户反馈"皮影的水波纹去掉"就是这个）。
	# 递减必须在闸门之前（先减 delta 再判 <= 0），否则节拍停在 first_delay 永不触发
	# —— 这正是策划案 §1.3 改法 B 的失败路径（iteration-01-fix-plan / D-1-F1）
	_orbit_cd = maxf(0.0, _orbit_cd - delta)
	var tick: bool = _orbit_cd <= 0.0
	if tick:
		_orbit_cd = WeaponDB.cooldown_at("phone", lv, stat("cooldown"))

	for i in count:
		var ang: float = _orbit_angle + TAU * float(i) / float(maxi(count, 1))
		var pos: Vector2 = p + Vector2.from_angle(ang) * radius
		var s: Sprite2D = _orbit_sprites[i]
		s.visible = true
		# 必须用 global_position：这些精灵挂在 WeaponManager 下，而管理器自身带父节点变换。
		# 写 position 会让手机环整体偏出玩家一圈，肉眼表现为"武器装了但看不见"。
		s.global_position = pos
		s.rotation = ang + TAU * 0.25
		# 残像：同一位置落后 0.38 rad（约 22°）。固定在"身后"而不是留一串历史点，
		# 是因为留历史点要每帧开关 visible，2 只环绕物 × 60fps 的赋值换不来可见差别。
		var g: Sprite2D = _orbit_ghosts[i]
		var gang: float = ang - 0.38
		g.visible = true
		g.global_position = p + Vector2.from_angle(gang) * radius
		g.rotation = gang + TAU * 0.25
		if tick:
			for e in _pool.active:
				if e.alive and e.global_position.distance_to(pos) < e.hit_radius() + hit_r:
					e.take_damage(dmg, &"phone")
					# 击退方向 = 从环绕物指向敌人（被"撞开"），不是从玩家向外（那会变成推怪）
					e.knock_back((e.global_position - pos).normalized(), knock)
					spawn_spark(pos, 0.6)
			# 资源点判定放在敌人之后：可破坏物不该抢走本该打在怪身上的伤害
			if resources != null:
				resources.try_hit(pos, hit_r, dmg)
	# _ensure_orbit_sprites 只扩不缩：进化回退（测试里 evolved.clear()）后
	# 池里仍留着第 3 只，不隐藏会残留一个停在原地的影人。
	for i in range(count, _orbit_sprites.size()):
		_orbit_sprites[i].visible = false
	for i in range(count, _orbit_ghosts.size()):
		_orbit_ghosts[i].visible = false

func _ensure_orbit_sprites(count: int) -> void:
	var tex: Texture2D = Art.tex(Art.PHONE_ORBIT)
	while _orbit_sprites.size() < count:
		var s := Sprite2D.new()
		s.texture = tex
		s.visible = false
		# 压在敌人之上、特效之下：环绕物本来就该"绕着角色转"，被怪遮住就没意义
		s.z_index = 3
		add_child(s)
		_orbit_sprites.append(s)
		# 剪影残像（v6 §6「环绕武将拖出黑色剪影残像」）。
		# 用**孪生精灵**而不是 projectile_trail：那个 shader 是 blend_add，
		# 只能加光、不能压暗，做不出"黑影"。一张同贴图的精灵挂在角度落后
		# 0.38 rad 的位置、压暗、半透明，就是最便宜的真残像 —— 而且不挂材质，
		# 与本体共用同一张纹理，合批不受影响。
		var g := Sprite2D.new()
		g.texture = tex
		g.visible = false
		g.z_index = 2
		g.modulate = Color(0.34, 0.38, 0.52, 0.32)
		add_child(g)
		_orbit_ghosts.append(g)

func _hide_orbits() -> void:
	for s in _orbit_sprites:
		s.visible = false
	for g in _orbit_ghosts:
		g.visible = false

# ---------------------------------------------------------------- 子弹
func update_bullets(delta: float) -> void:
	if _pool == null:
		return
	var i: int = _bullets.size() - 1
	while i >= 0:
		var b: Bullet = _bullets[i]
		b.life -= delta
		b.pos += b.vel * delta
		b.node.global_position = b.pos
		# 刀/鸟：每帧对齐速度方向；糖丝现在也是对齐（spin = 0）；
		# 打铁花的罐子是抛投物，保留自转才读得出"被扔出去"。
		if b.bounce > 0:
			b.node.rotation = b.vel.angle()
		elif b.spin != 0.0:
			b.node.rotation += delta * b.spin
		var dead: bool = b.life <= 0.0
		if not dead:
			for e in _pool.active:
				if not e.alive or b.hit_ids.has(e.get_instance_id()):
					continue
				if b.pos.distance_to(e.global_position) < e.hit_radius() + b.radius:
					b.hit_ids.append(e.get_instance_id())
					b.hits_done += 1
					# 剪纸：第 2 跳之后每次 -30%（防两怪无限互弹，也防"一颗刀清一片"）
					var dmg: float = b.dmg
					var bd: Dictionary = WeaponDB.def(b.id)
					if b.bounce > 0 and bool(bd.get("bounce_falloff", false)) \
							and b.hits_done > int(bd.get("bounce_falloff_after", 2)):
						dmg *= float(bd.get("bounce_falloff_ratio", 0.70))
					# 迭代03 M-07：线越绷越紧 —— 同一发子弹每多穿一只，后一只吃得更重。
					# 几何一动不动（vel / rotation 全程恒定），这是"墨斗弹线必须笔直"下的增强方式。
					# hits_done 在上面已自增，所以第一只拿到的就是 ×1.00。
					if b.id == "inkline" and evolved.has("inkline"):
						dmg *= 1.0 + minf(0.25 * float(b.hits_done - 1), 0.75)
					e.take_damage(dmg, StringName(b.id))
					spawn_spark(b.pos, 0.7)
					# 迭代03 M-07：每多穿一只加粗 15%，从第 2 只起算（第 1 只是"进入笔尖"）。
					# 池化精灵在 _take_bullet 会把 scale 重置成 ONE，所以这里改了不用还原。
					if b.id == "inkline" and evolved.has("inkline") and b.hits_done >= 2:
						b.node.scale.y = minf(b.node.scale.y * 1.15, 2.8)
					# 迭代03 M-05：糖水粘连。只粘每根糖丝的**第一跳** ——
					# 后两跳是穿透顺带的，全粘等于一次冷却定住 12 只（Lv8 4 发 × 穿透 3）。
					var glued: bool = false
					if b.id == "glowstick" and evolved.has("glowstick") and b.hits_done == 1:
						glued = e.apply_root(GLUE_TIME)
					# ---- 逐武器命中表现（v6 §5 复用清单）----
					# 糖画：糖晶迸裂。只给前两跳做 —— 糖丝穿透 3 个目标 × 最多 4 根，
					# 每跳都开一个 ColorRect + 材质，一秒能开出十几个节点，
					# 而第二跳之后的画面反正已经被第一跳的迸裂盖住了。
					if b.id == "glowstick" and b.hits_done <= 2:
						# 粘住的那一下读「糖浆摊开」（无射线、更慢、更大），没粘住的仍是「糖晶迸裂」。
						# 不做成第二次 burst 调用：burst 每次都要 new ColorRect + new ShaderMaterial，
						# 一秒 4 根 × 2 跳已经是 8 个，翻倍会顶到渲染开销。
						ShaderFX.burst_ellipse(self, b.pos,
							66.0 if glued else 46.0, 66.0 if glued else 46.0,
							Enemy.GLUE_TINT if glued else Color(1.0, 0.90, 0.56),
							0 if glued else 6, 0.30 if glued else 0.18)
					# 剪纸：弹射点的"纸花绽放"。放在这里而不是弹射分支里，
					# 是因为读到这里 b.pos 还是**被咬中的那个点**，弹射后它就不动了。
					elif b.id == "blade" and b.bounce > 0:
						ShaderFX.burst_ellipse(self, b.pos, 52.0, 52.0,
							PAPER_BLOOM_COLOR, 7, 0.20)
					# 打铁花：命中即碎开（每发一次 / 进化再多迸一圈火星）
					if b.id == "extinguisher":
						_shatter(b, e)
					if b.hit_cap > 0:
						b.hit_cap -= 1
						if b.hit_cap <= 0:
							dead = true
							break
					if b.bounce > 0 and b.bounces_left > 0:
						# 美工刀：弹射到附近另一个目标，不衰减。
						# 次数封顶（迭代01 D-2 / IT-06）：单发最多 1 + bounce 次命中；
						# bounces_left 归零后落入下方 pierce 分支，下一次命中即回收。
						var nxt: Enemy = _pool.nearest_except(b.pos, b.bounce_range, b.hit_ids)
						if nxt != null:
							var dir: Vector2 = (nxt.global_position - b.pos).normalized()
							b.vel = dir * b.vel.length()
							b.life = maxf(b.life, 0.5)
							b.bounces_left -= 1
						else:
							dead = true
							break
					else:
						b.pierce -= 1
						if b.pierce < 0:
							dead = true
							break
			# 子弹穿过的每一帧都碰一次资源点；ResourceField 内部按 key 去重，
			# 同一颗子弹不会把同一个可破坏物重复打（它会在 HP 归零后从 _alive 移除）
			if not dead and resources != null:
				resources.try_hit(b.pos, b.radius, b.dmg)
		if dead:
			_release_bullet(b.node)
			_bullets.remove_at(i)
		i -= 1

## 立刻清空在场上的弹体（含视觉节点回收）。
## 给测试用：用例之间只 clear_all 敌人、不召回在飞弹体的话，上一条用例打出去的
## 弹体会飞进下一条用例刚生成的敌人身上 —— 伤害断言就会随机多算一次
## （实测过 1/3 概率把"糖画打结壳 ×1.0"测成 14.68）。
func clear_bullets() -> void:
	for b in _bullets:
		# 弹体节点来自池，必须走 _release_bullet 而不是 queue_free，否则池会漏
		_release_bullet(b.node)
	_bullets.clear()

## 铁水碎裂（v6 §4 / v7 T8）。
## 规则：
##   · **每发只碎一次**，碎在第一个命中点。不然同一群会被反复溅，总伤直接翻倍；
##   · 碎开半径内每只吃 `scatter_ratio ×` 主伤，最多 `scatter_cap` 只；
##   · **被直接命中的那只不吃自己触发的溅射**（Brotato 规则，防同一发双算）。
##
## 【为什么弹体不消失】
## v6 §4.1 同时写了"撞到第一只实体即碎裂"和"直射路径仍造成次要直伤"，还留了 `hit_cap 4`。
## 这两句只有在"碎裂是一次**判定事件**、弹体继续飞完剩下的穿透"时才同时成立。
## 所以穿透手感一点没动，只把"落点炸一个中等圈"换成"碎开一大片"。
func _shatter(b: Bullet, hit: Enemy) -> void:
	if b.exploded:
		return
	b.exploded = true
	var d: Dictionary = WeaponDB.def("extinguisher")
	var r: float = float(d.get("scatter_radius", 150.0)) * stat("area") * _area_mult("extinguisher")
	var sdmg: float = b.dmg * float(d.get("scatter_ratio", 0.40))
	var cap: int = WeaponDB.scatter_cap_at("extinguisher", weapon_level("extinguisher"))
	var hit_id: int = hit.get_instance_id()

	# 【为什么先查圈再排序，而不是直接遍历 _pool.active 取前 cap 只】
	# active 的顺序是**生成顺序**，不是距离顺序。圈里挤了 40 只时，
	# 直接取前 16 只会打到远处那批、漏掉脚边这几只 ——
	# 玩家看到的画面是"火星明明溅过它了，它却没掉血"，这比少打几只更难接受。
	_pool.query_circle(b.pos, r, _scratch)
	var cand: Array[Enemy] = []
	for e in _scratch:
		if e.get_instance_id() != hit_id:
			cand.append(e)
	if cand.size() > cap:
		cand.sort_custom(func(x: Enemy, y: Enemy) -> bool:
			return b.pos.distance_squared_to(x.global_position) \
				< b.pos.distance_squared_to(y.global_position))
	for i in mini(cap, cand.size()):
		cand[i].take_damage(sdmg, &"extinguisher")

	# ---- 视觉：铁水撞散，不是"炸了个环" ----
	# v6 §4 的签名是"撞一下 → 散成一大片小火星"，所以这里用 molten_scatter
	# 而不是 cast_burst：后者画的是一条干净环，读作"敲了一下"（那是铜锣的语言）。
	# 半径**直接传 r**（= 实际结算半径），玩家才能按火星的范围判断走位。
	ShaderFX.molten_scatter(self, b.pos, r, MOLTEN_COLOR, 0.42)
	# 屏幕微光晕：只在冷却到了才放。同一次泼洒会碎两发（count 2），
	# 两团光叠加会整块过曝，把"溅开"糊成一片白 —— 这是加法混合的固有代价。
	# 半径封在 360：散开半径 150 比旧引爆的 76 大了近一倍，
	# 沿用 r×3.6 会变成 540（720 竖屏的 0.75 屏宽），整屏泛白、看不见火星形状。
	if _glow_left <= 0.0:
		_glow_left = 0.25
		ShaderFX.flash_glow(self, b.pos, minf(r * 2.4, 360.0), Color(1.0, 0.62, 0.26), 0.28)
	# 二次溅射（百子千花）：同一碎裂点再迸出一圈更小的火星。
	# 为什么不做成 "r × 1.40"：进化态的 area_mult 已经是 1.40，r 本身就放大了，
	# 再画一圈更大的就等于宣称一个不存在的伤害范围。这里画**内部**的一圈，
	# 语义是"铁水在大片里又炸了一遍"，与"再次结算"这件事对得上。
	if evolved.has("extinguisher"):
		var second: float = r * 0.62
		var tw2: Tween = create_tween()
		tw2.tween_interval(0.10)
		tw2.tween_callback(func() -> void:
			ShaderFX.molten_scatter(self, b.pos, second, Color(1.0, 0.66, 0.24), 0.34))

## 锣面：被敲的金属先亮住一拍、弹一下、再散。
##
## 为什么不走 `_push_fx()`：那条路径的 alpha 是从**第一帧**就开始掉的
## （climb(t) = t × 1.6），锣面会变成"闪一下就没了"，读不出"一面被敲响的锣"。
## 敲击类要的是"先亮住 → 再退"，所以单独一条 tween 管。
##
## 收尾必须回 `_recycle_fx()`：它会剥净材质、复位 scale/modulate、塞回池子。
## 少这一步，这个精灵既不在 _fx 里也不在 _fx_free 里 —— 永久泄漏，而且不报错。
func _ring_face_anim(s: Sprite2D) -> void:
	var base: Vector2 = s.scale
	# 起手缩到 0.78：从"还没敲到"的一瞬间弹出来，比一出生就是全尺寸更有力
	s.scale = base * 0.78
	var tw: Tween = s.create_tween()
	# ① 弹开：快
	tw.tween_property(s, "scale", base * 1.10, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# ② 回落：略慢。这一下是"被敲得颤了一下"，锣面还在振
	tw.tween_property(s, "scale", base * 0.99, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# ③ 亮住：金属余振。没有这一段，锣面就只是一次闪光，不像"一件乐器"
	tw.tween_interval(0.06)
	# ④ 散开
	tw.tween_property(s, "modulate:a", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_recycle_fx.bind(s))

## 把已经播完的池化精灵直接还回空闲表（不经过 _fx 的缩放收尾）
func _recycle_fx(s: Sprite2D) -> void:
	if not is_instance_valid(s):
		return
	if s.material != null:
		ShaderFX.clear(s)
		s.material = null
	s.visible = false
	s.modulate = Color.WHITE
	s.scale = Vector2.ONE
	# z_index 也要复位：池子是混用的，铜锣的锣面会临时落到 -2（画在玩家之下）。
	# 不还原的话，下一个从池里拿到它的火花 / 弧光会整片沉到玩家脚下。
	s.z_index = 0
	_fx_free.append(s)

func _take_bullet(tex_path: String) -> Sprite2D:
	var s: Sprite2D
	if not _bullet_free.is_empty():
		s = _bullet_free.pop_back()
		# 同 _take_fx：池化精灵必须剥净上一轮的拖尾材质，
		# 否则这一发会在缩到 0 的旧拖尾里"看不见"。
		if s.material != null:
			ShaderFX.clear(s)
			s.material = null
	else:
		s = Sprite2D.new()
		# 弹道压在敌人之上：否则穿过人堆时刀/罐子会被完全遮住
		s.z_index = 3
		add_child(s)
	s.texture = Art.tex(tex_path)
	s.visible = true
	s.modulate = Color.WHITE
	s.scale = Vector2.ONE
	return s

func _release_bullet(s: Sprite2D) -> void:
	# 还原材质而不是留着：留着的话这颗精灵进了池还挂着独立材质，
	# 池里 128 个精灵就永远是 128 个不同材质，等于永久掉出合批。
	if s.material != null:
		ShaderFX.clear_trail(s)
		s.material = null
	s.visible = false
	_bullet_free.append(s)

# ---------------------------------------------------------------- 命中特效池
## 正在飞的池化特效数量（弧光/火花/引爆/进化共用这一个池）。
## 给测试与调试用：它直接反映"一秒钟开了多少个特效"，比帧率更早暴露爆发期的池压力。
func fx_active_count() -> int:
	return _fx.size()

## 命中火花。color 用来区分"谁打的" —— 铜锣给银白（金属光），
## 默认留白（暖金）给其它武器。走 modulate 而不是新建配色贴图：
## 一次爆发几十个火花，多一张图就多一次纹理切换（掉合批）。
func spawn_spark(pos: Vector2, size_mul: float, color := Color(1.0, 1.0, 1.0)) -> void:
	var s: Sprite2D = _take_fx(Art.FX_SPARK)
	s.global_position = pos
	s.rotation = randf() * TAU
	s.flip_h = randf() < 0.5
	s.scale = Vector2.ONE * (0.55 * size_mul)
	s.modulate = Color(color.r, color.g, color.b, 0.9)
	_push_fx(s, 0.14, 1.4 * size_mul, 1.45)

## 进化特效：开箱时在玩家身上放一颗星
func spawn_evolve(pos: Vector2) -> void:
	var s: Sprite2D = _take_fx(Art.FX_EVOLVE)
	s.global_position = pos
	s.rotation = 0.0
	s.flip_h = false
	s.scale = Vector2.ONE * 1.2
	s.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_push_fx(s, 0.55, 3.6, 1.6)

func _take_fx(path: String) -> Sprite2D:
	var s: Sprite2D
	if not _fx_free.is_empty():
		s = _fx_free.pop_back()
		# 池子是**混用**的：弧光和火花都从 _take_fx 取。上一轮挂过 slash_arc 遮罩的精灵
		# 如果直接拿去当火花，progress 会停在半路，火花被遮罩挡成**完全不可见**——
		# 而且不报任何错，只会表现为"打击感突然没了"。所以取出来先剥干净。
		if s.material != null:
			ShaderFX.clear(s)
			s.material = null
		if s.texture == null or s.texture.resource_path != path:
			s.texture = Art.tex(path)
	else:
		s = Sprite2D.new()
		s.texture = Art.tex(path)
		add_child(s)
	s.visible = true
	# 池子是混用的，z_index 每轮都可能不同（铜锣锣面会临时落到玩家之下）。
	# 出发前统一归零，调用方要改再自己改 —— 否则弧光会继承上一轮锣面的层级。
	s.z_index = 0
	return s

func _push_fx(s: Sprite2D, life: float, grow: float, fade_at: float) -> void:
	var f := Fx.new()
	f.node = s
	f.life = life
	f.total = life
	f.grow = grow
	_fx.append(f)

func update_fx(delta: float) -> void:
	var i: int = _fx.size() - 1
	while i >= 0:
		var f: Fx = _fx[i]
		f.life -= delta
		if f.life <= 0.0:
			f.node.visible = false
			f.node.scale = Vector2.ONE
			f.node.modulate = Color.WHITE
			_fx_free.append(f.node)
			_fx.remove_at(i)
		else:
			var t: float = f.life / f.total
			f.node.modulate.a = climb(t)
			f.node.scale = f.node.scale.lerp(Vector2.ONE * f.grow, clampf(delta * 12.0, 0.0, 1.0))
		i -= 1

static func climb(t: float) -> float:
	return clampf(t * 1.6, 0.0, 1.0)

## 火神开脸的第二刀：竖劈弧光。复用同一张 WHIP_ARC，旋转 90°。
## 不复用 _second_arc 的两个理由：① 它按 sign_x 翻水平方向，竖劈没有左右；
## ② 它对 Lv8 染暗红，而竖劈本身就是开脸的标志，再染红会让"满级"和"开脸"糊在一起（见 M-08）。
func _delay_arc_v(p: Vector2, length: float, width: float, lv: int) -> void:
	var tw: Tween = create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(_second_arc_v.bind(p, length, width, lv))

func _second_arc_v(p: Vector2, length: float, width: float, _lv: int) -> void:
	var arc: Sprite2D = _take_fx(Art.WHIP_ARC)
	arc.position = Vector2(p.x + width * 0.10, p.y - length * 0.18)
	arc.rotation = PI * 0.5
	arc.flip_h = false
	arc.scale = Vector2(0.9, 1.15) * (length / 115.0) * 0.92
	arc.modulate = Color(1.0, 0.78, 0.42, 0.95)    # 暖金：与横向白弧明确区分
	_push_fx(arc, 0.16, 1.55, 1.15)
	ShaderFX.slash(arc, 0.12, false, false)

# ---------------------------------------------------------------- 迭代03 M-06：铜锣回响
## 开市锣的回响。判定口径与主敲一致（最近 cap 只），但**不碰资源点**：
## 同一次敲击把资源点打两遍，会让"可拆资源点"的血量预期整体错位（ResourceField 按 key 去重，
## 所以不会重复扣，但会白跑一遍遍历）。
func _gong_echo(pos: Vector2, radius: float, dmg: float, cap: int) -> void:
	_pool.query_circle(pos, radius, _scratch)
	if _scratch.is_empty():
		return
	for e in _nearest_n(pos, cap):
		e.take_damage(dmg, &"gong")
		e.apply_slow(0.25, 0.8)
		spawn_spark(e.global_position, 0.6, GONG_SPARK_COLOR)
	# 第二圈波：半径 0.92，比主波小一圈 —— 读作"回音从墙上反弹回来"
	ShaderFX.burst_ellipse(
		self, pos, radius * 2.0 * 0.92, radius * 2.0 * 0.92,
		GONG_WAVE_COLOR, 8, 0.26
	)
	Audio.play_sfx("gong", -6.0)

## 糖水系留时间（秒）。这是「固定」，不是「变慢」 —— 见 Enemy.apply_root。
## 减速硬上限 85%（Enemy 里 clampf(_slow_pct, 0, 0.85)），所以 apply_slow(1.0) 做不到站住，
## 必须走 Enemy 的第二条正交通道 _root_left。
const GLUE_TIME := 1.0

# ---------------------------------------------------------------- 迭代03：进化机制声明
## 每条进化的"行为机制"落在哪。这张表是**声明**，不是数据源 ——
## 武器侧照旧用 evolved.has(id) 判定（沿用 EvolutionDB.gd:87-91 的既有决定）。
## 存在的意义只有一个：让"9 条进化里几条真有机制"这件事可以被测试断言，
## 而不是靠人去 _shatter / update_bullets / fire_projectile 三处翻。
##
## 键 = 武器 id；值 = "机制名:落点函数"。
## 值必须是**真实存在的方法名**：断言会拿它跑 has_method()，重命名函数时这里会红。
const EVOLVE_MECHANIC: Dictionary = {
	"whip": "十字扫:_second_arc_v",
	"halo": "灯心同心:_visual_center",          # 迭代04 D-15：判定与可见环都以身体中心为圆心
	"glowstick": "糖水粘连:update_bullets",      # 敌人侧落在 Enemy.apply_root
	"gong": "回响:_gong_echo",
	"inkline": "穿透累进:update_bullets",
	"print": "门神镇守:_land_zone",
	"extinguisher": "二次溅射:_shatter",       # 迭代前既有
	"phone": "环绕 +1:_ensure_orbit_sprites",   # 迭代前既有（orbit_count_bonus）
	"blade": "弹射半径:fire_projectile",        # 迭代前既有（bounce_range_scaled）
}

# ---------------------------------------------------------------- 聚合数据（带类型，不用 Dictionary 手搓）
class Bullet:
	var id := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var dmg := 0.0
	var pierce := 0
	var bounce := 0
	## 剩余弹射次数（迭代01 D-2-F1 / IT-06）。与 bounce 严格分离：
	## bounce 是"弹射类"的类型判据 + 初始上限（旋转对齐 :855 与衰减判据 :870 都读它，
	## 递减它会让纸鹊飞着飞着突然开始自转），bounces_left 只负责消耗，归零即停弹。
	var bounces_left := 0
	var bounce_range := 240.0
	var hit_cap := 0
	var radius := 8.0
	## 自转角速度（rad/s）。0 = 保持射出时的朝向（弹体自己指向飞行方向）。
	## 自转的弹体没法挂 projectile_trail：拖尾做在贴图 UV 里，跟着转就会绕圈。
	var spin := 6.0
	var hit_ids: Array[int] = []
	## 这发子弹已经命中过几次（剪纸衰减 / 百子千花"每 2 命中"都读它）
	var hits_done := 0
	## 打铁花：这发是否已经引爆过（基础形态每发只炸一次）
	var exploded := false
	var node: Sprite2D

## 延迟落点区（木版年画）：先显影，到点结算，然后淡出归还池子。
class Zone:
	var pos := Vector2.ZERO
	var radius := 0.0
	var dmg := 0.0
	var left := 0.0
	var total := 0.45
	var node: Sprite2D

class Fx:
	var node: Sprite2D
	var life := 0.0
	var total := 1.0
	var grow := 1.4
