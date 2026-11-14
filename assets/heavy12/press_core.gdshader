shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

varying flat vec4 event_info;
varying flat vec4 paper_info;
uniform vec3 ink : source_color = vec3(0.37, 0.22, 0.10);
uniform vec3 paper : source_color = vec3(0.98, 0.91, 0.75);
uniform vec3 folded_paper : source_color = vec3(0.77, 0.59, 0.34);

void vertex() {
    event_info = INSTANCE_CUSTOM;
    paper_info = COLOR;
    float life = clamp(event_info.x / max(event_info.y, 0.001), 0.0, 1.0);
    float delay = round(event_info.z) == 3.0 ? paper_info.g * 0.28 : 0.0;
    float t = clamp((life - delay) / max(1.0 - delay, 0.01), 0.0, 1.0);
    // Camera-facing short pressure-flash. Ground waves remain in the ground material.
    float flatten = exp(-pow((t - 0.14) * 12.0, 2.0));
    float recovery = smoothstep(0.16, 0.45, t);
    VERTEX.x *= 0.70 + flatten * 0.44 + recovery * 0.12;
    VERTEX.y *= 0.78 + flatten * 0.30 - recovery * 0.06;
}

void fragment() {
    float life = clamp(event_info.x / max(event_info.y, 0.001), 0.0, 1.0);
    float delay = round(event_info.z) == 3.0 ? paper_info.g * 0.28 : 0.0;
    float t = clamp((life - delay) / max(1.0 - delay, 0.01), 0.0, 1.0);
    vec2 p = (floor(UV * 64.0) + 0.5) / 64.0 * 2.0 - 1.0;
    float radius = length(p);
    float angle = atan(p.y, p.x) + paper_info.r * 0.17;
    float sector = abs(mod(angle + 0.196350, 0.392699) - 0.196350);
    float spoke = 1.0 - smoothstep(0.025, 0.145, sector);
    // Broad, jagged pixel pressure-star: cream center, amber rim, dark printed cracks.
    // The entire flash expires quickly; this never becomes a persistent white disc.
    float boundary = 0.43 + pow(spoke, 3.0) * 0.47;
    float silhouette = 1.0 - smoothstep(boundary - 0.025, boundary + 0.01, radius);
    float amber_edge = smoothstep(boundary - 0.12, boundary - 0.055, radius);
    float dark_edge = smoothstep(boundary - 0.045, boundary - 0.012, radius);
    float crack_angle = abs(mod(angle + 0.392699, 0.785398) - 0.392699);
    float crack = (1.0 - smoothstep(0.018, 0.048, crack_angle)) * smoothstep(0.10, 0.18, radius) * (1.0 - smoothstep(0.40, 0.63, radius));
    float cross_crack = (1.0 - smoothstep(0.018, 0.046, abs(p.y + p.x * 0.19))) * smoothstep(0.08, 0.18, abs(p.x)) * (1.0 - smoothstep(0.38, 0.61, abs(p.x)));
    vec3 color = mix(paper, vec3(0.92, 0.57, 0.19), amber_edge);
    color = mix(color, ink, max(dark_edge * 0.88, max(crack, cross_crack) * 0.94));
    float show = step(delay, life) * (1.0 - smoothstep(0.22, 0.48, t));
    ALBEDO = color;
    ALPHA = silhouette * show * paper_info.b * 0.98;
}
