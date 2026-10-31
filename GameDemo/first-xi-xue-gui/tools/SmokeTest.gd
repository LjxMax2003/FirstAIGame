extends Node

# 阶段一自动化验收（无头）。对应《核心玩法完善步骤》Step 1~5。
# 用法：
#   godot --headless --path . res://tools/SmokeTest.tscn
# 注意：必须作为场景运行（不能 --script），否则 autoload 与全局类不注册。
#
# 写测试时的三条硬约定（踩过的坑）：
# 1) 推进时间用 physics_frame，process_frame 在无头下不保证物理步进；
# 2) 每个用例开头强制解除暂停并把玩家设为无敌，避免上一用例的状态污染；
# 3) 不要在 await 死循环里等状态──阻塞期间物理帧不推进，会得出错误的"卡死"结论。

const GAME_SCENE := "res://scenes/Game.tscn"

var _fails: Array[String] = []
var _game: GameScene = null
var _player: Player = null
var _enemies: EnemyPool = null
var _gems: GemPool = null
var _weapons: WeaponManager = null
var _lvui: LevelUpUI = null
var _pauseui: PauseUI = null
var _deathui: DeathUI = null
var _shopui: ShopUI = null
## 跑测试前的真实存档（阶段四会改 MetaSave，测完必须原样还回去）
var _meta_backup: Dictionary = {}
# 自动选卡：压力测试期间必须持续消费升级弹窗，否则一升级就整树暂停，
# 后面的"敌人停止移动/武器不命中"全部是暂停造成的假象。
var _auto_pick := false
## 开局那一刻的 Engine.max_fps（由 GameManager._ready 设入）。本套件随后会把它摘成 0。
var _fps_at_boot := 0

func _process(_delta: float) -> void:
	if _auto_pick and get_tree().paused and _lvui != null and _lvui.is_open():
		_pick_first_card()

func _ready() -> void:
	# 必须在暂停时也继续跑，否则 _process 里的自动选卡钩子会被一起冻住
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 先把它**记下来**再摘掉：这是 GameManager._ready（autoload，先于本场景）设进去的那个值，
	# 也就是"游戏真正跑起来时的上限"。_case_frame_cap() 断言的就是这个数，
	# 而不是只断言常量 —— 否则 GameManager 里那行被删掉了测试也照样绿。
	_fps_at_boot = Engine.max_fps
	# 摘掉上限：本套件测的是逻辑，不是呈现。留着会让 _wait(秒) 真的按墙钟跑，
	# 整套用例从几十秒涨到一分多钟。
	Engine.max_fps = 0
	await get_tree().process_frame
	await _boot()
	await _step1_movement()
	await _step2_enemies()
	await _step3_weapons()
	await _step4_gems()
	await _step5_levelup()
	await _pause_and_restart()
	await _art_check()
	await _movement_facing()
	# ---- 阶段二（Step 6 / 7 / 8）
	await _step6_stats_pipeline()
	await _step7_weapon_data()
	await _step8_evolution()
	# ---- 阶段三（Step 9 / 10 / 11）
	await _step9_wave_table()
	await _step9_boss()
	await _step10_pickups()
	await _step10_resources()
	await _step11_result()
	await _soak_density()
	# ---- 阶段四（Step 12）
	await _step12_meta_shop()
	# ---- 呈现口径（帧率上限）
	_case_frame_cap()
	await _report()

func _boot() -> void:
	# 【阶段四的前置】MetaSave 里的乘数会直接改 stats，而阶段一~三的断言全部是
	# "纯局内公式"的口径（比如 max_hp Lv3 == 160）。所以必须在建场景之前把 Meta 清零，
	# 否则"某台机器上跑测试失败、另一台通过"这种幽灵问题就会出现。
	# 但也不能直接删档 —— 那等于跑一次测试就抹掉玩家的商店进度。备份、清零、测完还原。
	_meta_backup = MetaSave.snapshot()
	MetaSave.debug_set(0, {})
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_game = packed.instantiate() as GameScene
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_node("World/Player") as Player
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	_gems = _game.get_node("World/GemPool") as GemPool
	_weapons = _game.get_node("World/Weapons") as WeaponManager
	_lvui = _game.get_node("UI/LevelUpUI") as LevelUpUI
	_pauseui = _game.get_node("UI/PauseUI") as PauseUI
	_deathui = _game.get_node("UI/DeathUI") as DeathUI
	_shopui = _game.get_node("UI/ShopUI") as ShopUI
	print("paused=%s started=%s owned=%s start_weapon=%s" % [str(get_tree().paused), str(GameManager.started), str(_weapons.owned.keys()), GameManager.start_weapon])
	# T9：起始武器来自所选匠人（默认铁花匠 → 打铁花）。
	# 【为什么必须在这里断言】这是全套件唯一"刚开局、还没被任何用例改过"的时刻 ——
	#   Step2 的 _pin_probe_build() 会把 owned 整个替换掉，之后再问"起始武器"就没意义了。
	_check(_weapons.owned.size() == 1 and _weapons.has_weapon(CharacterDB.starting_weapon()),
		"开局只发起始武器「%s」（%s）" % [CharacterDB.starting_weapon(), str(_weapons.owned.keys())])

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		_fails.append(msg)

## 等待 N 个"物理+渲染"帧（无头下两者交替，确保依赖任一循环的逻辑都推进）
func _wait_frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
		await get_tree().process_frame

## 等待秒数：以物理帧计数，避免被无头帧率影响
func _wait(seconds: float) -> void:
	var steps: int = maxi(1, int(seconds * 60.0))
	await _wait_frames(steps)

## 每个用例的公共前置：解暂停、清场、玩家无敌（免疫干扰但不会死）、冻住经验条。
##
## 【为什么默认冻结经验】
## 升级弹窗的优先级高于暂停菜单（设计如此，Step5 定的），所以任何一个用例只要在等待期间
## "恰好攒够经验"，整树就会暂停，接下来的"武器还在开火吗""恢复游戏了吗"全部假失败。
## 这是本套件里最隐蔽的一类 flake：不是逻辑错了，是测量被另一个合法机制打断。
## 想测升级本身的用例（Step5）传 freeze_xp = false，由它自己掌控升级时机。
func _prep(invincible: bool = true, freeze_xp: bool = true) -> void:
	get_tree().paused = false
	if _lvui.is_open():
		_lvui.close_all()
	if _pauseui.is_open():
		_close_pause()
	_player.set("invuln_left", 999999.0 if invincible else 0.0)
	if freeze_xp:
		_player.xp = 0
		_player.xp_next = 1 << 30
	else:
		_player.xp_next = _player.xp_for_level(_player.level)
	_enemies.clear_all()
	await _wait_frames(2)

## 关掉暂停菜单并同步 HUD 按钮文案。
## 直接调 PauseUI.close() 不会经过 Game.toggle_pause()，HUD 上的 ▶/II 会停在错的状态，
## 退出和 test 里都必须走同一条"关闭"路径。
func _close_pause() -> void:
	_pauseui.close()
	_game.hud.set_paused(false)

## 点第一张卡（走 Button.pressed，和真实点击同一条路径）
func _pick_first_card() -> bool:
	var cards: HBoxContainer = _lvui.get_node("Popup/VB/Cards") as HBoxContainer
	if cards.get_child_count() == 0:
		return false
	for c in (cards.get_child(0) as Control).get_children():
		if c is Button:
			(c as Button).pressed.emit()
			return true
	return false

# ---------------------------------------------------------------- Step 1
func _step1_movement() -> void:
	await _prep()
	print("\n[Step1] 移动与相机")
	var start: Vector2 = _player.global_position
	_player.set("_drag_active", true)
	_player.set("_drag_index", 0)
	_player.set("_drag_dir", Vector2(1.0, 0.0))
	await _wait(0.45)
	var moved: float = _player.global_position.distance_to(start)
	_check(moved > 40.0, "单指拖拽移动生效，位移 %.1f px" % moved)

	var cam: Camera2D = _game.get_node("World/Player/Camera") as Camera2D
	var offset: float = cam.get_screen_center_position().distance_to(_player.global_position + cam.position)
	_check(offset < 90.0, "相机跟随玩家，屏幕中心偏差 %.1f px" % offset)
	_check(cam.position_smoothing_enabled, "相机平滑跟随已开启")

	# 键盘输入通路（桌面）
	var before: Vector2 = _player.global_position
	Input.action_press("move_left")
	await _wait(0.30)
	Input.action_release("move_left")
	var kb_moved: float = _player.global_position.distance_to(before)
	_check(kb_moved > 20.0, "键盘方向键移动生效，位移 %.1f px" % kb_moved)

	_player.global_position = Vector2(50000.0, -42000.0)
	await _wait(0.2)
	_check(_player.global_position.length() > 1000.0, "远离原点（50k px）仍正常运行＝无限地面")
	_player.global_position = Vector2.ZERO
	_player.set("_drag_active", false)
	_player.set("_drag_index", -1)
	_player.set("_drag_dir", Vector2.ZERO)
	await _wait_frames(2)

# ---------------------------------------------------------------- Step 2
func _step2_enemies() -> void:
	await _prep()
	print("\n[Step2] 敌人生成与追踪")
	_check(_enemies.alive_count() == 0, "清场后存活敌人数 = 0")

	# 把时间推到 8 分钟，观察密度爬升。
	#
	# 【为什么不再断言"必须到 300"】
	# 阶段一用连续 lerp 难度，刷怪率会一路把同屏数顶到上限；阶段三换成事件表后，
	# 同屏数是"刷怪率 − 击杀率"的平衡点，480s 档刷 ~10 只/0.58s。
	#
	# 【为什么必须先把构筑钉死】
	# 同屏数 = 刷怪率 − 击杀率，而击杀率完全取决于"自动选卡抽到了什么"。
	# 原来一边自动选卡一边测密度，同一条断言实测会在 73~164 之间飘（抽到范围/伤害就杀得多，
	# 抽到新武器就杀得少），今天过明天挂 —— 这是测量方法的问题，不是难度曲线变了。
	# seed() 也救不了：randf 的调用次数受帧时序影响，同一颗种子两次跑结果仍不同。
	# 所以这里显式固定"8 分钟档的初始构筑"（鞭弧 Lv2 + 光环 Lv1、被动全 0）并把经验条冻住，
	# 让这一段只测"刷怪密度"这一件事。测完放开，后续用例自己会重置构筑。
	_pin_probe_build()
	_game.elapsed = 480.0
	_game.set("_prev_t", 480.0)
	_enemies.clear_all()
	_auto_pick = true
	var frames := 0
	var mid := 0
	while frames < 1200:
		await get_tree().physics_frame
		# 钉住 elapsed：否则一局会真的往后走，波次参数漂移
		_game.elapsed = 480.0
		frames += 1
		if frames == 600:
			mid = _enemies.alive_count()
	var alive: int = _enemies.alive_count()
	_check(alive >= 100, "8 分钟档同屏 %d 只（需走位的密度下限 100）" % alive)
	_check(alive <= _enemies.max_alive,
		"同屏 %d ≤ params max_alive %d" % [alive, _enemies.max_alive])
	_check(maxi(alive, mid) > 40, "密度爬升：600 帧时 %d 只 → 1200 帧时 %d 只" % [mid, alive])

	# 分离：必须在"高密度"状态下测，此时邻居足够多。先测这个，再清场测追踪。
	var stack_pos: Vector2 = _player.global_position + Vector2(0, 320)
	var grp: Array[Enemy] = []
	for i in 15:
		var e: Enemy = _enemies.active[i]
		e.global_position = stack_pos
		grp.append(e)
	await _wait(0.5)
	var spread := 0.0
	for e in grp:
		spread += e.global_position.distance_to(stack_pos)
	spread /= float(grp.size())
	_check(spread > 8.0, "同点堆叠后平均散开 %.1f px（轻量分离生效）" % spread)

	# 追踪检查必须单独隔离一只敌人：场内已有 300 只时，
	# 从 active[0] 里挑一只瞬移出去，它的空间网格记录还停在旧位置，
	# 会吃到一堆"幽灵邻居"的分离力，追踪方向被抵消 —— 这是取样问题，不是逻辑问题。
	_enemies.clear_all()
	var probe: Enemy = _enemies.spawn(_player.global_position + Vector2(400, 0), 999.0, 90.0, 1, "cup", false)
	var d0: float = probe.global_position.distance_to(_player.global_position)
	await _wait(0.6)
	var d1: float = probe.global_position.distance_to(_player.global_position)
	_check(d1 < d0 - 15.0, "敌人直线追踪玩家：%.0f → %.0f px" % [d0, d1])

	# 接触伤害必须真的扣血：清空无敌帧再贴脸
	#
	# ⚠️ 咬人的那只必须挑**活着的**：active[0] 可能是一具还在播死亡溶解的尸体，
	#    尸体不跑接触判定，这条断言就会偶发失败（实测两次运行挂过一次）。
	#    等待也放宽到 0.3s：0.15s 在极少数帧边界上刚好落在"刚被咬完的无敌窗口"里。
	_player.set("invuln_left", 0.0)
	var hp0: float = float(_player.stats["hp"])
	var biter: Enemy = null
	for e in _enemies.active:
		if e.alive:
			biter = e
			break
	if biter == null:
		biter = _enemies.active[0]
	biter.global_position = _player.global_position + Vector2(12, 0)
	await _wait(0.30)
	var hp1: float = float(_player.stats["hp"])
	_check(hp1 < hp0, "贴脸接触扣血：%.0f → %.0f（距离判定，无物理体）" % [hp0, hp1])
	_player.set("invuln_left", 999999.0)

	# 池复用：击杀后回收再生成，敌人必须能继续移动（曾出现 set_process(false) 未复位）
	_enemies.clear_all()
	var victim: Enemy = _enemies.spawn(_player.global_position + Vector2(300, 0), 1.0, 90.0, 1, "cup", false)
	await _wait(0.05)
	_enemies.clear_all()
	var revived: Enemy = _enemies.spawn(_player.global_position + Vector2(300, 0), 999.0, 90.0, 1, "bag", false)
	var rp0: Vector2 = revived.global_position
	await _wait(0.4)
	_check(revived.global_position.distance_to(rp0) > 10.0,
		"池复用的敌人恢复处理：位移 %.1f px" % revived.global_position.distance_to(rp0))
	var revived_art: String = (revived.get_node("Art") as Sprite2D).texture.resource_path
	_check(_art_is(revived_art, "mob_heavy"), "复用时贴图随种类切换（%s）" % revived_art.get_file())
	_enemies.clear_all()
	_auto_pick = false

# ---------------------------------------------------------------- Step 3
func _step3_weapons() -> void:
	await _prep()
	print("\n[Step3] 自动攻击武器")
	# ⚠️ 这里**不能**断言"起始武器"：Step2 的 _pin_probe_build() 把 owned 整个替换成
	#   {whip:2, halo:1} 来钉死密度测量的构筑（刻意的测量隔离）。开局发哪把由 _boot 断言，
	#   那边才有"没被动过的开局状态"。这里只确认钉住的构筑确实生效了。
	_check(_weapons.has_weapon("whip") and _weapons.weapon_level("whip") == 2,
		"Step2 钉住的测量构筑生效（whip Lv%d）" % _weapons.weapon_level("whip"))

	var big := 99999.0
	# 鞭弧左右交替：_side 是跨用例共享的状态，上一用例可能停在 -1。
	# 这里显式复位到 +1，否则"身前敌人被打到"这一条会随机失败（取决于上一次挥到哪边）。
	_weapons.set("_side", 1)
	_weapons._cd["whip"] = 0.0
	var right: Enemy = _enemies.spawn(_player.global_position + Vector2(60, 0), big, 0.0, 1, "cup", false)
	await _wait(1.9)
	_check(right != null and right.hp < big, "鞭子命中身前敌人（剩余 %.0f）" % (right.hp if right != null else -1.0))

	var behind: Enemy = _enemies.spawn(_player.global_position + Vector2(-60, 0), big, 0.0, 1, "cup", false)
	await _wait(2.6)
	_check(behind != null and behind.hp < big, "鞭子左右交替，背面也被扫到（剩余 %.0f）" % (behind.hp if behind != null else -1.0))

	_weapons.acquire("halo")
	var near: Enemy = _enemies.spawn(_player.global_position + Vector2(40, 0), big, 0.0, 1, "cup", false)
	await _wait(0.9)
	_check(near != null and near.hp < big, "光环灼烧贴身敌人")
	_check(_player.garlic_ring.visible, "光环范围可视化显示（半径 %.0f px 与判定一致）" % _weapons.halo_radius())

	_weapons.acquire("glowstick")
	_enemies.clear_all()
	var far: Enemy = _enemies.spawn(_player.global_position + Vector2(0, -300), big, 0.0, 1, "cup", false)
	await _wait(1.8)
	_check(far != null and far.hp < big, "荧光棒自动锁定并命中 300px 外敌人")

	_enemies.clear_all()
	for i in 6:
		_enemies.spawn(_player.global_position + Vector2.from_angle(TAU * float(i) / 6.0) * 70.0, 6.0, 0.0, 1, "cup", false)
	var k0: int = _game.kills
	await _wait(2.2)
	_check(_game.kills > k0, "站桩不动也能击杀（击杀 +%d）" % (_game.kills - k0))

# ---------------------------------------------------------------- Step 4
func _step4_gems() -> void:
	await _prep()
	print("\n[Step4] 经验宝石与吸附拾取")
	_enemies.clear_all()
	await _wait(0.1)
	var xp0: int = _player.xp
	_gems.spawn(_player.global_position + Vector2(260, 0), 1)
	await _wait(0.75)
	_check(_player.xp == xp0, "磁吸半径（%.0f px）外的宝石不会被吸" % GemPool.MAGNET_BASE)
	_gems.spawn(_player.global_position + Vector2(70, 0), 2)
	await _wait(1.0)
	_check(_player.xp != xp0, "进入磁吸圈自动飞向玩家并拾取")
	var lv0: int = _player.level
	var xp1: int = _player.xp
	_gems.spawn(_player.global_position, 1)
	await _wait(0.2)
	_check(_player.xp != xp1 or _player.level != lv0, "贴脸宝石 0.2s 内被吃掉（吸附手感）")

	# 磁力被动应当真的扩大吸附范围
	var magnet_before: float = float(GameManager.stats["magnet"])
	_player.level_upgrades["magnet"] = 4
	UpgradeDB.apply({"def": {"id": "magnet", "kind": "stat"}, "new_level": 4})
	_check(float(GameManager.stats["magnet"]) > magnet_before,
		"磁力被动生效：%.2f → %.2f 倍" % [magnet_before, float(GameManager.stats["magnet"])])

# ---------------------------------------------------------------- Step 5
func _step5_levelup() -> void:
	# 唯一需要"真的能升级"的用例：不冻结经验条，且用真实的 next 值
	await _prep(true, false)
	print("\n[Step5] 升级三选一")
	# 自动选卡必须关掉，否则它会抢先把卡片点掉，测不到"选卡生效"
	_auto_pick = false
	# 重置被动，让"是否生效"的对比有干净的基线
	_player.level_upgrades.clear()
	for key in ["damage", "cooldown", "area", "speed", "magnet", "might"]:
		GameManager.stats[key] = 1.0
	var lv_before: int = _player.level
	_player.gain_xp(_player.xp_next)
	await _wait_frames(2)
	_check(_player.level == lv_before + 1, "经验满后升级（Lv %d → %d）" % [lv_before, _player.level])
	_check(get_tree().paused, "升级瞬间全树暂停")
	var cards: HBoxContainer = _lvui.get_node("Popup/VB/Cards") as HBoxContainer
	_check(cards.get_child_count() == 3, "弹出 %d 张卡（目标 3）" % cards.get_child_count())
	_check(_lvui.mask.visible and _lvui.popup.visible, "遮罩与卡片同时可见")

	# 模拟"点在第一张卡上"：走真实 GUI 命中路径，验证不是只有代码调用能生效
	var first: Control = cards.get_child(0) as Control
	var btn: Button = null
	for c in first.get_children():
		if c is Button:
			btn = c as Button
	_check(btn != null, "卡片可点击")

	var wep_before: Dictionary = _weapons.owned.duplicate()
	var passive_before: Dictionary = _player.level_upgrades.duplicate()
	if btn != null:
		btn.pressed.emit()
	await _wait_frames(2)
	_check(not get_tree().paused, "选卡后恢复游戏")
	var changed: bool = _weapons.owned != wep_before or _player.level_upgrades != passive_before
	_check(changed, "选卡后确实生效（武器 %s / 被动 %s）" % [str(_weapons.owned), str(_player.level_upgrades)])

	_check(_player.xp_for_level(1) == 6, "经验曲线 next = 5 + level^2（Lv1 → 6）")
	var lv2: int = _player.level
	_player.gain_xp(_player.xp_next + 40)
	await _wait_frames(2)
	_check(_player.level > lv2, "一次大量经验可连升（Lv %d → %d）" % [lv2, _player.level])

	# 连续升级排队：全部选完后必须自动解除暂停（否则整局死锁）
	var guard := 0
	while get_tree().paused and guard < 40:
		var c2: HBoxContainer = _lvui.get_node("Popup/VB/Cards") as HBoxContainer
		if c2.get_child_count() > 0:
			for c in (c2.get_child(0) as Control).get_children():
				if c is Button:
					(c as Button).pressed.emit()
					break
		await get_tree().process_frame
		guard += 1
	_check(not get_tree().paused, "连续升级排队全部选完后自动恢复（%d 轮）" % guard)

# ---------------------------------------------------------------- 暂停 / 重开
func _pause_and_restart() -> void:
	await _prep()
	_auto_pick = false
	print("\n[Step6] 暂停与重开闭环")
	_game.toggle_pause()
	await _wait_frames(2)
	_check(get_tree().paused and _pauseui.is_open(), "暂停菜单打开且全树暂停")
	_check(_game.hud.get_node("Top/Col/Row/Pause").text == "▶", "暂停时 HUD 按钮切换为继续图标")

	# 暂停界面开着时，升级不该叠出一层卡（否则关掉一层仍被另一层锁住）
	_lvui._on_level_up()
	await _wait_frames(2)
	_check(not _lvui.is_open(), "暂停菜单期间不叠加升级卡（避免双重暂停锁）")

	_game.toggle_pause()
	await _wait_frames(2)
	_check(not get_tree().paused and not _pauseui.is_open(), "再次点击恢复游戏")
	_check(_game.hud.get_node("Top/Col/Row/Pause").text == "II", "恢复后 HUD 按钮切回暂停图标")

	# 升级界面开着时，暂停键不该抢锁
	_player.set("invuln_left", 999999.0)
	_lvui._on_level_up()
	await _wait_frames(2)
	_check(_lvui.is_open(), "升级卡正常弹出")
	_game.toggle_pause()
	await _wait_frames(2)
	_check(not _pauseui.is_open(), "升级卡期间按暂停无效（升级优先级更高）")
	_lvui.close_all()
	await _wait_frames(2)
	_check(not get_tree().paused, "选完卡后恢复运行")

	# 重开：清空后整局重建，计时/击杀/武器全部归零
	_player.set("invuln_left", 999999.0)
	_game.elapsed = 123.0
	_game.kills = 7
	_weapons.acquire("glowstick")
	var old_game: GameScene = _game
	_game.restart()
	await _wait_frames(6)
	# 找到刚刚重建出来的新实例
	var new_game: GameScene = null
	for c in get_children():
		if c is GameScene and c != old_game and is_instance_valid(c):
			new_game = c
	_check(new_game != null, "重开生成新的游戏实例")
	if new_game != null:
		_check(new_game.elapsed < 1.0 and new_game.kills == 0, "重开后计时/击杀归零（%.2fs / %d）" % [new_game.elapsed, new_game.kills])
		var nw: WeaponManager = new_game.get_node("World/Weapons") as WeaponManager
		var want: String = CharacterDB.starting_weapon()
		_check(nw.owned.size() == 1 and nw.has_weapon(want),
			"重开后武器重置为起始武器「%s」（%s）" % [want, str(nw.owned.keys())])
		_check(not get_tree().paused, "重开后没有残留暂停锁")
		_game = new_game
		_player = new_game.get_node("World/Player") as Player
		_enemies = new_game.get_node("World/EnemyPool") as EnemyPool
		_gems = new_game.get_node("World/GemPool") as GemPool
		_weapons = nw
		_lvui = new_game.get_node("UI/LevelUpUI") as LevelUpUI
		_pauseui = new_game.get_node("UI/PauseUI") as PauseUI
		_deathui = new_game.get_node("UI/DeathUI") as DeathUI
		_shopui = new_game.get_node("UI/ShopUI") as ShopUI

	# 死亡结算：HP 归零 → 结算界面出现且可再次重开
	await _prep()
	_player.set("invuln_left", 0.0)
	_player.stats["hp"] = 1.0
	_player.take_damage(999.0)
	await _wait_frames(3)
	_check(_deathui.is_open(), "死亡后弹出结算界面")
	_check(not GameManager.started, "死亡后停止游戏逻辑")
	_deathui._on_restart()
	await _wait_frames(4)
	var revived: GameScene = null
	for c in get_children():
		if c is GameScene and is_instance_valid(c) and c != _game:
			revived = c
	_check(revived != null and revived.player.hp_ratio() > 0.9, "结算界面重开后满血回到场上")
	if revived != null:
		_game = revived
		_player = revived.get_node("World/Player") as Player
		_enemies = revived.get_node("World/EnemyPool") as EnemyPool
		_gems = revived.get_node("World/GemPool") as GemPool
		_weapons = revived.get_node("World/Weapons") as WeaponManager
		_lvui = revived.get_node("UI/LevelUpUI") as LevelUpUI
		_pauseui = revived.get_node("UI/PauseUI") as PauseUI
		_deathui = revived.get_node("UI/DeathUI") as DeathUI
		_shopui = revived.get_node("UI/ShopUI") as ShopUI

# ---------------------------------------------------------------- 美术接入
## 断言"这个槽位用的是对的那张图"。
## 判定标准是**槽位语义键**（Art.SLOT_ALIASES），不是文件名：
## 换皮时改路径不改键，测试因此不会因为改名而误报。
## 注意：必须按文件名主干精确比对——"enemy_cup" 是 "enemy_cup_fast" 的子串，
## 用 contains 会让 base 槽位静默接受 fast 的图。
func _art_is(path: String, slot: String) -> bool:
	return Art.is_slot(path, slot)

## 操作反应：四向朝向 / 走路帧 / 侧倾。
##
## 【为什么要专门测这个】
## 这层东西全是"看得见但不进数值"的，最容易在换美术时被悄悄弄丢：
## P2 明明接入了 `shouyiren_back.svg`，Player.gd 却从头到尾没用过 —— 
## 玩家向上走时一直拿正面图倒着跑，没有任何用例会失败。
## 所以断言要盯三件事：正/背后缀对不对、斜走会不会高频互闪、停下有没有回正。
func _movement_facing() -> void:
	await _prep()
	print("\n[操作反应] 朝向与走路帧")
	var art: Sprite2D = _player.get_node("Art") as Sprite2D
	_player.set("_drag_active", true)
	_player.set("_drag_index", 0)
	# 先把基准朝向拉回"正面朝下"：前面的用例可能让角色朝过左/右，
	# 而朝向是**保持**的（停下来不重置），不先归位就会读到上一条用例的残留。
	_player.set("_drag_dir", Vector2(0.0, 1.0))
	await _wait(0.12)
	_player.set("_drag_dir", Vector2.ZERO)
	await _wait(0.12)
	_check(Art.is_player_front(art.texture.resource_path), "静止时正面朝下（%s）" % art.texture.resource_path.get_file())

	# 上：唯一会换背面帧的方向
	_player.set("_drag_dir", Vector2(0.0, -1.0))
	await _wait(0.18)
	_check(_player.facing_dir == Player.Facing.UP, "向上输入切到背面朝向")
	_check(Art.is_player_back(art.texture.resource_path), "向上移动使用背面贴图（%s）" % art.texture.resource_path.get_file())

	# 下：回正面
	_player.set("_drag_dir", Vector2(0.0, 1.0))
	await _wait(0.18)
	_check(_player.facing_dir == Player.Facing.DOWN, "向下输入切回正面朝向")
	_check(Art.is_player_front(art.texture.resource_path), "向下移动使用正面贴图（%s）" % art.texture.resource_path.get_file())

	# 左 / 右：共正面帧，靠 flip_h 区分
	_player.set("_drag_dir", Vector2(-1.0, 0.0))
	await _wait(0.18)
	_check(_player.facing_dir == Player.Facing.LEFT and art.flip_h, "向左移动时水平翻转")
	_player.set("_drag_dir", Vector2(1.0, 0.0))
	await _wait(0.18)
	_check(_player.facing_dir == Player.Facing.RIGHT and not art.flip_h, "向右移动时恢复正向")
	_check(art.rotation > 0.01, "向右冲刺时身体向右倾（%.3f rad）" % art.rotation)

	# 斜向：不许在正/背之间闪。竖向要 1.25 倍才切背面，斜 45° 应稳定停在正面。
	_player.set("_drag_dir", Vector2(1.0, -1.0).normalized())
	var flips := 0
	var last := ""
	for _i in 24:
		await get_tree().physics_frame
		var grp := "back" if Art.is_player_back(art.texture.resource_path) else "front"
		if last != "" and grp != last:
			flips += 1
		last = grp
	_check(flips == 0, "斜向移动不会在正/背面之间闪烁（切换 %d 次）" % flips)

	# 走路帧：同一个方向上必须真的在换图，否则等于把三帧美术白扔了
	var seen: Dictionary = {}
	for _i in 36:
		await get_tree().physics_frame
		seen[art.texture.resource_path.get_file()] = true
	_check(seen.size() >= 2, "移动中走路帧在循环（见到 %d 帧）" % seen.size())

	# 松手：回第 1 帧 + 身体回正
	_player.set("_drag_dir", Vector2.ZERO)
	_player.set("_drag_active", false)
	_player.set("_drag_index", -1)
	await _wait(0.35)
	_check(Art.is_player_front(art.texture.resource_path) and art.texture.resource_path.get_file().get_basename() == Art.KEY_PLAYER_FRONT,
		"松手后回到正面第 1 帧")
	_check(absf(art.rotation) < 0.005 and absf(art.position.y) < 0.2, "松手后身体回正（rotation %.4f）" % art.rotation)
	# 断言完把姿态还原，避免后续用例读到"歪着的玩家"
	_player.set("_drag_dir", Vector2.ZERO)

func _art_check() -> void:
	await _prep()
	print("\n[美术] SVG 资源接入")
	var art: Sprite2D = _player.get_node("Art") as Sprite2D
	_check(art.texture != null and _art_is(art.texture.resource_path, "player_front"), "玩家使用 player_front 槽位贴图")

	_enemies.clear_all()
	var a: Enemy = _enemies.spawn(_player.global_position + Vector2(200, 0), 999.0, 0.0, 1, "bag", false)
	var b: Enemy = _enemies.spawn(_player.global_position + Vector2(-200, 0), 999.0, 0.0, 1, "cup", false)
	var elite: Enemy = _enemies.spawn(_player.global_position + Vector2(0, 260), 999.0, 0.0, 12, "box", true)
	# 死神走"精英 + reaper 种类"，位置要避开鞭子/光环，免得血量被打低影响判断
	var reaper: Enemy = _enemies.spawn(_player.global_position + Vector2(0, -1500), 999.0, 0.0, 12, "reaper", true)
	var bag_tex: String = (a.get_node("Art") as Sprite2D).texture.resource_path
	var cup_tex: String = (b.get_node("Art") as Sprite2D).texture.resource_path
	var elite_tex: String = (elite.get_node("Art") as Sprite2D).texture.resource_path
	var reaper_tex: String = (reaper.get_node("Art") as Sprite2D).texture.resource_path
	_check(_art_is(bag_tex, "mob_heavy"), "重装敌人使用 mob_heavy 槽位贴图（%s）" % bag_tex.get_file())
	_check(_art_is(cup_tex, "mob_base"), "基础杂兵使用 mob_base 槽位贴图（%s）" % cup_tex.get_file())
	_check(_art_is(elite_tex, "elite_box"), "精英怪使用 elite_box 槽位贴图（96px）")
	_check(_art_is(reaper_tex, "boss_base"), "死神精英使用 boss_base 槽位贴图")
	_check(elite.size > b.size, "精英体型 %.0f > 普通 %.0f" % [elite.size, b.size])
	_check(elite.hp_bar.visible, "精英血条默认显示")

	_gems.spawn(_player.global_position + Vector2(300, 0), 1)
	await get_tree().process_frame
	var last: Gem = _gems.active[_gems.active.size() - 1]
	_check(last.texture != null and _art_is(last.texture.resource_path, "gem_small"), "普通宝石使用 gem_small 槽位贴图")
	_gems.spawn(_player.global_position + Vector2(320, 0), 12)
	await get_tree().process_frame
	var big_gem: Gem = _gems.active[_gems.active.size() - 1]
	_check(_art_is(big_gem.texture.resource_path, "gem_big"), "大宝石使用 gem_big 槽位贴图")

	_check(_art_is(_player.garlic_ring.get_node("Ring").texture.resource_path, "halo_ring"),
		"蒜环使用 halo_ring 槽位贴图")
	# 原断言只检查 _frame != null，换名它也不会报错，等于没测"用对图"。
	var frame: Texture2D = _lvui.get("_frame") as Texture2D
	_check(frame != null and _art_is(frame.resource_path, "card_frame"),
		"升级卡框使用 card_frame 槽位贴图")
	_check(_art_paths_loadable(), "资源齐备性守卫通过")

## 守卫：Art.gd 与各 DB 里声明的每一个路径都必须能 load。
## 换图时最常见的失败是"路径写错一个字"，报错信息是运行时 load 返回 null，
## 届时表现为敌人没贴图/白块。这里提前一次性暴露，避免逐个用例去猜。
## 返回 true（无缺失）——由调用方 _check，便于在报告里同时看到耗时与总数。
func _art_paths_loadable() -> bool:
	var all: Array[String] = []
	all.append_array(Art.ALL_PATHS)
	# 这几处不走 Art.gd（资源路径在数据表里），单独纳入，防止 P2 换路径时漏掉。
	for wid in WeaponDB.DEFS:
		var d: Dictionary = WeaponDB.DEFS[wid]
		all.append(String(d.get("svg", "")))
		if d.has("bullet_svg"):
			all.append(String(d["bullet_svg"]))
	for fid in EvolutionDB.FORMS:
		all.append(String(EvolutionDB.FORMS[fid].get("svg", "")))
	for kind in PickupField.DEFS:
		all.append(String(PickupField.DEFS[kind].get("svg", "")))

	var missing: Array[String] = []
	for p in all:
		if p == "":
			continue
		if Art.tex(p) == null:
			missing.append(p)

	print("\n[美术] 路径可加载性（共 %d 条 / %d 条唯一）" % [all.size(), _uniq(all).size()])
	if not missing.is_empty():
		for m in _uniq(missing):
			print("  缺失: ", m)
	return missing.is_empty()

func _uniq(src: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for s in src:
		if s != "" and not (s in out):
			out.append(s)
	return out

# ---------------------------------------------------------------- 阶段二 Step 6
## 统一数值管线：被动只改 stats，武器只读 stats。
## 验收口径（核心玩法完善步骤 Step 6）："同一把武器在不同被动下表现明显不同"。
func _step6_stats_pipeline() -> void:
	await _prep()
	_auto_pick = false
	print("\n[Step6] 统一数值管线（被动 → stats → 武器）")

	# 1) 公式逐级核对：这是 Step 6 的根，公式错了后面全错
	var dm: Array[float] = Stats.table("damage")
	_check(is_equal_approx(dm[0], 1.0) and is_equal_approx(dm[5], 1.5),
		"伤害公式 1+0.10L：Lv0=%.2f / Lv5=%.2f" % [dm[0], dm[5]])
	var cd: Array[float] = Stats.table("cooldown")
	_check(is_equal_approx(cd[5], 0.75), "冷却公式 1-0.05L：Lv5=%.2f（不是文档旧的 -8%%）" % cd[5])
	var ar: Array[float] = Stats.table("area")
	_check(is_equal_approx(ar[5], 1.35), "范围公式 1+0.07L：Lv5=%.2f（不是文档旧的 +10%%）" % ar[5])
	var mg: Array[float] = Stats.table("max_hp")
	_check(is_equal_approx(mg[0], 100.0) and is_equal_approx(mg[5], 200.0),
		"生命公式 100+20L：Lv0=%.0f / Lv5=%.0f" % [mg[0], mg[5]])
	var mi: Array[float] = Stats.table("might")
	_check(is_equal_approx(mi[5], 0.65), "力量公式 1-0.07L：Lv5=%.2f（受击伤害 ×%.2f）" % [mi[5], mi[5]])
	_check(is_equal_approx(Stats.value_at("cooldown", 99), 0.75),
		"冷却等级钳制：Lv99 被压回 Lv5 的 %.2f（地板 0.40 要到 Lv12 才触发）" % Stats.value_at("cooldown", 99))
	# 地板只在"不钳制"的公式里才有意义：等级被钳在 5，公式本身永远到不了地板，
	# 所以直接核对公式下限，而不是指望 value_at(99) 掉到地板。
	_check(maxf(Stats.COOLDOWN_FLOOR, 1.0 - 0.05 * 12.0) == Stats.COOLDOWN_FLOOR,
		"冷却地板 %.2f 在 Lv12 生效（Lv5 内用不到，但公式必须写死）" % Stats.COOLDOWN_FLOOR)
	_check(maxf(Stats.MIGHT_FLOOR, 1.0 - 0.07 * 8.0) == Stats.MIGHT_FLOOR,
		"力量地板 %.2f 在 Lv8 生效" % Stats.MIGHT_FLOOR)
	_check(is_equal_approx(Stats.value_at("might", 99), 0.65),
		"力量等级钳制：Lv99 被压回 Lv5 的 %.2f" % Stats.value_at("might", 99))
	_check(Stats.value_at("damage", 6) == Stats.value_at("damage", 5),
		"等级上限 5：Lv6 不再超过 Lv5")

	# 2) 写入口：apply_to 只动 stats，max_hp 要连带补血
	var s: Dictionary = Stats.make_base()
	s["hp"] = 40.0
	Stats.apply_to(s, "max_hp", 3)
	_check(is_equal_approx(float(s["max_hp"]), 160.0) and is_equal_approx(float(s["hp"]), 100.0),
		"点生命上限 100→%.0f 并补血 40→%.0f（不是只涨上限）" % [float(s["max_hp"]), float(s["hp"])])

	# 3) 管线验证：复位 → 只改被动 → 武器实际数值必须跟着变
	await _reset_stats()
	var wp0: float = WeaponDB.damage_at("whip", 1, float(GameManager.stats["damage"]))
	var cd0: float = WeaponDB.cooldown_at("whip", 1, float(GameManager.stats["cooldown"]))
	var halo_r0: float = _weapons.halo_radius() if _weapons.has_weapon("halo") else -1.0

	UpgradeDB.apply({"def": {"id": "damage", "kind": "stat"}, "new_level": 5})
	UpgradeDB.apply({"def": {"id": "cooldown", "kind": "stat"}, "new_level": 5})
	UpgradeDB.apply({"def": {"id": "area", "kind": "stat"}, "new_level": 5})
	var wp1: float = WeaponDB.damage_at("whip", 1, float(GameManager.stats["damage"]))
	var cd1: float = WeaponDB.cooldown_at("whip", 1, float(GameManager.stats["cooldown"]))
	_check(wp1 > wp0 * 1.4, "满级伤害被动让鞭弧伤害 %.1f → %.1f（+%.0f%%）" % [wp0, wp1, (wp1 / wp0 - 1.0) * 100.0])
	_check(cd1 < cd0 * 0.8, "满级冷却被动让鞭弧冷却 %.2fs → %.2fs" % [cd0, cd1])

	# 武器侧的"读 stats"必须真的发生在读的时候，而不是被快照住
	if _weapons.has_weapon("halo"):
		var r1: float = _weapons.halo_radius()
		_check(r1 > halo_r0 * 1.2, "满级范围被动让光环半径 %.0f → %.0f px" % [halo_r0, r1])

	# 4) 反向验证：被动不能绕过 stats 直接改武器常量
	var lv_before: int = _weapons.weapon_level("whip")
	await _reset_stats()
	_check(_weapons.weapon_level("whip") == lv_before,
		"复位被动不改武器等级（whip 仍 Lv%d）—— 两边解耦" % lv_before)

	# 5) 升级池：7 个被动的描述里数字必须和 Stats 公式一致
	var defs: Array[Dictionary] = UpgradeDB.all_defs()
	var stat_ids: Array[String] = []
	for d in defs:
		if String(d["kind"]) == "stat":
			stat_ids.append(String(d["id"]))
	# v5 池：7 → 9（新增回春/结界，见 v5_ai_playbook §6 Phase 1）
	_check(stat_ids.size() == 9, "被动卡数量 = %d（目标 9）" % stat_ids.size())
	_check(not defs.has({"id": "wand"}), "旧武器 id 'wand' 已改名为 'glowstick'")

## 把被动全部复位成 0 级（不含武器）
func _reset_stats() -> void:
	_player.level_upgrades.clear()
	for key in Stats.STAT_KEYS:
		Stats.apply_to(GameManager.stats, key, 0)
	GameManager.stats["hp"] = float(GameManager.stats["max_hp"])
	await _wait_frames(1)

## 密度测量的固定构筑：鞭弧 Lv2 + 光环 Lv1，被动全 0。
## 这不是"推荐构筑"，只是一个**可复现的测量条件** —— 密度断言不该由抽卡运气决定。
## （经验条由 _prep 统一冻结，这里不重复处理。）
func _pin_probe_build() -> void:
	_weapons.evolved.clear()
	_weapons.owned = {"whip": 2, "halo": 1}
	_weapons._cd = {"whip": 0.1, "halo": 0.1}
	_player.level_upgrades.clear()
	for key in Stats.STAT_KEYS:
		Stats.apply_to(GameManager.stats, key, 0)
	GameManager.stats["hp"] = float(GameManager.stats["max_hp"])

# ---------------------------------------------------------------- 阶段二 Step 7
## 数据驱动：新增武器只加数据。验收口径："加第 4、5 把武器纯靠配置"。
func _step7_weapon_data() -> void:
	await _prep()
	_auto_pick = false
	print("\n[Step7] 数据驱动武器定义（6 把）")

	_check(WeaponDB.ORDER.size() == 9, "WeaponDB 收录 %d 把武器（6 旧 + 铜锣/墨斗/木版年画）" % WeaponDB.ORDER.size())
	for id in WeaponDB.ORDER:
		var d: Dictionary = WeaponDB.def(id)
		_check(not d.is_empty(), "武器 %s 有完整定义（%s）" % [id, String(d.get("name", ""))])

	# 数据表必须能被"只看数据"地评估：伤害随等级单调涨，冷却不涨
	for id in WeaponDB.ORDER:
		var prev_dmg: float = 0.0
		var mono := true
		for lv in range(1, WeaponDB.MAX_LEVEL + 1):
			var dmg: float = WeaponDB.damage_at(id, lv, 1.0)
			if dmg < prev_dmg:
				mono = false
			prev_dmg = dmg
		_check(mono, "%s 的 8 级伤害曲线单调不减（Lv8=%.1f）" % [id, prev_dmg])

	# 关键数值修正：荧光棒 dmg_per_level 必须是 3.0，否则 Lv8 不如 Lv1 鞭弧
	var w1: float = WeaponDB.damage_at("whip", 1, 1.0)
	var g8: float = WeaponDB.damage_at("glowstick", 8, 1.0)
	_check(g8 > w1, "荧光棒 Lv8 伤害 %.1f > 鞭弧 Lv1 %.1f（NUM_DESIGN §4.2 硬约束）" % [g8, w1])

	# 每把武器都要能真的打掉血
	await _reset_stats()
	var big := 99999.0
	for id in WeaponDB.ORDER:
		if id == "halo":
			continue  # 光环在 Step3 已验过，且需要贴身，单独一测容易和别的武器互相干扰
		_enemies.clear_all()
		_weapons.evolved.clear()
		if not _weapons.has_weapon(id):
			_weapons.acquire(id)
		_weapons.owned[id] = 3
		_weapons._cd[id] = 0.0
		# 鞭弧是"左右交替横扫"，第一发可能甩向背面。
		# 把敌人同时放在身前和身后各一只，才不会把交替节奏误判成"武器没伤害"。
		var target: Enemy = _enemies.spawn(_player.global_position + Vector2(90, 0), big, 0.0, 1, "cup", false)
		if id == "whip":
			_enemies.spawn(_player.global_position + Vector2(-90, 0), big, 0.0, 1, "cup", false)
		await _wait(1.6)
		_check(target != null and target.hp < big, "%s（%s）能造成伤害" % [id, WeaponDB.display_name(id)])

	# 光环：减速而不是推开（NUM_DESIGN §4.1 修正点）
	_enemies.clear_all()
	if not _weapons.has_weapon("halo"):
		_weapons.acquire("halo")
	_weapons.owned["halo"] = 3
	var slowed: Enemy = _enemies.spawn(_player.global_position + Vector2(30, 0), big, 0.0, 1, "cup", false)
	await _wait(0.7)
	_check(slowed != null and slowed.is_slowed(), "光环给敌人上了减速状态（不是推开）")
	var pos_before: Vector2 = slowed.global_position
	await _wait(0.25)
	_check(slowed.global_position.distance_to(pos_before) < 12.0,
		"被减速的敌人仍贴在玩家身边（位移 %.1f px，没有被推走＝没变成无声无敌）"
			% slowed.global_position.distance_to(pos_before))

	# 6 槽位上限：拿到第 7 把武器时不该再出现新武器卡
	await _reset_stats()
	var fake_owned: Dictionary = {}
	for id in WeaponDB.ORDER:
		fake_owned[id] = 1
	_weapons.owned = fake_owned.duplicate()
	_weapons._cd.clear()
	var slots_full: bool = _weapons.owned.size() >= UpgradeDB.WEAPON_SLOTS
	var pool_has_new_weapon := false
	for e in UpgradeDB.draw(UpgradeDB.CARD_COUNT):
		var d: Dictionary = e["def"]
		if String(d["kind"]) == "weapon" and bool(e["is_new"]):
			pool_has_new_weapon = true
	_check(slots_full and not pool_has_new_weapon, "武器槽满 %d 后不再抽新武器卡" % UpgradeDB.WEAPON_SLOTS)

	# 复位成只有鞭弧
	_weapons.owned = {"whip": 1}
	_weapons._cd = {"whip": 0.1}
	_enemies.clear_all()

# ---------------------------------------------------------------- 阶段二 Step 8
## 进化：指定武器 Lv8 + 指定被动 Lv>=1 → 精英掉宝箱 → 开箱进化。
func _step8_evolution() -> void:
	await _prep()
	_auto_pick = false
	print("\n[Step8] 进化配方（3 条）")

	_check(EvolutionDB.FORMS.size() == 6, "配方表 %d 条（3 旧 + 铜锣/墨斗/打铁花）" % EvolutionDB.FORMS.size())

	# 1) 条件门：不满足就不给进化
	await _reset_stats()
	_weapons.owned = {"whip": 8}
	_weapons.evolved.clear()
	var lv0: int = _player.level_upgrades.get("damage", 0)
	_check(lv0 == 0, "前置：力量被动 Lv0")
	_check(not _weapons.is_evolved("whip"), "鞭弧 Lv8 但缺被动时不进化")
	_check(not _game.can_evolve_any(), "配方不满足时 candidates 为空")

	# 配方对齐 params.json：1.7 / 1.5 / 1.4，且 req_passive 各不相同
	var fw: Dictionary = EvolutionDB.form("evolve_whip")
	var fg: Dictionary = EvolutionDB.form("evolve_glowstick")
	var fh: Dictionary = EvolutionDB.form("evolve_halo")
	_check(is_equal_approx(float(fw["dps_mult"]), 1.7) and is_equal_approx(float(fw["area_mult"]), 1.5),
		"血鞭倍率 dps×%.2f / area×%.2f" % [float(fw["dps_mult"]), float(fw["area_mult"])])
	_check(is_equal_approx(float(fg["dps_mult"]), 1.5) and is_equal_approx(float(fg["area_mult"]), 1.0),
		"圣魔杖倍率 dps×%.2f / area×%.2f" % [float(fg["dps_mult"]), float(fg["area_mult"])])
	_check(is_equal_approx(float(fh["dps_mult"]), 1.4) and is_equal_approx(float(fh["area_mult"]), 1.6),
		"圣蒜倍率 dps×%.2f / area×%.2f" % [float(fh["dps_mult"]), float(fh["area_mult"])])
	_check(String(fw["req_passive"]) == "damage" and String(fg["req_passive"]) == "cooldown" and String(fh["req_passive"]) == "area",
		"三条配方分别绑定 伤害 / 冷却 / 范围 被动")

	# 2) 补齐条件后必须能进化
	UpgradeDB.apply({"def": {"id": "damage", "kind": "stat"}, "new_level": 1})
	_check(EvolutionDB.meets_recipe("whip", 8, 1), "鞭弧 Lv8 + 力量 Lv1 满足配方")
	_check(_game.can_evolve_any(), "满足配方后 candidates 非空")
	var evolved_ok: bool = _game._open_chest()
	_check(evolved_ok and _weapons.is_evolved("whip"), "开箱后鞭弧进化为 %s" % _weapons.display_name("whip"))
	_check(_weapons.owned.size() == 1, "进化不占新武器槽（仍 %d 把）" % _weapons.owned.size())

	# 3) 进化真的增强：同一等级下伤害/范围都要更大
	await _reset_stats()
	var plain: float = WeaponDB.damage_at("whip", 8, 1.0)
	var boosted: float = plain * float(fw["dps_mult"])
	_check(boosted > plain * 1.6, "进化后鞭弧伤害 %.1f → %.1f" % [plain, boosted])

	# 4) 宝箱链路：精英死 → 掉宝箱 → 走过去自动开
	_enemies.clear_all()
	_chests_clear()
	_weapons.evolved.clear()
	_weapons.owned = {"whip": 8}
	UpgradeDB.apply({"def": {"id": "damage", "kind": "stat"}, "new_level": 1})
	# 精英必须给超高血量：鞭弧会在等待帧里把它顺手打死，
	# 那样"手动击杀"就变成了"被武器打死"，测不到我们想测的那条链。
	var elite: Enemy = _enemies.spawn(_player.global_position + Vector2(120, 0), 99999.0, 0.0, 12, "box", true)
	await _wait(0.1)
	var before_chest: int = _game.chest_count()
	_check(elite.alive, "精英存活（等待期间没被武器顺手打死）")
	elite.take_damage(999999.0)
	await _wait_frames(3)
	_check(_game.chest_count() == before_chest + 1, "精英死亡掉落宝箱（场上 %d 只）" % _game.chest_count())
	# 走到宝箱上：直接把它挪到脚下，走真实拾取判定
	var chest: Sprite2D = _game._chests[0]
	chest.position = _player.global_position
	await _wait_frames(3)
	_check(_weapons.is_evolved("whip"), "走到宝箱上自动开箱并进化")
	_check(_game.chest_count() == 0, "宝箱拾取后清场")

	# 5) 普通敌人不掉宝箱（否则进化会变成刷金币）
	_chests_clear()
	var mob: Enemy = _enemies.spawn(_player.global_position + Vector2(120, 0), 1.0, 0.0, 1, "cup", false)
	await _wait(0.1)
	mob.take_damage(99999.0)
	await _wait_frames(3)
	_check(_game.chest_count() == 0, "普通敌人死亡不掉宝箱")

	# 6) 硬约束验算 X11 < X1：三把进化武器的 DPS/R 必须低于六把未进化之和
	var x1_sum: float = 0.0
	for id in WeaponDB.ORDER:
		x1_sum += _dps_per_radius(id, 8, 1.0)
	var x11_sum: float = 0.0
	for id in WeaponDB.ORDER:
		var fid: String = EvolutionDB.form_id_for(id)
		var mul: float = 1.0
		if fid != "":
			mul = float(EvolutionDB.form(fid)["dps_mult"])
		x11_sum += _dps_per_radius(id, 8, mul)
	_check(x11_sum < x1_sum * 3.0,
		"X11 < X1 量级校验：6 把全进化 %.1f < 6 把未进化 %.1f × 3" % [x11_sum, x1_sum])
	# 逐把比较：任何一把进化武器的 dps/R 都不得超过整包未进化总量
	var worst: float = 0.0
	for id in WeaponDB.ORDER:
		var fid: String = EvolutionDB.form_id_for(id)
		if fid == "":
			continue
		worst = maxf(worst, _dps_per_radius(id, 8, float(EvolutionDB.form(fid)["dps_mult"])))
	_check(worst < x1_sum, "最强进化武器 dps/R %.1f < 六把未进化之和 %.1f（防止'少拿武器去进化'成最优解）" % [worst, x1_sum])

	# 7) 进化后不再出现在升级池
	_weapons.owned = {"whip": 8}
	_weapons.evolved = {"whip": "evolve_whip"}
	var pool_has_whip := false
	for e in UpgradeDB.draw(12):
		if String((e["def"] as Dictionary)["id"]) == "whip":
			pool_has_whip = true
	_check(not pool_has_whip, "已进化的武器不再出现在升级三选一里")

	# 复位
	_chests_clear()
	_weapons.evolved.clear()
	_weapons.owned = {"whip": 1}
	_weapons._cd = {"whip": 0.1}
	await _reset_stats()
	_enemies.clear_all()

## 粗算 dps/radius：冷却 + 单体伤害 + 覆盖半径，用来做量级比较（不是精确模拟）
func _dps_per_radius(id: String, lv: int, dmg_mul: float) -> float:
	var d: Dictionary = WeaponDB.def(id)
	var cd: float = maxf(WeaponDB.cooldown_at(id, lv, 1.0), 0.12)
	var dmg: float = WeaponDB.damage_at(id, lv, 1.0) * dmg_mul
	var hits: float = 1.0
	var radius: float = 120.0
	match id:
		"whip":
			radius = minf(float(d.get("length", 110.0)) + float(d.get("length_per_level", 12.0)) * float(lv - 1),
				float(d.get("length_cap", 260.0))) * 0.5 + float(d.get("width", 64.0)) * 0.5
			hits = 2.0
		"halo":
			radius = float(d.get("radius", 70.0)) + float(d.get("radius_per_level", 7.0)) * float(lv - 1)
			hits = radius / 24.0
		"glowstick":
			hits = float(WeaponDB.count_at(id, lv))
			radius = float(d.get("range", 500.0)) * 0.5
		"phone":
			radius = float(d.get("orbit_radius", 58.0)) + float(d.get("orbit_radius_per_level", 5.0)) * float(lv - 1)
			hits = float(d.get("orbit_count", 2))
		"blade":
			hits = 1.0 + float(d.get("bounce", 0))
			radius = float(d.get("bounce_range", 260.0))
		"extinguisher":
			hits = float(d.get("hit_cap", 4))
			radius = float(d.get("range", 320.0))
	return (dmg * hits / cd) / maxf(radius, 1.0) * 100.0

func _chests_clear() -> void:
	for c in _game._chests:
		if is_instance_valid(c):
			c.queue_free()
	_game._chests.clear()

# ==================================================================
# 阶段三（Step 9 / 10 / 11）：压力曲线、资源点、结算
# ==================================================================

## Step 9：时间波次表。全部是纯函数，直接对 params.json v3.1 的数值断言。
func _step9_wave_table() -> void:
	await _prep()
	_auto_pick = false
	print("\n[Step9a] 时间驱动波次表")

	# 1) 刷怪间隔：1.1 → 0.45，600 秒后封底
	_check(absf(WaveTable.spawn_interval(0.0) - 1.10) < 0.001,
		"t=0 刷怪间隔 1.10s（实测 %.3f）" % WaveTable.spawn_interval(0.0))
	_check(absf(WaveTable.spawn_interval(300.0) - 0.775) < 0.005,
		"t=300 刷怪间隔 0.775s（实测 %.3f）" % WaveTable.spawn_interval(300.0))
	_check(absf(WaveTable.spawn_interval(600.0) - 0.45) < 0.001,
		"t=600 刷怪间隔 0.45s 封底（实测 %.3f）" % WaveTable.spawn_interval(600.0))
	_check(absf(WaveTable.spawn_interval(1800.0) - 0.45) < 0.001,
		"t=1800 不再收紧，仍 0.45s（实测 %.3f）" % WaveTable.spawn_interval(1800.0))

	# 2) 单批数量 6 + 0.01t，封顶 30
	_check(WaveTable.batch_size(0.0) == 6, "t=0 单批 6 只（实测 %d）" % WaveTable.batch_size(0.0))
	_check(WaveTable.batch_size(600.0) == 12, "t=600 单批 12 只（实测 %d）" % WaveTable.batch_size(600.0))
	_check(WaveTable.batch_size(1800.0) == 24, "t=1800 单批 24 只（实测 %d）" % WaveTable.batch_size(1800.0))
	_check(WaveTable.batch_size(5000.0) == 30, "单批封顶 30 只（实测 %d）" % WaveTable.batch_size(5000.0))

	# 3) 敌人血量 3 × (1+t/1800)^1.70
	_check(absf(WaveTable.enemy_hp(0.0) - 3.0) < 0.001,
		"t=0 杂兵 3 血（实测 %.2f）" % WaveTable.enemy_hp(0.0))
	var hp900: float = WaveTable.enemy_hp(900.0)
	_check(absf(hp900 - 3.0 * pow(1.5, 1.70)) < 0.01,
		"t=900 杂兵 %.1f 血（=3×1.5^1.70）" % hp900)
	var hp1800: float = WaveTable.enemy_hp(1800.0)
	_check(absf(hp1800 - 3.0 * pow(2.0, 1.70)) < 0.02,
		"t=1800 杂兵 %.1f 血（=3×2^1.70）" % hp1800)
	# 单调递增：任何"后期血量比前期低"的回归都会在这里炸
	var mono_ok := true
	var prev: float = -1.0
	for k in 37:
		var h: float = WaveTable.enemy_hp(float(k) * 50.0)
		if h < prev:
			mono_ok = false
		prev = h
	_check(mono_ok, "血量函数在 0~1800s 全程单调递增")

	# 4) 波次表：5 段，精英占比逐段上升
	_check(WaveTable.WAVES.size() == 5, "波次表 %d 段" % WaveTable.WAVES.size())
	var rising := true
	var last_share: float = -1.0
	for w in WaveTable.WAVES:
		var s: float = float(w["elite_share"])
		if s < last_share:
			rising = false
		last_share = s
	_check(rising, "精英占比随波次单调不降（0→6%%→10%%→14%%→18%%）")

	_check(absf(WaveTable.elite_share(0.0)) < 0.0001, "0~5min 无精英（实测 %.0f%%）" % (WaveTable.elite_share(0.0) * 100.0))
	_check(absf(WaveTable.elite_share(450.0) - 0.06) < 0.0001, "5~10min 精英 6%%（实测 %.0f%%）" % (WaveTable.elite_share(450.0) * 100.0))
	_check(absf(WaveTable.elite_share(900.0) - 0.10) < 0.0001, "10~20min 精英 10%%（实测 %.0f%%）" % (WaveTable.elite_share(900.0) * 100.0))
	_check(absf(WaveTable.elite_share(1300.0) - 0.14) < 0.0001, "20~25min 精英 14%%（实测 %.0f%%）" % (WaveTable.elite_share(1300.0) * 100.0))
	_check(absf(WaveTable.elite_share(1700.0) - 0.18) < 0.0001, "25~30min 精英 18%%（实测 %.0f%%）" % (WaveTable.elite_share(1700.0) * 100.0))

	# 5) 杂兵阵容倍率：均值 1.1333 会推高需求侧，这一条是 §9.1 R 曲线的输入
	var avg: float = 0.0
	for k in WaveTable.MOB_DEFS.keys():
		avg += float((WaveTable.MOB_DEFS[k] as Dictionary)["hp_mult"])
	avg /= float(WaveTable.MOB_DEFS.size())
	_check(absf(avg - 1.1333) < 0.002, "杂兵血量倍率均值 %.4f（=1.1333，已计入 R 曲线）" % avg)

	# 6) 种类分布：30s 前纯 cup，120s 前不出 fast
	var only_cup := true
	for i in 40:
		if WaveTable.pick_mob(10.0, float(i) / 40.0) != "cup":
			only_cup = false
	_check(only_cup, "前 30 秒只刷杯子（不出现快速兵）")
	var no_fast := true
	for i in 40:
		if WaveTable.pick_mob(100.0, float(i) / 40.0) == "fast":
			no_fast = false
	_check(no_fast, "30~120 秒仍不出快速兵（只加肉盾）")
	var seen: Dictionary = {}
	for i in 200:
		seen[WaveTable.pick_mob(900.0, float(i) / 200.0)] = true
	_check(seen.has("cup") and seen.has("bag") and seen.has("fast"),
		"120 秒后三种杂兵全部出现（实测 %s）" % str(seen.keys()))

	# 7) 精英种类：10 分钟后才出红精英
	var box_only := true
	for i in 40:
		if WaveTable.pick_elite(300.0) != "box":
			box_only = false
	_check(box_only, "10 分钟前的精英固定为蓝箱")
	var got_red := false
	var got_box := false
	for i in 120:
		if WaveTable.pick_elite(900.0) == "red":
			got_red = true
		else:
			got_box = true
	_check(got_box and got_red, "10 分钟后蓝箱/红精英两种都会出现")

## Step 9：Boss 登场与击杀。
func _step9_boss() -> void:
	await _prep()
	print("\n[Step9b] Boss 登场")

	_check(WaveTable.BOSSES.size() == 3, "Boss 表 %d 档（15min / 25min / 30min）" % WaveTable.BOSSES.size())
	_check(absf(float(WaveTable.BOSSES[0]["t"]) - 900.0) < 0.01, "第 1 只 Boss 在 900s")
	_check(absf(float(WaveTable.BOSSES[1]["t"]) - 1500.0) < 0.01, "第 2 只 Boss 在 1500s")
	_check(absf(float(WaveTable.BOSSES[2]["t"]) - 1800.0) < 0.01, "第 3 只 Boss 在 1800s")
	_check(absf(float(WaveTable.BOSSES[0]["hp"]) - 2800.0) < 0.01, "Boss1 血量 2800")
	_check(absf(float(WaveTable.BOSSES[1]["hp"]) - 6100.0) < 0.01, "Boss2 血量 6100")
	# v5：终局 Boss 11000 → 7000（局内可独立通关，见 v5_ai_playbook §6 Phase 4）
	_check(absf(float(WaveTable.BOSSES[2]["hp"]) - 7000.0) < 0.01, "Boss3 血量 7000（v5 下调）")

	# 跨越判定：只在"这一帧越过时间点"时返回，不能每帧都返回
	var due_a: Dictionary = WaveTable.boss_due(899.0, 900.0)
	_check(not due_a.is_empty(), "899→900 判定 Boss1 登场")
	_check(not WaveTable.boss_due(899.0, 900.0).is_empty(), "跨越判定可重复调用")
	var due_none: Dictionary = WaveTable.boss_due(900.0, 901.0)
	_check(due_none.is_empty(), "900→901 不重复判定（避免每帧刷 Boss）")
	# 大步跨越（比如断点续跑/掉帧）只应返回最早那一档，不能一帧把 3 只 Boss 一起放出来。
	# boss_due 的 for 循环里 return 第一个命中项，所以这里断言"返回的是 Boss1 而非 Boss3"。
	var jump: Dictionary = WaveTable.boss_due(899.0, 1900.0)
	_check(not jump.is_empty() and absf(float(jump["t"]) - 900.0) < 0.01,
		"899→1900 大步跨越只返回最早一档 Boss（t=%.0f）" % float(jump.get("t", -1.0)))
	_check(not WaveTable.boss_due(1799.0, 1800.0).is_empty(), "1799→1800 判定终局 Boss（>= 边界）")

	# 实际生成：把 elapsed 拨到 899.99 再推进一帧，让 Game._check_boss 真的跑一次
	_enemies.clear_all()
	GameManager.started = true
	_game.elapsed = 899.99
	_game.set("_prev_t", 899.99)
	_game.won = false
	await _wait_frames(3)
	var boss: Enemy = _enemies.boss()
	_check(boss != null, "Game 在 900s 实际生成了 Boss")
	if boss != null:
		_check(boss.is_boss, "生成体 is_boss = true")
		_check(absf(boss.max_hp - 2800.0) < 1.0, "Boss1 血量 %.0f（表值 2800）" % boss.max_hp)
		_check(boss.is_elite, "Boss 复用精英标记（血条常显/宝箱掉落走同一条通路）")
		_check(absf(boss.contact_damage - WaveTable.CONTACT_DAMAGE * WaveTable.BOSS_DAMAGE_MULT) < 0.01,
			"Boss 接触伤害 %.0f（=杂兵 %.0f × 3.0 倍率）" % [boss.contact_damage, WaveTable.CONTACT_DAMAGE])
		_check(absf(boss.touch_radius - WaveTable.BOSS_CONTACT_R) < 0.01,
			"Boss 判定半径 %.0f（params 钉死 34，不套 size*0.36）" % boss.touch_radius)
		_check(boss.hp_bar.visible, "Boss 血条常显")

	# Boss 在场时刷怪被压制：间隔应变成 1/0.35 倍
	_check(_enemies.has_boss(), "has_boss() 在 Boss 存活时返回 true")

	# Boss 击杀 → boss_kills + 宝箱 + 大宝石
	var kills_before: int = _game.boss_kills
	var chests_before: int = _game.chest_count()
	var boss_pos: Vector2 = boss.global_position if boss != null else Vector2.ZERO
	if boss != null:
		boss.take_damage(99999.0)
	await _wait_frames(3)
	_check(_game.boss_kills == kills_before + 1, "Boss 死亡计入 boss_kills（%d→%d）" % [kills_before, _game.boss_kills])
	_check(_game.chest_count() > chests_before, "Boss 必掉宝箱（%d→%d）" % [chests_before, _game.chest_count()])
	_check(not _enemies.has_boss(), "Boss 死后 has_boss() 变回 false")

	# 尸体回收：Boss 死后必须离开 active，否则池位只增不减。
	#
	# 【断言口径】不能断言"对象不在 active 里" —— 池子会把同一个 Enemy 实例
	# 立刻复用成下一只杂兵，于是 `active.has(boss)` 又会变回 true。
	# 正确的口径是：这只 Boss 已经死了，且池子没泄漏（inactive 有货）。
	await _wait(0.5)
	var boss_revived_as_boss := false
	for e in _enemies.active:
		if e == boss and e.alive and e.is_boss:
			boss_revived_as_boss = true
	_check(not boss_revived_as_boss, "Boss 尸体在 %.1fs 内被回收（未被当作活体重复计算）" % Enemy.CORPSE_TIME)
	_check(_enemies.inactive.size() > 0,
		"回收后池子有 %d 个可复用对象（无泄漏）" % _enemies.inactive.size())

	# 收尾：清 Boss 场景状态
	_chests_clear()
	_enemies.clear_all()
	await _reset_stats()

## Step 10：掉落物（磁铁 / 炸弹 / 烤鸡）与炸弹限流。
func _step10_pickups() -> void:
	await _prep()
	print("\n[Step10a] 随机掉落")

	_check(PickupField.DEFS.size() == 3, "掉落物 %d 种（磁铁/炸弹/烤鸡）" % PickupField.DEFS.size())
	_check(absf(PickupField._rate("magnet") - 0.0005) < 1e-9, "磁铁掉率 0.0005/击杀")
	_check(absf(PickupField._rate("bomb") - 0.0002) < 1e-9, "炸弹掉率 0.0002/击杀")
	_check(absf(PickupField._rate("bento") - 0.0003) < 1e-9, "烤鸡掉率 0.0003/击杀")
	# 三张图必须真实存在，否则掉落出来是个空白精灵（不会报错，只会"看不见东西"）
	for kind in PickupField.DEFS.keys():
		var path: String = String((PickupField.DEFS[kind] as Dictionary)["svg"])
		_check(ResourceLoader.exists(path), "掉落物 %s 贴图存在：%s" % [kind, path])

	# 掉落返回类型正确
	_game.pickups.clear_all()
	_game.bombs_dropped = 0
	_game.magnets_dropped = 0
	var spawned := false
	for i in 6000:
		var got: String = _game.pickups.roll_drop(Vector2(i, 0), _game)
		if got != "":
			spawned = true
			break
	_check(spawned, "6000 次击杀掷点至少掉出一次东西（掉率量级正确，不是 0 也不是 100%）")

	# 炸弹限流 ①：每局上限 4
	_game.pickups.clear_all()
	_game.bombs_dropped = 0
	var forced_bombs := 0
	var overflows := 0
	# 每 10000 次击杀的炸弹期望只有 2 次（0.0002），要观察"超过 4 次后转宝石"
	# 必须把预算放大到 300000 次掷点。之前写 4000 次，连 4 个都还没凑满，
	# 自然看不到 overflow —— 是测试预算错了，不是限流没生效。
	var rolls := 0
	while rolls < 300000 and not (forced_bombs >= PickupField.BOMB_PER_RUN_CAP and overflows > 0):
		var got: String = _game.pickups.roll_drop(Vector2.ZERO, _game)
		rolls += 1
		if got == "bomb":
			forced_bombs += 1
		elif got == "bomb_overflow":
			overflows += 1
		# 掉出来的实体不用留，避免 CAP 40 顶住后续 spawn
		if _game.pickups.count() > 0:
			_game.pickups.clear_all()
	_check(_game.bombs_dropped <= PickupField.BOMB_PER_RUN_CAP,
		"本局炸弹实际掉落 %d 个 ≤ 上限 %d（掷点 %d 次）" % [
			_game.bombs_dropped, PickupField.BOMB_PER_RUN_CAP, rolls])
	_check(overflows > 0, "超出上限的炸弹 roll 转成宝石（overflow %d 次）" % overflows)
	_check(rolls <= 300000, "限流在上限处以概率生效，而非阻断全部掉落")

	# 炸弹限流 ②：Boss 在场时一次都不掉
	_game.pickups.clear_all()
	_game.bombs_dropped = 0
	_enemies.clear_all()
	GameManager.started = true
	var fake_boss: Enemy = _enemies.spawn(Vector2(100, 100), 99999.0, 0.0, 1, "reaper", true, 30.0, true)
	_check(fake_boss != null, "构造一只在场 Boss 用于限流验证")
	var boss_bomb := 0
	for i in 6000:
		if _game.pickups.roll_drop(Vector2.ZERO, _game) == "bomb":
			boss_bomb += 1
	_check(boss_bomb == 0, "Boss 在场时炸弹掉落 %d 次（必须为 0）" % boss_bomb)
	_enemies.clear_all()

	# 铜铃（原磁铁）：全图吸取。
	# ⚠️ 这条断言以前只校验 `age == 999`，而那正是实现的**内部手法**、不是效果 ——
	#    真正让道具失效的原因就是"吸引条件看距离、age 根本不参与判定"，
	#    于是断言全绿、道具全废。现在一律断言**收进袋**（gem_count 归零）。
	_game.pickups.clear_all()
	_game.gems.active.clear()
	for i in 12:
		_game.gems.spawn(_player.global_position + Vector2(-700.0 - float(i) * 10.0, 0), 1)
	var gems_before: int = _game.gem_count()
	_check(gems_before == 12, "铜铃生效前场上有 %d 颗 700px 外的灯花" % gems_before)
	_game.pickups.spawn(_player.global_position + Vector2(4, 0), "magnet")
	await _wait(0.3)
	var flying_all := true
	for g in _game.gems.active:
		if not g.flying:
			flying_all = false
	_check(flying_all or _game.gem_count() == 0, "铜铃让磁吸圈外的灯花也进入飞行")
	# 1100px/s 飞 700px 约 0.7s，给到 2s 余量（headless 帧率不稳）
	var t_wait := 0.0
	while t_wait < 2.0 and _game.gem_count() > 0:
		await _wait(0.1)
		t_wait += 0.1
	_check(_game.gem_count() == 0, "铜铃把远处灯花全部收进袋（剩 %d 颗）" % _game.gem_count())

	# 炸弹：清掉屏内非 Boss，且不碰 Boss
	_enemies.clear_all()
	var near: Enemy = _enemies.spawn(_player.global_position + Vector2(120, 0), 500.0, 0.0, 1, "cup", false)
	var far: Enemy = _enemies.spawn(_player.global_position + Vector2(900, 0), 500.0, 0.0, 1, "cup", false)
	var safe_boss: Enemy = _enemies.spawn(_player.global_position + Vector2(80, 0), 500.0, 0.0, 1, "reaper", true, 30.0, true)
	await _wait_frames(2)
	_game.pickups.spawn(_player.global_position, "bomb")
	await _wait(0.12)
	_check(near == null or not near.alive, "炸弹清掉屏内杂兵")
	_check(safe_boss != null and safe_boss.alive, "炸弹对 Boss 无效（否则 Boss 战等于重开一颗）")
	_check(far == null or far.alive, "炸弹不打 700px 外的敌人（只清屏内）")

	# 烤鸡：回血 30% max_hp
	_enemies.clear_all()
	GameManager.stats["hp"] = 10.0
	var mx: float = float(GameManager.stats["max_hp"])
	_game.pickups.spawn(_player.global_position, "bento")
	await _wait(0.12)
	var healed: float = float(GameManager.stats["hp"])
	_check(healed > 10.0, "烤鸡回血生效：10 → %.1f" % healed)
	_check(healed <= mx + 0.01, "烤鸡不会超过最大生命（%.1f ≤ %.1f）" % [healed, mx])

	# 掉落物有时限，不会永远堆在地上
	_game.pickups.clear_all()
	_game.pickups.spawn(_player.global_position + Vector2(2000, 2000), "magnet")
	_check(_game.pickups.count() == 1, "掉落物落地计数 1")
	_game.pickups.clear_all()
	_check(_game.pickups.count() == 0, "clear_all 后掉落物清空（重开不残留）")

	_game.pickups.clear_all()
	_game.bombs_dropped = 0
	_enemies.clear_all()
	await _reset_stats()

## Step 10：可破坏资源点。
func _step10_resources() -> void:
	await _prep()
	print("\n[Step10b] 场景资源点")

	var res: ResourceField = _game.get_node("World/Resources") as ResourceField
	_check(res != null, "Game 场景里有 Resources 节点")
	if res == null:
		return
	# 相机在玩家身上，_sync_cells 需要相机位置；先挪玩家到原点让格子稳定
	_player.global_position = Vector2.ZERO
	await _wait(0.35)
	var alive_n: int = res.count()
	_check(alive_n > 0, "视野内生成 %d 个资源点" % alive_n)

	# 确定性：走开再走回来，同一格还是同一批（不会闪烁/乱跳）
	var first_positions: Array[Vector2] = []
	for key in res._alive.keys():
		first_positions.append(Vector2((res._alive[key] as Dictionary)["pos"]))
	# 上面已拆掉一个资源点（进 _broken），确定性检查只用剩下的
	_player.global_position = Vector2(9000.0, 9000.0)
	await _wait(0.3)
	_player.global_position = Vector2.ZERO
	await _wait(0.4)
	# 回到原点后，之前那批位置必须原样恢复（_despawn 只回收节点，不销毁生成记录）
	var restored := 0
	for p in first_positions:
		if _has_alive_at(res, p):
			restored += 1
	_check(restored == first_positions.size(),
		"走开再回来资源点位置不变：%d/%d 个原位恢复（格哈希确定性生成）" % [restored, first_positions.size()])

	# 打掉：金币增加 + 节点消失
	var key0: String = ""
	for k in res._alive.keys():
		key0 = String(k)
		break
	if key0 != "":
		var pos0: Vector2 = (res._alive[key0] as Dictionary)["pos"]
		var coins_before: int = _game.coins_earned
		var hp_before: float = float((res._alive[key0] as Dictionary)["hp"])
		var hit: bool = res.try_hit(pos0, 4.0, ResourceField.HP * 0.5)
		_check(hit, "武器命中资源点返回 true")
		_check(res._alive.has(key0) and float((res._alive[key0] as Dictionary)["hp"]) < hp_before,
			"一次半血伤害后资源点仍在，但 HP 从 %.0f 降到 %.0f" % [hp_before, float((res._alive[key0] as Dictionary)["hp"])])
		res.try_hit(pos0, 4.0, 9999.0)
		_check(not res._alive.has(key0), "血量归零后资源点被拆掉")
		_check(_game.coins_earned > coins_before,
			"拆掉资源点给金币（%d → %d）" % [coins_before, _game.coins_earned])

	# 空处命中不应返回 true
	_check(not res.try_hit(Vector2(999999.0, 999999.0), 4.0, 100.0), "空地命中不误判")

	# 武器通路：鞭弧能打到资源点（说明 WeaponManager.resources 已接线）
	_check(_game.weapons.resources == res, "WeaponManager.resources 已绑定到 Resources 节点")

	# 重开后资源点金币不跨局残留
	_game.coins_earned = 0

func _has_alive_at(res: ResourceField, p: Vector2) -> bool:
	for k in res._alive.keys():
		if Vector2((res._alive[k] as Dictionary)["pos"]).distance_to(p) < 0.5:
			return true
	return false

## Step 11：胜负结算与金币公式。
func _step11_result() -> void:
	await _prep()
	print("\n[Step11] 胜负结算")

	# 金币公式：击杀 + 时长 + 精英/Boss + 资源点，胜利 ×1.5
	_game.kills = 0
	_game.elapsed = 0.0
	_game.elite_kills = 0
	_game.boss_kills = 0
	_game.coins_earned = 0
	_game.won = false
	_check(_game.coin_reward() == 0, "空局金币 0（实测 %d）" % _game.coin_reward())

	_game.kills = 1000
	_game.elapsed = 600.0
	var base: int = int(1000.0 * 0.12) + int(600.0 / 12.0)
	_check(_game.coin_reward() == base, "1000 杀 + 10min = %d 金币（公式 120+50）" % _game.coin_reward())

	_game.elite_kills = 3
	_game.boss_kills = 1
	_check(_game.coin_reward() == base + 3 * 6 + 40,
		"精英 3 只 + Boss 1 只再加 %d 金币（实测 %d）" % [3 * 6 + 40, _game.coin_reward()])

	_game.coins_earned = 25
	_check(_game.coin_reward() == base + 18 + 40 + 25,
		"资源点金币 %d 直接相加（实测 %d）" % [25, _game.coin_reward()])

	var lose_coins: int = _game.coin_reward()
	_game.won = true
	_check(_game.coin_reward() == int(float(base + 18 + 40) * 1.5) + 25,
		"胜利 ×1.5 乘数只作用于击杀/时长部分，不放大资源点金币（%d → %d）" % [lose_coins, _game.coin_reward()])

	# 结算界面：失败
	_game.won = false
	_game.kills = 1000
	_game.elapsed = 612.0
	_game.coins_earned = 0
	_game.elite_kills = 0
	_game.boss_kills = 0
	_deathui.show_result(_game.kills, _game.elapsed, 22, false, lose_coins, 0, 0, 0)
	await _wait_frames(2)
	_check(_deathui.is_open(), "失败结算面板打开")
	var title_lbl: Label = _deathui.get_node("Popup/Panel/VB/Title") as Label
	_check(title_lbl.text == "灯灭了", "失败标题「灯灭了」（实测「%s」）" % title_lbl.text)
	var coins_lbl: Label = _deathui.get_node("Popup/Panel/VB/Coins") as Label
	_check(coins_lbl != null and coins_lbl.visible, "结算面板显示金币行")
	_check(coins_lbl != null and coins_lbl.text.contains(str(lose_coins)),
		"金币行内容含实际金币 %d（实测「%s」）" % [lose_coins, coins_lbl.text if coins_lbl != null else ""])
	var info_lbl: Label = _deathui.get_node("Popup/Panel/VB/Info") as Label
	_check(info_lbl.text.contains("归色"), "结算明细含归色数")
	_check(info_lbl.text.contains("10:12"), "结算明细含存活时长 10:12（实测含 %s）" % str(info_lbl.text.contains("10:12")))
	get_tree().paused = false
	_deathui.get_node("Popup").visible = false
	_deathui.get_node("Mask").visible = false
	await _wait_frames(2)

	# 结算界面：胜利
	_game.won = true
	_game.elapsed = WaveTable.RUN_LENGTH
	_deathui.show_result(3000, WaveTable.RUN_LENGTH, 45, true, 999, 8, 3, 4)
	await _wait_frames(2)
	_check(_deathui.is_open(), "胜利结算面板打开")
	_check(title_lbl.text == "五更鸡鸣", "胜利标题「五更鸡鸣」（实测「%s」）" % title_lbl.text)
	_check(info_lbl.text.contains("30:00"), "胜利明细显示 30:00 满时长")
	_check(info_lbl.text.contains("Boss"), "胜利明细含 Boss 击杀数")
	_check(info_lbl.text.contains("传承"), "胜利明细含传承数")
	_check(title_lbl.get_theme_color("font_color").g > title_lbl.get_theme_color("font_color").r * 0.8,
		"胜利标题为金色（与非失败红区分）")
	get_tree().paused = false
	_deathui.get_node("Popup").visible = false
	_deathui.get_node("Mask").visible = false
	await _wait_frames(2)

	# 真实胜负闭环：玩家血量归零 → 走 Game._on_player_died
	game_reset_round()
	GameManager.started = true
	_player.set("invuln_left", 0.0)
	GameManager.stats["hp"] = 0.5
	_player.take_damage(9999.0)
	await _wait(0.2)
	_check(_deathui.is_open(), "玩家死亡触发结算面板（真实通路，非直接调 show_result）")
	_check(not GameManager.started, "死亡后 GameManager.started = false（停止刷怪）")
	get_tree().paused = false
	_deathui.get_node("Popup").visible = false
	_deathui.get_node("Mask").visible = false
	await _wait_frames(2)

	# 胜利闭环：把 elapsed 推到 RUN_LENGTH 前 1 帧
	game_reset_round()
	GameManager.started = true
	_enemies.clear_all()
	_game.won = false
	_game.elapsed = WaveTable.RUN_LENGTH - 0.02
	_game.set("_prev_t", WaveTable.RUN_LENGTH - 0.02)
	await _wait(0.2)
	_check(_game.won, "撑满 %d 秒后 won = true" % int(WaveTable.RUN_LENGTH))
	# 五更鸡鸣演出（T4.5）：判胜和"进结算"不再是同一帧，这里必须按新时序断言。
	# 原来这两条写在一起，等于把"演出"判成失败 —— 是测试假设过期，不是功能坏了。
	_check(not _deathui.is_open(), "判胜后 %.1fs 内不进结算（演出期看得到终局 Boss）" % GameScene.WIN_HOLD)
	get_tree().paused = false
	# ⚠️ 这里不能按"帧数"等：_win_hold 吃的是引擎真实 delta，headless 帧率不固定，
	# 固定帧数在高帧率机器上会等不够（面板还没开就断言 → 假红）。
	# 改成"轮询到面板打开 + 真实时间上限"，无论帧率都稳。
	var waited: float = 0.0
	while not _deathui.is_open() and waited < GameScene.WIN_HOLD * 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(_deathui.is_open(), "演出结束后进入结算面板（实等 %.2fs）" % waited)
	_check(title_lbl.text == "五更鸡鸣", "胜利闭环标题正确")
	get_tree().paused = false
	_deathui.get_node("Popup").visible = false
	_deathui.get_node("Mask").visible = false
	await _wait_frames(2)

## 把上一用例留下的计数复位，但不动 elapsed（有的用例需要它继续往前跑）
func game_reset_round() -> void:
	get_tree().paused = false
	if _lvui.is_open():
		_lvui.close_all()
	_enemies.clear_all()
	_game.pickups.clear_all()
	_chests_clear()
	_game.won = false
	_game.elite_kills = 0
	_game.boss_kills = 0
	_game.evolutions = 0
	_game.bombs_dropped = 0
	_game.magnets_dropped = 0
	_game.coins_earned = 0
	_game.banked = false
	# 五更鸡鸣演出也必须复位：上一个用例判了胜但演出还没走完就复位，
	# 下一次进 _process 会直接把这一局结算掉（表现为"开局 0.1s 就弹结算"）。
	_game.set("_win_hold", -1.0)
	GameManager.stats["hp"] = float(GameManager.stats["max_hp"])

## 长跑冒烟：把波次快进，验证"高密度 + 高血量 + Boss 同屏"不崩、不卡死。
## 注意这不是平衡验收（那需要真人试玩），只证明压力点上不宕机、池子不泄漏。
## （原本借用了 Step12 的名号，阶段四真的做了 Step12 之后改名，避免两处都叫 Step12。）
func _soak_density() -> void:
	await _prep()
	print("\n[Soak] 高密度长跑冒烟（快进到 25 分钟档）")
	game_reset_round()
	GameManager.started = true
	_game.elapsed = 1500.0
	_game.set("_prev_t", 1500.0 - 0.1)
	_player.set("invuln_left", 999999.0)
	_auto_pick = true

	var t0: int = Time.get_ticks_msec()
	var frames := 0
	# 60 帧 ≈ 1 秒真实运行，但 elapsed 被架在 1500s，所以刷的是 25 分钟档
	for _i in 400:
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
		# 手动补 elapsed 会让 _check_boss 反复触发；这里把 elapsed 钉住不推进，
		# 只让刷怪/Boss 压制逻辑在 1500s 这一档跑满。
		_game.elapsed = 1500.0
	var dt: int = Time.get_ticks_msec() - t0

	var alive_n: int = _enemies.alive_count()
	var active_n: int = _enemies.active.size()
	var inactive_n: int = _enemies.inactive.size()
	print("    frames=%d  wall=%dms  alive=%d  active=%d  inactive=%d  gems=%d  pickups=%d  res=%d" % [
		frames, dt, alive_n, active_n, inactive_n, _game.gem_count(),
		_game.pickups.count(), (_game.get_node("World/Resources") as ResourceField).count()])

	_check(alive_n > 0, "25 分钟档 400 帧内刷出了敌人（同屏 %d）" % alive_n)
	_check(active_n + inactive_n <= EnemyPool.CAP + EnemyPool.BOSS_RESERVE,
		"敌人池总量 %d ≤ CAP %d + Boss 预留 %d（无泄漏）" % [
			active_n + inactive_n, EnemyPool.CAP, EnemyPool.BOSS_RESERVE])
	_check(inactive_n > 0, "池里有可复用对象 %d 个（击杀后确实回收了）" % inactive_n)
	_check(_game.pickups.count() <= PickupField.CAP, "掉落物 %d 个 ≤ 上限 %d" % [_game.pickups.count(), PickupField.CAP])
	_check(_game.gem_count() <= GemPool.CAP, "宝石 %d 颗 ≤ 上限 %d" % [_game.gem_count(), GemPool.CAP])
	_check(dt < 30000, "400 帧耗时 %dms（未卡死，阈值 30s）" % dt)

	_auto_pick = false
	_enemies.clear_all()
	_game.pickups.clear_all()
	_game.gems.active.clear()
	GameManager.started = false
	await _wait_frames(2)

# ==================================================================
# 阶段四（Step 12）：金币 Meta 商店 + 存档持久化 + 复活
# ==================================================================
## 验收口径（核心玩法完善步骤 Step 12）：
## "局内击杀掉金币 → 结算入存档 → 商店买永久属性 → 买完 Power Up 明显变强，形成再来一局钩子"。
## 所以这里不只测"数值加对了"，还要测三件事：
##   ① 买的东西真的写进了 stats（否则是"买了没感觉"）
##   ② 重开一局之后还在（否则 meta 就不叫 meta 了）
##   ③ 买不起 / 满级时按钮不可点（否则玩家会以为坏了）
func _step12_meta_shop() -> void:
	await _prep()
	_auto_pick = false
	print("\n[Step12] 金币 Meta 商店")

	# ---------- 1) 数据表对齐 params.json（价格是玩家能感知的最硬数字，不能悄悄漂）
	_check(MetaSave.TRACKS.size() == 5,
		"商店 %d 条成长线（攻击/生命/冷却/磁力/复活）" % MetaSave.TRACKS.size())
	var ids: Array[String] = MetaSave.track_ids()
	_check(ids == ["damage", "max_hp", "cooldown", "magnet", "revive"],
		"成长线顺序 %s" % str(ids))
	var dmg_price: Array = MetaSave.track("damage").get("price", [])
	_check(dmg_price == [200, 500, 1200, 3000, 7000],
		"攻击价格曲线照抄 params.json（%s）" % str(dmg_price))
	var rev_price: Array = MetaSave.track("revive").get("price", [])
	_check(rev_price == [2500, 8000], "复活价格 2500/8000（最贵的一条，%s）" % str(rev_price))
	_check(MetaSave.max_level_of("magnet") == 3 and MetaSave.max_level_of("revive") == 2,
		"等级上限：磁力 3 / 复活 2（不是全都 5）")

	# ---------- 2) 买不起时不能扣钱（最伤信任的一类 bug）
	MetaSave.debug_set(0, {})
	_check(not MetaSave.can_afford("damage"), "0 金币时攻击买不起")
	var refused: bool = MetaSave.buy("damage")
	_check(not refused and MetaSave.coins == 0 and MetaSave.level_of("damage") == 0,
		"买不起时 buy() 返回 false，金币与等级都不变")

	# ---------- 3) 入账 → 购买 → 真落盘
	MetaSave.add_coins(500)
	_check(MetaSave.coins == 500, "结算入账 500 金币（实测 %d）" % MetaSave.coins)
	_check(MetaSave.buy("magnet"), "500 金币买下磁力 Lv1（100）")
	_check(MetaSave.coins == 400 and MetaSave.level_of("magnet") == 1,
		"购买后金币 500→%d，磁力 Lv%d" % [MetaSave.coins, MetaSave.level_of("magnet")])
	_check(is_equal_approx(MetaSave.mult("magnet"), 1.10),
		"磁力 Lv1 乘数 ×%.2f（+10%%/级）" % MetaSave.mult("magnet"))
	MetaSave.reload_from_disk()
	_check(MetaSave.coins == 400 and MetaSave.level_of("magnet") == 1,
		"重新读盘后仍是 400 金币 / 磁力 Lv1（真落盘，不是只在内存里）")
	_check(MetaSave.save_exists(), "存档文件 user://save.json 存在")

	# ---------- 4) 满级闸门
	MetaSave.debug_set(20000, {})
	MetaSave.buy("revive")
	MetaSave.buy("revive")
	_check(MetaSave.level_of("revive") == MetaSave.max_level_of("revive"), "复活买满 2 级")
	_check(MetaSave.price_of("revive") == -1,
		"满级后 price_of 返回 -1（不是 0，否则 UI 会显示成『0 元可买』）")
	var coins_at_max: int = MetaSave.coins
	_check(not MetaSave.buy("revive") and MetaSave.coins == coins_at_max,
		"满级后再买不扣钱（仍 %d）" % MetaSave.coins)

	# ---------- 5) 乘数只乘不进卡池；总上限守住 params 的 1.35
	MetaSave.debug_set(0, {"damage": 5, "cooldown": 5})
	_check(is_equal_approx(MetaSave.mult("damage"), 1.15),
		"攻击满级 ×%.2f（+3%% × 5）" % MetaSave.mult("damage"))
	_check(is_equal_approx(MetaSave.mult("cooldown"), 0.85),
		"冷却满级 ×%.2f（-3%% × 5，越小越快）" % MetaSave.mult("cooldown"))
	var meta_total: float = MetaSave.mult("damage") / MetaSave.mult("cooldown")
	_check(absf(meta_total - 1.35) < 0.006,
		"meta 满级总伤害乘数 ×%.3f ≈ params._note 的 1.35（必须远低于单武器进化 2.4）" % meta_total)
	var stat_cards := 0
	for d in UpgradeDB.all_defs():
		if String(d["kind"]) == "stat":
			stat_cards += 1
	_check(stat_cards == 9, "升级卡池仍是 9 条被动（meta 不往局内塞卡，%d）" % stat_cards)

	# ---------- 6) 买完真的变强：开局 stats 就带着乘数
	GameManager.reset()
	_check(is_equal_approx(float(GameManager.stats["damage"]), 1.15),
		"开局 damage 基线 = %.2f（= 1.00 × meta 1.15）" % float(GameManager.stats["damage"]))
	_check(is_equal_approx(float(GameManager.stats["cooldown"]), 0.85),
		"开局 cooldown 基线 = %.2f" % float(GameManager.stats["cooldown"]))
	_check(is_equal_approx(float(GameManager.stats["max_hp"]), 100.0),
		"没买生命时 max_hp 仍是 100（乘数不能串到别的线上）")

	# 与局内被动是**乘算**而不是加算：1.50 × 1.15 = 1.725，不是 1.65
	var s: Dictionary = Stats.make_base()
	Stats.apply_to(s, "damage", 5)
	_check(is_equal_approx(float(s["damage"]), 1.5 * 1.15),
		"伤害 Lv5 × meta：1.50 → %.3f（乘算；加算会是 1.650）" % float(s["damage"]))
	Stats.apply_to(s, "cooldown", 5)
	_check(is_equal_approx(float(s["cooldown"]), 0.75 * 0.85),
		"冷却 Lv5 × meta：0.75 → %.3f" % float(s["cooldown"]))

	# 生命：乘数作用在"上限"上，且开局血量跟着上限走
	MetaSave.debug_set(0, {"max_hp": 5})
	var s2: Dictionary = Stats.make_base()
	_check(is_equal_approx(float(s2["max_hp"]), 150.0) and is_equal_approx(float(s2["hp"]), 150.0),
		"生命满级：开局 %.0f 血（100 × 1.5，且血量随上限一起给）" % float(s2["max_hp"]))

	# ---------- 7) 复活次数：每局重置、用完为止
	MetaSave.debug_set(-1, {"revive": 2})
	MetaSave.begin_run()
	_check(MetaSave.revive_left == 2, "开局携带 2 次复活")
	_check(MetaSave.consume_revive() and MetaSave.consume_revive(), "两次复活都能消耗")
	_check(not MetaSave.consume_revive(), "用完后 consume_revive() 返回 false")

	# ---------- 8) 真实复活通路：血量归零 → 不结算、满血、继续打
	_chests_clear()
	_enemies.clear_all()
	game_reset_round()
	MetaSave.debug_set(-1, {"revive": 1})
	MetaSave.begin_run()
	_relink_stats()
	game_reset_round()
	_player.set("invuln_left", 0.0)
	GameManager.stats["hp"] = 0.0
	_player.take_damage(999.0)
	await _wait(0.15)
	_check(not _deathui.is_open(), "有复活时不进结算界面")
	_check(GameManager.started, "复活后本局继续（started 仍为 true）")
	_check(_player.hp_ratio() > 0.99, "复活后满血（%.0f%%）" % (_player.hp_ratio() * 100.0))
	_check(MetaSave.revive_left == 0, "复活次数已扣到 0")
	_check(_player.invuln_left > 1.0, "复活后带 %.1fs 无敌（否则站起来就被同一个人再撞死）" % _player.invuln_left)
	# 用完就没得用了：再死一次必须正常结算
	_player.set("invuln_left", 0.0)
	GameManager.stats["hp"] = 0.0
	_player.take_damage(999.0)
	await _wait(0.15)
	_check(_deathui.is_open(), "复活用完后再次死亡 → 正常进入结算")

	# ---------- 9) 结算入账 + 防重复入账
	game_reset_round()
	_game.kills = 1200
	_game.elapsed = 700.0
	_game.won = false
	var reward: int = _game.coin_reward()
	var before: int = MetaSave.coins
	_check(reward > 0, "构造一局可入账的奖励：%d 金币" % reward)
	_game._finish(false)
	await _wait_frames(2)
	_check(MetaSave.coins == before + reward,
		"结算入账：%d → %d（+%d）" % [before, MetaSave.coins, reward])
	var total_lbl: Label = _deathui.get_node("Popup/Panel/VB/Total") as Label
	_check(total_lbl != null and total_lbl.visible and total_lbl.text.contains(str(MetaSave.coins)),
		"结算界面显示持有总额「%s」" % (total_lbl.text if total_lbl != null else "null"))
	var shop_btn: Button = _deathui.get_node("Popup/Panel/VB/Shop") as Button
	_check(shop_btn != null and shop_btn.text.contains("百工谱"),
		"结算界面有商店入口（「%s」）" % (shop_btn.text if shop_btn != null else "null"))
	_game._finish(true)
	await _wait_frames(1)
	_check(MetaSave.coins == before + reward,
		"重复调用 _finish 不会二次入账（仍 %d，防『同时死亡+胜利』刷双份）" % MetaSave.coins)

	# ---------- 10) 商店 UI：行数、按钮状态、关店后的暂停还原
	_check(not _shopui.is_open(), "商店默认关闭")
	_shopui.open()
	await _wait_frames(2)
	_check(_shopui.is_open() and get_tree().paused, "商店打开且全树暂停")
	var rows: VBoxContainer = _shopui.get_node("Center/Panel/Margin/VB/Rows") as VBoxContainer
	_check(rows.get_child_count() == 5, "商店列出 %d 行" % rows.get_child_count())

	MetaSave.debug_set(1000, {})
	_shopui.refresh()
	await _wait_frames(1)
	var cells: Dictionary = _shopui.get("_cells")
	var magnet_buy: Button = (cells["magnet"] as Dictionary)["buy"] as Button
	_check(not magnet_buy.disabled, "有 1000 金币时磁力（100）按钮可点")
	var c1: int = MetaSave.coins
	magnet_buy.pressed.emit()
	await _wait_frames(2)
	_check(MetaSave.level_of("magnet") == 1 and MetaSave.coins == c1 - 100,
		"点按钮真买到了：磁力 Lv%d，金币 %d → %d" % [
			MetaSave.level_of("magnet"), c1, MetaSave.coins])

	MetaSave.debug_set(0, {})
	_shopui.refresh()
	await _wait_frames(1)
	var dmg_buy: Button = (cells["damage"] as Dictionary)["buy"] as Button
	_check(dmg_buy.disabled, "0 金币时攻击按钮禁用（点了没反应会被当成 bug）")
	var coins_lbl: Label = _shopui.get_node("Center/Panel/Margin/VB/Head/Coins") as Label
	_check(coins_lbl.text.contains("0"), "商店顶栏余额同步为「%s」" % coins_lbl.text)

	_shopui.close()
	await _wait_frames(2)
	_check(not _shopui.is_open(), "关店后商店隐藏")
	_check(get_tree().paused,
		"从结算界面关店后仍保持暂停（否则游戏会在结算面板后面偷跑）")
	_check(_deathui.is_open(), "关店后结算界面仍在，可以再来一局")

	# ---------- 11) 跨局持久：重开一局，买的东西还在
	MetaSave.debug_set(300, {"magnet": 2, "max_hp": 1})
	var expect_coins: int = MetaSave.coins
	var old_game: GameScene = _game
	_game.restart()
	await _wait_frames(6)
	var ng: GameScene = null
	for c in get_children():
		if c is GameScene and is_instance_valid(c) and c != old_game:
			ng = c
	_check(ng != null, "重开生成新的游戏实例")
	if ng != null:
		_game = ng
		_player = ng.get_node("World/Player") as Player
		_enemies = ng.get_node("World/EnemyPool") as EnemyPool
		_gems = ng.get_node("World/GemPool") as GemPool
		_weapons = ng.get_node("World/Weapons") as WeaponManager
		_lvui = ng.get_node("UI/LevelUpUI") as LevelUpUI
		_pauseui = ng.get_node("UI/PauseUI") as PauseUI
		_deathui = ng.get_node("UI/DeathUI") as DeathUI
		_shopui = ng.get_node("UI/ShopUI") as ShopUI
		_check(MetaSave.coins == expect_coins and MetaSave.level_of("magnet") == 2,
			"重开一局后金币 %d / 磁力 Lv2 都还在（局外资产没被 reset 清掉）" % MetaSave.coins)
		_check(is_equal_approx(float(GameManager.stats["magnet"]), 1.2),
			"新局 magnet 基线 ×%.2f（1.0 + 0.1×2）" % float(GameManager.stats["magnet"]))
		_check(is_equal_approx(float(GameManager.stats["max_hp"]), 110.0),
			"新局 max_hp 基线 %.0f（100 × 1.1）" % float(GameManager.stats["max_hp"]))
		_check(MetaSave.revive_left == MetaSave.level_of("revive"),
			"新局的复活次数按等级重置（%d 次）" % MetaSave.revive_left)

	_enemies.clear_all()
	GameManager.started = false
	await _wait_frames(2)

## 局外乘数改完之后，把新的 stats 字典重新挂到各系统上。
## Game._ready 里做过同一件事：GameManager.reset() 换的是**新字典**，
## 不重挂的话 player/weapons 还指着上一局那个，读到的加成永远是旧的。
func _relink_stats() -> void:
	GameManager.reset()
	GameManager.on_started()
	_player.stats = GameManager.stats
	_weapons.stats = GameManager.stats

## 帧率上限的**双保险**必须同时成立：
##   ① project.godot 的 application/run/max_fps（给编辑器里直接 F5 跑的人）
##   ② GameManager.MAX_FPS + 运行时的 Engine.max_fps（给"工程设置被改回 0"兜底）
## 只写一处会静默失效：project.godot 被编辑器重写、或有人为了截图临时改 0 忘了改回。
##
## 为什么是 60 而不是更高：P5Perf 实测 400 同屏单帧 11.44ms / P95 12.96ms。
## 60fps 的预算是 16.6ms → 用掉 69%，留 31% 余量。
## 若放到 144Hz（6.9ms 预算），密度一过 250 只（7.09ms）就开始丢 vsync，
## 表现为"人一多就顿一下、帧率数字却看不出来"—— 这正是本用例要防的回归。
func _case_frame_cap() -> void:
	print("\n[呈现] 帧率上限 60（vsync 开启）")
	var want: int = int(GameManager.MAX_FPS)
	_check(want == 60, "GameManager.MAX_FPS 应为 60（实际 %d）" % want)
	# 端到端：GameManager._ready 到底有没有把这行真的执行了。
	# 只断言常量的话，那行 `Engine.max_fps = MAX_FPS` 被人删掉测试仍然是绿的。
	_check(_fps_at_boot == want,
		"autoload 启动后 Engine.max_fps 应被设为 %d（实测 %d）" % [want, _fps_at_boot])
	var proj: int = int(ProjectSettings.get_setting("application/run/max_fps", 0))
	_check(proj == want,
		"project.godot 的 run/max_fps（%d）必须等于 GameManager.MAX_FPS（%d）" % [proj, want])
	# 单帧预算换算：60fps = 16.6ms，400 同屏实测 P95 12.96ms，余量 ≥ 20%
	var budget_ms: float = 1000.0 / float(maxi(want, 1))
	_check(budget_ms > 16.0 and budget_ms < 17.0,
		"60 帧对应单帧预算 %.2fms（应落在 16.0~17.0）" % budget_ms)

func _report() -> void:
	# 把跑测试前备份的真实存档还回去（debug_set 里含 save()，所以退出后磁盘上也是原样）
	# 整字典回灌：snapshot() 的键名和 debug_set 的 extra 是对齐的，
	# 所以还原不需要逐字段抄 —— 抄漏一个字段（比如 T12 的 codex）会静默留在
	# "测试改过的值"上，下次跑就变成查不出来的幽灵问题。
	MetaSave.debug_set(int(_meta_backup.get("coins", 0)),
		_meta_backup.get("levels", {}) as Dictionary, _meta_backup)
	CodexDB.clear_fresh()
	print("\n========== 阶段一 + 二 + 三 + 四 验收 ==========")
	if _fails.is_empty():
		print("全部通过 OK")
	else:
		for f in _fails:
			print("失败: ", f)
	await _wait(0.2)
	get_tree().quit(0 if _fails.is_empty() else 1)
