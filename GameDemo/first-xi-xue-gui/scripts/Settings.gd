extends Node

# =====================================================================
# 全局设置（v7 策划案 L-06 / T4）。
#
# 【为什么单独一个 autoload，而不是塞进 MetaSave】
# MetaSave 是"玩家的游戏进度"，存档损坏时最坏的情况是**丢进度**；
# 设置是"这台机器的偏好"（特效档位、震屏），跟进度没有关系，也不该
# 因为玩家点"清除存档"就被一起重置 —— 那会让低配机的玩家每次清档都要重新关特效。
# 所以两条独立文件：user://save.json 与 user://settings.cfg。
#
# 【音频项】
# 音乐 / 音效两条音量存在这里（与存档分开），由 Audio autoload 应用到
# AudioServer 的 Music / SFX 总线上。拖动滑条立即生效，改动即时落盘。
#
# 【特效档位到底关什么】
# v7 §5.3 的降级顺序：皮影残像 → 走马灯 → 铁水火星 → 摊位装饰；
# 花灯波纹与铜锣冲击环**最后关**（它们是"圈里在烧 / 到哪算打到"的唯一读数）。
# 低配档只关前三类，"不表达判定的装饰"优先牺牲。
# =====================================================================

const PATH := "user://settings.cfg"

## 特效档位：FULL = 完整，LOW = 低配
enum Fx { FULL, LOW }

## 低配档会关掉的表现（顺序即"牺牲优先级"，v7 §5.3）。
## 花灯波纹 / 铜锣冲击环**不在这个表里**：它们是判定读数，不是装饰。
const LOW_OFF: Array[String] = ["phone_ghost", "lantern_stream", "molten_scatter", "stall_props"]

var fx_level: int = Fx.FULL
## 震屏。本作只有 Boss 登场与震吼用，关掉不影响判定。
var shake: bool = true
## 情境提示（L-07）。关掉只影响局内提示，不影响开场三页。
var tips: bool = true
## 音乐 / 音效音量（线性 0..1）。默认值按"能听清但不盖过判定"取：
## 音效要能在一百只怪里分辨，所以略高于音乐。
var music_volume: float = 0.8
var sfx_volume: float = 0.9

func _ready() -> void:
	load_cfg()

# ---------------------------------------------------------------- IO
func load_cfg() -> void:
	fx_level = Fx.FULL
	shake = true
	tips = true
	music_volume = 0.8
	sfx_volume = 0.9
	if not FileAccess.file_exists(PATH):
		return
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d: Dictionary = {}
	# 手写 key=value 而不是 JSON：settings.cfg 是玩家真会拿记事本打开的文件，
	# 一行一项比一段 JSON 好读好改，也没有"少一个引号整份失效"的风险。
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line == "" or line.begins_with("#") or not line.contains("="):
			continue
		var k: String = line.get_slice("=", 0).strip_edges()
		var v: String = line.get_slice("=", 1).strip_edges()
		d[k] = v
	f.close()
	fx_level = clampi(int(d.get("fx_level", Fx.FULL)), Fx.FULL, Fx.LOW)
	shake = String(d.get("shake", "1")) != "0"
	tips = String(d.get("tips", "1")) != "0"
	music_volume = clampf(float(d.get("music", "0.8")), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx", "0.9")), 0.0, 1.0)

func save_cfg() -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: 无法写入 %s（error %d）" % [PATH, FileAccess.get_open_error()])
		return
	f.store_line("# 《守艺人·百工夜行》设置。删掉这个文件 = 恢复默认。")
	f.store_line("fx_level=%d" % fx_level)
	f.store_line("shake=%d" % (1 if shake else 0))
	f.store_line("tips=%d" % (1 if tips else 0))
	f.store_line("music=%.2f" % music_volume)
	f.store_line("sfx=%.2f" % sfx_volume)
	f.close()

# ---------------------------------------------------------------- 查询
## 某类表现现在该不该开。低配档下只有 LOW_OFF 里的会被关掉。
func fx_on(feature: String) -> bool:
	if fx_level == Fx.FULL:
		return true
	return not (feature in LOW_OFF)

func is_low() -> bool:
	return fx_level == Fx.LOW

# ---------------------------------------------------------------- 变更
func set_fx_level(v: int) -> void:
	fx_level = clampi(v, Fx.FULL, Fx.LOW)
	save_cfg()

func set_shake(v: bool) -> void:
	shake = v
	save_cfg()

func set_tips(v: bool) -> void:
	tips = v
	save_cfg()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	save_cfg()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	save_cfg()

## 测试用：不改磁盘、只改内存态，测完用它还原。
func debug_set(fx: int, sh: bool, tp: bool) -> void:
	fx_level = clampi(fx, Fx.FULL, Fx.LOW)
	shake = sh
	tips = tp

func reset_defaults() -> void:
	debug_set(Fx.FULL, true, true)
	music_volume = 0.8
	sfx_volume = 0.9
	save_cfg()
