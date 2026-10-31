shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 走马灯流光 —— 花灯 Lv8 觉醒（v6 §6「场边缘走马灯流光」）
// ----------------------------------------------------------------------------
// 用途：花灯（halo）满级后，在范围场的边缘巡游一道金亮带。
// 挂载：ColorRect（正方形，直径 = 花灯判定直径），叠在 aura_field / area_ripple 之上。
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 纯数学。
// ----------------------------------------------------------------------------
// 为什么值得单独写一个（而不是把 aura_field 的 swirl_speed 调高）：
//   aura_field 的环流是**噪声在流**，边界糊、没有方向感，读作"雾在转"。
//   "走马灯"是民间灯彩里一圈画片绕着灯芯匀速走 —— 它必须**一格一格**地过，
//   有明确的行进方向和拖尾。这是几何结构上的差别，调参数调不出来。
//
// 和花灯原有表现的分工（三层，别合并）：
//   · aura_field   环流噪声边带 → "这个圈在那儿，一直在烧"
//   · area_ripple  同心波纹外推 → "圈里在挨打"
//   · lantern_stream 巡游光带   → "满级了"（Lv1~7 不出现）
// 三层同屏也不糊：波纹是径向的、环流是绒的、流光是**硬边一段一段**的。
//
// 坑：环向用 atan 取角度后加 TIME 偏移，按短边归一化（rect_size）避免椭圆；
//     与"虚线环"不同，这里是连续的亮头 + 拖尾，不是等距的小方块。
// ============================================================================

group_uniforms Ring;
uniform vec2 rect_size = vec2(260.0, 260.0);              // 节点像素尺寸，短边归一化
uniform float inner : hint_range(0.0, 1.0) = 0.80;        // 亮带内沿（靠外，只贴边一圈）
uniform float band_width : hint_range(0.01, 0.3) = 0.12;  // 亮带宽度（径向）

group_uniforms Flow;
uniform float flow_speed : hint_range(0.0, 6.0) = 1.8;    // 沿圆周流动速度（rad/s）

group_uniforms Look;
uniform vec4 lantern_color : source_color = vec4(1.0, 0.78, 0.322, 1.0);  // #FFC752 灯笼金
uniform float intensity : hint_range(0.0, 3.0) = 1.0;     // 常驻 1.0；命中那一下由脚本推到 1.6

varying vec4 node_tint;

// 走马灯的格数 = 灯面画片数。做成常量而不是 uniform：这是"走马灯"这个词的
// 固定语义（六面灯），换来一个可省的状态——真要调，改这一行。
const float PANELS = 6.0;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	float edge = max(min(rect_size.x, rect_size.y) * 0.5, 1.0);
	vec2 q = (UV - 0.5) * rect_size / edge;
	float d = length(q);
	float ang = atan(q.y, q.x);

	// ---- 环带：中心线在 inner + band_width/2，所以亮带正好压在 [inner, inner+w]
	float c = inner + band_width * 0.5;
	float half_w = band_width * 0.5;
	float band = 1.0 - smoothstep(0.0, half_w + 1.0e-4, abs(d - c));
	// 带外一层很淡的柔光：没有它，亮带会像一条剪出来的硬纸条
	float halo = 1.0 - smoothstep(half_w, half_w * 2.1, abs(d - c));

	// ---- 走马灯：6 格沿圆周推进，每格"亮头在前、拖尾在后"
	// a2 随 TIME 递减 → 亮头沿负角方向走；用 fract 保证跨 0 处连续
	float a2 = ang - TIME * flow_speed;
	float u = fract(a2 / TAU * PANELS);          // 0..1 在一格之内
	// 拖尾：u 接近 0 时最亮（亮头），往后 pow 衰减
	float tail = pow(max(1.0 - u, 0.0), 2.6);
	// 亮头再收一个极窄的尖，读作"灯芯烫亮的那一下"
	float tip = pow(max(1.0 - u, 0.0), 14.0);

	// 底噪压到 0.05 而不是 0.22：**走马灯是一格一格的**。
	// 0.22 的底噪会把六格连成一个连续的亮环，和 aura_field 的边带完全同形 ——
	// 加了等于没加（第一版就是这样，截图里 Lv7 和 Lv8 几乎分不出来）。
	// 留 0.05 只是为了格与格之间不出现"断到底"，仍能看出是同一圈灯。
	float a = (band * (0.05 + 0.95 * tail) + tip * band * 0.55 + halo * 0.08) * intensity;

	COLOR = vec4(lantern_color.rgb * a, 1.0) * node_tint;
}
