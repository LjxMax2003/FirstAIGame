extends Node

# 全局属性字典：本局数值。
# 注意：autoload 脚本不写 class_name（4.7 会报 Class "X" hides an autoload singleton）。

const BASE_HP := 100.0

## 帧率上限。与 project.godot 的 application/run/max_fps 是同一个值，
## 这里再写一遍是**兜底**：project.godot 被编辑器重写、或被人手改成 0 时，
## 运行时仍然守住 60。
##
## 为什么必须是 60（实测，不是拍的）：
##   P5Perf 扫描 400 同屏单帧 11.44ms / P95 12.96ms。不限帧时 fps 会被 vsync 钉到屏幕刷新率，
##   144Hz 屏上单帧预算只有 6.9ms —— 密度一过 250 只（实测 7.09ms）就开始丢 vsync，
##   表现为"人越多越卡、但帧率数字看着还行"的间歇性卡顿。
##   压到 60 之后预算 16.6ms，400 只用掉 69%，留 31% 余量。
const MAX_FPS := 60

var stats: Dictionary = {}
var player: Node2D
var weapons: Node2D
var started := false

# ---------------------------------------------------------------- v7.1 起始武器保底（T9）
## 本局角色的起始武器 id。升级三选一用它做"前三次必出"的保底 ——
## 玩家选了铁花匠却在前三次抽卡里抽不到打铁花，会直接读成"我选的角色没用"。
var start_weapon: String = ""
## 还剩几次三选一允许把起始武器塞进候选。开局 3，抽一次减一次。
var pity_left: int = 0

func _ready() -> void:
	# 性能测试工具要测"不限帧时的真实单帧耗时"，会自己把这条改回 0。
	Engine.max_fps = MAX_FPS

## 开局复位。字典一律从 Stats.make_base() 生成，不在这里手抄一份 ——
## 阶段四加了局外 Meta 乘数之后，手抄的那份会漏掉加成（这正是"买了 Power Up 却没生效"的经典成因）。
func reset() -> void:
	stats = Stats.make_base()
	started = false

## 真正开局：血量回满 + 打开逻辑开关（重开也走这里，避免"带着尸体血量开局"）
func on_started() -> void:
	stats["hp"] = float(stats.get("max_hp", BASE_HP))
	started = true
