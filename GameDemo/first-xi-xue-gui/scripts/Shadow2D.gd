extends RefCounted
class_name Shadow2D

# 运行时生成椭圆影子：用 1x1 白色贴图 + 椭圆遮罩太麻烦，
# 直接用 Polygon2D 画一圈椭圆更省事，且不占任何美术资源。

static func make(parent: Node2D, pos: Vector2, rx: float, ry: float, alpha: float) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = ellipse(rx, ry, 16)
	poly.color = Color(0.05, 0.08, 0.14, alpha)
	poly.position = pos
	poly.z_index = -1
	parent.add_child(poly)
	return poly

static func ellipse(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func resize(poly: Polygon2D, rx: float, ry: float) -> void:
	poly.polygon = ellipse(rx, ry, 16)
