extends RefCounted
class_name CodexDB

# =====================================================================
# 图鉴（v7.1 / T12 · 策划案 §4.3 优先级 4）
#
# 36 条 = 9 手艺 + 9 开脸 + 9 心法 + 9 对手。
#
# 【为什么手艺/开脸/心法三条轴直接读现有表，只有"对手"手写】
#   前三条的 id、名字、图标、说明本来就活在 WeaponDB / EvolutionDB / UpgradeDB 里，
#   图鉴再抄一份的结果是：改一次数值要改两处，改漏的那一处不会报错，
#   只会让图鉴里挂着一条"上一版的旧描述"。这类静默不一致是本工程反复吃亏的地方。
#   而"对手"没有对应表（敌人是纯运行时对象，只有 kind 字符串），
#   所以只能在这里写死 —— 但 kind 必须和 Enemy.setup() 收到的字符串一模一样，
#   因为解锁走的是真实击杀路径（见 §解锁），对不上就永远收不到。
#
# 【解锁口径：见过就收】
#   手艺 = 拿到过（WeaponManager.acquire）
#   开脸 = 进化过一次（Game._open_chest 成功）
#   心法 = 点过一次（UpgradeDB.apply）
#   对手 = 杀过一只（EnemyPool 的死亡信号）
#   四条全部落在**玩家实际做过的事**上，没有"看了图鉴就算解锁"的旁路。
#
# 【为什么收录状态存在 MetaSave 而不是这里】
#   静态类不能在退出时持久化，而图鉴必须是跨局的。MetaSave.codex_seen 是一个
#   id → true 的集合，加条目不用改存档结构。
# =====================================================================

const KIND_WEAPON := "weapon"
const KIND_FORM := "form"
const KIND_STAT := "stat"
const KIND_FOE := "foe"

## 展示顺序：手艺 → 开脸 → 心法 → 对手。
## 前三条是"我能变成什么"，最后一条是"我会遇到什么"，读起来有递进。
const KIND_ORDER: Array[String] = [KIND_WEAPON, KIND_FORM, KIND_STAT, KIND_FOE]
const KIND_NAME: Dictionary = {
	KIND_WEAPON: "手艺",
	KIND_FORM: "开脸",
	KIND_STAT: "心法",
	KIND_FOE: "对手",
}

## 9 个对手。id 即 Enemy.setup() 的 p_kind；
## "red" / "box" 是两种精英的 kind（见 Enemy._art_for），"reaper" 是三现 Boss。
## 说明不写数值（数值会变），只写"看到它该怎么反应" —— 图鉴的用处在这里。
const FOES: Array[Dictionary] = [
	{
		"id": "cup", "name": "纸屑", "tag": "杂兵", "svg": Art.ENEMY_CUP,
		"desc": "成摞的旧纸屑自己卷成一团，贴着地皮滚过来。\n最慢也最薄，擦边就能带走。",
	},
	{
		"id": "fast", "name": "纸鸢", "tag": "杂兵", "svg": Art.ENEMY_CUP_FAST,
		"desc": "断了线的纸鸢，飞得急，喜欢从侧面切进来。\n别让它绕到背后 —— 它比你想的快。",
	},
	{
		"id": "bag", "name": "纸偶", "tag": "杂兵", "svg": Art.ENEMY_BAG,
		"desc": "戏散后被丢下的纸偶，肚子里塞满了浆糊。\n走得慢、皮很厚；起壳之后刀砍不进，得靠墨。",
	},
	{
		"id": "box", "name": "墨渍", "tag": "精英", "svg": Art.ELITE_BOX,
		"desc": "从墨斗里泼出来的一团陈墨，裹着碎木屑。\n血厚，掉宝箱 —— 宝箱里是开脸的机会。",
	},
	{
		"id": "red", "name": "傩面", "tag": "精英", "svg": Art.ELITE_RED,
		"desc": "没有脸的傩面，比戏台上的那张更沉。\n撞上来很疼，绕开比硬顶划算。",
	},
	{
		"id": "drum", "name": "更鼓傀", "tag": "小 Boss", "svg": Art.BOSS_DRUM,
		"desc": "三更打更的鼓自己长了腿。\n它一响，当夜所有的对手都更凶。",
	},
	{
		"id": "nuo", "name": "无面傩", "tag": "小 Boss", "svg": Art.BOSS_NUO,
		"desc": "傩戏散了，面具没人摘。\n它在街上找一张脸，找到之前不会停。",
	},
	{
		"id": "lantern", "name": "长夜灯", "tag": "小 Boss", "svg": Art.BOSS_LANTERN,
		"desc": "长夜灯自燃不熄，灯下没有影子。\n因为它把影子都收了去。",
	},
	{
		"id": "reaper", "name": "残面", "tag": "Boss", "svg": Art.REAPER,
		"desc": "十五分钟起，从街尾一寸寸压过来的那张大脸。\n它不缺眼睛，缺的是你这一张。",
	},
]

# ---------------------------------------------------------------- 取条目
## 全部 36 条，按 KIND_ORDER 排列。调用方不需要知道每种几条。
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in KIND_ORDER:
		out.append_array(of_kind(k))
	return out

static func of_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match kind:
		KIND_WEAPON:
			for id in WeaponDB.ORDER:
				var d: Dictionary = WeaponDB.def(id)
				out.append({
					"id": id, "kind": KIND_WEAPON,
					"name": String(d.get("name", id)),
					"tag": "起手可选" if id in ["whip", "halo", "glowstick"] else "局内获得",
					"svg": String(d.get("svg", "")),
					"desc": String(d.get("desc", "")).replace("\n", ""),
				})
		KIND_FORM:
			for fid in EvolutionDB.FORMS.keys():
				var f: Dictionary = EvolutionDB.FORMS[fid]
				out.append({
					"id": String(fid), "kind": KIND_FORM,
					"name": String(f.get("name", fid)),
					"tag": "开脸",
					"svg": String(f.get("svg", "")),
					"desc": "由 %s 开脸而成。" % String(f.get("desc", "")),
				})
		KIND_STAT:
			for sd in UpgradeDB.STAT_DEFS:
				var sid: String = String(sd["id"])
				out.append({
					"id": sid, "kind": KIND_STAT,
					"name": String(sd["name"]),
					"tag": "心法",
					"svg": String(Art.STAT_ICON.get(sid, Art.GEM_ORANGE)),
					"desc": stat_line(sid),
				})
		KIND_FOE:
			for f in FOES:
				out.append({
					"id": String(f["id"]), "kind": KIND_FOE,
					"name": String(f["name"]), "tag": String(f["tag"]),
					"svg": String(f["svg"]), "desc": String(f["desc"]),
				})
	return out

static func entry(id: String) -> Dictionary:
	for e in entries():
		if String(e["id"]) == id:
			return e
	return {}

## 被动条目的说明：说"一档给多少"，而不是"满级给多少"。
## 玩家在图鉴里对的是"下次抽到这张卡会怎样"，不是结算面板。
static func stat_line(id: String) -> String:
	for sd in UpgradeDB.STAT_DEFS:
		if String(sd["id"]) == id:
			return String(sd["unit"])
	return ""

static func total() -> int:
	return entries().size()

static func total_of(kind: String) -> int:
	return of_kind(kind).size()

# ---------------------------------------------------------------- 解锁
static func is_seen(id: String) -> bool:
	return MetaSave.has_codex(id)

## 收录一条，返回"是不是首次"。所有真实行为都要走这里，不要直接写 MetaSave。
static func unlock(id: String) -> bool:
	if entry(id).is_empty():
		# 收一条不存在的 id 是接错线了：静默忽略，但也别崩 ——
		# 图鉴不该因为"某个 kind 拼错"把整局打死。
		return false
	var fresh: bool = MetaSave.note_codex(id)
	if fresh:
		_fresh[id] = true
	return fresh

static func seen_count() -> int:
	var n := 0
	for e in entries():
		if is_seen(String(e["id"])):
			n += 1
	return n

static func seen_in(kind: String) -> int:
	var n := 0
	for e in of_kind(kind):
		if is_seen(String(e["id"])):
			n += 1
	return n

## "12 / 36"。给 UI 的顶栏和主菜单按钮用同一个口径。
static func progress_line() -> String:
	return "%d / %d" % [seen_count(), total()]

## 主菜单按钮文案："图鉴 · 12/36（有 3 条新）"——"新"是本次会话里刚收录、
## 还没在图鉴里看过的数量。用会话内计数而不是存档字段：
## 玩家点进图鉴就算看过了，不需要为一件"看过没看过"再写一个持久字段。
static var _fresh: Dictionary = {}

static func fresh_count() -> int:
	return _fresh.size()

static func clear_fresh() -> void:
	_fresh = {}
