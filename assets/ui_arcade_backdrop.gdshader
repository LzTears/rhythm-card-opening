shader_type canvas_item;
render_mode unshaded;

// Authored paper-silhouette backdrop. It never samples the interactive world.
uniform sampler2D background_art : source_color, filter_nearest;
uniform bool has_art = false;
uniform float art_strength : hint_range(0.0, 1.0) = 1.0;
uniform float reduced : hint_range(0.0, 1.0) = 0.0;
uniform vec2 surface_size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 px = floor(UV * surface_size / 2.0) * 2.0;
	vec2 pixel_uv = (px + 1.0) / max(surface_size, vec2(1.0));
	vec2 p = pixel_uv * 2.0 - 1.0;
	float edge = max(abs(p.x), abs(p.y));
	vec3 base = mix(vec3(0.18,0.13,0.28),vec3(0.07,0.045,0.13),clamp(edge,0.0,1.0));
	if (has_art) {
		vec4 art = texture(background_art,pixel_uv);
		base = mix(base,art.rgb,art_strength*art.a);
	}
	COLOR = vec4(base,1.0);
}
