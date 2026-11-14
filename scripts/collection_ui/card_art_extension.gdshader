shader_type canvas_item;
render_mode unshaded;

// Background pass only. The separate, sharp contain TextureRect stays intact.
// Rectangles use normalized xywh, not left/top/right/bottom.
uniform vec4 foreground_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 source_valid_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 window_pixels = vec2(714.0, 632.0);
// Never reach the middle of the picture: a moon/face must not become a backdrop.
uniform float edge_depth : hint_range(0.002, 0.05, 0.001) = 0.024;
// Optional monotonic tangential adjustment; no noise or periodic tile offset.
uniform float edge_flow : hint_range(0.0, 0.06, 0.001) = 0.0;
// Gaussian support radius in design pixels, growing from zero at the join.
uniform float softness_pixels : hint_range(0.0, 64.0, 1.0) = 32.0;

varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

// Reflect filter taps at source endpoints without exposing transparent padding.
vec2 mirror_unit(vec2 value) {
	return vec2(1.0) - abs(mod(value, vec2(2.0)) - vec2(1.0));
}

vec2 safe_source_uv(vec2 local_uv, vec2 source_texel) {
	vec2 half_texel = source_texel * 0.5;
	vec2 lo = max(source_valid_rect.xy, half_texel);
	vec2 hi = min(source_valid_rect.xy + source_valid_rect.zw, vec2(1.0) - half_texel);
	return clamp(source_valid_rect.xy + mirror_unit(local_uv) * source_valid_rect.zw, lo, max(lo, hi));
}

// Work in straight-alpha source space, average in premultiplied space.
vec4 premultiplied_sample(sampler2D art_texture, vec2 local_uv, vec2 source_texel) {
	vec4 value = texture(art_texture, safe_source_uv(local_uv, source_texel));
	return vec4(value.rgb * value.a, value.a);
}

void fragment() {
	vec2 fitted_size = max(foreground_rect.zw, vec2(0.0001));
	vec2 local_uv = (UV - foreground_rect.xy) / fitted_size;
	vec2 outer = max(-local_uv, local_uv - vec2(1.0));
	vec2 distance_out = max(outer, vec2(0.0));
	vec2 fitted_pixels = max(window_pixels * fitted_size, vec2(1.0));
	vec2 outside_pixels = distance_out * fitted_pixels;
	float join_distance = length(outside_pixels);
	vec2 source_uv = clamp(local_uv, vec2(0.0), vec2(1.0));

	if (join_distance < 0.001) {
		// Hidden under the foreground. This is also the exact edge-join color.
		vec4 original = texture(TEXTURE, safe_source_uv(source_uv, TEXTURE_PIXEL_SIZE));
		COLOR = vec4(original.rgb * vertex_tint.rgb, vertex_tint.a);
	} else {
		// One bounded edge-strip continuation. No periodic mirroring, tile or
		// full-image cover: the center subject is never sampled for padding.
		vec2 gap_before = max(foreground_rect.xy / fitted_size, vec2(0.0001));
		vec2 gap_after = max((vec2(1.0) - foreground_rect.xy - fitted_size) / fitted_size, vec2(0.0001));
		vec2 gap_extent = mix(gap_before, gap_after, step(vec2(1.0), local_uv));
		vec2 gap_fraction = clamp(distance_out / gap_extent, vec2(0.0), vec2(1.0));
		vec2 depth = edge_depth * gap_fraction;
		vec2 inward_sign = vec2(1.0) - step(vec2(1.0), local_uv) * 2.0;
		source_uv += depth * inward_sign;
		vec2 flow_envelope = gap_fraction * gap_fraction * (vec2(3.0) - 2.0 * gap_fraction);
		source_uv.y += (clamp(local_uv.y, 0.0, 1.0) - 0.5) * edge_flow * flow_envelope.x;
		source_uv.x += (clamp(local_uv.x, 0.0, 1.0) - 0.5) * edge_flow * flow_envelope.y;

		// Gradually replace high-frequency edge marks by their local Gaussian
		// neighborhood. Wide gaps receive a larger radius, never a dark tint.
		bool side_gap = outside_pixels.x >= outside_pixels.y;
		float gap_pixels = side_gap ? gap_extent.x * fitted_pixels.x : gap_extent.y * fitted_pixels.y;
		float soften = smoothstep(0.0, max(24.0, gap_pixels * 0.7), join_distance);
		float width_gain = mix(0.7, 1.15, smoothstep(35.0, 160.0, gap_pixels));
		vec2 radius = vec2(softness_pixels * width_gain * soften) / fitted_pixels;
		vec2 tangent = side_gap ? vec2(0.0, radius.y / 6.0) : vec2(radius.x / 6.0, 0.0);
		// Thirteen bounded taps, Gaussian sigma = support radius / 2.5.
		// All offsets are tangential so nearby central eyes/moons remain excluded.
		vec4 average = premultiplied_sample(TEXTURE, source_uv, TEXTURE_PIXEL_SIZE) * 0.167291898;
		average += (premultiplied_sample(TEXTURE, source_uv + tangent, TEXTURE_PIXEL_SIZE) + premultiplied_sample(TEXTURE, source_uv - tangent, TEXTURE_PIXEL_SIZE)) * 0.153382473;
		average += (premultiplied_sample(TEXTURE, source_uv + tangent * 2.0, TEXTURE_PIXEL_SIZE) + premultiplied_sample(TEXTURE, source_uv - tangent * 2.0, TEXTURE_PIXEL_SIZE)) * 0.118216532;
		average += (premultiplied_sample(TEXTURE, source_uv + tangent * 3.0, TEXTURE_PIXEL_SIZE) + premultiplied_sample(TEXTURE, source_uv - tangent * 3.0, TEXTURE_PIXEL_SIZE)) * 0.076591812;
		average += (premultiplied_sample(TEXTURE, source_uv + tangent * 4.0, TEXTURE_PIXEL_SIZE) + premultiplied_sample(TEXTURE, source_uv - tangent * 4.0, TEXTURE_PIXEL_SIZE)) * 0.041714604;
		average += (premultiplied_sample(TEXTURE, source_uv + tangent * 5.0, TEXTURE_PIXEL_SIZE) + premultiplied_sample(TEXTURE, source_uv - tangent * 5.0, TEXTURE_PIXEL_SIZE)) * 0.019098338;
		average += (premultiplied_sample(TEXTURE, source_uv + tangent * 6.0, TEXTURE_PIXEL_SIZE) + premultiplied_sample(TEXTURE, source_uv - tangent * 6.0, TEXTURE_PIXEL_SIZE)) * 0.007350293;
		vec3 color = average.rgb / max(average.a, 0.0001);
		// The backing fills its gap even for an alpha PNG. A fully transparent
		// edge has no recoverable scenery; retain its stored RGB as the fallback.
		if (average.a <= 0.0001) { color = texture(TEXTURE, safe_source_uv(source_uv, TEXTURE_PIXEL_SIZE)).rgb; }
		COLOR = vec4(color * vertex_tint.rgb, vertex_tint.a);
	}
}
