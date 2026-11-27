class_name InsectMesh
extends RefCounted
## Procedural insect bodies built from primitives (no imported art needed), so
## every genome has a visible, distinct silhouette. Designed to be replaced by
## Blender-authored glTF meshes later without changing callers.

static func _mat(c: Color, emit: float = 0.0, rough: float = 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.35
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func _sphere(r: float = 0.5) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s

static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 6
	return c

## profile keys: color, accent, legs, wings, mandibles, plates, abdomen, glow, scale
static func build(profile: Dictionary) -> Node3D:
	var root := Node3D.new()
	var body: Color = profile.get("color", Color(0.4, 0.3, 0.2))
	var acc: Color = profile.get("accent", body.lightened(0.3))
	var sc: float = profile.get("scale", 1.0)
	var glow: float = profile.get("glow", 0.0)
	var bm := _mat(body)
	var am := _mat(acc, glow)
	var abdomen: float = profile.get("abdomen", 1.0)
	_part(root, _sphere(0.42), bm, Vector3(0, 0.55, 0), Vector3(1, 0.8, 1.2))                 # thorax
	_part(root, _sphere(0.28), bm, Vector3(0, 0.6, -0.62), Vector3(1, 0.9, 1))               # head
	_part(root, _sphere(0.5), am, Vector3(0, 0.55, 0.72 * abdomen), Vector3(0.9, 0.8, 1.3 * abdomen))  # abdomen
	var eye := _mat(Color(0.9, 0.2, 0.1), 1.5)
	_part(root, _sphere(0.08), eye, Vector3(-0.14, 0.7, -0.82))
	_part(root, _sphere(0.08), eye, Vector3(0.14, 0.7, -0.82))
	var legs: int = profile.get("legs", 6)
	var lm := _mat(body.darkened(0.25))
	for i in legs:
		var side := -1.0 if i % 2 == 0 else 1.0
		var zi := float(i / 2) / maxf(1.0, float(legs / 2 - 1))
		var z := lerpf(-0.35, 0.45, zi)
		_part(root, _cyl(0.04, 0.06, 0.7), lm, Vector3(side * 0.5, 0.3, z), Vector3.ONE, Vector3(0, 0, side * -50))
	if profile.get("mandibles", false):
		var mm := _mat(Color(0.2, 0.08, 0.05))
		_part(root, _cyl(0.0, 0.07, 0.4), mm, Vector3(-0.15, 0.55, -0.95), Vector3.ONE, Vector3(90, 0, 25))
		_part(root, _cyl(0.0, 0.07, 0.4), mm, Vector3(0.15, 0.55, -0.95), Vector3.ONE, Vector3(90, 0, -25))
	if profile.get("wings", false):
		var wm := _mat(Color(0.8, 0.9, 1.0, 0.55), 0.3, 0.2)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_part(root, _sphere(0.5), wm, Vector3(-0.55, 0.95, 0.2), Vector3(0.9, 0.05, 1.5), Vector3(0, 0, 18))
		_part(root, _sphere(0.5), wm, Vector3(0.55, 0.95, 0.2), Vector3(0.9, 0.05, 1.5), Vector3(0, 0, -18))
	for p in int(profile.get("plates", 0)):
		_part(root, _cyl(0.05, 0.28, 0.12), _mat(body.darkened(0.4), 0.0, 0.3), Vector3(0, 0.95 + 0.0, -0.1 + p * 0.3), Vector3(1.4, 1, 1.4))
	if profile.get("stinger", false):
		_part(root, _cyl(0.0, 0.1, 0.55), _mat(Color(0.9, 0.7, 0.1), 0.6), Vector3(0, 0.55, 1.55 * abdomen), Vector3.ONE, Vector3(90, 0, 0))
	root.scale = Vector3.ONE * sc
	return root

static func profile_from_genome(g: Genome) -> Dictionary:
	var ids := []
	for s in 6:
		ids.append(g.express(s).id)
	var body: Color = GeneDB.get_gene(ids[5]).color.lerp(GeneDB.get_gene(ids[1]).color, 0.5)
	var acc: Color = GeneDB.get_gene(ids[2]).color
	var plates := 0
	if ids[5] == "chitin_plate" or ids[1] == "hardened_thorax": plates = 2
	if ids[4] == "elytra_shield": plates += 2
	return {
		"color": body.lightened(0.05), "accent": acc, "legs": 6,
		"wings": ids[4] != "larval_wings" and ids[4] != "vestigial_stubs",
		"mandibles": ids[0] in ["mandible_shear", "raptorial_forelimbs"],
		"plates": plates, "abdomen": 1.3 if ids[2] != "larval_abdomen" else 0.9,
		"glow": 2.0 if ids[2] == "biolume_organ" else 0.0,
		"stinger": ids[2] == "venom_stinger", "scale": 1.0,
	}

static func profile_from_species(sid: String) -> Dictionary:
	var sp := SpeciesDB.get_species(sid)
	var c: Color = sp.color
	return {"color": c, "accent": c.lightened(0.25), "legs": 6, "scale": sp.scale,
		"wings": sid in ["ash_moth", "hive_drone", "cathedral_regent"],
		"mandibles": sid in ["razor_mantis", "web_widow", "cathedral_regent", "gutter_roach"],
		"plates": 3 if sid in ["rust_beetle", "cathedral_regent"] else 0,
		"abdomen": 1.5 if sid == "web_widow" else 1.0,
		"glow": 1.5 if sid in ["ash_moth", "cathedral_regent"] else 0.0,
		"stinger": sid in ["hive_drone", "web_widow"]}
