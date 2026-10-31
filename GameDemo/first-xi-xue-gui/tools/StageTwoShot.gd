extends Node

# 阶段二窗口渲染冒烟（真实窗口，非 headless）。
# 目的：
#   1) 证明 6 把武器同时在场时渲染不崩、画面不是全黑；
#   2) 证明新武器（手机环 / 美工刀 / 灭火器）确实有可见的实体；
#   3) 证明宝箱贴图与进化横幅能画出来。
#
# 用法：godot --path . res://tools/StageTwoShot.tscn
# 注意：这个脚本只做"渲染证据"，不替代玩法验收 —— 玩法由 SmokeTest.tscn 覆盖。

const SHOTS := "user://"

func _ready() -> void:
	await get_tree().process_frame
	var game: GameScene = get_node_or_null("Game") as GameScene
	if game == null:
		print("SHOT FAIL: Game 节点缺失")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.6).timeout

	var player: Player = game.get_node("World/Player") as Player
	var weapons: WeaponManager = game.get_node("World/Weapons") as WeaponManager
	var enemies: EnemyPool = game.get_node("World/EnemyPool") as EnemyPool

	# 六把武器全部装上并给到中段等级，让每种特效都出现在画面里
	for id in WeaponDB.ORDER:
		if not weapons.has_weapon(id):
			weapons.acquire(id)
		weapons.owned[id] = 4
		weapons._cd[id] = 0.05

	# 玩家周围铺一圈敌人，保证近战/环状武器都有目标
	for i in 26:
		var ang: float = TAU * float(i) / 26.0
		enemies.spawn(player.global_position + Vector2.from_angle(ang) * randf_range(110.0, 300.0),
			120.0, 10.0, 1, "cup", false)

	# 地上放一只宝箱（进化入口的可见性证据）
	game._drop_chest(player.global_position + Vector2(90, 120))

	# 触发一次进化横幅
	game.hud.flash_evolve("进化！ 血鞭")

	# 让武器打几个周期，弹道类（荧光棒/美工刀/灭火器）必须在飞
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var out: String = SHOTS + "shot_stage2.png"
	var err: int = img.save_png(out)
	print("SHOT ", ProjectSettings.globalize_path(out), " err=", err, " size=", img.get_size())

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
	print("AVG_LUMA %.4f over %d samples" % [sum / float(maxi(n, 1)), n])
	print("WEAPONS ", str(weapons.owned.keys()))
	print("ALIVE %d  CHESTS %d" % [enemies.alive_count(), game.chest_count()])
	get_tree().quit()
