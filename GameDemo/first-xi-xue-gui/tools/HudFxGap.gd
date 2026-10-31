extends Node2D

# ============================================================================
# HUD 数值显示 & 敌人受击/死亡特效 —— 回归套件
#   对应 docs/design/hud_fx_gap_fix.md 任务 A~F
#
# 用法（**不要加 --headless**，末尾要截图）：
#   godot --path . res://tools/HudFxGap.tscn
#
# 两条纪律（和 V5InGame / SmokeTest 一致）：
#   1) 所有用例都 await。只要有一个用例带 await 它就是协程，
#      调用点不 await 就会和后面的用例交错执行，测出来的数是别人的。
#   2) 断言要能从数据独立反推，不能简单回读被测代码自己的中间变量。
#      能读到"私有字段"的地方（比如 _corpse_left）只在**行为断言做不到**时才用。
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"
const SHOT_PATH := "user://shot_hud_fx.png"

var _fails: Array[String] = []
var _game: GameScene
var _player: Player
var _enemies: EnemyPool
var _weapons: WeaponManager
var _hud: HUD
var _dn: DamageNumbers
var _meta_backup: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	await get_tree().process_frame
	await _boot()
	await _case_hud_numbers()
	await _case_shield()
	await _case_damage_pool()
	await _case_damage_aggregate()
	await _case_hit_flash()
	await _case_mob_dissolve()
	_case_spark_budget()
	await _shot()
	await _report()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		_fails.append(msg)

func _shader_of(m: Material) -> String:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader != null:
			return sm.shader.resource_path.get_file()
	return "<none>"

func _boot() -> void:
	# 局外乘数（商店等级）会直接改 stats，而下面的断言全是"纯局内口径"。
	# 备份 → 清零 → 测完还原，别把玩家的商店进度跑没了。
	_meta_backup = MetaSave.snapshot()
	MetaSave.debug_set(0, {})
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_node("World/Player") as Player
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_hud = _game.get_node("UI/HUD") as HUD
	_dn = _game.get_node("World/DamageNumbers") as DamageNumbers
	# 关掉"刷怪"和"自动开火"：这两个是持续产出（敌人、飘字、特效）的源头，
	# 留着的话每一次计数断言都会被后台的随机事件污染，只能靠运气通过。
	_game.set_process(false)
	_weapons.set_process(false)
	# 清掉开局那 4 只
	_enemies.clear_all()

## 在玩家脚下 300px 外的固定位置放一只不动的小怪（speed=0）。
## 不动的意义：它会一直站在那儿，不会走过来撞玩家、也不会走出判定范围。
func _mob(hp: float, offset := Vector2(300.0, 0.0)) -> Enemy:
	var e: Enemy = _enemies.spawn(_player.global_position + offset, hp, 0.0, 1, "cup", false)
	e.visible = true
	return e

## 推进 n 个完整迭代（物理 + 空闲）。
##
## 为什么不能只 await 一次：`physics_frame` / `process_frame` 都是在**回调之前**发的，
## 醒来的那一刻，本帧的 `_physics_process` / `_process` 还没跑。
## 所以"改了数据 → 等一帧 → 读 Label"会读到上一帧的文本，
## 而且错得很像产品 bug（值明明改了，界面纹丝不动）。
func _tick(n := 3) -> void:
	for _i in n:
		await get_tree().physics_frame
		await get_tree().process_frame

# ---------------------------------------------------------------- B + C：HUD 数字
func _case_hud_numbers() -> void:
	print("\n[B/C] 血条 / 经验条数字")
	var hp_max: float = float(_player.stats["max_hp"])
	var hp0: float = float(_player.stats["hp"])
	var want := "%d / %d" % [int(ceilf(hp0)), int(round(hp_max))]
	_check(_hud.hp_label.text == want,
		"血量数字应为 \"%s\"，实际 \"%s\"" % [want, _hud.hp_label.text])

	# 真打一下再看：只断言"能显示"没意义，要断言它**跟着掉**
	_player.invuln_left = 0.0
	_player.take_damage(17.0)
	await _tick()
	var hp1: float = float(_player.stats["hp"])
	_check(is_equal_approx(hp1, hp0 - 17.0),
		"受击 17 后 hp 应从 %.0f 变成 %.0f，实际 %.0f" % [hp0, hp0 - 17.0, hp1])
	var want1 := "%d / %d" % [int(ceilf(hp1)), int(round(hp_max))]
	_check(_hud.hp_label.text == want1,
		"受击后血量数字应为 \"%s\"，实际 \"%s\"" % [want1, _hud.hp_label.text])

	# 低血变色：阈值 HP_COLOR_WARN 只在**跨越那一帧**写一次，这里验的是它真的被写进去了
	_player.stats["hp"] = hp_max * 0.2
	await _tick()
	_check(_hud.hp_label.get_theme_color("font_color").is_equal_approx(HUD.HP_COLOR_WARN),
		"血量 20%% 时数字应变朱红，实际 %s" % _hud.hp_label.get_theme_color("font_color"))
	_player.stats["hp"] = hp_max
	await _tick()
	_check(_hud.hp_label.get_theme_color("font_color").is_equal_approx(HUD.HP_COLOR_NORMAL),
		"血量回满后数字应变回白色，实际 %s" % _hud.hp_label.get_theme_color("font_color"))

	# 经验数字：xp 是"本等级内"的经验，不是累计
	var before_xp: int = _player.xp
	_player.gain_xp(2)
	await _tick()
	var want_xp := "%d / %d" % [_player.xp, _player.xp_next]
	_check(_hud.xp_label.text == want_xp,
		"经验数字应为 \"%s\"，实际 \"%s\"" % [want_xp, _hud.xp_label.text])
	_check(_player.xp == before_xp + 2,
		"gain_xp(2) 后本等级经验应 +2，实际 %d → %d" % [before_xp, _player.xp])

# ---------------------------------------------------------------- D：护盾
func _case_shield() -> void:
	print("\n[D] 护盾条 / 护盾数字 / 破盾反馈")
	_check(not _hud.shield_bar.visible,
		"没买结界时护盾条必须隐藏（否则是一块空条噪音）")

	_player.stats["shield"] = 60.0
	await _tick(4)
	_check(_hud.shield_bar.visible, "结界生效后护盾条应出现")
	_check(is_equal_approx(_player.shield_hp, 60.0),
		"结界首次进 _update_passives 应把护盾补到 60，实际 %.1f" % _player.shield_hp)
	_check(is_equal_approx(_hud.shield_bar.max_value, 60.0),
		"护盾条 max 应等于 stats[\"shield\"]=60，实际 %.1f" % _hud.shield_bar.max_value)
	_check(_hud.shield_label.text == "60 / 60",
		"护盾数字应为 \"60 / 60\"，实际 \"%s\"" % _hud.shield_label.text)

	# 护盾先吃伤害：血一点都不能掉
	var hp_before: float = float(_player.stats["hp"])
	_player.invuln_left = 0.0
	_player.take_damage(25.0)
	await _tick()
	_check(is_equal_approx(_player.shield_hp, 35.0),
		"受击 25 后护盾应剩 35，实际 %.1f" % _player.shield_hp)
	_check(is_equal_approx(float(_player.stats["hp"]), hp_before),
		"盾没破之前血量不应变化（%.1f → %.1f）" % [hp_before, float(_player.stats["hp"])])
	_check(_hud.shield_label.text == "35 / 60",
		"护盾数字应随受击变化为 \"35 / 60\"，实际 \"%s\"" % _hud.shield_label.text)

	# 破盾：环要"炸开"，而不是跟着 shield_hp 归零一起消失
	_player.invuln_left = 0.0
	_player.take_damage(100.0)
	await _tick()
	_check(is_equal_approx(_player.shield_hp, 0.0),
		"超额伤害应把护盾清到 0，实际 %.1f" % _player.shield_hp)
	_check(_player._shield_break > 0.0, "破盾应触发闪光计时（_shield_break > 0）")
	_check(_player._shield_ring != null and _player._shield_ring.visible,
		"破盾闪光期间光环必须仍然可见（否则看不到\"盾碎了\"）")
	# 0.26s 后收干净，且因为 shield_hp=0 而不应再显示
	await get_tree().create_timer(0.40).timeout
	_check(not _player._shield_ring.visible,
		"破盾闪光结束后光环应隐藏（护盾为 0）")

	# 还原，避免污染后面的截图与用例
	_player.stats["shield"] = 0.0
	_player.shield_hp = 0.0
	_player.stats["hp"] = float(_player.stats["max_hp"])
	await _tick()

# ---------------------------------------------------------------- A：飘字池
func _case_damage_pool() -> void:
	print("\n[A] 伤害飘字池化")
	_check(_dn != null, "Game 场景里应有 World/DamageNumbers 节点")
	_check(_dn.label_count() == DamageNumbers.POOL_SIZE,
		"飘字层应预热 %d 个 Label，实际 %d" % [DamageNumbers.POOL_SIZE, _dn.label_count()])
	var cap: int = _dn.label_count()
	# 连续弹 300 次：池子必须**一个节点都不新建**
	for i in 300:
		_dn.pop(_player.global_position + Vector2(float(i % 40) * 12.0, 0.0), float(i + 1), i % 7 == 0)
	_check(_dn.label_count() == cap,
		"连弹 300 条后 Label 数不应增长（%d → %d）" % [cap, _dn.label_count()])
	_check(_dn.active_count() <= cap,
		"同时存在的飘字数不应超过池容量（%d ≤ %d）" % [_dn.active_count(), cap])
	# 全部飞完之后必须回收到 0，而且节点仍然在（池复用，不是 free）
	await get_tree().create_timer(DamageNumbers.LIFE * 1.4).timeout
	_check(_dn.active_count() == 0,
		"生命周期结束后应全部回收，实际还剩 %d" % _dn.active_count())
	_check(_dn.label_count() == cap,
		"回收不应销毁节点（应留在池里复用），实际 %d" % _dn.label_count())

	var fmt_ok: bool = DamageNumbers._fmt(12.4) == "12" and DamageNumbers._fmt(0.4) == "0.4"
	_check(fmt_ok, "数字格式：12.4 → \"12\"、0.4 → \"0.4\"（小数只在 <1 时保留）")

# ---------------------------------------------------------------- A：聚合与强调档
func _case_damage_aggregate() -> void:
	print("\n[A] 伤害聚合（0.22s 窗口）与击杀强调档")
	var e: Enemy = _mob(9999.0)
	var got: Array = []
	e.damage_dealt.connect(func(p: Vector2, a: float, big: bool) -> void: got.append([a, big]))
	e.take_damage(10.0)
	_check(got.size() == 1 and absf(float(got[0][0]) - 10.0) < 0.01,
		"第一下应立即冒字（不等窗口），实际 %d 条 / %.1f" % [got.size(), float(got[0][0]) if got.size() > 0 else -1.0])
	e.take_damage(10.0)
	e.take_damage(10.0)
	_check(got.size() == 1,
		"同一窗口内的后续命中应被合并，不应立刻再冒（实际 %d 条）" % got.size())
	await get_tree().create_timer(Enemy.DMG_POP_INTERVAL + 0.10).timeout
	_check(got.size() == 2 and absf(float(got[1][0]) - 20.0) < 0.01,
		"窗口收口时应把累计的 20 点一次冒出去，实际 %d 条 / %.1f" % [
			got.size(), float(got[1][0]) if got.size() > 1 else -1.0])
	e.take_damage(999999.0)

	# 击杀那一击必须是强调档：这是玩家唯一真正需要"被强调"的读数
	var e2: Enemy = _mob(12.0, Vector2(300.0, 80.0))
	var big_flags: Array = []
	e2.damage_dealt.connect(func(p: Vector2, a: float, big: bool) -> void: big_flags.append(big))
	e2.take_damage(999999.0)
	_check(big_flags.size() == 1 and bool(big_flags[0]) == true,
		"击杀那一击应只发一条且 big=true，实际 %s" % str(big_flags))

# ---------------------------------------------------------------- E：受击染色
func _case_hit_flash() -> void:
	print("\n[E] 小怪受击染色（不挂材质）")
	var e: Enemy = _mob(9999.0, Vector2(-300.0, 0.0))
	var before: Material = e.art.material
	e.take_damage(1.0)
	_check(e.art.material == before,
		"小怪受击不应换材质（会掉出合批），实际 %s" % _shader_of(e.art.material))
	_check(e.art.modulate.is_equal_approx(Enemy.HIT_COLOR),
		"小怪受击应走 modulate 染色，实际 %s" % e.art.modulate)

	# 时长用**手动推帧**验，不用墙钟：sleep 出来的时序每次都不一样，
	# 而这里要断言的恰恰是"0.09 太重、0.12 才够"这种几十毫秒的差别。
	e._process(0.09)
	_check(e.art.modulate.is_equal_approx(Enemy.HIT_COLOR),
		"受击 0.09s 后应仍在染色（旧的 0.09 配置到这里就已经复位了）")
	e._process(0.04)
	_check(e.art.modulate.is_equal_approx(Color.WHITE),
		"受击 0.13s 后应恢复原色，实际 %s" % e.art.modulate)
	e.take_damage(999999.0)

# ---------------------------------------------------------------- F：小怪溶解
func _case_mob_dissolve() -> void:
	print("\n[F] 小怪死亡化墨（复用 in-house dissolve）")
	var e: Enemy = _mob(10.0, Vector2(0.0, 300.0))
	e.take_damage(999999.0)
	_check(_shader_of(e.art.material).ends_with("dissolve_spawn.gdshader"),
		"小怪死亡应挂 dissolve_spawn，实际 %s" % _shader_of(e.art.material))
	_check(e.modulate.a > 0.99,
		"不能再靠 modulate.a 硬淡出（那会让溶解看不见），实际 a=%.2f" % e.modulate.a)
	# 尸体留存必须 ≥ 溶解时长：0.20 会在溶到 2/3 时被回收，表现是"闪一下就没了"
	_check(e.corpse_expired(0.20) == false,
		"小怪尸体在 0.20s 时不应被回收（溶解需 %.2fs）" % Enemy.MOB_DISSOLVE)
	_check(e.corpse_expired(0.20) == true,
		"小怪尸体在 0.40s 时应已到回收时间")

	# 池复用纪律：这具带溶解材质的尸体被回收后，冒出来的新怪必须是干净的。
	# 漏了 ShaderFX.clear 的话新怪会带着 progress=0 出场 —— 也就是"看不见的怪打你"。
	_enemies.deactivate(e)
	var fresh: Enemy = _mob(20.0, Vector2(0.0, -300.0))
	_check(not _shader_of(fresh.art.material).ends_with("dissolve_spawn.gdshader"),
		"复用后的新怪不应带着溶解材质，实际 %s" % _shader_of(fresh.art.material))
	_check(fresh.art.modulate.is_equal_approx(Color.WHITE) and fresh.modulate.a > 0.99,
		"复用后的新怪不应带半透明残留，实际 art=%s / node.a=%.2f" % [fresh.art.modulate, fresh.modulate.a])
	fresh.take_damage(999999.0)

# ---------------------------------------------------------------- 火花预算
func _case_spark_budget() -> void:
	print("\n[E] 命中火花令牌桶（不抽干 FX 池）")
	# 前面的用例已经通过 signal 链花掉了一些令牌，这里先补满，
	# 否则断言只能写成 "<="（弱），证明不了上限到底是几颗。
	_game._spark_tokens = float(GameScene.SPARK_BURST)
	# 位置丢到屏幕外：这一条会真的冒飘字，落在玩家脚下会污染后面的截图
	var far: Vector2 = _player.global_position + Vector2(4000.0, 4000.0)
	var before: int = _weapons.fx_active_count()
	for _i in 40:
		_game._on_enemy_damage(far, 1.0, false)
	var gained: int = _weapons.fx_active_count() - before
	_check(gained == int(GameScene.SPARK_BURST),
		"连续 40 次普通命中应正好开 %d 颗火花，实际 %d 颗" % [int(GameScene.SPARK_BURST), gained])
	# 令牌花光之后必须彻底停手（Game._process 关着，不会回充）
	for _i in 40:
		_game._on_enemy_damage(far, 1.0, false)
	_check(_weapons.fx_active_count() - before == int(GameScene.SPARK_BURST),
		"令牌耗尽后不应继续开火花，实际累计 %d 颗" % (_weapons.fx_active_count() - before))

	# 击杀不吃预算：那是最该被看见的一次反馈，被节流掉就等于没有
	var before2: int = _weapons.fx_active_count()
	for _i in 5:
		_game._on_enemy_damage(far, 1.0, true)
	_check(_weapons.fx_active_count() - before2 == 5,
		"5 次击杀应各开一颗火花（不吃预算），实际 %d 颗" % (_weapons.fx_active_count() - before2))

# ---------------------------------------------------------------- 截图
func _shot() -> void:
	if DisplayServer.get_name() == "headless":
		print("\n[截图] headless 下跳过（dummy driver 不会触发 frame_post_draw）")
		return
	# 摆一个"正在打"的画面：满血 HUD + 护盾 + 一串飘字 + 火花
	_player.stats["hp"] = float(_player.stats["max_hp"]) * 0.62
	_player.stats["shield"] = 60.0
	_player._shield_cd = 99.0
	_player.shield_hp = 42.0
	_game.set_process(true)
	_weapons.set_process(true)
	var base: Vector2 = _player.global_position
	for i in 9:
		var ang: float = TAU * float(i) / 9.0
		var e: Enemy = _enemies.spawn(base + Vector2.from_angle(ang) * 190.0, 99999.0, 0.0, 1, "cup", false)
		e.visible = true
		e.take_damage(float(11 + i * 4))
	_game.set_process(false)
	_weapons.set_process(false)
	await get_tree().create_timer(0.14).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(SHOT_PATH)
	print("\n[截图] 已保存 ", ProjectSettings.globalize_path(SHOT_PATH))

func _report() -> void:
	MetaSave.debug_set(int(_meta_backup.get("coins", 0)),
		_meta_backup.get("levels", {}) as Dictionary)
	print("\n========== HUD 数值 & 敌人特效 验收 ==========")
	if _fails.is_empty():
		print("全部通过 OK")
	else:
		for f in _fails:
			print("失败: ", f)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _fails.is_empty() else 1)
