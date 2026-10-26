class_name CropModels
extends RefCounted
## Per-crop plant shapes for farm plots (one look per crop in data/crops.json; unknown crops reuse glowfruit).
## Plot base (soil, frame, furrows) is shared and built by FarmLayer; this adds the plants for one stage.
const CROPS: Array[String] = ["lfg:crop/glowfruit", "lfg:crop/sporebean", "lfg:crop/saltroot"]

static func index_of(crop_id: String) -> int:
	var i: int = CROPS.find(crop_id)
	return maxi(i, 0)

## stage: FarmLayer.Stage (SEEDED 1, SPROUT 2, GROWING 3, RIPE 4, WILTED 5; TILLED 0 has no plants).
static func add_plant(k: MeshKit, crop: String, stage: int, base: Vector3, i: int, row: int) -> void:
	match crop:
		"lfg:crop/sporebean": _sporebean(k, stage, base, i, row)
		"lfg:crop/saltroot": _saltroot(k, stage, base, i, row)
		_: _glowfruit(k, stage, base, i, row)

static func _glowfruit(k: MeshKit, stage: int, base: Vector3, i: int, row: int) -> void:
	match stage:
		1: k.dome(base, 0.16, 0.8, 1, 5, Color("e8d8a0"))
		2:
			k.pyramid(base, 0.14, 0.04, 0.55, Color("7fe05a"), Color("a8f06a"))
			k.pyramid(base, 0.04, 0.14, 0.45, Color("7fe05a"), Color("a8f06a"))
		3:
			k.frustum(base, 0.0, 0.07, 0.9, 0.05, 4, Color("3fc08a"), Color("6fe0a0"))
			k.dome(base + Vector3(0, 0.55, 0), 0.38, 0.7, 1, 6, Color("2fa87a"), Color("2fa87a"))
			k.dome(base + Vector3(0, 0.95, 0), 0.14, 1.0, 1, 5, Color("e6ff2e"))
		4:
			k.frustum(base, 0.0, 0.08, 1.2, 0.06, 4, Color("2f9a6a"), Color("4fb88a"))
			k.dome(base + Vector3(0, 0.7, 0), 0.5, 0.7, 1, 6, Color("2fa87a"), Color("2fa87a"))
			var orb: Color = Color("ff2fb5") if (i + row) % 2 == 0 else Color("ffe82e")
			k.blob(base + Vector3(0, 1.45, 0), Vector3(0.36, 0.36, 0.36), 3 + i + row * 7, orb, orb.lightened(0.4))
		5:
			k.frustum(base, 0.0, 0.06, 0.45, 0.05, 4, Color("8a7a4a"), Color("8a7a4a"))
			k.pyramid(base + Vector3(0.18, 0.2, 0), 0.2, 0.04, 0.2, Color("6a5a38"))

## Sporebean: tall purple stalk with hanging teal pods; drought-proof so it stands stiff.
static func _sporebean(k: MeshKit, stage: int, base: Vector3, i: int, row: int) -> void:
	var stalk := Color("7a4ad0")
	match stage:
		1: k.dome(base, 0.14, 0.8, 1, 5, Color("c8b8f0"))
		2: k.frustum(base, 0.0, 0.07, 0.6, 0.04, 4, Color("9a6af0"), Color("c8a8ff"))
		3:
			k.frustum(base, 0.0, 0.08, 1.5, 0.05, 4, stalk, Color("b08aff"))
			k.dome(base + Vector3(0, 0.9, 0), 0.3, 0.5, 1, 5, Color("5a3aa0"))
			k.dome(base + Vector3(0, 1.55, 0), 0.2, 0.9, 1, 5, Color("19e0c8"))
		4:
			k.frustum(base, 0.0, 0.1, 2.0, 0.06, 4, stalk, Color("b08aff"))
			for p in 3:
				var a: float = float(p) * 2.1 + float(i + row)
				k.frustum(base + Vector3(cos(a) * 0.28, 0.8 + 0.4 * float(p), sin(a) * 0.28), 0.0, 0.14, 0.5, 0.1, 5, Color("19e0c8"), Color("9affee"))
			k.dome(base + Vector3(0, 2.05, 0), 0.3, 0.6, 1, 6, Color("ff2fb5"), Color("ff8ad8"))
		5:
			k.frustum(base, 0.0, 0.06, 0.8, 0.04, 4, Color("6a5a78"))
			k.pyramid(base + Vector3(0.15, 0.6, 0.0), 0.2, 0.04, 0.2, Color("4a3a58"))

## Saltroot: low frilly leaves with a fat pale bulb breaking the soil.
static func _saltroot(k: MeshKit, stage: int, base: Vector3, i: int, row: int) -> void:
	var leaf := Color("5fd0a8")
	match stage:
		1: k.dome(base, 0.15, 0.7, 1, 5, Color("f0e0e0"))
		2:
			k.pyramid(base, 0.2, 0.05, 0.4, leaf, leaf.lightened(0.2))
			k.pyramid(base, 0.05, 0.2, 0.4, leaf, leaf.lightened(0.2))
		3:
			for a in 3:
				var an: float = float(a) * 2.09
				k.pyramid(base + Vector3(cos(an) * 0.12, 0.0, sin(an) * 0.12), 0.1, 0.1, 0.8, leaf, leaf.lightened(0.25))
			k.dome(base + Vector3(0, 0.0, 0), 0.2, 0.8, 1, 6, Color("ffe8f0"))
		4:
			for a2 in 4:
				var an2: float = float(a2) * 1.57 + float(i)
				k.pyramid(base + Vector3(cos(an2) * 0.15, 0.2, sin(an2) * 0.15), 0.12, 0.12, 1.1, leaf, leaf.lightened(0.25))
			k.blob(base + Vector3(0, 0.15, 0), Vector3(0.38, 0.34, 0.38), 11 + i + row * 5, Color("fff0f6"), Color("ffc8e0"))
		5:
			k.pyramid(base, 0.15, 0.04, 0.3, Color("8a7a6a"))
			k.dome(base, 0.2, 0.6, 1, 5, Color("c8b8b0"))
