extends Node2D

# ============================================================================
# 花灯（halo）语义探针：**站桩领域** 还是 **绕身环绕**？
# ----------------------------------------------------------------------------
# 玩家问的问题只有一个：花灯到底是"围着主角转、转到谁身上谁掉血"，
# 还是"以主角为圆心的一块区域、每隔 0.5s 烧一次里面所有人"？
# 顺带验：可见的圈和真正的判定圈是不是同一个圈。
#
# 不改任何游戏代码，只读不写（本工具的唯一副作用是截图 + 打印）。
#
# ⚠️ 截图需要真实渲染，**不能加 --headless**：
#     godot --path . res://tools/HaloLogic.tscn
#     （headless 下 RenderingServer.frame_post_draw 不会触发，进程会静默挂死）
# ============================================================================

const GAME := "res://scenes/Game.tscn"
const SHOT_PATH := "user://halo_logic.png"
const SHOT_ORBIT := "user://phone_orbit.png"

# lantern_halo.svg 的几何事实（256×256，圆心 128）：
#   20 只灯笼的中心落在 r=112 的圆上，单只椭圆 ry=12.5 → 外沿 124.5
const SVG_HALF := 128.0
const SVG_LANTERN_CENTER := 112.0
const SVG_LANTERN_OUTER := 124.5

var _game: GameScene
var _player: Player
var _weapons: WeaponManager
var _enemies: EnemyPool

var _ok := 0
var _bad: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 测的是判定逻辑，不是帧率：摘掉 60 上限，让 _wait 按墙钟走
	Engine.max_fps = 0
	await get_tree().process_frame

	_game = (load(GAME) as PackedScene).instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame

	_player = _game.get_node("World/Player") as Player
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool

	# 停掉自动刷怪，并把玩家血量拉到无敌：本探针只关心花灯，别被杂兵打断
	_game.set("_spawn_left", 1e9)
	_game.set("_elite_left", 1e9)
	GameManager.stats["max_hp"] = 1e9
	GameManager.stats["hp"] = 1e9
	_player.stats["hp"] = 1e9
	_player.stats["max_hp"] = 1e9

	print("\n===== 花灯语义探针 =====")
	await _case_visual_matches_hitbox()
	await _case_not_orbiting()
	await _case_full_circle_one_frame()
	await _case_outside_untouched()
	await _case_pulse_cadence()
	await _case_slow_applied()
	await _case_phone_is_the_orbit_contrast()
	await _shot()

	print("\n---------- 汇总 ----------")
	if _bad.is_empty():
		print("全部通过 OK（%d 条断言）" % _ok)
	else:
		for f in _bad:
			print("失败: ", f)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if _bad.is_empty() else 1)

# ---------------------------------------------------------------- 断言基座
func _check(ok: bool, msg: String) -> void:
	if ok:
		_ok += 1
		print("  ok   ", msg)
	else:
		_bad.append(msg)
		print("  FAIL ", msg)

func _equip(ids: Array, lv: int) -> void:
	for id in WeaponDB.ORDER:
		_weapons.owned.erase(id)
	_weapons.evolved = {}
	_weapons.refines = {}
	_weapons._cd = {}
	for id in ids:
		_weapons.owned[String(id)] = lv
	# Player 每帧按 has_weapon("halo") 重设常驻圈，等几帧让它生效
	await _frames(4)

func _pick(pos: Vector2, name: String) -> Enemy:
	var e: Enemy = _enemies.spawn(pos, 99999.0, 0.0, 1, "cup", false)
	if e != null:
		e.name = "probe_" + name
	return e

# ---------------------------------------------------------------- ① 视觉圈 = 判定圈
func _case_visual_matches_hitbox() -> void:
	print("\n[①] 可见的圈和判定的圈是不是同一个")
	_enemies.clear_all()
	await _equip(["halo"], 1)
	var r: float = _weapons.halo_radius()
	var ring: GarlicRing = _player.garlic_ring
	var tex_edge: float = ring.ring.scale.x * SVG_HALF   # 贴图外沿在世界里的半径
	var lantern_c: float = ring.ring.scale.x * SVG_LANTERN_CENTER
	var lantern_o: float = ring.ring.scale.x * SVG_LANTERN_OUTER
	print("  判定半径 halo_radius = %.1f px" % r)
	print("  常驻圈 radius 字段   = %.1f px" % ring.radius)
	print("  贴图外沿（透明）     = %.1f px" % tex_edge)
	print("  灯笼中心环           = %.1f px（%.1f%% 判定半径）" % [lantern_c, lantern_c / r * 100.0])
	print("  灯笼外沿（真正可见边）= %.1f px（%.1f%% 判定半径）" % [lantern_o, lantern_o / r * 100.0])
	_check(absf(ring.radius - r) < 0.01, "常驻圈半径 == 判定半径（%.2f / %.2f）" % [ring.radius, r])
	_check(absf(tex_edge - r) < 0.01, "贴图缩放后外沿 == 判定半径（%.2f / %.2f）" % [tex_edge, r])
	# 灯笼是"点"不是"线"，玩家看到的边界是灯笼外沿；偏 3% 以内读不出差别
	_check(absf(lantern_o - r) / r < 0.05,
		"最外可见像素（灯笼外沿）与判定半径偏差 %.1f%% < 5%%" % (absf(lantern_o - r) / r * 100.0))

# ---------------------------------------------------------------- ② 不是环绕
func _case_not_orbiting() -> void:
	print("\n[②] 圈是钉在玩家脚下的，还是在绕圈飞")
	var ring: GarlicRing = _player.garlic_ring
	var p0: Vector2 = _player.global_position
	var n0: Vector2 = ring.global_position
	var s0: Vector2 = ring.ring.global_position
	var rot0: float = ring.ring.rotation
	var dmax := 0.0
	var smax := 0.0
	for _i in 60:
		await get_tree().process_frame
		dmax = maxf(dmax, ring.global_position.distance_to(n0))
		smax = maxf(smax, ring.ring.global_position.distance_to(s0))
	print("  0.6s 内节点位移：容器 %.3f px / 光圈本体 %.3f px" % [dmax, smax])
	print("  光圈 rotation = %.4f rad（起 0.0000）" % ring.ring.rotation)
	_check(dmax < 0.5, "GarlicRing 容器相对玩家不动（最大位移 %.3f px）" % dmax)
	_check(smax < 0.5, "光圈贴图本体不动（最大位移 %.3f px）" % smax)
	_check(absf(ring.ring.rotation - rot0) < 0.0001 and absf(rot0) < 0.0001,
		"光圈不自转（rotation 恒为 0）")
	_check(_player.global_position.distance_to(p0) < 0.5, "玩家本身没被推走（对照组前提成立）")

# ---------------------------------------------------------------- ③ 同帧命中整圈
func _case_full_circle_one_frame() -> void:
	print("\n[③] 一次 tick 是命中整圈，还是只命中一个点")
	_enemies.clear_all()
	await _frames(2)
	var r: float = _weapons.halo_radius()
	var c: Vector2 = _player.global_position
	var probes: Array[Enemy] = []
	for i in 3:
		var ang: float = TAU * float(i) / 3.0
		probes.append(_pick(c + Vector2.from_angle(ang) * r * 0.6, "fan%d" % i))
	await _frames(2)
	var hp0: Array[float] = []
	for e in probes:
		hp0.append(e.hp)
	# 逐帧记录每只第一次掉血的帧号
	var first_hit := [-1, -1, -1]
	for f in 120:
		await get_tree().process_frame
		for i in 3:
			if first_hit[i] < 0 and probes[i].hp < hp0[i] - 0.01:
				first_hit[i] = f
		if first_hit[0] >= 0 and first_hit[1] >= 0 and first_hit[2] >= 0:
			break
	print("  三只（0°/120°/240°，0.6r）首次掉血帧号：%s" % str(first_hit))
	_check(first_hit[0] >= 0 and first_hit[1] >= 0 and first_hit[2] >= 0, "三只都在圈内被打到")
	var spread: int = 0
	if first_hit[0] >= 0 and first_hit[1] >= 0 and first_hit[2] >= 0:
		spread = maxi(maxi(first_hit[0], first_hit[1]), first_hit[2]) \
			- mini(mini(first_hit[0], first_hit[1]), first_hit[2])
	_check(spread <= 1, "三只**同一帧**掉血（帧号跨度 %d ≤ 1）—— 是整圈判定，不是扫过某一点" % spread)
	# 环绕武器必须有"逐点"特征；这里一次 tick 三只同时掉血，说明它不是环绕
	var all_hit_same_frame: bool = spread <= 1
	_check(all_hit_same_frame, "不存在\"环绕物转到谁才算谁\"的逐个命中特征")

# ---------------------------------------------------------------- ④ 圈外不吃伤害
func _case_outside_untouched() -> void:
	print("\n[④] 圈外是否安全（判定确实只在半径内）")
	var r: float = _weapons.halo_radius()
	var out: Enemy = _pick(_player.global_position + Vector2(r * 1.30, 0), "out")
	var inn: Enemy = _pick(_player.global_position + Vector2(r * 0.55, 0), "in")
	await _frames(2)
	var out_hp: float = out.hp
	var inn_hp: float = inn.hp
	await _wait(0.75)
	print("  1.30r 处血量变化 %.1f，0.55r 处血量变化 %.1f" % [out_hp - out.hp, inn_hp - inn.hp])
	_check(is_equal_approx(out.hp, out_hp), "1.30r 处完全不吃伤害（%.1f → %.1f）" % [out_hp, out.hp])
	_check(inn.hp < inn_hp, "0.55r 处持续掉血（%.1f → %.1f）" % [inn_hp, inn.hp])

# ---------------------------------------------------------------- ⑤ 脉冲节奏
func _case_pulse_cadence() -> void:
	print("\n[⑤] 是\"持续每帧烧\"还是\"每 0.5s 脉冲一次\"")
	_enemies.clear_all()
	await _frames(2)
	var e: Enemy = _pick(_player.global_position + Vector2(20, 0), "cad")
	await _frames(2)
	var hits := 0
	var prev: float = e.hp
	var t := 0.0
	var dur := 1.65
	# 记录每次掉血的时间点
	var stamps: Array[float] = []
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		if e.hp < prev - 0.01:
			hits += 1
			stamps.append(t)
			prev = e.hp
	var cd: float = WeaponDB.cooldown_at("halo", 1, _weapons.stat("cooldown"))
	print("  %.2fs 内命中 %d 次，时刻 %s；武器冷却 %.3fs" % [dur, hits, str(_fmt(stamps)), cd])
	_check(hits >= 2 and hits <= 5, "命中次数落在脉冲区间（%d 次 / %.2fs，不是每帧结算）" % [hits, dur])
	var gaps: Array[float] = []
	for i in range(1, stamps.size()):
		gaps.append(stamps[i] - stamps[i - 1])
	if gaps.size() > 0:
		print("  相邻命中间隔 %s" % str(_fmt(gaps)))
		_check(absf(gaps[0] - cd) < 0.12, "命中间隔 ≈ 武器冷却 %.2fs（实测 %.3fs）" % [cd, gaps[0]])

# ---------------------------------------------------------------- ⑥ 减速
func _case_slow_applied() -> void:
	print("\n[⑥] 命中是否附带减速（伤害逻辑的另一半）")
	var e: Enemy = null
	for it in _enemies.active:
		if it.alive and String(it.name).begins_with("probe_"):
			e = it
			break
	_check(e != null, "找到探针怪")
	if e == null:
		return
	print("  is_slowed = %s, slow_pct = %.2f" % [str(e.is_slowed()), e._slow_pct])
	_check(e.is_slowed(), "圈内敌人被打后处于减速状态")
	_check(absf(e._slow_pct - float(WeaponDB.def("halo").get("slow_pct", 0.22))) < 0.001,
		"减速幅度 %.2f == 数据表 slow_pct" % e._slow_pct)
	# 减速必须在画面上看得见：它是"下一击 +20%"的唯一提示。
	# ⚠️ 不能在某个固定时刻读一次 modulate：受击闪白 0.12s 夹在 0.44s 的冷却里，
	#    随机相位有 27% 概率正好读到闪白（第一版就踩了，读到 (1,0.78,0.7)）。
	#    正确做法是采一整个周期，看**两种状态是否都出现过**。
	var seen_flash := false
	var seen_slow := false
	var t := 0.0
	while t < 1.00:
		await get_tree().process_frame
		t += get_process_delta_time()
		if e.art.modulate.is_equal_approx(Enemy.SLOW_TINT):
			seen_slow = true
		if e.art.modulate.is_equal_approx(Enemy.HIT_COLOR):
			seen_flash = true
	print("  一个周期内采样 1.0s：见到琥珀 = %s，见到闪白 = %s" % [str(seen_slow), str(seen_flash)])
	_check(seen_slow, "减速的敌人会被染成琥珀色（这就是\"+20% 伤\"的可读凭据）")
	_check(seen_flash, "受击闪白仍然存在（0.12s，没有被染色吃掉）")
	_check(not Enemy.SLOW_TINT.is_equal_approx(Enemy.HIT_COLOR),
		"减速色与受击闪白是两种色相（%s vs %s）" % [str(Enemy.SLOW_TINT), str(Enemy.HIT_COLOR)])
	# 摘掉花灯 → 不再续减速 → 染色必须自己退回去
	await _equip([], 1)
	await _wait(0.90)
	print("  减速结束后 art.modulate = %s" % str(e.art.modulate))
	_check(e.art.modulate.is_equal_approx(Color.WHITE), "减速结束后恢复原色（不残留琥珀）")

# ---------------------------------------------------------------- ⑦ 真正的环绕长什么样
func _case_phone_is_the_orbit_contrast() -> void:
	print("\n[⑦] 对照：本作真正的\"绕身\"是皮影（phone），不是花灯")
	_enemies.clear_all()
	await _equip(["phone"], 1)
	await _frames(3)
	var sprites: Array = _weapons._orbit_sprites
	_check(sprites.size() > 0, "皮影环绕体已生成（%d 个）" % sprites.size())
	if sprites.is_empty():
		return
	var s: Sprite2D = sprites[0]
	var p0: Vector2 = s.global_position
	var dmax := 0.0
	for _i in 40:
		await get_tree().process_frame
		dmax = maxf(dmax, s.global_position.distance_to(p0))
	print("  皮影环绕体 0.4s 内位移 %.1f px（花灯光圈为 0）" % dmax)
	_check(dmax > 20.0, "环绕体确实在飞（位移 %.1f px > 20）" % dmax)
	print("  → 结论：\"绕身\"是皮影的机制；花灯是站桩圆域。两者在代码里是两套完全不同的东西。")

# ---------------------------------------------------------------- 截图
func _shot() -> void:
	_enemies.clear_all()
	await _equip(["halo"], 8)
	await _frames(3)
	var r: float = _weapons.halo_radius()
	var c: Vector2 = _player.global_position
	# 一圈炮灰站在判定半径的 0.75 处：能同时看到"边界在哪"和"圈内在烧"
	for i in 10:
		var ang: float = TAU * float(i) / 10.0 + 0.15
		var e: Enemy = _pick(c + Vector2.from_angle(ang) * r * 0.75, "shot%d" % i)
		if e != null:
			e.hp_bar.visible = false
	await _wait(0.42)   # 让水波纹至少推出一圈
	await _save(SHOT_PATH, "花灯（站桩圆域）halo_radius = %.1f" % r)
	# 同一批敌人换到皮影的环绕半径上：只有环绕体转到的那一两只掉血 —— 这就是"环绕伤害"
	_enemies.clear_all()
	await _equip(["phone"], 1)
	await _frames(3)
	var orbit_r: float = 58.0
	for i in 10:
		var ang2: float = TAU * float(i) / 10.0 + 0.15
		var e2: Enemy = _pick(c + Vector2.from_angle(ang2) * orbit_r, "pshot%d" % i)
		if e2 != null:
			e2.hp_bar.visible = false
	await _wait(0.60)
	await _save(SHOT_ORBIT, "皮影（绕身碰撞）orbit_r = %.1f" % orbit_r)

func _save(path: String, title: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("\n[截图] headless 下跳过（要真实渲染才能出图）")
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("\n[截图] %s → %s" % [title, ProjectSettings.globalize_path(path)])

# ---------------------------------------------------------------- 小工具
func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _fmt(a: Array[float]) -> Array[String]:
	var out: Array[String] = []
	for v in a:
		out.append("%.3f" % v)
	return out
