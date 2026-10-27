class_name CompanionModels
extends RefCounted
## Original procedural models for the six companions (data/companions.json). Small (0.6-1.1 m), chunky, three colours from the data (base / accent / light) so each
## reads as its own silhouette at phone scale: long ears (Mossbun), spiral shell (Dewsnail), mushroom cap and snout (Truffler), wings and glow (Glowmoth), comb and
## tail fan (Brindlehen), spines (Bristlepup). Built into a CharacterRig, so they walk, bob and flash like every other character. 3-6 meshes each.
const KINDS: Array[String] = ["lfg:companion/mossbun", "lfg:companion/dewsnail", "lfg:companion/truffler", "lfg:companion/glowmoth", "lfg:companion/brindlehen", "lfg:companion/bristlepup"]

static func has_model(kind: String) -> bool:
	return KINDS.has(kind)

static func _col(kind: String, i: int) -> Color:
	var cs: Array = Content.companion(kind).get("colors", ["ffffff", "888888", "ffffff"])
	return Color(String(cs[clampi(i, 0, cs.size() - 1)]))

static func build(kind: String) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.look_id = kind
	match kind:
		"lfg:companion/mossbun": _mossbun(rig, kind)
		"lfg:companion/dewsnail": _dewsnail(rig, kind)
		"lfg:companion/truffler": _truffler(rig, kind)
		"lfg:companion/glowmoth": _glowmoth(rig, kind)
		"lfg:companion/brindlehen": _hen(rig, kind)
		"lfg:companion/bristlepup": _pup(rig, kind)
		_: _mossbun(rig, "lfg:companion/mossbun")
	return rig

static func _eyes(k: MeshKit, y: float, z: float, spread: float, size: float = 0.07) -> void:
	k.box(Vector3(-spread, y, z), Vector3(size, size * 1.4, 0.04), Color("1d1030"))
	k.box(Vector3(spread, y, z), Vector3(size, size * 1.4, 0.04), Color("1d1030"))

static func _mossbun(rig: CharacterRig, kind: String) -> void:
	var base := _col(kind, 0)
	var acc := _col(kind, 1)
	var light := _col(kind, 2)
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.25, 0), 0.5, 0.95, 3, 9, base, base.darkened(0.15))                         # round mossy body
	b.dome(Vector3(0, 0.25, 0), 0.5, -0.5, 2, 9, light, light.darkened(0.1))                         # pale belly
	b.dome(Vector3(0, 0.72, -0.3), 0.3, 0.95, 2, 8, base.lightened(0.05), base)                      # head
	b.box(Vector3(0, 0.7, -0.58), Vector3(0.12, 0.09, 0.08), Color("ff8aa0"))                         # nose
	_eyes(b, 0.8, -0.52, 0.13)
	for s in [-1.0, 1.0]:                                                                              # the long ears
		b.frustum(Vector3(0.16 * s, 0.92, -0.25), 0.0, 0.1, 0.62, 0.07, 5, acc, acc.lightened(0.25))
	b.dome(Vector3(0, 0.95, 0.28), 0.14, 0.9, 1, 6, light, Color("ffffff"))                          # a tuft of a tail
	b.box(Vector3(0, 0.45, 0.42), Vector3(0.5, 0.36, 0.22), Color("a8743a"), Color("c8945a"))         # the little pack it carries
	b.box(Vector3(0, 0.62, 0.42), Vector3(0.54, 0.08, 0.26), Color("6a4a30"))
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.08, -0.04), Vector3(0.15, 0.2, 0.28), light)
		rig.add_part(l, Vector3(0.2 * s, 0.2, 0.0), "leg", s)
	rig.nominal_height = 1.2

static func _dewsnail(rig: CharacterRig, kind: String) -> void:
	var base := _col(kind, 0)
	var acc := _col(kind, 1)
	var light := _col(kind, 2)
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.0, 0.0), 0.62, 0.45, 2, 9, light, light.darkened(0.1))                       # slug body
	b.dome(Vector3(0, 0.0, -0.55), 0.3, 0.9, 2, 8, light.darkened(0.04), light)                      # head
	for s in [-1.0, 1.0]:                                                                              # eye stalks
		b.frustum(Vector3(0.13 * s, 0.2, -0.7), 0.0, 0.04, 0.4, 0.035, 4, light.darkened(0.15))
		b.dome(Vector3(0.13 * s, 0.6, -0.7), 0.07, 1.0, 1, 5, Color("1d1030"))
	# the shell: a rain-barrel spiral of three stepped domes
	b.dome(Vector3(0.0, 0.2, 0.15), 0.52, 1.0, 2, 9, acc, base)
	b.dome(Vector3(0.0, 0.62, 0.15), 0.36, 1.0, 2, 8, acc.lightened(0.1), base)
	b.dome(Vector3(0.0, 0.92, 0.15), 0.2, 1.0, 1, 7, base.lightened(0.2), Color("ffffff"))
	b.box(Vector3(0.0, 0.5, -0.36), Vector3(0.5, 0.06, 0.06), base.lightened(0.3))                    # a droplet ring
	rig.add_part(b, Vector3(0, 0.0, 0.0), "body")
	var t := MeshKit.new()
	t.dome(Vector3(0, 0.0, 0.0), 0.35, 0.4, 1, 7, light.darkened(0.08))
	rig.add_part(t, Vector3(0, 0.0, 0.62), "slither", 1.0)
	rig.nominal_height = 1.3

static func _truffler(rig: CharacterRig, kind: String) -> void:
	var base := _col(kind, 0)
	var acc := _col(kind, 1)
	var light := _col(kind, 2)
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.3, 0), 0.5, 0.75, 2, 8, Color("c8a878"), Color("a8845a"))                    # stocky body
	b.box(Vector3(0, 0.38, -0.56), Vector3(0.3, 0.26, 0.4), Color("e8c8a0"), Color("f6dcb8"))         # snout
	b.box(Vector3(0, 0.38, -0.78), Vector3(0.2, 0.14, 0.06), Color("5a3a22"))
	_eyes(b, 0.58, -0.4, 0.14)
	b.dome(Vector3(0, 0.62, -0.05), 0.62, 0.6, 2, 9, acc, acc.darkened(0.3))                         # the mushroom cap hat
	for i in 5:
		var a: float = TAU * float(i) / 5.0
		b.dome(Vector3(cos(a) * 0.3, 0.88 - 0.1 * float(i % 2), -0.05 + sin(a) * 0.3), 0.09, 0.6, 1, 5, light)
	b.pyramid(Vector3(0, 0.3, 0.52), 0.1, 0.1, 0.2, base)
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.1, 0), Vector3(0.16, 0.26, 0.2), Color("a8845a"))
		rig.add_part(l, Vector3(0.22 * s, 0.22, -0.18), "leg", s)
		var l2 := MeshKit.new()
		l2.box(Vector3(0, -0.1, 0), Vector3(0.16, 0.26, 0.2), Color("8a6a46"))
		rig.add_part(l2, Vector3(0.22 * s, 0.22, 0.22), "leg", -s)
	rig.nominal_height = 1.3

static func _glowmoth(rig: CharacterRig, kind: String) -> void:
	var base := _col(kind, 0)
	var acc := _col(kind, 1)
	var light := _col(kind, 2)
	var b := MeshKit.new()
	b.dome(Vector3(0, 0, 0), 0.24, 1.0, 2, 8, base, acc)                                              # glowing belly
	b.dome(Vector3(0, 0, 0), 0.24, -1.1, 2, 8, light, base)
	b.dome(Vector3(0, 0.06, -0.26), 0.15, 1.0, 1, 7, acc.darkened(0.2), acc)                         # head
	_eyes(b, 0.09, -0.37, 0.07, 0.06)
	for s in [-1.0, 1.0]:                                                                              # feathery antennae
		b.frustum(Vector3(0.07 * s, 0.17, -0.3), 0.0, 0.015, 0.34, 0.01, 4, acc.darkened(0.3))
		b.dome(Vector3(0.07 * s, 0.52, -0.3), 0.04, 1.0, 1, 5, light)
	rig.add_part(b, Vector3.ZERO, "body")
	for s in [-1.0, 1.0]:
		var w := MeshKit.new()
		w.box(Vector3(s * 0.4, 0, 0), Vector3(0.7, 0.04, 0.55), light, Color("ffffff"))
		w.box(Vector3(s * 0.8, 0, 0.1), Vector3(0.4, 0.035, 0.35), base, light)
		rig.add_part(w, Vector3(s * 0.1, 0.1, 0), "wing", s)
	rig.float_height = 1.1
	rig.nominal_height = 1.4

static func _hen(rig: CharacterRig, kind: String) -> void:
	var base := _col(kind, 0)
	var acc := _col(kind, 1)
	var light := _col(kind, 2)
	var b := MeshKit.new()
	b.dome(Vector3(0, 0.1, 0.0), 0.5, 1.05, 3, 9, base, acc.darkened(0.1))                           # round speckled body
	b.dome(Vector3(0, 0.1, 0.0), 0.5, -0.45, 2, 9, light, light.darkened(0.05))
	for i in 6:                                                                                        # speckles
		var a: float = TAU * float(i) / 6.0
		b.dome(Vector3(cos(a) * 0.32, 0.45 + 0.1 * float(i % 3), sin(a) * 0.3), 0.07, 0.5, 1, 4, acc)
	b.dome(Vector3(0, 0.82, -0.36), 0.2, 1.0, 2, 8, base.lightened(0.05), base)                        # head
	b.pyramid(Vector3(0, 0.78, -0.56), 0.09, 0.05, -0.16, Color("ffb020"))                            # beak
	b.box(Vector3(0, 1.08, -0.34), Vector3(0.08, 0.16, 0.2), Color("e8353a"))                          # comb
	b.box(Vector3(0, 0.6, -0.5), Vector3(0.05, 0.12, 0.05), Color("e8353a"))                           # wattle
	_eyes(b, 0.88, -0.52, 0.1, 0.05)
	rig.add_part(b, Vector3.ZERO, "body")
	var t := MeshKit.new()
	for i in 3:
		var a2: float = deg_to_rad(-30.0 + 30.0 * float(i))
		t.frustum(Vector3(sin(a2) * 0.18, 0.0, 0.0), 0.0, 0.1, 0.5, 0.04, 4, acc if i != 1 else acc.lightened(0.2))
	rig.add_part(t, Vector3(0, 0.5, 0.45), "tail", 1.0)
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.12, 0), Vector3(0.07, 0.3, 0.07), Color("ffb020"))
		rig.add_part(l, Vector3(0.16 * s, 0.26, 0.0), "leg", s)
	rig.nominal_height = 1.2

static func _pup(rig: CharacterRig, kind: String) -> void:
	var base := _col(kind, 0)
	var acc := _col(kind, 1)
	var dark := _col(kind, 2)
	var b := MeshKit.new()
	b.box(Vector3(0, 0.42, 0.0), Vector3(0.5, 0.42, 0.9), base, base.lightened(0.1))                  # body
	b.box(Vector3(0, 0.62, -0.62), Vector3(0.42, 0.4, 0.4), base.lightened(0.05), base.lightened(0.15))   # head
	b.box(Vector3(0, 0.54, -0.9), Vector3(0.24, 0.2, 0.2), Color("e8d0a0"))                           # muzzle
	b.box(Vector3(0, 0.58, -1.01), Vector3(0.1, 0.08, 0.05), dark)
	_eyes(b, 0.7, -0.83, 0.12, 0.06)
	for s in [-1.0, 1.0]:                                                                              # ears
		b.pyramid(Vector3(0.16 * s, 0.82, -0.58), 0.08, 0.08, 0.28, acc)
	for i in 5:                                                                                        # the thorn-back
		b.pyramid(Vector3(0, 0.63, -0.3 + 0.2 * float(i)), 0.07, 0.07, 0.3 - 0.03 * float(i), acc, acc.lightened(0.2))
	rig.add_part(b, Vector3.ZERO, "body")
	var t := MeshKit.new()
	t.box(Vector3(0, 0.2, 0.1), Vector3(0.1, 0.4, 0.1), base.darkened(0.1))
	rig.add_part(t, Vector3(0, 0.45, 0.46), "tail", 1.0)
	for s in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.13, 0), Vector3(0.14, 0.3, 0.16), base.darkened(0.15))
		rig.add_part(l, Vector3(0.18 * s, 0.3, -0.3), "leg", s)
		var l2 := MeshKit.new()
		l2.box(Vector3(0, -0.13, 0), Vector3(0.14, 0.3, 0.16), base.darkened(0.2))
		rig.add_part(l2, Vector3(0.18 * s, 0.3, 0.3), "leg", -s)
	rig.nominal_height = 1.2
