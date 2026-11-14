shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.11,0.075,0.045,0.18);
uniform float ring : hint_range(0.0,1.0) = 0.0;
uniform float opacity : hint_range(0.0,1.0) = 1.0;
uniform bool cross_glint = false;

void fragment() {
	vec2 p = ((floor(UV*32.0)+vec2(0.5))/32.0-vec2(0.5))*2.0;
	float r = length(p);
	float disk = 1.0-step(0.76,r);
	float rim = (1.0-step(0.085,abs(r-0.69)));
	float cross = (1.0-step(0.10,min(abs(p.x),abs(p.y))))*(1.0-step(0.72,max(abs(p.x),abs(p.y))));
	ALBEDO = tint.rgb;
	ALPHA = tint.a * floor(opacity*4.0)/4.0 * (cross_glint ? cross : mix(disk,rim,ring));
}
