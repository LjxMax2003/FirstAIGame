shader_type canvas_item;

// ============================================================================
// 挥砍弧光 —— 沿弧线扫出的刀锋
// ----------------------------------------------------------------------------
// 用途：傩面·师刀（whip）横扫、剪纸刀（blade）挥击、进化后的范围斩。
// 挂载：**直接挂在现有的弧光贴图上**（Art.WHIP_ARC / NUO_BLADE_ARC），
//       本 shader 只做遮罩与过曝，不改画风 —— 美术画的弧线纹理全部保留。
// 渲染：canvas_item · Mobile / Compatibility / Forward+ 全通用
// 采样：1 次 TEXTURE（无额外采样）
// ----------------------------------------------------------------------------
// 为什么用「遮罩」而不是「程序化画弧」：
//   站点上的 procedural slash 都是纯数学生成，风格硬、和本作的剪纸笔触对不上；
//   遮罩方案让同一条弧光能演出"扫出去"的过程，而美术资产零改动。
//
// progress 的含义：0 = 起手（看不见），1 = 收势（整条弧可见）。
// 用法是 progress 0→1 用 0.08~0.14 秒推完，配合 WeaponManager 的 FX 生命周期。
// ============================================================================

group_uniforms Sweep;
uniform float progress : hint_range(0.0, 1.0) = 1.0;         // 扫出进度，脚本 0 → 1
uniform vec2 pivot = vec2(0.0, 0.5);                          // 起手点（UV 空间），左中 = 从左往右扫
uniform float start_angle : hint_range(-3.14, 3.14) = -1.35;  // 起始角（弧度）
uniform float arc_span : hint_range(0.2, 6.28) = 2.5;         // 整条弧占多少弧度
uniform bool flip = false;                                     // 反向挥（配合 flip_h）

group_uniforms Look;
uniform vec4 edge_color : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform float edge_width : hint_range(0.0, 0.6) = 0.10;        // 刀锋亮带宽度（占弧长的比例）
uniform float edge_boost : hint_range(0.0, 4.0) = 1.35;        // 刀锋过曝量
uniform float tail_fade : hint_range(0.0, 1.0) = 0.55;         // 刀尾衰减，0 = 整条一样亮

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// 以 pivot 为圆心取角，注意 pivot 可能落在像素边界上，加个极小量防止 atan(0,0)
	vec2 p = UV - pivot;
	if (flip) {
		p.x = -p.x;
	}
	p += vec2(1e-5);

	float ang = atan(p.y, p.x) - start_angle;
	ang = mod(ang + TAU, TAU);                     // 0 .. TAU

	float in_arc = step(ang, arc_span);            // 只保留弧内的像素
	float t = clamp(ang / arc_span, 0.0, 1.0);     // 0 起手 → 1 收势

	// 扫出：t 小于 progress 的部分已经"划过"，用极窄的软过渡当刀锋边缘
	float swept = 1.0 - smoothstep(progress - 0.015, progress + 0.015, t);

	// 刀尾衰减：越靠起手越淡，让弧光读起来有方向
	float tail = mix(1.0, smoothstep(0.0, 1.0, t), tail_fade);

	// 刀锋亮带：贴着当前 progress 的一条窄带
	float head = 1.0 - smoothstep(0.0, edge_width + 1e-4, abs(t - progress));
	head *= head;

	float mask = in_arc * swept * tail;

	vec3 rgb = tex.rgb;
	rgb += tex.rgb * head * edge_boost;            // 刀锋处把原画整体提亮
	rgb += edge_color.rgb * head * edge_boost * 0.45;

	COLOR = vec4(rgb, tex.a * mask) * node_tint;
}
