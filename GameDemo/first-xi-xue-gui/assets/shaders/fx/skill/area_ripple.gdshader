shader_type canvas_item;
render_mode blend_add;

// ============================================================================
// 范围伤害水波纹 —— "这一圈里在持续烧"的持续表现
// ----------------------------------------------------------------------------
// 用途：花灯（halo）领域第二层、皮影环绕体的轨迹圈、任何"常驻范围伤害"。
// 挂载：ColorRect（正方形，边长 = 范围直径），由 ShaderFX.ripple() 建。
// 渲染：canvas_item · blend_add · Mobile / Compatibility / Forward+ 全通用
// 采样：0 次 —— 纯同心环数学，整块面积只是几条 ALU
// ----------------------------------------------------------------------------
// 和 aura_field 的分工（别混用）：
//   aura_field   = 环流噪声，描述"场在那里、在转"，用于**边界带**
//   area_ripple  = 同心环由内向外推，描述"场一直在输出伤害"，用于**内部**
//   两者叠起来才是完整的：边界告诉你"站到哪算走出去"，波纹告诉你"圈内在挨打"。
//
// 改编自 godotshaders「Circular Waves 2D」（MIT），**去掉了**它依赖的 SCREEN_TEXTURE
// 折射那段 —— 本作移动端后端不支持，而且我们只要环、不要背景扭曲。
//
// 三个必须守的红线（踩过）：
//   ① blend_add 下 src 会被再乘一次 src.a → COLOR.a 恒 1.0，亮度全算进 rgb。
//      写成 a<1 会得到"越亮越透"的怪结果。
//   ② 节点 modulate 必须纯白，否则顶点色会当乘数把环染色（ShaderFX.ripple 里设的）。
//   ③ 径向 shader 不能拿 UV 直接算半径 —— 非正方形时环会变椭圆。
//      这里按**短边**归一化：p = (UV-0.5)*2 * size/min(size)。正方形时系数正好是 1。
// ============================================================================

group_uniforms Shape;
// 节点像素尺寸。用途只有一个：非正方形时把环拉回正圆（短边归一化）。
uniform vec2 rect_size = vec2(256.0, 256.0);
uniform float inner : hint_range(0.0, 1.0) = 0.10;      // 内径，环从这里开始（0 = 圆心）
uniform float outer : hint_range(0.0, 1.0) = 0.98;      // 外径，环到这里消失
uniform float softness : hint_range(0.01, 0.5) = 0.14;  // 内外边界的羽化宽度

group_uniforms Wave;
uniform float rings : hint_range(0.5, 8.0) = 2.0;       // 半径方向上有几圈（越大越密）
uniform float speed : hint_range(0.0, 6.0) = 1.6;       // 每秒往外推几圈（0 = 静止花纹）
uniform float wave_power : hint_range(1.0, 16.0) = 5.0; // 越大环越细、越像一道锋面
uniform vec4 ring_color : source_color = vec4(1.0, 0.62, 0.30, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.55;

group_uniforms Pulse;
// 命中时置 1 再衰减（接 GarlicRing.beat()）。和连续环叠加：环是"一直在烧"，
// pulse 是"这一下打中了"。两种语义都要有，混成一个就都读不出来。
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_boost : hint_range(0.0, 2.0) = 0.9;

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	// 短边归一化：正方形 rect 时系数为 1，非正方形时短边方向仍落在 0..1
	float m = max(min(rect_size.x, rect_size.y), 1.0);
	vec2 p = (UV - 0.5) * 2.0 * (rect_size / m);
	float r = length(p);

	// 环带遮罩：内径软进、外径软出，避免圆心一个亮点 + 方角一刀切
	float band = smoothstep(inner, inner + softness, r)
			* (1.0 - smoothstep(outer - softness, outer, r));

	// 同心环：相位随半径增大，TIME 让同相位的点向外走（负号不能丢，丢了就是往里收）
	float phase = r * rings - TIME * speed;
	// cos 而不是 fract：fract 在环的收尾处会有一条硬接缝，cos 天然连续
	float wave = pow(0.5 + 0.5 * cos(phase * 6.2831853), wave_power);

	float a = band * wave * intensity * (1.0 + pulse * pulse_boost);

	// alpha 恒 1.0，亮度全在 rgb（见文件头 ①）
	COLOR = vec4(ring_color.rgb * a, 1.0) * node_tint;
}
