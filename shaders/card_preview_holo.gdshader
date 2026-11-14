shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

// All motion uses the component-owned clock, deliberately never shader TIME.
uniform sampler2D card_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool texture_loaded = false;
uniform int theme_kind = 0;
uniform vec2 texture_texel = vec2(0.00092081, 0.00069061);
uniform vec4 art_bounds = vec4(0.035, 0.083, 0.965, 0.700);
uniform vec4 title_bounds = vec4(0.300, 0.000, 0.700, 0.090);
uniform vec2 tilt = vec2(0.0);
uniform float effect_time = 0.0;
uniform float holo_strength : hint_range(0.0, 1.5) = 1.0;
uniform bool reduced_effects = false;
uniform float parallax_strength : hint_range(0.0, 0.015) = 0.0085;

const float FOIL_TAU = 6.28318530718;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float box_mask(vec2 p, vec4 bounds, float feather) {
	vec2 lo = smoothstep(bounds.xy, bounds.xy + vec2(feather), p);
	vec2 hi = vec2(1.0) - smoothstep(bounds.zw - vec2(feather), bounds.zw, p);
	return lo.x * lo.y * hi.x * hi.y;
}

float ellipse(vec2 p, vec2 center, vec2 radius) {
	float distance_to_center = length((p - center) / radius);
	return 1.0 - smoothstep(0.72, 1.12, distance_to_center);
}

float subject_depth(vec2 uv) {
	// These broad masks infer foreground/background from a single flat image.
	// They do not represent extracted layers, real depth or occluded artwork.
	if (theme_kind == 1) {
		float body = ellipse(uv, vec2(0.51, 0.36), vec2(0.26, 0.29));
		float left_arm = ellipse(uv, vec2(0.24, 0.35), vec2(0.22, 0.20));
		float right_arm = ellipse(uv, vec2(0.79, 0.37), vec2(0.19, 0.20));
		float foreground = max(body, max(left_arm, right_arm) * 0.84);
		return mix(-0.35, 0.80, foreground);
	}
	vec2 center = uv - vec2(0.51, 0.368);
	vec2 rotated = vec2(center.x * 0.876 - center.y * 0.482, center.x * 0.482 + center.y * 0.876);
	float ring_distance = length(rotated / vec2(0.33, 0.105));
	float ring = exp(-pow((ring_distance - 1.0) * 2.9, 2.0));
	float core = ellipse(uv, vec2(0.51, 0.365), vec2(0.20, 0.11));
	return mix(-0.42, 0.72, ring) - core * 0.22;
}

vec3 spectrum(float phase) {
	vec3 wave = vec3(0.5) + vec3(0.5) * cos(phase + vec3(0.0, 2.0943951, 4.1887902));
	return mix(vec3(0.065), wave, 0.935);
}

float gold_mask(vec3 color) {
	float high = max(color.r, max(color.g, color.b));
	float low = min(color.r, min(color.g, color.b));
	float saturation = (high - low) / max(high, 0.001);
	float warm_ratio = color.g / max(color.r, 0.001);
	// Saturation excludes cream paper; green/red ratio excludes red lettering.
	return smoothstep(0.56, 0.78, saturation)
		* smoothstep(0.28, 0.60, color.r)
		* smoothstep(0.34, 0.52, warm_ratio)
		* (1.0 - smoothstep(0.97, 1.12, warm_ratio))
		* smoothstep(0.04, 0.17, color.g - color.b);
}

float foil_height(vec2 uv) {
	vec3 color = texture(card_texture, uv).rgb;
	return gold_mask(color) * dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = UV;
	// The image's rounded card silhouette is also the physical plane silhouette.
	vec2 rounded = abs((uv - vec2(0.5)) * vec2(3.0, 4.0)) - vec2(1.33, 1.83);
	float corner_distance = length(max(rounded, vec2(0.0))) + min(max(rounded.x, rounded.y), 0.0) - 0.17;
	if (corner_distance > 0.0) {
		discard;
	}

	vec3 original = vec3(0.13, 0.008, 0.019);
	if (texture_loaded) {
		original = texture(card_texture, uv).rgb;
	}
	float title_protection = box_mask(uv, title_bounds, 0.008);
	float artwork = box_mask(uv, art_bounds, 0.013) * (1.0 - title_protection);
	// Guarantee an exact stable UV in the text panel, including its upper edge.
	artwork *= 1.0 - step(0.700, uv.y);
	vec2 displaced_uv = uv;
	float depth = subject_depth(uv);
	if (!reduced_effects) {
		displaced_uv += tilt * vec2(-1.0, 0.78) * depth * parallax_strength * artwork * min(holo_strength, 1.0);
	}
	vec3 art_color = original;
	if (texture_loaded) {
		art_color = texture(card_texture, displaced_uv).rgb;
	}
	vec3 color = mix(original, art_color, artwork);
	float luminance = dot(art_color, vec3(0.299, 0.587, 0.114));
	float angle = tilt.x * 4.9 - tilt.y * 3.5;
	float clock = effect_time * 0.24;
	vec2 surface = uv * vec2(0.75, 1.0);
	vec2 facet_grid = surface * vec2(118.0, 118.0);
	vec2 tile = floor(facet_grid);
	vec2 local = fract(facet_grid);
	float triangle = step(local.x + local.y, 1.0);
	float facet_id = hash21(tile + vec2(triangle * 71.0, triangle * 13.0));
	float facet_orientation = facet_id * FOIL_TAU;
	float prism_phase = dot(surface, vec2(2.15, -1.65)) * FOIL_TAU + angle + clock;
	vec3 rainbow = spectrum(prism_phase + facet_id * 0.92);
	float broad_reflection = pow(0.5 + 0.5 * sin(dot(surface, vec2(1.02, -0.70)) * FOIL_TAU + angle * 1.19 + clock), 5.0);
	float facet_reflection = pow(max(0.0, cos(facet_orientation + angle * 1.7 + clock * 1.8)), 8.0);
	float micro_spark = pow(max(0.0, cos(facet_orientation * 2.1 + angle * 2.4 + clock * 2.2)), 30.0)
		* step(0.84, facet_id);
	if (reduced_effects) {
		facet_reflection = 0.0;
		micro_spark = 0.0;
	}
	float intensity = holo_strength * artwork;
	// Colored modulation and colored highlights preserve dark cores and armor.
	// No white screen blend is used for the large-area holographic laminate.
	vec3 interference = art_color * (vec3(0.70) + rainbow * 0.62);
	float material_weight = (0.16 + broad_reflection * 0.24 + facet_reflection * 0.10) * intensity;
	color = mix(color, interference, min(material_weight, 0.68));
	float highlight = (broad_reflection * 0.15 + facet_reflection * 0.070 + micro_spark * 0.13)
		* intensity * smoothstep(0.018, 0.54, luminance);
	color += rainbow * highlight * (0.24 + luminance * 0.64);

	// Warm foil glints apply to gold ink, including emblems, without moving it.
	float gold = gold_mask(original);
	if (texture_loaded) {
		float left_height = foil_height(uv - vec2(texture_texel.x * 1.4, 0.0));
		float right_height = foil_height(uv + vec2(texture_texel.x * 1.4, 0.0));
		float up_height = foil_height(uv - vec2(0.0, texture_texel.y * 1.4));
		float down_height = foil_height(uv + vec2(0.0, texture_texel.y * 1.4));
		vec3 relief_normal = normalize(vec3((left_height - right_height) * 1.6, (down_height - up_height) * 1.6, 0.75));
		vec3 foil_light = normalize(vec3(-0.45 + tilt.x * 0.9, 0.65 - tilt.y * 0.8, 0.72));
		float relief_light = dot(relief_normal, foil_light);
		color *= 1.0 + gold * holo_strength * (relief_light - 0.60) * 0.17;
	}
	float gold_sweep = pow(0.5 + 0.5 * cos(dot(surface, vec2(0.82, -0.59)) * FOIL_TAU + angle * 1.05 + clock * 0.8), 15.0);
	color += vec3(0.46, 0.265, 0.055) * gold * gold_sweep * holo_strength * 0.58;

	// The red frame catches a ruby sheen; holographic rainbow stays in the art.
	float frame = 1.0 - box_mask(uv, vec4(0.053, 0.083, 0.947, 0.962), 0.013);
	float ruby = smoothstep(0.12, 0.32, original.r - max(original.g, original.b))
		* smoothstep(0.15, 0.46, original.r) * frame * (1.0 - title_protection);
	color += vec3(0.11, 0.002, 0.009) * ruby * gold_sweep * holo_strength;
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.3;
}
