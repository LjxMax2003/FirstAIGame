extends Node2D

# 姿态证据图：四向朝向 / 走路帧 / 侧倾"看一眼就知道对不对"。
#
# 为什么需要它：SmokeTest 只能证明 resource_path 换成了 shouyiren_back，
# 证明不了"向上走时屏幕上真的是一张后背"。换皮里最常见的翻车是
# 帧用对了但脚底错位、镜像方向反了、倾斜反了 —— 这些都只有肉眼能发现。
#
# 用法：godot --path . res://tools/PlayerPoseShot.tscn
# 输出：res://shots/player_poses.png

const OUT := "res://shots/player_poses.png"
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const CELL := Vector3(240.0, 380.0, 3.0)  # x 间距 / y 间距 / 放大倍数

func _ready() -> void:
	var bg := ColorRect.new()
	# 浅底：背面图的头/腿/鞋全是深色，放在夜景底色上根本看不出轮廓，
	# 也就没法判断"脚底有没有对齐"。这张图是给校核对齐用的，不是氛围图。
	bg.color = Color("#9FB2AC")
	bg.size = Vector2(720, 1280)
	bg.z_index = -100
	add_child(bg)
	await get_tree().process_frame

	# 3 列 x 3 行：正面三帧 / 背面三帧 / 三向组合
	_pose(0, 0, "DOWN · idle", true, 0, false, 0.0)
	_pose(1, 0, "DOWN · walk 2", true, 1, false, 0.0)
	_pose(2, 0, "DOWN · walk 3", true, 2, false, 0.0)
	_pose(0, 1, "UP · idle", false, 0, false, 0.0)
	_pose(1, 1, "UP · walk 2", false, 1, false, 0.0)
	_pose(2, 1, "UP · walk 3", false, 2, false, 0.0)
	_pose(0, 2, "LEFT (flip_h)", true, 0, true, 0.0)
	_pose(1, 2, "RIGHT · tilt", true, 1, false, 0.055)
	_pose(2, 2, "UP+RIGHT · flip", false, 1, true, 0.0)

	# 鞋底线：SVG 里鞋底在 y=75/80，经 offset(-18)、scale(3) 换算后落在 pos.y + 51。
	# 正面与背面必须踩在同一条线上 —— 差一格就是"向上走时人陷进地面"。
	for row in 3:
		var line := ColorRect.new()
		line.color = Color(0.15, 0.2, 0.19, 0.75)
		line.size = Vector2(700, 2)
		line.position = Vector2(10, 210.0 + row * CELL.y + 51.0)
		add_child(line)

	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(OUT)
	print("SHOT poses %s err=%d size=%s" % [ProjectSettings.globalize_path(OUT), err, str(img.get_size())])
	get_tree().quit(0)

## 摆一个"定格"的角色：关掉物理处理，否则 _update_anim 每帧会把贴图重置回第 1 帧，
## 手摆的姿态根本留不住（这是这个工具唯一的技术要点）。
func _pose(col: int, row: int, title: String, front: bool, frame: int, flip: bool, tilt: float) -> void:
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	p.set_physics_process(false)
	p.position = Vector2(120.0 + col * CELL.x, 210.0 + row * CELL.y)
	p.scale = Vector2(CELL.z, CELL.z)

	var cam := p.get_node_or_null("Camera") as Camera2D
	if cam != null:
		cam.enabled = false  # 九台相机互相抢画面，最后只剩一台的视野

	var art: Sprite2D = p.get_node("Art") as Sprite2D
	var frames: Array = p.get("_front_frames") if front else p.get("_back_frames")
	if frames.is_empty():
		push_error("帧为空：%s" % title)
		return
	art.texture = frames[mini(frame, frames.size() - 1)]
	art.flip_h = flip
	art.rotation = tilt

	var lb := Label.new()
	lb.text = title
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", Color("#E8DCC0"))
	lb.position = Vector2(p.position.x - 95.0, p.position.y + 66.0)
	add_child(lb)
