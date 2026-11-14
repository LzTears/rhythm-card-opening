shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;

void fragment() {
	// The authored silver spiral, engraved grooves and stepped rim are the back.
	// Keep the same shared source as the five generic reward cards.
	vec4 source = texture(source_texture,UV);
	if (source.a<.22) discard;
	ALBEDO = source.rgb;
	ROUGHNESS = .86;
	ALPHA = source.a;
	ALPHA_SCISSOR_THRESHOLD = .22;
}
