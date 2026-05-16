shader_type canvas_item;

uniform float strength : hint_range(0.0, 2.0) = 0.85;
uniform float radius   : hint_range(0.0, 2.0) = 0.75;
uniform vec4  tint     : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv * vec2(1.0, 1.1));
	float vignette = smoothstep(radius, radius - 0.45, dist * strength);
	vignette = 1.0 - vignette;
	COLOR = vec4(tint.rgb, vignette * tint.a);
}
