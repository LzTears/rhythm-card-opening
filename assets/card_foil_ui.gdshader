shader_type canvas_item;
render_mode unshaded;

// Only attached to the two premium card fronts. Ink and alpha stay intact.
uniform int foil_grade : hint_range(3, 4) = 3;
uniform bool reduced = false;
uniform float phase_offset = 0.0;
// Re-register a reused illustration to its actual independent-card rarity.
uniform bool rarity_reframe = false;
varying vec4 item_tint;

vec3 rainbow(float hue) {
	vec3 p = abs(fract(vec3(hue) + vec3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0);
	return clamp(p - 1.0, vec3(0.0), vec3(1.0));
}

float pixel_cross(vec2 point, vec2 center) {
	vec2 d = abs(point - center);
	return (1.0 - step(0.008, min(d.x, d.y))) * (1.0 - step(0.025, max(d.x, d.y)));
}

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	// Preserve the original silhouette: no halo, bloom, or added alpha outside it.
	if (ink.a < 0.001) {
		discard;
	}
	vec2 q = (floor(UV * 128.0) + vec2(0.5)) / 128.0;
	vec2 p = q - vec2(0.5);
	float radius = length(p);
	float tick = reduced ? 0.75 : floor(TIME * 12.0) / 12.0;
	float strength = reduced ? 0.4 : 1.0;
	// Four discrete zones reserve the central animal print. Most foil is on the
	// surrounding field and rim; the inner illustration receives no tint at all.
	float area = floor(clamp((radius - 0.23) / 0.19, 0.0, 1.0) * 4.0) / 4.0;
	float sweep_position = fract(q.x * 0.72 + q.y * 0.43 - tick * 0.18 + phase_offset);
	float sweep = 1.0 - step(0.045, abs(sweep_position - 0.5));
	float soft_band = 1.0 - step(0.15, abs(sweep_position - 0.5));
	float wink = reduced ? 0.0 : step(0.78, 0.5 + 0.5 * sin(tick * 2.1 + phase_offset * 6.28));
	float glints = max(pixel_cross(p, vec2(0.34, -0.26)), pixel_cross(p, vec2(-0.32, 0.27))) * wink;
	vec3 result = ink.rgb;
	if (rarity_reframe) {
		// Only the authored outer paper rim changes. The central animal stays intact.
		float rim = step(0.325, radius);
		float shade = floor(clamp(dot(ink.rgb, vec3(0.299,0.587,0.114)),0.0,1.0)*4.0)/4.0;
		vec3 dark_rim = foil_grade == 3 ? vec3(0.42,0.27,0.12) : vec3(0.47,0.13,0.17);
		vec3 light_rim = foil_grade == 3 ? vec3(1.0,0.83,0.43) : vec3(0.98,0.58,0.48);
		result = mix(result,mix(dark_rim,light_rim,shade),rim*0.94);
	}
	if (foil_grade == 3) {
		float gold_ink = step(ink.b + 0.12, ink.r) * step(ink.b + 0.02, ink.g);
		float metal_area = area * mix(0.55, 1.0, gold_ink);
		float shine = min(0.20, sweep * 0.10 + soft_band * 0.035 + glints * 0.065);
		result += vec3(1.0, 0.84, 0.40) * shine * metal_area * strength;
	} else {
		// The original red border retains its identity under a very light foil film.
		float red_ink = step(ink.g * 1.2 + 0.05, ink.r) * step(ink.b * 1.2 + 0.05, ink.r);
		float red_rim = red_ink * step(0.365, radius);
		float film = 0.22 * area * (0.25 + 0.75 * sweep) * mix(1.0, 0.18, red_rim) * strength;
		vec3 spectral = rainbow(fract(q.x * 0.85 + q.y * 0.45 + tick * 0.12 + phase_offset));
		result = mix(result, spectral, film);
		result += vec3(0.94, 0.98, 1.0) * (sweep * 0.035 + glints * 0.065) * area * strength;
	}
	COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), ink.a) * item_tint;
}
