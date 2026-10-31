extends Node

# =====================================================================
# 平衡真相源·第 1 环：把**代码里的真实数值**导出成 JSON。
#
# 为什么需要这一步，而不是让 v7_model.py 自己抄一份数：
#   v7 策划案 §3.2 L-01 诊断出的病根就是"文档说 A、代码是 B、模型是 C"。
#   只要模型里出现任何一个人手抄的数字，第三次漂移就只是时间问题。
#   所以链条固定为：代码 → 本工具导出 → 模型读取 → v7_result.json → BalanceAudit 比对。
#   任何一环的手抄都等于重新打开漂移的门。
#
# 用法：
#   godot --headless --path . res://tools/BalanceDump.tscn
#   产出 docs/balance/v7_code_dump.json（工程外的绝对路径，供 Python 读取）
#
# 注意：必须作为**场景**运行。--script 模式下 autoload 与全局类不注册，
#      WeaponDB.def() 会解析到 null 上。
# =====================================================================

const OUT_PATH := "res://../docs/balance/v7_code_dump.json"
## 工程根在 GameDemo/first-xi-xue-gui，docs/ 在**仓库根**（QoderGameFirst），
## 所以要退两级。退一级会落到 GameDemo/docs/ 上 —— 那里不存在，报 error 7。
const REL_OUT := "../../docs/balance/v7_code_dump.json"

func _ready() -> void:
	var d: Dictionary = dump()
	var text: String = JSON.stringify(d, "  ", false)
	var abs_path: String = ProjectSettings.globalize_path("res://").path_join(REL_OUT).simplify_path()
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_error("BalanceDump: 无法写入 %s（error %d）" % [abs_path, FileAccess.get_open_error()])
		get_tree().quit(1)
		return
	f.store_string(text)
	f.close()
	print("[BalanceDump] %s" % abs_path)
	print("  武器 %d 把 / 被动 %d 条 / Boss %d 档" % [
		(d["weapons"] as Dictionary).size(),
		Stats.STAT_KEYS.size(),
		WaveTable.BOSSES.size(),
	])
	get_tree().quit(0)

func dump() -> Dictionary:
	return {
		"schema": 1,
		"note": "由 tools/BalanceDump.tscn 从 WeaponDB / Stats / WaveTable 直接导出，禁止手改。",
		"weapons": _weapons(),
		"weapon_order": Array(WeaponDB.ORDER),
		"stats": _stats(),
		"waves": _waves(),
	}

# ---------------------------------------------------------------- 武器
func _weapons() -> Dictionary:
	var out: Dictionary = {}
	for id in WeaponDB.ORDER:
		var w: Dictionary = WeaponDB.def(id)
		# 只导出**数值与结构**字段。svg / desc / name 是表现层，模型不关心，
		# 也避免改文案就把审计判红（那不是数值漂移）。
		var row: Dictionary = {
			"kind": String(w.get("kind", "")),
			"dmg_kind": String(w.get("dmg_kind", "")),
			"cooldown": float(w.get("cooldown", 0.0)),
			"cd_per_level": float(w.get("cd_per_level", 0.0)),
			"damage": float(w.get("damage", 0.0)),
			"dmg_per_level": float(w.get("dmg_per_level", 0.0)),
			"aim": WeaponDB.aim_at(id),
			# 命中上限：0 = **无上限**（花灯 / 师刀是 query 全查，代码里没有这个字段）。
			# 不能默认成 1 —— 那会让模型把"打到全圈"当成"打到 1 只"，band 直接失真。
			"hit_cap": int(w.get("hit_cap", 0)),
			"radius": float(w.get("radius", 0.0)),
			"radius_per_level": float(w.get("radius_per_level", 0.0)),
			"length": float(w.get("length", 0.0)),
			"length_per_level": float(w.get("length_per_level", 0.0)),
			"length_cap": float(w.get("length_cap", 1.0e9)),
			"width": float(w.get("width", 0.0)),
			"count": int(w.get("count", 1)),
			"count_base": int(w.get("count_base", 1)),
			"count_per_two_level": int(w.get("count_per_two_level", 0)),
			"count_cap": int(w.get("count_cap", 1)),
			"pierce": int(w.get("pierce", 1)),
			"pierce_milestone": bool(w.get("pierce_milestone", false)),
			"bounce": int(w.get("bounce", 0)),
			"orbit_radius": float(w.get("orbit_radius", 0.0)),
			"orbit_radius_per_level": float(w.get("orbit_radius_per_level", 0.0)),
			"orbit_count": int(w.get("orbit_count", 0)),
			# v7 T8：explode_* 已整体退役，散开走 scatter_* 三件套
			"scatter_radius": float(w.get("scatter_radius", 0.0)),
			"scatter_ratio": float(w.get("scatter_ratio", 0.0)),
			# 注意导的是 **Lv1 基础值**，逐级封顶由 WeaponDB.scatter_cap_at() 算；
			# 模型侧照同一个公式推，审计侧比这两个原始字段。
			"scatter_cap": int(w.get("scatter_cap", 0)),
			"scatter_cap_per_level": int(w.get("scatter_cap_per_level", 0)),
			"slow_pct": float(w.get("slow_pct", 0.0)),
			"slow_dmg": float(w.get("slow_dmg", 0.0)),
			"shell_bonus": float(w.get("shell_bonus", 0.0)),
			"amp": float(w.get("amp", 0.0)),
			"double_sweep": bool(w.get("double_sweep", false)),
			"double_sweep_from": int(w.get("double_sweep_from", 0)),
			"double_sweep_ratio": float(w.get("double_sweep_ratio", 0.0)),
		}
		# 逐级展开的实测曲线：模型直接用，不再自己推一遍公式
		# （推一遍就等于在模型里手抄一次公式，正是要杜绝的东西）。
		var dmg_curve: Array[float] = []
		var cd_curve: Array[float] = []
		var hit_curve: Array[int] = []
		for lv in range(1, WeaponDB.MAX_LEVEL + 1):
			dmg_curve.append(WeaponDB.damage_at(id, lv, 1.0))
			cd_curve.append(WeaponDB.cooldown_at(id, lv, 1.0))
			hit_curve.append(WeaponDB.count_at(id, lv))
		row["dmg_curve"] = dmg_curve
		row["cd_curve"] = cd_curve
		row["count_curve"] = hit_curve
		out[id] = row
	return out

# ---------------------------------------------------------------- 被动
func _stats() -> Dictionary:
	var tables: Dictionary = {}
	for k in Stats.STAT_KEYS:
		var t: Array[float] = []
		for lv in range(0, Stats.STAT_MAX + 1):
			t.append(Stats.value_at(k, lv))
		tables[k] = t
	return {
		"stat_max": Stats.STAT_MAX,
		"base_hp": Stats.BASE_HP,
		"cooldown_floor": Stats.COOLDOWN_FLOOR,
		"might_floor": Stats.MIGHT_FLOOR,
		"cooldown_abs_floor": Stats.COOLDOWN_ABS_FLOOR,
		"refine_max": Stats.REFINE_MAX,
		"refine_step": Stats.REFINE_STEP,
		"regen_per_lv": Stats.REGEN_PER_LV,
		"regen_cap": Stats.regen_cap(),
		"shield_pulse_base": Stats.SHIELD_BASE,
		"shield_pulse_per_lv": Stats.SHIELD_PER_LV,
		"shield_period": Stats.SHIELD_PERIOD,
		"shield_cap_base": Stats.SHIELD_CAP_BASE,
		"shield_cap_per_lv": Stats.SHIELD_CAP_PER,
		"shield_cap_curve": _arr(func(lv: int) -> float: return Stats.shield_cap(lv)),
		"tables": tables,
	}

func _arr(f: Callable) -> Array[float]:
	var out: Array[float] = []
	for lv in range(0, Stats.STAT_MAX + 1):
		out.append(float(f.call(lv)))
	return out

# ---------------------------------------------------------------- 波次
func _waves() -> Dictionary:
	var waves: Array = []
	for w in WaveTable.WAVES:
		waves.append({"t0": float(w["t0"]), "t1": float(w["t1"]), "elite_share": float(w["elite_share"])})
	var bosses: Array = []
	for b in WaveTable.BOSSES:
		bosses.append({"t": float(b["t"]), "hp": float(b["hp"])})
	var minis: Array = []
	for m in WaveTable.MINI_BOSSES:
		minis.append({"t": float(m["t"]), "hp": float(m["hp"]), "kind": String(m["kind"])})
	var surges: Array = []
	for s in WaveTable.SURGES:
		surges.append({"t0": float(s["t0"]), "dur": float(s["dur"]),
			"lam_mult": float(s["lam_mult"]), "elite_add": float(s["elite_add"])})
	var mobs: Dictionary = {}
	for k in WaveTable.MOB_DEFS:
		var md: Dictionary = WaveTable.MOB_DEFS[k]
		mobs[k] = {"hp_mult": float(md["hp_mult"]), "speed_mult": float(md["speed_mult"])}
	var elites: Dictionary = {}
	for k in WaveTable.ELITE_DEFS:
		var ed: Dictionary = WaveTable.ELITE_DEFS[k]
		elites[k] = {"hp_mult": float(ed["hp_mult"]), "dmg_mult": float(ed["dmg_mult"])}
	return {
		"run_length": WaveTable.RUN_LENGTH,
		"waves": waves,
		"bosses": bosses,
		"mini_bosses": minis,
		"surges": surges,
		"drum_step": WaveTable.DRUM_STEP,
		"drum_times": Array(WaveTable.DRUM_TIMES),
		"shell_on": WaveTable.SHELL_ON,
		"shell_fade0": WaveTable.SHELL_FADE0,
		"shell_off": WaveTable.SHELL_OFF,
		"shell_hp_mult": WaveTable.SHELL_HP_MULT,
		"shell_aoe_taken": WaveTable.SHELL_AOE_TAKEN,
		"contact_damage": WaveTable.CONTACT_DAMAGE,
		"contact_cadence": WaveTable.CONTACT_CADENCE,
		"mobs": mobs,
		"elites": elites,
		# 采样密度曲线：模型必须用同一组，否则 R 曲线和实机不是一回事。
		# 之所以**采样**而不是导出 (base, ref, exp) 三个常数：
		# 那三个数写在 WaveTable.enemy_hp() 的函数体里，导出它们等于让人手抄一遍公式
		# —— 正是这一轮要消灭的东西。采样则是"直接问代码要答案"。
		"hp_curve": _sample_curve(60.0, func(t: float) -> float: return WaveTable.enemy_hp(t)),
		"lam_curve": _sample_curve(60.0, func(t: float) -> float:
			return float(WaveTable.batch_size(t)) / maxf(WaveTable.spawn_interval(t), 0.001)),
	}

## 0..RUN_LENGTH 每 step 秒取一个点（31 个）。模型线性插值使用。
func _sample_curve(step: float, f: Callable) -> Array[float]:
	var out: Array[float] = []
	var t: float = 0.0
	while t <= WaveTable.RUN_LENGTH + 0.001:
		out.append(float(f.call(t)))
		t += step
	return out
