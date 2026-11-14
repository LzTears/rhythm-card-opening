shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
// Heavy is a tabletop paper press, with the same exact playable radius as every guide.
uniform float progress : hint_range(0.0,1.0)=0.0;
uniform float phase=0.0;
uniform bool reduced=false;
uniform bool guide_only=false;
uniform int aim_style=0;
uniform vec3 guide_tone : source_color=vec3(.84,.57,.24);
uniform vec3 charge_tone : source_color=vec3(.84,.57,.24);
uniform vec3 ready_tone : source_color=vec3(.96,.78,.43);
float band(float radius,float center,float width) { return 1.0-step(width+.005,abs(radius-center)); }
void fragment() {
	vec2 p=(floor(UV*64.0)+vec2(.5))/64.0-vec2(.5);
	float radius=length(p);
	float angle=mod(atan(p.y,p.x)+1.5707963+6.2831853,6.2831853);
	float turn=angle/6.2831853;
	float guide=band(radius,.433,.0025);
	float ink=band(radius,.433,.013);
	float ticks=step(.87,fract(turn*4.0))*band(radius,.449,.008);
	float cross=(1.0-step(.008,min(abs(p.x),abs(p.y))))*(1.0-step(.027,radius));
	float q=clamp(progress,0.0,1.0);
	float press_size=mix(.16,.065,floor(q*12.0)/12.0);
	float box_distance=max(abs(p.x),abs(p.y));
	float corner=step(press_size-.030,min(abs(p.x),abs(p.y)));
	float bracket=band(box_distance,press_size,.003)*corner;
	float bracket_ink=band(box_distance,press_size,.013)*corner;
	float arc=band(radius,.405,.005)*step(floor(turn*16.0)/16.0,floor(q*16.0)/16.0);
	// Four crease marks converge towards the contact. No filled targeting disc or hammer.
	float axis=min(abs(p.x),abs(p.y));
	float press_marks=(1.0-step(.009,axis))*band(box_distance,mix(.27,.15,q),.020);
	vec3 paper=vec3(.96,.87,.66);
	vec3 warm_ink=vec3(.29,.20,.13);
	vec3 rim=mix(warm_ink,paper,max(guide,max(ticks,cross)));
	float guide_alpha=max(ink*.92,max(guide,max(ticks,cross)));
	float charge_alpha=max(arc*.94,max(bracket_ink*(.35+q*.50),press_marks*.52*q));
	vec3 load_color=mix(warm_ink,mix(charge_tone,paper,.35),max(bracket,max(arc,press_marks)));
	ALBEDO=guide_only?rim:load_color;
	ALPHA=guide_only?guide_alpha:charge_alpha*(reduced?.70:1.0);
}
