shader_type spatial;
// A wooden crate: framed faces with a diagonal brace and planks.
// BoxMesh lays its six faces out in a 3 x 2 grid of UV space.

uniform vec4 wood : source_color = vec4(0.8, 0.55, 0.3, 1.0);
uniform vec4 frame : source_color = vec4(0.46, 0.28, 0.14, 1.0);

void fragment() {
	vec2 face = fract(UV * vec2(3.0, 2.0));
	float edge = min(min(face.x, 1.0 - face.x), min(face.y, 1.0 - face.y));
	float border = 1.0 - smoothstep(0.09, 0.12, edge);
	float brace = 1.0 - smoothstep(0.04, 0.07, abs(face.x - face.y));
	float plank = step(0.5, fract(face.y * 4.0)) * 0.07;
	vec3 color = mix(wood.rgb * (1.0 - plank), frame.rgb, max(border, brace));
	ALBEDO = color;
	ROUGHNESS = 0.8;
}
