shader_type canvas_item;

// ============================================================================
// 扫光 —— shine sweep
// ----------------------------------------------------------------------------
// 用途：地面掉落物/宝箱/商店卡片的"这里有值钱东西"、升级卡翻面、
//       结束时对被选中卡片扫一次。
// 挂载：Sprite2D / TextureRect 的 material（物品图标、卡片底图都行）
// 渲染：canvas_item · blend_mix · Mobile / Compatibility / Forward+ 全通用
// 采样：1 次 TEXTURE
// ----------------------------------------------------------------------------
// 两种驱动方式，二选一：
//   auto_speed = 0  → 由脚本 tween progress（推荐：扫一次就停，别一直闪）
//   auto_speed > 0  → 自己循环扫（地上的掉落物用这个，但别开太快）
//
// 只扫 1~3 条带，且是常量循环（不是动态次数），移动端不会触发循环展开的坑。
// ============================================================================

group_uniforms Shine;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(-0.5, 1.5) = 0.55;      // 扫光位置，脚本 tween -0.2 → 1.2
uniform float width : hint_range(0.01, 0.6) = 0.16;         // 光带宽度
uniform float angle : hint_range(-1.57, 1.57) = 0.6;         // 扫光角度（弧度），0.6 ≈ 斜 34°
uniform float intensity : hint_range(0.0, 2.0) = 1.1;

group_uniforms Variations;
uniform float bands : hint_range(1.0, 3.0, 1.0) = 1.0;       // 平行光带数量 1~3
uniform float band_gap : hint_range(0.02, 0.5) = 0.12;
uniform float band_falloff : hint_range(0.0, 1.0) = 0.45;    // 后续光带变细变淡的比例
uniform float hardness : hint_range(0.0, 1.0) = 0.0;         // 0 柔光 / 1 硬边（剪纸风用 0.8）
uniform vec4 tail_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

group_uniforms Auto;
uniform float auto_speed : hint_range(0.0, 3.0) = 0.0;       // 每秒扫几次，0 = 用 progress
uniform float auto_pause : hint_range(0.0, 3.0) = 1.0;       // 两次之间的停顿（秒）

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	float p = progress;
	if (auto_speed > 0.0) {
		float period = 1.0 / auto_speed + auto_pause;
		p = mod(TIME, period) * auto_speed * 1.8 - 0.4;   // -0.4 → 1.4，然后等待
	}

	// 投影到扫光方向的一维坐标
	float d = UV.x * cos(angle) + UV.y * sin(angle);
	float aa = fwidth(d) + 1e-4;

	float glow = 0.0;
	vec3 tint = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		if (float(i) >= bands) break;
		float fi = float(i);
		float w = width * pow(1.0 - band_falloff * 0.6, fi);
		float x = abs(d - (p - fi * (band_gap + width)));
		float soft = smoothstep(w, 0.0, x);
		float hard = 1.0 - smoothstep(w * 0.55 - aa, w * 0.55 + aa, x);
		float b = mix(soft, hard, hardness) * pow(1.0 - band_falloff, fi);
		if (b > glow) {
			glow = b;
			tint = mix(tail_color.rgb, shine_color.rgb, mix(soft, 1.0, hardness));
		}
	}

	// 乘 col.a：光只在图案内部扫，不会给图标加一个发光矩形
	col.rgb += tint * glow * intensity * col.a;
	COLOR = col * node_tint;
}
