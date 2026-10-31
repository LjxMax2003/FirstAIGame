extends Node

# P2 资源接入的**渲染证据**（真实窗口，非 headless）。
# 不是玩法验收——玩法与槽位断言由 SmokeTest.tscn 覆盖（285 项）。
# 这里只回答一件事：换完图之后，"该看见的东西"是否真的出现在屏幕上。
#
# 覆盖方案 P2 出口的三类目视项：
#   1) 玩家 / 基础杂兵 / 重型杂兵 / 精英 / Boss 全部换成守艺人素材；
#   2) 快速怪（断线纸鸢）有亮青描边，其余敌人没有（描边是唯一的"这只会咬人"预警）；
#   3) 血条 4 段刻度在满血时也看得见（px 级扫描，不靠肉眼）。
#
# 用法：godot --path . res://tools/P2Shot.tscn

const SHOTS := "user://"
# 描边色 = shader 里的 vec4(0.37, 0.88, 0.82)，转成 0..255 便于按阈值扫
const OUTLINE := Color(0.37, 0.88, 0.82)

var _game: GameScene
var _player: Player
var _enemies: EnemyPool
var _weapons: WeaponManager
var _sc := 1.0

func _ready() -> void:
	await get_tree().process_frame
	_game = get_node_or_null("Game") as GameScene
	if _game == null:
		print("SHOT FAIL: Game 节点缺失")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.6).timeout
	_player = _game.get_node("World/Player") as Player
	_enemies = _game.get_node("World/EnemyPool") as EnemyPool
	_weapons = _game.get_node("World/Weapons") as WeaponManager

	# 玩家不能死，也不能因为碰怪掉血污染血条读数
	_player.set("invuln_left", 1e9)
	GameManager.stats["hp"] = 1e9
	GameManager.stats["max_hp"] = 1e9

	# 六把武器全上、等级拉高：让特效密度接近中期局，才看得出换皮后的整体观感
	for id in WeaponDB.ORDER:
		if not _weapons.has_weapon(id):
			_weapons.acquire(id)
		_weapons.owned[id] = 4
		_weapons._cd[id] = 0.06

	# ---- 场景 1：中场混战（玩家 + 三种杂兵 + 掉落 + 布景）
	var mob_hp: float = WaveTable.enemy_hp(600.0)
	for i in 20:
		var ang: float = TAU * float(i) / 20.0
		_enemies.spawn(_player.global_position + Vector2.from_angle(ang) * (150.0 + float(i % 3) * 45.0),
			mob_hp, 16.0, 1, ["cup", "bag", "fast"][i % 3], false, WaveTable.CONTACT_DAMAGE)
	_game.pickups.spawn(_player.global_position + Vector2(-110, 70), "magnet")
	_game.pickups.spawn(_player.global_position + Vector2(110, 70), "bento")
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img := _grab()
	_save(img, "shot_p2_field.png", "中场混战")

	# ---- 场景 2：快速怪描边（左侧 fast，右侧 cup 做对照）
	_enemies.clear_all()
	await get_tree().process_frame
	var fast: Enemy = _enemies.spawn(_player.global_position + Vector2(-70, -120), 999.0, 0.0, 1, "fast", false)
	var plain: Enemy = _enemies.spawn(_player.global_position + Vector2(70, -120), 999.0, 0.0, 1, "cup", false)
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	img = _grab()
	_save(img, "shot_p2_fast_outline.png", "快速怪描边（左 fast / 右 对照）")
	print("OUTLINE fast=%d px  plain=%d px" % [_count_outline(img, fast), _count_outline(img, plain)])

	# ---- 场景 3：Boss（残面）+ 精英
	_enemies.clear_all()
	var boss: Enemy = _enemies.spawn(_player.global_position + Vector2(0, -230),
		6100.0, WaveTable.BOSS_SPEED, WaveTable.BOSS_XP_MULT,
		"reaper", true, WaveTable.CONTACT_DAMAGE * WaveTable.BOSS_DAMAGE_MULT, true)
	var elite: Enemy = _enemies.spawn(_player.global_position + Vector2(-190, -110), mob_hp * 18.0, 17.0, 12,
		"box", true, WaveTable.CONTACT_DAMAGE * 1.6)
	var elite_red: Enemy = _enemies.spawn(_player.global_position + Vector2(190, -110), mob_hp * 18.0, 17.0, 12,
		"red", true, WaveTable.CONTACT_DAMAGE * 1.6)
	if boss != null:
		boss.take_damage(6100.0 * 0.35)
	if elite_red != null:
		elite_red.take_damage(mob_hp * 18.0 * 0.4)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	img = _grab()
	_save(img, "shot_p2_boss_elite.png", "Boss + 两种精英")
	print("BOSS_TEX %s  ELITE_TEX %s  ELITE_RED_TEX %s" % [
		(boss.get_node("Art") as Sprite2D).texture.resource_path.get_file(),
		(elite.get_node("Art") as Sprite2D).texture.resource_path.get_file(),
		(elite_red.get_node("Art") as Sprite2D).texture.resource_path.get_file()])

	# ---- 场景 4：六种敌人同框（剪影/配色总览，给人工可辨识度复核用）
	_enemies.clear_all()
	await get_tree().process_frame
	var lineup: Array = [
		["cup", false, Vector2(-200, -80)], ["bag", false, Vector2(0, -80)], ["fast", false, Vector2(200, -80)],
		["box", true, Vector2(-200, 90)], ["red", true, Vector2(0, 90)], ["reaper", true, Vector2(200, 90)],
	]
	for row in lineup:
		_enemies.spawn(_player.global_position + Vector2(row[2]),
			999.0, 0.0, 1, String(row[0]), bool(row[1]),
			WaveTable.CONTACT_DAMAGE, String(row[0]) == "reaper")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	img = _grab()
	_save(img, "shot_p2_lineup.png", "六种敌人同框（上：纸屑/傀儡/纸鸢 下：墨渍/傩面/Boss）")

	# ---- 场景 5：血条（62% 血，既有填充也有刻度）+ 局部裁图
	_enemies.clear_all()
	GameManager.stats["max_hp"] = 100.0
	GameManager.stats["hp"] = 62.0
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	img = _grab()
	_save(img, "shot_p2_hud.png", "HUD 血条 62%")
	_save_hpbar(img)

	# ---- 场景 5：升级卡（宣纸木版卡框 + 武器图标）
	# 卡池是随机的，随机抽到的若是三条被动就测不出"两行描述 + 数值行"的版面压力。
	# 这里钉死三张：两把武器（desc 两行 + 数值行）+ 一条被动，保证每次截图可对比。
	_game.level_up_ui._on_level_up()
	await get_tree().process_frame
	_game.level_up_ui._clear_cards()
	var entries: Array[Dictionary] = []
	# 走 UpgradeDB.all_defs() 拿"卡面定义"（带 id/kind/name/desc），不要去翻 WeaponDB.DEFS
	var defs: Array[Dictionary] = UpgradeDB.all_defs()
	for d in defs:
		if String(d["id"]) == "whip" or String(d["id"]) == "halo" or String(d["id"]) == "damage":
			entries.append({"def": d, "new_level": UpgradeDB.current_level(String(d["id"])) + 1, "is_new": false})
	for e in entries:
		_game.level_up_ui.cards.add_child(_game.level_up_ui._make_card(e))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	img = _grab()
	_save(img, "shot_p2_cards.png", "升级卡（钉死两条武器 + 一条被动）")
	print("CARDS open=%s" % str(_game.level_up_ui.is_open()))
	_game.level_up_ui.close_all()

	get_tree().quit()

func _grab() -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	_sc = float(img.get_width()) / get_viewport().get_visible_rect().size.x
	return img

func _save(img: Image, name: String, label: String) -> void:
	var err: int = img.save_png(SHOTS + name)
	print("SHOT [%s] %s err=%d size=%s" % [label, ProjectSettings.globalize_path(SHOTS + name), err, str(img.get_size())])

## 在敌人贴图的外接框内数描边色像素。
## 阈值放宽到 ±0.12：描边经过缩放与抗锯齿，颜色会有边缘混色。
func _count_outline(img: Image, e: Enemy) -> int:
	if e == null:
		return -1
	var art: Sprite2D = e.get_node("Art") as Sprite2D
	var tex: Vector2 = art.texture.get_size()
	# 必须走 canvas 变换：玩家身上挂着 Camera2D，世界坐标 ≠ 屏幕坐标
	var c: Vector2 = art.get_global_transform_with_canvas().origin * _sc
	var half: Vector2 = tex * 0.5 * _sc + Vector2(6, 6)
	var n := 0
	var hist: Dictionary = {}
	for y in range(int(c.y - half.y), int(c.y + half.y)):
		for x in range(int(c.x - half.x), int(c.x + half.x)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var p: Color = img.get_pixel(x, y)
			var key := "%d,%d,%d" % [int(p.r * 16.0), int(p.g * 16.0), int(p.b * 16.0)]
			hist[key] = int(hist.get(key, 0)) + 1
			if absf(p.r - OUTLINE.r) < 0.12 and absf(p.g - OUTLINE.g) < 0.12 and absf(p.b - OUTLINE.b) < 0.12:
				n += 1
	print("  outline probe: mat=%s tex=%s world=%s screen=%s" % [
		("ShaderMaterial" if art.material is ShaderMaterial else str(art.material)),
		art.texture.resource_path.get_file(), str(e.global_position), str(c)])
	print("  bbox=%s hist_top=%s" % [
		Rect2i(int(c.x - half.x), int(c.y - half.y), int(half.x * 2), int(half.y * 2)),
		str(_top_keys(hist, 5))])
	return n

func _top_keys(h: Dictionary, n: int) -> Array:
	var pairs: Array = []
	for k in h:
		pairs.append([k, h[k]])
	pairs.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var out: Array = []
	for i in mini(n, pairs.size()):
		out.append("%s×%d" % [pairs[i][0], pairs[i][1]])
	return out

## 单独存一条血条：P2 出口要求"4 段刻度可见"，给一张能一眼数出 4 格的图
func _save_hpbar(img: Image) -> void:
	var bar: TextureProgressBar = _game.hud.get_node("Top/Col/HPBar")
	var r: Rect2 = bar.get_global_rect()
	var x: int = maxi(0, int(r.position.x * _sc) - 4)
	var y: int = maxi(0, int(r.position.y * _sc) - 4)
	var w: int = mini(img.get_width() - x, int(r.size.x * _sc) + 8)
	var h: int = mini(img.get_height() - y, int(r.size.y * _sc) + 8)
	var crop: Image = img.get_region(Rect2i(x, y, w, h))
	# 放大 3 倍便于目视（最近邻，避免插值把 1px 刻度糊掉）
	crop.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(SHOTS + "shot_p2_hpbar.png")
	print("SHOT [血条裁切] %s size=%s" % [ProjectSettings.globalize_path(SHOTS + "shot_p2_hpbar.png"), str(crop.get_size())])
