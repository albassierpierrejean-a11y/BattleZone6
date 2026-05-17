shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, ambient_light_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity   : hint_range(0.0, 0.04) = 0.012;
uniform float speed       : hint_range(0.0, 4.0)  = 1.2;
uniform float noise_scale : hint_range(1.0, 20.0) = 6.0;
uniform float vertical_fade : hint_range(0.0, 1.0) = 0.6;

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 17.5);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i),               hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

void fragment() {
	float t   = TIME * speed;
	vec2  uv  = SCREEN_UV;

	// Deux couches de bruit décalées dans le temps
	float n1  = noise(vec2(UV.x * noise_scale,       UV.y * noise_scale * 0.5 + t * 0.7));
	float n2  = noise(vec2(UV.x * noise_scale * 1.4 + 3.7, UV.y * noise_scale * 0.4 - t * 0.5));
	float n   = (n1 + n2) * 0.5;

	// Fondu vertical : plus intense en bas (air chaud au sol)
	float fade = pow(clamp(1.0 - UV.y * (1.0 / max(vertical_fade, 0.01)), 0.0, 1.0), 1.6);

	vec2 offset = vec2((n - 0.5) * 2.0, (n1 - 0.5)) * intensity * fade;
	vec3 col    = texture(screen_texture, uv + offset).rgb;

	ALBEDO  = col;
	ALPHA   = fade * 0.92;
}