shader_type canvas_item;

uniform float grid_alpha  : hint_range(0.0, 0.3)  = 0.055;
uniform float scan_alpha  : hint_range(0.0, 0.3)  = 0.04;
uniform float vig_strength: hint_range(0.0, 3.0)  = 1.4;
uniform float scroll_speed: hint_range(0.0, 2.0)  = 0.18;

void fragment() {
	vec2 uv = UV;

	// Tactical grid — perspective-shifted
	vec2 grid_uv = uv * vec2(52.0, 29.0) + vec2(0.0, TIME * scroll_speed);
	float gx = step(0.94, fract(grid_uv.x));
	float gy = step(0.94, fract(grid_uv.y));
	float grid = clamp(gx + gy, 0.0, 1.0);

	// Brighter grid intersections
	float intersect = gx * gy * 3.0;

	// Horizontal scan pulse
	float scan_pos = fract(TIME * 0.12);
	float scan_beam = smoothstep(0.0, 0.004, abs(uv.y - scan_pos)) ;
	scan_beam = 1.0 - scan_beam;
	scan_beam *= scan_alpha * 6.0;

	// Subtle scanlines
	float scanlines = sin(uv.y * 720.0) * 0.5 + 0.5;
	scanlines = pow(scanlines, 0.8) * scan_alpha;

	// Radial vignette
	vec2 center = (uv - 0.5) * 2.0;
	float vignette = 1.0 - clamp(dot(center * 0.8, center * 0.8) * vig_strength * 0.45, 0.0, 1.0);
	vignette = pow(vignette, 1.4);

	vec4 base = COLOR;
	// Green tint on grid
	base.rgb += vec3(grid * grid_alpha * 0.5, grid * grid_alpha, grid * grid_alpha * 0.6) * vignette;
	base.rgb += vec3(intersect * 0.012, intersect * 0.025, intersect * 0.015) * vignette;
	// Scan beam in green
	base.rgb += vec3(0.0, scan_beam * 0.6, scan_beam * 0.3);
	base.rgb -= scanlines;
	// Vignette darkening
	base.rgb *= (0.55 + vignette * 0.45);

	COLOR = base;
}
