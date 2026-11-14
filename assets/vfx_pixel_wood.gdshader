shader_type spatial;
render_mode specular_disabled;

uniform sampler2D wood_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 dark_brown : source_color = vec4(0.408,0.329,0.263,1.0);
uniform vec4 light_brown : source_color = vec4(0.565,0.467,0.365,1.0);

void fragment() {
	vec3 source = texture(wood_texture,UV).rgb;
	float luminance = dot(source,vec3(0.2126,0.7152,0.0722));
	// Compatibility samples this PNG in sRGB; other renderers decode source_color to linear.
	// Measured source clusters: seams .19-.25, grain .29-.31, body .39-.41, highlights .48-.50 sRGB.
	float seam = OUTPUT_IS_SRGB ? 0.25 : 0.067;
	float grain = OUTPUT_IS_SRGB ? 0.345 : 0.12;
	float highlight = OUTPUT_IS_SRGB ? 0.45 : 0.21;
	float level = luminance<seam ? 0.0 : (luminance<grain ? 0.333333 : (luminance<highlight ? 0.666667 : 1.0));
	ALBEDO = mix(dark_brown.rgb,light_brown.rgb,level);
	ROUGHNESS = 1.0;
}
