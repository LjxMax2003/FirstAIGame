shader_type canvas_item;

// ============================================================================
// 受伤红边 —— hurt vignette（全屏）
// ----------------------------------------------------------------------------
// 用途：玩家掉血时的边缘压迫感；也可驱动成"残血常驻"状态。
// 挂载：HUD 最上层的一个 ColorRect（Anchor = Full Rect，Mouse Filter = Ignore）
// 渲染：canvas_item · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 纯噪声函数，移动端整屏也就几条 ALU
// ----------------------------------------------------------------------------
// 为什么不用 smoothstep 画一个规整的圆角矩形：
//   规整边缘属于 UI，会读成"界面弹窗"；用噪声扰动内边界才像"血糊上来"。
//
// 竖屏适配（这里改过一次，别改回去）：
//   最初按 screen_size.y（屏高）归一化，理由是"四边像素厚度一致"。
//   在 720x1280 竖屏上这是错的：size=0.22 意味着 0.22*1280 = 282px 的带宽，
//   而半宽只有 360px —— 左右两侧直接吃到接近屏幕中线，画面上是"整屏泛红"，
//   正是换掉纯红 ColorRect 想避开的观感。
//   现在按**短边**归一化：同样的 size 在四边都是相同像素宽度，
//   竖屏的左右不会被放大成屏高的 1.8 倍。
//
// 常用驱动：
//   一次受击 → ShaderFX.hurt(vignette_rect, 0.8, 0.5)
//   残血常驻 → 每帧 set_shader_parameter("max_alpha", lerp(0.15, 0.7, 1.0 - hp_ratio))
// ============================================================================

group_uniforms Hurt;
uniform vec4 hurt_color : source_color = vec4(0.52, 0.06, 0.05, 1.0);
uniform vec2 screen_size = vec2(720.0, 1280.0);            // 必须 = 项目 viewport 尺寸
uniform float size : hint_range(0.0, 0.5) = 0.13;           // 从屏幕边缘向内侵蚀的深度（占短边比例）
uniform float softness : hint_range(0.0, 1.0) = 0.7;        // 0 硬边 / 1 极缓
uniform float roughness : hint_range(0.0, 1.0) = 0.35;      // 内边界的破碎程度
uniform float max_alpha : hint_range(0.0, 1.0) = 0.85;      // 总强度上限（脚本主要驱动这个）

group_uniforms Pulse;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.8;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.5;    // 0 常亮 / 1 完全呼吸

varying vec4 node_tint;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	// 到最近屏幕边的像素距离，再按**短边**归一化 → 四边是相同像素宽度。
	// 按屏高归一化会让竖屏左右各吃到 282px（半宽 360），整屏发红。
	vec2 px = UV * screen_size;
	vec2 e = min(px, screen_size - px);
	float unit = max(min(screen_size.x, screen_size.y), 1.0);
	float edge = min(e.x, e.y) / unit;

	// 慢速漂移的噪声，让内边界看起来在蠕动
	float n = value_noise(UV * 6.0 + vec2(0.0, TIME * 0.05));
	edge += (n - 0.5) * roughness * size;

	float soft_start = size * (1.0 - softness);
	float vignette = clamp(1.0 - smoothstep(soft_start, size, edge), 0.0, 1.0);

	float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed * TAU));

	// 同一个噪声场给颜色做斑驳，避免"一整片纯红"的塑料感
	vec3 mottled = hurt_color.rgb * (0.85 + 0.3 * n);

	COLOR = vec4(mottled, vignette * pulse * max_alpha * hurt_color.a) * node_tint;
}
