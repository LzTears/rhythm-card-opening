shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform bool skin_wrapper = false;
uniform sampler2D print_texture : source_color, filter_nearest, repeat_disable;
uniform int pack_grade = 0;
uniform float phase = 0.0;
uniform bool reduced = false;
uniform float hit_flash = 0.0;
uniform int damage_level = 0;
uniform vec4 crop_rect = vec4(.136,.0417,.727,.9167);
uniform vec4 damage_uv_rect = vec4(.136,.0417,.727,.9167);
uniform vec4 damage_target_rect = vec4(.136,.0417,.727,.9167);
uniform vec2 art_texel_size = vec2(.00390625,.0026041667);
uniform bool clip_to_table = false;
// World metres: (min X, max X, min Z, max Z). Only normal pack materials opt in.
uniform vec4 table_bounds_xz = vec4(-1.0,1.0,-1.0,1.0);
varying vec2 table_position_xz;
uniform sampler2D damage_texture_1 : source_color, filter_nearest, repeat_disable;
uniform sampler2D damage_texture_2 : source_color, filter_nearest, repeat_disable;
uniform sampler2D damage_texture_3 : source_color, filter_nearest, repeat_disable;
vec4 wear_sample(vec2 at) {
	// The common wear stays registered when the new wrapper has another canvas/crop.
	at=damage_uv_rect.xy+(at-damage_target_rect.xy)/max(damage_target_rect.zw,vec2(.0001))*damage_uv_rect.zw;
	if (damage_level==1) return texture(damage_texture_1,at);
	if (damage_level==2) return texture(damage_texture_2,at);
	if (damage_level>=3) return texture(damage_texture_3,at);
	return vec4(0.0);
}
void vertex() {
	table_position_xz = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
}
void fragment() {
	if (clip_to_table && (table_position_xz.x<table_bounds_xz.x || table_position_xz.x>table_bounds_xz.y || table_position_xz.y<table_bounds_xz.z || table_position_xz.y>table_bounds_xz.w)) discard;
	vec4 source = texture(print_texture,UV);
	if (source.a<0.22) discard;
	vec3 color = source.rgb;
	if (pack_grade>=3) {
		vec2 wrapper_uv = (UV-damage_target_rect.xy)/max(damage_target_rect.zw,vec2(.0001));
		vec2 pixel = floor(wrapper_uv*32.0)/32.0;
		float tick = reduced ? 0.0 : floor(phase*10.0)/10.0;
		float sweep = 1.0-step(0.055,abs(fract(pixel.x*.8+pixel.y*.6-tick*.14)-.5));
		// Only the narrow crimped metal seams catch light. The coloured wrapper and
		// central swirl retain their authored pixels, including the ancient red pack.
		float seams = max(1.0-step(.11,wrapper_uv.y),step(.89,wrapper_uv.y));
		float value = max(source.r,max(source.g,source.b));
		float metal = seams*step(.38,value);
		vec3 film = pack_grade==4 ? vec3(1.0,.81,.52) : vec3(1.0,.92,.68);
		color = mix(color,film,sweep*metal*(reduced ? .025 : .08));
	}
	// Three existing wear overlays stay registered to the measured new wrapper body.
	vec4 damage_art=wear_sample(UV);
	if (damage_level>0) {
		vec2 texel=art_texel_size*1.5;
		vec4 neighbor=wear_sample(UV+vec2(texel.x,0.0));
		if (neighbor.a>damage_art.a) damage_art=neighbor;
		neighbor=wear_sample(UV-vec2(texel.x,0.0));
		if (neighbor.a>damage_art.a) damage_art=neighbor;
		neighbor=wear_sample(UV+vec2(0.0,texel.y));
		if (neighbor.a>damage_art.a) damage_art=neighbor;
		neighbor=wear_sample(UV-vec2(0.0,texel.y));
		if (neighbor.a>damage_art.a) damage_art=neighbor;
		damage_art.a=pow(damage_art.a,.85);
	}
	// Full-canvas registered artwork is clipped by the original wrapper silhouette.
	if (skin_wrapper) {
		float fold = abs(fract(UV.x*7.0+sin(UV.y*18.0)*.13)-.5);
		float crack = (1.0-step(.018,fold))*float(damage_level)/3.0;
		color=mix(color,vec3(.13,.09,.15),crack*.65);
	} else {
		color=mix(color,damage_art.rgb,damage_art.a*source.a);
	}
	ALBEDO = mix(color,vec3(1.0,.98,.86),hit_flash*.90);
	ALPHA = source.a;
	ALPHA_SCISSOR_THRESHOLD = .22;
}
