class_name GameWorld
extends Node2D
## Renders the ecosystem's world and answers terrain queries. 1 tile = 32px, 8x8 tiles per sim region.
const TILE := 32.0
const TPR := 8
const TW := EcoSim.RW * TPR   # tiles across
const SS := 3                 # data-texture supersampling per tile
var sim: EcoSim
var elev := PackedFloat32Array()
var water := PackedFloat32Array()
var tree_n := PackedFloat32Array()
var data_img: Image
var data_tex: ImageTexture
var mat: ShaderMaterial
var time_s := 0.0
var fx: FxLayer

func world_px() -> float: return TW * TILE

func build(s: EcoSim) -> void:
	sim = s
	var n := TW * TW
	elev.resize(n); water.resize(n); tree_n.resize(n)
	var noise := FastNoiseLite.new(); noise.seed = s.seed_ + 99; noise.frequency = 0.09; noise.fractal_octaves = 3
	data_img = Image.create(TW, TW, false, Image.FORMAT_RGBAF)
	var hi := Image.create(TW * SS, TW * SS, false, Image.FORMAT_RGBAF)
	for ty in TW:
		for tx in TW:
			var fx := (tx + 0.5) / TPR - 0.5; var fy := (ty + 0.5) / TPR - 0.5
			var x0 := clampi(int(floor(fx)), 0, EcoSim.RW - 1); var y0 := clampi(int(floor(fy)), 0, EcoSim.RH - 1)
			var x1 := mini(x0 + 1, EcoSim.RW - 1); var y1 := mini(y0 + 1, EcoSim.RH - 1)
			var ax := clampf(fx - x0, 0.0, 1.0); var ay := clampf(fy - y0, 0.0, 1.0)
			var e := _bil(s.elev, x0, y0, x1, y1, ax, ay) + noise.get_noise_2d(tx, ty) * 0.045
			var m := _bil(s.moist, x0, y0, x1, y1, ax, ay)
			var t := _bil(s.temp, x0, y0, x1, y1, ax, ay)
			var tr := _bil(s.trees, x0, y0, x1, y1, ax, ay)
			var w := 1.0 if e < 0.325 else (0.0 if _bil(s.water, x0, y0, x1, y1, ax, ay) < 0.3 else 0.5)
			var i := ty * TW + tx
			elev[i] = e; water[i] = w; tree_n[i] = tr * (1.0 if e > 0.35 and e < 0.62 else 0.0)
			data_img.set_pixel(tx, ty, Color(clampf(e, 0, 1), m, w, t))
	for hy in TW * SS:
		for hx in TW * SS:
			var fx2 := (hx + 0.5) / SS - 0.5; var fy2 := (hy + 0.5) / SS - 0.5
			var ix := clampi(int(floor(fx2)), 0, TW - 1); var iy := clampi(int(floor(fy2)), 0, TW - 1)
			var jx := mini(ix + 1, TW - 1); var jy := mini(iy + 1, TW - 1)
			var ax2 := clampf(fx2 - ix, 0.0, 1.0); var ay2 := clampf(fy2 - iy, 0.0, 1.0)
			var c00 := data_img.get_pixel(ix, iy); var c10 := data_img.get_pixel(jx, iy); var c01 := data_img.get_pixel(ix, jy); var c11 := data_img.get_pixel(jx, jy)
			hi.set_pixel(hx, hy, c00.lerp(c10, ax2).lerp(c01.lerp(c11, ax2), ay2))
	data_tex = ImageTexture.create_from_image(hi)
	mat = ShaderMaterial.new()
	mat.shader = load("res://art/shaders/terrain.gdshader")
	mat.set_shader_parameter("world_data", data_tex)
	mat.set_shader_parameter("world_px", Vector2(world_px(), world_px()))
	var rect := ColorRect.new()
	rect.size = Vector2(world_px(), world_px())
	rect.material = mat
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(rect)
	fx = FxLayer.new(); fx.z_index = 100; add_child(fx)

func _bil(a: PackedFloat32Array, x0: int, y0: int, x1: int, y1: int, ax: float, ay: float) -> float:
	var i := func(x, y): return a[y * EcoSim.RW + x]
	return lerpf(lerpf(i.call(x0, y0), i.call(x1, y0), ax), lerpf(i.call(x0, y1), i.call(x1, y1), ax), ay)

func _process(dt: float) -> void:
	time_s += dt
	if mat: mat.set_shader_parameter("time_s", time_s)

func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / TILE), 0, TW - 1), clampi(int(p.y / TILE), 0, TW - 1))

func is_water(p: Vector2) -> bool:
	var t := tile_of(p)
	return elev[t.y * TW + t.x] < 0.325

func deep_water(p: Vector2) -> bool:
	var t := tile_of(p)
	return elev[t.y * TW + t.x] < 0.26

func region_of(p: Vector2) -> int:
	var rx := clampi(int(p.x / (TILE * TPR)), 0, EcoSim.RW - 1)
	var ry := clampi(int(p.y / (TILE * TPR)), 0, EcoSim.RH - 1)
	return ry * EcoSim.RW + rx

func region_center(r: int) -> Vector2:
	return Vector2((r % EcoSim.RW + 0.5) * TILE * TPR, (r / EcoSim.RW + 0.5) * TILE * TPR)

func random_land_near(c: Vector2, rad: float, rng: RandomNumberGenerator, aquatic: bool = false) -> Vector2:
	for k in 20:
		var p := c + Vector2(rng.randf_range(-rad, rad), rng.randf_range(-rad, rad))
		p = p.clamp(Vector2(40, 40), Vector2(world_px() - 40, world_px() - 40))
		if is_water(p) == aquatic: return p
	return c

func fx_ring(p: Vector2, c: Color, r: float) -> void:
	if fx: fx.ring(p, c, r)
func fx_text(p: Vector2, s: String, c: Color) -> void:
	if fx: fx.text(p, s, c)

func civ_spot(civ_id: int, rng: RandomNumberGenerator) -> Vector2:
	if civ_id < 0 or civ_id >= sim.civs.size(): return Vector2.ZERO
	var st: Array = sim.civs[civ_id]["structures"]
	if st.is_empty(): return Vector2.ZERO
	var s: Dictionary = st[rng.randi() % st.size()]
	if s["state"] != "alive": return Vector2.ZERO
	return Vector2(s["tile"].x * TILE + 16.0, s["tile"].y * TILE + 16.0)

signal civ_attacked(civ_id: int, victim)
func civ_provoked(civ_id: int, victim) -> void:
	civ_attacked.emit(civ_id, victim)
