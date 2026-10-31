shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 铁水散开 · 漫天火星 —— 打铁花的签名
// ----------------------------------------------------------------------------
// 用途：v6 §4「铁水团撞到第一只实体即碎裂，半径 150 溅成一片小火星」。
// 挂载：ColorRect（边长 = 2 × 溅射半径），放碎裂点，z 低于弹体。
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 纯数学。同屏十几团同时炸也不吃带宽。
// ----------------------------------------------------------------------------
// 为什么不能复用 cast_burst：
//   cast_burst 画的是**一条干净环**（一个锋面、宽窄一致），它的语义是"敲了一下"。
//   铁水是"一团熔铁砸在地上散成一片火星"——没有环，只有一堆各自往外飞、各自熄灭的
//   亮点，中间还有熔核的余温。形状语言完全不同，复用只会让打铁花和铜锣读成同一件事。
//
// 三个坑（都是本工程踩过的，别改回去）：
//   ① blend_add 下 COLOR.a 恒 1.0，所有亮度都算进 rgb。所以本文件从不写半透明"覆盖层"，
//      只写"加多少光"；node_tint 也必须给纯白，否则顶点色会当乘数把火星染脏。
//   ② 极坐标噪声的接缝：直接用 (atan, r) 当噪声坐标，atan 在 ±PI 处断开，环上会留一条
//      笔直的缝。这里把角度映射到**单位圆上的坐标**再采样（同 aura_field），天然连续。
//   ③ 半径是"短边归一化的比例"，不是像素。节点是正方形（2r × 2r），但外层容器可能被
//      缩放，所以这里用 rect_size 现场换算，非正方形也不会变成椭圆。
// ============================================================================

group_uniforms Shape;
uniform vec2 rect_size = vec2(300.0, 300.0);                // 节点像素尺寸，API 跟随 resize 写
uniform float radius : hint_range(0.0, 1.0) = 0.95;         // 火星外缘，留边避免被矩形裁掉
uniform float spread : hint_range(0.0, 1.0) = 0.85;         // 火星从中心往外推到的比例
uniform float sparks : hint_range(0.5, 12.0) = 5.0;         // 火星密度（角度分格数 = sparks × 7）
uniform float noise_scale : hint_range(1.0, 24.0) = 7.0;    // 火星颗粒尺度
uniform float spark_power : hint_range(1.0, 16.0) = 6.0;    // 单颗火星的锐度（越大越细）
uniform float speed : hint_range(0.0, 6.0) = 1.4;           // 每秒推几轮，读作扩散速度

group_uniforms Look;
uniform vec4 scatter_color : source_color = vec4(1.0, 0.478, 0.102, 1.0);  // #FF7A1A 铁水橙红
uniform vec4 core_color : source_color = vec4(1.0, 0.82, 0.42, 1.0);       // #FFD16B 熔核
uniform float intensity : hint_range(0.0, 3.0) = 1.4;       // 未开 HDR2D 别超 1.6，否则过曝

group_uniforms Pulse;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;           // 碎裂置 1，脚本推回 0
uniform float pulse_boost : hint_range(0.0, 2.0) = 1.0;

varying vec4 node_tint;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
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
	// 短边归一化：d = 1.0 正好落在短边的一半上
	float edge = max(min(rect_size.x, rect_size.y) * 0.5, 1.0);
	vec2 q = (UV - 0.5) * rect_size / edge;
	float d = length(q);
	float dn = d / max(radius, 1.0e-3);        // 0 = 中心，1 = 外缘
	float ang = atan(q.y, q.x);
	float turn = ang / TAU + 0.5;              // 0..1 环向

	// 包络：碎裂瞬间最亮，之后整片一起暗下去；火星本身继续往外飞
	float k = clamp(pulse, 0.0, 1.0);
	float env = mix(0.18, 1.0, k) * (1.0 + pulse_boost * k * 0.35);

	// ---- ① 火星：按角度分格，每格一个固定随机数 → 稳定的"一颗火星一条线"
	//      用 TIME 推进而不是每帧随机：随机会让画面变成一片雪花噪点，
	//      看不出"从中心往外飞"。分格 + 固定相位才读得出方向。
	float cells = max(sparks, 1.0) * 7.0;
	float cf = turn * cells;
	float idx = floor(cf);

	float r1 = hash11(idx);
	float ph1 = fract(TIME * speed * (0.45 + 0.85 * r1) + r1 * 7.3);
	float head1 = spread * radius * (0.16 + 0.84 * ph1);
	float dash1 = 1.0 - smoothstep(0.0, 0.075, abs(d - head1));
	float seg1 = abs(fract(cf) - 0.5) * 2.0;                 // 0 格中心 / 1 格边界
	float thin1 = pow(max(1.0 - seg1, 0.0), spark_power * 0.5);

	// 第二层：错开半个格 + 不同种子。只有一层时，火星会排成均匀的放射状虚线
	float r2 = hash11(idx + 91.7);
	float ph2 = fract(TIME * speed * (0.62 + 0.75 * r2) + r2 * 3.7);
	float head2 = spread * radius * (0.10 + 0.90 * ph2);
	float dash2 = 1.0 - smoothstep(0.0, 0.055, abs(d - head2));
	float seg2 = abs(fract(cf * 1.7 + 0.37) - 0.5) * 2.0;
	float thin2 = pow(max(1.0 - seg2, 0.0), spark_power * 0.6);

	float spark_v = max(dash1 * thin1, dash2 * thin2 * 0.8);

	// ---- ② 火星云：填补火星之间的空隙，让"整片散开"有体积感。
	//      用单位圆坐标采噪声（坑②），再加一个随 TIME 旋转的角向偏移
	float spin = TIME * 0.6;
	vec2 ring = vec2(cos(ang + spin), sin(ang + spin)) * noise_scale;
	vec2 radial = vec2(0.0, dn * noise_scale * 1.9);
	float n = value_noise(ring + radial) * 0.62
			+ value_noise(ring * 2.7 + radial * 2.1 + vec2(7.7, 3.1)) * 0.38;
	// 越靠外越稀：铁水是从中心溅出去的，外缘只有零星几点
	float fall = 1.0 - smoothstep(0.10, radius, d);
	float haze = pow(n, 2.0) * pow(fall, 1.3) * 0.85;

	// ---- ③ 熔核：中心那一小团还在发白热的光
	float core_v = pow(max(0.0, 1.0 - dn * 1.55), 3.0);

	// 冷热分色：中心熔核偏黄白，外圈是铁水橙红
	vec3 col = mix(core_color.rgb, scatter_color.rgb, clamp(dn * 1.35, 0.0, 1.0));
	float a = (spark_v * 1.55 + haze + core_v * 1.15) * intensity * env;

	COLOR = vec4(col * a, 1.0) * node_tint;
}
