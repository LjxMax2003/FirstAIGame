extends Node

# ============================================================================
# FX 落地验收 —— 用**游戏真实的代码路径**把 7 个 shader 触发一遍，逐个截图
# ----------------------------------------------------------------------------
# 与 FxSheet 的分工（别混）：
#   FxSheet    证明"shader 本身能编译、参数对、画面不是黑的"——挂的是孤立 Sprite2D。
#   FxInGame   证明"接进去了"——调 Enemy.take_damage() / Enemy._die() / Gem.setup() /
#              HUD 每帧驱动这些**真函数**，再看材质是不是真的换成了对应的 shader。
#
# 为什么必须有这一层：
#   上一个坑就是"文件都在、没人调用"——shader 全绿、游戏里一个都看不见。
#   只跑 FxSheet 会得到"7 个效果都正常"的假结论。
#
# 用法：godot --path . res://tools/FxInGame.tscn
#   产出 user://fx_*.png，控制台打印 PASS/FAIL 断言。
# ============================================================================

const ZOOM := 0.55          # 拉远镜头，让 608px 外的 Boss 也能进画面
const ZOOM_CLOSE := 1.6     # 拉近看细节：96px 精英在 0.55 缩放下只有 53px，判别不了溶解形态
const WARMUP := 2.0

var game: GameScene
var _bad: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 摘掉 60 帧上限：本工具靠真实渲染截图，各用例之间是按秒等待的。
	# 留上限只会让整套跑得更慢，且"受击闪 0.09s"这类窗口反而更容易被帧率抖动影响。
	Engine.max_fps = 0
	await get_tree().process_frame
	# 等刷怪跑起来：需要 GameManager.started 为 true，敌人 _process 才会动
	await get_tree().create_timer(WARMUP).timeout
	game = $Game
	_zoom(ZOOM_CLOSE)
	print("\n===== FX 落地验收（真实代码路径）=====")

	await _case_elite()
	await _case_mob()
	await _case_gem()
	await _case_pickup()
	await _case_hurt()
	await _case_chest()
	await _case_boss()

	print("\n---------- 断言 ----------")
	if _bad.is_empty():
		print("  ok   7 个效果全部走真实路径生效")
	else:
		for b in _bad:
			print("  FAIL %s" % b)
	print("\n==== FX 落地验收：%s ====\n" % ("PASS" if _bad.is_empty() else "FAIL"))
	get_tree().quit(0 if _bad.is_empty() else 1)


# --- 用例 -------------------------------------------------------------------

## 精英：出场溶解 → 受击闪 → 化墨散去，三段各截一张
func _case_elite() -> void:
	print("\n[精英] 溶解出场 / 受击闪 / 化墨")
	var pos: Vector2 = game.player.global_position + Vector2(0.0, -200.0)
	var e: Enemy = game.enemies.spawn(pos, 9999.0, 40.0, 5, "red", true)
	# 出场：0.40s 的 tween，0.14s 时约到 35%，正是"从墨里渗出来"最明显的一帧
	await get_tree().create_timer(0.14).timeout
	_check(_shader_of(e.art) .ends_with("dissolve_spawn.gdshader"),
		"精英 setup() 后 art 应挂 dissolve_spawn，实际 %s" % _shader_of(e.art))
	await _shot("elite_spawn")

	# 受击：0.09s 全白再退回。截图必须赶在这之前，否则拍到的就是"已经恢复"
	e.take_damage(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_shader_of(e.art).ends_with("hit_flash.gdshader"),
		"精英 take_damage() 后应挂 hit_flash，实际 %s" % _shader_of(e.art))
	await _shot("elite_hit")

	# 化墨：必须等受击闪结束再打死，否则拍到的是闪光不是溶解
	await get_tree().create_timer(0.12).timeout
	e.take_damage(999999.0)
	# ⚠️ 必须**当场**读 _corpse_left：它是倒计时，等 0.18s 再读只能读到剩余值（0.45-0.18），
	#    断言会假失败。要验的是"出生时被设成多长"。
	_check(absf(e.get("_corpse_left") - Enemy.ELITE_DISSOLVE) < 0.02,
		"精英尸体留存应等于溶解时长 %.2fs（小于它会被回收在半途），实际 %.2f" % [
			Enemy.ELITE_DISSOLVE, float(e.get("_corpse_left"))])
	await get_tree().create_timer(0.18).timeout
	_check(_shader_of(e.art).ends_with("dissolve_spawn.gdshader"),
		"精英死亡后应挂 dissolve_spawn，实际 %s" % _shader_of(e.art))
	await _shot("elite_die")


## 普通小怪：必须**不挂材质**（0 额外 draw call），颜色走 modulate
func _case_mob() -> void:
	print("\n[小怪] 受击只走 modulate，不挂材质")
	_zoom(ZOOM_CLOSE)
	var pos: Vector2 = game.player.global_position + Vector2(-160.0, -120.0)
	var e: Enemy = game.enemies.spawn(pos, 9999.0, 10.0, 1, "cup", false)
	var before: Material = e.art.material
	e.take_damage(1.0)
	await get_tree().process_frame
	_check(e.art.material == before,
		"小怪受击不应换材质（会掉出合批），实际 %s" % _shader_of(e.art))
	_check(e.art.modulate.is_equal_approx(Enemy.HIT_COLOR),
		"小怪受击应把 art.modulate 设成 HIT_COLOR，实际 %s" % e.art.modulate)
	# ⚠️ 不能 queue_free()：这只敌人已经登记在 EnemyPool.active 里，直接删会留下悬空引用，
	#    下一帧 EnemyPool._process 摸到 "previously freed" 直接崩（signal 11）。
	#    走正常击杀，让它按池的约定回收。
	e.take_damage(999999.0)


## 灯花：大颗（>=5 点）发光，小颗不挂
func _case_gem() -> void:
	print("\n[灯花] 大颗发光 / 小颗不挂")
	_zoom(ZOOM_CLOSE)
	var base: Vector2 = game.player.global_position + Vector2(120.0, -90.0)
	# GemPool.spawn() 返回 void（池化），实例要从 active 尾部取
	game.gems.spawn(base, 8)
	var big: Gem = game.gems.active.back()
	game.gems.spawn(base + Vector2(90.0, 0.0), 1)
	var small: Gem = game.gems.active.back()
	await get_tree().create_timer(0.25).timeout
	_check(_shader_of(big).ends_with("sprite_glow.gdshader"),
		"大灯花应挂 sprite_glow，实际 %s" % _shader_of(big))
	_check(small.material == null,
		"小灯花不应挂材质，实际 %s" % _shader_of(small))
	# 合批关键：所有大灯花必须共用同一个材质实例
	game.gems.spawn(base + Vector2(0.0, 70.0), 9)
	var big2: Gem = game.gems.active.back()
	await get_tree().process_frame
	_check(big.material == big2.material,
		"同为大灯花应共用一份材质（各自 new 会拆散合批）")
	await _shot("gem_glow")


## 掉落物：落地扫一次光
func _case_pickup() -> void:
	print("\n[掉落物] 落地扫光")
	_zoom(ZOOM_CLOSE)
	var pos: Vector2 = game.player.global_position + Vector2(-140.0, 40.0)
	var before: int = game.pickups.active.size()
	game.pickups.spawn(pos, "magnet")
	await get_tree().process_frame
	_check(game.pickups.active.size() == before + 1, "掉落物应被加入 active 列表")
	var s: Sprite2D = game.pickups.active.back()
	_check(_shader_of(s).ends_with("shine_sweep.gdshader"),
		"掉落物出场应挂 shine_sweep，实际 %s" % _shader_of(s))
	await get_tree().create_timer(0.1).timeout
	await _shot("pickup_sweep")


## 玩家受伤：HUD 每帧推 max_alpha
func _case_hurt() -> void:
	print("\n[玩家] 受伤红边")
	_zoom(1.0)
	_check(_shader_of(game.hud.hurt).ends_with("hurt_vignette.gdshader"),
		"HUD.Hurt 应挂 hurt_vignette，实际 %s" % _shader_of(game.hud.hurt))
	game.player.set("invuln_left", 0.0)
	game.player.take_damage(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var mat: ShaderMaterial = game.hud.hurt.material as ShaderMaterial
	var a: float = float(mat.get_shader_parameter("max_alpha"))
	_check(a > 0.1, "受击后 max_alpha 应被推起来，实际 %.3f" % a)
	await _shot("hurt")


## 宝箱：进化唯一入口，背后必须有一层暖光
func _case_chest() -> void:
	print("\n[宝箱] 背后光晕")
	_zoom(ZOOM_CLOSE)
	var pos: Vector2 = game.player.global_position + Vector2(-70.0, -250.0)
	game._drop_chest(pos)
	var s: Sprite2D = game._chests.back()
	var aura: ColorRect = null
	for c in s.get_children():
		if c is ColorRect and _shader_of(c).ends_with("glow_aura.gdshader"):
			aura = c
	_check(aura != null, "宝箱应带一个 glow_aura 光晕")
	_check(aura != null and aura.show_behind_parent, "光晕应画在箱子**背后**，不能盖住箱体")
	await get_tree().create_timer(0.3).timeout
	await _shot("chest_aura")


## Boss 登场傩阵：走 Game._check_boss 的真实分支
func _case_boss() -> void:
	print("\n[Boss] 登场傩阵")
	_zoom(ZOOM)
	var keep_elapsed: float = game.elapsed
	var boss_t: float = float(WaveTable.BOSSES[0]["t"])
	# 伪造"刚跨过 Boss 时间点"，然后直接调用真实函数，而不是自己再画一遍法阵
	game.set("_prev_t", boss_t - 1.0)
	game.elapsed = boss_t
	game._check_boss()
	game.elapsed = keep_elapsed
	await get_tree().create_timer(0.34).timeout

	var circle: ColorRect = null
	for c in game.get_children():
		if c is ColorRect and _shader_of(c).ends_with("magic_circle.gdshader"):
			circle = c
	_check(circle != null, "Boss 登场应在场上留下一个 magic_circle 法阵")
	_check(game.enemies.has_boss(), "Boss 应已生成")
	await _shot("boss_circle")


# --- 工具 -------------------------------------------------------------------

func _zoom(z: float) -> void:
	game.camera.zoom = Vector2.ONE * z


func _shader_of(n: CanvasItem) -> String:
	if n == null or n.material == null:
		return "<null>"
	var m := n.material as ShaderMaterial
	if m == null or m.shader == null:
		return "<non-shader>"
	return m.shader.resource_path.get_file()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   %s" % msg)
	else:
		print("  FAIL %s" % msg)
		_bad.append(msg)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := "user://fx_%s.png" % tag
	var err: int = img.save_png(path)
	print("  SHOT %-14s err=%d size=%s" % [tag, err, str(img.get_size())])
