shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_mix, specular_disabled;
#include "res://world/shaders/fow.gdshaderinc"
uniform float purge : hint_range(0.0, 1.0) = 0.0;
varying vec3 wpos;
varying vec4 vcol;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}
void fragment() {
	vec3 col = srgb_to_lin(vcol.rgb);
	// slow sparkle bands, cheap and flat
	float s = sin(wpos.x * 0.7 + TIME * 0.8) * sin(wpos.z * 0.55 - TIME * 0.6);
	col += vec3(0.06, 0.12, 0.12) * smoothstep(0.55, 0.95, s);
	col = mix(col, vec3(0.5, 0.05, 0.25), purge * 0.5);
	float a = vcol.a;
	if (fow_enabled) {
		float st = fow_state(hex_info(wpos.xz));
		if (st < 0.25) {
			col = srgb_to_lin(fow_unseen_color);
			a = 1.0;
		} else if (st < 0.75) {
			col *= 0.6;
		}
	}
	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = 0.4;
}
