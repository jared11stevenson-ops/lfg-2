shader_type canvas_item;
// Fake tilt-shift for the Compatibility renderer (no DOF there): blur grows away from a focus band,
// plus a mild vignette and saturation/contrast lift. 9 taps. Toggle off on weak GPUs.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float focus_y : hint_range(0.0, 1.0) = 0.55;
uniform float focus_width : hint_range(0.0, 0.5) = 0.18;
uniform float blur_amount : hint_range(0.0, 8.0) = 4.5;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float saturation : hint_range(0.5, 2.0) = 1.06;
uniform vec3 tint : source_color = vec3(1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	float d = max(0.0, abs(uv.y - focus_y) - focus_width);
	float k = clamp(d * 3.2, 0.0, 1.0) * blur_amount;
	vec2 px = SCREEN_PIXEL_SIZE * k;
	vec3 c = texture(screen_tex, uv).rgb * 0.2;
	c += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(0.0, px.y)).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(0.0, px.y)).rgb * 0.1;
	c += texture(screen_tex, uv + px).rgb * 0.1;
	c += texture(screen_tex, uv - px).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(px.x, -px.y)).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(-px.x, px.y)).rgb * 0.1;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * tint;
	vec2 q = uv - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.85, dot(q, q) * 2.0);
	COLOR = vec4(c, 1.0);
}
