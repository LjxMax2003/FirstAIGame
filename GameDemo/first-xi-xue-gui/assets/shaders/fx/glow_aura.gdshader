shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 程序化光晕 —— 无贴图光斑 / 光环
// ----------------------------------------------------------------------------
// 用途：篝火、油灯、boss 蓄力、技能落地光斑、拾取高光、精英怪的"危险"底光。
// 挂载：ColorRect（推荐，尺寸自己定，1x1 也行）或 纯色 Sprite2D
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 纯数学，比任何 blur / SCREEN_TEXTURE 方案都便宜
// ----------------------------------------------------------------------------
// 为什么不用"模糊一张贴图"：
//   模糊要么预渲染多张 mip（美术负担），要么运行时多次采样（8~16 次/像素）。
//   光斑本来就是软过渡，横向 sine 抖动 + 径向衰减就够，还不会在放大时糊。
//
// 用法要点：
//   把节点放在角色/道具的**背后**（z_index 更低），尺寸开成光晕直径的 2 倍，
//   modulate 会照常生效，可以用 modulate.a 做整体淡入淡出。
// ============================================================================

group_uniforms Shape;
uniform float radius : hint_range(0.0, 1.0) = 0.42;        // 亮芯半径（UV 归一化，0.5 = 触边）
uniform float softness : hint_range(0.01, 1.0) = 0.55;      // 羽化宽度，越大越散
uniform float ring : hint_range(0.0, 1.0) = 0.0;            // 0 = 实心光斑，1 = 空心光环
uniform float wobble : hint_range(0.0, 0.4) = 0.06;         // 角度抖动，让光斑"呼吸"而不是几何完美圆

group_uniforms Look;
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.35, 1.0);
uniform float intensity : hint_range(0.0, 5.0) = 1.0;
uniform float core_boost : hint_range(0.0, 3.0) = 0.8;      // 中心过曝量，>0 才有"光源"感

group_uniforms Pulse;
uniform float pulse_speed : hint_range(0.0, 8.0) = 1.4;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.18;

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);

	// 角度扰动：两个不成整数比的 sine 叠一层，避免出现规整的花瓣
	float ang = atan(p.y, p.x);
	d *= 1.0 + wobble * sin(ang * 3.0 + TIME * 0.9)
			+ wobble * 0.5 * sin(ang * 7.0 - TIME * 1.3);

	float outer = max(radius + softness, 1e-4);
	float g = clamp(1.0 - d / outer, 0.0, 1.0);
	g *= g;                                        // 二次衰减，接近真实光斑的肩部

	// 空心模式：把内部压下去，只留一圈
	float hollow = smoothstep(radius * 0.35, radius * 0.85, d) * g;
	float shape = mix(g, hollow, ring);

	// 亮芯
	float core = (1.0 - smoothstep(0.0, max(radius * 0.5, 1e-4), d)) * core_boost;

	float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	float a = (shape + core * shape) * intensity * pulse;

	COLOR = vec4(glow_color.rgb * a, 1.0) * node_tint;
}
