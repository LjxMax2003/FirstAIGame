shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 发动冲击环 —— 技能"出手"的那一帧
// ----------------------------------------------------------------------------
// 用途：任何技能触发的瞬间（横扫起手、光环一跳、泼射、进化爆发）。
//       同一个 shader 两种模式：扩散（出招）/ 收拢（蓄力）。
// 挂载：ColorRect（尺寸 = 冲击环的外径），放在技能中心、本体的下层
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 纯数学，同屏十几个也不吃带宽
// ----------------------------------------------------------------------------
// 三条设计约束：
// 1) 必须能压扁。傩面·师刀是横向矩形判定（length × width），圆环会读错范围；
//    把 squash 设成 (1.7, 0.5) 就是一条贴着判定框的椭圆冲击波。
// 2) 必须能关光条。rays = 0 是纯环，适合"灯晕一跳"；rays = 8~12 才有爆点的狠劲。
// 3) gather = true 时同一个参数反向走，变成"向心收拢"，用于进化/蓄力预警，
//    不再单独写一个 charge shader —— 少一个 uniform、少一份维护。
// ============================================================================

group_uniforms Burst;
uniform float progress : hint_range(0.0, 1.0) = 0.0;      // 0 → 1 播完；脚本驱动
uniform bool gather = false;                               // false 扩散 / true 收拢
uniform float rings : hint_range(1.0, 3.0, 1.0) = 1.0;     // 同心环数
uniform float spread : hint_range(0.1, 1.0) = 0.9;         // 外径（UV 归一化，1.0 = 触边）
uniform float width : hint_range(0.01, 0.5) = 0.12;        // 环带宽
uniform vec2 squash = vec2(1.0, 1.0);                      // 压扁：横扫 (1.7, 0.5)
uniform int rays : hint_range(0, 24) = 0;                  // 径向光条数，0 = 关
uniform float ray_sharp : hint_range(0.5, 8.0) = 3.0;

group_uniforms Look;
uniform vec4 burst_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float intensity : hint_range(0.0, 5.0) = 2.2;
uniform float core : hint_range(0.0, 3.0) = 0.6;           // 中心亮点强度
uniform float fade_pow : hint_range(0.5, 4.0) = 1.2;       // 越大掉得越快

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	// 归一化到 -1..1，再按 squash 反向缩放坐标 = 把画出来的圆压成椭圆
	vec2 p = (UV - 0.5) * 2.0;
	p /= max(squash, vec2(0.001));

	float d = length(p);

	// gather：半径从大到小；否则从小到大
	float k = gather ? (1.0 - progress) : progress;
	float r = mix(0.02, spread, k);

	// 多重同心环：第 0 环最外、最强
	float band = 0.0;
	for (int i = 0; i < 3; i++) {
		if (float(i) >= rings) break;
		float ri = r * (1.0 - float(i) * 0.16);
		float w = width * (1.0 - float(i) * 0.25);
		band = max(band, 1.0 - smoothstep(0.0, w + 1e-4, abs(d - ri)));
	}

	// 整体包络：起手 0.15 内快速淡入（否则第一帧是个空环），之后逐渐消失
	float env = smoothstep(0.0, 0.15, progress) * pow(1.0 - progress, fade_pow);

	// 径向光条：按角度做三角波，pow 收窄成尖条
	float spokes = 1.0;
	if (rays > 0) {
		float ang = atan(p.y, p.x);
		float s = abs(fract(ang / TAU * float(rays)) - 0.5) * 2.0;   // 0..1
		spokes = mix(0.28, 1.0, pow(1.0 - s, ray_sharp));
	}

	// 中心亮核
	float core_v = core * (1.0 - smoothstep(0.0, max(r, 0.05), d));

	float a = (band * spokes + core_v) * intensity * env;

	COLOR = vec4(burst_color.rgb * a, 1.0) * node_tint;
}
