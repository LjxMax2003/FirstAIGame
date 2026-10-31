extends Node

# 卡面文案核对表：把 CardText 对"所有武器 × 所有等级 × 所有被动"的输出全打印出来。
#
# 【为什么需要】
# 文案是生成出来的，就一定能过编译；能过编译不等于**说得对**。
# 这个工具把每一句都摊开，让人一眼看出"这一级到底变了什么"，
# 并顺手做两件机器能判的事：
#   ① 行数是否超出卡面能放下的 3 行（超出会被卡框/印章吃掉）；
#   ② 每行**像素宽**是否超过描述区的 128px。
#
# 【为什么量像素宽，而不是数字符】
# 第一版用"≤13 字"当标准，结果把 `伤害 10 · 冷却 1.30s`（16 字符）误判成超宽 ——
# 数字与空格的实际宽度只有汉字的 1/2~1/3。字符数不是排版单位，像素才是。
#
# 用法：godot --headless --path . res://tools/CardTextProbe.tscn

## 描述区实际尺寸（与 LevelUpUI._make_card 一致）
const DESC_W := 128.0
const DESC_H := 56.0
## 12px 字，与卡面一致
const FONT_SIZE := 12

var _bad: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame

	print("\n========== 武器卡：首次获得 ==========")
	for id in WeaponDB.ORDER:
		_row("%s 首得" % WeaponDB.display_name(id), CardText.weapon_desc(id, 0, 1))

	print("\n========== 武器卡：逐级升级 ==========")
	for id in WeaponDB.ORDER:
		print("\n-- %s（%s）--" % [WeaponDB.display_name(id), id])
		for lv in range(1, WeaponDB.MAX_LEVEL):
			_row("Lv %d → %d" % [lv, lv + 1], CardText.weapon_desc(id, lv, lv + 1))

	print("\n========== 被动卡：逐级 ==========")
	for sd in UpgradeDB.STAT_DEFS:
		var key: String = String(sd["id"])
		print("\n-- %s（%s）--" % [String(sd["name"]), key])
		for lv in range(1, Stats.STAT_MAX + 1):
			_row("点第 %d 级" % lv, CardText.stat_desc(key, lv))

	print("\n========== 反查：文案里的数字是否等于公式值 ==========")
	_verify_numbers()

	print("\n---------- 排版检查 ----------")
	if _bad.is_empty():
		print("  ok   全部文案 ≤3 行、每行 ≤%.0fpx" % DESC_W)
	else:
		for b in _bad:
			print("  FAIL %s" % b)
	print("\n==== CardText 核对：%s ====" % ("PASS" if _bad.is_empty() else "FAIL"))
	get_tree().quit(0 if _bad.is_empty() else 1)

func _row(head: String, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var lines: PackedStringArray = text.split("\n")
	var widest: float = 0.0
	var total_h: float = 0.0
	for i in lines.size():
		var line: String = lines[i]
		print("  %-14s %s" % [head if i == 0 else "", line])
		var sz: Vector2 = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		widest = maxf(widest, sz.x)
		total_h += font.get_height(FONT_SIZE)
		if sz.x > DESC_W + 0.5:
			_bad.append("%s 第 %d 行 %.0fpx 超过描述区 %.0fpx：%s" % [head, i + 1, sz.x, DESC_W, line])
	if lines.size() > CardText.MAX_LINES:
		_bad.append("%s 有 %d 行，超过卡面可放的 %d 行" % [head, lines.size(), CardText.MAX_LINES])
	if total_h > DESC_H + 0.5:
		_bad.append("%s 文字总高 %.0fpx 超过描述区 %.0fpx" % [head, total_h, DESC_H])

## 抽查几条最容易写错的：用 WeaponDB/Stats 的原始公式反算，和文案里的数字对撞。
## 只验方向和量级，不验字符串拼装（拼错了上面那张表一眼能看出来）。
func _verify_numbers() -> void:
	var fails: PackedStringArray = []

	# 1) 打铁花 Lv1→2：伤害 16 → 18，应报 +13%（roundi(18/16-1=12.5) = 13）
	var ext: String = CardText.weapon_desc("extinguisher", 1, 2)
	if not ext.contains("+13%"):
		fails.append("打铁花 Lv1→2 应含 +13%%，实际：%s" % ext.replace("\n", " / "))

	# 2) 打铁花每级只有伤害在变：不该出现"发数"字样
	if ext.contains("发数"):
		fails.append("打铁花发数恒定，不该出现发数行：%s" % ext.replace("\n", " / "))

	# 3) 糖画 Lv2→3 是 +1 发的那个等级（count_per_two_level = 1）
	var gs: String = CardText.weapon_desc("glowstick", 2, 3)
	if not gs.contains("发数 1 → 2"):
		fails.append("糖画 Lv2→3 应出现「发数 1 → 2」，实际：%s" % gs.replace("\n", " / "))

	# 4) 糖画 Lv1→2 不该出现发数（还没到加发的等级）
	var gs12: String = CardText.weapon_desc("glowstick", 1, 2)
	if gs12.contains("发数"):
		fails.append("糖画 Lv1→2 尚未加发，不该出现发数行：%s" % gs12.replace("\n", " / "))

	# 5) 护身是减伤：必须写 "-"，不能写成 "受击伤害 +7%"
	var might: String = CardText.stat_desc("might", 1)
	if not might.contains("受击伤害 -7%"):
		fails.append("护身第 1 级应为「受击伤害 -7%%」，实际：%s" % might.replace("\n", " / "))
	if might.contains("+7%"):
		fails.append("护身被写成了加伤：%s" % might.replace("\n", " / "))

	# 6) 底气：+20，且累计到 120
	var hp: String = CardText.stat_desc("max_hp", 1)
	if not (hp.contains("+20") and hp.contains("120")):
		fails.append("底气第 1 级应含 +20 且累计 120，实际：%s" % hp.replace("\n", " / "))

	# 7) 巧手：冷却 -5%，累计 -5%
	var cd: String = CardText.stat_desc("cooldown", 1)
	if not cd.contains("-5%"):
		fails.append("巧手第 1 级应含 -5%%，实际：%s" % cd.replace("\n", " / "))

	for f in fails:
		print("  FAIL %s" % f)
		_bad.append(f)
	if fails.is_empty():
		print("  ok   7 条数字反查全部对得上公式")
