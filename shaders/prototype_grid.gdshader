shader_type spatial;

// Placeholder "developer texture" for blockout geometry, like the orange and
// grey grid textures on CS developer maps. It draws a grid in world space, so
// every surface shows 1 m squares no matter how big the box is. That makes
// speed and distances easy to judge while testing movement.
// Replaced by retro textures in M3.

uniform vec3 base_color : source_color = vec3(0.5);
uniform vec3 line_color : source_color = vec3(0.3);
// Size of one grid square in metres.
uniform float cell_size = 1.0;
// Line thickness in metres.
uniform float line_width = 0.03;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Returns 1.0 on a grid line and 0.0 elsewhere, with soft (anti-aliased) edges.
float grid_lines(vec2 position, float size, float width) {
	vec2 distance_to_line = abs(fract(position / size - 0.5) - 0.5) * size;
	vec2 blur = fwidth(position);
	vec2 lines = 1.0 - smoothstep(vec2(width * 0.5) - blur, vec2(width * 0.5) + blur, distance_to_line);
	return max(lines.x, lines.y);
}

void fragment() {
	// Use the two world axes that lie along this surface (triplanar mapping).
	vec3 n = abs(world_normal);
	vec2 surface_position;
	if (n.y >= n.x && n.y >= n.z) {
		surface_position = world_position.xz;
	} else if (n.x >= n.z) {
		surface_position = world_position.zy;
	} else {
		surface_position = world_position.xy;
	}
	float major = grid_lines(surface_position, cell_size, line_width);
	float minor = grid_lines(surface_position, cell_size * 0.25, line_width * 0.5) * 0.35;
	ALBEDO = mix(base_color, line_color, max(major, minor));
	ROUGHNESS = 0.9;
}
