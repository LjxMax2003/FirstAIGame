shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 本体发光 —— texture-clipped pulse glow
// ----------------------------------------------------------------------------
// 用途：道具掉落时"这东西有用"的高光、被点燃/中毒的怪、技能附魔的武器、
//       拾取瞬间的整块过曝。光被裁剪在贴图轮廓内，不会多出一个方框。
// 挂载：Sprite2D / AnimatedSprite2D 的 material
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：1 次 TEXTURE
// ----------------------------------------------------------------------------
// 为什么不直接用 modulate：
//   modulate 是乘法，暗色贴图永远提不亮；这里是加法，暗色也能"自己发光"。
//
// 为什么不加 WorldEnvironment 的 glow：
//   2D 全屏 glow 需要 hdr_2d + 一次额外 framebuffer，整屏成本；
//   单个道具/怪物发光用加法混合就够了，只有真的要大范围泛光时才值得上后处理。
//
// blend_add 下 alpha 会被着色器再次相乘，所以这里把亮度全部算进 rgb，
// alpha 固定输出 1.0 —— 避免"叠两层就变成 a²"的衰减。
// ============================================================================

group_uniforms Glow;
uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.32, 1.0);
uniform float intensity : hint_range(0.0, 5.0) = 1.2;
uniform float falloff : hint_range(0.2, 3.0) = 1.1;      // 越小越平（整片贴纸感），越大越"从中心亮出去"

group_uniforms Pulse;
uniform float pulse_speed : hint_range(0.0, 8.0) = 1.6;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.25; // 0 = 常亮，1 = 完全明暗交替

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// 以 UV 中心做径向衰减，再乘贴图 alpha：光只活在图案内部
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float mask = pow(clamp(1.0 - d, 0.0, 1.0), falloff);

	float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	float a = tex.a * mask * intensity * pulse;

	COLOR = vec4(glow_color.rgb * a, 1.0) * node_tint;
}
