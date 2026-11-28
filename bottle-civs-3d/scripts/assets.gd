class_name BCAssets
extends RefCounted
## Loading + material helpers. Every mesh in the game comes from the imported CC0 packs; materials use Poly Haven PBR maps.

static var _scenes := {}
static var _mats := {}

const HEX := "res://assets/hex/"

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

static func inst(path: String) -> Node3D:
	var ps := scene(path)
	return ps.instantiate() if ps != null else Node3D.new()

static func building(name: String, color: String) -> Node3D:
	if color == "neutral" or name.begins_with("wall_") or name.begins_with("fence_") or name in ["building_grain", "building_dirt", "building_destroyed", "building_scaffolding", "building_bridge_A", "building_bridge_B"]:
		return inst(HEX + "buildings/neutral/%s.gltf" % name)
	return inst(HEX + "buildings/%s/%s_%s.gltf" % [color, name, color])

static func nature(name: String) -> Node3D: return inst(HEX + "decoration/nature/%s.gltf" % name)
static func prop(name: String) -> Node3D: return inst(HEX + "decoration/props/%s.gltf" % name)
static func tile(name: String) -> Node3D: return inst(HEX + "tiles/base/%s.gltf" % name)

## PBR material from a Poly Haven folder (diff / nor / arm jpgs).
static func pbr(name: String, uv: Vector3 = Vector3(1, 1, 1), tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [name, uv, tint]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	var base := "res://assets/pbr/%s/%s_" % [name, name]
	m.albedo_texture = load(base + "diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "nor.jpg")
	var arm: Texture2D = load(base + "arm.jpg")
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic = 1.0
	m.metallic_texture = arm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.uv1_scale = uv
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	_mats[key] = m
	return m

static func glass(tint: Color = Color(0.7, 0.9, 1.0, 0.13)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic = 0.0
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.5
	return m

static func emissive(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

static func box(size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	return mi
