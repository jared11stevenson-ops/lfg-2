shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;
#include "res://world/shaders/fow.gdshaderinc"

uniform bool hide_unseen = false; // props vanish inside unexplored hexes
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
varying vec3 wpos;
varying vec4 vcol;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	vec3 col = srgb_to_lin(vcol.rgb);
	vec4 hi = hex_info(wpos.xz);
	float st = 1.0;
	if (fow_enabled) {
		st = fow_state(hi);
		if (hide_unseen && st < 0.25) {
			discard;
		}
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	if (fow_enabled) {
		if (st < 0.25) {
			float e = hex_edge_dist(hi.zw);
			float line = 1.0 - smoothstep(0.1, 0.5, e);
			EMISSION = srgb_to_lin(fow_unseen_color) * 1.1 + srgb_to_lin(vec3(0.55, 0.3, 0.9)) * line * 0.45;
			ALBEDO = vec3(0.0);
		} else if (st < 0.75) {
			vec3 grey = vec3(dot(col, vec3(0.299, 0.587, 0.114)));
			col = mix(grey, col, 0.45) * 0.62 + srgb_to_lin(fow_unseen_color) * 0.25;
			ALBEDO = col;
		} else {
			ALBEDO = col;
		}
	} else {
		ALBEDO = col;
	}
	if (grid_on) {
		float e = hex_edge_dist(hi.zw);
		float line = 1.0 - smoothstep(0.08, 0.28, e);
		EMISSION += srgb_to_lin(grid_color) * line * 0.9;
	}
	ROUGHNESS = 1.0;
}
