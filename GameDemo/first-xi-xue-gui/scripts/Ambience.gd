extends Node
class_name Ambience

## v9 C1：环境层（暗角 / 远景视差 / 灯晕）。
##
## 【为什么是 Node + 两个 CanvasLayer，而不是一个 Node2D】
## 这一层同时有两种坐标系的东西：
##   · 远景剪影 —— **世界坐标**，要随镜头反向漂移（视差）
##   · 暗角 + 灯晕 —— **屏幕坐标**，必须钉在屏幕上，镜头走到哪都不动
## 塞进同一个节点就只能选一种。这里用两个子层各管一种：
##   WorldLayer  : z_index=-6，参与 World 的层级排序（Ground -10 之上、Resources -3 之下）
##   ScreenLayer : CanvasLayer，跟随屏幕，固定压在画面最前但**不吃输入**
##
## ⚠️ 【这里踩过一个真坑，别退回去】
## 初版把暗角也做成 Sprite2D 挂在 World 下。错在：World 里的 Sprite2D 会跟着
## Camera2D 一起平移，于是暗角会跟着镜头跑 —— 表现为"四角一直不暗，但屏幕中间
## 偶尔有一团黑"。屏幕感受必须用 CanvasLayer，不能用世界内的节点。
##
## 【为什么暗角不用 ShaderMaterial】
## 径向渐变是一张代码生成的 ImageTexture，纯靠 modulate.a + scale 摆位。
## 不挂材质 → 不破合批、不需要 SCREEN_TEXTURE（Mobile 渲染器下禁用）。
## 整个环境层 3 个 draw call（远景 1 / 暗角 1 / 灯晕 1），预算上限 23。

# ---------------------------------------------------------------- 暗角
## 内半径 / 外半径（相对屏幕短边的一半）。
## 0.34 是"完全不暗"的边界，1.06 是"最暗"的边界 —— 外半径**故意超过 1.0**，
## 让最暗处落在屏幕四角外面，否则四角会出现一块死黑的方块。
const R_INNER := 0.34
const R_OUTER := 1.06
## 最暗处透明度。0.42 = 读得出压暗、但角落里的敌人仍可见的上限。
## 实测 0.55 时边角杂兵会彻底融进背景，等于"看不见的目标在打你"。
const ALPHA_FULL := 0.42
## 低配档比例。不是关掉（关掉画面会突然"变平"，两档像两个游戏），是减到 60%。
const LOW_RATIO := 0.60

# ---------------------------------------------------------------- 远景视差
## 反向漂移比例。镜头走 100px，远景走 6px。
## 超过 0.12 远景会明显脱离地面，读成"背景在滑"而不是"远处的东西视差位移"。
const PARALLAX_RATIO := 0.06
## 出血余量（相对屏幕尺寸）。视差会整体偏移，不留余量时边缘会露出空白。
const BLEED := 0.06

# ---------------------------------------------------------------- 灯晕
## 呼吸周期。4.2s 接近"人正常呼吸稍慢"，比 2s 更像夜里的灯而不是在闪。
const LAMP_PERIOD := 4.2
const LAMP_ALPHA_BASE := 0.22
const LAMP_ALPHA_AMP := 0.10

var _near: Node2D = null
var _screen: CanvasLayer = null
var _vignette: TextureRect = null
var _far: Sprite2D = null
var _lamps: Control = null
var _lamp_sprites: Array[Sprite2D] = []
var _t := 0.0

var _cam: Camera2D = null
var _base := Vector2(720, 1280)
## 视差累计偏移。用累计而不是直接由镜头位置算：镜头有平滑抖动，直接乘会让远景抖。
var _scroll := Vector2.ZERO

func _ready() -> void:
	# 近景层：世界坐标，参与 World 排序
	_near = Node2D.new()
	_near.name = "Near"
	_near.z_index = -6
	add_child(_near)
	# 屏幕层：钉住屏幕。layer 取 0 —— 要压在世界之上、HUD（layer 10）之下。
	# 但注意：CanvasLayer 的 0 会压住整个默认 canvas（含 World），这正是我们要的
	# （暗角必须在敌人之上，否则暗角被敌人盖住）。HUD 在 layer=10 仍然在它上面。
	_screen = CanvasLayer.new()
	_screen.name = "Screen"
	_screen.layer = 0
	add_child(_screen)

## 由 Game 注入。不自己 get_node：与 Player.active_skill 同一条依赖注入约定，
## 才能在测试里单独实例化。
func bind(cam: Camera2D, view_size: Vector2) -> void:
	_cam = cam
	_base = view_size
	_build(view_size)

func _build(view: Vector2) -> void:
	if _vignette != null:
		return
	# ---- 远景剪影（世界坐标，会视差漂移）
	_far = Sprite2D.new()
	_far.name = "Far"
	_far.texture = _make_far_tex()
	_far.centered = true
	_far.scale = Vector2.ONE * 4.0
	# 铺在视差层最底下，但仍在 Ground(-10) 之上 —— 它就是"比地面更远的一层"。
	_far.modulate = Color(1, 1, 1, 1)
	_near.add_child(_far)

	# ---- 暗角（屏幕坐标）
	_vignette = TextureRect.new()
	_vignette.name = "Vignette"
	_vignette.texture = _make_vignette_tex()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vignette.modulate = Color(1, 1, 1, ALPHA_FULL)
	# 全屏铺满且**不吃输入**：它是纯视觉层，绝不能挡住摇杆/按钮。
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_vignette)

	# ---- 灯晕（屏幕坐标，串在暗角之上，也是纯视觉）
	_lamps = Control.new()
	_lamps.name = "Lamps"
	_lamps.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_lamps)
	var tex: Texture2D = _make_glow_tex()
	# 灯位按固定布局，不随机：环境层每局都该是"同一条街"，
	# 随机会让玩家觉得"换了关卡"，而这一层不是关卡。
	var spots: Array[Vector2] = [
		Vector2(-210, -180), Vector2(240, -120), Vector2(-260, 200),
		Vector2(200, 260), Vector2(-40, -320),
	]
	for i in spots.size():
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		# 屏幕坐标要落在屏幕中心附近：Control 的原点在左上，所以补半屏
		s.position = _base * 0.5 + spots[i]
		s.scale = Vector2.ONE * (2.6 if i % 2 == 0 else 2.0)
		s.modulate = Color(1.0, 0.86, 0.62, LAMP_ALPHA_BASE)
		_lamps.add_child(s)
		_lamp_sprites.append(s)

func _process(delta: float) -> void:
	if _cam == null or _vignette == null:
		return
	_t += delta
	# 远景：按比例反向位移 + 出血钳制
	var center: Vector2 = _cam.get_screen_center_position()
	_scroll = center * (1.0 - PARALLAX_RATIO)
	var bleed: Vector2 = _base * BLEED
	_scroll.x = clampf(_scroll.x, -bleed.x, bleed.x)
	_scroll.y = clampf(_scroll.y, -bleed.y, bleed.y)
	_far.position = _scroll
	# 灯晕呼吸：每盏相位错开，所有灯同拍会读成"屏幕在闪"
	var phase: float = _t / LAMP_PERIOD * TAU
	for i in _lamp_sprites.size():
		var s: Sprite2D = _lamp_sprites[i]
		var k: float = sin(phase + float(i) * 1.7) * 0.5 + 0.5
		s.modulate.a = LAMP_ALPHA_BASE + LAMP_ALPHA_AMP * k

## 低配档：暗角减到 60%，灯晕停在基准亮度（不再呼吸）。
## 暗角与灯晕都在屏幕层，镜头怎么走都不影响它们。
func apply_quality(low: bool) -> void:
	if _vignette != null:
		_vignette.modulate.a = ALPHA_FULL * (LOW_RATIO if low else 1.0)
	if low:
		for s in _lamp_sprites:
			s.modulate.a = LAMP_ALPHA_BASE

## 暗角贴图：径向渐变，中心透明 → 边缘黑。
## 用 Image 逐像素画而不是打包 png：这是纯数学图形，多一张 png 只是多一个
## 二进制依赖 + 一次导入。也符合"不往 GameDemo 加美术二进制"的交付约定。
func _make_vignette_tex() -> Texture2D:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := float(n) * 0.5
	for y in n:
		for x in n:
			var d: float = Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(0, 0, 0, smoothstep(R_INNER, R_OUTER, d)))
	return ImageTexture.create_from_image(img)

## 远景剪影：低对比屋脊线 + 几点窗光。
## 全部压在深色（亮度 < 0.14）：远景必须"退后"，比地面亮就变成视觉骚扰。
func _make_far_tex() -> Texture2D:
	var w := 96
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 固定 seed：每一局的远景必须是同一条街
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	var x := 0
	while x < w:
		var bw: int = rng.randi_range(8, 18)
		var bh: int = rng.randi_range(10, 26)
		var base_y: int = h - 1
		for yy in range(maxi(base_y - bh, 0), base_y + 1):
			for xx in range(x, mini(x + bw, w)):
				img.set_pixel(xx, yy, Color(0.05, 0.06, 0.09, 0.85))
		for _k in rng.randi_range(0, 2):
			var wx: int = rng.randi_range(x, mini(x + bw - 1, w - 1))
			var wy: int = rng.randi_range(maxi(base_y - bh + 2, 0), base_y - 1)
			if wx >= 0 and wy >= 0 and wx < w and wy < h:
				img.set_pixel(wx, wy, Color(0.86, 0.62, 0.30, 0.55))
		x += bw + rng.randi_range(0, 3)
	return ImageTexture.create_from_image(img)

## 灯晕：柔和径向光斑，中心偏白、外缘透明。
func _make_glow_tex() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := float(n) * 0.5
	for y in n:
		for x in n:
			var d: float = Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			# 三次方：中心一小团亮，边缘迅速消失（避免整片发灰）
			img.set_pixel(x, y, Color(1.0, 0.92, 0.72, a * a * a))
	return ImageTexture.create_from_image(img)
