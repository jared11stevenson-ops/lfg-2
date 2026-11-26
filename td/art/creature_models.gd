extends RefCounted
# Procedural 3D creature models built from primitives, toon-shaded with inverted-hull outlines.
# Rendered to sprites by tools/render_sprites.gd (Bloons-style pre-rendered 3D). All models face +Z, stand on y=0.

static var _toon: Shader
static var _outline: Shader

static func _shaders() -> void:
	if _toon != null:
		return
	_toon = Shader.new()
	_toon.code = """
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float emit = 0.0;
uniform float alpha = 1.0;
void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = alpha;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = albedo.rgb * emit + rim_color.rgb * rim * 0.16;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.38 + 0.34 * step(0.0, ndl) + 0.28 * step(0.5, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band;
}
"""
	_outline = Shader.new()
	_outline.code = """
shader_type spatial;
render_mode cull_front, unshaded;
uniform float width = 0.03;
uniform vec4 ocolor : source_color = vec4(0.07, 0.06, 0.1, 1.0);
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = ocolor.rgb; }
"""

static func part(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, emit: float = 0.0, alpha: float = 1.0) -> MeshInstance3D:
	_shaders()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("emit", emit)
	m.set_shader_parameter("alpha", alpha)
	if alpha >= 0.99:
		var o := ShaderMaterial.new()
		o.shader = _outline
		var avg := (scl.x + scl.y + scl.z) / 3.0
		var size := mesh.get_aabb().size.length() * avg
		o.set_shader_parameter("width", (0.014 if size < 0.5 else 0.03) / avg)
		m.next_pass = o
	mi.material_override = m
	parent.add_child(mi)
	return mi

static func S(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 28
	m.rings = 14
	return m

static func Cone(r: float, h: float, seg: int = 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	return m

static func Cyl(r: float, h: float, seg: int = 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	return m

static func Box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

static func Tor(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m

static func _eyes(p: Node3D, y: float, x: float, z: float, r: float, iris: Color = Color("f6e7a8")) -> void:
	for s in [-1.0, 1.0]:
		part(p, S(r), Vector3(x * s, y, z), iris, Vector3(1, 1, 0.55))
		part(p, S(r * 0.5), Vector3(x * s, y, z + r * 0.35), Color("14121a"), Vector3(1, 1, 0.5))
		part(p, S(r * 0.18), Vector3(x * s + r * 0.2, y + r * 0.25, z + r * 0.6), Color.WHITE, Vector3.ONE, Vector3.ZERO, 1.0)

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"tickindle": _tickindle(root)
		"dugloom": _dugloom(root)
		"hutzin": _hutzin(root)
		"shuckit": _shuckit(root)
		"zapnose": _zapnose(root)
		"glomm": _glomm(root)
	return root

# Tickindle: Ember/Forge. Manul + Hephaestus's automatons + pocket watch.
static func _tickindle(r: Node3D) -> void:
	var fur := Color("5a5566")
	var fur2 := Color("7a7488")
	part(r, S(0.8), Vector3(0, 0.85, 0), fur, Vector3(1, 0.9, 1.05))
	part(r, S(0.55), Vector3(0, 0.7, 0.5), Color("8a8497"), Vector3(1, 1, 0.6))
	part(r, S(0.7), Vector3(0, 1.5, 0.25), fur, Vector3(1.3, 0.8, 0.95))
	for s in [-1.0, 1.0]:
		part(r, S(0.3), Vector3(0.75 * s, 1.35, 0.35), fur2)
		part(r, Cone(0.22, 0.45), Vector3(0.62 * s, 1.98, 0.1), fur, Vector3.ONE, Vector3(0, 0, -18 * s))
		part(r, Cone(0.11, 0.25), Vector3(0.62 * s, 1.94, 0.2), Color("e59a9a"), Vector3.ONE, Vector3(0, 0, -18 * s))
		part(r, S(0.24), Vector3(0.48 * s, 0.22, 0.42), Color("3d3a47"), Vector3(1, 0.8, 1.2))
		part(r, S(0.24), Vector3(0.5 * s, 0.22, -0.4), Color("3d3a47"), Vector3(1, 0.8, 1.2))
		part(r, Box(0.28, 0.07, 0.07), Vector3(0.4 * s, 1.74, 0.82), Color("231f2b"), Vector3.ONE, Vector3(0, 0, 18 * s))
	_eyes(r, 1.55, 0.4, 0.8, 0.15)
	part(r, S(0.08), Vector3(0, 1.4, 0.98), Color("e59a9a"))
	# pocket-watch chest plate
	part(r, Cyl(0.34, 0.1), Vector3(0, 0.82, 0.98), Color("e8c15a"), Vector3.ONE, Vector3(90, 0, 0))
	part(r, Cyl(0.26, 0.11), Vector3(0, 0.82, 1.0), Color("fff0c8"), Vector3.ONE, Vector3(90, 0, 0), 0.4)
	part(r, Tor(0.3, 0.42), Vector3(0, 0.82, 0.98), Color("ff8a2b"), Vector3.ONE, Vector3(90, 0, 0), 1.6)
	part(r, Box(0.04, 0.22, 0.03), Vector3(0.05, 0.9, 1.07), Color("c43c00"), Vector3.ONE, Vector3(0, 0, -35))
	# ember tail
	part(r, S(0.25), Vector3(0, 0.85, -0.95), fur)
	part(r, S(0.22), Vector3(0, 1.2, -1.1), fur)
	part(r, S(0.2), Vector3(0, 1.5, -1.05), Color("ff8a2b"), Vector3.ONE, Vector3.ZERO, 1.3)
	part(r, Cone(0.12, 0.4), Vector3(0, 1.85, -1.0), Color("ffd23a"), Vector3.ONE, Vector3.ZERO, 1.6)

# Dugloom: Tide/Spirit. Dugong + selkie lore + lighthouse lamp.
static func _dugloom(r: Node3D) -> void:
	var hide := Color("5f9fb0")
	part(r, S(0.9), Vector3(0, 0.8, 0), hide, Vector3(1, 0.85, 1.25))
	part(r, S(0.7), Vector3(0, 0.5, 0.1), Color("bfe0e6"), Vector3(1, 0.6, 1.1))
	part(r, S(0.55), Vector3(0, 1.15, 0.95), hide)
	part(r, S(0.38), Vector3(0, 0.95, 1.35), Color("d9ecef"), Vector3(1.2, 0.8, 0.9))
	for s in [-1.0, 1.0]:
		part(r, S(0.04), Vector3(0.1 * s, 1.0, 1.7), Color("0b1d22"))
		part(r, Cone(0.06, 0.22), Vector3(0.17 * s, 0.7, 1.55), Color.WHITE, Vector3.ONE, Vector3(180, 0, 0))
		part(r, S(0.36), Vector3(0.98 * s, 0.45, 0.4), hide, Vector3(1, 0.22, 0.75), Vector3(0, 0, -25 * s))
		part(r, S(0.46), Vector3(0.45 * s, 0.75, -1.55), hide, Vector3(1, 0.16, 0.6), Vector3(0, 20 * s, -10 * s))
	_eyes(r, 1.3, 0.32, 1.36, 0.1, Color("0b1d22"))
	part(r, S(0.4), Vector3(0, 0.78, -1.2), hide)
	# lantern: base, glass, cage ring
	part(r, Cyl(0.22, 0.14), Vector3(0, 1.72, 0.85), Color("3a2e22"))
	part(r, S(0.3), Vector3(0, 2.05, 0.85), Color("ffe680"), Vector3.ONE, Vector3.ZERO, 2.0, 0.9)
	part(r, Tor(0.28, 0.34), Vector3(0, 2.05, 0.85), Color("3a2e22"))
	part(r, Cone(0.18, 0.2), Vector3(0, 2.4, 0.85), Color("3a2e22"))
	for i in 3:
		part(r, S(0.07), Vector3(-0.9 + i * 0.9, 0.25 + i * 0.1, 0.2 - i * 0.4), Color("9fe8ff"), Vector3.ONE, Vector3.ZERO, 1.6, 0.7)

# Hutzin: Verdant/Venom. Hoatzin + Baba Yaga's hut + teapot.
static func _hutzin(r: Node3D) -> void:
	var green := Color("7a9a3a")
	part(r, S(0.75), Vector3(0, 1.0, 0), green, Vector3(1, 1, 1.1))
	part(r, S(0.5), Vector3(0, 0.85, 0.45), Color("c8d890"), Vector3(1, 1, 0.6))
	part(r, S(0.4), Vector3(0, 1.8, 0.55), green)
	part(r, S(0.24), Vector3(0, 1.75, 0.85), Color("5ac8d6"), Vector3(1.1, 1, 0.6))
	part(r, Cone(0.12, 0.32), Vector3(0, 1.66, 1.08), Color("f2b84b"), Vector3.ONE, Vector3(90, 0, 0))
	_eyes(r, 1.9, 0.22, 0.88, 0.09, Color("d6362b"))
	for i in 3:
		part(r, Cone(0.09, 0.55), Vector3(-0.16 + i * 0.16, 2.25 - abs(i - 1) * 0.1, 0.4), Color("e0632b"), Vector3.ONE, Vector3(-25, 0, (i - 1) * 14))
	for s in [-1.0, 1.0]:
		part(r, S(0.4), Vector3(0.78 * s, 1.0, 0.05), Color("5f7a2c"), Vector3(0.35, 1, 0.8), Vector3(0, 0, -15 * s))
		part(r, Cone(0.05, 0.22), Vector3(0.9 * s, 0.55, 0.45), Color("231f2b"), Vector3.ONE, Vector3(150, 0, 0))
		part(r, Cyl(0.075, 0.8), Vector3(0.3 * s, 0.4, 0.15), Color("e0a23b"))
		for t in 3:
			part(r, S(0.08), Vector3(0.3 * s + (t - 1) * 0.11, 0.05, 0.3), Color("e0a23b"), Vector3(1, 0.7, 1.6))
	# cottage-teapot on its back
	part(r, Box(0.85, 0.6, 0.7), Vector3(0, 1.75, -0.3), Color("9a6b3c"))
	var roof := Cone(0.75, 0.55, 4)
	part(r, roof, Vector3(0, 2.3, -0.3), Color("c14a4a"), Vector3.ONE, Vector3(0, 45, 0))
	part(r, Box(0.22, 0.38, 0.05), Vector3(0, 1.6, 0.07), Color("3b2412"))
	part(r, Box(0.2, 0.4, 0.2), Vector3(0.28, 2.55, -0.45), Color("8a8a96"))
	part(r, Cone(0.12, 0.5), Vector3(0.65, 1.85, -0.3), Color("9a6b3c"), Vector3.ONE, Vector3(0, 0, -65))
	for i in 3:
		part(r, S(0.1 + i * 0.03), Vector3(0.9 + i * 0.1, 2.15 + i * 0.28, -0.3), Color("b44bd8"), Vector3.ONE, Vector3.ZERO, 1.2, 0.6)

# Shuckit: Umbra/Gale. Bat-eared fox + Black Shuck + broken umbrella.
static func _shuckit(r: Node3D) -> void:
	var ink := Color("34314a")
	part(r, S(0.55), Vector3(0, 0.75, -0.1), ink, Vector3(0.9, 0.8, 1.3))
	part(r, S(0.42), Vector3(0, 0.95, 0.7), ink)
	part(r, Cone(0.2, 0.55), Vector3(0, 0.85, 1.15), ink, Vector3.ONE, Vector3(90, 0, 0))
	part(r, S(0.07), Vector3(0, 0.85, 1.42), Color("14121a"))
	for s in [-1.0, 1.0]:
		part(r, Cone(0.38, 1.1), Vector3(0.42 * s, 1.6, 0.5), ink, Vector3(1, 1, 0.3), Vector3(-10, 0, -22 * s))
		part(r, Cyl(0.02, 1.0), Vector3(0.36 * s, 1.6, 0.58), Color("8a89a6"), Vector3.ONE, Vector3(-10, 0, -22 * s))
		part(r, Cyl(0.07, 0.6), Vector3(0.28 * s, 0.3, 0.3), Color("231f2b"))
		part(r, Cyl(0.07, 0.6), Vector3(0.28 * s, 0.3, -0.5), Color("231f2b"))
	for i in 3:
		part(r, S(0.2 - i * 0.04), Vector3(0, 0.9 + i * 0.15, -0.95 - i * 0.28), ink, Vector3.ONE, Vector3.ZERO, 0.3 * i)
	for s in [-1.0, 1.0]:
		part(r, S(0.09), Vector3(0.2 * s, 1.05, 1.0), Color("fff3a0"), Vector3.ONE, Vector3.ZERO, 2.2)

# Zapnose: Volt/Aether. Elephantnose fish + Nikola Tesla + doorbell.
static func _zapnose(r: Node3D) -> void:
	var blue := Color("2f45b0")
	part(r, S(0.55), Vector3(0, 0.95, 0), blue, Vector3(0.8, 0.75, 1.7))
	part(r, S(0.4), Vector3(0, 0.98, 0.9), blue)
	for i in 3:
		part(r, Tor(0.46, 0.58), Vector3(0, 0.95, -0.45 + i * 0.4), Color("ffd23a"), Vector3(0.8, 0.8, 0.8), Vector3(90, 0, 0), 0.6)
	var np := [Vector3(0, 0.88, 1.3), Vector3(0, 0.78, 1.58), Vector3(0, 0.72, 1.84), Vector3(0, 0.8, 2.05)]
	for i in 4:
		part(r, S(0.15 - i * 0.015), np[i], Color("6c8cff"))
	part(r, S(0.12), Vector3(0, 0.98, 2.2), Color("ffd23a"), Vector3.ONE, Vector3.ZERO, 1.8)
	_eyes(r, 1.08, 0.38, 0.95, 0.1, Color.WHITE)
	part(r, Cone(0.3, 0.6), Vector3(0, 1.55, -0.1), Color("ffd23a"), Vector3(0.3, 1, 1), Vector3(-10, 0, 0))
	part(r, S(0.4), Vector3(0, 0.95, -1.5), blue, Vector3(0.1, 0.9, 0.7))
	for s in [-1.0, 1.0]:
		part(r, S(0.3), Vector3(0.5 * s, 0.7, 0.4), blue, Vector3(0.8, 0.15, 0.7), Vector3(0, 0, -20 * s))
	for i in 4:
		part(r, Cone(0.05, 0.4), Vector3(-0.6 + i * 0.4, 1.7 + (i % 2) * 0.2, -0.3 + (i % 3) * 0.3), Color("fff3a0"), Vector3.ONE, Vector3(20 * i, 0, 30 * i - 40), 2.0)

# Glomm: Stone/Frost. Yeti crab + Golem of Prague + snow globe.
static func _glomm(r: Node3D) -> void:
	var stone := Color("7f8da6")
	var fur := Color("e8f0f7")
	part(r, S(0.95), Vector3(0, 0.95, 0), stone, Vector3(1, 0.85, 1))
	for i in 3:
		part(r, S(0.28), Vector3(-0.5 + i * 0.5, 1.25 - (i % 2) * 0.35, -0.7), Color("5a6679"), Vector3(1, 0.5, 0.5))
	part(r, Box(1.1, 0.24, 0.35), Vector3(0, 1.15, 0.78), Color("5a6679"))
	for s in [-1.0, 1.0]:
		part(r, S(0.1), Vector3(0.3 * s, 0.98, 0.9), Color("9be7ff"), Vector3.ONE, Vector3.ZERO, 2.0)
		part(r, S(0.4), Vector3(1.2 * s, 0.8, 0.5), fur)
		for i in 6:
			var a := i * 1.05
			part(r, Cone(0.1, 0.34), Vector3(1.2 * s + cos(a) * 0.38, 0.8 + sin(a) * 0.38, 0.5), fur, Vector3.ONE, Vector3(0, 0, rad_to_deg(a) - 90))
		for i in 3:
			part(r, Cyl(0.12, 0.5), Vector3(0.6 * s, 0.2, 0.5 - i * 0.5), Color("5a6679"))
	part(r, Box(0.5, 0.06, 0.05), Vector3(0, 0.7, 0.93), Color("1c2433"))
	for i in 12:
		var a := i * TAU / 12.0
		part(r, Cone(0.1, 0.38), Vector3(cos(a) * 0.82, 0.4, sin(a) * 0.82), fur, Vector3.ONE, Vector3(rad_to_deg(sin(a)) * -1.0, 0, rad_to_deg(cos(a)) * -0.6 + 180))
	# snow globe on its back
	part(r, Cyl(0.32, 0.2), Vector3(0, 1.82, -0.2), Color("a2763a"))
	part(r, S(0.52), Vector3(0, 2.3, -0.2), Color("b8e4ff"), Vector3.ONE, Vector3.ZERO, 0.3, 0.35)
	part(r, Cone(0.14, 0.4), Vector3(0, 2.1, -0.2), Color("3f8a3a"))
	for i in 9:
		part(r, S(0.04), Vector3(-0.3 + fmod(i * 0.37, 0.6), 2.1 + fmod(i * 0.23, 0.5), -0.4 + fmod(i * 0.31, 0.4)), Color.WHITE, Vector3.ONE, Vector3.ZERO, 2.0)
