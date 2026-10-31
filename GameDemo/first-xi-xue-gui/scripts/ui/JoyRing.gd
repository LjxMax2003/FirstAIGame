extends Node2D
class_name JoyRing

# 摇杆外圈：等距细线环 + 中心点，纯色块，不依赖任何贴图

const RADIUS := 56.0
const SEGMENTS := 32

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.12, 0.16, 0.24, 0.45))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, SEGMENTS, Color(0.7, 0.85, 1.0, 0.65), 2.5)
	draw_arc(Vector2.ZERO, RADIUS * 0.45, 0.0, TAU, SEGMENTS, Color(0.7, 0.85, 1.0, 0.25), 1.5)
	for i in 4:
		var a: float = TAU * float(i) / 4.0
		draw_line(Vector2.from_angle(a) * (RADIUS - 8.0), Vector2.from_angle(a) * RADIUS, Color(0.8, 0.9, 1.0, 0.5), 2.0)
