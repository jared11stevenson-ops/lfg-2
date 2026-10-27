class_name GuardianModels
extends RefCounted
## Original procedural models for the seven region guardians (data/guardians.json): each a large, unmistakable silhouette (3.5-6 m) that reads from the follow camera
## and from across a hex. Built into a CharacterRig so they bob, rear back (attack), flash (hurt) and topple (death) like every other creature. 4-7 meshes each.
const IDS: Array[String] = ["lfg:enemy/guardian_meadow", "lfg:enemy/guardian_shore", "lfg:enemy/guardian_fungal_grove", "lfg:enemy/guardian_ruins", "lfg:enemy/guardian_salt_flats",
	"lfg:enemy/guardian_highlands", "lfg:enemy/guardian_bog"]

static func has_model(id: String) -> bool:
	return IDS.has(id)

static func build(id: String) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.look_id = id
	match id:
		"lfg:enemy/guardian_meadow": _gourdmother(rig)
		"lfg:enemy/guardian_shore": _brinecrown(rig)
		"lfg:enemy/guardian_fungal_grove": _elder(rig)
		"lfg:enemy/guardian_ruins": _vaultwarden(rig)
		"lfg:enemy/guardian_salt_flats": _heron(rig)
		"lfg:enemy/guardian_highlands": _ram(rig)
		"lfg:enemy/guardian_bog": _toad(rig)
		_: _gourdmother(rig)
	return rig

static func _eyes(k: MeshKit, y: float, z: float, spread: float, size: float, col: Color) -> void:
	k.box(Vector3(-spread, y, z), Vector3(size, size * 0.8, 0.08), col)
	k.box(Vector3(spread, y, z), Vector3(size, size * 0.8, 0.08), col)

static func _gourdmother(rig: CharacterRig) -> void:
	var rind := Color("f08a2a")
	var stripe := Color("5fa83a")
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.9, 0), 2.1, 1.0, 3, 10, rind, rind.darkened(0.2))                         # the great gourd
	b.dome(Vector3(0, 0.9, 0), 2.1, -0.6, 2, 10, rind.darkened(0.15), rind.darkened(0.3))
	for i in 5:                                                                                    # green ribs
		var a: float = TAU * float(i) / 5.0
		b.box(Vector3(cos(a) * 1.85, 2.0, sin(a) * 1.85), Vector3(0.22, 1.9, 0.22), stripe)
	_eyes(b, 2.35, -1.95, 0.55, 0.42, Color("ffe82e"))
	b.box(Vector3(0, 1.6, -2.0), Vector3(1.3, 0.35, 0.1), Color("3a1a10"))                         # a stern mouth
	b.frustum(Vector3(0, 3.8, 0), 0.0, 0.3, 0.9, 0.2, 5, Color("6a8a2a"))
	for i in 4:                                                                                    # leaf crown
		var a2: float = TAU * float(i) / 4.0
		b.pyramid(Vector3(cos(a2) * 0.55, 4.5, sin(a2) * 0.55), 0.3, 0.12, 0.8, stripe.lightened(0.1))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var arm := MeshKit.new()
		arm.frustum(Vector3(0, -1.5, 0), 0.0, 0.3, 1.9, 0.22, 5, stripe.darkened(0.1))
		arm.dome(Vector3(0, -1.6, 0), 0.5, -0.8, 1, 6, stripe)
		rig.add_part(arm, Vector3(2.2 * s, 2.6, 0), "arm", s)
	rig.nominal_height = 5.0

static func _brinecrown(rig: CharacterRig) -> void:
	var shell := Color("2fb8a8")
	var coral := Color("ff6a5a")
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.9, 0), 2.4, 0.75, 3, 10, shell, shell.darkened(0.25))
	b.dome(Vector3(0, 0.9, 0), 2.4, -0.3, 2, 10, coral.darkened(0.2), coral.darkened(0.4))
	for i in 6:                                                                                    # the crown of spikes
		var a: float = TAU * float(i) / 6.0
		b.pyramid(Vector3(cos(a) * 1.0, 2.55, sin(a) * 1.0 - 0.2), 0.22, 0.22, 1.1 + 0.25 * float(i % 2), coral, Color("fff0d0"))
	for s in [-1.0, 1.0]:                                                                          # eye stalks
		b.frustum(Vector3(0.7 * s, 2.2, -1.5), 0.0, 0.1, 0.9, 0.08, 5, shell.lightened(0.15))
		b.dome(Vector3(0.7 * s, 3.1, -1.5), 0.24, 1.0, 1, 6, Color("ffe82e"))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var claw := MeshKit.new()
		claw.box(Vector3(0, 0, -0.9), Vector3(0.6, 0.6, 1.8), coral)
		claw.pyramid(Vector3(-0.3, 0.0, -2.1), 0.3, 0.3, -1.1, coral.lightened(0.15))
		claw.pyramid(Vector3(0.3, 0.0, -2.1), 0.3, 0.3, -1.1, coral.lightened(0.15))
		claw.dome(Vector3(0, 0, 0), 0.5, 0.9, 1, 6, coral.darkened(0.15))
		rig.add_part(claw, Vector3(2.5 * s, 1.5, -0.3), "arm", s)
	for i in 3:
		for s in [-1.0, 1.0]:
			var l := MeshKit.new()
			l.box(Vector3(0.7 * s, -0.4, 0), Vector3(1.4, 0.18, 0.18), shell.darkened(0.3))
			rig.add_part(l, Vector3(1.9 * s * 0.6, 0.8, 0.6 + 0.6 * float(i)), "leg", s * (1.0 if i % 2 == 0 else -1.0))
	rig.nominal_height = 4.2

static func _elder(rig: CharacterRig) -> void:
	var stalk := Color("f3e4cf")
	var cap := Color("a63ad8")
	var b := MeshKit.new()
	b.frustum(Vector3.ZERO, 0.0, 1.4, 4.0, 1.0, 9, stalk, stalk.lightened(0.1), true, true)
	b.dome(Vector3(0, 3.9, 0), 3.0, 0.65, 3, 11, cap, cap.darkened(0.3))                          # the huge cap
	b.dome(Vector3(0, 3.9, 0), 3.0, -0.18, 2, 11, Color("e8c8f8"), Color("c8a0e0"))
	for i in 7:                                                                                    # glowing spots
		var a: float = TAU * float(i) / 7.0
		b.dome(Vector3(cos(a) * 1.7, 5.3 - 0.35 * float(i % 3), sin(a) * 1.7), 0.38, 0.5, 1, 6, [Color("b6ff6a"), Color("ffe84a"), Color("ff2fb5")][i % 3], Color("ffffff"))
	_eyes(b, 2.5, -1.2, 0.4, 0.36, Color("b6ff6a"))
	b.box(Vector3(0, 1.8, -1.12), Vector3(0.9, 0.3, 0.1), Color("2a1030"))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var arm := MeshKit.new()
		arm.frustum(Vector3(0, -1.6, 0), 0.0, 0.26, 2.0, 0.18, 5, Color("6a4a30"))
		arm.pyramid(Vector3(0, -1.7, 0), 0.4, 0.4, -0.8, Color("6a4a30").darkened(0.1))
		rig.add_part(arm, Vector3(1.4 * s, 2.7, 0), "arm", s)
	rig.nominal_height = 6.0

static func _vaultwarden(rig: CharacterRig) -> void:
	var stone := Color("8a7a9a")
	var glow := Color("c47bff")
	var b := MeshKit.new()
	b.box(Vector3(0, 2.4, 0), Vector3(2.8, 3.0, 1.8), stone, stone.lightened(0.15))                # torso
	b.box(Vector3(0, 4.35, -0.1), Vector3(1.5, 1.3, 1.4), stone.lightened(0.05), stone.lightened(0.2))   # head
	_eyes(b, 4.4, -0.85, 0.35, 0.3, glow)
	b.box(Vector3(0, 2.6, -0.95), Vector3(1.6, 0.14, 0.06), glow)                                     # carved glyph lines
	b.box(Vector3(0, 3.1, -0.95), Vector3(0.14, 1.2, 0.06), glow)
	b.box(Vector3(0, 1.6, -0.95), Vector3(1.0, 0.14, 0.06), Color("49c6e5"))
	b.box(Vector3(0, 1.0, 0), Vector3(2.2, 0.8, 1.5), stone.darkened(0.2))
	b.pyramid(Vector3(0, 5.0, -0.1), 0.6, 0.6, 0.7, stone.darkened(0.1), glow)
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var arm := MeshKit.new()
		arm.box(Vector3(0, -1.0, 0), Vector3(0.9, 2.2, 0.9), stone.darkened(0.05), stone.lightened(0.1))
		arm.box(Vector3(0, -2.4, 0), Vector3(1.4, 1.1, 1.3), stone.lightened(0.1), stone.lightened(0.25))
		arm.box(Vector3(0, -2.4, -0.68), Vector3(0.7, 0.14, 0.06), glow)
		rig.add_part(arm, Vector3(1.9 * s, 3.5, 0), "arm", s)
		var l := MeshKit.new()
		l.box(Vector3(0, -0.4, 0), Vector3(1.0, 1.4, 1.1), stone.darkened(0.25))
		rig.add_part(l, Vector3(0.8 * s, 0.9, 0.0), "leg", s)
	rig.nominal_height = 5.4

static func _heron(rig: CharacterRig) -> void:
	var white := Color("e8f4ff")
	var blue := Color("7ac8f0")
	var b := MeshKit.new()
	b.dome(Vector3(0, 3.2, 0.3), 1.0, 0.85, 2, 9, white, blue)                                     # slim body
	b.dome(Vector3(0, 3.2, 0.3), 1.0, -0.6, 2, 9, blue.lightened(0.2), blue)
	b.frustum(Vector3(0, 3.6, -0.5), 0.0, 0.28, 1.9, 0.18, 6, white)                               # long neck
	b.dome(Vector3(0, 5.6, -0.8), 0.45, 0.9, 2, 8, white, white.darkened(0.05))                     # head
	b.pyramid(Vector3(0, 5.55, -1.45), 0.14, 0.14, -1.4, Color("ffb020"))                           # dagger beak
	_eyes(b, 5.7, -1.1, 0.2, 0.12, Color("ff3a2a"))
	for i in 3:                                                                                    # crest plumes
		b.pyramid(Vector3(0.0, 6.0, -0.55 + 0.25 * float(i)), 0.06, 0.12, 0.8 - 0.1 * float(i), blue, Color("ffffff"))
	b.pyramid(Vector3(0, 3.1, 1.4), 0.3, 0.12, 0.9, blue)
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.frustum(Vector3(0, -1.3, 0), 0.0, 0.1, 2.7, 0.07, 4, Color("e8a21a"))
		l.box(Vector3(0, -1.35, -0.3), Vector3(0.12, 0.08, 0.7), Color("e8a21a"))
		rig.add_part(l, Vector3(0.42 * s, 2.7, 0.3), "leg", s)
		var w := MeshKit.new()
		w.box(Vector3(s * 1.4, 0, 0), Vector3(2.6, 0.08, 1.6), white, blue)
		w.box(Vector3(s * 3.0, 0, 0.3), Vector3(1.5, 0.07, 1.0), blue, Color("ffffff"))
		rig.add_part(w, Vector3(s * 0.7, 3.5, 0.4), "wing", s)
	rig.nominal_height = 6.0

static func _ram(rig: CharacterRig) -> void:
	var wool := Color("9aa8c8")
	var horn := Color("f0dca0")
	var b := MeshKit.new()
	b.dome(Vector3(0, 1.6, 0.3), 2.2, 0.8, 3, 10, wool, wool.darkened(0.25))                       # woolly bulk
	b.dome(Vector3(0, 1.6, 0.3), 2.2, -0.5, 2, 10, wool.darkened(0.25), wool.darkened(0.4))
	b.box(Vector3(0, 2.5, -2.0), Vector3(1.2, 1.3, 1.3), Color("6a5a4a"), Color("8a7a66"))          # face
	b.box(Vector3(0, 2.2, -2.7), Vector3(0.8, 0.7, 0.4), Color("c8b090"))
	_eyes(b, 2.8, -2.68, 0.35, 0.22, Color("ffe82e"))
	for s in [-1.0, 1.0]:                                                                           # curled horns
		b.frustum(Vector3(0.85 * s, 2.9, -1.8), 0.0, 0.32, 1.1, 0.26, 6, horn)
		b.frustum(Vector3(1.2 * s, 3.8, -1.8), 0.0, 0.28, 0.9, 0.2, 6, horn.darkened(0.05), horn.lightened(0.2), true, false)
		b.pyramid(Vector3(1.7 * s, 3.6, -1.8), 0.22, 0.22, 0.9, Color("ffe84a"), Color("ffffff"))   # lightning tips
	for i in 5:
		b.pyramid(Vector3(-1.2 + 0.6 * float(i), 3.7, 0.2), 0.15, 0.15, 0.5, Color("ffe84a"))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.5, 0), Vector3(0.6, 1.6, 0.7), Color("6a5a4a"))
		rig.add_part(l, Vector3(1.0 * s, 1.1, -1.0), "leg", s)
		var l2 := MeshKit.new()
		l2.box(Vector3(0, -0.5, 0), Vector3(0.6, 1.6, 0.7), Color("5a4a3a"))
		rig.add_part(l2, Vector3(1.0 * s, 1.1, 1.4), "leg", -s)
	rig.nominal_height = 4.8

static func _toad(rig: CharacterRig) -> void:
	var skin := Color("6a8a3a")
	var belly := Color("d8e08a")
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.8, 0), 2.6, 0.65, 3, 10, skin, skin.darkened(0.3))
	b.dome(Vector3(0, 0.8, 0), 2.6, -0.45, 2, 10, belly, belly.darkened(0.2))
	for i in 8:                                                                                    # warts
		var a: float = TAU * float(i) / 8.0 + 0.2
		b.dome(Vector3(cos(a) * 1.5, 1.8 + 0.15 * float(i % 3), sin(a) * 1.1 + 0.2), 0.22, 0.7, 1, 5, skin.lightened(0.2), Color("c8e86a"))
	for s in [-1.0, 1.0]:                                                                          # periscope eyes
		b.dome(Vector3(0.9 * s, 2.35, -1.2), 0.5, 1.0, 2, 7, skin.lightened(0.1), skin)
		b.dome(Vector3(0.9 * s, 2.55, -1.55), 0.28, 0.9, 1, 6, Color("ffe82e"))
		b.box(Vector3(0.9 * s, 2.55, -1.8), Vector3(0.1, 0.3, 0.05), Color("1d1030"))
	b.box(Vector3(0, 0.9, -2.45), Vector3(2.6, 0.22, 0.2), Color("3a1a10"))                          # wide mouth
	b.dome(Vector3(0, 0.3, -2.3), 0.8, 0.7, 2, 7, Color("f0a0b0"), Color("c87888"))                  # throat sac
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.dome(Vector3(0, 0, 0), 0.9, 1.0, 2, 7, skin.darkened(0.15), skin)
		l.box(Vector3(0, -0.2, -0.7), Vector3(0.9, 0.2, 0.8), skin.darkened(0.25))
		rig.add_part(l, Vector3(2.1 * s, 0.6, 0.9), "leg", s)
		var a2 := MeshKit.new()
		a2.box(Vector3(0, -0.4, 0), Vector3(0.5, 1.0, 0.5), skin.darkened(0.2))
		a2.box(Vector3(0, -0.9, -0.3), Vector3(0.9, 0.18, 0.7), skin.darkened(0.3))
		rig.add_part(a2, Vector3(1.6 * s, 1.1, -1.4), "arm", s)
	rig.nominal_height = 3.6
