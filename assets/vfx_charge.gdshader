shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
uniform float progress : hint_range(0.0,1.0)=0.0;
uniform float phase=0.0;
uniform bool reduced=false;
uniform bool guide_only=false;
uniform int aim_style=0;
uniform vec3 guide_tone : source_color=vec3(.1843137,.545098,.4745098);
uniform vec3 charge_tone : source_color=vec3(.7843137,.509804,.152941);
uniform vec3 ready_tone : source_color=vec3(.882353,.666667,.294118);
uniform sampler2D spark_atlas : source_color, filter_linear, repeat_disable;
uniform bool use_spark_atlas=false;
uniform vec2 spark_grid=vec2(4.0,4.0);
uniform float spark_frames=16.0;
uniform float spark_fps=30.0;
uniform float spark_cell_px=48.0;
const float TAU_VALUE=6.28318530718;
const float GUIDE_RADIUS=0.433;
const float LOAD_RADIUS=0.405;
float stroke(float d,float width,float aa) {
 return 1.0-smoothstep(width-aa,width+aa,abs(d));
}
float disc(vec2 p,float radius,float aa) {
 return 1.0-smoothstep(radius-aa,radius+aa,length(p));
}
float spark_stamp(vec2 p,vec2 center,float tangent,float age,float size_value,float aa) {
 vec2 delta=p-center;
 float c=cos(tangent);
 float s=sin(tangent);
 vec2 local=vec2(c*delta.x+s*delta.y,-s*delta.x+c*delta.y);
 if (use_spark_atlas) {
  vec2 cell_uv=local/size_value+vec2(.5);
  if (cell_uv.x<0.0 || cell_uv.x>1.0 || cell_uv.y<0.0 || cell_uv.y>1.0) return 0.0;
  float frame=floor(mod(age*max(1.0,spark_fps),max(1.0,spark_frames)));
  vec2 cell=vec2(mod(frame,spark_grid.x),floor(frame/spark_grid.x));
  float inset=.5/max(1.0,spark_cell_px);
  vec4 stamp=texture(spark_atlas,(cell+clamp(cell_uv,vec2(inset),vec2(1.0-inset)))/spark_grid);
  return clamp(stamp.a*max(stamp.r,max(stamp.g,stamp.b))*1.5,0.0,1.0);
 }
 // Finite fallback only while a fresh authoring PNG is unavailable.
 float core=disc(local,.0035,aa);
 float tail=stroke(local.y,.0017,aa)*(1.0-smoothstep(.0,.018,abs(local.x+.008)));
 return max(core,tail*.55);
}
void fragment() {
 // Continuous UV/SDF edges: keep the exact .433 registered playable contour.
 vec2 p=UV-vec2(.5);
 float radius=length(p);
 float aa=max(max(fwidth(p.x),fwidth(p.y))*.7,.00025);
 float turn=mod(atan(p.y,p.x)+1.57079632679+TAU_VALUE,TAU_VALUE)/TAU_VALUE;
 float q=clamp(progress,0.0,1.0);
 if (guide_only) {
  float ink=stroke(radius-GUIDE_RADIUS,.009,aa);
  float rim=stroke(radius-GUIDE_RADIUS,.0031,aa);
  float tick_count=aim_style==0 ? 4.0 : (aim_style==4 ? 6.0 : 8.0);
  float ticks=0.0;
  for (int i=0;i<8;i++) {
   if (float(i)<tick_count) {
    float a=float(i)*TAU_VALUE/tick_count-1.57079632679;
    vec2 d=p-vec2(cos(a),sin(a))*.449;
    float shape=aim_style==1 ? (abs(d.x)+abs(d.y))*.75 : length(d);
    ticks=max(ticks,1.0-smoothstep(.0034-aa,.0034+aa,shape));
   }
  }
  float cross=stroke(min(abs(p.x),abs(p.y)),.0015,aa)*(1.0-smoothstep(.018,.023,radius));
  float detail=max(rim,max(ticks,cross));
  ALBEDO=mix(vec3(.16,.23,.19),mix(guide_tone,vec3(1.0,.97,.86),.34),detail);
  ALPHA=max(ink*.57,detail*.96);
 } else {
  float active=step(.000001,q);
  float angle_aa=max(aa/(LOAD_RADIUS*TAU_VALUE),.0003);
  float filled=q>=.999999 ? 1.0 : 1.0-smoothstep(q-angle_aa,q+angle_aa,turn);
  float arc_ink=stroke(radius-LOAD_RADIUS,.015,aa)*filled*active;
  float arc=stroke(radius-LOAD_RADIUS,.0085,aa)*filled*active;
  float head_angle=q*TAU_VALUE-1.57079632679;
  vec2 head=vec2(cos(head_angle),sin(head_angle))*LOAD_RADIUS;
  float head_core=disc(p-head,.012,aa)*active;
  float head_ink=disc(p-head,.017,aa)*active;
  float behind=mod(q-turn+1.0,1.0);
  float tail=stroke(radius-LOAD_RADIUS,.0065,aa)*(1.0-smoothstep(.0,.11,behind))*filled*active;
  float sparks=0.0;
  float spark_ink=0.0;
  if (!reduced) {
   for (int i=0;i<3;i++) {
    float age=phase+float(i)*.177;
    float life=mod(age*max(1.0,spark_fps),max(1.0,spark_frames))/max(1.0,spark_frames);
    float lag=.008+float(i)*.015+life*.026;
    float t=max(0.0,q-lag);
    float a=t*TAU_VALUE-1.57079632679;
    vec2 center=vec2(cos(a),sin(a))*(LOAD_RADIUS+.035+life*.020);
    float gate=step(lag,q)*active;
    sparks=max(sparks,spark_stamp(p,center,a+1.57079632679,age,.14,aa)*gate*.96);
    spark_ink=max(spark_ink,spark_stamp(p-vec2(.0022,.0028),center,a+1.57079632679,age,.14,aa)*gate*.75);
   }
  }
  vec3 tone=mix(charge_tone,ready_tone,smoothstep(.55,1.0,q));
  vec3 bright_tone=mix(tone,vec3(1.0,.995,.97),.85);
  float trail_alpha=reduced ? .12 : .38;
  float base_alpha=max(spark_ink,max(arc_ink*.85,head_ink*.85));
  float light_alpha=max(arc*.99,max(head_core*.99,max(sparks,tail*trail_alpha)));
  float out_alpha=light_alpha+base_alpha*(1.0-light_alpha);
  // Composite the bright source over its ink, then return straight alpha.
  // Coverage controls alpha once, rather than also darkening the source RGB.
  ALBEDO=(bright_tone*light_alpha+vec3(.10,.14,.14)*base_alpha*(1.0-light_alpha))/max(out_alpha,.00001);
  ALPHA=out_alpha*active;
 }
}
