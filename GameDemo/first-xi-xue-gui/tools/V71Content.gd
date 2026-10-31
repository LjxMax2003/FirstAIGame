extends Node

# ============================================================================
# v7.1 内容纵深验收（T9–T13）
# ----------------------------------------------------------------------------
# 用法：godot --headless --path . res://tools/V71Content.tscn
#
# 为什么单开一份而不是塞进 V7Shell：
#   V7Shell 管的是"产品壳"（设置/暂停/结算），失败意味着**玩家卡住**；
#   这份管的是"内容纵深"（角色/图鉴/置景/演出），失败意味着**内容没接上**。
#   两类问题的处理人不同，混在一张报告里会让"红了"这件事失去定位能力。
#
# 断言口径（沿用 V5InGame / V7Shell 的规矩）：
#   期望值来自外部事实（贴图文件名、世界坐标几何、存档文件内容），
#   不回读被测代码的中间状态。
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"
const VIEW_W := 720.0
const VIEW_H := 1280.0

var _bad: Array[String] = []
var _ok := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	await get_tree().process_frame

	print("\n===== v7.1 内容纵深验收（T9–T13）=====")
	_case_art_paths()
	await _case_characters()
	_case_street()
	await _case_enemy_frames()
	await _case_codex()
	await _case_boss_phases()
	await _report()

# ---------------------------------------------------------------- 公共
func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
		_ok += 1
	else:
		print("  FAIL ", msg)
		_bad.append(msg)

func _report() -> void:
	await get_tree().process_frame
	print("\n---------- 汇总 ----------")
	if _bad.is_empty():
		print("全部通过 OK（%d 条断言）" % _ok)
		get_tree().quit(0)
	else:
		for b in _bad:
			print("失败: ", b)
		get_tree().quit(1)

# ---------------------------------------------------------------- 资源守卫
## Art.ALL_PATHS 是"换图漏接"的唯一防线：新增资源不登记，就等于允许静默漏接。
## 这里只验**本批新增**的那 20 条，SmokeTest 负责全量。
func _case_art_paths() -> void:
	print("\n[1] 资源守卫：v7.1 新增资源全部可 load 且已登记")
	var added: Array[String] = [
		Art.STALL_FORGE, Art.STALL_LANTERN, Art.STALL_PAPER, Art.STALL_SHADOW, Art.STALL_SUGAR,
		Art.ARCHWAY, Art.OLD_STAGE, Art.LANTERN_PILLAR,
		Art.CHAR_FORGE, Art.CHAR_LANTERN, Art.CHAR_PAPER, Art.CHAR_SHADOW, Art.CHAR_SUGAR,
		Art.CODEX_BG, Art.UI_SEAL,
		Art.BOSS_MASK_GLOW, Art.BOSS_LANTERN_DRAIN, Art.BOSS_WARNING_RING,
	]
	var missing_reg: Array[String] = []
	var missing_load: Array[String] = []
	for p in added:
		if not (p in Art.ALL_PATHS):
			missing_reg.append(p.get_file())
		if Art.tex(p) == null:
			missing_load.append(p.get_file())
	_check(missing_reg.is_empty(), "18 条新增路径全部登记进 ALL_PATHS%s"
		% ("" if missing_reg.is_empty() else "（漏了 %s）" % [missing_reg]))
	_check(missing_load.is_empty(), "18 条新增路径都能 load 成 Texture2D%s"
		% ("" if missing_load.is_empty() else "（缺 %s）" % [missing_load]))

# ---------------------------------------------------------------- T9 角色选择
## 三条互相独立的线，失败的样子完全不同：
## ① 数据面：五个匠人、五把不同的起始武器、**一个属性字段都没有**（红线）；
## ② 解锁面：门槛读的是原始计数，改完计数立刻翻转 —— 不依赖存档里的布尔表，
##            否则"改了解锁规则对老档不生效"这种问题永远测不出来；
## ③ 手感面：起始武器在前三次三选一里必出，用满三次后不再强塞。
func _case_characters() -> void:
	print("\n[4] T9 角色选择（五匠人）")
	var all: Array[Dictionary] = CharacterDB.all()
	_check(all.size() == 5, "五匠人齐（%d）" % all.size())

	var weapons: Array[String] = []
	var bad_weapon: Array[String] = []
	var bad_svg: Array[String] = []
	for e in all:
		var w: String = String(e.get("weapon", ""))
		weapons.append(w)
		if not WeaponDB.has_weapon(w):
			bad_weapon.append("%s→%s" % [e["id"], w])
		if Art.tex(String(e.get("svg", ""))) == null:
			bad_svg.append(String(e["id"]))
	_check(bad_weapon.is_empty(), "每个匠人的起始武器都是真实武器%s"
		% ("" if bad_weapon.is_empty() else "（坏 %s）" % [bad_weapon]))
	_check(bad_svg.is_empty(), "五个匠人立绘都能 load 成 Texture2D%s"
		% ("" if bad_svg.is_empty() else "（缺 %s）" % [bad_svg]))
	var uniq: Dictionary = {}
	for w in weapons:
		uniq[w] = true
	_check(uniq.size() == 5, "五把起始武器互不相同（%s）" % [weapons])

	# ① 红线：只有起始武器不同，没有属性差。
	# 【为什么用白名单】黑名单只能挡住"我已经想到的那几个字段名"，
	# 下一个人写个 atk_bonus 就绕过去了。白名单外的一切字段都必须显式报错。
	var allowed: Array[String] = ["id", "name", "svg", "weapon", "role", "line", "unlock", "aux"]
	var extra: Array[String] = []
	for e in all:
		for k in e.keys():
			var ks := String(k)
			if not (ks in allowed) and not (ks in extra):
				extra.append(ks)
	_check(extra.is_empty(), "匠人数据里没有属性字段（白名单只有 %d 项）%s"
		% [allowed.size(), "" if extra.is_empty() else "（多出 %s）" % [extra]])
	# 反过来确认基线确实共用同一份：五个 id 走 Stats.make_base() 得到的血/速完全一致
	var base_hp: float = float(Stats.make_base()["max_hp"])
	_check(CharacterDB.start_level("lantern") == 2 and CharacterDB.start_level("shadow") == 2
		and CharacterDB.start_level("forge") == 1 and CharacterDB.start_level("paper") == 1,
		"辅助档（花灯/皮影）起始 Lv2，其余 Lv1")
	_check(is_equal_approx(base_hp, 100.0),
		"所有匠人共用同一份 Stats 基线（max_hp %.0f，没有角色加成）" % base_hp)

	# ② 解锁门槛：改原始计数 → 立刻翻转。存档先备份，测完原样还回去。
	var backup: Dictionary = MetaSave.snapshot()
	MetaSave.debug_set(0, {}, {
		"won_runs": 0, "best_time": 0.0, "mini_boss_kills": 0,
		"coins_total": 0, "char_id": "",
	})
	var locked: Array[String] = []
	for e in all:
		if not CharacterDB.is_unlocked(String(e["id"])):
			locked.append(String(e["id"]))
	_check(locked.size() == 4 and not ("forge" in locked),
		"全零存档下只默认开放铁花匠（锁着 %s）" % [locked])
	_check(CharacterDB.progress_text("lantern") != "" and CharacterDB.current_id() == "forge",
		"锁着的匠人给出进度文案，当前角色回落铁花匠")

	MetaSave.debug_set(0, {}, {
		"won_runs": 1, "best_time": 600.0, "mini_boss_kills": 3,
		"coins_total": 5000, "char_id": "",
	})
	var still_locked: Array[String] = []
	for e in all:
		if not CharacterDB.is_unlocked(String(e["id"])):
			still_locked.append(String(e["id"]))
	_check(still_locked.is_empty(), "四个门槛各自达标后全部解锁（不用重开档）%s"
		% ("" if still_locked.is_empty() else "（仍锁 %s）" % [still_locked]))

	# 持久化 + 回落：写进存档的 char_id 必须被读回来；写个不存在的 id 必须回落
	MetaSave.set_character("lantern")
	_check(CharacterDB.current_id() == "lantern" and CharacterDB.starting_weapon() == "halo"
		and CharacterDB.start_level() == 2,
		"选中灯彩匠后：当前角色=lantern / 起始武器=halo / Lv2")
	MetaSave.set_character("no_such_artisan")
	_check(CharacterDB.current_id() == "forge", "存档里是无效 id 时回落铁花匠（不会开不了局）")
	MetaSave.debug_set(int(backup["coins"]), backup["levels"], {
		"won_runs": int(backup["won_runs"]), "best_time": float(backup["best_time"]),
		"mini_boss_kills": int(backup["mini_boss_kills"]),
		"coins_total": int(backup["coins_total"]), "char_id": String(backup["char_id"]),
	})

	# ③ 起始武器保底：真开一局来测，不手搓 GameManager 状态
	var g: GameScene = (load(GAME_SCENE) as PackedScene).instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	g.set_process(false)
	var starter: String = String(g.weapons.owned.keys()[0])
	_check(g.weapons.owned.size() == 1 and GameManager.pity_left == 3,
		"开局只发起始武器「%s」，保底计数 = 3" % starter)

	var front_ok := true
	for _i in 3:
		var cards: Array[Dictionary] = UpgradeDB.draw(UpgradeDB.CARD_COUNT)
		if String((cards[0]["def"] as Dictionary)["id"]) != starter:
			front_ok = false
	_check(front_ok and GameManager.pity_left == 0,
		"前三次三选一的队首都是起始武器，用满三次后计数归零")

	# 第 4 次起不再强塞。单次队首命中概率约 1/3，30 次全中约 2e-15 —— 这个上界足够硬，
	# 又不需要去读 _pity_to_front 的内部实现（口径要求不回读被测代码）。
	var hits := 0
	for _i in 30:
		var cards: Array[Dictionary] = UpgradeDB.draw(UpgradeDB.CARD_COUNT)
		if String((cards[0]["def"] as Dictionary)["id"]) == starter:
			hits += 1
	_check(hits < 30, "保底用完后不再强塞（30 次里随机命中队首 %d 次）" % hits)

	# 池里根本没有起始武器时（满级 + 精炼满），保底不能空耗次数 ——
	# 否则玩家打完一局会发现"保底用掉了，但一次都没见到"。
	GameManager.pity_left = 3
	g.weapons.owned[starter] = UpgradeDB.WEAPON_MAX
	g.weapons.refines[starter] = UpgradeDB.REFINE_MAX
	UpgradeDB.draw(UpgradeDB.CARD_COUNT)
	_check(GameManager.pity_left == 3, "起始武器满级精炼后不进池，保底不空耗（仍 3 次）")

	g.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- T11 置景
## 三条互相独立的约束：
## ① 数量与种类对（五摊 + 三处地标）；
## ② 开局一屏内完整可见、彼此不重叠（改坐标时最容易悄悄破的两条）；
## ③ 纯装饰（不产出任何碰撞体）。
func _case_street() -> void:
	print("\n[2] T11 置景：五摊 + 牌楼/戏台/灯柱")
	var lm: Array[Dictionary] = PropField.LANDMARKS
	_check(lm.size() == 11, "街区共 11 处置景（5 摊 + 牌楼 + 戏台 + 4 灯柱）")

	# 按文件名主干计数：断言"五门手艺各一个"，而不是"数组里有 5 个字典"
	var stems: Dictionary = {}
	var rects: Array[Rect2] = []
	for m in lm:
		var path: String = String(m["path"])
		var stem: String = path.get_file().get_basename()
		stems[stem] = int(stems.get(stem, 0)) + 1
		var t: Texture2D = Art.tex(path)
		var sz: Vector2 = t.get_size() if t != null else Vector2.ZERO
		var pos: Vector2 = m["pos"]
		rects.append(Rect2(pos + Vector2(-sz.x * 0.5, -sz.y), sz))

	var want: Array[String] = ["stall_forge", "stall_lantern", "stall_paper",
		"stall_shadow", "stall_sugar", "archway", "old_stage", "lantern_pillar"]
	var missing: Array[String] = []
	for w in want:
		if int(stems.get(w, 0)) <= 0:
			missing.append(w)
	_check(missing.is_empty(), "五摊与三处地标各至少一处%s"
		% ("" if missing.is_empty() else "（缺 %s）" % [missing]))
	_check(int(stems.get("lantern_pillar", 0)) == 4, "灯柱 4 根（街两侧成对）")

	# ② 几何：开局一屏之内 + 全不重叠
	var outside: Array[String] = []
	for i in rects.size():
		var r: Rect2 = rects[i]
		if absf(r.get_center().x) + r.size.x * 0.5 > VIEW_W * 0.5 \
				or r.position.y < -VIEW_H * 0.5 or r.end.y > VIEW_H * 0.5:
			outside.append(String(lm[i]["path"]).get_file())
	_check(outside.is_empty(), "11 处置景都完整落在开局一屏（%dx%d）内%s"
		% [int(VIEW_W), int(VIEW_H), "" if outside.is_empty() else "（出界 %s）" % [outside]])

	var overlap: Array[String] = []
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			# 灯柱不参与重叠判定：它是一根 80 宽的细杆，灯笼本来就该探到摊位上方。
			# 把它算进去只会逼着把柱子推到屏幕边缘 —— 那是为了断言好看而牺牲画面。
			# 真正要防的是"两个大件叠在一起看不清"，所以只查摊/牌楼/戏台之间。
			if _stem_of(lm, i) == "lantern_pillar" or _stem_of(lm, j) == "lantern_pillar":
				continue
			if rects[i].intersects(rects[j]):
				overlap.append("%s×%s" % [_stem_of(lm, i), _stem_of(lm, j)])
	_check(overlap.is_empty(), "摊位/牌楼/戏台之间互不重叠%s"
		% ("" if overlap.is_empty() else "（重叠 %s）" % [overlap]))

	# ③ 纯装饰：PropField 是自绘节点，不该有任何子节点，更不能有碰撞体
	var pf := PropField.new()
	var has_collision := false
	for c in pf.get_children():
		if c is CollisionObject2D or c is CollisionShape2D or c is Area2D:
			has_collision = true
	_check(pf.get_child_count() == 0 and not has_collision,
		"置景不产出子节点/碰撞体（纯自绘，走距离判定不参与物理）")
	pf.free()

func _stem_of(lm: Array[Dictionary], i: int) -> String:
	return String(lm[i]["path"]).get_file().get_basename()

# ---------------------------------------------------------------- T10 行走帧
## 三条断言各有各的失败方式：
## ① 三帧画布不一致 → 敌人走一步"长大"一点（换生成器时最容易踩，且肉眼要盯很久才看出来）；
## ② 结壳没换图 → 回到"叠一层壳"，结壳兵长什么样看不出来；
## ③ 帧序不推进 → 图换了但没人动，等于没做。
func _case_enemy_frames() -> void:
	print("\n[3] T10 行走帧 + 结壳变体")
	var kinds: Array[String] = ["cup", "fast", "bag"]
	var bad_canvas: Array[String] = []
	var bad_count: Array[String] = []
	for k in kinds:
		var frames: Array = Art.ENEMY_FRAMES.get(k, [])
		if frames.size() != 3:
			bad_count.append(k)
			continue
		var base: Texture2D = Art.tex(String(frames[0]))
		var base_sz: Vector2 = base.get_size() if base != null else Vector2.ZERO
		for f in frames:
			var t: Texture2D = Art.tex(String(f))
			if t == null or t.get_size() != base_sz:
				bad_canvas.append("%s/%s" % [k, String(f).get_file()])
	_check(bad_count.is_empty(), "三类杂兵各 3 帧%s"
		% ("" if bad_count.is_empty() else "（不全 %s）" % [bad_count]))
	_check(bad_canvas.is_empty(), "三帧与本体同画布（48x48，换帧不改变碰撞半径）%s"
		% ("" if bad_canvas.is_empty() else "（不一致 %s）" % [bad_canvas]))
	# 三帧必须是三张不同的图：同图循环等于没做，而且不会报任何错
	var same: Array[String] = []
	for k in kinds:
		var fr: Array = Art.ENEMY_FRAMES.get(k, [])
		if fr.size() == 3:
			var t0: Texture2D = Art.tex(String(fr[0]))
			var t1: Texture2D = Art.tex(String(fr[1]))
			var t2: Texture2D = Art.tex(String(fr[2]))
			if t0 == t1 or t1 == t2 or t0 == t2:
				same.append(k)
	_check(same.is_empty(), "三帧互不相同（不是同一张图循环）%s"
		% ("" if same.is_empty() else "（重复 %s）" % [same]))

	# 运行时：结壳换图 / 精英不做帧 / 帧序推进
	var g: GameScene = (load(GAME_SCENE) as PackedScene).instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	g.set_process(false)
	g.enemies.clear_all()
	await get_tree().process_frame

	var plain: Enemy = g.enemies.spawn(Vector2(-200.0, 0.0), 100.0, 0.0, 1, "cup",
		false, 0.0, false, false)
	var shell: Enemy = g.enemies.spawn(Vector2(0.0, 0.0), 100.0, 0.0, 1, "cup",
		false, 0.0, false, true)
	var elite: Enemy = g.enemies.spawn(Vector2(200.0, 0.0), 100.0, 0.0, 1, "cup",
		true, 0.0, false, false)
	await get_tree().process_frame

	_check(plain._frames.size() == 3, "杂兵装上了 3 帧")
	_check(shell._frames.is_empty(), "结壳兵不做帧动画（壳本身要读成「沉重」）")
	_check(elite._frames.is_empty(), "精英不做帧动画（贴图自带姿态，且同屏个位数）")
	# 结壳换图：本体贴图必须是 _shell 变体，而不是原来的 paper_scrap
	_check(shell.art.texture == Art.tex(Art.ENEMY_CUP_SHELL),
		"结壳兵本体贴图 = paper_scrap_shell（换图，不是叠壳）")
	_check(shell.art.get_child_count() == 0,
		"结壳不再挂叠加层（Art 下无子节点）")

	# 帧序：7fps 下经过 3 个帧长应回到第 0 帧
	plain._frame_i = 0
	var seen: Array[int] = [0]
	for _i in 3:
		plain._tick_frames(1.0 / Art.ENEMY_FRAME_FPS)
		seen.append(plain._frame_i)
	_check(seen == [0, 1, 2, 0], "帧序按 0→1→2→0 循环（实测 %s）" % [seen])
	# 掉帧时不能把欠账一直攒着快进：一次给 1 秒，只该推进一帧
	plain._frame_i = 1
	plain._tick_frames(1.0)
	_check(plain._frame_i == 2, "一帧掉到 1 秒也只推进一格（不快进）")

	g.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- T12 图鉴
## 四段各查一件事：
## ① 表本身：33 条、四类 9/6/9/9、id 唯一、图标能 load、说明非空；
## ② 解锁口径：四条真实路径（拿到 / 点过 / 开脸 / 杀过）各自能把条目点亮，
##    且重复触发不再返回"首次"（否则每局都会弹一遍"新收录"）；
## ③ 持久化：落盘后重新读盘仍在 —— 图鉴最容易写成"看着有、其实没存"；
## ④ 面板：未收录显示"尚未收录"且不盖章，收录后名字与说明都要变，页签数字同步。
func _case_codex() -> void:
	print("\n[5] T12 图鉴（33 条）")
	var all: Array[Dictionary] = CodexDB.entries()
	_check(all.size() == 33, "图鉴共 33 条（%d）" % all.size())
	_check(CodexDB.total_of(CodexDB.KIND_WEAPON) == 9
		and CodexDB.total_of(CodexDB.KIND_FORM) == 6
		and CodexDB.total_of(CodexDB.KIND_STAT) == 9
		and CodexDB.total_of(CodexDB.KIND_FOE) == 9,
		"四类分别 9 / 6 / 9 / 9（手艺·开脸·心法·对手）")

	var ids: Dictionary = {}
	var dup: Array[String] = []
	var bad_svg: Array[String] = []
	var bad_text: Array[String] = []
	for e in all:
		var id: String = String(e["id"])
		if ids.has(id):
			dup.append(id)
		ids[id] = true
		if Art.tex(String(e["svg"])) == null:
			bad_svg.append(id)
		if String(e["name"]) == "" or String(e["desc"]) == "" or String(e["tag"]) == "":
			bad_text.append(id)
	_check(dup.is_empty(), "33 个 id 互不重复%s" % ("" if dup.is_empty() else "（重复 %s）" % [dup]))
	_check(bad_svg.is_empty(), "33 条图标都能 load 成 Texture2D%s"
		% ("" if bad_svg.is_empty() else "（缺 %s）" % [bad_svg]))
	_check(bad_text.is_empty(), "33 条都有名字 / 分类 / 说明%s"
		% ("" if bad_text.is_empty() else "（缺 %s）" % [bad_text]))

	# 从零开始：把 codex 清空，但保留其它局外进度（别把玩家的金币也清了）
	var backup: Dictionary = MetaSave.snapshot()
	var zero: Dictionary = backup.duplicate()
	zero["codex"] = {}
	MetaSave.debug_set(int(zero["coins"]), zero["levels"], zero)
	_check(CodexDB.seen_count() == 0 and CodexDB.progress_line() == "0 / 33",
		"空存档时 0 / 33（%s）" % CodexDB.progress_line())

	# ② 解锁口径
	_check(CodexDB.unlock("whip") and CodexDB.is_seen("whip"),
		"收录第一条后 is_seen 为真")
	_check(not CodexDB.unlock("whip"), "同一条重复收录返回 false（不会重复弹『新收录』）")
	_check(CodexDB.progress_line() == "1 / 33", "计数口径同步（%s）" % CodexDB.progress_line())
	_check(not CodexDB.unlock("no_such_entry"), "收录不存在的 id 返回 false（接错线不会崩）")

	var g: GameScene = (load(GAME_SCENE) as PackedScene).instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	g.set_process(false)
	g.enemies.clear_all()
	await get_tree().process_frame

	# 拿到武器 → 手艺点亮（走真实 acquire，不直接喊 unlock）
	g.weapons.acquire("halo")
	_check(CodexDB.is_seen("halo"), "拿到花灯后「花灯」收录（acquire 路径）")

	# 点被动 → 心法点亮（走真实 apply）
	UpgradeDB.apply({"def": {"id": "damage", "kind": "stat"}, "new_level": 1})
	_check(CodexDB.is_seen("damage"), "点过「匠心」后收录（apply 路径）")

	# 杀敌 → 对手点亮（走真实死亡信号）
	var foe: Enemy = g.enemies.spawn(Vector2(300.0, 0.0), 1.0, 0.0, 1, "fast", false)
	await get_tree().process_frame
	foe.take_damage(99999.0)
	await get_tree().process_frame
	_check(CodexDB.is_seen("fast"), "杀死一只纸鸢后收录（死亡信号路径）")

	# 精英 / Boss 也走同一条死亡信号：用 elite 通道验一次，别只验杂兵
	var elite: Enemy = g.enemies.spawn(Vector2(200.0, 0.0), 1.0, 0.0, 12, "red", true)
	await get_tree().process_frame
	elite.take_damage(999999.0)
	await get_tree().process_frame
	_check(CodexDB.is_seen("red"), "杀死傩面精英后收录（精英通道同一条信号）")

	# 开脸 → 走真实的宝箱开箱
	g.weapons.owned = {"whip": 8}
	g.player.level_upgrades = {"damage": 1}
	Stats.apply_to(GameManager.stats, "damage", 1)
	g.weapons.evolved.clear()
	var opened: bool = g._open_chest()
	_check(opened and CodexDB.is_seen("evolve_whip"),
		"开箱进化后「火神开脸」收录（%s）" % ("开成" if opened else "没开成"))

	# ③ 持久化：写盘 → 重新读盘
	var before: int = CodexDB.seen_count()
	MetaSave.save()
	MetaSave.reload_from_disk()
	_check(CodexDB.seen_count() == before and CodexDB.is_seen("evolve_whip"),
		"重新读盘后仍收录 %d 条（不是只存在内存里）" % CodexDB.seen_count())

	# ④ 面板：未收录态 / 收录态 / 页签
	var ui := CodexUI.new()
	add_child(ui)
	await get_tree().process_frame
	ui.open(CodexDB.KIND_WEAPON)
	await get_tree().process_frame
	_check(ui.current_tab() == CodexDB.KIND_WEAPON, "默认停在第 1 个页签（手艺）")
	_check(ui.card_text("whip", "desc") != "—— 尚未收录 ——", "已收录的手艺显示真实说明")
	_check(ui.card_text("whip", "name") != "", "已收录的手艺显示名字")
	_check(ui.card_text("print", "desc") == "—— 尚未收录 ——" and not ui.card_seen_mark_visible("print"),
		"未收录的手艺显示『尚未收录』且不盖章")
	_check(ui.card_text("print", "name") != "", "未收录也显示名字（名字是收集目标，不是剧透）")

	ui.open(CodexDB.KIND_FOE)
	await get_tree().process_frame
	_check(ui.current_tab() == CodexDB.KIND_FOE and ui.card_text("fast", "desc") != "—— 尚未收录 ——",
		"切到「对手」页签后，杀过的纸鸢显示说明")
	_check(ui.card_text("reaper", "desc") == "—— 尚未收录 ——", "没杀过的残面仍是未收录")
	ui.close()
	_check(not ui.is_open(), "关闭后隐藏")
	ui.queue_free()

	# 还原存档（codex 与其它字段一起回灌，别只还原一半）
	MetaSave.debug_set(int(backup["coins"]), backup["levels"], backup)
	CodexDB.clear_fresh()
	g.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- T13 残面三现
## 三档真 Boss 是同一个反派的三次现身，验收只认两件事：
## ① **逐次加层**：一现 1 层、二现 2 层、三现 3 层，且后一现包含前一现的所有层
##    （不是"每现换一张图"—— 那读起来就成三个不同对手了）；
## ② **一层比一层外扩**：目标宽度必须严格递增，否则"压迫感逐次加码"就不成立。
## 另外顺手验两件容易忘的事：光效钉在残面身上（它追人，不跟随就会掉在原地），
## 以及残面一死必须整组清掉（否则结算界面背后浮着一圈红环）。
func _case_boss_phases() -> void:
	print("\n[6] T13 残面三现（金光裂纹 / 灯影吸魂 / 全屏傩面）")
	_check(GameScene.BOSS_FX_TEX.size() == 3 and GameScene.BOSS_FX_SPEC.size() == 3,
		"三现共 3 层配置（贴图 %d / 参数 %d）"
		% [GameScene.BOSS_FX_TEX.size(), GameScene.BOSS_FX_SPEC.size()])
	var widths: Array[String] = []
	var grow := true
	for i in GameScene.BOSS_FX_SPEC.size():
		var w: float = float(GameScene.BOSS_FX_SPEC[i]["w"])
		widths.append("%.0f" % w)
		if i > 0 and w <= float(GameScene.BOSS_FX_SPEC[i - 1]["w"]):
			grow = false
	_check(grow, "三层的目标宽度严格递增（%s px）" % [" < ".join(widths)])

	var g: GameScene = (load(GAME_SCENE) as PackedScene).instantiate() as GameScene
	add_child(g)
	await get_tree().process_frame
	g.set_process(false)
	g.enemies.clear_all()
	await get_tree().process_frame
	# 残面放在屏幕中上方：三现是"盖住战场"的演出，得看得见它
	var boss: Enemy = g.enemies.spawn(Vector2(0.0, -120.0), 99999.0, 0.0, 1, "reaper",
		true, 0.0, true)
	await get_tree().process_frame
	_check(boss != null and boss.alive, "残面已登场（否则下面的层数断言都无从谈起）")

	var counts: Array[int] = []
	for phase in 3:
		g.spawn_boss_visual(phase)
		await get_tree().process_frame
		counts.append(g._boss_fx.size())
	_check(counts == [1, 2, 3], "一现 1 层 / 二现 2 层 / 三现 3 层（实测 %s）" % [counts])

	# 后一现必须包含前一现的层：用贴图路径比对，而不是"数组长度对上了就算"
	g.spawn_boss_visual(2)
	await get_tree().process_frame
	var texs: Array[String] = []
	for s in g._boss_fx:
		texs.append(s.texture.resource_path.get_file())
	_check(texs.size() == 3
		and texs[0] == Art.BOSS_MASK_GLOW.get_file()
		and texs[1] == Art.BOSS_LANTERN_DRAIN.get_file()
		and texs[2] == Art.BOSS_WARNING_RING.get_file(),
		"三现是三层叠加：%s" % [texs])
	_check(String(texs[2]) != String(texs[0]), "三现与一现不是同一张图（逐次加层，不是换皮）")

	# 跟随：把残面挪走，光效必须跟着走
	g._update_boss_fx(0.016)
	var before: Vector2 = g._boss_fx[0].global_position
	boss.global_position = boss.global_position + Vector2(120.0, 0.0)
	g._update_boss_fx(0.016)
	_check(g._boss_fx[0].global_position.distance_to(before) > 100.0,
		"光效钉在残面身上（挪 120px 后跟过去 %.0f px）"
		% g._boss_fx[0].global_position.distance_to(before))

	# 残面死 → 整组清掉
	boss.take_damage(999999.0)
	await get_tree().process_frame
	g._update_boss_fx(0.016)
	_check(g._boss_fx.is_empty(), "残面倒下后三现光效整组清除（不留残影盖住结算）")

	g.queue_free()
	await get_tree().process_frame
