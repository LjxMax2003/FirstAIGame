extends Node

# ============================================================================
# v7 产品壳验收（T4 / L-06）：设置面板 · 暂停菜单 · 结算出口 · 死因归纳
# ----------------------------------------------------------------------------
# 用法：godot --headless --path . res://tools/V7Shell.tscn
#
# 为什么要有这一份：
#   设置面板的失败方式是**静默的**——开关点下去变了个颜色，但没写盘；
#   下次启动一切照旧，玩家会以为"这游戏记不住我的设置"。
#   没有任何报错，也没有任何崩溃。这类 bug 只有断言能抓住。
#
# 断言口径（沿用 V5InGame 的规矩）：
#   期望值来自**外部事实**（磁盘上的文件内容、屏幕上的字），不是回读被测代码。
#   例如"设置落盘"这条，是重新 new 一个 FileAccess 去读 user://settings.cfg，
#   而不是再调一次 Settings.load_cfg() 然后跟自己比。
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"
const PAUSE_SCENE := "res://scenes/ui/PauseUI.tscn"

var _bad: Array[String] = []
var _ok := 0

# 存档/设置快照：跑测试不该抹掉玩家真实的铜钱与偏好
var _meta_backup: Dictionary = {}
var _set_backup: Array = []
## 引导标记也要备份：这份用例会推着开场和提示往前走，
## 不还原的话，跑一次测试就等于替玩家把首次引导"看过"了。
var _intro_backup := false
var _tips_backup: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	await get_tree().process_frame

	_meta_backup = MetaSave.snapshot()
	_set_backup = [Settings.fx_level, Settings.shake, Settings.tips]
	_intro_backup = MetaSave.intro_done
	_tips_backup = MetaSave.seen_tips.duplicate()

	print("\n===== v7 产品壳验收（T4 / L-06）=====")
	_case_settings_io()
	_case_fx_tiers()
	_case_meta_tips()
	await _case_settings_ui()
	await _case_pause_ui()
	await _case_menu()
	await _case_result()
	await _case_death_cause()
	await _case_intro()
	await _case_intro_gate()
	await _case_tips()

	print("\n---------- 汇总 ----------")
	if _bad.is_empty():
		print("全部通过 OK（%d 条断言）" % _ok)
	else:
		for f in _bad:
			print("失败: ", f)
	await get_tree().create_timer(0.2).timeout
	_restore()
	get_tree().quit(0 if _bad.is_empty() else 1)

func _restore() -> void:
	MetaSave.debug_set(int(_meta_backup.get("coins", 0)), _meta_backup.get("levels", {}) as Dictionary)
	MetaSave.intro_done = _intro_backup
	MetaSave.seen_tips = _tips_backup.duplicate()
	MetaSave.save()
	Settings.debug_set(int(_set_backup[0]), bool(_set_backup[1]), bool(_set_backup[2]))
	# 必须落盘：前面测过"坏 settings.cfg 也要能活下来"，那条用例往磁盘写了垃圾，
	# 不覆盖回去的话玩家下次启动会读到一份坏文件。
	Settings.save_cfg()

# ---------------------------------------------------------------- 断言基座
func _check(ok: bool, msg: String) -> void:
	if ok:
		_ok += 1
		print("  ok   ", msg)
	else:
		_bad.append(msg)
		print("  FAIL ", msg)

# ---------------------------------------------------------------- 1. 设置 IO
func _case_settings_io() -> void:
	print("\n[1] 设置落盘（user://settings.cfg）")
	Settings.debug_set(Settings.Fx.LOW, false, false)
	Settings.save_cfg()

	# 重新开一个 FileAccess 读回来，模拟"下次启动"
	_check(FileAccess.file_exists(Settings.PATH), "settings.cfg 真的写到了磁盘")
	var raw: String = ""
	var f: FileAccess = FileAccess.open(Settings.PATH, FileAccess.READ)
	if f != null:
		raw = f.get_as_text()
		f.close()
	# 手写 key=value 而不是 JSON：断言也按行读，等于替玩家验了一次"记事本能看懂"
	_check(raw.contains("fx_level=1"), "文件里 fx_level=1（低配）")
	_check(raw.contains("shake=0"), "文件里 shake=0")
	_check(raw.contains("tips=0"), "文件里 tips=0")
	_check(raw.begins_with("#"), "首行是注释（玩家打开能立刻知道这文件是什么）")

	# 内存态被改脏后重读，应当从磁盘恢复
	Settings.debug_set(Settings.Fx.FULL, true, true)
	Settings.load_cfg()
	_check(Settings.fx_level == Settings.Fx.LOW, "load_cfg 从磁盘恢复了 fx_level=LOW")
	_check(Settings.shake == false, "load_cfg 从磁盘恢复了 shake=false")
	_check(Settings.tips == false, "load_cfg 从磁盘恢复了 tips=false")

	# 文件被玩家改坏时必须能活下来，而不是开机崩
	var bad: FileAccess = FileAccess.open(Settings.PATH, FileAccess.WRITE)
	if bad != null:
		bad.store_line("这不是 key=value，也没有等号")
		bad.store_line("fx_level=abc")
		bad.close()
	Settings.load_cfg()
	_check(Settings.fx_level == Settings.Fx.FULL, "坏文件回落到默认档（fx_level=abc → FULL）")

# ---------------------------------------------------------------- 2. 特效档位
func _case_fx_tiers() -> void:
	print("\n[2] 特效档位只关装饰，不关判定读数")
	Settings.debug_set(Settings.Fx.FULL, true, true)
	var all_on := true
	for k in Settings.LOW_OFF:
		if not Settings.fx_on(k):
			all_on = false
	_check(all_on, "完整档下 LOW_OFF 里的全部为开")

	Settings.debug_set(Settings.Fx.LOW, true, true)
	var all_off := true
	for k in Settings.LOW_OFF:
		if Settings.fx_on(k):
			all_off = false
	_check(all_off, "低配档下 LOW_OFF 里的全部关闭")
	# 这两条是"低配档不能碰"的红线：花灯波纹标出"圈里在烧"，
	# 铜锣冲击环标出"这一下打到哪"。关掉等于让玩家在低配机上玩另一个规则的游戏。
	_check(Settings.fx_on("lantern_stream") == false, "低配确实关掉了花灯走马灯（装饰）")
	_check(Settings.fx_on("gong_ring") == true, "低配**保留**铜锣冲击环（判定读数）")
	_check(Settings.fx_on("halo_ripple") == true, "低配**保留**花灯波纹（判定读数）")
	Settings.debug_set(Settings.Fx.FULL, true, true)

# ---------------------------------------------------------------- 3. 引导标记
func _case_meta_tips() -> void:
	print("\n[3] 引导标记：mark_tip 判重 + 两种重置的边界")
	MetaSave.debug_set(300, {"damage": 2})
	MetaSave.intro_done = false
	MetaSave.seen_tips = {}

	_check(MetaSave.mark_tip("first_spike") == true, "首次标记返回 true（该显示）")
	_check(MetaSave.mark_tip("first_spike") == false, "同一 id 第二次返回 false（不显示）")
	_check(MetaSave.has_tip("first_spike"), "has_tip 记录了它")

	# 「重看开场」只清引导，铜钱与传承一点不动 —— 否则这就是一颗伪装成设置的重置按钮
	MetaSave.reset_intro()
	_check(MetaSave.coins == 300, "reset_intro 不动铜钱")
	_check(MetaSave.level_of("damage") == 2, "reset_intro 不动传承等级")
	_check(not MetaSave.has_tip("first_spike"), "reset_intro 清掉了提示标记")

	# 「清除存档」反过来：全部归零
	MetaSave.reset_progress()
	_check(MetaSave.coins == 0, "reset_progress 清零铜钱")
	_check(MetaSave.level_of("damage") == 0, "reset_progress 清零传承")

# ---------------------------------------------------------------- 4. 设置面板
func _case_settings_ui() -> void:
	print("\n[4] 设置面板（SettingsUI）")
	Settings.debug_set(Settings.Fx.FULL, true, true)
	var ui: SettingsUI = SettingsUI.new()
	add_child(ui)
	await get_tree().process_frame

	_check(not ui.is_open(), "面板默认关闭")
	ui.open()
	_check(ui.is_open(), "open() 之后可见")

	# 切到低配：点的是真 Button，走的是真回调
	var low_btn: Button = ui.get_node("Center/Panel/VB/FxRow").get_child(1) as Button
	low_btn.pressed.emit()
	_check(Settings.fx_level == Settings.Fx.LOW, "点「低配」后 Settings.fx_level = LOW")
	_check(not Settings.fx_on("phone_ghost"), "低配立刻生效（皮影残像关闭）")

	var high_btn: Button = ui.get_node("Center/Panel/VB/FxRow").get_child(0) as Button
	high_btn.pressed.emit()
	_check(Settings.fx_level == Settings.Fx.FULL, "点「完整」后切回 FULL")

	# 清除存档必须二次确认：不确认时一点都不能动
	MetaSave.debug_set(999, {"damage": 5})
	ui._on_clear_save()
	_check(ui.is_confirming(), "「清除存档」先弹确认")
	_check(MetaSave.coins == 999, "确认之前铜钱纹丝不动")

	# 取消路径
	ui._confirm.dismiss()
	_check(not ui.is_confirming(), "取消后确认层收起")
	_check(MetaSave.coins == 999, "取消后铜钱仍未变")

	# 确认路径
	ui._on_clear_save()
	ui._confirm._on_yes()
	_check(MetaSave.coins == 0, "确认后铜钱归零")
	_check(MetaSave.level_of("damage") == 0, "确认后传承归零")

	# 关面板时，确认层不能自己留着。但这里要分两步：
	# Esc 的第一下只应该"退出确认"，不该顺手把整个设置面板也关掉 ——
	# 否则玩家在确认框上误按一次 Esc，会连着丢掉两层，观感像"设置闪退了"。
	ui._on_clear_save()
	ui.close()
	_check(not ui.is_confirming(), "第一次 close 只收确认层")
	_check(ui.is_open(), "确认层收起后面板仍在（Esc 分两步退）")

	var closed_count := [0]
	ui.closed.connect(func() -> void: closed_count[0] += 1)
	ui.close()
	_check(closed_count[0] == 1, "再按一次才真的关闭，且发出一次 closed")
	_check(not ui.is_open(), "面板已关闭")
	ui.close()
	_check(closed_count[0] == 1, "已经关着时 close() 不重复发 closed 信号")

	ui.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 5. 暂停菜单
func _case_pause_ui() -> void:
	print("\n[5] 暂停菜单：设置 / 回主菜单（二次确认）")
	var packed: PackedScene = load(PAUSE_SCENE) as PackedScene
	_check(packed != null, "加载 PauseUI.tscn")
	if packed == null:
		return
	var p: PauseUI = packed.instantiate() as PauseUI
	add_child(p)
	await get_tree().process_frame

	_check(p.get_node_or_null("Popup/VB/Settings") != null, "暂停菜单有「设置」按钮")
	_check(p.get_node_or_null("Popup/VB/Menu") != null, "暂停菜单有「回主菜单」按钮")

	p.open()
	_check(p.is_open(), "暂停菜单能打开")
	_check(get_tree().paused, "打开时整棵树暂停")

	p._on_settings()
	_check(p._settings.is_open(), "点设置 → 设置面板叠在暂停菜单之上")
	_check(get_tree().paused, "开着设置时仍然是暂停的（不能在设置里被怪咬）")
	p._settings.close()
	_check(not p._settings.is_open(), "关设置后回到暂停菜单")

	# 回主菜单必须过确认：这一步丢掉整夜
	p._on_menu()
	_check(p._confirm.is_showing(), "点「回主菜单」先弹确认")
	_check(get_tree().paused, "确认期间仍是暂停的")
	_check(p.is_open(), "确认期间暂停菜单还在（没有先把自己关了）")
	p._confirm.dismiss()
	_check(not p._confirm.is_showing(), "取消后留在暂停菜单")
	_check(p.is_open(), "取消后没有被踢回主菜单")

	p.close()
	_check(not get_tree().paused, "关闭时解除暂停")

	p.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 6. 主菜单
func _case_menu() -> void:
	print("\n[6] 主菜单设置入口")
	var packed: PackedScene = load(MENU_SCENE) as PackedScene
	_check(packed != null, "加载 MainMenu.tscn")
	if packed == null:
		return
	var m: MainMenu = packed.instantiate() as MainMenu
	add_child(m)
	await get_tree().process_frame

	var btn: Button = m.get_node_or_null("Col/BtnSettings") as Button
	_check(btn != null, "主菜单有「设置」按钮")
	# 按钮顺序：设置必须夹在商店和退出之间，而不是排到"新游戏"上面
	if btn != null:
		_check(m.btn_new.get_index() < btn.get_index(), "设置排在「新游戏」之后")
		_check(btn.get_index() < m.btn_quit.get_index(), "设置排在「退出」之前")

	btn.pressed.emit()
	_check(m._settings != null and m._settings.is_open(), "点设置 → 主菜单开出设置面板")
	_check(not get_tree().paused, "主菜单里开设置不暂停树（本来就没在跑）")
	# 清档后主菜单摘要必须跟着变，否则玩家会看到"0 铜钱"上面还写着"手上 500"
	MetaSave.debug_set(500, {"damage": 1})
	m.refresh()
	_check(m.stats_label.text.contains("500"), "菜单摘要显示 500 铜钱")
	MetaSave.reset_progress()
	m.refresh()
	_check(m.stats_label.text.contains("0 枚"), "清档后摘要归零")
	_check(m.btn_load.disabled, "清档后「载入存档」置灰（这个按钮不能点了个寂寞）")

	m.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 7. 结算面板
func _case_result() -> void:
	print("\n[7] 结算面板：死因第二行 / 出口回主菜单")
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	_check(packed != null, "加载 Game.tscn")
	if packed == null:
		return
	var g: GameScene = packed.instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	g.set_process(false)

	# 失败局：死因在明细第一行
	g.death_ui.show_result(120, 376.0, 14, false, 30, 2, 0, 1, 30, "被围住")
	var info: String = (g.death_ui.get_node("Popup/Panel/VB/Info") as Label).text
	_check(info.contains("死因  被围住"), "失败结算里出现死因行")
	_check(info.begins_with("死因"), "死因是明细的第一行（扫一眼就能看到）")

	# 胜利局：没有"死因"这回事
	g.death_ui.show_result(900, 1800.0, 40, true, 200, 9, 3, 5, 200, "被围住")
	info = (g.death_ui.get_node("Popup/Panel/VB/Info") as Label).text
	_check(not info.contains("死因"), "胜利结算不显示死因（赢了不算死因）")

	# 老调用路径（不传 cause）不能崩，也不能冒出空死因
	g.death_ui.show_result(10, 60.0, 3, false, 5, 0, 0, 0)
	info = (g.death_ui.get_node("Popup/Panel/VB/Info") as Label).text
	_check(not info.contains("死因"), "不传 cause 时整行省略（而不是显示「死因  」）")

	_check((g.death_ui.get_node("Popup/Panel/VB/Quit") as Button).text == "回主菜单",
		"结算的退出按钮改为「回主菜单」")

	# 死在提示正播的那 4 秒里：木牌必须被收掉。
	# 它的时间轴是 PAUSABLE，结算一暂停就会把它冻在屏幕正中 —— 正好压住「回主菜单」。
	g.tips._enqueue("move", "拖拽移动，出手是自动的。")
	g.tips._show("move")
	_check(g.tips.is_showing(), "先把木牌点起来")
	g._finish(false, "被围住")
	_check(not g.tips.is_showing(), "结算时木牌被收掉（不会冻在结算面板前面）")

	get_tree().paused = false
	g.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 8. 死因归纳
func _case_death_cause() -> void:
	print("\n[8] 死因归纳的四类映射")
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		return
	var g: GameScene = packed.instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	g.set_process(false)

	# Boss 优先于一切：被 Boss 按死的时候，告诉你"潮涌期"是没用的信息
	g.elapsed = 610.0
	g.player.last_hit_source = &"boss"
	_check(g.death_cause() == "Boss 贴身按住", "boss 来源 → Boss 贴身按住")

	g.player.last_hit_source = &"mob"
	_check(g.death_cause() == "潮涌里被挤灭", "潮涌时段（610s 在一更潮涌里）→ 潮涌")

	# 潮涌以外的时间
	g.elapsed = 60.0
	_check(g.death_cause() == "被围住", "开场杂兵围死 → 被围住")

	g.player.last_hit_source = &"elite"
	_check(g.death_cause() == "被围住", "精英堵死也归到「被围住」这一档")

	g.player.last_hit_source = &""
	_check(g.death_cause() == "力竭而倒", "来源未知 → 力竭而倒（不编一个假的凶手）")

	get_tree().paused = false
	g.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 9. 三页开场
func _case_intro() -> void:
	print("\n[9] 三页开场（IntroUI）：只播一次、可跳过")
	for p in IntroUI.PAGES:
		_check(Art.tex(String(p["tex"])) != null, "开场插画可加载：%s" % String(p["tex"]).get_file())
	_check(IntroUI.PAGES.size() == 3, "开场正好 3 页")

	var intro: IntroUI = IntroUI.new()
	add_child(intro)
	await get_tree().process_frame
	_check(not intro.is_open(), "开场默认不显示")
	intro.open()
	_check(intro.is_open(), "open() 之后显示")
	_check(intro.page_index() == 0, "从第 1 页开始")

	var art: TextureRect = intro.get_node("Art")
	var next_btn: Button = intro.get_node("Next")
	_check(art.texture == Art.tex(Art.INTRO_1), "第 1 页用的是 intro_01")
	_check(next_btn.text == "继续", "非末页按钮是「继续」")

	# 版面几何：页码 / 按钮 / 文案三层不许互相压。
	# 这几条是为"页码压在按钮头上"那个真 bug 补的 —— 单看代码里两行 offset 都是
	# 合理的数，只有把两个矩形求交才看得出来。
	await get_tree().process_frame
	var idx: Label = intro.get_node("Index")
	var line: Label = intro.get_node("Line")
	var r_idx: Rect2 = idx.get_global_rect()
	var r_btn: Rect2 = next_btn.get_global_rect()
	var r_line: Rect2 = line.get_global_rect()
	_check(not r_idx.intersects(r_btn), "页码不压按钮（页码底 %.0f / 按钮顶 %.0f）"
		% [r_idx.end.y, r_btn.position.y])
	_check(not r_line.intersects(r_idx), "文案不压页码")
	_check(r_btn.end.y <= intro.get_viewport().get_visible_rect().size.y, "按钮不出屏幕下沿")
	intro.next()
	_check(art.texture == Art.tex(Art.INTRO_2), "第 2 页换成 intro_02")
	intro.next()
	_check(art.texture == Art.tex(Art.INTRO_3), "第 3 页换成 intro_03")
	_check(next_btn.text == "开始这一夜", "末页按钮改为「开始这一夜」")

	# 末页再按 = 开始这一夜：发 finished 并把"看过了"落盘
	var done := [0]
	intro.finished.connect(func() -> void: done[0] += 1)
	intro.next()
	_check(done[0] == 1, "末页继续会发出 finished")
	_check(not intro.is_open(), "播完自动收起")
	_check(MetaSave.intro_done, "播完把「看过开场」写进存档")
	intro.queue_free()
	await get_tree().process_frame

	# 跳过同样算看过 —— 否则下次还会糊一遍，那是打断而不是提醒
	MetaSave.intro_done = false
	var intro2: IntroUI = IntroUI.new()
	add_child(intro2)
	await get_tree().process_frame
	intro2.open()
	intro2.skip_all()
	_check(MetaSave.intro_done, "「跳过」也算看过")
	_check(not intro2.is_open(), "跳过后立即收起")
	intro2.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 10. 开场闸门（主菜单）
func _case_intro_gate() -> void:
	print("\n[10] 主菜单：首局才播开场")
	var packed: PackedScene = load(MENU_SCENE) as PackedScene
	if packed == null:
		return
	var m: MainMenu = packed.instantiate() as MainMenu
	add_child(m)
	await get_tree().process_frame

	var intents: Array = []
	MetaSave.intro_done = false

	# ① 没看过开场 + 没有测试钩子 → 先播开场，**不**切场景
	m._on_new_game()
	_check(m._intro != null and m._intro.is_open(), "首局点「新游戏」先播开场")
	_check(intents.is_empty(), "开场没播完之前不切场景")

	# ② 播完之后才真的开局。这里才装上钩子，是为了让 _leave 走"只回报意图"的分支，
	#    否则测试会把整棵树切到 Game.tscn，用例当场死掉。
	m.intent_hook = func(kind: String, arg: String) -> void: intents.append([kind, arg])
	var guard := 0
	while m._intro != null and m._intro.is_open() and guard < 10:
		m._intro.next()
		guard += 1
	_check(guard < 10, "开场能被翻完（%d 次继续）" % guard)
	_check(intents.size() == 1, "看完开场后发出一次离开菜单的意图")
	if intents.size() == 1:
		_check(String(intents[0][0]) == "scene" and String(intents[0][1]) == MainMenu.GAME_SCENE,
			"意图是切到 Game.tscn")
	_check(MetaSave.intro_done, "看过了")

	# ③ 第二局不再播
	m._on_new_game()
	_check(m._intro == null, "第二局点「新游戏」不再播开场")

	m.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- 11. 情境提示
func _case_tips() -> void:
	print("\n[11] 五条情境提示（TipUI）：一次性 / 4 秒 / 木牌")
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		return
	MetaSave.seen_tips = {}
	var g: GameScene = packed.instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	g.set_process(false)

	_check(g.tips != null, "Game 里挂了提示层")
	if g.tips == null:
		g.queue_free()
		return
	# 低于升级卡(10)：木牌不该盖住玩家正在做的三选一
	_check(g.tips.layer < 10, "提示层压在升级卡之下（layer %d < 10）" % g.tips.layer)
	_check(TipUI.TIPS.size() == 5, "正好 5 条提示")
	# 时间轴自己推进，测试才能确定性地验 4 秒
	g.tips.set_process(false)

	# ① 首次移动
	g.player.moving = true
	g.tips.scan()
	_check(g.tips.is_showing(), "首次移动 → 弹出提示")
	_check(g.tips.current_text() == "拖拽移动，出手是自动的。", "文案是「拖拽移动」（实测「%s」）" % g.tips.current_text())
	_check(MetaSave.has_tip("move"), "已记为看过")

	# ② 只出现一次：再扫一遍不会重播
	g.tips.advance(TipUI.HOLD + TipUI.FADE * 2.0 + 0.05)
	_check(not g.tips.is_showing(), "4 秒后自己走掉")
	g.player.moving = true
	g.tips.scan()
	_check(not g.tips.is_showing(), "同一条提示不会再出现第二次")

	# ③ 4 秒之前不能提前消失
	g.player.xp_total = 1
	g.tips.scan()
	_check(g.tips.current_text() == "灯花是经验，靠近会自动拾取。", "第二个条件成立 → 换成灯花提示")
	g.tips.advance(TipUI.HOLD - 0.1)
	_check(g.tips.is_showing(), "不到 4 秒仍在显示")

	# ④ 排队：两条同时成立时，第二条等第一条播完，不互相盖掉
	g.tips.clear()
	g.player.level = 2
	g.player.stats["max_hp"] = 100.0
	g.player.stats["hp"] = 40.0
	g.tips.scan()
	_check(g.tips.current_text() == "三选一，决定这一夜的构筑。", "升级提示先播（按 TIPS 顺序）")
	_check(g.tips.queued_count() == 1, "低血提示排在后面（已排 %d）" % g.tips.queued_count())
	g.tips.advance(TipUI.HOLD + TipUI.FADE * 2.0 + 0.05)
	_check(g.tips.current_text() == "震吼：冲刺 + 清开一圈，25 秒一次。", "第一条播完接着播第二条")

	# ⑤ 关掉设置里的提示：条件成立也既不弹、也不记账
	# 记账这一条特别重要 —— 记了就等于"这条提示永远不再出现"，
	# 而玩家当初关提示只是嫌吵，不是放弃引导。
	g.tips.clear()
	g.chests_opened = 1
	MetaSave.seen_tips.erase("chest")
	Settings.debug_set(Settings.Fx.FULL, true, false)
	g.tips.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not g.tips.is_showing() and g.tips.queued_count() == 0, "关掉提示后一条都不弹")
	_check(not MetaSave.has_tip("chest"), "关掉提示时也不记账")
	Settings.debug_set(Settings.Fx.FULL, true, true)
	g.tips.set_process(false)

	# ⑥ 宝箱提示靠 Game.chests_opened 这个真事件（宝箱不是持续状态）
	g.tips.clear()
	g.chests_opened = 0
	g.tips.scan()
	_check(not g.tips.is_showing(), "没开过箱时不提示")
	g.chests_opened = 1
	g.tips.scan()
	_check(g.tips.current_text() == "满级武器 + 对应被动 = 进化。", "开过箱 → 进化提示")

	get_tree().paused = false
	g.queue_free()
	await get_tree().process_frame

