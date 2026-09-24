shader_type spatial;
// Inverted-hull outline: draws the back faces of a slightly inflated copy of
// the mesh in a flat color. Used as a material's next_pass.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.1, 0.07, 0.15, 1.0);
uniform float outline_width = 0.018;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
