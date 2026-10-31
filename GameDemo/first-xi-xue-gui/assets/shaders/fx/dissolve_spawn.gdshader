shader_type canvas_item;
render_mode blend_mix;

// ============================================================================
// 出现 / 消失 —— 噪声溶解 + 发光边缘
// ----------------------------------------------------------------------------
// 用途：敌人从地里"爬出来"、死亡后化墨散去、道具被拾取时收走、UI 卡片登场。
// 挂载：Sprite2D / AnimatedSprite2D 的 material
// 渲染：canvas_item · Mobile / Compatibility / Forward+ 全通用
// 采样：1 次 TEXTURE；噪声是程序化生成的，不需要任何 noise 贴图
// ----------------------------------------------------------------------------
// 一个参数驱动两种动画：
//   progress 0 → 1  = 出现
//   progress 1 → 0  = 消失
// 用脚本 tween 一个 float 就够，不需要 AnimationPlayer。
//
// 不用 discard 的取舍：
//   移动端 discard 会打断早期深度剔除，且硬边在缩放时闪锯齿；
//   这里改用 alpha 软过渡（softness），代价是 1 个透明像素的填充率，
//   换来"边缘是化开的墨"而不是"像素在跳"，与水墨/剪纸的题材一致。
//
// 描边冲突：
//   这个 shader 未提供描边参数 —— 因为它只在出现/消失的 0.3~0.6 秒里
//   临时占用 material 槽，边缘的发光本身已经承担了"这里有东西"的提示作用；
//   过渡结束后由 ShaderFX.dissolve_*() 自动还原原来的 outline 材质。
// ============================================================================

group_uniforms Dissolve;
uniform float progress : hint_range(0.0, 1.0) = 1.0;          // 0 全没 / 1 全有
uniform float noise_scale : hint_range(1.0, 40.0) = 9.0;       // 墨块颗粒大小
uniform float softness : hint_range(0.005, 0.35) = 0.07;       // 边缘软硬；越大越"化开"

group_uniforms Edge;
uniform vec4 edge_color : source_color = vec4(1.0, 0.82, 0.42, 1.0);
uniform float edge_width : hint_range(0.0, 0.5) = 0.12;        // 发光边宽度（噪声空间）
uniform float edge_boost : hint_range(0.0, 5.0) = 0.9;         // 加亮强度；开了 HDR 2D 可拉到 2 以上才有溢光
uniform float edge_tint : hint_range(0.0, 1.0) = 0.75;         // 边缘把本体染成发光色的比例

group_uniforms Direction;
uniform float direction : hint_range(0.0, 1.0) = 0.4;          // 0 均匀溶解 / 1 完全按方向推进
uniform bool from_bottom = true;                                // true 自下而上（破土而出）

varying vec4 node_tint;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 程序化 value noise：省一张贴图，移动端也只是几条 ALU 指令
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
	vec4 tex = texture(TEXTURE, UV);

	// 两个八度就够：单个八度太像"随机点阵"，太多画在 48px 上浪费
	float n = value_noise(UV * noise_scale) * 0.65
			+ value_noise(UV * noise_scale * 2.7 + vec2(13.7, 5.1)) * 0.35;

	// 方向偏置：UV.y = 0 在顶部、1 在底部
	float grad = from_bottom ? UV.y : 1.0 - UV.y;
	float bias = mix(0.5, grad, direction);
	float v = clamp(n + (bias - 0.5) * direction * 0.9, 0.0, 1.0);

	// 把 0..1 的 progress 映射到略微超出 0..1 的区间，
	// 这样 progress = 0 / 1 时是彻底消失 / 彻底完整，不会有半透明的残留
	float p = mix(-softness * 2.0, 1.0 + softness * 2.0, progress);
	float mask = 1.0 - smoothstep(p - softness, p + softness, v);

	// 发光边：只在 v 贴着推进面时亮；过渡结束后自动熄灭，不会留一圈常亮描边
	float e = 0.0;
	if (progress > 0.001 && progress < 0.999) {
		e = 1.0 - smoothstep(0.0, edge_width + 1e-4, abs(v - p));
		e *= e;
	}

	vec3 rgb = mix(tex.rgb, edge_color.rgb, e * edge_tint);
	rgb += edge_color.rgb * e * edge_boost;

	COLOR = vec4(rgb, tex.a * mask) * node_tint;
}
