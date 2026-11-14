shader_type canvas_item;
// Same microfacet field and reflection response as the approved 3D preview.
// The host supplies time; reduced effects and pause never depend on shader TIME.
uniform float effect_time = 0.0;
uniform vec2 tilt = vec2(0.0);
uniform float strength = 0.65;
uniform bool reduced = false;
uniform bool compact = false;
uniform bool hidden_pattern = false;
uniform int theme_kind = 0;
// Card-space origin and size of this separately extracted illustration texture.
uniform vec4 source_uv_rect = vec4(0.0,0.0,1.0,1.0);
// An original reference band can be uniformly mounted into the common opening.
// Clip the old illustration window only; preserve its complete source pixels.
uniform vec4 clip_uv_bounds = vec4(0.0,0.0,1.0,1.0);
const float FOIL_TAU = 6.28318530718;
varying vec4 vertex_tint;

void vertex() { vertex_tint=COLOR; }

float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float ellipse(vec2 p,vec2 center,vec2 radius) {
	return 1.0-smoothstep(0.72,1.12,length((p-center)/radius));
}
float subject_depth(vec2 uv) {
	if (theme_kind==1) {
		float body = ellipse(uv,vec2(0.51,0.36),vec2(0.26,0.29));
		float left_arm = ellipse(uv,vec2(0.24,0.35),vec2(0.22,0.20));
		float right_arm = ellipse(uv,vec2(0.79,0.37),vec2(0.19,0.20));
		return mix(-0.35,0.80,max(body,max(left_arm,right_arm)*0.84));
	}
	vec2 center = uv-vec2(0.51,0.368);
	vec2 rotated = vec2(center.x*0.876-center.y*0.482,center.x*0.482+center.y*0.876);
	float ring = exp(-pow((length(rotated/vec2(0.33,0.105))-1.0)*2.9,2.0));
	return mix(-0.42,0.72,ring)-ellipse(uv,vec2(0.51,0.365),vec2(0.20,0.11))*0.22;
}
vec3 spectrum(float phase) {
	vec3 wave = vec3(0.5)+vec3(0.5)*cos(phase+vec3(0.0,2.0943951,4.1887902));
	return mix(vec3(0.065),wave,0.935);
}
float gold_mask(vec3 color) {
	float high=max(color.r,max(color.g,color.b));
	float low=min(color.r,min(color.g,color.b));
	float saturation=(high-low)/max(high,0.001);
	float ratio=color.g/max(color.r,0.001);
	return smoothstep(0.56,0.78,saturation)*smoothstep(0.28,0.60,color.r)
		*smoothstep(0.34,0.52,ratio)*(1.0-smoothstep(0.97,1.12,ratio))
		*smoothstep(0.04,0.17,color.g-color.b);
}
float foil_height(sampler2D tex,vec2 uv) {
	vec3 color=texture(tex,uv).rgb;
	return gold_mask(color)*dot(color,vec3(0.299,0.587,0.114));
}
void fragment() {
	if (UV.x<clip_uv_bounds.x || UV.y<clip_uv_bounds.y || UV.x>clip_uv_bounds.z || UV.y>clip_uv_bounds.w) { discard; }
	vec2 card_uv = source_uv_rect.xy+UV*source_uv_rect.zw;
	vec2 sample_uv = UV;
	vec2 edge_uv = (UV-clip_uv_bounds.xy)/max(clip_uv_bounds.zw-clip_uv_bounds.xy,vec2(0.001));
	// Keep the fitted cape/crest edge stable while the inner surface parallax moves.
	float feather = smoothstep(0.0,0.025,edge_uv.x)*smoothstep(0.0,0.025,edge_uv.y)
		*(1.0-smoothstep(0.975,1.0,edge_uv.x))*(1.0-smoothstep(0.975,1.0,edge_uv.y));
	if (!reduced && !compact) {
		sample_uv += tilt*vec2(-1.0,0.78)*subject_depth(card_uv)*0.0085*strength*feather/source_uv_rect.zw;
	}
	vec4 art = texture(TEXTURE,clamp(sample_uv,max(vec2(0.001),clip_uv_bounds.xy),min(vec2(0.999),clip_uv_bounds.zw)))*vertex_tint;
	vec3 color = art.rgb;
	float luminance = dot(art.rgb,vec3(0.299,0.587,0.114));
	float angle = tilt.x*4.9-tilt.y*3.5;
	float clock = effect_time*0.24;
	vec2 surface = card_uv*vec2(0.75,1.0);
	vec2 facet_grid = surface*vec2(118.0,118.0);
	vec2 tile = floor(facet_grid);
	vec2 local = fract(facet_grid);
	float triangle = step(local.x+local.y,1.0);
	float facet_id = hash21(tile+vec2(triangle*71.0,triangle*13.0));
	float orientation = facet_id*FOIL_TAU;
	float phase = dot(surface,vec2(2.15,-1.65))*FOIL_TAU+angle+clock;
	vec3 rainbow = spectrum(phase+facet_id*0.92);
	float broad = pow(0.5+0.5*sin(dot(surface,vec2(1.02,-0.70))*FOIL_TAU+angle*1.19+clock),5.0);
	float facet = pow(max(0.0,cos(orientation+angle*1.7+clock*1.8)),8.0);
	float spark = pow(max(0.0,cos(orientation*2.1+angle*2.4+clock*2.2)),30.0)*step(0.84,facet_id);
	// Compact cards retain the same broad response, without subpixel glints.
	if (compact) { facet *= 0.20; spark = 0.0; }
	if (reduced) { facet = 0.0; spark = 0.0; }
	vec3 interference = art.rgb*(vec3(0.70)+rainbow*0.62);
	float weight = (0.16+broad*0.24+facet*0.10)*strength;
	color = mix(color,interference,min(weight,0.68));
	float highlight = (broad*0.15+facet*0.070+spark*0.13)*strength*smoothstep(0.018,0.54,luminance);
	color += rainbow*highlight*(0.24+luminance*0.64);
	// The source contains gold stars, rings and armor as well as frame metal.
	// Match the old threshold/gradient relief response without moving that ink.
	vec3 original=texture(TEXTURE,UV).rgb;
	float gold=gold_mask(original);
	if (!compact) {
		vec2 texel=TEXTURE_PIXEL_SIZE*1.4;
		float left_height=foil_height(TEXTURE,UV-vec2(texel.x,0.0));
		float right_height=foil_height(TEXTURE,UV+vec2(texel.x,0.0));
		float up_height=foil_height(TEXTURE,UV-vec2(0.0,texel.y));
		float down_height=foil_height(TEXTURE,UV+vec2(0.0,texel.y));
		vec3 normal=normalize(vec3((left_height-right_height)*1.6,(down_height-up_height)*1.6,0.75));
		vec3 light=normalize(vec3(-0.45+tilt.x*0.9,0.65-tilt.y*0.8,0.72));
		color*=1.0+gold*strength*(dot(normal,light)-0.60)*0.17;
	}
	float gold_sweep=pow(0.5+0.5*cos(dot(surface,vec2(0.82,-0.59))*FOIL_TAU+angle*1.05+clock*0.8),15.0);
	color+=vec3(0.46,0.265,0.055)*gold*gold_sweep*strength*(compact ? 0.38 : 0.58);
	if (hidden_pattern) {
		float pattern;
		if (theme_kind==1) { pattern = step(0.90,fract(card_uv.x*24.0))*step(0.3,fract(card_uv.y*30.0)); }
		else { pattern = pow(max(0.0,cos(length((card_uv-0.5)*vec2(1.0,0.75))*100.0-angle-clock)),20.0); }
		color += vec3(0.9,0.66,0.28)*pattern*(compact ? 0.035 : 0.08);
	}
	COLOR = vec4(clamp(color,vec3(0.0),vec3(1.0)),art.a);
}

