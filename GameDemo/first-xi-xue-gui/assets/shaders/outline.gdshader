shader_type canvas_item;

// 轮廓描边：在贴图 alpha 之外补一圈纯色，用于"快速怪"的速度预警。
// 48px 屏幕尺寸下，颜色先于细节被看见——玩家来不及读图，只能靠色块判断"这只会不会咬到我"。
// 只在 fast 种类上开，其余敌人保持无描边；全场都发光等于没有预警。

uniform vec4 outline_color : source_color = vec4(0.37, 0.88, 0.82, 1.0);
uniform float outline_width = 2.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.05) {
		COLOR = c;
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
				+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		COLOR = a > 0.05 ? outline_color : vec4(0.0);
	}
}
