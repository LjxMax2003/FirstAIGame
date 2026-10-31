shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 弹道辉光尾 —— 糖画（glowstick）/ 剪纸刀（blade）的"速度感"
// ----------------------------------------------------------------------------
// 用途：飞行弹体、环绕体、回旋镖。让一颗圆点在高速移动时读起来像"射出去的能量"。
// 挂载：Sprite2D（弹体本体）
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：1 次 TEXTURE
// ----------------------------------------------------------------------------
// 诚实说明：**这不是真拖尾。** 真拖尾要在身后连续留下一串会消散的图，需要
// Line2D 或额外的拖尾节点；本 shader 只在弹体自身拉出一条方向性亮尾，解决的是
// "60fps 下弹体像瞬移"的问题。两者不冲突，可以先上这个，再决定要不要真拖尾。
//
// 方向：axis 用整数而不是 vector，因为弹体会旋转（rotation），vector 参数在
// 旋转后还要再变换一次，容易和节点的 transform 打架；用轴向枚举最不容易错。
// ============================================================================

group_uniforms Trail;
uniform float stretch : hint_range(0.0, 1.0) = 0.55;    // 尾长（占贴图长度的比例）
uniform int axis : hint_range(0, 3) = 0;                 // 0 +X / 1 -X / 2 +Y / 3 -Y
uniform float tightness : hint_range(0.1, 4.0) = 1.4;    // 横向收束，越大越细
uniform vec4 trail_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

group_uniforms Life;
uniform float flicker : hint_range(0.0, 1.0) = 0.2;      // 高频抖动，消掉"塑料光条"感
uniform float flicker_speed : hint_range(0.0, 40.0) = 18.0;

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// 轴向与垂直方向（UV 空间）
	vec2 dir = vec2(1.0, 0.0);
	if (axis == 1) dir = vec2(-1.0, 0.0);
	if (axis == 2) dir = vec2(0.0, 1.0);
	if (axis == 3) dir = vec2(0.0, -1.0);
	vec2 perp = vec2(-dir.y, dir.x);

	vec2 c = UV - 0.5;
	float along = dot(c, dir) + 0.5;     // 0 = 尾端，1 = 头端
	float lat = abs(dot(c, perp)) * 2.0; // 0 = 中轴，1 = 边缘

	// 从尾端向头端逐渐变实；stretch = 0 时整条一样（等于没有尾）
	float tail = smoothstep(1.0 - stretch, 1.0, along);
	// 横向收束
	float side = pow(clamp(1.0 - lat, 0.0, 1.0), tightness);

	// 抖动：用 UV 和时间做伪随机，避免整条同步闪
	float fl = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * flicker_speed + UV.x * 37.0 + UV.y * 21.0));

	float a = tex.a * tail * side * intensity * fl;
	// 夹到 0..1：不夹的话 intensity > 1 会把尾巴烧成一条纯白横杠（第一版就是这个毛病）
	a = clamp(a, 0.0, 1.0);

	// blend_add 下 src 会再乘一次 src.a，所以这里把亮度全算进 rgb、alpha 交给 modulate。
	// 否则弹体边缘会出现 a² 的二次衰减，尾巴会比预期短一半。
	vec3 rgb = tex.rgb * tex.a + trail_color.rgb * a;

	COLOR = vec4(rgb, 1.0) * node_tint;
}
