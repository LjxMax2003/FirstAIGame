shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 领域能量场 —— 光环类技能"在烧"的持续表现
// ----------------------------------------------------------------------------
// 用途：花灯（halo）领域内部、进化后的火神开脸范围、Boss 的领域技能。
// 挂载：ColorRect（尺寸 = 领域直径），放在光环贴图**下面**一层
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 两段程序化噪声，整块面积也只是 ALU
// ----------------------------------------------------------------------------
// 为什么不用噪声贴图：
//   本站同类条目都要求一张 noise 贴图，等于多一个资源依赖 + 一次采样。
//   极坐标流动用两段 value noise 就能做出丝状环流，且分辨率无关（放大不糊）。
//
// 角向接缝的坑（值得记）：
//   如果直接用 (角度, 半径) 当噪声坐标，atan 在 ±PI 处会断开，环上会出现一条
//   笔直的接缝。这里改成把角度映射到**单位圆上的坐标**再采样，天然连续，无接缝。
// ============================================================================

group_uniforms Field;
uniform float inner : hint_range(0.0, 1.0) = 0.62;      // 内径（UV 归一化，0.5 = 触边）
uniform float outer : hint_range(0.0, 1.0) = 0.98;      // 外径
uniform float softness : hint_range(0.01, 0.5) = 0.10;  // 内外边界的羽化宽度
uniform vec4 field_color : source_color = vec4(1.0, 0.72, 0.35, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.9;

group_uniforms Flow;
uniform float noise_scale : hint_range(1.0, 20.0) = 5.0;   // 纹理尺度，越大越碎
uniform float swirl_speed : hint_range(-3.0, 3.0) = 0.55;  // 环流速度，负值反向
uniform float streak : hint_range(0.0, 1.0) = 0.45;        // 0 云雾状 / 1 丝状

group_uniforms Beat;
uniform float beat : hint_range(0.0, 1.0) = 0.0;           // 命中时置 1 再衰减，配合 GarlicRing.beat()
uniform float beat_boost : hint_range(0.0, 2.0) = 0.7;

varying vec4 node_tint;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);

	// 环带遮罩：内径软进、外径软出。
	// 外径必须在**节点边界内**收口：ColorRect 的 UV 在 r>1 处已被裁掉，若 fade 拖到
	// outer+softness（默认 1.10 / 花灯实配 1.20），边界上会留一圈方形硬边 ——
	// add 混合下就是一个发亮的方框（实测截图确认）。收口到 r=1.0 后，
	// 场的可见外沿正好等于光环贴图的半径，视觉半径与判定半径同界。
	float out_end = min(outer + softness, 1.0);
	float out_w = min(softness * 1.25, out_end);
	float band = smoothstep(inner - softness, inner + softness * 0.25, r)
			* (1.0 - smoothstep(out_end - out_w, out_end, r));

	// 关键：角度 → 单位圆坐标，天然连续，不会在 ±PI 处裂开
	float a2 = ang + TIME * swirl_speed;
	vec2 ring = vec2(cos(a2), sin(a2)) * noise_scale;
	vec2 radial = vec2(0.0, r * noise_scale * 1.7);   // 径向下压 = 角向拉长 = 丝状

	float n = value_noise(ring + radial) * 0.62
			+ value_noise(ring * 2.6 + radial * 2.2 + vec2(7.7, 3.1)) * 0.38;

	// streak 越大，暗部越暗，亮丝越细
	n = mix(n, pow(n, 3.0), streak);

	float a = band * n * intensity * (1.0 + beat * beat_boost);

	COLOR = vec4(field_color.rgb * a, 1.0) * node_tint;
}
