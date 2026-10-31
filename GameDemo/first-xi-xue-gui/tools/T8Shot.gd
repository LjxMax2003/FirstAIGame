extends Node

# ============================================================================
# T8 铁水散开 · 眼见为实（**不能加 --headless**）
#
# 用法：godot --path . res://tools/T8Shot.tscn
# 产出：user://t8_flight.png（弹体还在飞）/ user://t8_burst.png（碎开）/ user://t8_late.png（散开锋面）
#
# 为什么单开一个截图工具：
#   V5InGame 能证明"半径传的是 150、上限是 18、直击者不吃溅射"，
#   但证明不了**画面上这 150 到底有多大**、火星有没有糊成一坨白。
#   散开半径从 76 改到 150 是本次改动里唯一玩家用眼睛立刻能分辨的差异，
#   这种改动不截图等于没验收。
#
# 【两个必须先关掉的东西，否则截出来不可复现】
#   ① Game._process：波次会持续往场上丢怪，散开边界里混进不相干的人；
#   ② Weapons._process：它每 1.6s 自动开一次火，等你按下截图键时
#      画面上那团火星可能已经是第三发了 —— 我第一次就是这么截到"爆点在怪群外面"的。
# ============================================================================

const GAME_SCENE := "res://scenes/Game.tscn"
## 环形包围的半径：55~99。弹体 300px/s，飞行 0.18~0.33s 命中，
## 所以下面那三个时间点正好落在"飞行中 / 刚碎 / 锋面散开"。
const RING_MIN := 55.0
const RING_STEP := 22.0

var _g: GameScene

func _ready() -> void:
	await get_tree().process_frame
	_g = (load(GAME_SCENE) as PackedScene).instantiate() as GameScene
	add_child(_g)
	await get_tree().process_frame
	await get_tree().process_frame

	_g.set_process(false)
	_g.enemies.clear_all()
	await get_tree().process_frame

	var p: Vector2 = _g.player.global_position
	# 环形包围：fire_extinguisher 的 base_ang 是随机的，两发朝着相反方向飞。
	# 只有把人围成一圈，才能保证**不管随机到哪个角**都打在密集人群里。
	for i in 46:
		var a: float = TAU * float(i) / 46.0
		var rr: float = RING_MIN + RING_STEP * float(i % 3)
		_g.enemies.spawn(p + Vector2.from_angle(a) * rr, 99999.0, 0.0, 1, "cup")
	await get_tree().process_frame

	_g.weapons.owned = {"extinguisher": 8}
	_g.weapons.fire_extinguisher(_g.player)
	# 【为什么不能直接 weapons.set_process(false)】
	# 子弹的位移是在 WeaponManager._process 的 update_bullets() 里推进的，
	# 关掉 process 等于把子弹冻在原地 —— 我第一次就是这么截到两张"什么都没发生"。
	# 正确做法是**留这一发、锁住下一发**：把冷却顶到 999s，
	# _tick_cd() 判 left > 0 就不再自动开火，而子弹照常飞。
	_g.weapons._cd["extinguisher"] = 999.0

	await get_tree().create_timer(0.16).timeout
	await _snap("t8_flight")
	await get_tree().create_timer(0.14).timeout
	await _snap("t8_burst")
	await get_tree().create_timer(0.16).timeout
	await _snap("t8_late")

	print("DONE")
	get_tree().quit()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var out := "user://%s.png" % name
	var err: int = img.save_png(out)
	print("SHOT %-12s err=%d %s" % [name, err, ProjectSettings.globalize_path(out)])
