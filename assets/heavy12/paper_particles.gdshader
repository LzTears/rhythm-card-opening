shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

varying flat vec4 event_info;
varying flat vec4 paper_info;
uniform vec3 cream : source_color = vec3(0.98, 0.91, 0.74);
uniform vec3 amber : source_color = vec3(0.43, 0.26, 0.12);

void vertex() {
    event_info = INSTANCE_CUSTOM;
    paper_info = COLOR;
    float life = clamp(event_info.x / max(event_info.y, 0.001), 0.0, 1.0);
    float t = max(0.0, life - 0.065);
    float seed = paper_info.r;
    float angle = seed * 6.283185 + paper_info.g * 4.7;
    float radius = clamp(paper_info.a, 0.04, 1.6);
    float mode = round(event_info.z);
    float speed = mode == 6.0 ? 0.16 : (0.25 + radius * 0.70);
    float spin = (seed - 0.5) * 11.0 * t;
    vec2 corner = VERTEX.xy;
    float chip_size = mode == 6.0 ? 0.044 : mix(0.058, 0.110, fract(seed * 7.3));
    corner *= chip_size;
    corner.y *= 0.67;
    corner = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * corner;
    corner.x *= 0.45 + abs(cos(t * 10.0 + seed * 4.0)) * 0.55;
    vec2 flight = vec2(cos(angle) * speed * t * 2.7, sin(angle) * speed * t * 0.68 + speed * (2.6 * t - 3.8 * t * t));
    if (mode == 2.0) {
        // Waves scatter a low handful of paper dust flakes, not an explosion.
        flight.y *= 0.43;
        flight.x *= 1.35;
    }
    if (mode == 4.0) flight *= 0.48 * (1.0 - t);
    VERTEX.xy = corner + flight;
}

void fragment() {
    float life = clamp(event_info.x / max(event_info.y, 0.001), 0.0, 1.0);
    vec2 p = abs(UV - 0.5) * 2.0;
    float torn = step(0.78, UV.x) * step(UV.y, 0.30);
    float mask = (1.0 - smoothstep(0.84, 1.0, max(p.x, p.y))) * (1.0 - torn);
    float edge = step(0.62, max(p.x, p.y));
    ALBEDO = mix(cream, amber, edge * 0.64 + step(0.66, paper_info.r) * 0.14);
    ALPHA = mask * paper_info.b * smoothstep(0.015, 0.08, life) * (1.0 - smoothstep(0.35, 0.93, life));
}
