shader_type canvas_item;

// ============================================================================
// 等级外框 —— 让"这把技能升到几级了"一眼看出来
// ----------------------------------------------------------------------------
// 用途：武器槽图标、光环范围圈、环绕体本体。常驻，不参与一次性演出。
// 挂载：Sprite2D / TextureRect（有 alpha 的图都行）
// 渲染：canvas_item · blend_mix · Mobile / Compatibility / Forward+ 全通用
// 采样：9 次（1 本体 + 8 邻域）。**这是本包采样最多的一个**，所以只给常驻的
//       个位数节点用（6 个武器槽 / 1 个光环圈），不要挂到小怪或弹幕上。
// ----------------------------------------------------------------------------
// 为什么"升级区分"必须这样做：
//   本作 MAX_LEVEL = 8，如果每级都换贴图，美术要画 6×8 张；如果只加数字，玩家
//   在战斗里看不见。可复用的做法是**同一张图 + 三档颜色 + 三档厚度 + 流动速度**，
//   因为颜色是前注意（pre-attentive）的：玩家不用读，余光就知道"这把变金了"。
//
//   分档（rank 1~8 连续驱动，中间值会平滑过渡）：
//     Lv1~2  无外框（新手期不该有噪音）
//     Lv3~4  冷白细框
//     Lv5~6  金框
//     Lv7~8  朱红粗框 + 流动加快
//     进化   强制朱红 + 双倍强度（evolved = true）
// ============================================================================

group_uniforms Rank;
uniform float rank : hint_range(1.0, 8.0, 1.0) = 1.0;   // 直接喂 WeaponManager.weapon_level()
uniform bool evolved = false;                            // 进化形态：无视 rank 直接最高档

group_uniforms Rim;
uniform float rim_width : hint_range(0.0, 8.0) = 2.0;    // 基础外框宽度（贴图像素）
uniform float rim_strength : hint_range(0.0, 3.0) = 1.0;
uniform vec4 low_color : source_color = vec4(0.80, 0.92, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.78, 0.32, 1.0);
uniform vec4 high_color : source_color = vec4(1.0, 0.36, 0.22, 1.0);

group_uniforms Flow;
uniform float flow_speed : hint_range(0.0, 6.0) = 1.2;   // 外框上流动的高光速度
uniform float flow_amount : hint_range(0.0, 1.0) = 0.35; // 0 = 恒定亮，1 = 强明暗流动
uniform float inner_glow : hint_range(0.0, 2.0) = 0.0;   // 本体整体泛色（高等级才有）

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// rank 归一化：1 → 0.0，8 → 1.0
	float t = clamp((rank - 1.0) / 7.0, 0.0, 1.0);

	// 三档颜色：低 → 中 → 高，中间值线性过渡（升级时 tween rank 就能看到"变色过程"）
	vec3 tier = t < 0.5
			? mix(low_color.rgb, mid_color.rgb, t * 2.0)
			: mix(mid_color.rgb, high_color.rgb, (t - 0.5) * 2.0);
	if (evolved) {
		tier = high_color.rgb;
	}

	// Lv1~2 完全不出框：新手期画面越干净越好
	float gate = smoothstep(2.2, 3.0, rank);
	if (evolved) {
		gate = 1.0;
	}

	// 8 邻域采样：靠近本体边缘的透明像素被点亮成框
	// 进化态的框宽拉到 2 倍 —— Lv8 与进化必须能一眼分开，否则"进化"只是换个数字
	float w = rim_width * mix(0.75, 1.7, t) * (evolved ? 2.0 : 1.0);
	vec2 px = TEXTURE_PIXEL_SIZE * w;
	const float D = 0.7071;

	float around = 0.0;
	around = max(around, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	around = max(around, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	around = max(around, texture(TEXTURE, UV + vec2(px.x * D, px.y * D)).a);
	around = max(around, texture(TEXTURE, UV - vec2(px.x * D, px.y * D)).a);
	around = max(around, texture(TEXTURE, UV + vec2(px.x * D, -px.y * D)).a);
	around = max(around, texture(TEXTURE, UV - vec2(px.x * D, -px.y * D)).a);

	// 只画在"本体之外、邻域有东西"的位置；本体内部保持原样
	float rim = around * (1.0 - step(0.05, tex.a));

	// 沿轮廓流动的高光：角向三重正弦，读起来像"能量在绕"
	vec2 p = UV - 0.5;
	float ang = atan(p.y, p.x);
	float sweep = 0.5 + 0.5 * sin(ang * 3.0 - TIME * flow_speed * 2.0);
	rim *= mix(1.0, 0.5 + 1.1 * sweep, flow_amount);

	// 进化态：整圈"通电"。高频呼吸 + 更亮，和 Lv8 的区别不需要看颜色就能感知
	if (evolved) {
		rim *= 1.35 * (1.0 + 0.22 * sin(TIME * 9.0));
	}

	rim *= gate * rim_strength;

	vec3 rgb = tex.rgb + tier * rim;
	rgb += tex.rgb * tier * inner_glow * gate * t;   // 高等级的本体也微微泛色

	float alpha = max(tex.a, clamp(rim, 0.0, 1.0));

	COLOR = vec4(rgb, alpha) * node_tint;
}
