extends Node2D
class_name HpBar

# 敌人血条：只有被打过才显示（精英常显），纯色块 + 圆角，零贴图开销。

const BG := Color(0.06, 0.08, 0.12, 0.85)
const FILL := Color(0.98, 0.36, 0.38)
const FILL_ELITE := Color(1.0, 0.72, 0.28)

var ratio := 1.0
var bar_w := 26.0
var bar_h := 4.0
var fill_color := FILL

func setup(enemy_size: float, elite: bool) -> void:
	bar_w = maxf(26.0, enemy_size * 0.62)
	bar_h = 5.0 if elite else 4.0
	fill_color = FILL_ELITE if elite else FILL
	# 挂在头顶（素材原点在脚底附近，向上偏移到头顶）
	position = Vector2(0.0, -enemy_size - 2.0)
	ratio = 1.0
	queue_redraw()

func set_ratio(r: float) -> void:
	ratio = clampf(r, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var half: float = bar_w * 0.5
	draw_rect(Rect2(-half - 1.0, -1.0, bar_w + 2.0, bar_h + 2.0), BG)
	draw_rect(Rect2(-half, 0.0, bar_w * ratio, bar_h), fill_color)
