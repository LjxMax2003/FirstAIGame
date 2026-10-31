extends RefCounted
class_name ShaderFX

# ============================================================================
# 视觉特效统一入口 —— 把 assets/shaders/fx/ 下的 14 个 shader 包成一句调用
#   · 战斗反馈 7 个：assets/shaders/fx/
#   · 技能表现 7 个：assets/shaders/fx/skill/（发动 / 等级区分 / 持续表现 / 觉醒）
#     v6 新增：molten_scatter（铁水火星）、lantern_stream（走马灯流光）
# ----------------------------------------------------------------------------
# 设计前提（很重要，改之前先读）：
#   一个 CanvasItem 只能挂一个 ShaderMaterial，而本项目已经有三处占用了它
#   （Enemy 的快速怪描边、HpBar、各类 UI）。所以这里统一做三件事：
#     1. 进特效前把原材质存进 meta，出特效后原样还回去；
#     2. 每个节点按 shader 缓存材质，反复受击不会反复 new（池化敌人 100+ 只）；
#     3. 同一个节点上重叠的特效先 kill 掉上一条 tween，避免两个动画抢同一个 uniform。
#
# 性能红线（与 Enemy.gd 现有做法保持一致）：
#   独立材质会让 CanvasItem 无法与同类合批 —— 同屏 100 只纸片怪如果每只都挂
#   hit_flash，等于 100 次 draw call。所以：
#     · 小怪群受击：继续用 art.modulate = HIT_COLOR（现在的写法是对的，0 额外成本）
#     · 精英 / Boss / 玩家 / 掉落物：用本工具（同屏数量 < 10，值这个钱）
#     · 小怪死亡：用现有的"放大 + modulate 淡出"，需要"化墨散去"时再按数量上限挑几只走 shader
# ============================================================================

const SHADER_HIT_FLASH := preload("res://assets/shaders/fx/hit_flash.gdshader")
const SHADER_DISSOLVE := preload("res://assets/shaders/fx/dissolve_spawn.gdshader")
const SHADER_SPRITE_GLOW := preload("res://assets/shaders/fx/sprite_glow.gdshader")
const SHADER_GLOW_AURA := preload("res://assets/shaders/fx/glow_aura.gdshader")
const SHADER_SHINE_SWEEP := preload("res://assets/shaders/fx/shine_sweep.gdshader")
const SHADER_HURT := preload("res://assets/shaders/fx/hurt_vignette.gdshader")
const SHADER_MAGIC_CIRCLE := preload("res://assets/shaders/fx/magic_circle.gdshader")

# 技能向（assets/shaders/fx/skill/）
const SHADER_SLASH_ARC := preload("res://assets/shaders/fx/skill/slash_arc.gdshader")
const SHADER_CAST_BURST := preload("res://assets/shaders/fx/skill/cast_burst.gdshader")
const SHADER_RANK_RIM := preload("res://assets/shaders/fx/skill/skill_rank_rim.gdshader")
const SHADER_AURA_FIELD := preload("res://assets/shaders/fx/skill/aura_field.gdshader")
const SHADER_TRAIL := preload("res://assets/shaders/fx/skill/projectile_trail.gdshader")
const SHADER_AREA_RIPPLE := preload("res://assets/shaders/fx/skill/area_ripple.gdshader")
# v6 新增（docs/design/v6_fx_art_plan.md §3.1 / §4）
const SHADER_MOLTEN_SCATTER := preload("res://assets/shaders/fx/skill/molten_scatter.gdshader")
const SHADER_LANTERN_STREAM := preload("res://assets/shaders/fx/skill/lantern_stream.gdshader")

const META_PREV := &"fx_prev_material"
const META_CACHE := &"fx_material_cache"
const META_TWEEN := &"fx_tween"

const HIT_COLOR := Color(1.0, 0.96, 0.86)

## 走马灯的常驻亮度。**只存一份**：beat() 要把亮度推高再"回落"，
## 回落值写死 0.9 就会和常驻值漂移（改了常驻忘了改回落 = 命中一次之后永久变暗）。
const LANTERN_BASE := 1.0


# --- 材质接管 ---------------------------------------------------------------

## 把 node 换成指定 shader 的材质；原材质存进 meta，detach() 时还原。
## 同一个节点反复调用不会重复创建材质（按 shader 路径缓存）。
static func attach(node: CanvasItem, shader: Shader) -> ShaderMaterial:
	var current: Material = node.material
	if current is ShaderMaterial and (current as ShaderMaterial).shader == shader:
		return current

	if not node.has_meta(META_PREV):
		node.set_meta(META_PREV, current)

	var mat: ShaderMaterial = _cached_mat(node, shader)
	node.material = mat
	return mat


## 还原 attach() 之前的材质。特效播完后调用。
static func detach(node: CanvasItem) -> void:
	if node.has_meta(META_PREV):
		node.material = node.get_meta(META_PREV)
		node.remove_meta(META_PREV)


## 池化对象出场时复位特效状态：杀掉还在跑的 tween、清掉 meta。
## ⚠️ 故意**不碰 node.material** —— 调用方（Enemy.setup / Gem.setup）随后会自己重设材质，
##    这里再去还原一次只会把上一次的旧材质盖回来。
## 为什么必须有它：池化对象寿命远长于一次特效。上一局被打断的溶解会留下一个 tween 和一组 meta，
## 复用出来时接着播，表现就是"看不见的怪打你"或"新怪一出场就是半透明的"。
static func clear(node: CanvasItem) -> void:
	if node.has_meta(META_TWEEN):
		var tw: Tween = node.get_meta(META_TWEEN)
		if tw != null and tw.is_valid():
			tw.kill()
		node.remove_meta(META_TWEEN)
	node.remove_meta(META_PREV)
	node.remove_meta(META_CACHE)


static func _cached_mat(node: CanvasItem, shader: Shader) -> ShaderMaterial:
	var cache: Dictionary = node.get_meta(META_CACHE, {})
	var key: String = shader.resource_path
	if cache.has(key):
		return cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = shader
	cache[key] = mat
	node.set_meta(META_CACHE, cache)
	return mat


## 一个节点同时只能跑一条特效 tween，新特效打断旧的
static func _new_tween(node: CanvasItem) -> Tween:
	if node.has_meta(META_TWEEN):
		var old: Tween = node.get_meta(META_TWEEN)
		if old != null and old.is_valid():
			old.kill()
	var tw: Tween = node.create_tween()
	node.set_meta(META_TWEEN, tw)
	return tw


# --- 受击 -------------------------------------------------------------------

## 受击闪光：1 帧内推到纯色，再在 duration 内退回原图。
## 自动继承原描边材质（快速怪的青色描边不会因为受击闪而消失）。
static func flash(node: CanvasItem, color: Color = HIT_COLOR, duration := 0.12, hold := 0.0) -> void:
	var prev: Material = node.material
	var mat: ShaderMaterial = attach(node, SHADER_HIT_FLASH)

	# 原材质如果是 outline.gdshader，把描边参数搬过来，视觉上零跳变
	if prev is ShaderMaterial:
		var prev_mat := prev as ShaderMaterial
		if prev_mat.shader != null and prev_mat.shader.resource_path.ends_with("outline.gdshader"):
			mat.set_shader_parameter("outline_color", prev_mat.get_shader_parameter("outline_color"))
			mat.set_shader_parameter("outline_width", prev_mat.get_shader_parameter("outline_width"))

	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("amount", 1.0)
	mat.set_shader_parameter("active", false)

	var tw: Tween = _new_tween(node)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("amount", v),
		1.0, 0.0, duration
	)
	# 闪完必须还原：不还原的话这个节点会永久挂在 hit_flash 材质上，
	# 白白掉出合批（同屏 100 只小怪的 draw call 就是这么涨起来的）。
	# 新一轮 flash() 会先 kill 掉这条 tween，所以中途再被打不会漏掉还原。
	tw.tween_callback(func() -> void: detach(node))


# --- 出现 / 消失 -------------------------------------------------------------

## 敌人 / 道具出场：噪声溶解从 0 推到 1，结束后还原原材质。
static func spawn_in(node: CanvasItem, duration := 0.35, restore := true) -> void:
	var mat: ShaderMaterial = attach(node, SHADER_DISSOLVE)
	mat.set_shader_parameter("progress", 0.0)
	var tw: Tween = _new_tween(node)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v),
		0.0, 1.0, duration
	)
	if restore:
		tw.tween_callback(func() -> void: detach(node))


## 死亡 / 拾取收走：噪声溶解从 1 推到 0。
## restore=false 时保持材质不动，适合"反正要 hide() 回收"的池化对象。
static func dissolve_out(node: CanvasItem, duration := 0.45, restore := true) -> void:
	var mat: ShaderMaterial = attach(node, SHADER_DISSOLVE)
	mat.set_shader_parameter("progress", 1.0)
	var tw: Tween = _new_tween(node)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v),
		1.0, 0.0, duration
	)
	if restore:
		tw.tween_callback(func() -> void: detach(node))


# --- 道具 / 技能 -------------------------------------------------------------

## 道具扫光一次（商店卡片、掉落物高光）。扫完还原材质。
static func sweep(node: CanvasItem, duration := 0.55, delay := 0.0) -> void:
	var mat: ShaderMaterial = attach(node, SHADER_SHINE_SWEEP)
	mat.set_shader_parameter("auto_speed", 0.0)
	var tw: Tween = _new_tween(node)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v),
		-0.2, 1.2, duration
	)
	tw.tween_callback(func() -> void: detach(node))


## 在地面画一个法阵（技能预警 / 召唤 / 传送）。返回的节点自己 queue_free() 收尾。
static func spawn_circle(parent: Node, diameter := 180.0, color := Color(0.95, 0.72, 0.36)) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_MAGIC_CIRCLE
	mat.set_shader_parameter("circle_color", color)
	mat.set_shader_parameter("appear", 0.0)
	rect.material = mat
	parent.add_child(rect)

	var tw: Tween = rect.create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("appear", v),
		0.0, 1.0, 0.3
	)
	return rect


## 给任意节点加一层"光"（篝火 / 精英底光 / 拾取高光）。挂在父节点下、位于本体背后。
static func add_aura(parent: Node, diameter := 120.0, color := Color(1.0, 0.72, 0.35)) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_GLOW_AURA
	mat.set_shader_parameter("glow_color", color)
	rect.material = mat
	parent.add_child(rect)
	return rect


## 道具"有用"的脉冲发光：挂上就一直亮，传 false 关闭。
static func set_item_glow(node: CanvasItem, on: bool, color := Color(1.0, 0.78, 0.32)) -> void:
	if on:
		var mat: ShaderMaterial = attach(node, SHADER_SPRITE_GLOW)
		mat.set_shader_parameter("glow_color", color)
	else:
		detach(node)


## 全场共用一份的"常亮发光"材质，专给**批量同类**对象用（灯花、铜钱这种满地都是的）。
##
## 为什么不能直接用 set_item_glow()：那个是按节点缓存材质，每颗宝石一份独立 ShaderMaterial，
## 于是 60 颗宝石 = 60 次 draw call（CanvasItem 靠"材质相同"合批）。
## 这里所有节点**共用同一个材质实例**，参数全场统一，合批照旧成立。
## 代价：无法给单颗单独调颜色/强度——灯花也确实不需要。
static func set_group_glow(node: CanvasItem, on: bool) -> void:
	if on:
		if _group_glow == null:
			_group_glow = ShaderMaterial.new()
			_group_glow.shader = SHADER_SPRITE_GLOW
			_group_glow.set_shader_parameter("glow_color", Color(1.0, 0.78, 0.32))
			_group_glow.set_shader_parameter("intensity", 1.8)
			_group_glow.set_shader_parameter("falloff", 1.0)
			# 满屏掉落时"呼吸"会变成一片闪烁的噪音，常亮更干净
			_group_glow.set_shader_parameter("pulse_amount", 0.0)
		node.material = _group_glow
	else:
		node.material = null

static var _group_glow: ShaderMaterial = null


# --- 玩家受伤 ---------------------------------------------------------------

## 全屏受伤红边：一次挂好材质，之后每帧只推 max_alpha。
##
## 为什么不像 hurt() 那样用 tween：HUD 的 hit_flash 本身就是一条连续衰减的曲线
## （Player 每帧 -= delta*3），两条动画去写同一个 uniform 会互相打架，
## 表现为"受击红边一顿一顿"。所以这里给"每帧直接设值"的口径。
##
## screen_size 必须等于项目 viewport（720x1280）：shader 用像素距离归一化，
## 尺寸对不上时竖屏的左右边会比上下厚 1.8 倍。
static func hurt_setup(rect: Control) -> ShaderMaterial:
	var mat: ShaderMaterial = attach(rect, SHADER_HURT)
	mat.set_shader_parameter("screen_size", Vector2(720.0, 1280.0))
	# pulse_amount = 0：红边强度完全由受击曲线决定，不需要它自己呼吸
	mat.set_shader_parameter("pulse_amount", 0.0)
	mat.set_shader_parameter("max_alpha", 0.0)
	# ColorRect 的 color 是顶点色，会乘进 shader 结果里。
	# 红边颜色由 shader 的 hurt_color 决定，节点自身必须调成纯白，否则红会叠红。
	rect.color = Color.WHITE
	return mat


## 每帧驱动受伤红边强度（0 = 完全不显示）。
static func hurt_drive(rect: Control, alpha: float) -> void:
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("max_alpha", clampf(alpha, 0.0, 1.0))


## 一次性受伤红边（带淡出）。与 hurt_drive() 二选一 —— 同一条 tween 会覆盖每帧写入。
static func hurt(rect: Control, strength := 0.8, duration := 0.5) -> void:
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat == null:
		return
	var tw: Tween = rect.create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("max_alpha", v),
		strength, 0.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ============================================================================
# 技能表现（assets/shaders/fx/skill/）
# ----------------------------------------------------------------------------
# 分三类，调用口径完全不同，别混用：
#   · 一次性演出   slash() / burst()  —— 返回或接管一个节点，自己 queue_free 收尾
#   · 常驻状态     set_rank() / set_trail() / field()  —— 挂上就一直在，改参数就行
#   · 持续场       field() 额外给 beat() 做"命中一跳"
# ============================================================================


# --- 技能：挥砍 -------------------------------------------------------------

## 挥砍弧光。**遮罩式**：挂在原有的弧光贴图上（Art.WHIP_ARC），只改"这一帧画到哪"，
## 不重新画弧，所以和现有画风零冲突。
##
## 为什么不能自己生成弧光：本作的弧光是一张 SVG（nuo_blade_arc.svg），边缘有笔触细节。
## 用 shader 从零画圆环会变成"霓虹灯管"，画风直接崩。所以这个 shader 只做遮挡。
##
## @param sprite   挂了 arc 贴图的 Sprite2D（WeaponManager 里 _take_fx 拿到的那个）
## @param duration 扫完一次的时间，刀类 0.10~0.14，重击 0.18
## @param flip     true = 反向挥（从左往右变从右往左）
## @param restore  true 时扫完还原原材质；池化对象传 false 省一次赋值
static func slash(sprite: CanvasItem, duration := 0.12, flip := false, restore := true) -> void:
	var mat: ShaderMaterial = attach(sprite, SHADER_SLASH_ARC)
	mat.set_shader_parameter("flip", flip)
	mat.set_shader_parameter("progress", 0.0)
	var tw: Tween = _new_tween(sprite)
	# 前半段快、后半段慢：刀锋出手瞬间极快，收尾的余势才是"重量感"的来源。
	# 匀速看起来像进度条。
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if restore:
		tw.tween_callback(func() -> void: detach(sprite))


# --- 技能：发动 -------------------------------------------------------------

## 发动冲击环（技能"出手"的那一帧）。返回的 ColorRect 自己 tween 完就 queue_free()。
##
## @param size    冲击环的外径（世界像素）。横扫传 Vector2(280, 90)
## @param squash  压扁比例。**这是和矩形判定对齐的关键**：whip 是 length × width 的矩形，
##                圆环会读错范围，squash = (1.7, 0.5) 才贴着判定框。
##                传 Vector2.ONE 就是正圆。
## @param rays    径向光条数，0 = 纯环（灯晕一跳），8~12 = 爆点
## @param gather  true 收拢（蓄力/进化预警），false 扩散（出招）
## @param duration 整段时长，出招 0.22~0.3，蓄力收拢 0.4
##
## ⚠️ 尺寸换算：shader 里的 squash 是在 UV 空间乘的，节点本身必须放大到
##    size * (1 / min(squash.x, squash.y))，否则椭圆的长轴会被节点矩形裁掉。
##    例：size (280,90)、squash (1.7,0.5) → 节点 560×180，椭圆正好填满。
static func burst(
	parent: Node,
	size := Vector2(200.0, 200.0),
	color := Color(1.0, 0.86, 0.55),
	squash := Vector2.ONE,
	rays := 0,
	gather := false,
	duration := 0.26,
	delay := 0.0
) -> ColorRect:
	# squash 乘的是半径方向的 UV，所以节点得按"最扁的那个轴"整体放大
	var scale_up: float = 1.0 / maxf(minf(squash.x, squash.y), 0.01)
	var node_size: Vector2 = size * scale_up

	var rect := ColorRect.new()
	rect.size = node_size
	rect.position = -node_size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# blend_add 已经会把暗部加没，ColorRect 自身必须是纯白，
	# 否则 color 会当顶点色乘进去，跟 burst_color 叠成脏色。
	rect.color = Color.WHITE

	var mat := ShaderMaterial.new()
	mat.shader = SHADER_CAST_BURST
	mat.set_shader_parameter("burst_color", color)
	mat.set_shader_parameter("squash", squash)
	mat.set_shader_parameter("rays", rays)
	mat.set_shader_parameter("gather", gather)
	mat.set_shader_parameter("progress", 0.0)
	rect.material = mat
	parent.add_child(rect)

	var tw: Tween = rect.create_tween()
	# 延迟段：给"回震"这类需要等主环先炸开再跟上的一次性演出用。
	# 用 tween 的 interval 而不是 timer：暂停时一起停，不会出现"暂停回来补发一圈"。
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(rect.queue_free)
	return rect


## 按**椭圆外径**生成冲击环：long_px / short_px 是要看见的实际直径（世界像素）。
##
## 为什么不直接调 burst() 传 squash —— 那个 squash 是 UV 空间的**除子**：
##   p = (UV - 0.5) * 2 / squash
## 传 squash.x > 1 会把 p.x 压小，等价于把椭圆在 x 方向**拉长到节点之外**，
## 于是长轴两端直接被节点矩形裁掉（文档 §3.6 的例子 (1.7, 0.5) 就有这个毛病，
## 且"把节点反向放大"并不能修：p 只跟 UV 有关，跟节点像素宽无关）。
## 这里固定 squash.x = 1、只用 y 表达长宽比，再反推节点边长，椭圆就完整落在节点内。
##
## ⚠️ 两段缩放必须一起算，少算一段椭圆就会大 (1/长宽比) 倍：
##   ① burst() 会把节点放大 1/min(squash)（为的是让椭圆不被节点边界切掉）；
##   ② 环半径 = 0.9 × 节点边（0.9 = shader 的 spread 默认值）。
##   所以节点边 = long ÷ 0.9，而节点边长又等于 size × (1/ratio)，
##   于是 size = long × ratio ÷ 0.9。
static func burst_ellipse(
	parent: Node,
	center: Vector2,
	long_px: float,
	short_px: float,
	color := Color(1.0, 0.86, 0.55),
	rays := 0,
	duration := 0.26,
	delay := 0.0,
	gather := false
) -> ColorRect:
	var ratio: float = clampf(short_px / maxf(long_px, 1.0), 0.04, 1.0)
	var want_edge: float = maxf(long_px, 8.0) / 0.9
	var node_edge: float = want_edge * ratio
	var rect: ColorRect = burst(parent, Vector2(node_edge, node_edge), color, Vector2(1.0, ratio), rays, gather, duration, delay)
	rect.global_position = center - rect.size * 0.5
	return rect


# --- 技能：等级区分（常驻） -------------------------------------------------

## 给武器槽 / 环绕体挂等级外框。**常驻**，不是一次性演出。
##
## 用法就一句：每次武器升级后调一次，传 WeaponManager.weapon_level(id)。
##   ShaderFX.set_rank(slot.icon, WeaponManager.weapon_level(id), WeaponManager.is_evolved(id))
##
## 为什么不逐级换贴图：MAX_LEVEL = 8、6 把武器 = 48 张图，美术成本不划算，
## 而玩家在战斗里也不会去读小数字。三档颜色（冷白 → 金 → 朱红）+ 三档厚度 + 流动
## 是"余光可读"的：不用看，扫一眼就知道哪把变金了。
##
## @param rank    1~8，中间值平滑过渡；Lv1~2 不出框（新手期不该有噪音）
## @param evolved 进化形态：无视 rank 直接最高档 + 高频呼吸
## @param rim_px  外框粗细，单位是**屏幕像素**（不是 shader 里的纹素）
static func set_rank(node: CanvasItem, rank: int, evolved := false, rim_px := 2.0) -> void:
	var mat: ShaderMaterial = attach(node, SHADER_RANK_RIM)
	mat.set_shader_parameter("rank", float(clampi(rank, 1, 8)))
	mat.set_shader_parameter("evolved", evolved)
	mat.set_shader_parameter("rim_width", _rim_texels(node, rim_px))


## 把"屏幕像素"换算成 shader 的纹素单位。
## 为什么必须换算：`rim_width` 乘的是 TEXTURE_PIXEL_SIZE，也就是**源贴图的纹素**。
## 武器槽图标只有 40px，但源图分辨率差 5 倍（糖画 48px、花灯 256px）——
## 同样传 2.0，48px 的图标框有 1.7 屏幕像素，256px 的花灯只剩 0.3 像素，
## 表现为"升到 Lv8 了却看不出来"，而且不报任何错。
static func _rim_texels(node: CanvasItem, rim_px: float) -> float:
	var tex: Texture2D = null
	var shown := 1.0
	if node is Sprite2D:
		var sp := node as Sprite2D
		tex = sp.texture
		if tex != null:
			# 显示宽度 = 源图宽 × |scale.x|（scale 已经被父节点折算过，这里只看自身）
			shown = maxf(absf(sp.scale.x) * float(tex.get_width()), 1.0)
	elif node is TextureRect:
		var tr := node as TextureRect
		tex = tr.texture
		shown = maxf(tr.size.x, 1.0)
	if tex == null:
		return clampf(rim_px, 0.5, 16.0)
	return clampf(rim_px * float(tex.get_width()) / shown, 0.5, 16.0)


## 关掉等级外框（武器被换下 / 退回初始形态）。
static func clear_rank(node: CanvasItem) -> void:
	detach(node)


# --- 技能：持续场（光环类） -------------------------------------------------

## 领域能量场（光环 / 毒圈 / 减速区）。挂在**范围圈贴图**上，不额外占节点。
##
## 和 spawn_circle()（法阵）的分工：
##   · magic_circle / spawn_circle = 一次性，出完就没，用来做预警
##   · aura_field / field        = 常驻，边转边呼吸，是"技能一直在这儿"的持续表达
##
## @param diameter 场直径，直接传 GarlicRing 的判定直径（TEX_DIAMETER 缩放后）
## @param color    场色
## @param swirl    环流速度，负值反向（同屏多个光环时反向能看出层次）
static func field(
	parent: Node,
	diameter := 200.0,
	color := Color(1.0, 0.72, 0.35),
	swirl := 0.55
) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	rect.color = Color.WHITE  # blend_add，顶点色必须纯白

	var mat := ShaderMaterial.new()
	mat.shader = SHADER_AURA_FIELD
	mat.set_shader_parameter("field_color", color)
	mat.set_shader_parameter("swirl_speed", swirl)
	mat.set_shader_parameter("beat", 0.0)
	rect.material = mat
	parent.add_child(rect)
	return rect


## 光环命中一跳：把 beat 推到 1 再衰减回 0。
## 接在 GarlicRing.beat() 里 —— 判定命中时本来就有一个视觉反馈，这里只是把它放大。
static func field_beat(rect: CanvasItem, duration := 0.18) -> void:
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat == null or mat.shader != SHADER_AURA_FIELD:
		return
	var tw: Tween = _new_tween(rect)
	mat.set_shader_parameter("beat", 1.0)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("beat", v),
		1.0, 0.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 改已有能量场的大小（升级加范围时用）。只改节点尺寸，shader 参数不用碰。
static func field_resize(rect: ColorRect, diameter: float) -> void:
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5


# --- 技能：范围水波纹（常驻） -----------------------------------------------

## 同心扩散环（area_ripple）。描述"这个圈里**一直在输出伤害**"。
##
## 和 field() 的分工（两个都要用，不是二选一）：
##   · field()      = 环流噪声，压成贴边窄带 → 告诉玩家"边界在哪"（走位依据）
##   · ripple()     = 同心环由内向外推    → 告诉玩家"圈内在挨打"（伤害依据）
##   只留边界会读成"一个圈"；只留波纹会把边界糊掉，玩家不知道自己是不是走出了范围。
##
## @param diameter 范围直径（世界像素）。传判定半径 × 2，波纹才和实际伤害区严格对齐
## @param rings    半径方向上的圈数。2 在 110px 半径下大约每 55px 一道，够读不吵
## @param speed    每秒往外推几圈。**这是"发射频率"的唯一来源** —— 1.6 ≈ 每 0.6s 一圈
## @param intensity 亮度。花灯这种常驻大面积用 0.5 上下；再亮会盖住脚下角色
##
## ⚠️ 常驻节点：一个 GarlicRing / 一个 WeaponManager 各一份，别给敌人逐只挂
##    （同屏 200 只小怪逐只挂 ShaderMaterial = 200 次 draw call，合批直接没了）。
static func ripple(
	parent: Node,
	diameter := 200.0,
	color := Color(1.0, 0.62, 0.30),
	rings := 2.0,
	speed := 1.6,
	intensity := 0.55
) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	# blend_add 会把暗部加没，顶点色必须是纯白，否则它会当乘数把环染脏
	rect.color = Color.WHITE

	var mat := ShaderMaterial.new()
	mat.shader = SHADER_AREA_RIPPLE
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("ring_color", color)
	mat.set_shader_parameter("rings", rings)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("pulse", 0.0)
	rect.material = mat
	parent.add_child(rect)
	return rect


## 改已有波纹的大小（升级加范围时用）。
## rect_size 必须一起改：shader 靠它做短边归一化，只改节点尺寸会让环变椭圆。
static func ripple_resize(rect: ColorRect, diameter: float) -> void:
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat != null and mat.shader == SHADER_AREA_RIPPLE:
		mat.set_shader_parameter("rect_size", rect.size)


## 命中一跳：把 pulse 推到 1 再衰减回 0。接在 GarlicRing.beat() 里。
## 和连续环是**叠加**关系，不是替代：连续环说"一直在烧"，这一跳说"刚才打中了"。
static func ripple_pulse(rect: CanvasItem, duration := 0.22) -> void:
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat == null or mat.shader != SHADER_AREA_RIPPLE:
		return
	var tw: Tween = _new_tween(rect)
	mat.set_shader_parameter("pulse", 1.0)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("pulse", v),
		1.0, 0.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- 技能：一次性冲击波（敲击类乐器） ---------------------------------------

## 敲下去的"咚"：主冲击环 + 一记回震。
##
## **和 ripple() 是相反的语义，别混用** —— 这一条就是为了让铜锣和花灯不糊在一起：
##   · ripple()    持续、多道、一直往外推  → "这个圈里一直在输出"
##   · shockwave() 一次性、单道、炸开之后有一圈往回缩 → "刚才敲了一下"
##
## 两者外轮廓都是圆环，所以**只换颜色不够**。真正让人一眼分出来的是：
## 径向声波刺（花灯是光滑环）+ 回震往内收（花灯的环永远只往外推）。
## 颜色只是第三层保险。
##
## @param diameter 冲击波外径（世界像素），传武器判定半径 × 2 才和实际伤害区对齐
## @param rays     径向声波刺数量。**0 会退回纯环、重新和花灯撞车**，敲击类给 12~20
## @param duration 主环时长。敲击要脆：0.26~0.32，不要超过 0.4（超过就变成"领域"了）
static func shockwave(
	parent: Node,
	center: Vector2,
	diameter: float,
	color := Color(1.0, 0.97, 0.82),
	rays := 16,
	duration := 0.30
) -> ColorRect:
	# ① 主冲击环：**薄**锋面 + 声波刺。
	#    width 是相对当前半径的比例（不是像素），所以 0.20 在半径 200px 时等于
	#    一条 80px 厚的带子 —— 环形被填成实心圆盘，截图里就是"一坨光"。
	#    0.075 才读得出"一圈正在扩散的声波"。
	#    中心亮核必须关掉 —— 中心留给乐器本体（锣面），两处都亮会糊成一个亮球。
	var wave: ColorRect = burst_ellipse(parent, center, diameter, diameter, color, rays, duration)
	# 贴地：冲击波是"从地上荡过去"的，压在玩家和乐器本体之下（Player 在 -1）
	wave.z_index = -3
	var m: ShaderMaterial = wave.material as ShaderMaterial
	if m != null:
		m.set_shader_parameter("width", 0.085)
		m.set_shader_parameter("core", 0.0)
		# 3.2 而不是 1.5：rays > 0 时 spokes 是在 mix(0.28, 1.0, ...) 里取的，
		# 刺与刺之间只有 0.28 的亮度，再乘 env（progress 0.5 时约 0.4）就只剩 1 成，
		# 在深蓝地面上直接看不见 —— 环会"消失"，只剩中间的锣面。
		m.set_shader_parameter("intensity", 3.2)
		m.set_shader_parameter("ray_sharp", 3.5)
		# 敲击要"一上来就很响、拖到最后才收"，所以衰减比默认 1.2 慢一档
		m.set_shader_parameter("fade_pow", 0.9)

	# ② 回震：晚 0.09s，从 68% 半径**向内**收。
	#    冷白而不是暖金 —— 声音在空气里传，和乐器本身的金属暖色分开；
	#    更关键的是方向：这是花灯**永远不会出现**的运动，也是"这是敲锣"的锚点。
	# 0.85 而不是 0.68：回震是"撞到范围的边界弹回来"，起点得贴着判定边。
	# 放太里面会和锣面挤在一起，读成一个"镶银边的金盘"。
	var echo: ColorRect = burst_ellipse(
		parent, center, diameter * 0.85, diameter * 0.85,
		Color(0.90, 0.98, 1.0), 0, duration * 0.82, 0.12, true
	)
	echo.z_index = -3
	var em: ShaderMaterial = echo.material as ShaderMaterial
	if em != null:
		em.set_shader_parameter("width", 0.06)
		em.set_shader_parameter("core", 0.0)
		# 0.75 而不是 1.0：回震是**余韵**，不该比乐器本体更抢眼。
		# 实测 1.0 时整张截图里最亮的是那圈冷白，锣面反而沉下去了。
		em.set_shader_parameter("intensity", 0.75)
	# 返回主环而不是 void：验收要能读回 rays / width 这些参数，
	# 否则"铜锣带声波刺"这条契约只能靠肉眼看截图（等于没法回归）。
	return wave


# --- 技能：铁水散射（打铁花 v6 签名） ---------------------------------------

## 铁水团砸开：一团熔铁散成一片火星。**一次性演出**，播完自己 queue_free()。
##
## 和 burst()/shockwave() 的分工（三种完全不同的形状语言，别互相替代）：
##   · burst()      一条干净环   → "技能出手了"
##   · shockwave()  带声波刺的环 + 回震 → "敲了一下"（铜锣）
##   · molten_scatter 没有环，只有一堆各自往外飞的亮点 → "铁水溅开了"（打铁花）
##
## @param radius_px 溅射半径，**必须传实际结算半径**（`scatter_radius × area`），
##                  否则玩家会按火星的范围去走位，而伤害在别处。
## @param duration  整段时长，0.35~0.5。短于 0.3 读不出"溅开"，长于 0.6 会挡视线
## @return 节点本身（验收要读回 radius / sparks 这些参数，否则契约只能靠肉眼看图）
##
## ⚠️ z_index = -2：铁水是**溅在地上**的，要压在怪物(0)和玩家(-1)之下、资源点(-3)之上。
##    放最上层会变成一张挡住所有人的橙色大饼 —— 这是"看得见伤害还是看得见战场"的取舍，
##    本工程一律选后者（同铜锣锣面落 -2 的理由）。
static func molten_scatter(
	parent: Node,
	center: Vector2,
	radius_px := 150.0,
	color := Color(1.0, 0.48, 0.10),
	duration := 0.42
) -> ColorRect:
	# 节点边长 = 2×半径；shader 的 radius 是 0.95（火星外缘落在节点内 5% 处，
	# 不会被矩形边界切掉一条边）。所以"看得见的火星锋面"约等于判定半径的 95%，
	# 有意**略小于**伤害半径 —— 宁可少画一点，也不能让玩家以为圈外也挨打。
	var edge: float = maxf(radius_px, 8.0) * 2.0
	var rect := ColorRect.new()
	rect.size = Vector2(edge, edge)
	rect.position = -rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	# blend_add 下顶点色是乘数，必须是纯白，否则火星会被染脏
	rect.color = Color.WHITE
	# z = 1：压在怪物(0)之上、拾取物(2)之下。
	# 一开始放在 -2（"铁水溅在地上"），实测被怪堆挡掉大半 ——
	# 打铁花的签名是"漫天火星"，火星必须看得见；遮住玩家的问题不存在，
	# 因为爆点在命中处而不是玩家脚下（铜锣锣面要 -2 是另一回事）。
	rect.z_index = 1

	var mat := ShaderMaterial.new()
	mat.shader = SHADER_MOLTEN_SCATTER
	# rect_size 必须在这里写一次：shader 靠它做短边归一化，
	# 不写就是默认 300×300，半径一变火星就变椭圆（同 area_ripple 的坑）。
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("scatter_color", color)
	# spread 从清单默认的 0.85 提到 1.0：火星锋面 = spread × radius = 0.85 × 0.95，
	# 只到判定半径的 81% —— 玩家按火星判断会被"看不见的 19% 边缘"白打，
	# 而这正是"特效要跟伤害逻辑对齐"的底线。提到 1.0 后锋面落在 0.95r，
	# 仍留 5% 余量不被节点矩形切边。
	mat.set_shader_parameter("spread", 1.0)
	# 1.5 是清单允许的上限（未开 HDR2D 超过 1.6 会过曝）。
	# 1.4 在深蓝地面上偏灰，火星只剩"几粒金点"，读不出"散成一片"。
	mat.set_shader_parameter("intensity", 1.5)
	mat.set_shader_parameter("pulse", 1.0)
	mat.set_shader_parameter("pulse_boost", 1.0)
	rect.material = mat
	parent.add_child(rect)
	rect.global_position = center - rect.size * 0.5

	# pulse 1 → 0：整片亮度衰减，但 shader 里的 TIME 继续推火星往外飞，
	# 所以看起来是"光暗下去了、火星还在飘"，而不是"整张图淡出"。
	var tw: Tween = rect.create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("pulse", v),
		1.0, 0.0, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(rect.queue_free)
	return rect


## 一次性屏幕光晕（打铁花炸开时整块画面亮一下）。
##
## 为什么不用 hurt_vignette：那是"我受伤了"的语言，红色从四边侵蚀进来。
## 这里要的是**局部**爆点的暖光溢满屏幕，中心亮、四角暗，属 glow_aura 的用法。
## modulate 淡出而不是改 shader 参数：一次演出不需要常驻状态。
static func flash_glow(
	parent: Node,
	center: Vector2,
	diameter := 560.0,
	color := Color(1.0, 0.62, 0.26),
	duration := 0.30
) -> ColorRect:
	var rect: ColorRect = add_aura(parent, diameter, color)
	rect.z_index = -6   # 压在道具/资源点之上、场景光之下：只加光，不挡任何实体
	rect.global_position = center - rect.size * 0.5
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat != null:
		# ⚠️ radius + softness 必须 ≤ 1.0。glow_aura 用 outer = radius + softness 做衰减分母，
		#    超过 1.0 时节点边缘还剩 0.13 的亮度 —— 于是矩形边界被画成一个**硬圆环**，
		#    看起来像"又一个声波圈"而不是光晕（第一版 0.62 + 0.95 就是这样）。
		mat.set_shader_parameter("radius", 0.45)
		mat.set_shader_parameter("softness", 0.55)
		mat.set_shader_parameter("intensity", 0.9)
		# 这个光晕是"爆开的一瞬"，不该自己呼吸；呼吸会和 pulse 衰减叠成两套节拍
		mat.set_shader_parameter("pulse_amount", 0.0)
		mat.set_shader_parameter("wobble", 0.0)
	rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, duration * 0.30)
	tw.tween_property(rect, "modulate:a", 0.0, duration * 0.70)
	tw.tween_callback(rect.queue_free)
	return rect


# --- 技能：走马灯流光（花灯 Lv8 觉醒） --------------------------------------

## 花灯满级后，范围场边缘巡游的一圈金亮带。
##
## **只在 Lv8 出现**：v6 §6 把"场边缘走马灯流光"列为觉醒钩子。
## Lv1 就转的话，满级那一刻没有任何变化，"升满"读不出来（这也是本作
## 一贯的取舍：常驻的噪音要留给状态，一次性/里程碑才配用旋转）。
##
## @param diameter 花灯判定直径（世界像素），传半径 × 2
static func lantern_stream(
	parent: Node,
	diameter := 200.0,
	color := Color(1.0, 0.78, 0.32)
) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	rect.color = Color.WHITE          # blend_add，顶点色必须纯白

	var mat := ShaderMaterial.new()
	mat.shader = SHADER_LANTERN_STREAM
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("lantern_color", color)
	mat.set_shader_parameter("intensity", LANTERN_BASE)
	rect.material = mat
	parent.add_child(rect)
	return rect


## 改走马灯直径（升级加范围 / 满级瞬间第一次显示）。
static func lantern_stream_resize(rect: ColorRect, diameter: float) -> void:
	rect.size = Vector2(diameter, diameter)
	rect.position = -rect.size * 0.5
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat != null and mat.shader == SHADER_LANTERN_STREAM:
		mat.set_shader_parameter("rect_size", rect.size)


## 命中一跳：亮带整体亮一下再回到常驻亮度。
## 注意是**改 intensity 再回 0.9**，不是新建节点 —— 常驻表现每次命中都新建
## 一个 ColorRect，0.44s 一次的节奏下很快就会把 GC 拖起来。
static func lantern_stream_beat(rect: CanvasItem, duration := 0.20) -> void:
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat == null or mat.shader != SHADER_LANTERN_STREAM:
		return
	var tw: Tween = _new_tween(rect)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("intensity", v),
		LANTERN_BASE * 1.7, LANTERN_BASE, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- 技能：弹道拖尾（常驻） -------------------------------------------------

## 弹道辉光尾（糖丝、飞刀、泼出去的符纸都适用）。挂上就一直有，跟着本体转。
##
## axis 为什么是 int 不是 Vector2：这个 shader 是**在贴图自身 UV 里**拖尾的，
## 一旦用一个 vec2 方向去乘，就会和节点的 rotation 打架（转了 90° 后尾巴横着飞）。
## 只在"未旋转的贴图坐标系"里选四条轴，让它跟着 sprite 自己转，更稳。
##
## @param axis 0 = +X（向右飞，sprite 默认朝向）  1 = -X   2 = +Y   3 = -Y
##
## ⚠️ 合批代价：和 set_item_glow() 一样是**每节点一份独立材质**。
##    糖丝/飞刀同屏一般 < 20，可以接受；但 "泼射" 类一次打 40+ 发就别逐发挂，
##    要么共用一份（不接受逐发变色的话），要么只给最前排挂。
static func set_trail(node: CanvasItem, axis := 0, color := Color(1.0, 0.86, 0.55)) -> void:
	var mat: ShaderMaterial = attach(node, SHADER_TRAIL)
	mat.set_shader_parameter("axis", clampi(axis, 0, 3))
	mat.set_shader_parameter("trail_color", color)


## 关掉拖尾（弹道落地 / 回收进池）。
static func clear_trail(node: CanvasItem) -> void:
	detach(node)
