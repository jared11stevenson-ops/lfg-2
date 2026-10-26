shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// uv = local ground coords: x,y in [-1,1] over the footprint (origin at attack origin).
uniform int shape = 0; // 0 circle, 1 cone, 2 line (forward = +y of uv, width = |x|)
uniform float progress : hint_range(0.0, 1.0) = 0.0; // wind-up fill 0..1
uniform float half_angle = 0.7; // cone half angle in radians
uniform float line_half_width = 0.25;
uniform vec3 color_a : source_color = vec3(1.0, 0.1, 0.2);
uniform vec3 color_b : source_color = vec3(1.0, 0.8, 0.2);
varying vec2 luv;
void vertex() { luv = UV * 2.0 - 1.0; }
void fragment() {
	vec2 p = luv;
	float inside = 0.0;
	float fillr = 0.0; // 0..1 normalised distance used for the wind-up sweep
	float edge = 0.0;
	if (shape == 0) {
		float d = length(p);
		inside = 1.0 - step(1.0, d);
		fillr = d;
		edge = smoothstep(0.9, 1.0, d);
	} else if (shape == 1) {
		float d = length(p);
		float ang = abs(atan(p.x, p.y));
		inside = (1.0 - step(1.0, d)) * (1.0 - step(half_angle, ang));
		fillr = d;
		edge = max(smoothstep(0.92, 1.0, d), smoothstep(half_angle - 0.07, half_angle, ang));
	} else {
		float inl = 1.0 - step(line_half_width, abs(p.x));
		float inl2 = step(0.0, p.y) * (1.0 - step(1.0, p.y));
		inside = inl * inl2;
		fillr = p.y;
		edge = max(smoothstep(line_half_width * 0.8, line_half_width, abs(p.x)), smoothstep(0.94, 1.0, p.y));
	}
	float filled = 1.0 - step(progress, fillr);
	float pulse = 0.65 + 0.35 * sin(TIME * (6.0 + 10.0 * progress));
	vec3 c = mix(color_a * 0.35, color_b, filled) * pulse;
	c += color_a * edge * 1.4;
	ALBEDO = c * inside;
	ALPHA = inside * 0.85;
}
