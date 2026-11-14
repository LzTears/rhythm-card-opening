shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

uniform sampler2D print_texture : source_color, filter_nearest, repeat_disable;
uniform int foil_grade : hint_range(3,4) = 3;
uniform float phase = 0.0;
uniform bool reduced = false;
uniform float gold_gain : hint_range(0.0,0.20) = 0.20;
uniform float rainbow_gain : hint_range(0.0,0.22) = 0.22;
uniform float reduced_gain : hint_range(0.0,1.0) = 0.40;
uniform float alpha_cutoff : hint_range(0.0,1.0) = 0.22;

float hash_pixel(vec2 cell) {
	return fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
}

vec3 rainbow_step(float hue) {
	float segment = floor(fract(hue)*6.0);
	if (segment<1.0) return vec3(1.0,0.28,0.36);
	if (segment<2.0) return vec3(1.0,0.77,0.31);
	if (segment<3.0) return vec3(0.27,0.88,0.65);
	if (segment<4.0) return vec3(0.24,0.67,1.0);
	if (segment<5.0) return vec3(0.65,0.39,1.0);
	return vec3(1.0,0.38,0.76);
}

void fragment() {
	vec4 source = texture(print_texture,UV);
	if (source.a<alpha_cutoff) discard;
	vec2 grid = (floor(UV*32.0)+vec2(0.5))/32.0;
	float radius = length(UV-vec2(0.5));
	float tick = reduced ? 0.0 : floor(phase*12.0)/12.0;
	float value = max(source.r,max(source.g,source.b));
	// The workshop's enamel portrait stays untouched. Moving foil belongs only
	// to the narrow embossed metal ring and never washes across the animal.
	float frame_mask = step(0.355,radius)*(1.0-step(0.46875,radius));
	float foil_mask = frame_mask*mix(0.20,1.0,step(0.38,value));
	float diagonal = grid.x*0.75+grid.y*0.45;
	float travel = fract(tick*0.18);
	float sweep = 1.0-step(0.08,abs(fract(diagonal-travel+1.0)-0.5));
	float facet = step(0.5,fract(grid.x*6.0+grid.y*4.0));
	vec3 gold = mix(vec3(0.89,0.68,0.40),vec3(1.0,0.86,0.60),facet);
	vec3 film = foil_grade==4 ? mix(gold,rainbow_step(grid.x*0.55+grid.y*0.30+tick*0.08),0.24) : gold;
	float glitter = reduced ? 0.0 : step(0.985,hash_pixel(floor(UV*16.0)+vec2(floor(tick*4.0),0.0)));
	float gain = foil_grade==4 ? min(rainbow_gain,0.22) : min(gold_gain,0.20);
	gain *= reduced ? reduced_gain : 1.0;
	float amount = gain*foil_mask*clamp(0.45+0.55*sweep+0.45*glitter,0.0,1.0);
	ALBEDO = mix(source.rgb,film,amount);
	METALLIC = (foil_grade==4 ? 0.14 : 0.20)*foil_mask;
	SPECULAR = 0.17;
	ROUGHNESS = mix(0.82,0.55,foil_mask*(0.45+0.55*sweep));
	ALPHA = source.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
}
