extends Node

# =====================================================================
# 平衡真相源·第 4 环（回归门禁）：代码 vs 模型。
#
# v7 策划案 §5.2 的门禁表里这一条是：
#   「BalanceAudit | 新增 | 代码 vs 模型差异 > ±3% 即红」
#
# 【它到底防什么】
# 防的不是"数值不好看"，而是**漂移**：有人改了 WeaponDB 的一个数、没重跑模型，
# 于是文档/模型继续对外宣称一个代码里已经不存在的手感。
# v7 之前这个项目已经漂了三轮（花灯 4.00 / 3.60 / 2.50 三份数并存），
# 三轮里没有任何一次是被测试抓到的 —— 因为没有测试在比这一对。
#
# 【为什么比的是 fingerprint 而不是 band】
# band（收敛带）是模型的**输出**，它依赖命中数那套几何假设（属于模型自己的东西）。
# 把这个假设在 GDScript 里再写一遍，就制造了第二份实现 —— 那才是新的漂移源。
# 所以审查只比对**输入**：武器表 / 被动表 / 波次表里每一个参与计算的数。
# band 与四项验收从 v7_result.json 里读结果，只用于展示与"结果是否通过"的判断。
#
# 用法：
#   godot --headless --path . res://tools/BalanceAudit.tscn
# 前置：tools/BalanceDump.tscn 已跑过；docs/balance/v7_model.py 已跑过。
# =====================================================================

const REL_RESULT := "../../docs/balance/v7_result.json"
const REL_DUMP := "../../docs/balance/v7_code_dump.json"
## §5.2 的容差
const TOL := 0.03
## 绝对值下限：0 附近的数（盾池 Lv0、amp 缺省）用相对误差没有意义，
## 1e-4 的意义是"打印精度噪声不算漂移"。
const ABS_FLOOR := 1e-4

var _ok := 0
var _fails: Array[String] = []

func _ready() -> void:
	print("== BalanceAudit：代码 ←→ v7_result.json")
	print("   基准：%s" % REL_RESULT)

	var base: String = ProjectSettings.globalize_path("res://")
	var res: Dictionary = _read_json(base.path_join(REL_RESULT).simplify_path())
	if res.is_empty():
		_fail("读不到 v7_result.json —— 先跑 tools/BalanceDump.tscn 再跑 v7_model.py")
		_finish()
		return
	var fp: Dictionary = res.get("code_fingerprint", {})
	if fp.is_empty():
		_fail("v7_result.json 里没有 code_fingerprint（模型版本不匹配）")
		_finish()
		return

	_check_fingerprint(fp)
	_check_result(res)
	_finish()

# ---------------------------------------------------------------- 指纹比对
func _check_fingerprint(fp: Dictionary) -> void:
	var worst_key := ""
	var worst: float = 0.0
	var n := 0
	for k in fp.keys():
		var key: String = String(k)
		var want: float = float(fp[k])
		var got_v: Variant = _code_value(key)
		if got_v == null:
			_fail("指纹里有审计不认识的键：%s（模型加了字段但这里没跟着实现）" % key)
			continue
		var got: float = float(got_v)
		var diff: float = absf(got - want)
		var rel: float = diff / maxf(absf(want), ABS_FLOOR)
		n += 1
		if diff > ABS_FLOOR and rel > worst:
			worst = rel
			worst_key = key
		if diff > ABS_FLOOR and rel > TOL:
			_fail("%s：代码 %.4f vs 模型 %.4f（差 %.1f%% > 3%%）" % [key, got, want, rel * 100.0])
	if _fails.is_empty():
		print("  ok    指纹 %d 项全部在 ±3%% 内（最大偏差 %.2f%% @ %s）" % [n, worst * 100.0, worst_key])

## 把一个指纹键翻译成**当前代码里的值**。
## 这里是全工程唯一"知道指纹格式"的地方 —— 模型加字段必须同步加分支，
## 漏了会走 null 分支报"不认识的键"，不会静默通过。
func _code_value(key: String) -> Variant:
	if key.begins_with("weapon."):
		var parts: PackedStringArray = key.split(".")
		if parts.size() < 3:
			return null
		var wid: String = parts[1]
		var field: String = parts[2]
		var d: Dictionary = WeaponDB.def(wid)
		if d.is_empty():
			return null
		# 曲线：weapon.<id>.dmg_curve[3]
		if field.begins_with("dmg_curve["):
			var i: int = int(field.get_slice("[", 1).get_slice("]", 0))
			return WeaponDB.damage_at(wid, i + 1, 1.0)
		if field.begins_with("cd_curve["):
			var i: int = int(field.get_slice("[", 1).get_slice("]", 0))
			return WeaponDB.cooldown_at(wid, i + 1, 1.0)
		if field == "aim":
			return WeaponDB.aim_at(wid)
		# 其余是 WeaponDB.def() 的原始字段。表里没写的字段导出时是**默认值**，
		# 不是"不存在" —— 所以这里必须用同一张默认表，不能直接判 has() 后返回 null。
		# 两张表不一致时，审计会把"模型里 0、代码里缺省"误判成漂移（实测过一次：
		# print 没有 bounce/pierce，报了一屏"审计不认识的键"）。
		return float(d.get(field, _weapon_default(field)))

	if key.begins_with("stat.table."):
		# stat.table.damage[2]
		var rest: String = key.substr("stat.table.".length())
		var tname: String = rest.get_slice("[", 0)
		var i2: int = int(rest.get_slice("[", 1).get_slice("]", 0))
		return Stats.value_at(tname, i2)

	if key == "stat.shield_cap_curve[0]" or key.begins_with("stat.shield_cap_curve["):
		var i3: int = int(key.get_slice("[", 1).get_slice("]", 0))
		return Stats.shield_cap(i3)

	if key.begins_with("stat."):
		var sk: String = key.substr("stat.".length())
		return int(_stat_const(sk)) if sk == "stat_max" or sk == "refine_max" else _stat_const(sk)

	if key.begins_with("wave.boss["):
		var i4: int = int(key.get_slice("[", 1).get_slice("]", 0))
		if i4 < 0 or i4 >= WaveTable.BOSSES.size():
			return null
		if key.ends_with(".hp"):
			return float(WaveTable.BOSSES[i4]["hp"])
		if key.ends_with(".t"):
			return float(WaveTable.BOSSES[i4]["t"])
		return null

	if key.begins_with("wave.hp_curve["):
		var i5: int = int(key.get_slice("[", 1).get_slice("]", 0))
		return WaveTable.enemy_hp(float(i5) * 60.0)

	if key.begins_with("wave.lam_curve["):
		var i6: int = int(key.get_slice("[", 1).get_slice("]", 0))
		var t: float = float(i6) * 60.0
		return float(WaveTable.batch_size(t)) / maxf(WaveTable.spawn_interval(t), 0.001)

	match key:
		"wave.run_length":
			return WaveTable.RUN_LENGTH
		"wave.shell_hp_mult":
			return WaveTable.SHELL_HP_MULT
		"wave.shell_aoe_taken":
			return WaveTable.SHELL_AOE_TAKEN
		"wave.drum_step":
			return WaveTable.DRUM_STEP
	return null

## 与 tools/BalanceDump.gd 里 `w.get(x, 默认值)` 的默认值**逐条对应**。
## 只在 dump 用了非 0 默认时才有条目；其余一律 0.0。
func _weapon_default(field: String) -> float:
	match field:
		"length_cap":
			return 1.0e9
		"count", "count_base", "count_cap", "pierce":
			return 1.0
		_:
			return 0.0

func _stat_const(k: String) -> float:
	match k:
		"stat_max":
			return float(Stats.STAT_MAX)
		"base_hp":
			return Stats.BASE_HP
		"cooldown_floor":
			return Stats.COOLDOWN_FLOOR
		"might_floor":
			return Stats.MIGHT_FLOOR
		"cooldown_abs_floor":
			return Stats.COOLDOWN_ABS_FLOOR
		"refine_max":
			return float(Stats.REFINE_MAX)
		"refine_step":
			return Stats.REFINE_STEP
		"regen_per_lv":
			return Stats.REGEN_PER_LV
		"regen_cap":
			return Stats.regen_cap()
		"shield_pulse_base":
			return Stats.SHIELD_BASE
		"shield_pulse_per_lv":
			return Stats.SHIELD_PER_LV
		"shield_period":
			return Stats.SHIELD_PERIOD
		"shield_cap_base":
			return Stats.SHIELD_CAP_BASE
		"shield_cap_per_lv":
			return Stats.SHIELD_CAP_PER
	# 返回 NaN 会让 diff 恒为 false，等于静默通过 —— 直接给一个不可能相等的哨兵
	push_error("BalanceAudit: 未知 stat 常量 %s" % k)
	return -999999.0

# ---------------------------------------------------------------- 结果自身的验收
## 模型算出来的四项验收必须全绿。它不是"重新验一遍数值"，而是防止
## **有人只改了代码没重跑模型** 时审计还是绿的（旧 result 往往四项也绿）。
## 真正抓漂移的是上面的指纹；这里抓的是"result 过期"。
func _check_result(res: Dictionary) -> void:
	var checks: Dictionary = res.get("checks", {})
	if checks.is_empty():
		_fail("v7_result.json 里没有 checks")
		return
	for k in checks.keys():
		var key: String = String(k)
		var v: bool = bool(checks[k])
		if v:
			_ok += 1
			print("  ok    %s" % key)
		else:
			_fail("验收项 %s 未通过（重跑 v7_model.py 看具体数字）" % key)

	var span: Dictionary = res.get("band_span", {})
	if not span.is_empty():
		print("  info  收敛带 %.2f×（%.1f ~ %.1f），辅助档 %s" % [
			float(span.get("ratio", 0.0)), float(span.get("lo", 0.0)),
			float(span.get("hi", 0.0)), str(span.get("aux", {})),
		])

# ---------------------------------------------------------------- 收尾
func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok    %s" % msg)
	else:
		_fail(msg)

func _fail(msg: String) -> void:
	_fails.append(msg)
	print("  FAIL  %s" % msg)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f.close()
	var v: Variant = JSON.parse_string(raw)
	if v is Dictionary:
		return v as Dictionary
	return {}

func _finish() -> void:
	print("")
	if _fails.is_empty():
		print("BalanceAudit  PASS   %d 项通过 / 0 失败" % _ok)
		get_tree().quit(0)
	else:
		print("BalanceAudit  FAIL   %d 项通过 / %d 失败" % [_ok, _fails.size()])
		for f in _fails:
			print("   - %s" % f)
		get_tree().quit(1)
