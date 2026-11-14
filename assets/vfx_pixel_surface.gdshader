shader_type spatial;
render_mode unshaded, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.39,0.45,0.54,1.0);
uniform vec4 shadow_color : source_color = vec4(0.15,0.16,0.27,1.0);
uniform vec4 light_color : source_color = vec4(0.60,0.70,0.69,1.0);

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL,0.0)).xyz);
	float face = dot(world_normal, normalize(vec3(-0.35,0.85,0.45)));
	ALBEDO = face > 0.65 ? light_color.rgb : (face > 0.05 ? base_color.rgb : shadow_color.rgb);
	ROUGHNESS = 1.0;
}
