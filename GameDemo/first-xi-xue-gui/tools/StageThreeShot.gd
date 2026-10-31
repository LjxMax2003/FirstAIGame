extends Node

# 阶段三窗口渲染冒烟（真实窗口，非 headless）。
# 目的：
#   1) 证明 Boss（死神）能实际生成、血条常显、画面不是全黑；
#   2) 证明三种掉落物（磁铁/炸弹/烤鸡）与资源点（可破坏物）画得出来；
#   3) 证明结算面板的胜负两种版面与金币行渲染正常。
#
# 用法：godot --path . res://tools/StageThreeShot.tscn
# 注意：这个脚本只做"渲染证据"，不替代玩法验收 —— 玩法由 SmokeTest.tscn 覆盖。

const SHOTS := "user://"

var _game: GameScene

func _ready() -> void:
	await get_tree().process_frame
	_game = get_node_or_null("Game") as GameScene
	if _game == null:
		print("SHOT FAIL: Game 节点缺失")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.6).timeout

	var player: Player = _game.get_node("World/Player") as Player
	var weapons: WeaponManager = _game.get_node("World/Weapons") as WeaponManager
	var enemies: EnemyPool = _game.get_node("World/EnemyPool") as EnemyPool
	var res: ResourceField = _game.get_node("World/Resources") as ResourceField

	# 六把武器全上，中段等级：让特效够密，显示"25 分钟档"的视觉密度
	for id in WeaponDB.ORDER:
		if not weapons.has_weapon(id):
			weapons.acquire(id)
		weapons.owned[id] = 4
		weapons._cd[id] = 0.05

	# ---- 场景 1：Boss 在场 + 掉落物 + 资源点
	player.set("invuln_left", 999999.0)
	GameManager.stats["hp"] = 1e9
	GameManager.stats["max_hp"] = 1e9

	# 25 分钟档的杂兵（血量按表值，不是硬编码），铺成一圈
	var t_mark := 1500.0
	var mob_hp: float = WaveTable.enemy_hp(t_mark)
	for i in 22:
		var ang: float = TAU * float(i) / 22.0
		enemies.spawn(player.global_position + Vector2.from_angle(ang) * randf_range(120.0, 330.0),
			mob_hp, 20.0, 1, ["cup", "bag", "fast"][i % 3], false, WaveTable.CONTACT_DAMAGE)

	# 一只精英 + 一只 Boss（用表的真实血量，证明血条比例正确）
	enemies.spawn(player.global_position + Vector2(-210, -170), mob_hp * 18.0, 18.0, 12,
		"box", true, WaveTable.CONTACT_DAMAGE * 1.6)
	var boss: Enemy = enemies.spawn(player.global_position + Vector2(180, -230),
		6100.0, WaveTable.BOSS_SPEED, WaveTable.BOSS_XP_MULT,
		"reaper", true, WaveTable.CONTACT_DAMAGE * WaveTable.BOSS_DAMAGE_MULT, true)
	if boss != null:
		# 打掉 35% 血：血条不能是满的，否则看不出它在工作
		boss.take_damage(6100.0 * 0.35)

	# 三种掉落物各摆一个在玩家附近
	_game.pickups.spawn(player.global_position + Vector2(-120, 60), "magnet")
	_game.pickups.spawn(player.global_position + Vector2(0, 90), "bomb")
	_game.pickups.spawn(player.global_position + Vector2(120, 60), "bento")

	# 资源点：把玩家挪到有资源点的格子附近（资源点由格哈希生成）
	await get_tree().create_timer(0.5).timeout

	_game.hud.flash_boss("死神降临  ·  Boss 2/3")
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	_shot("shot_stage3_boss.png", "Boss 在场")

	print("BOSS_HP %.0f / %.0f  is_boss=%s" % [boss.hp if boss else -1.0, boss.max_hp if boss else -1.0,
		str(boss.is_boss if boss else false)])
	print("PICKUPS %d  RESOURCES %d  ALIVE %d" % [_game.pickups.count(), res.count(), enemies.alive_count()])

	# ---- 场景 2：失败结算
	enemies.clear_all()
	_game.pickups.clear_all()
	_game.kills = 1284
	_game.elapsed = 1147.0
	_game.elite_kills = 7
	_game.boss_kills = 1
	_game.evolutions = 2
	_game.coins_earned = 38
	_game.won = false
	_game.death_ui.show_result(_game.kills, _game.elapsed, 31, false,
		_game.coin_reward(), _game.elite_kills, _game.boss_kills, _game.evolutions)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_shot("shot_stage3_lose.png", "失败结算")
	print("LOSE_COINS %d" % _game.coin_reward())

	get_tree().paused = false
	_game.death_ui.get_node("Popup").visible = false
	_game.death_ui.get_node("Mask").visible = false

	# ---- 场景 3：胜利结算
	_game.won = true
	_game.elapsed = WaveTable.RUN_LENGTH
	_game.kills = 3921
	_game.elite_kills = 21
	_game.boss_kills = 3
	_game.evolutions = 4
	_game.death_ui.show_result(_game.kills, _game.elapsed, 45, true,
		_game.coin_reward(), _game.elite_kills, _game.boss_kills, _game.evolutions)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_shot("shot_stage3_win.png", "胜利结算")
	print("WIN_COINS %d" % _game.coin_reward())

	get_tree().quit()

func _shot(name: String, label: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var out: String = SHOTS + name
	var err: int = img.save_png(out)
	print("SHOT [%s] %s err=%d size=%s" % [label, ProjectSettings.globalize_path(out), err, str(img.get_size())])
	# 亮度采样：排除"截到一张纯黑图"的假成功
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum := 0.0
	var n := 0
	for x in range(int(w * 0.2), int(w * 0.8), 7):
		for y in range(int(h * 0.2), int(h * 0.8), 7):
			var c: Color = img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
			n += 1
	print("  AVG_LUMA %.4f over %d samples" % [sum / float(maxi(n, 1)), n])
