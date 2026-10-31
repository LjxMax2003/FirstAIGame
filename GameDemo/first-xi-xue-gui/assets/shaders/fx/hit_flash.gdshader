shader_type canvas_item;

// ============================================================================
// 受击闪光 —— hit flash
// ----------------------------------------------------------------------------
// 用途：敌人 / 玩家被打中的那一瞬变色，让"打中了"在没有伤害数字时也能被感知。
// 挂载：Sprite2D / AnimatedSprite2D / TextureRect 的 material
// 渲染：canvas_item · blend_mix · Mobile / Compatibility / Forward+ 全通用
// 采样：1 次 TEXTURE（关描边）/ 5 次（开描边，只对透明像素多取 4 次）
// ----------------------------------------------------------------------------
// 三个设计取舍，改之前先读：
//
// 1) 默认"整块压成单色"（preserve_shading = 0）。
//    48px 的怪在 720x1280 竖屏上只剩色块，整块变色比整体提亮更容易被眼睛抓到；
//    满屏同色纸片怪时，"整体提亮 10%" 会被背景吃掉。
//
// 2) 自带可选描边，因为它和 assets/shaders/outline.gdshader 抢同一个 material 槽。
//    一个 CanvasItem 只能挂一个 ShaderMaterial —— 快速怪请直接用本 shader，
//    把 outline_width 设成 2，就同时拿到"描边预警 + 受击闪"。
//
// 3) modulate / self_modulate 在 vertex() 取出来最后再乘。
//    否则 flash 一开就把节点调色覆盖掉了（这是 Godot 4 canvas shader 的经典坑：
//    fragment() 里的 COLOR 是输出变量，写了就被覆盖，不会自动保留顶点色）。
// ============================================================================

group_uniforms Flash;
uniform vec4 flash_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;           // 0 = 原图，1 = 纯色；脚本 tween 1 → 0
uniform bool active = false;                                  // 懒人开关：true 等同 amount = 1
uniform float preserve_shading : hint_range(0.0, 1.0) = 0.0;  // 0 平涂 / 1 保留明暗层次
uniform float boost : hint_range(0.0, 3.0) = 1.35;             // 闪色亮度倍率，>1 略过曝

group_uniforms Outline;
uniform vec4 outline_color : source_color = vec4(0.37, 0.88, 0.82, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 0.0;      // 0 = 关闭描边

varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = active ? 1.0 : amount;

	// 受击闪：把原图往目标色推，alpha 保持不变（轮廓不变形，只有颜色变）
	if (a > 0.0) {
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		vec3 shaded = flash_color.rgb * boost * mix(1.0, 0.45 + lum * 1.1, preserve_shading);
		tex.rgb = mix(tex.rgb, shaded, a);
	}

	// 可选描边：只在贴图 alpha 之外补一圈纯色
	// 注意：Godot 着色语言不允许在 fragment() 里 return，只能一路算到底再赋值
	vec4 out_col = tex;
	if (outline_width > 0.0 && tex.a < 0.05) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float o = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
				+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (o > 0.05) {
			out_col = outline_color;
		}
	}

	COLOR = out_col * node_tint;
}
