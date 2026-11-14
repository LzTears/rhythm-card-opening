shader_type canvas_item;
// Separate frame pass: metal reacts to angle/time; paper and runtime text stay still.
uniform float effect_time = 0.0;
uniform vec2 tilt = vec2(0.0);
uniform bool reduced = false;
uniform bool compact = false;
uniform float strength = 0.65;
uniform float ruby_strength = 0.65;
uniform bool show_separator = true;
const float FOIL_TAU = 6.28318530718;
varying vec4 vertex_tint;

void vertex() { vertex_tint=COLOR; }

float gold_mask(vec3 color) {
	float high = max(color.r,max(color.g,color.b));
	float low = min(color.r,min(color.g,color.b));
	float saturation = (high-low)/max(high,0.001);
	float ratio = color.g/max(color.r,0.001);
	return smoothstep(0.56,0.78,saturation)*smoothstep(0.28,0.60,color.r)
		*smoothstep(0.34,0.52,ratio)*(1.0-smoothstep(0.97,1.12,ratio))
		*smoothstep(0.04,0.17,color.g-color.b);
}
float band(float value,float low,float high,float feather) {
	return smoothstep(low-feather,low,value)*(1.0-smoothstep(high,high+feather,value));
}
float separator_mask(vec2 px) {
	float line=band(px.x,158.0,612.0,2.0)*band(px.y,888.5,895.5,2.0);
	float diamond=1.0-smoothstep(0.94,1.12,abs(px.x-384.0)/29.0+abs(px.y-892.0)/29.0);
	return max(line,diamond);
}
vec4 frame_sample(sampler2D tex,vec2 uv,bool image_draw) {
	vec4 source=texture(tex,uv);
	if (!image_draw) { return source; }
	vec2 px=uv*vec2(768.0,1024.0);
	// One common paper layout leaves room for Latin descenders at 84px.
	// Erase only the old thin line/star with neighboring real paper texture.
	float old_mask=separator_mask(px);
	if (old_mask>0.0) {
		vec3 paper=texture(tex,uv-vec2(0.0,68.0/1024.0)).rgb;
		source.rgb=mix(source.rgb,paper,old_mask);
	}
	// Keep the horizontal line's full width and copy the same ornament pixels.
	// Its vertical span is fitted between title end 886 and description start 930.
	float source_y=892.0+(px.y-906.0)/0.68;
	float new_mask=separator_mask(vec2(px.x,source_y))*band(px.y,890.0,924.0,2.0);
	if (show_separator && new_mask>0.0) {
		vec3 moved=texture(tex,vec2(uv.x,source_y/1024.0)).rgb;
		source.rgb=mix(source.rgb,moved,new_mask);
	}
	return source;
}
float foil_height(sampler2D tex,vec2 uv,bool image_draw) {
	vec3 color = frame_sample(tex,uv,image_draw).rgb;
	return gold_mask(color)*dot(color,vec3(0.299,0.587,0.114));
}
void fragment() {
	// Generated frames can retain isolated opaque specks deep in the opening.
	// This safe inner rectangle contains no frame line, corner or paper plaque;
	// the complete illustration is rendered independently beneath this pass.
	vec2 frame_px=UV*vec2(768.0,1024.0);
	bool image_draw=TEXTURE_PIXEL_SIZE.x<0.01 && TEXTURE_PIXEL_SIZE.y<0.01;
	if (image_draw && frame_px.x>=64.0 && frame_px.x<=704.0 && frame_px.y>=130.0 && frame_px.y<=680.0) { discard; }
	vec4 original = frame_sample(TEXTURE,UV,image_draw)*vertex_tint;
	// Generated RGBA windows retain at most 2/255 residual alpha. Discard that
	// residue; cream paper near 251..254 alpha is physically opaque mounting paper.
	if (original.a<=0.0098) { discard; }
	if (original.a>0.97) { original.a=1.0; }

	vec3 color = original.rgb;
	float gold = gold_mask(original.rgb);
	float angle = tilt.x*4.9-tilt.y*3.5;
	float clock = effect_time*0.24;
	vec2 surface = UV*vec2(0.75,1.0);
	if (!compact && strength>0.0) {
		vec2 texel = TEXTURE_PIXEL_SIZE*1.4;
		float left_height = foil_height(TEXTURE,UV-vec2(texel.x,0.0),image_draw);
		float right_height = foil_height(TEXTURE,UV+vec2(texel.x,0.0),image_draw);
		float up_height = foil_height(TEXTURE,UV-vec2(0.0,texel.y),image_draw);
		float down_height = foil_height(TEXTURE,UV+vec2(0.0,texel.y),image_draw);
		vec3 normal = normalize(vec3((left_height-right_height)*1.6,(down_height-up_height)*1.6,0.75));
		vec3 light = normalize(vec3(-0.45+tilt.x*0.9,0.65-tilt.y*0.8,0.72));
		color *= 1.0+gold*strength*(dot(normal,light)-0.60)*0.17;
	}
	float sweep = pow(0.5+0.5*cos(dot(surface,vec2(0.82,-0.59))*FOIL_TAU+angle*1.05+clock*0.8),15.0);
	color += vec3(0.46,0.265,0.055)*gold*sweep*strength*(compact ? 0.38 : 0.58);
	float ruby = smoothstep(0.12,0.32,original.r-max(original.g,original.b))*smoothstep(0.15,0.46,original.r);
	color += vec3(0.11,0.002,0.009)*ruby*sweep*ruby_strength;
	COLOR = vec4(clamp(color,vec3(0.0),vec3(1.0)),original.a);
}

