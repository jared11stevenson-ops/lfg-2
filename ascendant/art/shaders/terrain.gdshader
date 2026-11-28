shader_type canvas_item;
// Painterly terrain: data texture (R elev, G moist, B water, A temp) -> illustrated ground.
uniform sampler2D world_data : filter_linear, repeat_disable;
uniform vec2 world_px = vec2(8192.0, 8192.0);
uniform float time_s = 0.0;
varying vec2 wpos;

float hash(vec2 p){ p = fract(p*vec2(123.34, 456.21)); p += dot(p, p+45.32); return fract(p.x*p.y); }
float vnoise(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x), f.y); }
float fbm(vec2 p){ float a=0.5, s=0.0; for(int i=0;i<4;i++){ s+=a*vnoise(p); p*=2.03; a*=0.5;} return s; }

void vertex(){ wpos = VERTEX; }

vec3 pal_grass(float moist, float temp, float n){
  vec3 dry  = vec3(0.70, 0.62, 0.36);
  vec3 lush = vec3(0.30, 0.52, 0.27);
  vec3 cold = vec3(0.50, 0.58, 0.46);
  vec3 c = mix(dry, lush, smoothstep(0.25, 0.75, moist));
  c = mix(c, cold, smoothstep(0.55, 0.15, temp)*0.6);
  return c * (0.88 + 0.24*n);
}

void fragment(){
  vec2 uv = wpos / world_px;
  vec4 d = texture(world_data, uv);
  float e = d.r, m = d.g, w = d.b, t = d.a;
  vec2 px = 1.0 / vec2(textureSize(world_data, 0));
  // hillshade from elevation gradient
  float ex = texture(world_data, uv + vec2(px.x,0)).r - texture(world_data, uv - vec2(px.x,0)).r;
  float ey = texture(world_data, uv + vec2(0,px.y)).r - texture(world_data, uv - vec2(0,px.y)).r;
  float shade = clamp(0.5 - (ex*0.9 + ey*1.2)*9.0, 0.0, 1.0);
  float n1 = fbm(wpos*0.012);
  float n2 = fbm(wpos*0.06 + 7.0);
  float grain = vnoise(wpos*0.9);
  vec3 col;
  float shore = smoothstep(0.30, 0.355, e);   // 0 water -> 1 land
  // ground
  vec3 g = pal_grass(m + (n1-0.5)*0.25, t, n2);
  vec3 sand = vec3(0.82, 0.74, 0.52) * (0.92 + 0.14*n2);
  vec3 rock = vec3(0.50, 0.46, 0.45) * (0.85 + 0.3*n2);
  float beach = smoothstep(0.37, 0.33, e + (n2-0.5)*0.03);
  col = mix(g, sand, beach * (1.0 - w*0.0));
  col = mix(col, rock, smoothstep(0.62, 0.78, e + (n1-0.5)*0.1));
  // wet ground / marsh tint
  col = mix(col, vec3(0.26,0.40,0.30), clamp(w,0.0,1.0)*smoothstep(0.30,0.36,e)*0.8);
  // water
  vec3 deep = vec3(0.10, 0.24, 0.38);
  vec3 shal = vec3(0.26, 0.55, 0.60);
  float depth = smoothstep(0.34, 0.14, e);
  vec3 wc = mix(shal, deep, depth);
  float rip = vnoise(wpos*0.05 + vec2(time_s*0.15, -time_s*0.1)) + vnoise(wpos*0.11 - vec2(time_s*0.2, time_s*0.07))*0.5;
  wc += (rip-0.75)*0.10;
  wc += 0.06*smoothstep(0.82,0.95, vnoise(wpos*0.09 + vec2(time_s*0.3, 0.0)));  // glints
  col = mix(wc, col, shore);
  // foam / inked shoreline
  float edge = abs(e - 0.325);
  float foam = smoothstep(0.012, 0.0, edge) * (0.6 + 0.4*sin(time_s*1.5 + wpos.x*0.05));
  col = mix(col, vec3(0.93,0.95,0.9), foam*0.55);
  float inkl = smoothstep(0.004, 0.0, abs(e - 0.34));
  col = mix(col, vec3(0.13,0.12,0.2), inkl*0.55);
  // lighting: warm lights, cool shadows
  float l = mix(0.80, 1.12, shade);
  col *= mix(vec3(0.85,0.88,1.05), vec3(1.06,1.0,0.88), shade) * l;
  // paper grain + vignette-like variation
  col += (grain-0.5)*0.035;
  COLOR = vec4(col, 1.0);
}
