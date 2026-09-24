shader_type spatial;
// World-space prototype grid for grey-boxing. Thin lines every meter and bold
// lines every 5 meters, so heights and distances can be read at a glance
// while tuning movement. Projected along the dominant axis of each face.

uniform vec4 color : source_color = vec4(0.72, 0.74, 0.8, 1.0);
uniform float line_width = 0.025;
uniform float minor_strength = 0.22;
uniform float major_strength = 0.4;
uniform float checker_strength = 0.035;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1.0 on grid lines, 0.0 elsewhere, anti-aliased and faded out where the lines get too dense.
float grid(vec2 coords, float spacing, float width) {
	vec2 cells = coords / spacing;
	vec2 pixel = fwidth(cells);
	vec2 from_line = abs(fract(cells - 0.5) - 0.5);
	vec2 half_width = vec2(0.5 * width / spacing);
	vec2 lines = 1.0 - smoothstep(half_width - pixel, half_width + pixel, from_line);
	float density_fade = 1.0 - clamp(max(pixel.x, pixel.y) * 3.0 - 0.5, 0.0, 1.0);
	return max(lines.x, lines.y) * density_fade;
}

void fragment() {
	vec3 axis = abs(world_normal);
	vec2 coords;
	if (axis.y >= axis.x && axis.y >= axis.z) {
		coords = world_position.xz;
	} else if (axis.x >= axis.z) {
		coords = world_position.zy;
	} else {
		coords = world_position.xy;
	}
	vec2 cell = floor(coords);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 albedo = color.rgb * (1.0 - checker * checker_strength);
	albedo *= 1.0 - grid(coords, 1.0, line_width) * minor_strength;
	albedo *= 1.0 - grid(coords, 5.0, line_width * 2.0) * major_strength;
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
}
