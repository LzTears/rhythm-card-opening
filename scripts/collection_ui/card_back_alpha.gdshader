shader_type canvas_item;
// Remove only near-zero generation residue; preserve the supplied back art.
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE,UV)*vertex_tint;
	if (source.a<0.02) { discard; }
	COLOR = source;
}
