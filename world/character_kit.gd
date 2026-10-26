class_name CharacterKit
extends RefCounted
## Original procedural characters: 14 playable class looks (palette + hat + hand prop + back item), 6 enemy archetypes,
## villagers, merchant and AI raiders. All built from MeshKit primitives into a CharacterRig (5-6 draw calls each).
## Consistent scale: humanoid body ~1.9 m to the top of the head, hats/props extend the silhouette above/beside it.

const SKINS: Array[Color] = [Color("ffd9b8"), Color("e8b890"), Color("c98a5e"), Color("8a5a3a"), Color("f2c29c")]

const CLASS_LOOKS: Dictionary = {
	"lfg:class/judd": {"tunic": Color("e8b040"), "accent": Color("f5dc80"), "pants": Color("6a4a2a"), "skin": 1, "hat": "wide", "prop": "staff", "back": "none", "width": 1.12},
	"lfg:class/mira": {"tunic": Color("7a3fd0"), "accent": Color("3bf0c0"), "pants": Color("3a2a60"), "skin": 0, "hat": "witch", "prop": "flask", "back": "bottles", "width": 0.92},
	"lfg:class/bram": {"tunic": Color("b8402a"), "accent": Color("5b3a2a"), "pants": Color("4a3020"), "skin": 2, "hat": "horns", "prop": "club", "back": "pelt", "width": 1.2},
	"lfg:class/tavi": {"tunic": Color("6a7a8a"), "accent": Color("ffd02a"), "pants": Color("3a4250"), "skin": 3, "hat": "lamp_helm", "prop": "pickaxe", "back": "pack", "width": 1.1},
	"lfg:class/pip": {"tunic": Color("2fa8ff"), "accent": Color("ff5a2f"), "pants": Color("23406a"), "skin": 4, "hat": "feather_cap", "prop": "scroll", "back": "satchel", "width": 0.86},
	"lfg:class/oren": {"tunic": Color("fff2e0"), "accent": Color("e8453a"), "pants": Color("7a6a5a"), "skin": 2, "hat": "toque", "prop": "ladle", "back": "apron", "width": 1.15},
	"lfg:class/vex": {"tunic": Color("2a2236"), "accent": Color("ff2fb5"), "pants": Color("1a1424"), "skin": 0, "hat": "cowl", "prop": "dagger", "back": "cloak", "width": 0.84},
	"lfg:class/sable": {"tunic": Color("4d8a3a"), "accent": Color("c98a4a"), "pants": Color("5b4a2a"), "skin": 3, "hat": "ranger", "prop": "bow", "back": "quiver", "width": 0.95},
	"lfg:class/quill": {"tunic": Color("2f4fa8"), "accent": Color("f0e6c8"), "pants": Color("1f2a5a"), "skin": 4, "hat": "beret", "prop": "quill", "back": "scroll_case", "width": 0.9},
	"lfg:class/forge": {"tunic": Color("5a5a66"), "accent": Color("ff7a1a"), "pants": Color("2a2a30"), "skin": 2, "hat": "goggles", "prop": "hammer", "back": "leather_apron", "width": 1.25},
	"lfg:class/nyx": {"tunic": Color("1fb08a"), "accent": Color("ff2fb5"), "pants": Color("0f5a50"), "skin": 0, "hat": "mushroom", "prop": "spore_staff", "back": "spores", "width": 0.98},
	"lfg:class/rook": {"tunic": Color("a01830"), "accent": Color("ffd24a"), "pants": Color("4a1020"), "skin": 3, "hat": "crown", "prop": "banner", "back": "cape", "width": 1.12},
	"lfg:class/dune": {"tunic": Color("d8a050"), "accent": Color("2f9aa0"), "pants": Color("8a6a3a"), "skin": 1, "hat": "turban", "prop": "wrench", "back": "bigpack", "width": 1.0},
	"lfg:class/halo": {"tunic": Color("f4f0ff"), "accent": Color("ffe66a"), "pants": Color("b8a8e0"), "skin": 4, "hat": "halo", "prop": "lantern", "back": "wings", "width": 1.0},
}

const ENEMY_IDS: Array[String] = ["lfg:enemy/sporeling", "lfg:enemy/rootbrute", "lfg:enemy/thorn_slinger", "lfg:enemy/mire_leech", "lfg:enemy/gloomwing", "lfg:enemy/bulwark"]

static func class_ids() -> Array[String]:
	var out: Array[String] = []
	for k in CLASS_LOOKS.keys():
		out.append(String(k))
	return out

## Distinctness signature used by tests and the class-select screen.
static func look_signature(class_id: String) -> String:
	var l: Dictionary = CLASS_LOOKS.get(class_id, {})
	return "%s|%s|%s" % [l.get("hat", ""), l.get("prop", ""), l.get("back", "")]

# ---------------------------------------------------------------- public builders

static func build_class(class_id: String) -> CharacterRig:
	var look: Dictionary = CLASS_LOOKS.get(class_id, CLASS_LOOKS["lfg:class/judd"])
	var rig := CharacterRig.new()
	rig.look_id = class_id
	_humanoid(rig, look)
	return rig

static func build_enemy(archetype: String) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.look_id = archetype
	match archetype:
		"lfg:enemy/sporeling": _sporeling(rig)
		"lfg:enemy/rootbrute": _rootbrute(rig)
		"lfg:enemy/thorn_slinger": _thorn_slinger(rig)
		"lfg:enemy/mire_leech": _mire_leech(rig)
		"lfg:enemy/gloomwing": _gloomwing(rig)
		"lfg:enemy/bulwark": _bulwark(rig)
		_: _sporeling(rig)
	return rig

## kind: "villager" | "merchant" | "raider". `variant` picks palette/hat deterministically (holding id, faction id...).
static func build_npc(kind: String, variant: int = 0) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.look_id = "npc/" + kind
	var v: int = absi(variant)
	var look: Dictionary
	match kind:
		"merchant":
			look = {"tunic": Color("ff8a1a"), "accent": Color("ffe84a"), "pants": Color("6a2a5a"), "skin": v % 5, "hat": "merchant", "prop": "coin_pouch", "back": "trade_pack", "width": 1.25}
		"raider":
			var hue: float = float((v * 47) % 360) / 360.0
			look = {"tunic": Color.from_hsv(hue, 0.55, 0.45), "accent": Color.from_hsv(hue, 0.9, 1.0), "pants": Color("221a2a"), "skin": v % 5, "hat": "spike_helm", "prop": "sword", "back": "sash", "width": 1.1}
		_:
			var tunics: Array[Color] = [Color("c98a5a"), Color("8ab86a"), Color("d86a7a"), Color("7aa8d8")]
			var hats: Array[String] = ["straw", "none", "kerchief", "straw"]
			look = {"tunic": tunics[v % 4], "accent": Color("f0dca0") if v % 2 == 0 else Color("ffffff"), "pants": Color("6a5a48"), "skin": (v / 2) % 5, "hat": hats[v % 4], "prop": "none" if v % 3 != 0 else "hoe", "back": "none", "width": 0.95 + 0.05 * float(v % 3)}
	_humanoid(rig, look)
	return rig

# ---------------------------------------------------------------- humanoid

static func _humanoid(rig: CharacterRig, look: Dictionary) -> void:
	var tunic: Color = look["tunic"]
	var accent: Color = look["accent"]
	var pants: Color = look["pants"]
	var skin: Color = SKINS[int(look["skin"]) % SKINS.size()]
	var w: float = float(look["width"])
	var torso := MeshKit.new()
	torso.frustum(Vector3.ZERO, 0.45, 0.46 * w, 1.25, 0.34 * w, 7, tunic, tunic.lightened(0.15), true, true)
	torso.frustum(Vector3.ZERO, 0.78, 0.44 * w, 0.9, 0.43 * w, 7, accent.darkened(0.35), accent.darkened(0.35), false)
	# head
	torso.dome(Vector3(0, 1.25, 0), 0.4, 1.0, 2, 8, skin, skin)
	torso.dome(Vector3(0, 1.25, 0), 0.4, -0.8, 2, 8, skin.darkened(0.06), skin.darkened(0.06))
	torso.box(Vector3(-0.15, 1.3, -0.37), Vector3(0.1, 0.14, 0.06), Color("2a1838"))
	torso.box(Vector3(0.15, 1.3, -0.37), Vector3(0.1, 0.14, 0.06), Color("2a1838"))
	_hat(torso, String(look["hat"]), accent, tunic, skin)
	_back(torso, String(look["back"]), accent, tunic, w)
	rig.add_part(torso, Vector3.ZERO, "body")
	for side in [-1.0, 1.0]:
		var lk := MeshKit.new()
		lk.box(Vector3(0, -0.2, 0), Vector3(0.2, 0.42, 0.22), pants)
		lk.box(Vector3(0, -0.43, -0.04), Vector3(0.22, 0.12, 0.3), pants.darkened(0.5))
		rig.add_part(lk, Vector3(0.2 * side, 0.46, 0), "leg", side)
		var ak := MeshKit.new()
		ak.box(Vector3(0, -0.25, 0), Vector3(0.16, 0.5, 0.16), tunic.darkened(0.15))
		ak.box(Vector3(0, -0.52, 0), Vector3(0.18, 0.12, 0.18), skin)
		if side > 0.0:
			_prop(ak, String(look["prop"]), accent, tunic)
		rig.add_part(ak, Vector3(0.5 * w * side + 0.0, 1.12, 0), "arm", side)
	rig.nominal_height = 2.0

static func _hat(k: MeshKit, hat: String, accent: Color, tunic: Color, skin: Color) -> void:
	match hat:
		"none":
			k.dome(Vector3(0, 1.5, 0), 0.43, 0.55, 2, 8, tunic.darkened(0.5), tunic.darkened(0.5)) # hair
		"straw":
			k.frustum(Vector3(0, 1.5, 0), 0.0, 0.85, 0.1, 0.8, 10, accent, accent.lightened(0.1))
			k.dome(Vector3(0, 1.55, 0), 0.42, 0.7, 2, 8, accent.darkened(0.1), accent)
		"wide":
			k.frustum(Vector3(0, 1.5, 0), 0.0, 1.05, 0.12, 0.95, 10, accent.darkened(0.1), accent)
			k.dome(Vector3(0, 1.58, 0), 0.45, 0.85, 2, 8, accent, accent.lightened(0.1))
			k.frustum(Vector3(0, 1.6, 0), 0.0, 0.47, 0.12, 0.47, 8, Color("8a5a3a"), Color("8a5a3a"), false)
		"witch":
			k.frustum(Vector3(0, 1.5, 0), 0.0, 0.7, 0.08, 0.6, 9, tunic.darkened(0.2), tunic)
			k.frustum(Vector3(0, 1.55, 0), 0.0, 0.5, 1.15, 0.04, 8, tunic, tunic.lightened(0.1), false)
			k.frustum(Vector3(0, 1.58, 0), 0.0, 0.52, 0.16, 0.52, 8, accent, accent, false)
			k.dome(Vector3(0.05, 2.7, 0), 0.12, 1.0, 1, 5, accent)
		"horns":
			k.dome(Vector3(0, 1.45, 0), 0.5, 0.8, 2, 8, Color("8a8070"), Color("a89a88"))
			for s in [-1.0, 1.0]:
				k.frustum(Vector3(s * 0.46, 1.62, 0), 0.0, 0.14, 0.4, 0.1, 5, Color("f0e6c8"))
				k.frustum(Vector3(s * 0.62, 2.0, 0), 0.0, 0.1, 0.45, 0.02, 5, Color("f0e6c8"))
		"lamp_helm":
			k.dome(Vector3(0, 1.48, 0), 0.5, 0.85, 2, 8, accent, accent.lightened(0.15))
			k.box(Vector3(0, 1.84, -0.28), Vector3(0.3, 0.26, 0.24), Color("fff7a0"), Color("ffffff"))
			k.box(Vector3(0, 1.66, -0.22), Vector3(0.16, 0.08, 0.2), Color("3a3a42"))
		"feather_cap":
			k.dome(Vector3(0, 1.5, 0), 0.45, 0.7, 2, 8, tunic.lightened(0.1), tunic)
			k.box(Vector3(0, 1.52, -0.42), Vector3(0.5, 0.06, 0.3), accent)
			k.pyramid(Vector3(0.32, 1.7, 0.05), 0.07, 0.22, 0.95, accent, accent.lightened(0.3))
		"toque":
			k.frustum(Vector3(0, 1.52, 0), 0.0, 0.4, 0.45, 0.46, 8, Color("ffffff"), Color("f4f0ff"), false)
			k.dome(Vector3(0, 1.95, 0), 0.52, 0.7, 2, 8, Color("ffffff"), Color("e8e4f4"))
		"cowl":
			k.dome(Vector3(0, 1.25, 0), 0.47, 1.05, 2, 8, tunic, tunic.lightened(0.05))
			k.box(Vector3(0, 1.3, -0.38), Vector3(0.62, 0.17, 0.06), accent)
			k.pyramid(Vector3(0, 1.62, 0.2), 0.3, 0.3, 0.5, tunic.darkened(0.1), tunic)
		"ranger":
			k.frustum(Vector3(0, 1.5, 0), 0.0, 0.7, 0.07, 0.62, 9, tunic.darkened(0.1), tunic)
			k.frustum(Vector3(0, 1.55, 0), 0.0, 0.45, 0.65, 0.12, 7, tunic, tunic.lightened(0.15), false)
			k.pyramid(Vector3(0.38, 1.8, 0.0), 0.05, 0.2, 0.8, accent, Color("ffffff"))
		"beret":
			k.dome(Vector3(0, 1.52, 0), 0.62, 0.38, 2, 9, accent, accent.darkened(0.15))
			k.dome(Vector3(0.0, 1.75, 0), 0.08, 1.0, 1, 4, accent.darkened(0.3))
		"goggles":
			k.dome(Vector3(0, 1.48, 0), 0.45, 0.6, 2, 8, accent.darkened(0.25), accent.darkened(0.1))
			k.box(Vector3(0, 1.5, 0), Vector3(0.9, 0.12, 0.88), Color("3a2a22"))
			k.box(Vector3(-0.19, 1.62, -0.36), Vector3(0.24, 0.22, 0.2), accent, accent.lightened(0.3))
			k.box(Vector3(0.19, 1.62, -0.36), Vector3(0.24, 0.22, 0.2), accent, accent.lightened(0.3))
		"mushroom":
			k.dome(Vector3(0, 1.5, 0), 0.95, 0.7, 2, 9, accent, accent.darkened(0.25))
			k.dome(Vector3(0.28, 2.1, -0.1), 0.15, 0.5, 1, 5, Color("fff7c0"))
			k.dome(Vector3(-0.35, 2.0, 0.2), 0.12, 0.5, 1, 5, Color("fff7c0"))
			k.dome(Vector3(0.0, 2.12, 0.35), 0.1, 0.5, 1, 5, Color("fff7c0"))
		"crown":
			k.frustum(Vector3(0, 1.55, 0), 0.0, 0.44, 0.22, 0.44, 8, accent, accent.lightened(0.2), false)
			for i in 5:
				var a: float = TAU * float(i) / 5.0
				k.pyramid(Vector3(cos(a) * 0.36, 1.77, sin(a) * 0.36), 0.08, 0.08, 0.28, accent.lightened(0.15), accent)
			k.pyramid(Vector3(0, 1.8, 0.25), 0.1, 0.1, 0.9, Color("ff3a5a"), Color("ff8a9a"))
		"turban":
			k.dome(Vector3(0, 1.5, 0), 0.55, 0.95, 3, 9, tunic.lightened(0.1), tunic)
			k.frustum(Vector3(0, 1.52, 0), 0.0, 0.57, 0.18, 0.57, 9, accent, accent, false)
			k.dome(Vector3(0, 1.72, -0.5), 0.1, 1.0, 1, 5, Color("ff3a5a"))
			k.box(Vector3(0, 1.7, -0.4), Vector3(0.62, 0.14, 0.12), Color("3a2a22"))
		"halo":
			k.dome(Vector3(0, 1.45, 0), 0.46, 0.55, 2, 8, Color("ffffff"), Color("e8e4f4"))
			k.ring(Vector3(0, 2.25, 0), 0.34, 0.52, 0.09, 12, accent)
		"merchant":
			k.frustum(Vector3(0, 1.5, 0), 0.0, 0.9, 0.1, 0.8, 10, accent.darkened(0.15), accent)
			k.dome(Vector3(0, 1.58, 0), 0.46, 1.1, 2, 8, accent, accent.lightened(0.1))
			k.pyramid(Vector3(0.45, 1.9, 0.0), 0.06, 0.24, 0.9, Color("ff2fb5"), Color("ff8ad8"))
		"spike_helm":
			k.dome(Vector3(0, 1.45, 0), 0.5, 0.9, 2, 8, Color("3a3a48"), Color("5a5a6a"))
			for i in 5:
				var a2: float = TAU * float(i) / 5.0
				k.pyramid(Vector3(cos(a2) * 0.3, 1.8, sin(a2) * 0.3), 0.07, 0.07, 0.38, accent, accent.lightened(0.2))
		"kerchief":
			k.dome(Vector3(0, 1.45, 0), 0.45, 0.6, 2, 8, accent, accent.darkened(0.1))
			k.pyramid(Vector3(0, 1.4, 0.38), 0.18, 0.1, 0.34, accent.darkened(0.15))

static func _back(k: MeshKit, back: String, accent: Color, tunic: Color, w: float) -> void:
	var bz: float = 0.42 * w
	match back:
		"none":
			pass
		"bottles":
			for i in 3:
				k.frustum(Vector3(-0.3 + 0.3 * float(i), 0.8, -0.38), 0.0, 0.08, 0.32, 0.05, 5, accent, accent.lightened(0.3))
		"pelt":
			k.box(Vector3(0, 1.0, bz), Vector3(0.9 * w, 0.8, 0.14), accent, accent.lightened(0.1))
			k.box(Vector3(0, 1.5, 0.3), Vector3(0.9 * w, 0.18, 0.5), accent.lightened(0.15))
		"pack":
			k.box(Vector3(0, 0.95, bz + 0.05), Vector3(0.7, 0.8, 0.36), Color("8a8a96"), Color("a8a8b4"))
			k.box(Vector3(0, 1.45, bz + 0.05), Vector3(0.6, 0.22, 0.3), accent)
		"satchel":
			k.box(Vector3(0.45 * w, 0.75, 0.05), Vector3(0.18, 0.5, 0.6), accent, accent.lightened(0.2))
			k.box(Vector3(0, 1.0, 0.0), Vector3(0.1, 0.1, 0.1), accent) # strap anchor
		"apron":
			k.box(Vector3(0, 0.7, -bz + 0.02), Vector3(0.7 * w, 0.62, 0.08), Color("ffffff"), Color("ffffff"))
			k.box(Vector3(0, 0.7, -bz - 0.02), Vector3(0.3, 0.28, 0.05), accent)
		"cloak":
			k.box(Vector3(0, 0.85, bz), Vector3(0.9 * w, 1.25, 0.1), tunic.lightened(0.05), tunic)
			k.box(Vector3(0, 0.25, bz + 0.03), Vector3(0.7 * w, 0.2, 0.08), accent)
		"quiver":
			k.frustum(Vector3(0.2, 0.7, bz), 0.0, 0.14, 0.9, 0.12, 6, accent.darkened(0.2), accent)
			for i in 3:
				k.pyramid(Vector3(0.12 + 0.08 * float(i), 1.55, bz), 0.04, 0.04, 0.3, Color("ffffff"), Color("f0e6c8"))
		"scroll_case":
			k.frustum(Vector3(-0.15, 0.55, bz + 0.1), 0.0, 0.1, 1.2, 0.1, 6, accent, accent.lightened(0.2))
			k.frustum(Vector3(0.05, 0.55, bz + 0.1), 0.0, 0.1, 1.0, 0.1, 6, accent.darkened(0.1), accent)
		"leather_apron":
			k.box(Vector3(0, 0.75, -bz + 0.02), Vector3(0.78 * w, 0.8, 0.09), Color("7a4a2a"), Color("8a5a34"))
			k.box(Vector3(0, 1.25, -bz + 0.0), Vector3(0.5, 0.12, 0.1), Color("5a3a22"))
		"spores":
			for i in 4:
				var a: float = float(i) * 1.7
				k.dome(Vector3(cos(a) * 0.3, 1.0 + 0.18 * float(i), bz + 0.1), 0.2 - 0.02 * float(i), 0.7, 1, 6, accent, accent.darkened(0.3))
		"cape":
			k.box(Vector3(0, 0.75, bz + 0.02), Vector3(1.0 * w, 1.55, 0.1), accent.darkened(0.55), tunic)
			k.box(Vector3(0, 0.0, bz + 0.05), Vector3(1.0 * w, 0.1, 0.12), accent)
			k.box(Vector3(0, 1.45, 0.0), Vector3(1.02 * w, 0.14, 0.9), accent)
		"bigpack":
			k.box(Vector3(0, 1.0, bz + 0.15), Vector3(0.95, 1.05, 0.5), accent.darkened(0.2), accent)
			k.frustum(Vector3(-0.3, 1.5, bz + 0.15), 0.0, 0.07, 0.8, 0.07, 5, Color("8a8a96"))
			k.frustum(Vector3(0.3, 1.5, bz + 0.15), 0.0, 0.07, 0.6, 0.07, 5, Color("8a8a96"))
		"wings":
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.55, 1.3, bz + 0.05), Vector3(0.7, 0.9, 0.06), Color("ffffff"), Color("fff7d0"))
				k.box(Vector3(s * 0.95, 1.6, bz + 0.05), Vector3(0.35, 0.7, 0.05), Color("f4f0ff"))
		"trade_pack":
			k.box(Vector3(0, 1.0, bz + 0.2), Vector3(1.1, 1.0, 0.6), Color("ff2fb5"), Color("ff8ad8"))
			k.box(Vector3(0, 1.62, bz + 0.2), Vector3(0.8, 0.3, 0.5), accent)
			k.box(Vector3(0.0, 1.0, bz + 0.52), Vector3(0.9, 0.15, 0.05), Color("19e0c8"))
		"sash":
			k.box(Vector3(0, 0.95, 0), Vector3(0.9, 0.18, 0.9), accent)
			k.box(Vector3(0, 0.95, bz), Vector3(0.6, 0.9, 0.06), accent.darkened(0.2))

## Prop is built in the right arm's local space; the hand is at about (0,-0.52,0).
static func _prop(k: MeshKit, prop: String, accent: Color, tunic: Color) -> void:
	var wood := Color("8a5a3a")
	match prop:
		"none":
			pass
		"hoe":
			k.frustum(Vector3(0, -0.9, 0), 0.0, 0.05, 1.7, 0.05, 5, wood)
			k.box(Vector3(0, 0.78, -0.2), Vector3(0.1, 0.1, 0.5), Color("8a8a96"))
		"staff":
			k.frustum(Vector3(0, -0.95, 0), 0.0, 0.06, 2.4, 0.06, 5, wood)
			k.dome(Vector3(0, 1.45, 0), 0.14, 1.0, 1, 5, accent)
		"flask":
			k.frustum(Vector3(0, -0.5, -0.22), 0.0, 0.2, 0.25, 0.16, 7, accent, accent.lightened(0.4))
			k.frustum(Vector3(0, -0.25, -0.22), 0.0, 0.07, 0.25, 0.07, 6, Color("d0f0e8"))
			k.dome(Vector3(0, 0.0, -0.22), 0.09, 1.0, 1, 5, Color("5a3a22"))
		"club":
			k.frustum(Vector3(0, -0.75, -0.1), 0.0, 0.08, 1.0, 0.24, 6, wood, wood.lightened(0.15))
			for i in 4:
				var a: float = TAU * float(i) / 4.0
				k.pyramid(Vector3(cos(a) * 0.24, 0.1 + 0.1 * float(i % 2), -0.1 + sin(a) * 0.24), 0.05, 0.05, 0.16, Color("f0e6c8"))
		"pickaxe":
			k.frustum(Vector3(0, -0.8, -0.05), 0.0, 0.055, 1.6, 0.055, 5, wood)
			k.box(Vector3(0, 0.8, -0.05), Vector3(0.12, 0.12, 1.0), Color("8a8a96"), Color("b8b8c4"))
			k.pyramid(Vector3(0, 0.8, -0.65), 0.06, 0.18, 0.0, Color("b8b8c4"))
		"scroll":
			k.frustum(Vector3(0, -0.5, -0.2), 0.0, 0.1, 0.5, 0.1, 6, Color("f0e6c8"), Color("ffffff"))
			k.box(Vector3(0, -0.5, -0.2), Vector3(0.24, 0.1, 0.24), accent)
		"ladle":
			k.frustum(Vector3(0, -0.6, -0.1), 0.0, 0.04, 1.3, 0.04, 5, Color("b8b8c4"))
			k.dome(Vector3(0, 0.7, -0.1), 0.2, 0.6, 1, 6, Color("8a8a96"), Color("d0d0dc"))
		"dagger":
			k.box(Vector3(0, -0.52, -0.42), Vector3(0.06, 0.1, 0.7), Color("e8e8f4"), Color("ffffff"))
			k.box(Vector3(0, -0.52, -0.06), Vector3(0.22, 0.06, 0.06), accent)
		"bow":
			k.box(Vector3(0, -0.5, -0.3), Vector3(0.07, 1.5, 0.07), wood)
			k.box(Vector3(0, 0.25, -0.15), Vector3(0.07, 0.3, 0.07), wood)
			k.box(Vector3(0, -1.25, -0.15), Vector3(0.07, 0.3, 0.07), wood)
			k.box(Vector3(0, -0.5, 0.0), Vector3(0.02, 1.7, 0.02), Color("f0e6c8"))
		"quill":
			k.pyramid(Vector3(0, -0.5, -0.2), 0.06, 0.2, 1.1, Color("ffffff"), accent)
			k.dome(Vector3(0, -0.5, -0.2), 0.08, 0.5, 1, 5, Color("1a1a2a"))
		"hammer":
			k.frustum(Vector3(0, -0.9, -0.05), 0.0, 0.06, 1.7, 0.06, 5, wood)
			k.box(Vector3(0, 0.85, -0.05), Vector3(0.6, 0.42, 0.42), Color("6a6a76"), Color("9a9aa8"))
			k.box(Vector3(0, 0.85, -0.3), Vector3(0.5, 0.3, 0.08), accent)
		"spore_staff":
			k.frustum(Vector3(0, -0.95, 0), 0.0, 0.06, 2.0, 0.06, 5, Color("e8d8c0"))
			k.dome(Vector3(0, 1.0, 0), 0.38, 0.8, 2, 7, accent, accent.darkened(0.3))
			k.dome(Vector3(0.1, 1.28, 0.05), 0.08, 0.6, 1, 4, Color("fff7c0"))
		"banner":
			k.frustum(Vector3(0, -1.0, 0), 0.0, 0.06, 3.8, 0.06, 5, wood)
			k.box(Vector3(0.45, 2.3, 0), Vector3(0.85, 0.9, 0.05), tunic, tunic.lightened(0.1))
			k.box(Vector3(0.45, 2.3, 0.03), Vector3(0.4, 0.4, 0.05), accent)
			k.pyramid(Vector3(0, 2.8, 0), 0.1, 0.1, 0.4, accent)
		"wrench":
			k.frustum(Vector3(0, -0.7, -0.05), 0.0, 0.06, 1.2, 0.06, 5, Color("8a8a96"))
			k.box(Vector3(0, 0.5, -0.05), Vector3(0.4, 0.2, 0.1), Color("b8b8c4"))
			k.box(Vector3(-0.16, 0.7, -0.05), Vector3(0.1, 0.25, 0.1), Color("b8b8c4"))
			k.box(Vector3(0.16, 0.7, -0.05), Vector3(0.1, 0.25, 0.1), Color("b8b8c4"))
			k.box(Vector3(0, 0.1, -0.05), Vector3(0.1, 0.1, 0.1), accent)
		"lantern":
			k.frustum(Vector3(0, -0.95, 0), 0.0, 0.05, 2.0, 0.05, 5, Color("e8e0f4"))
			k.box(Vector3(0, 0.95, 0), Vector3(0.34, 0.4, 0.34), accent, Color("ffffff"))
			k.pyramid(Vector3(0, 1.15, 0), 0.22, 0.22, 0.2, Color("b8a8e0"))
		"coin_pouch":
			k.dome(Vector3(0, -0.55, -0.22), 0.24, 0.9, 2, 7, Color("c98a3a"), Color("e0a85a"))
			k.dome(Vector3(0, -0.5, -0.22), 0.12, 1.0, 1, 5, accent)
		"sword":
			k.box(Vector3(0, -0.52, -0.55), Vector3(0.07, 0.12, 0.95), Color("c8c8d8"), Color("ffffff"))
			k.box(Vector3(0, -0.52, -0.08), Vector3(0.3, 0.07, 0.08), accent)

# ---------------------------------------------------------------- enemies

static func _sporeling(rig: CharacterRig) -> void:
	var cap := Color("ff2fb5")
	var b := MeshKit.new()
	b.frustum(Vector3.ZERO, 0.25, 0.36, 0.85, 0.3, 7, Color("f6ead7"), Color("fff6e6"), false)
	b.dome(Vector3(0, 0.7, 0), 0.8, 0.75, 2, 9, cap, cap.darkened(0.3))
	b.dome(Vector3(0.3, 1.25, -0.1), 0.14, 0.5, 1, 5, Color("fff7c0"))
	b.dome(Vector3(-0.3, 1.15, 0.2), 0.11, 0.5, 1, 5, Color("fff7c0"))
	b.box(Vector3(-0.13, 0.55, -0.31), Vector3(0.1, 0.16, 0.05), Color("2a1838"))
	b.box(Vector3(0.13, 0.55, -0.31), Vector3(0.1, 0.16, 0.05), Color("2a1838"))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.1, 0), Vector3(0.16, 0.26, 0.18), Color("f6ead7"))
		rig.add_part(l, Vector3(0.17 * s, 0.26, 0), "leg", s)
	rig.nominal_height = 1.3

static func _rootbrute(rig: CharacterRig) -> void:
	var bark := Color("6a4a30")
	var moss := Color("4fb85a")
	var b := MeshKit.new()
	b.frustum(Vector3.ZERO, 0.6, 0.9, 2.4, 0.75, 7, bark, bark.lightened(0.1), true, true)
	b.dome(Vector3(0, 2.4, 0), 0.9, 0.55, 2, 8, moss, moss.darkened(0.25))
	b.box(Vector3(-0.28, 2.0, -0.7), Vector3(0.22, 0.2, 0.1), Color("ffe82e"))
	b.box(Vector3(0.28, 2.0, -0.7), Vector3(0.22, 0.2, 0.1), Color("ffe82e"))
	b.pyramid(Vector3(0, 2.0, -0.78), 0.3, 0.05, -0.3, bark.darkened(0.3))
	for i in 3:
		b.pyramid(Vector3(-0.6 + 0.6 * float(i), 2.85, 0.1), 0.12, 0.12, 0.5, moss.lightened(0.1))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.frustum(Vector3(0, -0.2, 0), 0.0, 0.34, 0.9, 0.28, 6, bark.darkened(0.15))
		rig.add_part(l, Vector3(0.5 * s, 0.7, 0), "leg", s)
		var a := MeshKit.new()
		a.frustum(Vector3(0, -1.2, 0), 0.0, 0.2, 1.4, 0.33, 6, bark, bark.lightened(0.1))
		a.dome(Vector3(0, -1.3, 0), 0.4, -0.7, 1, 6, bark.darkened(0.2))
		rig.add_part(a, Vector3(1.05 * s, 2.0, 0), "arm", s)
	rig.nominal_height = 3.4

static func _thorn_slinger(rig: CharacterRig) -> void:
	var skin := Color("c8b070")
	var thorn := Color("f0e0b0")
	var b := MeshKit.new()
	b.frustum(Vector3.ZERO, 0.4, 0.3, 1.4, 0.22, 6, skin.darkened(0.2), skin, true, true)
	b.dome(Vector3(0, 1.4, 0), 0.34, 1.1, 2, 7, skin, skin)
	b.box(Vector3(-0.12, 1.5, -0.3), Vector3(0.1, 0.1, 0.05), Color("ff3a2a"))
	b.box(Vector3(0.12, 1.5, -0.3), Vector3(0.1, 0.1, 0.05), Color("ff3a2a"))
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		b.pyramid(Vector3(cos(a) * 0.22, 1.72, sin(a) * 0.22), 0.05, 0.05, 0.45, thorn)
	for i in 4:
		b.pyramid(Vector3(0.0, 0.7 + 0.18 * float(i), 0.3), 0.07, 0.07, 0.35, thorn)
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.2, 0), Vector3(0.14, 0.5, 0.14), skin.darkened(0.3))
		rig.add_part(l, Vector3(0.14 * s, 0.5, 0), "leg", s)
		var a2 := MeshKit.new()
		a2.box(Vector3(0, -0.3, 0), Vector3(0.1, 0.65, 0.1), skin)
		if s > 0.0:
			a2.box(Vector3(0, -0.6, -0.3), Vector3(0.1, 0.1, 0.8), Color("6a4a30"))
			a2.pyramid(Vector3(0, -0.6, -0.75), 0.08, 0.08, 0.0, thorn)
			a2.box(Vector3(0, -0.6, -0.4), Vector3(0.3, 0.06, 0.06), Color("6a4a30"))
		rig.add_part(a2, Vector3(0.34 * s, 1.2, 0), "arm", s)
	rig.nominal_height = 2.3

static func _mire_leech(rig: CharacterRig) -> void:
	var skin := Color("2a6a6a")
	var belly := Color("c8e84a")
	var head := MeshKit.new()
	head.dome(Vector3(0, 0.3, -0.9), 0.55, 0.9, 2, 8, skin, skin.lightened(0.1))
	head.dome(Vector3(0, 0.3, -0.9), 0.55, -0.5, 2, 8, belly, belly)
	head.box(Vector3(0, 0.38, -1.4), Vector3(0.4, 0.08, 0.08), Color("fff0f0"))
	head.box(Vector3(-0.2, 0.55, -1.3), Vector3(0.1, 0.1, 0.05), Color("ff3a2a"))
	head.box(Vector3(0.2, 0.55, -1.3), Vector3(0.1, 0.1, 0.05), Color("ff3a2a"))
	rig.add_part(head, Vector3.ZERO, "body")
	for i in 3:
		var seg := MeshKit.new()
		var r: float = 0.55 - 0.1 * float(i)
		seg.dome(Vector3(0, 0.0, 0.0), r, 0.9, 2, 8, skin.lerp(belly, 0.1 * float(i)), skin)
		seg.dome(Vector3(0, 0.0, 0.0), r, -0.5, 1, 8, belly.darkened(0.1 * float(i)))
		rig.add_part(seg, Vector3(0, 0.3, -0.2 + 0.7 * float(i)), "slither", float(i))
	rig.nominal_height = 1.1

static func _gloomwing(rig: CharacterRig) -> void:
	var dark := Color("3a1a5a")
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.0, 0), 0.5, 0.9, 2, 8, dark, dark.lightened(0.1))
	b.dome(Vector3(0, 0.0, 0), 0.5, -0.8, 2, 8, Color("8a4ad0"))
	b.dome(Vector3(0, 0.15, -0.5), 0.3, 0.9, 2, 7, dark.lightened(0.05))
	b.box(Vector3(-0.12, 0.25, -0.76), Vector3(0.09, 0.09, 0.05), Color("ffe82e"))
	b.box(Vector3(0.12, 0.25, -0.76), Vector3(0.09, 0.09, 0.05), Color("ffe82e"))
	b.pyramid(Vector3(0, -0.05, 0.4), 0.1, 0.1, -0.6, dark)
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var w := MeshKit.new()
		w.box(Vector3(s * 0.8, 0.0, 0.0), Vector3(1.4, 0.06, 0.9), dark.lightened(0.05), Color("5a2a8a"))
		w.box(Vector3(s * 1.7, 0.0, 0.2), Vector3(0.8, 0.05, 0.5), dark, Color("8a4ad0"))
		w.pyramid(Vector3(s * 2.2, 0.0, 0.1), 0.1, 0.35, 0.0, dark)
		rig.add_part(w, Vector3(s * 0.3, 0.3, 0.0), "wing", s)
	rig.float_height = 1.5
	rig.nominal_height = 2.4

static func _bulwark(rig: CharacterRig) -> void:
	var stone := Color("8a7a9a")
	var b := MeshKit.new()
	b.frustum(Vector3.ZERO, 0.3, 1.0, 1.5, 0.8, 8, stone, stone.lightened(0.15), true, true)
	b.dome(Vector3(0, 1.5, 0), 0.9, 0.7, 3, 8, stone.darkened(0.1), stone.lightened(0.1))
	b.dome(Vector3(0, 1.5, 0), 1.0, 0.35, 1, 8, Color("5a4a6a"))
	b.box(Vector3(0, 1.0, -0.95), Vector3(1.6, 1.5, 0.2), Color("ffc61a"), Color("fff08a")) # tower shield
	b.box(Vector3(0, 1.0, -1.06), Vector3(0.7, 0.9, 0.06), Color("c4122f"))
	b.dome(Vector3(0, 1.2, 0.6), 0.4, 0.9, 2, 7, Color("c8b8a8"))
	b.box(Vector3(-0.15, 1.25, 0.95), Vector3(0.1, 0.1, 0.05), Color("ff3a2a"))
	b.box(Vector3(0.15, 1.25, 0.95), Vector3(0.1, 0.1, 0.05), Color("ff3a2a"))
	for i in 5:
		var a: float = TAU * float(i) / 5.0 + 0.3
		b.pyramid(Vector3(cos(a) * 0.5, 2.0, sin(a) * 0.5 + 0.1), 0.12, 0.12, 0.4, Color("5a4a6a"))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.1, 0), Vector3(0.4, 0.4, 0.5), stone.darkened(0.3))
		rig.add_part(l, Vector3(0.55 * s, 0.4, 0.1), "leg", s)
	rig.nominal_height = 2.6
