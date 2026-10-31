extends Node2D
class_name GarlicRing

# 光环/领域武器（halo）的可见范围：贴图 halo_ring.svg 是 256px 直径的环，
# 缩放后与 WeaponManager.halo_radius() 的实际判定半径严格一致——
# 让玩家"看得见自己的领域有多大"，这是走位决策的唯一依据。

const TEX_DIAMETER := 256.0
const BEAT_TIME := 0.32
## 水波纹每圈往外推的间隔（秒）。写法是"频率"而不是"计时器"：
## 环由 shader 的 TIME 连续驱动，不需要脚本每 0.6s 去发射一次 ——
## 用计时器的话暂停时环会停住、恢复时又一次性补发好几圈。
const RIPPLE_INTERVAL := 0.60

@onready var ring: Sprite2D = $Ring

var radius := 0.0
var pulse := 0.0
## 领域能量场（aura_field）。常驻、边转边呼吸，和"法阵"是一次性预警的语义区分开。
var _field: ColorRect = null
## 范围水波纹（area_ripple）。**第二层**，不替换边带：
## 边带负责"边界在哪"（走位依据），波纹负责"圈里在一直烧"（伤害依据）。
var _ripple: ColorRect = null
## 走马灯流光（lantern_stream）。**只在 Lv8 觉醒时可见**，见 set_awakened()。
var _stream: ColorRect = null
## 是否已满级觉醒（走马灯流光的开关）
var _awakened := false

func _ready() -> void:
	visible = false
	ring.texture = Art.tex(Art.HALO_RING)
	# 花灯是暖色的，能量场跟着武器配色走，别用默认的橙（那是火系的色）
	# v6：swirl 0.55 → 1.15。原本的环流转得很慢，边缘读作"雾"；v6 §6 要的是
	# "灯晕实化为旋转光环"，转速得翻一倍才看得出**方向**（雾是没有方向的）。
	_field = ShaderFX.field(self, 1.0, Color(1.0, 0.78, 0.42), 1.15)
	# aura_field 的默认参数是给"大面积领域"调的（inner 0.62 / intensity 0.9）。
	# v6 §5 要求"由贴边窄带改为填充内部"，但**不能真填满**：
	# 玩家就站在场正中间，填满内部等于把"我在哪"和"边圈在哪"两个走位信息一起盖掉
	# （这是上一轮用截图否掉过的方案）。所以取中间态 —— inner 0.80 → 0.62：
	# 亮带厚度翻倍、读作一圈实化的灯晕，中心 62% 仍然干净。
	var fm: ShaderMaterial = _field.material as ShaderMaterial
	if fm != null:
		fm.set_shader_parameter("inner", 0.62)
		fm.set_shader_parameter("outer", 1.00)
		fm.set_shader_parameter("softness", 0.20)
		fm.set_shader_parameter("intensity", 0.52)
		fm.set_shader_parameter("streak", 0.34)
	# 波纹铺满整个领域：它要表达的正是"内部在烧"，压成窄带就退化成第二条边带。
	# 参数是照着**实测截图**调的，不是拍脑袋：
	#   边带那圈暖金本来就有一大片柔光，波纹如果只比它"稍微亮一点"，
	#   加法混合下会整片糊成同一个亮色，等于看不见（第一版 intensity 0.52 就是这样）。
	#   所以走"多而锐"：3 圈 + 锋面收到 7（第一版 1.6 圈其实只落下一条弧，
	#   圈数越少 → 半径方向的间距越大 → 能看见的弧越少，这个方向我一开始弄反了）。
	_ripple = ShaderFX.ripple(self, 1.0, Color(1.0, 0.5, 0.18), 3.0, 1.0 / RIPPLE_INTERVAL, 0.8)
	var rm: ShaderMaterial = _ripple.material as ShaderMaterial
	if rm != null:
		rm.set_shader_parameter("wave_power", 7.0)
	# 走马灯流光：Lv8 才显示（默认隐藏，等级由 Player 每帧同步过来）
	_stream = ShaderFX.lantern_stream(self, 1.0, Color(1.0, 0.78, 0.32))
	_stream.visible = false
	# 绘制顺序（同层子节点按树序）：能量场 → 波纹 → 走马灯 → 光圈。
	# 光圈最后画：判定的边界（那圈实线）是玩家走位的唯一依据，任何东西都不能盖住它。
	move_child(_field, 0)
	move_child(_ripple, 1)
	move_child(_stream, 2)

func set_radius(r: float) -> void:
	if is_equal_approx(r, radius):
		return
	radius = r
	var s: float = (r * 2.0) / TEX_DIAMETER
	ring.scale = Vector2(s, s)
	# 能量场直接按世界像素给尺寸，不走 ring 的贴图缩放
	ShaderFX.field_resize(_field, r * 2.0)
	ShaderFX.ripple_resize(_ripple, r * 2.0)
	ShaderFX.lantern_stream_resize(_stream, r * 2.0)
	queue_redraw()

## 满级觉醒开关（v6 §6：场边缘走马灯流光）。
## 为什么只有 Lv8 才有：这是"升满"这一刻唯一的新东西。
## 常驻从 Lv1 就转的话，满级那一秒画面没有任何变化，觉醒就读不出来。
func set_awakened(on: bool) -> void:
	if on == _awakened:
		return
	_awakened = on
	# 只管自己的开关：父节点（GarlicRing）不可见时子节点本来就不画，
	# 这里再去乘一次 visible 会让"卸下花灯又装回来"时流光永久消失。
	_stream.visible = on

## 每次光环真正命中目标时调用，给一圈明暗呼吸
func beat() -> void:
	pulse = 1.0
	# 判定命中时本来就有一个视觉反馈，这里把它放大一档：
	# 光圈"跳"一下是玩家唯一能确认"刚才真的打到了"的信号。
	ShaderFX.field_beat(_field)
	# 波纹单独一跳：连续环说"一直在烧"，这一跳说"刚才打中了"，两种语义分开
	ShaderFX.ripple_pulse(_ripple)
	# 走马灯只改 intensity 再回落，不新建节点：0.44s 一次的命中节奏下，
	# "每次都新建一个 ColorRect"很快就把节点数推上去。
	ShaderFX.lantern_stream_beat(_stream)

func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(0.0, pulse - delta / BEAT_TIME)
		# 贴图本身已带圈，只叠一层极淡的填充，避免遮挡脚下角色
		queue_redraw()
		ring.modulate = Color(1.0, 1.0, 1.0, 0.55 + 0.45 * pulse)
	elif not is_equal_approx(ring.modulate.a, 1.0):
		ring.modulate = Color.WHITE
		queue_redraw()

func _draw() -> void:
	if radius <= 0.0 or pulse <= 0.0:
		return
	# 命中脉冲：一层内收的光晕
	draw_circle(Vector2.ZERO, radius * (0.96 + 0.04 * pulse), Color(0.32, 0.88, 0.84, 0.07 * pulse))
