shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;

// Only committed effect age drives this shader. TIME is deliberately unused.
varying flat vec4 event_info;
varying flat vec4 paper_info;
uniform vec3 ink : source_color = vec3(0.56, 0.32, 0.12);
uniform vec3 cream : source_color = vec3(0.88, 0.75, 0.49);

void vertex() {
    event_info = INSTANCE_CUSTOM; // seconds, duration, language, capsule straight fraction
    paper_info = COLOR; // seed, propagation phase, opacity, actual radius in metres
}

void fragment() {
    float life = clamp(event_info.x / max(event_info.y, 0.001), 0.0, 1.0);
    float mode = round(event_info.z);
    float delay = mode == 3.0 ? paper_info.g * 0.28 : 0.0;
    float t = clamp((life - delay) / max(1.0 - delay, 0.01), 0.0, 1.0);
    float reached = step(delay, life);
    // A static residual impression lasts to the original event's end, including quiet mode.
    float tail = pow(max(1.0 - t, 0.0), 0.72) * reached;
    vec2 p = (UV - 0.5) * 2.0;
    float alpha = 0.0;
    vec3 color = ink;
    if (mode == 4.0 || mode == 5.0) {
        // The quad spans exactly the committed from/to segment: no invented continuation.
        float edge = 1.0 - smoothstep(0.88, 1.0, abs(p.x));
        float pixel = max(fwidth(p.y), 0.0001);
        float slot = 1.0 - smoothstep(pixel * 0.48, pixel * 1.38, abs(p.y));
        float lips = 1.0 - smoothstep(pixel * 0.48, pixel * 1.1, abs(p.y - pixel * 1.65));
        if (mode == 4.0) {
            // Fold chevrons close towards the actual finish (+X), without electric zigzags.
            float crease_x = fract((p.x + 1.0) * 4.0 - t * 1.7);
            float fold_y = abs(crease_x - 0.5) * 1.20;
            float folds = 1.0 - smoothstep(0.04, 0.10, abs(abs(p.y) - fold_y));
            float convergence = mix(0.30, 1.0, UV.x);
            alpha = (slot * 0.27 + folds * convergence * 0.29 + lips * 0.12) * edge;
        } else {
            // A narrow paper cut with two matte scored lips, never a glowing beam.
            float front = min(life / 0.26, 1.0);
            float arrived = step(UV.x, front);
            float amber_slot = 1.0 - smoothstep(pixel * 1.65, pixel * 3.1, abs(p.y));
            float leading_tip = (1.0 - smoothstep(0.015, 0.045, abs(UV.x - front))) * (1.0 - smoothstep(pixel * 2.0, pixel * 4.5, abs(p.y)));
            alpha = max(amber_slot * 0.83, leading_tip * 0.95) * edge * arrived;
            color = mix(vec3(0.67,0.34,0.09), vec3(1.0,0.95,0.80), max(slot,leading_tip));
        }
    } else {
        float fraction = clamp(event_info.w, 0.0, 0.999);
        float straight = fraction / max(1.0 - fraction, 0.001);
        vec2 q = vec2(p.x * (1.0 + straight), p.y);
        float d = length(vec2(max(abs(q.x) - straight, 0.0), q.y));
        float angle = atan(q.y, q.x);
        float sector = mod(angle + 3.141593 + 0.392699, 0.785398) - 0.392699;
        float stroke_gate = 1.0 - smoothstep(0.032, 0.070, abs(sector));
        float short_radial = smoothstep(0.53, 0.60, d) * (1.0 - smoothstep(0.82, 0.90, d));
        float corner_gate = 1.0 - smoothstep(0.10, 0.16, abs(sector));
        float corner = (1.0 - smoothstep(0.018, 0.047, abs(d - 0.64))) * corner_gate;
        float rim = max(stroke_gate * short_radial, corner * 0.65);
        float squeeze = exp(-pow((t - 0.13) * 12.0, 2.0));
        alpha = rim * (0.48 + squeeze * 0.25);
        float wave_sector = abs(mod(angle + 0.392699, 0.785398) - 0.392699);
        float wave_gate = 1.0 - smoothstep(0.15, 0.25, wave_sector);
        if (mode == 0.0 || mode == 1.0) {
            float rush = 0.19 + (1.0 - pow(1.0 - min(t * 2.4, 1.0), 2.0)) * 0.73;
            float press_arc = (1.0 - smoothstep(0.025, 0.075, abs(d - rush))) * wave_gate;
            float amber_arc = (1.0 - smoothstep(0.04, 0.10, abs(d - rush + 0.04))) * wave_gate;
            alpha = max(alpha, max(press_arc * 0.91, amber_arc * 0.66));
            color = mix(vec3(0.67,0.35,0.10),vec3(0.98,0.91,0.72),press_arc);
        }
        if (mode == 1.0) {
            // Echo is the same die pressed again: a close second amber registration line.
            float second_press = (1.0 - smoothstep(0.018, 0.042, abs(d - 0.49))) * corner_gate;
            alpha += second_press * 0.32;
        }
        if (mode == 2.0) {
            // Aftershocks press outward as short, broken ink/dust teeth inside real radius.
            float travel = 0.22 + (1.0 - pow(1.0 - min(t * 1.7, 1.0), 2.0)) * 0.68;
            float gate_a = 1.0 - smoothstep(0.12, 0.24, abs(mod(angle + 0.22, 0.785398) - 0.392699));
            float gate_b = 1.0 - smoothstep(0.11, 0.23, abs(mod(angle + 0.42, 0.785398) - 0.392699));
            float gate_c = 1.0 - smoothstep(0.10, 0.22, abs(mod(angle + 0.02, 0.785398) - 0.392699));
            float outer_a = (1.0 - smoothstep(0.034, 0.070, abs(d - travel))) * gate_a;
            float outer_b = (1.0 - smoothstep(0.032, 0.066, abs(d - travel + 0.19))) * gate_b * step(0.30,travel);
            float outer_c = (1.0 - smoothstep(0.030, 0.062, abs(d - travel + 0.38))) * gate_c * step(0.49,travel);
            float white_a = (1.0 - smoothstep(0.012, 0.030, abs(d - travel))) * gate_a;
            float white_b = (1.0 - smoothstep(0.011, 0.028, abs(d - travel + 0.19))) * gate_b * step(0.30,travel);
            float white_c = (1.0 - smoothstep(0.010, 0.026, abs(d - travel + 0.38))) * gate_c * step(0.49,travel);
            float outline = max(outer_a,max(outer_b,outer_c));
            float white_ink = max(white_a,max(white_b,white_c));
            alpha = outline * 0.99;
            color = mix(vec3(.43,.20,.06),vec3(1.0,.99,.90),white_ink);
            tail = (1.0 - smoothstep(0.72,1.0,t)) * reached;
        }
        if (mode == 3.0) {
            float kernel = 1.0 - smoothstep(0.24,0.49,d);
            float dark_lip = 1.0 - smoothstep(0.47,0.69,d);
            alpha = max(kernel*.98,dark_lip*.83);
            color = mix(vec3(.47,.24,.08),vec3(1.0,.94,.76),kernel);
        }
        if (mode == 6.0) {
            // A readable 2–3 pixel little press-crack at each real contact.
            float h = (1.0 - smoothstep(0.13, 0.28, abs(p.y + p.x * 0.22))) * (1.0 - smoothstep(0.65, 0.93, abs(p.x)));
            float v = (1.0 - smoothstep(0.12, 0.26, abs(p.x - p.y * 0.20))) * (1.0 - smoothstep(0.48, 0.75, abs(p.y)));
            alpha = max(h, v) * 0.85;
        }
    }
    ALBEDO = color;
    ALPHA = clamp(alpha * tail * paper_info.b, 0.0, mode == 2.0 ? 0.98 : 0.88);
}
