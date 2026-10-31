extends RefCounted
class_name UpgradeDB

# 升级三选一的卡池。
# 约定（Step 6 的核心接口）：被动不直接改武器，只改 GameManager.stats；
# 武器每帧从 stats 读。公式全部集中在 Stats.gd，这里只负责"选什么卡、写回哪一级"。

const WEAPON_MAX := WeaponDB.MAX_LEVEL
const STAT_MAX := Stats.STAT_MAX
const WEAPON_SLOTS := 6
const CARD_COUNT := 3
## 精炼：满级武器再抽到时的二次投入。每级该武器 +6%，最多 3 级，不占新卡位。
const REFINE_MAX := Stats.REFINE_MAX
const REFINE_STEP := Stats.REFINE_STEP

# 被动卡的显示名 / 描述按 Stats 公式生成，保证文案和数值不会各说一套。
const STAT_DEFS: Array[Dictionary] = [
	{"id": "damage", "name": "匠心", "unit": "全部手艺伤害 +10%"},
	{"id": "cooldown", "name": "巧手", "unit": "全部手艺冷却 -5%"},
	{"id": "area", "name": "火候", "unit": "手艺范围 +7%"},
	{"id": "speed", "name": "夜行", "unit": "移动速度 +8%"},
	{"id": "magnet", "name": "听风", "unit": "灯花拾取范围 +25%"},
	{"id": "max_hp", "name": "底气", "unit": "生命上限 +20 并立即回血"},
	{"id": "might", "name": "护身", "unit": "受到接触伤害 -7%"},
	# ---- v5 两条生存被动。它们是潮涌尖峰（§6）的唯一解，池子同时 7→9。
	# v7（v6 策划案 ③）：回春改涓流、结界改累积盾，unit 是卡面兜底文案，
	# 实际展示走 CardText.stat_lines（从 Stats 公式反推），两者必须同源。
	{"id": "regen", "name": "回春", "unit": "每秒回血 +0.6（上限 3.0/s）"},
	{"id": "shield", "name": "结界", "unit": "每 8s 叠 5 点护盾（池上限 30+6×级）"},
]

## 兼容旧调用：全量卡池（武器在前，被动在后）
static func all_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in WeaponDB.ORDER:
		var d: Dictionary = WeaponDB.def(id)
		out.append({
			"id": id,
			"kind": "weapon",
			"name": String(d.get("name", id)),
			"desc": String(d.get("desc", "")),
		})
	for sd in STAT_DEFS:
		out.append({
			"id": String(sd["id"]),
			"kind": "stat",
			"name": String(sd["name"]),
			"desc": _stat_desc(String(sd["id"]), String(sd["unit"])),
		})
	return out

## 被动描述：交给 CardText 统一生成。
## 这里以前是自己拼 "unit + ×1.00 → ×1.10"，有两个毛病：
##   ① `might`（护身）是**减伤**，倍率往下走（1.00 → 0.93），箭头朝下读起来像被削弱；
##   ② "×1.10" 是乘数字，不是效果语言。现在统一成「本级 +10% / 累计 +30%」。
static func _stat_desc(id: String, unit: String) -> String:
	var to_lv: int = current_level(id) + 1
	if to_lv > STAT_MAX:
		return unit
	return CardText.stat_desc(id, to_lv)

static func is_weapon(id: String) -> bool:
	return WeaponDB.has_weapon(id)

static func display_name(id: String) -> String:
	if WeaponDB.has_weapon(id):
		return WeaponDB.display_name(id)
	for sd in STAT_DEFS:
		if String(sd["id"]) == id:
			return String(sd["name"])
	return id

static func current_level(id: String) -> int:
	if is_weapon(id):
		if GameManager.weapons == null:
			return 0
		return int(GameManager.weapons.owned.get(id, 0))
	if GameManager.player == null:
		return 0
	return int(GameManager.player.level_upgrades.get(id, 0))

static func max_level(id: String) -> int:
	return WEAPON_MAX if is_weapon(id) else STAT_MAX

## 抽 3 张互不重复的卡；池子不足时返回实际数量
static func draw(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var owned_slots: int = 0
	if GameManager.weapons != null:
		owned_slots = GameManager.weapons.owned.size()
	for def in all_defs():
		var id: String = String(def["id"])
		var weapon: bool = is_weapon(id)
		var lv: int = current_level(id)
		# 已进化的武器不再出现在升级池里（它已经走到终点，精炼也不再供给）
		if weapon and GameManager.weapons != null and GameManager.weapons.is_evolved(id):
			continue
		if lv >= max_level(id):
			# 满级武器 → 精炼卡。这是"进程延展"的关键：Lv8 之后每一次抽到不再白给。
			# 精炼不占新卡位、不改等级，只在武器级伤害上叠一层乘区。
			if weapon and refine_tier(id) < REFINE_MAX:
				pool.append({
					"def": _refine_def(id),
					"new_level": lv,
					"is_new": false,
					"refine": refine_tier(id) + 1,
				})
			continue
		# 新武器受 6 槽限制；已拥有的武器升级不受限
		if lv == 0 and weapon and owned_slots >= WEAPON_SLOTS:
			continue
		pool.append({"def": def, "new_level": lv + 1, "is_new": lv == 0, "refine": 0})
	pool.shuffle()
	# 起始武器保底（T9）：先把它换到队首，再切片。
	# 【为什么是换位而不是"切完再追加第四张"】三选一是 UI 与手感契约
	#   （三个按钮、一行高）。临时变四张会让卡面重新排版，
	#   玩家一眼就看出"这局有点不一样"，保底反而成了破绽。
	_pity_to_front(pool)
	var out: Array[Dictionary] = []
	for i in mini(count, pool.size()):
		out.append(pool[i])
	return out

## 把起始武器换到队首。找不到（6 槽已满 / 已满级）就什么也不做：
## 那不是 bug，硬塞会造成"卡面写 Lv3、实际没加"。
## 每成功一次消耗一点 pity —— 计的是"出现过几次"，不是"被选过几次"：
## 玩家的抱怨是"抽不到"，不是"抽到了但没选"。
static func _pity_to_front(pool: Array[Dictionary]) -> void:
	if GameManager.pity_left <= 0:
		return
	var want: String = GameManager.start_weapon
	if want == "":
		return
	for i in pool.size():
		if String((pool[i]["def"] as Dictionary).get("id", "")) != want:
			continue
		if i > 0:
			var hit: Dictionary = pool[i]
			pool.remove_at(i)
			pool.insert(0, hit)
		GameManager.pity_left -= 1
		return

## 精炼卡：名字带"精炼·"，描述直接说清"这一层给谁加多少"。
## 不塞进 all_defs —— 它不是一张独立卡，而是"某把满级武器"的附加状态，
## 混进全量卡池会让 §4.2 的概率口径（9武×8 + 9被动×5）全部算错。
static func _refine_def(id: String) -> Dictionary:
	return {
		"id": id,
		"kind": "weapon",
		"name": "精炼·%s" % WeaponDB.display_name(id),
		"desc": "",
	}

static func refine_tier(id: String) -> int:
	if GameManager.weapons == null:
		return 0
	return int(GameManager.weapons.refines.get(id, 0))

## 写回。武器只改等级，被动只改 GameManager.stats —— 两边不互相碰。
static func apply(entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	var id: String = String(def["id"])
	# 精炼优先：它带 "refine" 且 new_level 等于当前等级，不会被误当成升级
	var rf: int = int(entry.get("refine", 0))
	if rf > 0:
		if GameManager.weapons != null:
			GameManager.weapons.set_refine(id, rf)
		return
	var lv: int = int(entry["new_level"])
	if is_weapon(id):
		if not GameManager.weapons.owned.has(id):
			GameManager.weapons.acquire(id)
		GameManager.weapons.owned[id] = lv
		return
	GameManager.player.level_upgrades[id] = lv
	Stats.apply_to(GameManager.stats, id, lv)
	# 图鉴（T12）：点过一次就收录。放在 apply 里而不是 UI 里 ——
	# 测试和"自动选卡"也走这条路，图鉴才不会只在真人手点时才长。
	CodexDB.unlock(id)
