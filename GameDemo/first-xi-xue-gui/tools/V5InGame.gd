extends Node

# ============================================================================
# v5 局内重写验收（Phase 1–4 的真实代码路径断言）
# ----------------------------------------------------------------------------
# 用法：godot --headless --path . res://tools/V5InGame.tscn
#
# 与 SmokeTest 的分工：
#   SmokeTest  保证"老的一局还能玩完"（299+ 条，端到端）。
#   V5InGame   专门验 v5 新增的每一条机制**真的按方案生效**：
#              三把新武器 / 引爆规则 / 减速加伤 / 击退 / 双扫 / 落点延迟 /
#              结壳倍率 / 潮涌 / 更鼓 / 震吼 / 精炼 / 回春结界。
#
# 为什么断言要"从数据反推期望值"，而不是回读被测代码：
#   本工程踩过一次 —— `size.x * 0.9 <= size.x` 恒真，把一个 3.4 倍的尺寸错误放过去了。
#   所以这里所有期望值都来自 v5_model.py 的公式（在下面的 _model_dps 里独立实现一遍），
#   或者来自"打之前的血量"这种外部事实。
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"
## 模型口径：30min 同屏密度（v5_model.py 的 density(1800)）
const N_ALIVE := 400.0
const AREA_SCREEN := 720.0 * 1280.0
## v5_result.json 的 band（只对三把新武器要求逐字一致，见报告"口径说明"）
const BAND_EXPECT := {"gong": 124.0, "inkline": 135.0, "print": 149.0}
const INKLINE_SINGLE_EXPECT := 100.0

var _bad: Array[String] = []
var _meta_backup: Dictionary = {}
var _game: GameScene
var _player: Player
var _enemies: EnemyPool
var _weapons: WeaponManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 测的是玩法逻辑，不是呈现：摘掉 60 帧上限，否则所有 _wait 都按墙钟跑
	Engine.max_fps = 0
	await get_tree().process_frame
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_node("World/Player") as Player
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	# 停掉 Game 自己的 _process（刷怪 / 计时 / Boss 调度），
	# 否则每个用例都会被打进来的杂兵污染。武器与敌人逻辑照常跑。
	_game.set_process(false)
	_enemies.clear_all()
	# 局外乘数会把每一个"期望值"整体放大（实测 +12%），必须清零再验。
	# 备份/还原照抄 SmokeTest 的做法：跑测试不该抹掉玩家的商店进度。
	_meta_backup = MetaSave.snapshot()
	MetaSave.debug_set(0, {})
	GameManager.stats = Stats.make_base()
	_player.stats = GameManager.stats
	_weapons.stats = GameManager.stats
	print("\n===== v5 局内重写验收（真实代码路径）=====")

	# ⚠️ 每条用例都必须 await：只要用例内部有 await，它就是协程；
	# 不 await 的话 _ready 会一路冲到 _case_ui，而前面那些用例稍后才恢复 ——
	# 它们会互相 _reset() 对方的战场（本文件第一版就踩了：击退量测出 0.00）。
	await _case_data()
	await _case_evolutions()
	await _case_band()
	await _case_passives()
	await _case_refine()
	await _case_pierce_milestone()
	await _case_whip_double()
	await _case_halo_slow_bonus()
	await _case_gong_halo_distinct()
	await _case_knock()
	await _case_shatter()
	await _case_print_delay()
	await _case_shell()
	await _case_shell_window()
	await _case_surge_drum()
	await _case_new_weapons_hit()
	await _case_extinguisher_aim()
	await _case_v6_awaken()
	await _case_roar()
	await _case_ui()

	print("\n---------- 汇总 ----------")
	if _bad.is_empty():
		print("全部通过 OK（%d 条断言）" % _ok_count)
	else:
		for f in _bad:
			print("失败: ", f)
	await get_tree().create_timer(0.2).timeout
	MetaSave.debug_set(int(_meta_backup.get("coins", 0)), _meta_backup.get("levels", {}) as Dictionary)
	get_tree().quit(0 if _bad.is_empty() else 1)

# ---------------------------------------------------------------- 断言基座
var _ok_count := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		_ok_count += 1
		print("  ok   ", msg)
	else:
		_bad.append(msg)
		print("  FAIL ", msg)

func _near(a: float, b: float, eps: float, msg: String) -> void:
	_check(absf(a - b) <= eps, "%s（实测 %.2f / 期望 %.2f ±%.2f）" % [msg, a, b, eps])

## 把一个用例的沙盒复位：清场 + 清背包 + 清进化/精炼 + 时间归零
func _reset() -> void:
	_enemies.clear_all()
	# 必须连同在飞弹体一起召回：弹体是 ticking 的，上一条用例打出去的那几颗
	# 会在下一条用例的敌人身上命中，把伤害断言随机抬高（1/3 概率复现）。
	_weapons.clear_bullets()
	_weapons.owned = {}
	_weapons.evolved = {}
	_weapons.refines = {}
	_weapons._cd = {}
	_weapons.run_time = 0.0
	_player.active_skill.cd_left = 0.0

func _spawn(x: float, y: float, hp: float, shelled: bool = false) -> Enemy:
	return _enemies.spawn(_player.global_position + Vector2(x, y), hp, 0.0, 1, "cup", false,
		WaveTable.CONTACT_DAMAGE, false, shelled)

# ---------------------------------------------------------------- Phase 1：数据层
func _case_data() -> void:
	print("\n[1] 数据层：9 把武器 / 9 条被动 / 6 个进化")
	_check(WeaponDB.ORDER.size() == 9, "ORDER 收录 9 把武器")
	for id in ["gong", "inkline", "print"]:
		_check(WeaponDB.has_weapon(id) and not WeaponDB.def(id).is_empty(),
			"新武器 %s 可被 has_weapon/def 命中（%s）" % [id, WeaponDB.display_name(id)])
	# 参数逐字取自 v5_model.py：拍过数就会在这里露出来
	_near(float(WeaponDB.def("gong")["radius"]), 150.0, 0.01, "铜锣基准半径 = 模型 150")
	_near(float(WeaponDB.def("gong")["amp"]), 0.12, 0.001, "铜锣破壳微增益 amp = 0.12")
	_near(float(WeaponDB.def("inkline")["shell_bonus"]), 1.80, 0.001, "墨斗 shell_bonus = 1.80")
	_near(float(WeaponDB.def("print")["delay"]), 0.45, 0.001, "年画落点延迟 = 0.45s")
	_near(float(WeaponDB.def("print")["radius"]), 105.0, 0.01, "年画半径 = 105")
	# 机制字段
	_near(float(WeaponDB.def("halo")["slow_pct"]), 0.22, 0.001, "花灯减速 0.15 → 0.22")
	_near(float(WeaponDB.def("halo")["slow_dmg"]), 0.20, 0.001, "花灯对减速敌 +20%")
	_near(float(WeaponDB.def("phone")["knock"]), 0.15, 0.001, "皮影击退 0.15")
	# v7 T8：铁水散开三件套。数值由 v7_model.py 反推（见 dmg_per_level 注释），
	# 这里断的是**口径**：半径 150 / 比例 0.40 / 上限 16。
	_near(float(WeaponDB.def("extinguisher")["scatter_radius"]), 150.0, 0.01, "铁水散开半径 150")
	_near(float(WeaponDB.def("extinguisher")["scatter_ratio"]), 0.28, 0.001, "铁水散开比例 0.28")
	_check(WeaponDB.scatter_cap_at("extinguisher", 1) == 4, "Lv1 只溅 4 只")
	_check(WeaponDB.scatter_cap_at("extinguisher", 8) == 18,
		"Lv8 溅 18 只（几何密度约 15，实际由密度封顶）")
	_check(not WeaponDB.def("extinguisher").has("explode_radius"),
		"旧的 explode_* 字段已退役（不留两套说法）")
	_check(bool(WeaponDB.def("blade")["bounce_falloff"]), "剪纸带弹射衰减标记")
	_check(bool(WeaponDB.def("whip")["double_sweep"]), "师刀带双扫标记")

func _case_evolutions() -> void:
	_check(EvolutionDB.FORMS.size() == 9, "进化配方 9 条（6 旧 + 3 迭代02 新增）")
	_near(float(EvolutionDB.form("evolve_gong")["dps_mult"]), 1.50, 0.001, "开市锣 dps×1.50")
	_near(float(EvolutionDB.form("evolve_gong")["area_mult"]), 1.50, 0.001, "开市锣 area×1.50")
	_near(float(EvolutionDB.form("evolve_inkline")["dps_mult"]), 1.55, 0.001, "龙筋墨线 dps×1.55")
	_near(float(EvolutionDB.form("evolve_extinguisher")["area_mult"]), 1.40, 0.001, "百子千花 area×1.40")
	_check(not EvolutionDB.form("evolve_extinguisher").has("explode_every"),
		"百子千花不再靠 explode_every：行为差异在武器侧（碎裂多迸一圈），进化侧只给倍率")
	_check(EvolutionDB.req_passive("gong") == "area", "开市锣要火候")
	_check(EvolutionDB.req_passive("inkline") == "damage", "龙筋墨线要匠心")
	# 配方门槛：Lv8 + 被动 ≥1
	_check(not EvolutionDB.meets_recipe("gong", 8, 0), "Lv8 但没点被动 → 不进宝箱候选")
	_check(EvolutionDB.meets_recipe("gong", 8, 1), "Lv8 + 火候 1 → 可进化")

## 收敛带：用 v5_model.py 的同一条公式在 GDScript 里独立算一遍。
## 只对三把新武器要求「与结果 JSON 逐字一致」——
## 既有 6 把沿用 v3.1 手感值（playbook §6 Phase 1 只要求给它们加机制字段，不重调数值）。
func _case_band() -> void:
	print("\n[2] 收敛带：三把新武器 Lv8 总 DPS 对齐 v5_result.json")
	for wid in ["gong", "inkline", "print"]:
		var d: Array = _model_dps(wid, 8)
		_near(d[0], BAND_EXPECT[wid], 1.5, "%s Lv8 总 DPS" % WeaponDB.display_name(wid))
	var ink: Array = _model_dps("inkline", 8)
	_near(ink[1], INKLINE_SINGLE_EXPECT, 1.5, "墨斗 Lv8 单体 DPS 独占单点头牌（100）")
	# 收敛带：三把新武器必须全落在 96–157，且互相跨度 <2×
	var lo := 1e9
	var hi := 0.0
	for wid in ["gong", "inkline", "print"]:
		var v: float = _model_dps(wid, 8)[0]
		lo = minf(lo, v)
		hi = maxf(hi, v)
		_check(v >= 96.0 and v <= 157.0, "%s Lv8 落在收敛带 96–157（%.0f）" % [wid, v])
	_check(hi / maxf(lo, 0.01) < 2.0, "三把新武器跨度 <2×（%.0f ~ %.0f）" % [lo, hi])
	# 既有 6 把不参与收敛带断言：它们保留 v3.1 手感值（playbook §6 Phase 1 只要求加机制字段）。
	# 这里把模型口径的值打出来，作为"若要全面对齐模型，会改动哪些手感"的清单。
	var line := "既有 6 把的模型口径 Lv8 总 DPS（仅供对照，不参与断言）："
	for wid in ["whip", "halo", "glowstick", "phone", "blade", "extinguisher"]:
		line += " %s=%.0f" % [wid, _model_dps(wid, 8)[0]]
	print("  info  " + line)

func _case_passives() -> void:
	print("\n[3] 新被动：回春 / 结界")
	_check(Stats.STAT_KEYS.size() == 9, "STAT_KEYS 7 → 9")
	# v7（v6 策划案 ③ 落地）：回春改涓流（+0.6×lv，封顶 3.0/s），
	# 结界改累积（每 8s 一脉冲 5+3×lv，池上限 30+6×lv）。
	# 断言直接读常量而不是写字面量 —— 字面量会在下一次调数时变成"测试说 7.5、代码是 3.0"。
	_near(Stats.value_at("regen", 5), Stats.regen_cap(), 0.001,
		"回春满级 = 封顶 %.1f/s（涓流，不再是 7.5/s 的续航引擎）" % Stats.regen_cap())
	_near(Stats.value_at("regen", 4), Stats.REGEN_PER_LV * 4.0, 0.001,
		"回春 Lv4 仍在线性段（%.1f/s，未触顶）" % (Stats.REGEN_PER_LV * 4.0))
	_near(Stats.value_at("shield", 5), Stats.SHIELD_BASE + Stats.SHIELD_PER_LV * 5.0, 0.001,
		"结界每 %.0fs 一脉冲 = %.0f 点" % [Stats.SHIELD_PERIOD, Stats.value_at("shield", 5)])
	_near(Stats.shield_cap(5), Stats.SHIELD_CAP_BASE + Stats.SHIELD_CAP_PER * 5.0, 0.001,
		"结界满级盾池上限 %.0f（叠加但不无限）" % Stats.shield_cap(5))
	_near(Stats.value_at("shield", 0), 0.0, 0.001, "没点结界时护盾脉冲为 0（不是白送 30）")
	_near(Stats.shield_cap(0), 0.0, 0.001, "没点结界时盾池上限也是 0")
	var base: Dictionary = Stats.make_base()
	_near(float(base["regen"]), 0.0, 0.001, "开局 regen = 0")
	_near(float(base["shield"]), 0.0, 0.001, "开局 shield = 0")
	# 文案必须和数值同一口径（上一轮返工的核心）
	var t: String = CardText.stat_desc("regen", 1)
	_check(t.contains("0.6"), "回春卡面写出 +0.6/s（实测「%s」）" % t.replace("\n", " / "))
	# 结界卡面必须**同时**说脉冲值与上限：只说脉冲，玩家会把 36 的池子读成 8 的上限。
	var t2: String = CardText.stat_desc("shield", 1)
	_check(t2.contains("8") and t2.contains("36"),
		"结界卡面同时写出脉冲 8 与上限 36（实测「%s」）" % t2.replace("\n", " / "))

func _case_refine() -> void:
	print("\n[4] 精炼：武器级乘区，不进全局公式")
	_near(Stats.refine_mult(0), 1.0, 0.001, "0 层精炼 ×1.00")
	_near(Stats.refine_mult(3), 1.18, 0.001, "3 层精炼 ×1.18（+6%/层）")
	_near(Stats.refine_mult(9), 1.18, 0.001, "超过 3 层被钳制（不会无限叠）")
	# 精炼不得污染 effective_at：全局伤害公式必须还是 1.0 + 0.10L
	_near(Stats.effective_at("damage", 5), 1.5, 0.001, "effective_at('damage',5) 仍是 ×1.50（没被精炼串味）")
	# 进游戏：同一把武器 tier 0 vs tier 3 的出手伤害差 18%
	_reset()
	_weapons.owned = {"gong": 8}
	_weapons.set_refine("gong", 0)
	var d0: float = _weapons.weapon_damage("gong", 8)
	_weapons.set_refine("gong", 3)
	var d3: float = _weapons.weapon_damage("gong", 8)
	_near(d3 / maxf(d0, 0.01), 1.18, 0.002, "满级铜锣精炼 3 层后出手伤害 ×1.18")
	# 满级武器再抽 → 出精炼卡（而不是空池）。
	# 先把层数降回来：3 层已满时本来就不该再出卡（那是"没有可投入的余地"）
	_weapons.set_refine("gong", 0)
	var found := false
	for e in UpgradeDB.draw(40):
		if int(e.get("refine", 0)) > 0:
			found = true
	_check(found, "满级武器会重新出现在卡池里，以「精炼」形态")
	_reset()

func _case_pierce_milestone() -> void:
	print("\n[5] 糖画穿透里程碑：Lv4 / Lv8 各 +1（不是线性）")
	_check(WeaponDB.pierce_at("glowstick", 3) == 1, "Lv3 穿透仍是 1")
	_check(WeaponDB.pierce_at("glowstick", 4) == 2, "Lv4 穿透 → 2（第一个里程碑）")
	_check(WeaponDB.pierce_at("glowstick", 7) == 2, "Lv7 仍是 2（里程碑之间不涨）")
	_check(WeaponDB.pierce_at("glowstick", 8) == 3, "Lv8 穿透 → 3（第二个里程碑）")
	_check(WeaponDB.count_at("glowstick", 8) == 4, "糖画 Lv8 发数 4（发数与穿透是两个轴）")

# ---------------------------------------------------------------- Phase 2：武器机制
func _case_whip_double() -> void:
	print("\n[6] 师刀 Lv7 双扫（各 60%）")
	_reset()
	# 【本用例必须关掉自动开火】这里的测量口径是"手动 fire_whip 一刀 + 0.12s 后补的 60%"。
	# _reset() 会把 _cd 清空，而 _tick_cd 对缺失的 key 按 0 处理 —— 于是 owned 里一有 whip，
	# 下一帧 _process 就会自动补一刀（此时 _side 已被手动那一刀翻面，打在背后，不进 d1），
	# 它同时也排了一次"第二刀"，结果 d2 变成 2×9.6 = 19.2，比值 1.20。
	# 这条曾经实测稳定红：不是产品算错，是测量把两刀算成了三刀。
	_weapons.set_process(false)
	_weapons.owned = {"whip": 7}
	var e: Enemy = _spawn(90.0, 0.0, 99999.0)
	await get_tree().process_frame
	var hp0: float = e.hp
	_weapons._side = 1
	_weapons.fire_whip(_player)
	var d1: float = hp0 - e.hp
	# 期望值从数据独立算：damage_at(whip,7,1.0) = 10 + 1×6 = 16
	_near(d1, WeaponDB.damage_at("whip", 7, 1.0), 0.5, "第一刀伤害 = Lv7 单发伤害 16")
	await get_tree().create_timer(0.3).timeout
	var d2: float = hp0 - e.hp - d1
	_near(d2 / maxf(d1, 0.01), 0.60, 0.02, "第二刀 = 第一刀的 60%（错开 0.12s 补上）")
	# Lv6 不该有第二刀
	_reset()
	_weapons.owned = {"whip": 6}
	var e2: Enemy = _spawn(90.0, 0.0, 99999.0)
	await get_tree().process_frame
	var h2: float = e2.hp
	_weapons._side = 1
	_weapons.fire_whip(_player)
	await get_tree().create_timer(0.3).timeout
	_near(e2.hp, h2 - WeaponDB.damage_at("whip", 6, 1.0), 0.5, "Lv6 只扫一刀（双扫是 Lv7 里程碑）")
	_weapons.set_process(true)

func _case_halo_slow_bonus() -> void:
	print("\n[7] 花灯：对已减速敌人 +20%")
	_reset()
	_weapons.owned = {"halo": 8}
	var e: Enemy = _spawn(30.0, 0.0, 99999.0)
	await get_tree().process_frame
	var h0: float = e.hp
	_weapons.fire_halo(_player)
	var d1: float = h0 - e.hp
	_check(d1 > 0.0, "花灯命中贴身敌人（%.1f 伤）" % d1)
	# 第一次命中已经上了减速；第二次应当吃到 +20%
	var h1: float = e.hp
	_weapons.fire_halo(_player)
	var d2: float = h1 - e.hp
	_near(d2 / maxf(d1, 0.01), 1.20, 0.02, "第二下（敌人已减速）×1.20")
	_check(e.is_slowed(), "命中后敌人处于减速状态（slow 0.22）")

## 铜锣和花灯**必须长得不一样**。
##
## 背景：v5 把铜锣归类成"光环型"后，Player 一度按 `has_weapon("halo") or has_weapon("gong")`
## 决定是否显示 GarlicRing 的常驻圈，于是只装铜锣的玩家脚下也有一个和花灯一模一样的
## 橙圈 + 水波纹 —— 两个技能彻底分不开，而且常驻圈在暗示"一直有伤害"，
## 跟铜锣 1.8s 敲一次的节奏直接矛盾。
##
## 现在：花灯 = 常驻橙圈（领域）；铜锣 = 一次性冷白声波 + 中心锣面（敲击）。
## 下面几条把"分得开"钉住，防止有人再把两者合并回同一个圈。
func _case_gong_halo_distinct() -> void:
	print("
[7b] 铜锣 / 花灯 视觉必须可区分")
	_reset()

	# ① 只装铜锣时不许有常驻光环圈：铜锣是一次性爆发，范围由冲击波当场表达
	_weapons.owned = {"gong": 8}
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not _player.garlic_ring.visible,
		"只装铜锣时不应出现常驻光环圈（实际 visible=%s）" % str(_player.garlic_ring.visible))

	# ② 装花灯 → 常驻圈出现，且半径严格等于花灯判定半径
	_weapons.owned = {"halo": 8}
	# ⚠️ 必须等**物理帧**：garlic_ring.visible 是 Player._physics_process 写的，
	#    而 process_frame 在 max_fps=0 下一帧只要 6ms —— 两个渲染帧可能一个物理 tick 都没跨过，
	#    断言读到的是上一帧的 false（这条以前偶发红，就是这么来的）。
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_player.garlic_ring.visible, "装花灯后常驻光环圈应出现")
	_near(_player.garlic_ring.radius, _weapons.halo_radius(), 0.5,
		"常驻圈半径 = 花灯判定半径")

	# ③ 铜锣的冲击波必须带径向声波刺。
	#    rays = 0 的纯环和花灯命中时的"灯晕一跳"完全同形，等于没区分。
	var wave: ColorRect = ShaderFX.shockwave(
		_weapons, _player.global_position, 440.0, WeaponManager.GONG_WAVE_COLOR, 16, 0.30)
	var wm: ShaderMaterial = wave.material as ShaderMaterial
	var rays_v: int = int(wm.get_shader_parameter("rays")) if wm != null else -1
	_check(rays_v > 0,
		"铜锣冲击波带径向声波刺（rays=%d，纯环会和花灯同形）" % rays_v)
	# ④ 颜色也要拉开：铜锣是金属白热反光（B 通道高），花灯是烛火橙（B 通道低）
	var halo_tint := Color(1.0, 0.78, 0.32)   # fire_halo 放的那圈"灯晕一跳"
	var gc: Color = WeaponManager.GONG_WAVE_COLOR
	_check(gc.b - halo_tint.b > 0.3,
		"铜锣色比花灯更白（B 通道 %.2f vs %.2f）" % [gc.b, halo_tint.b])
	# 收掉这个演示节点：它自己的 tween 会把 queue_free 挂在 0.3s 后，
	# 这里只隐藏，避免和后续用例抢同一帧的渲染
	wave.visible = false

func _case_knock() -> void:
	print("\n[8] 皮影击退")
	_reset()
	var e: Enemy = _spawn(200.0, 0.0, 99999.0)
	await get_tree().process_frame
	var x0: float = e.global_position.x
	e.knock_back(Vector2(1, 0), 0.15)
	var moved: float = e.global_position.x - x0
	# 期望值 = 0.15 × 身体尺寸（48px 杂兵 → 7.2px），不是固定像素
	_near(moved, 0.15 * e.size, 0.2, "击退距离 = 0.15 × 体长（48px 杂兵约 7.2px）")

func _case_shatter() -> void:
	print("\n[9] 铁水碎裂：每发一次 / 直击者不吃自己的溅射 / 有上限")
	_reset()
	var a: Enemy = _spawn(100.0, 0.0, 99999.0)
	var b: Enemy = _spawn(140.0, 0.0, 99999.0)
	await get_tree().process_frame
	var bullet := WeaponManager.Bullet.new()
	bullet.id = "extinguisher"
	bullet.dmg = 100.0
	bullet.pos = a.global_position
	var ha: float = a.hp
	var hb: float = b.hp
	_weapons._shatter(bullet, a)
	_near(a.hp, ha, 0.01, "被直接命中的 A 不吃自己触发的溅射（防双算）")
	# 期望值 = 100 × scatter_ratio，不受任何被动影响（此时 stats 全 1.0）
	var sr: float = float(WeaponDB.def("extinguisher")["scatter_ratio"])
	_near(hb - b.hp, 100.0 * sr, 1.5, "散开范围内的 B 吃到 %.0f 伤" % (100.0 * sr))
	var hb2: float = b.hp
	_weapons._shatter(bullet, a)
	_near(b.hp, hb2, 0.01, "同一发只碎一次（否则同一群被反复溅）")

	# ---- 上限：圈里挤满时不能一发清半屏 ----
	# 这是 T8 最容易被忽略的一条：半径从 76 提到 150 是面积 3.9 倍，
	# 没有封顶的话"大范围小伤害"会变成"大范围清场"。测 Lv8 是因为
	# 收敛带取的就是 Lv8 —— Lv1 那档不需要守。
	_reset()
	_weapons.owned = {"extinguisher": 8}
	var cap: int = WeaponDB.scatter_cap_at("extinguisher", 8)
	var many: Array[Enemy] = []
	for i in cap + 4:
		many.append(_spawn(float(60 + i * 4), 0.0, 99999.0))
	await get_tree().process_frame
	var before: Array[float] = []
	for e in many:
		before.append(e.hp)
	var b3 := WeaponManager.Bullet.new()
	b3.id = "extinguisher"
	b3.dmg = 100.0
	b3.pos = many[0].global_position
	_weapons._shatter(b3, many[0])
	var got := 0
	for i in many.size():
		if many[i].hp < before[i]:
			got += 1
	_check(got == cap, "圈里 %d 只只有 %d 只掉血（上限生效，实测 %d）" % [many.size(), cap, got])
	_check(many[0].hp == before[0], "被直击的那只在超限时也不吃溅射")

	# ---- 进化百子千花：碎裂即多迸一圈，不再是"每 2 命中才炸" ----
	_reset()
	_weapons.evolved = {"extinguisher": "evolve_extinguisher"}
	var c: Enemy = _spawn(100.0, 0.0, 99999.0)
	var d: Enemy = _spawn(140.0, 0.0, 99999.0)
	await get_tree().process_frame
	var b2 := WeaponManager.Bullet.new()
	b2.id = "extinguisher"
	b2.dmg = 100.0
	b2.pos = c.global_position
	var hd: float = d.hp
	b2.hits_done = 1
	_weapons._shatter(b2, c)
	_check(d.hp < hd, "百子千花：第 1 次碎裂就结算（旧版要等第 2 命中）")

func _case_print_delay() -> void:
	print("\n[10] 木版年画：0.45s 延迟落点")
	_reset()
	_weapons.owned = {"print": 8}
	var e: Enemy = _spawn(60.0, 0.0, 99999.0)
	await get_tree().process_frame
	var h0: float = e.hp
	_weapons.fire_print(_player)
	_near(e.hp, h0, 0.01, "按下瞬间不结算（雕版还在天上）")
	await get_tree().create_timer(0.7).timeout
	_check(e.hp < h0, "0.45s 后落地结算（掉了 %.1f）" % (h0 - e.hp))

func _case_shell() -> void:
	print("\n[11] 浆壳兵：血 ×1.40 / 吃 AoE ×0.75 / 吃墨斗 ×1.80")
	_reset()
	var e: Enemy = _spawn(0.0, 200.0, 100.0, true)
	await get_tree().process_frame
	_check(e.shelled, "结壳标记生效")
	_near(e.max_hp, 140.0, 0.01, "结壳后血量 ×1.40（100 → 140）")
	# 四种来源分别验：期望值都从 WeaponDB 的字段独立算
	var e1: Enemy = _spawn(0.0, 240.0, 100.0, true)
	var e2: Enemy = _spawn(0.0, 280.0, 100.0, true)
	var e3: Enemy = _spawn(0.0, 320.0, 100.0, true)
	var e4: Enemy = _spawn(0.0, 360.0, 100.0, true)
	await get_tree().process_frame
	e1.take_damage(10.0, &"inkline")
	_near(140.0 - e1.hp, 10.0 * 1.80, 0.01, "墨斗打结壳 ×1.80（官方解）")
	e2.take_damage(10.0, &"whip")
	_near(140.0 - e2.hp, 10.0 * 0.75, 0.01, "师刀（AoE）打结壳 ×0.75")
	e3.take_damage(10.0, &"glowstick")
	_near(140.0 - e3.hp, 10.0, 0.01, "糖画（单点）打结壳不吃减免")
	e4.take_damage(10.0, &"gong")
	_near(140.0 - e4.hp, 10.0 * (0.75 + 0.12), 0.01, "铜锣自带 amp=0.12 → ×0.87")
	# 不结壳的杂兵不该有任何减免
	var e5: Enemy = _spawn(0.0, 400.0, 100.0, false)
	await get_tree().process_frame
	e5.take_damage(10.0, &"whip")
	_near(100.0 - e5.hp, 10.0, 0.01, "未结壳的杂兵：AoE 全额")

func _case_shell_window() -> void:
	print("\n[12] 浆壳时间窗 8–20min")
	_near(WaveTable.shell_w(479.0), 0.0, 0.001, "8min 前不上壳")
	_near(WaveTable.shell_w(480.0), 1.0, 0.001, "8min 起满强度")
	_near(WaveTable.shell_w(1020.0), 1.0, 0.001, "17min 仍是满强度")
	_near(WaveTable.shell_w(1110.0), 0.5, 0.01, "17–20min 线性溃散（中点 0.5）")
	_near(WaveTable.shell_w(1200.0), 0.0, 0.001, "20min 消失")
	_check(WaveTable.shelled_now(1109.0, 0.4) and not WaveTable.shelled_now(1109.0, 0.6),
		"溃散期按概率上壳：w≈0.51 时 r=0.4 上壳、r=0.6 不上")

func _case_surge_drum() -> void:
	print("\n[13] 潮涌 / 更鼓")
	_near(WaveTable.surge_mult(600.0), 1.35, 0.001, "10min 潮涌 lam ×1.35")
	_near(WaveTable.surge_mult(615.0), 1.35, 0.001, "潮涌持续期内仍是 ×1.35")
	_near(WaveTable.surge_mult(630.0), 1.0, 0.001, "22s 后回稳态（只做尖峰）")
	_near(WaveTable.surge_mult(1780.0), 1.55, 0.001, "终局前长潮 ×1.55")
	_near(WaveTable.surge_elite_add(900.0), 0.10, 0.001, "二更潮涌精英 +0.10")
	_check(not WaveTable.surge_due(599.0, 601.0).is_empty(), "跨越 600s 触发一次预警")
	_check(WaveTable.surge_due(601.0, 602.0).is_empty(), "预警不会每帧重复触发")
	_near(WaveTable.drum_mult(0.0), 1.00, 0.001, "开局更鼓 ×1.00")
	_near(WaveTable.drum_mult(600.0), 1.16, 0.001, "10min（两更）×1.16")
	_near(WaveTable.drum_mult(1800.0), 1.40, 0.001, "30min（五更）×1.40")
	# 更鼓真的进伤害：run_time 同步后同一把武器强 8%
	_reset()
	_weapons.owned = {"gong": 8}
	var d0: float = _weapons.weapon_damage("gong", 8)
	_weapons.run_time = 300.0
	var d1: float = _weapons.weapon_damage("gong", 8)
	_near(d1 / maxf(d0, 0.01), 1.08, 0.001, "过第一更后出手伤害 ×1.08")
	_weapons.run_time = 1800.0
	_near(_weapons.weapon_damage("gong", 8) / maxf(d0, 0.01), 1.40, 0.002, "30min 出手伤害 ×1.40")
	_reset()

func _case_new_weapons_hit() -> void:
	print("\n[14] 三把新武器真的能发射 / 命中 / 结算")
	for wid in ["gong", "inkline", "print"]:
		_reset()
		_weapons.owned = {wid: 4}
		var e: Enemy = _spawn(70.0, 0.0, 99999.0)
		await get_tree().process_frame
		var h0: float = e.hp
		_weapons._cd[wid] = 0.0
		_weapons.fire(wid, _player)
		await get_tree().create_timer(0.7).timeout
		_check(e.hp < h0, "%s（%s）造成了 %.1f 伤害" % [wid, WeaponDB.display_name(wid), h0 - e.hp])

# ---------------------------------------------------------------- 打铁花锁定
## 回归：打铁花曾用 `randf() * TAU` 当基准角再 360/count 均分，
## 结果两发永远背靠背 180°、且和场上敌人毫无关系。
## 这组断言把"朝最近的两个敌人分别飞"钉死 —— 否则下次有人改回随机，门禁不会响。
func _case_extinguisher_aim() -> void:
	print("\n[13b] 打铁花：每发朝一个最近目标（不是背靠背均分）")
	var d: Dictionary = WeaponDB.def("extinguisher")
	var count: int = int(d.get("count", 2))

	# ① 一只敌人在正东：两发都该朝东（补位散角 ≤ 36°），不该出现"一发朝西"
	_reset()
	_weapons.owned = {"extinguisher": 1}
	_weapons.set_process(false)   # 锁死自动开火，只测这一炮
	var east: Enemy = _spawn(400.0, 0.0, 99999.0)
	await get_tree().process_frame
	_weapons.fire_extinguisher(_player)
	var east_angles: Array[float] = []
	for b in _weapons._bullets:
		east_angles.append(b.vel.angle())
	_check(east_angles.size() == count, "射出 %d 发（数量契约不变）" % count)
	var max_dev: float = 0.0
	for a in east_angles:
		max_dev = maxf(max_dev, absf(angle_difference(a, 0.0)))
	_check(max_dev < deg_to_rad(40.0),
		"单目标时全部朝东（最大偏角 %.1f°）" % rad_to_deg(max_dev))

	# ② 两个敌人一东一北：两发应分别指向两块，夹角接近 90°，而不是 180°
	_reset()
	_weapons.owned = {"extinguisher": 1}
	_weapons.set_process(false)
	_spawn(400.0, 0.0, 99999.0)
	_spawn(0.0, -400.0, 99999.0)
	await get_tree().process_frame
	_weapons.fire_extinguisher(_player)
	var two: Array[float] = []
	for b in _weapons._bullets:
		two.append(b.vel.angle())
	_check(two.size() == 2, "两目标时射出 2 发")
	if two.size() == 2:
		var sep: float = absf(rad_to_deg(angle_difference(two[0], two[1])))
		_check(sep > 70.0 and sep < 110.0,
			"两发分别对准东/北（夹角 %.1f°，旧实现恒为 180°）" % sep)
		# 逐发对齐：每一发都必须能在"最近两个"里找到方向吻合的目标
		var want: Array[float] = [0.0, -PI * 0.5]
		var paired: bool = true
		for a in two:
			var hit: bool = false
			for w in want:
				if absf(rad_to_deg(angle_difference(a, w))) < deg_to_rad(40.0):
					hit = true
			paired = paired and hit
		_check(paired, "每一发都指向一个实际存在的最近目标")

	# ③ 零敌人：不能抛给不存在的目标，退回均分（数量不变）
	_reset()
	_weapons.owned = {"extinguisher": 1}
	_weapons.set_process(false)
	await get_tree().process_frame
	_weapons.fire_extinguisher(_player)
	_check(_weapons._bullets.size() == count, "空场也射出 %d 发（退回均分，不空手）" % count)
	_clear_bullets()

	# ④ 远处敌人（超出弹体可达距离）不该被锁定成"朝它的方向"
	_reset()
	_weapons.owned = {"extinguisher": 1}
	_weapons.set_process(false)
	var far_x: float = float(d.get("bullet_speed", 300.0)) * 1.9 \
		+ float(d.get("scatter_radius", 150.0)) + 600.0
	var far_e: Enemy = _spawn(far_x, 0.0, 99999.0)
	await get_tree().process_frame
	_check(far_e.alive, "远处敌人（%.0f px）在场，下一条断言才有意义" % far_x)
	_weapons.fire_extinguisher(_player)
	var any_toward_far: bool = false
	for b in _weapons._bullets:
		if absf(rad_to_deg(angle_difference(b.vel.angle(), 0.0))) < deg_to_rad(15.0):
			any_toward_far = true
	_check(not any_toward_far, "超出可达距离的敌人不会被锁定（不追着屏幕外泼）")
	_clear_bullets()
	_weapons.set_process(true)

# ---------------------------------------------------------------- Phase 4：震吼
func _case_roar() -> void:
	print("\n[15] 主动技·震吼")
	_reset()
	_weapons.owned = {"glowstick": 8}
	var sd: float = _weapons.single_dps()
	_check(sd > 0.0, "单体 DPS 从构筑读出来（%.1f）" % sd)
	var e: Enemy = _spawn(120.0, 0.0, 99999.0)
	await get_tree().process_frame
	var h0: float = e.hp
	var ok: bool = _player.active_skill.try_cast()
	_check(ok, "CD 就绪时可以释放")
	_near(_player.active_skill.cd_left, 25.0, 0.01, "CD = 25s")
	_check(_player.invuln_left <= 0.701, "无敌 ≤ 0.7s（实测 %.2f）" % _player.invuln_left)
	# 期望值 = 2.5 × 单体 DPS（震吼不吃浆壳减免，所以这里用 1.0 的敌人）
	_near(h0 - e.hp, sd * 2.5, maxf(sd * 0.02, 0.5), "爆发伤害 = 250% 当前单体 DPS")
	_check(not _player.active_skill.try_cast(), "CD 期间再按无效")
	# 纯 AoE 构筑不该拿到 0 伤害的主动技
	_reset()
	_weapons.owned = {"halo": 8, "gong": 8}
	_check(_player.active_skill.burst_damage() > 0.0,
		"纯 AoE 构筑也有伤害（回落到总 DPS×30%%，实测 %.1f）" % _player.active_skill.burst_damage())

# ---------------------------------------------------------------- Phase 5：美术登记
func _case_ui() -> void:
	print("\n[17] 美术登记 / UI 接线")
	for p in [Art.GONG, Art.INKLINE, Art.WOODBLOCK_PRINT, Art.SHELL_CRUST,
			Art.PASSIVE_REGEN, Art.PASSIVE_SHIELD, Art.UI_SKILL_ROAR,
			Art.UI_REFINE_BADGE, Art.FX_SURGE_RING,
			Art.BOSS_DRUM, Art.BOSS_NUO, Art.BOSS_LANTERN]:
		_check(p in Art.ALL_PATHS, "%s 已登记进 ALL_PATHS" % p.get_file())
		_check(Art.tex(p) != null, "%s 能被 Art.tex 加载" % p.get_file())
	_check(Art.is_slot(Art.GONG, "weapon_gong"), "铜锣槽位别名命中")
	_check(Art.is_slot(Art.SHELL_CRUST, "enemy_shell"), "结壳层槽位别名命中")
	_check(Art.evolved_weapon_svg("gong") == Art.GONG_EVOLVED, "铜锣进化有独立贴图")
	_check(Art.evolved_weapon_svg("whip") == "", "没有独立进化图的武器回落本体（返回空串）")
	var hud: HUD = _game.get_node("UI/HUD") as HUD
	_check(hud.get_node_or_null("SkillBtn") != null, "HUD 上挂了震吼按钮")


# ---------------------------------------------------------------- v6 满级觉醒接线
## v6 觉醒的**接线**验收（docs/design/v6_fx_art_plan.md §8 新增检查 2 / 4）。
##
## 与 V6Fx.tscn 的分工：
##   V6Fx        证明 shader 出得来（像素级：可见 / 不过曝 / 贴边 / 在流动）
##   本用例      证明"真的接进去了"—— 角标挂在 HUD 上、弹体换了图、走马灯跟着等级走、
##               小怪身上没有多出材质（合批红线）
## 上一轮踩过的坑：文件都在、shader 都能编译，但没人调用 —— 那种"全绿"是假的。
func _case_v6_awaken() -> void:
	print("\n[16] v6 满级觉醒接线")

	# ① 觉醒徽记：Lv7 不能在，Lv8 必须在
	#    （清单 §3.2「非 Lv8（含进化）时隐藏」）
	_reset()
	_weapons.owned = {"whip": WeaponDB.MAX_LEVEL - 1}
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_find_badge(_game.get_node("UI/HUD")) == null, "Lv7 槽位没有觉醒徽记")
	_weapons.owned = {"whip": WeaponDB.MAX_LEVEL}
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_find_badge(_game.get_node("UI/HUD")) != null, "Lv8 槽位出现觉醒徽记")

	# ② 走马灯流光：跟着 halo 等级走，Lv1~7 不显示
	#    （v6 §6 把"场边缘走马灯流光"列为觉醒钩子，不是常驻表现）
	_reset()
	_weapons.owned = {"halo": WeaponDB.MAX_LEVEL - 1}
	await get_tree().physics_frame
	await get_tree().physics_frame
	var st: ColorRect = _player.garlic_ring.get("_stream") as ColorRect
	_check(st != null and not st.visible, "Lv7 花灯没有走马灯流光")
	_weapons.owned = {"halo": WeaponDB.MAX_LEVEL}
	await get_tree().process_frame
	await get_tree().process_frame
	_check(st != null and st.visible, "Lv8 花灯出现走马灯流光")

	# ③ 弹体换图：打铁花 = 铁水团，墨斗 = 龙筋墨线（清单 §4 推荐项）
	#    只断言"弹道用了新图"，武器本体图仍是原来的（卡面不能被顶掉）
	_reset()
	_weapons.owned = {"extinguisher": 1}
	await get_tree().process_frame
	_weapons.fire_extinguisher(_player)
	var got_molten := false
	for b in _weapons._bullets:
		if b.id == "extinguisher":
			got_molten = b.node.texture != null \
				and b.node.texture.resource_path == Art.MOLTEN_BLOB
			break
	_check(got_molten, "打铁花弹体用的是 molten_blob（不是铁花勺本体图）")
	_check(WeaponDB.def("extinguisher").get("svg") == Art.AXE_EXTINGUISHER,
		"WeaponDB 的本体图没被弹体换图波及（卡面/槽位不变）")
	_clear_bullets()

	var t: Enemy = _spawn(220.0, 0.0, 99999.0)
	await get_tree().process_frame
	_weapons.owned = {"inkline": WeaponDB.MAX_LEVEL}
	await get_tree().process_frame
	_weapons.fire_inkline(_player)
	_check(not _weapons._bullets.is_empty(), "墨斗射出了墨线")
	if not _weapons._bullets.is_empty():
		var ib: WeaponManager.Bullet = _weapons._bullets[_weapons._bullets.size() - 1]
		_check(ib.node.texture != null and ib.node.texture.resource_path == Art.INK_LINE_TEX,
			"墨线用的是 ink_line_tex（可平铺龙筋长条）")
		_check(ib.node.scale.y > 1.5, "Lv8 墨线加粗（scale.y %.2f > 1.5）" % ib.node.scale.y)
	_clear_bullets()
	t.take_damage(999999.0)
	_enemies.clear_all()

	# ④ 铁水火星：真正碎的时候要开 molten_scatter，而不是退回 cast_burst
	_reset()
	var a: Enemy = _spawn(100.0, 0.0, 99999.0)
	await get_tree().process_frame
	var bullet := WeaponManager.Bullet.new()
	bullet.id = "extinguisher"
	bullet.dmg = 100.0
	bullet.pos = a.global_position
	_weapons._shatter(bullet, a)
	_check(_count_molten() >= 1, "碎裂点开了 molten_scatter（%d 个）" % _count_molten())
	# 视觉半径必须等于**结算半径**：画小了玩家会以为圈外安全，画大了会以为自己打到了。
	# 这条以前没人测，而散开半径刚从 76 改成 150，正好是最容易忘记同步的一处。
	var mr: float = _molten_radius()
	_near(mr, float(WeaponDB.def("extinguisher")["scatter_radius"]), 1.5,
		"火星画的就是结算半径 %.0f" % mr)

	# ④b 百子千花：同一次碎裂迸**两圈**（内圈更小），这是它的行为差异
	_reset()
	_weapons.evolved = {"extinguisher": "evolve_extinguisher"}
	var a2: Enemy = _spawn(100.0, 0.0, 99999.0)
	await get_tree().process_frame
	var bullet2 := WeaponManager.Bullet.new()
	bullet2.id = "extinguisher"
	bullet2.dmg = 100.0
	bullet2.pos = a2.global_position
	_weapons._shatter(bullet2, a2)
	await get_tree().create_timer(0.25).timeout
	_check(_count_molten() >= 2, "百子千花：同一碎裂点迸两圈火星（%d 个）" % _count_molten())

	# ⑤ 合批红线：花灯/铜锣打在小怪身上，**不能**给它们挂独立材质
	#    （减速走 art.modulate，清单 §1.3）
	_reset()
	_weapons.owned = {"halo": 3, "gong": 3}
	var m: Enemy = _spawn(40.0, 0.0, 99999.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_check(m.art.material == null, "被花灯/铜锣打中的小怪身上没有 ShaderMaterial（合批未破坏）")

	# ⑥ 师刀双斩的第二刀要有画面（原先只补判定不补特效）
	_reset()
	_weapons.owned = {"whip": WeaponDB.MAX_LEVEL}
	var before: int = _weapons.fx_active_count()
	_weapons.fire_whip(_player)
	await get_tree().create_timer(0.14).timeout
	_check(_weapons.fx_active_count() >= before + 2,
		"Lv8 双斩：0.14s 内同屏有 2 段弧光（实计 %d）" % _weapons.fx_active_count())
	await get_tree().create_timer(0.3).timeout

## 递归找角标节点：HUD 的槽位是运行时拼的，没有固定路径
func _find_badge(n: Node) -> Node:
	if n.name == "AwakenBadge":
		return n
	for c in n.get_children():
		var hit: Node = _find_badge(c)
		if hit != null:
			return hit
	return null

## 数 WeaponManager 下挂了 molten_scatter 的 ColorRect
func _count_molten() -> int:
	var n := 0
	for c in _weapons.get_children():
		if c is ColorRect:
			var mat: ShaderMaterial = (c as ColorRect).material as ShaderMaterial
			if mat != null and mat.shader == ShaderFX.SHADER_MOLTEN_SCATTER:
				n += 1
	return n

## 火星节点的**视觉半径**（节点边长的一半）。
## ShaderFX.molten_scatter 的契约是 edge = 2 × radius_px，所以这等于回读它收到的那个参数。
func _molten_radius() -> float:
	for c in _weapons.get_children():
		if c is ColorRect:
			var mat: ShaderMaterial = (c as ColorRect).material as ShaderMaterial
			if mat != null and mat.shader == ShaderFX.SHADER_MOLTEN_SCATTER:
				return (c as ColorRect).size.x * 0.5
	return -1.0

## 清空飞行中的弹道（含把它归还池子），避免污染后面的用例
func _clear_bullets() -> void:
	for b in _weapons._bullets:
		_weapons._release_bullet(b.node)
	_weapons._bullets.clear()

# ---------------------------------------------------------------- 模型公式（独立实现）
func _dens() -> float:
	return N_ALIVE / AREA_SCREEN

func _cap_eff(lv: int, cap: float) -> float:
	return 1.0 + (cap - 1.0) * float(lv - 1) / 7.0

## 与 docs/balance/v5_model.py 的 weapon_hits() 同构。
## 这里刻意重写一遍，而不是调 WeaponManager —— 否则就是"用被测代码验被测代码"。
func _model_hits(wid: String, lv: int) -> float:
	var d: Dictionary = WeaponDB.def(wid)
	var dens: float = _dens()
	match wid:
		"whip":
			var ln: float = float(d["length"]) + float(d["length_per_level"]) * float(lv - 1)
			return maxf(1.0, minf(PI * pow(ln * 0.5, 2.0) * 0.5 * dens, _cap_eff(lv, 8.0)))
		"halo", "gong":
			var r: float = float(d["radius"]) + float(d["radius_per_level"]) * float(lv - 1)
			var cap: float = float(d.get("cap", d.get("hit_cap", 10)))
			return maxf(1.0, minf(PI * r * r * 0.5 * dens, _cap_eff(lv, cap)))
		"extinguisher":
			var per: float = maxf(1.0, minf(320.0 * 36.0 * dens, _cap_eff(lv, 4.0)))
			return per * 2.0
		"glowstick":
			return float(mini(1 + (lv - 1) / 2, 4))
		"blade":
			return 1.0 + 3.0 * 0.70
		"inkline":
			return 1.0 + 0.35 * float(WeaponDB.pierce_at(wid, lv))
		"print":
			var rr: float = float(d["radius"])
			return maxf(1.0, minf(PI * rr * rr * 0.5 * dens * 1.8, _cap_eff(lv, 6.0)))
		"phone":
			var r2: float = float(d["orbit_radius"]) + float(d["orbit_radius_per_level"]) * float(lv - 1)
			return maxf(1.0, minf(PI * r2 * r2 * 0.5 * dens + 1.6, _cap_eff(lv, 12.0)))
	return 1.0

## 返回 [总 DPS, 单体 DPS]
func _model_dps(wid: String, lv: int) -> Array:
	var dmg: float = WeaponDB.damage_at(wid, lv, 1.0)
	var cd: float = WeaponDB.cooldown_at(wid, lv, 1.0)
	var single: float = dmg / cd
	return [dmg * _model_hits(wid, lv) / cd, single]
