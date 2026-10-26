// Shared hex lookup + fog-of-war. Pointy-top, odd-r offset, 16 m flat-to-flat (matches HexMath).
uniform sampler2D fow_tex : filter_nearest, repeat_disable;
uniform bool fow_enabled = true;
uniform vec3 fow_unseen_color : source_color = vec3(0.16, 0.08, 0.26);
uniform bool grid_on = false;
uniform vec3 grid_color : source_color = vec3(1.0, 0.9, 0.5);

const float HEX_W = 16.0;
const float ROW_H = 13.856406;

// returns (col,row, local.x, local.z)
vec4 hex_info(vec2 p) {
	float qf = p.x / HEX_W - p.y / (2.0 * ROW_H);
	float rf = p.y / ROW_H;
	float sf = -qf - rf;
	float rq = round(qf);
	float rr = round(rf);
	float rs = round(sf);
	float dq = abs(rq - qf);
	float dr = abs(rr - rf);
	float ds = abs(rs - sf);
	if (dq > dr && dq > ds) {
		rq = -rr - rs;
	} else if (dr > ds) {
		rr = -rq - rs;
	}
	float par = rr - 2.0 * floor(rr * 0.5);
	float col = rq + (rr - par) * 0.5;
	vec2 cen = vec2(HEX_W * (col + 0.5 * par), ROW_H * rr);
	return vec4(col, rr, p - cen);
}

float hex_edge_dist(vec2 l) {
	float d0 = 8.0 - abs(l.x);
	float d1 = 8.0 - abs(dot(l, vec2(0.5, 0.8660254)));
	float d2 = 8.0 - abs(dot(l, vec2(-0.5, 0.8660254)));
	return min(d0, min(d1, d2));
}

// 0 unseen, 0.5 seen (remembered), 1 visible
float fow_state(vec4 hi) {
	ivec2 sz = textureSize(fow_tex, 0);
	if (hi.x < 0.0 || hi.y < 0.0 || hi.x >= float(sz.x) || hi.y >= float(sz.y)) {
		return 1.0;
	}
	return texelFetch(fow_tex, ivec2(int(hi.x), int(hi.y)), 0).r;
}

vec3 srgb_to_lin(vec3 c) {
	return pow(c, vec3(2.2));
}
