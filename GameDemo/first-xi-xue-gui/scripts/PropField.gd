extends Node2D
class_name PropField

# 场景装饰物（路障/垃圾桶/消防栓/自行车/售货机）：纯静态视觉锚点。
# 无限地图上按格子哈希确定性生成——走回去还是同一批物件，不会闪烁。
# 不参与碰撞（碰撞走距离判定），只提供"我在移动"的空间参照。

const CELL := 400.0
const RADIUS := 2

# ---------------------------------------------------------------- 夜市街区（T11）
# 【为什么是"固定世界坐标"而不是跟着格子哈希随机撒】
# 五张摊位各对应一门手艺（铁花 / 灯彩 / 剪纸 / 皮影 / 糖画），它们是**叙事地标**：
# 玩家在第一分钟看到的那个"百工夜市"必须每次都长一样，才认得出"我回到了入口"。
# 随机撒会把"地标"降级成"背景噪音"。离开街区半径后由下面的随机道具接管，
# 所以走远了不会空场。
#
# 【为什么塞进 PropField 而不是新开一个节点】
# 场景里已经有一层 z_index=-5 的批绘；再开一层等于让"谁压谁"多一处要维护的约定。
# 这里只是一次额外的 draw_texture_rect 循环，八张图 + 已有的五张随机道具 = 13 个批次。
const LANDMARKS: Array[Dictionary] = [
	# 牌楼：北入口。底边放在 -430 —— 720x1280 下可视区是 y∈[-640,640]，
	# 牌楼高 200，-430 时上沿落在 -630，刚好整座进画面且贴着顶边。
	# 原来放 -560 会被切掉大半，只剩两条腿，读起来像"一个坏掉的物件"。
	{"path": Art.ARCHWAY, "pos": Vector2(0.0, -430.0)},
	# 戏台：压街尾。玩家开局朝南回头就能看到"这里有人唱"，是街区的另一端。
	# 底边 545：戏台 220 高，上沿 325，正好避开左街最下面那张皮影摊（底边 290）。
	# 放 470 时会被摊位的包围盒切掉一条 —— 那条断言是 V71Content 抓出来的。
	{"path": Art.OLD_STAGE, "pos": Vector2(0.0, 545.0)},
	# 灯柱 ×4：街两侧，负责把"一条街"读出来（而不是一片空地摊着几个摊）。
	# 放在 ±310：720 宽的可视区半宽是 360，再往外柱子会被屏幕边缘切成一条。
	{"path": Art.LANTERN_PILLAR, "pos": Vector2(-310.0, -300.0)},
	{"path": Art.LANTERN_PILLAR, "pos": Vector2(310.0, -300.0)},
	{"path": Art.LANTERN_PILLAR, "pos": Vector2(-310.0, 380.0)},
	{"path": Art.LANTERN_PILLAR, "pos": Vector2(310.0, 380.0)},
	# 五摊：左街三（铁花/灯彩/皮影）、右街二（剪纸/糖画）。
	# 摆在内侧 235：摊位宽 180，再往外整列会贴着屏幕边缘被切。
	# 左三右二不是随手 —— 右街尽头要为戏台留出通道，否则摊位把台子挡掉一半。
	{"path": Art.STALL_FORGE, "pos": Vector2(-235.0, -170.0)},
	{"path": Art.STALL_LANTERN, "pos": Vector2(-235.0, 60.0)},
	{"path": Art.STALL_SHADOW, "pos": Vector2(-235.0, 290.0)},
	{"path": Art.STALL_PAPER, "pos": Vector2(235.0, -170.0)},
	{"path": Art.STALL_SUGAR, "pos": Vector2(235.0, 60.0)},
]

var _camera: Camera2D = null
var _texs: Array[Texture2D] = []
var _land_texs: Array[Texture2D] = []

func _ready() -> void:
	z_index = -5
	for p in Art.PROP_LIST:
		_texs.append(Art.tex(p))
	# 预加载一次：地标是常驻视觉锚点，不该在第一帧才去 load（那时正好在出怪）
	for m in LANDMARKS:
		_land_texs.append(Art.tex(String(m["path"])))

func bind(cam: Camera2D) -> void:
	_camera = cam
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _hash(cx: int, cy: int, salt: int) -> int:
	return absi(cx * 73856093 ^ cy * 19349663 ^ salt * 83492791)

func _draw() -> void:
	if _camera == null or _texs.is_empty():
		return
	# 裁剪范围跟地面用同一套视口尺寸，否则宽屏下道具会只在中间一条带里出现
	var view: Vector2 = Ground.view_size(self)
	var center: Vector2 = _camera.get_screen_center_position()
	_draw_landmarks(center, view)
	var cc := Vector2i(int(floor(center.x / CELL)), int(floor(center.y / CELL)))
	for cx in range(cc.x - RADIUS, cc.x + RADIUS + 1):
		for cy in range(cc.y - RADIUS, cc.y + RADIUS + 1):
			var n: int = _hash(cx, cy, 1) % 3
			for k in n:
				var jx: float = float(_hash(cx, cy, 2 + k) % 100) / 100.0
				var jy: float = float(_hash(cx, cy, 12 + k) % 100) / 100.0
				var pos := Vector2(
					(float(cx) + 0.18 + jx * 0.64) * CELL,
					(float(cy) + 0.18 + jy * 0.64) * CELL
				)
				# 视野外直接跳过
				if absf(pos.x - center.x) > view.x * 0.85 or absf(pos.y - center.y) > view.y * 0.85:
					continue
				var t: Texture2D = _texs[_hash(cx, cy, 30 + k) % _texs.size()]
				var sz: Vector2 = t.get_size()
				# 地面投影：横向压扁的椭圆，让物件"站在地上"
				draw_set_transform(pos + Vector2(0.0, 1.0), 0.0, Vector2(1.0, 0.34))
				draw_circle(Vector2.ZERO, sz.x * 0.34, Color(0.0, 0.0, 0.0, 0.22))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				# 贴图底部对齐 pos
				var rect := Rect2(pos + Vector2(-sz.x * 0.5, -sz.y + 3.0), sz)
				draw_texture_rect(t, rect, false, Color(1.0, 1.0, 1.0, 0.82))

# ---------------------------------------------------------------- 夜市街区
## 固定坐标的置景：五摊 + 牌楼 / 戏台 / 灯柱。**纯装饰、无碰撞、不参与任何判定**。
## 走 draw_texture_rect 而不是给每处摆一个 Sprite2D —— 和不参与判定的随机道具
## 用同一套批绘，以后改配色 / 加暗角只动这一个函数。
func _draw_landmarks(center: Vector2, view: Vector2) -> void:
	var left: float = center.x - view.x * 0.5
	var right: float = center.x + view.x * 0.5
	var top: float = center.y - view.y * 0.5
	var bottom: float = center.y + view.y * 0.5
	for i in mini(_land_texs.size(), LANDMARKS.size()):
		var t: Texture2D = _land_texs[i]
		if t == null:
			continue
		var sz: Vector2 = t.get_size()
		# pos 是**底边中点**（和随机道具一致），所以矩形上沿要减掉整张高度
		var pos: Vector2 = LANDMARKS[i]["pos"]
		var rect := Rect2(pos + Vector2(-sz.x * 0.5, -sz.y + 4.0), sz)
		# 用矩形求交做裁剪：只判中心点的话，320 宽的牌楼会在屏幕边缘整块闪掉
		if rect.end.x < left or rect.position.x > right:
			continue
		if rect.end.y < top or rect.position.y > bottom:
			continue
		# 影子比随机道具更宽更淡：地标是"大件"，影子太实会读成贴纸
		draw_set_transform(pos + Vector2(0.0, 1.0), 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, sz.x * 0.42, Color(0.0, 0.0, 0.0, 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(t, rect, false, Color(1.0, 1.0, 1.0, 0.94))
