shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float sharpness    : hint_range(0.0, 2.0)  = 0.65;
uniform float saturation   : hint_range(0.0, 2.0)  = 1.12;
uniform float contrast     : hint_range(0.5, 1.5)  = 1.06;
uniform float brightness   : hint_range(0.5, 1.5)  = 0.98;
uniform float vignette_str : hint_range(0.0, 2.0)  = 0.42;
uniform float grain_str    : hint_range(0.0, 0.05) = 0.018;
uniform float chrom_aber   : hint_range(0.0, 0.01) = 0.0015;
uniform float suppress_str : hint_range(0.0, 1.0)  = 0.0;

uniform vec3 lift  = vec3(0.96, 0.98, 1.02);
uniform vec3 gamma_val = vec3(1.0,  1.0,  1.0);
uniform vec3 gain  = vec3(1.02, 1.0,  0.96);

float rand(vec2 uv, float t) {
	return fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 apply_lgg(vec3 col) {
	col = col * gain * lift;
	col = pow(max(col, vec3(0.0)), 1.0 / max(gamma_val, vec3(0.001)));
	return col;
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Chromatic aberration
	float ca = chrom_aber * (1.0 + suppress_str * 3.0);
	vec2 off = (uv - 0.5) * ca;
	float r = texture(screen_texture, uv + off).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - off).b;
	vec3 col = vec3(r, g, b);

	// Adaptive sharpening (CAS-lite)
	if (sharpness > 0.01) {
		vec2 px = 1.0 / vec2(textureSize(screen_texture, 0));
		vec3 n  = texture(screen_texture, uv + vec2(0.0,  -px.y)).rgb;
		vec3 s  = texture(screen_texture, uv + vec2(0.0,   px.y)).rgb;
		vec3 e  = texture(screen_texture, uv + vec2( px.x, 0.0)).rgb;
		vec3 w  = texture(screen_texture, uv + vec2(-px.x, 0.0)).rgb;
		vec3 blur = (n + s + e + w) * 0.25;
		col = col + (col - blur) * sharpness * 0.8;
	}

	// Contrast & brightness
	col = (col - 0.5) * contrast + 0.5;
	col *= brightness;

	// Saturation
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(luma), col, saturation);

	// Lift / Gamma / Gain
	col = apply_lgg(col);

	// Film grain
	float g_val = rand(uv, TIME * 0.07) * 2.0 - 1.0;
	col += g_val * grain_str;

	// Vignette
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vig   = pow(vig_uv.x * vig_uv.y * 15.0, vignette_str);
	col *= vig;

	// Suppression IS-style — désaturation + bords bruités
	if (suppress_str > 0.01) {
		float edge      = length(uv - 0.5) * 2.0;
		float blur_mask = smoothstep(0.3, 1.0, edge) * suppress_str;
		float luma2     = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(luma2 * 0.7), blur_mask * 0.8);
		col = mix(col, vec3(luma2), suppress_str * 0.4);
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
