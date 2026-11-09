extends Node2D
class_name Ground

# 无限地面：以 ground_tile.svg（256px 无缝沥青地砖）平铺，
# 用矩形填充 + 重复贴图实现"无限滚动"，只覆盖可视区 + 一圈余量。
#
# 视野尺寸必须每帧从 viewport 读，不能写死 720x1280：
# project.godot 用 stretch/aspect="expand"，非 9:16 窗口下可视区域会比基准更宽，
# 写死尺寸就会出现"地面只铺了一部分、边角露出纯色背景"的裂口。

const TILE := 256.0

var _camera: Camera2D = null
var _tex: Texture2D = null
## 街区外的旧砖（C-02）。原工程声明了 TOMB_TILE 却零引用；
## 760 与 Game.SPAWN_RING 同值 —— 刷怪环就是街区边界，地面上"换砖"和"怪从这里来"两个信息互相加强。
var _tomb: Texture2D = null

func _ready() -> void:
	z_index = -10
	_tex = Art.tex(Art.GROUND_TILE)
	_tomb = Art.tex(Art.TOMB_TILE)

func bind(cam: Camera2D) -> void:
	_camera = cam
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

## 当前可视尺寸（用于铺砖与道具裁剪，统一从这里取，避免两处算法不一致）
static func view_size(node: Node) -> Vector2:
	var vp: Vector2 = node.get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = Vector2(720.0, 1280.0)
	return vp

## 砖块翻转：4 种朝向轮换。贴图本身是"井盖+路标"的不对称图，
## 单靠平铺会在宽屏上排出整齐的井盖网格；翻转后同一格地面不再一眼看出重复。
func _flip_at(gx: int, gy: int) -> bool:
	return ((gx * 7 + gy * 13) & 1) == 1

## 砖块明暗：只有两档，轻微差值，压掉"4 张一样的图并排"的观感。
func _shade_at(gx: int, gy: int) -> Color:
	var h: int = absi(gx * 73856093 ^ gy * 19349663) % 5
	if h == 0:
		return Color(0.94, 0.94, 0.99)
	if h == 1:
		return Color(1.06, 1.05, 1.02)
	return Color.WHITE

func _draw() -> void:
	if _camera == null or _tex == null:
		return
	var view: Vector2 = view_size(self)
	var center: Vector2 = _camera.get_screen_center_position()
	# 每个方向多铺两格，确保快速移动/相机平滑滞后时也不露边
	var half: Vector2 = view * 0.5 + Vector2(TILE * 2.0, TILE * 2.0)
	# 对齐到砖块整数倍，保证滚动时纹路连续不跳
	var origin := Vector2(
		floor((center.x - half.x) / TILE) * TILE,
		floor((center.y - half.y) / TILE) * TILE
	)
	var cols: int = int(ceil((half.x * 2.0 + TILE) / TILE))
	var rows: int = int(ceil((half.y * 2.0 + TILE) / TILE))
	for cx in cols:
		for cy in rows:
			var p := origin + Vector2(float(cx) * TILE, float(cy) * TILE)
			# 砖块索引来自"格子坐标"而不是循环序号，这样数据只由世界位置决定：
			# 相机怎么动、砖块从哪一格开始铺，同一块地的翻转/明暗都不会变。
			var gx: int = cx + int(round(origin.x / TILE))
			var gy: int = cy + int(round(origin.y / TILE))
			# C-02：格子中心到原点的距离决定用街区砖还是旧墓砖。
			# 每格独立选贴图，接缝两侧都是 256 无缝砖，不会出现半格拼贴。
			var cell_center := Vector2(p.x + TILE * 0.5, p.y + TILE * 0.5)
			var tile_tex: Texture2D = _tomb \
				if (_tomb != null and cell_center.length() > 760.0) else _tex
			draw_texture_rect(tile_tex, Rect2(p, Vector2(TILE, TILE)), false, _shade_at(gx, gy), _flip_at(gx, gy))
