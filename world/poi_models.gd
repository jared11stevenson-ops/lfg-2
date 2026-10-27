class_name PoiModels
extends RefCounted
## Original procedural props for the seven point-of-interest types (data/pois.json "prop" keys) plus the two beacon markers.
## Flat-shaded, vertex-coloured, 3-6 m wide so each reads from the follow camera: a silhouette per type, a glowing accent colour per type.
const PROPS: Array[String] = ["farm", "cave", "shrine", "vault", "wreck", "hut", "spire",
	"arena_meadow", "arena_shore", "arena_fungal_grove", "arena_ruins", "arena_salt_flats", "arena_highlands", "arena_bog"]
const ACCENT: Dictionary = {"farm": Color("ffd24a"), "cave": Color("b6ff6a"), "shrine": Color("49c6e5"), "vault": Color("c47bff"), "wreck": Color("ff8a3c"), "hut": Color("ff7a8a"), "spire": Color("d8fff6"),
	"arena_meadow": Color("f08a2a"), "arena_shore": Color("2fb8a8"), "arena_fungal_grove": Color("a63ad8"), "arena_ruins": Color("c47bff"), "arena_salt_flats": Color("7ac8f0"),
	"arena_highlands": Color("ffe84a"), "arena_bog": Color("8ab83a")}
static var _cache: Dictionary = {}

static func mesh_for(prop: String) -> ArrayMesh:
	if _cache.has(prop):
		return _cache[prop]
	var k := MeshKit.new()
	match prop:
		"farm": _farm(k)
		"cave": _cave(k)
		"shrine": _shrine(k)
		"vault": _vault(k)
		"wreck": _wreck(k)
		"hut": _hut(k)
		"spire": _spire(k)
		"arena_meadow", "arena_shore", "arena_fungal_grove", "arena_ruins", "arena_salt_flats", "arena_highlands", "arena_bog": _arena(k, prop)
		"beacon_on": _beacon(k, Color("ffe84a"), Color("fffbd0"), 9.0)
		"beacon_off": _beacon(k, Color("8a7f9a"), Color("b8aec4"), 3.2)
		_: _hut(k)
	var m: ArrayMesh = k.build()
	_cache[prop] = m
	return m

static func _farm(k: MeshKit) -> void:
	# a fallen barn: one wall standing, the roof slumped, a fence and one stubborn crop row
	k.box(Vector3(0, 0.15, 0), Vector3(5.6, 0.3, 4.0), Color("7a6a4a"))
	k.box(Vector3(-1.0, 1.4, 0.8), Vector3(3.4, 2.6, 0.35), Color("b8884a"), Color("d8a86a"))
	k.box(Vector3(1.6, 0.6, 0.6), Vector3(0.35, 1.2, 1.8), Color("9a6a3a"))
	k.quad(Vector3(-2.6, 2.7, 0.7), Vector3(0.4, 2.7, 0.7), Vector3(1.8, 0.7, -1.4), Vector3(-0.6, 0.6, -1.4), Color("c4683a"))
	k.quad(Vector3(0.4, 2.7, 0.7), Vector3(-2.6, 2.7, 0.7), Vector3(-0.6, 0.6, -1.4), Vector3(1.8, 0.7, -1.4), Color("e8553a"))
	for i in 5:
		k.box(Vector3(-2.4 + 1.2 * float(i), 0.6, -1.9), Vector3(0.18, 1.2, 0.18), Color("6a4a30"))
	k.box(Vector3(0.1, 0.95, -1.9), Vector3(5.0, 0.12, 0.1), Color("6a4a30"))
	for i in 4:
		k.dome(Vector3(-1.5 + 1.0 * float(i), 0.35, 2.0), 0.4, 1.1, 1, 5, Color("7fd04a"), Color("4fa03a"))
	k.dome(Vector3(1.8, 2.1, 0.0), 0.35, 1.4, 1, 6, Color("ffd24a"), Color("fff7c2"))

static func _cave(k: MeshKit) -> void:
	k.blob(Vector3(0, 1.4, 0), Vector3(3.6, 2.4, 3.0), 41, Color("7b5f8f"), Color("a58bb5"))
	k.blob(Vector3(-2.6, 0.7, 1.2), Vector3(1.4, 1.1, 1.2), 17, Color("6a5080"), Color("9078a8"))
	k.box(Vector3(0, 0.9, -2.3), Vector3(1.9, 1.8, 0.7), Color("1a0a2a"))
	k.pyramid(Vector3(0, 1.8, -2.3), 1.0, 0.4, 0.5, Color("1a0a2a"), Color("2a1a3a"))
	for i in 5:
		var a: float = deg_to_rad(-70.0 + 35.0 * float(i))
		var p := Vector3(sin(a) * 2.0, 0.0, -2.7 - cos(a) * 0.5)
		k.frustum(p, 0.0, 0.13, 0.6 + 0.2 * float(i % 3), 0.1, 5, Color("f6ead7"))
		k.dome(p + Vector3(0, 0.6 + 0.2 * float(i % 3), 0), 0.34, 0.8, 1, 6, Color("b6ff6a") if i % 2 == 0 else Color("ff2fb5"), Color("f0ffd0"))

static func _shrine(k: MeshKit) -> void:
	var st := Color("c5b4c8")
	k.frustum(Vector3.ZERO, 0.0, 2.1, 0.35, 1.9, 8, Color("8f7f9a"), Color("b8a8c0"))
	k.frustum(Vector3(0, 0.35, 0), 0.0, 0.5, 0.7, 0.8, 7, st, Color("49c6e5"))       # the offering bowl
	for i in 3:
		var a: float = deg_to_rad(210.0 + 60.0 * float(i))
		var p := Vector3(cos(a) * 1.45, 0.35, sin(a) * 1.45)
		k.frustum(p, 0.0, 0.3, 1.6, 0.22, 5, st, Color("e3d6e6"))
		k.box(p + Vector3(0, 1.75, 0), Vector3(0.62, 0.22, 0.62), Color("8f7f9a"), Color("b8a8c0"))
		k.dome(p + Vector3(0, 1.86, 0), 0.26, 1.3, 1, 6, Color("ffd24a"), Color("fff7c2"))
	k.box(Vector3(0, 1.3, 1.7), Vector3(0.3, 2.0, 0.3), Color("8f7f9a"))
	k.box(Vector3(0, 2.4, 1.7), Vector3(1.3, 0.22, 0.3), Color("8f7f9a"))

static func _vault(k: MeshKit) -> void:
	k.blob(Vector3(0, 1.0, 0.8), Vector3(3.8, 2.0, 2.6), 29, Color("6f5f7f"), Color("8f7f9f"))
	k.box(Vector3(0, 1.45, -1.3), Vector3(2.8, 2.9, 0.5), Color("b9a6b5"), Color("dccfdc"))
	k.box(Vector3(0, 1.3, -1.6), Vector3(1.5, 2.1, 0.18), Color("5a4a6a"), Color("7a6a8a"))
	for i in 3:
		var col: Array[Color] = [Color("c47bff"), Color("49c6e5"), Color("ffd24a")]
		k.box(Vector3(-1.0 + 1.0 * float(i), 0.12, -2.4), Vector3(0.7, 0.24, 0.7), col[i], col[i].lightened(0.3))
		k.box(Vector3(-1.0 + 1.0 * float(i), 3.05, -1.5), Vector3(0.5, 0.5, 0.12), col[i], col[i].lightened(0.3))
	k.box(Vector3(-2.2, 0.5, -1.3), Vector3(0.9, 1.0, 0.9), Color("a898ac"))
	k.box(Vector3(2.3, 0.3, -1.0), Vector3(1.1, 0.6, 0.8), Color("a898ac"), Color("cfc0d4"))

static func _wreck(k: MeshKit) -> void:
	var wood := Color("8a6a4a")
	k.box(Vector3(0, 0.12, 0), Vector3(6.0, 0.24, 3.4), Color("b8a888"))
	for i in 6:
		var x: float = -2.5 + 1.0 * float(i)
		var lean: float = 0.35 * float(i) / 5.0
		k.box(Vector3(x, 1.05, 0.9 - lean), Vector3(0.22, 1.9, 0.22), wood.darkened(0.05 * float(i % 2)))
		k.box(Vector3(x, 1.0, -0.9 + lean), Vector3(0.22, 1.7, 0.22), wood)
	k.box(Vector3(0, 0.25, 0), Vector3(5.6, 0.3, 1.4), wood.darkened(0.2))
	for i in 3:
		k.box(Vector3(-1.0 + 1.1 * float(i), 1.3, 1.0), Vector3(0.9, 0.16, 0.12), Color("6a4a30"))
	k.frustum(Vector3(-0.4, 0, 0), 0.2, 0.16, 3.4, 0.1, 5, Color("6a4a30"))
	k.quad(Vector3(-0.4, 3.2, 0), Vector3(-0.4, 2.0, 0), Vector3(1.0, 2.3, 0.5), Vector3(1.0, 3.0, 0.4), Color("f6ead7"))
	k.quad(Vector3(-0.4, 2.0, 0), Vector3(-0.4, 3.2, 0), Vector3(1.0, 3.0, 0.4), Vector3(1.0, 2.3, 0.5), Color("e8d8c0"))
	k.dome(Vector3(2.6, 0.3, -1.4), 0.5, 0.9, 1, 6, Color("ff8a3c"), Color("ffd0a0"))

static func _hut(k: MeshKit) -> void:
	k.box(Vector3(0, 0.12, 0), Vector3(4.4, 0.24, 4.0), Color("6a5a4a"))
	k.frustum(Vector3(0, 0.24, 0), 0.0, 1.9, 2.2, 1.6, 7, Color("c8a878"), Color("d8b888"))
	k.pyramid(Vector3(0.1, 2.4, 0), 2.1, 2.1, 1.7, Color("5a8a4a"), Color("7aaa5a"))
	k.box(Vector3(0, 0.95, -1.8), Vector3(0.9, 1.5, 0.12), Color("5a3a22"))
	k.box(Vector3(-1.1, 1.4, -1.7), Vector3(0.55, 0.55, 0.1), Color("ffd24a"), Color("fff7c2"))
	k.frustum(Vector3(0.9, 2.4, 0.5), 0.0, 0.34, 1.9, 0.27, 6, Color("8a6a5a"), Color("5a4a40"))
	k.dome(Vector3(0.9, 4.3, 0.5), 0.5, 0.9, 2, 6, Color("d8d4e4"), Color("ffffff"))
	k.dome(Vector3(1.3, 5.0, 0.4), 0.4, 0.9, 1, 6, Color("e8e4f4"), Color("ffffff"))
	k.frustum(Vector3(-2.3, 0, -1.2), 0.0, 0.1, 1.8, 0.08, 5, Color("6a4a30"))
	k.dome(Vector3(-2.3, 1.7, -1.2), 0.3, 1.3, 1, 6, Color("ff7a8a"), Color("ffd0d8"))
	k.box(Vector3(-1.6, 0.4, 1.9), Vector3(0.9, 0.8, 0.9), Color("b8884a"), Color("d8a86a"))

static func _spire(k: MeshKit) -> void:
	k.blob(Vector3(0, 0.5, 0), Vector3(2.8, 1.0, 2.4), 7, Color("c8b8cc"), Color("e8dcec"))
	k.frustum(Vector3(0, 0.6, 0), 0.0, 0.9, 6.2, 0.0, 6, Color("d8fff6"), Color("ffffff"), false)
	k.frustum(Vector3(1.0, 0.6, 0.4), 0.0, 0.55, 3.8, 0.0, 5, Color("b6f3ff"), Color("ffffff"), false, false, 0.4)
	k.frustum(Vector3(-0.9, 0.6, -0.5), 0.0, 0.5, 3.0, 0.0, 5, Color("ffd6f0"), Color("ffffff"), false, false, 0.2)
	k.frustum(Vector3(0.1, 0.6, -1.3), 0.0, 0.35, 1.9, 0.0, 4, Color("fff7c2"), Color("ffffff"), false, false, 0.7)
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + 0.6
		k.box(Vector3(cos(a) * 2.1, 0.3, sin(a) * 2.1), Vector3(0.6, 0.6, 0.6), Color("a898ac"), Color("cfc0d4"))

## A tall thin glowing needle so POIs can be spotted from across a hex or two. "on" = gold and high, "off" (claimed this week) = grey and short.
static func _beacon(k: MeshKit, col: Color, tip: Color, h: float) -> void:
	k.frustum(Vector3.ZERO, 0.0, 0.16, h, 0.0, 5, col, tip, false)
	k.dome(Vector3(0, h, 0), 0.34, 1.3, 1, 6, tip, col)

## Guardian arenas: a ring of six standing stones (the boundary of the fight) around the silhouette of the guardian that sleeps there, 4.5-7.5 m tall so
## the shape reads from a long way off. Each stone glows in the guardian's colour.
static func _arena(k: MeshKit, prop: String) -> void:
	var glow: Color = ACCENT[prop]
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + 0.3
		var h: float = 1.5 + 0.35 * float(i % 3)
		k.frustum(Vector3(cos(a) * 3.6, 0, sin(a) * 3.6), 0.0, 0.5, h, 0.32, 5, Color("8f7f9a"), Color("c5b4c8"), true, false, a)
		k.dome(Vector3(cos(a) * 3.6, h * 0.62, sin(a) * 3.6 - 0.3), 0.14, 1.0, 1, 5, glow, glow.lightened(0.5))
	match prop:
		"arena_meadow":
			k.dome(Vector3(0, 0.1, 0), 1.9, 1.0, 3, 9, Color("f08a2a"), Color("c8641a"))
			for i in 5:
				var a2: float = TAU * float(i) / 5.0
				k.box(Vector3(cos(a2) * 1.65, 1.2, sin(a2) * 1.65), Vector3(0.2, 1.6, 0.2), Color("5fa83a"))
			k.frustum(Vector3(0, 2.0, 0), 0.0, 0.26, 1.0, 0.18, 5, Color("6a8a2a"))
			for i in 4:
				var a3: float = TAU * float(i) / 4.0
				k.pyramid(Vector3(cos(a3) * 0.5, 3.0, sin(a3) * 0.5), 0.3, 0.12, 1.4, Color("5fa83a"), Color("a8e060"))
			for i in 3:
				k.dome(Vector3(-2.3 + 2.3 * float(i), 0.0, 1.8), 0.6, 0.9, 2, 7, Color("e8a21a"), Color("c8741a"))
		"arena_shore":
			for s in [-1.0, 1.0]:
				k.frustum(Vector3(1.5 * s, 0.0, 0), 0.0, 0.7, 4.2, 0.4, 6, Color("ff6a5a"), Color("ffb0a0"))
				k.pyramid(Vector3(1.0 * s, 4.2, 0), 0.5, 0.4, -1.6, Color("ff8a7a"))
				k.pyramid(Vector3(0.35 * s, 4.4, 0), 0.5, 0.4, 1.4, Color("ff8a7a"), Color("ffffff"))
			k.dome(Vector3(0, 0.0, -0.4), 1.7, 0.7, 2, 9, Color("2fb8a8"), Color("1a7a70"))
			for i in 6:
				var a4: float = TAU * float(i) / 6.0
				k.pyramid(Vector3(cos(a4) * 0.8, 1.2, sin(a4) * 0.8 - 0.4), 0.2, 0.2, 1.2 + 0.3 * float(i % 2), Color("ff6a5a"), Color("fff0d0"))
		"arena_fungal_grove":
			k.frustum(Vector3.ZERO, 0.0, 0.9, 4.3, 0.6, 8, Color("f3e4cf"), Color("fff6e6"), true, true)
			k.dome(Vector3(0, 4.2, 0), 2.8, 0.7, 3, 10, Color("a63ad8"), Color("6a1a98"))
			for i in 7:
				var a5: float = TAU * float(i) / 7.0
				k.dome(Vector3(cos(a5) * 1.6, 5.4 - 0.3 * float(i % 3), sin(a5) * 1.6), 0.34, 0.5, 1, 6, [Color("b6ff6a"), Color("ffe84a"), Color("ff2fb5")][i % 3], Color("ffffff"))
			for i in 4:
				k.dome(Vector3(-2.2 + 1.5 * float(i), 0.0, 2.0), 0.5, 0.8, 1, 6, Color("d8a8ff"), Color("fff0f8"))
		"arena_ruins":
			for s in [-1.0, 1.0]:
				k.box(Vector3(2.1 * s, 2.6, 0), Vector3(1.0, 5.2, 1.0), Color("b9a6b5"), Color("dccfdc"))
			k.box(Vector3(0, 5.6, 0), Vector3(5.6, 0.9, 1.2), Color("a898ac"), Color("cfc0d4"))
			k.box(Vector3(0, 2.6, 0.1), Vector3(2.4, 4.0, 1.2), Color("7a6a8a"), Color("9a8aaa"))
			k.box(Vector3(0, 5.0, 0.1), Vector3(1.4, 1.2, 1.1), Color("8a7a9a"), Color("b0a0c0"))
			k.box(Vector3(-0.3, 5.1, -0.55), Vector3(0.3, 0.2, 0.06), Color("c47bff"))
			k.box(Vector3(0.3, 5.1, -0.55), Vector3(0.3, 0.2, 0.06), Color("c47bff"))
			k.box(Vector3(0, 3.0, -0.55), Vector3(1.4, 0.12, 0.06), Color("c47bff"))
		"arena_salt_flats":
			k.frustum(Vector3.ZERO, 0.02, 3.0, 0.1, 3.0, 12, Color("cfe8ff"), Color("e8f6ff"))
			for s in [-1.0, 1.0]:
				k.frustum(Vector3(0.5 * s, 0.1, 0), 0.0, 0.14, 4.4, 0.08, 4, Color("e8a21a"))
			k.dome(Vector3(0, 4.5, 0.3), 1.0, 0.8, 2, 8, Color("e8f4ff"), Color("7ac8f0"))
			k.frustum(Vector3(0, 4.9, -0.4), 0.0, 0.26, 2.0, 0.16, 6, Color("e8f4ff"))
			k.dome(Vector3(0, 6.7, -0.7), 0.4, 0.9, 1, 7, Color("e8f4ff"))
			k.pyramid(Vector3(0, 6.65, -1.1), 0.12, 0.12, -1.2, Color("ffb020"))
			for i in 3:
				k.pyramid(Vector3(0, 7.0, -0.5 + 0.2 * float(i)), 0.05, 0.1, 0.7, Color("7ac8f0"))
		"arena_highlands":
			k.blob(Vector3(0, 0.8, 0), Vector3(2.6, 1.5, 2.2), 19, Color("8a8a9a"), Color("aab0c0"))
			for s in [-1.0, 1.0]:
				k.frustum(Vector3(1.2 * s, 1.3, 0), 0.0, 0.5, 2.4, 0.38, 6, Color("f0dca0"))
				k.frustum(Vector3(1.8 * s, 3.6, 0), 0.0, 0.4, 1.8, 0.24, 6, Color("e8c880"), Color("f0dca0"))
				k.pyramid(Vector3(2.4 * s, 5.3, 0), 0.26, 0.26, 1.6, Color("ffe84a"), Color("ffffff"))
			for i in 4:
				k.pyramid(Vector3(-1.2 + 0.8 * float(i), 2.2, 0.0), 0.2, 0.2, 0.9, Color("ffe84a"))
		"arena_bog":
			k.blob(Vector3(0, 0.9, 0), Vector3(3.4, 1.8, 3.0), 31, Color("6a8a3a"), Color("8ab83a"))
			for s in [-1.0, 1.0]:
				k.dome(Vector3(1.0 * s, 2.0, -0.6), 0.55, 1.0, 2, 7, Color("7a9a3a"), Color("5a7a2a"))
				k.dome(Vector3(1.0 * s, 2.4, -0.95), 0.24, 0.9, 1, 6, Color("ffe82e"))
			for i in 6:
				var x: float = -2.6 + 1.0 * float(i)
				k.frustum(Vector3(x, 0, 2.2 + 0.4 * float(i % 2)), 0.0, 0.07, 3.0 + 0.7 * float(i % 3), 0.04, 4, Color("5a7a2a"))
				k.dome(Vector3(x, 3.0 + 0.7 * float(i % 3), 2.2 + 0.4 * float(i % 2)), 0.16, 1.3, 1, 5, Color("c8845a"))
