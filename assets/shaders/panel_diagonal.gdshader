shader_type canvas_item;

uniform vec4  panel_color  : source_color = vec4(0.03, 0.05, 0.09, 0.94);
uniform vec4  edge_color   : source_color = vec4(0.18, 0.72, 0.38, 1.0);
uniform float edge_width   : hint_range(0.001, 0.02) = 0.004;
uniform float diag_slope   : hint_range(0.0, 0.6)    = 0.22;
uniform float panel_width  : hint_range(0.1, 1.0)    = 0.88;
uniform float noise_amount : hint_range(0.0, 0.05)   = 0.008;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Diagonal right edge: x_edge = panel_width - uv.y * diag_slope
	float x_edge = panel_width - uv.y * diag_slope;

	float dist = x_edge - uv.x;

	if (dist < 0.0) {
		// Outside panel
		COLOR = vec4(0.0);
	} else if (dist < edge_width * 2.5) {
		// Edge glow
		float t = dist / (edge_width * 2.5);
		float glow = pow(1.0 - t, 2.2);
		COLOR = vec4(edge_color.rgb, glow * edge_color.a);
	} else {
		// Panel interior — subtle gradient from edge
		float depth = smoothstep(0.0, 0.35, dist - edge_width * 2.5);
		float n = noise(uv * 300.0) * noise_amount;
		vec4 col = panel_color;
		// Slightly lighter near the edge for depth
		col.rgb += vec3(0.01, 0.015, 0.01) * (1.0 - depth) * 0.5;
		col.rgb += n;
		COLOR = col;
	}
}
