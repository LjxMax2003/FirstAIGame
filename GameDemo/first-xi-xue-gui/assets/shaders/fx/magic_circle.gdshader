shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 技能法阵 —— procedural magic circle
// ----------------------------------------------------------------------------
// 用途：技能蓄力/预警圈/传送门/召唤阵。配合 "appear" 从 0 扫到 1 就是"画阵"。
// 挂载：ColorRect（正方形最好，拉长会成为椭圆阵）或 纯色 Sprite2D
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 全程序化，不需要任何贴图
// ----------------------------------------------------------------------------
// 性能说明（移动端）：
//   满配（5 环 + 8 角星 + 刻痕 + 光点）约 60 次 length/smoothstep 运算，整块色块面积
//   在竖屏上通常 < 1/5 屏，实测比一张 512 贴图的模糊方案更便宜。
//   低配机型把 rings 降到 2、star_points 设 0 即可，代码路径不变。
//
// 美术方向：
//   默认配色偏金 —— 与本作"油纸灯笼 / 剪纸"的金红体系一致；
//   想要"阴气/鬼气"就换成青 (0.35,0.9,1.0)，与快速怪的青描边同源。
// ============================================================================

group_uniforms Circle;
uniform vec4 circle_color : source_color = vec4(0.95, 0.72, 0.36, 1.0);
uniform float glow : hint_range(0.0, 4.0) = 1.0;
uniform int rings : hint_range(1, 5) = 3;
uniform float line_width : hint_range(0.002, 0.03) = 0.008;

group_uniforms Runes;
uniform int ticks : hint_range(0, 96) = 48;                 // 外圈刻痕数，0 = 关
uniform int star_points : hint_range(0, 8) = 8;              // 星形顶点数，0 = 关
uniform int star_step : hint_range(1, 5) = 3;                // 8/3 = 八角星，5/2 = 五芒星
uniform int orbs : hint_range(0, 12) = 6;                    // 内圈游走光点

group_uniforms Anim;
uniform float spin_speed = 0.25;                             // 整体转速
uniform float pulse_speed = 2.0;
uniform float appear : hint_range(0.0, 1.0) = 1.0;            // 0 → 1 沿圆周"画"出法阵

varying vec4 node_tint;

float ring(float r, float radius, float w) {
	return smoothstep(w, 0.0, abs(r - radius));
}

float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return smoothstep(w, 0.0, length(pa - ba * h));
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float w = line_width;
	float t = TIME;
	float m = 0.0;

	// 同心环（外环加粗）
	for (int i = 0; i < 5; i++) {
		if (i >= rings) break;
		float rad = 0.92 - float(i) * 0.14;
		m += ring(r, rad, w * (i == 0 ? 1.6 : 1.0));
	}

	// 刻痕：用 fract 做角向重复，无需循环
	if (ticks > 0) {
		vec2 q = rot(p, t * spin_speed);
		float a = atan(q.y, q.x) / TAU + 0.5;
		float k = abs(fract(a * float(ticks)) - 0.5);
		float band = step(0.8, r) * step(r, 0.9);
		m += smoothstep(0.08, 0.0, k) * band;
	}

	// 星形：star_step 决定连线跨几个顶点
	if (star_points > 1) {
		vec2 q = rot(p, -t * spin_speed * 0.6);
		float R = 0.92 - float(rings - 1) * 0.14 - 0.02;
		R = max(R, 0.3);
		for (int i = 0; i < 8; i++) {
			if (i >= star_points) break;
			float a0 = TAU * float(i) / float(star_points) + TAU * 0.25;
			float a1 = TAU * float(i + star_step) / float(star_points) + TAU * 0.25;
			m += seg(q, vec2(cos(a0), sin(a0)) * R, vec2(cos(a1), sin(a1)) * R, w);
		}
	}

	// 内圈光点：把角度量化到扇区，取最近的扇区中心
	if (orbs > 0) {
		vec2 q = rot(p, t * spin_speed * 1.5);
		float a = atan(q.y, q.x);
		float sector = TAU / float(orbs);
		float ca = round(a / sector) * sector;
		vec2 c = vec2(cos(ca), sin(ca)) * 0.78;
		float d = length(q - c);
		m += ring(d, 0.035, w) + smoothstep(0.02, 0.0, d);
	}

	// 画阵：沿圆周逐角度揭开
	float ang = atan(p.y, p.x) / TAU + 0.5;
	m *= step(ang, appear * 1.001);

	float pulse = 0.85 + 0.15 * sin(t * pulse_speed);
	float halo = smoothstep(1.0, 0.2, r) * 0.08 * glow;
	vec3 col = circle_color.rgb * (m * glow * pulse + halo);
	col += vec3(1.0) * pow(clamp(m, 0.0, 1.0), 3.0) * 0.12;   // 线芯提白，画出"有电"的感觉

	COLOR = vec4(col, clamp(m + halo, 0.0, 1.0) * circle_color.a) * node_tint;
}
