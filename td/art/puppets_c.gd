extends RefCounted
# Creature designs batch C: Gloamoth, Bogbard, Quillwyrm, Drumbeak.
const Pup = preload("res://art/puppet.gd")

static func A(kind: String, amp: float, cyc: float = 1.0, ph: float = 0.0, px: float = 0.0, py: float = 0.0, atk: float = 0.0) -> Dictionary:
	return Pup.A(kind, amp, cyc, ph, px, py, atk)

static func build(id: String) -> Array:
	match id:
		"gloamoth": return _gloamoth()
		"bogbard": return _bogbard()
		"quillwyrm": return _quillwyrm()
		"drumbeak": return _drumbeak()
	return []

# Gloamoth: Umbra/Aether. Dreamy luna moth + Mothman + lampshade
static func _gloamoth() -> Array:
	return [
		Pup.E(-14, -74, 36, 30, "#a8d8b0", {"rot": -30.0, "wob": 0.05, "a": [A("rot", 12.0, 2.0, 0.0, 0, -54)]}),
		Pup.E(-26, -82, 9, 9, "#6a5aa8", {"rot": -30.0, "a": [A("rot", 12.0, 2.0, 0.0, 12, -26)]}),
		Pup.E(-26, -82, 4.5, 4.5, "#ffe36a", {"ow": 1.5, "a": [A("rot", 12.0, 2.0, 0.0, 12, -26)]}),
		Pup.leg([[-6, -26, 5], [-8, -13, 5], [-12, -1, 5]], "#7a5a8a", 0.0, -6, -28, 20.0),
		Pup.leg([[8, -26, 5], [10, -13, 5], [14, -1, 5]], "#7a5a8a", PI, 8, -28, 20.0),
		Pup.P([[-16, -30], [16, -30], [22, -70], [-22, -70]], "#ffd98a", {"ow": 3.5}),
		Pup.T([[-7, -34, 2], [-10, -66, 2]], "#e0a860", {"ow": 0}),
		Pup.T([[7, -34, 2], [10, -66, 2]], "#e0a860", {"ow": 0}),
		Pup.E(0, -30, 17, 6, "#7a4a8a", {"ow": 3.0}),
		Pup.E(6, -72, 19, 8, "#ffffff", {"wob": 0.18, "seed": 2.0}),
		Pup.E(8, -86, 15, 14, "#efe8f4", {"wob": 0.03}),
		Pup.T([[4, -96, 3], [-4, -114, 3], [-12, -120, 2.5]], "#9a8ac0", {"wave": 4.0}),
		Pup.T([[14, -96, 3], [20, -116, 3], [30, -122, 2.5]], "#9a8ac0", {"wave": 4.0, "wcyc": 1.0}),
		Pup.EYE(11, -88, 8.5, "dot"),
		Pup.EYE(21, -87, 6.0, "dot"),
		Pup.MOUTH(17, -77, 5, "smile", {"atk": "o"}),
		Pup.E(14, -68, 30, 26, "#c8ecd0", {"rot": 25.0, "wob": 0.05, "a": [A("rot", -12.0, 2.0, 0.0, 0, -54)]}),
		Pup.E(26, -66, 8, 8, "#6a5aa8", {"rot": 25.0, "a": [A("rot", -12.0, 2.0, 0.0, 0, -54)]}),
		Pup.E(26, -66, 4, 4, "#ffe36a", {"ow": 1.5, "a": [A("rot", -12.0, 2.0, 0.0, 0, -54)]}),
	]

# Bogbard: Tide/Venom. Smug Surinam toad busker + Kappa + banjo
static func _bogbard() -> Array:
	var toad := "#8a7a3a"
	var parts: Array = [
		Pup.leg([[-12, -22, 13], [-28, -10, 11], [-14, -1, 10]], "#6e6230", 0.0, -12, -24, 14.0),
		Pup.E(0, -36, 30, 24, toad, {"wob": 0.06, "seed": 2.0}),
		Pup.E(8, -30, 20, 15, "#d8cf8a", {"ow": 0}),
	]
	for i in 6:
		parts.append(Pup.E(-20 + i * 7, -52 + (i % 2) * 5, 3, 3, "#5e5226", {"ow": 0}))
	parts.append_array([
		Pup.T([[18, -26, 5], [46, -48, 4]], "#6a4a2a", {"ow": 2.5}),
		Pup.E(14, -24, 15, 15, "#c98a3a", {"ow": 3.0}),
		Pup.E(14, -24, 8, 8, "#f2e2b0", {"ow": 2.0}),
		Pup.T([[8, -34, 7], [18, -26, 6]], toad, {"a": [A("rot", 18.0, 4.0, 0, 8, -34, 40.0)]}),
		Pup.S(21, -25, 8, 5, toad, {"in": 0.5, "a": [A("rot", 18.0, 4.0, 0, -13, -9, 40.0)]}),
		Pup.E(16, -62, 24, 12, toad, {"wob": 0.04, "seed": 1.0}),
		Pup.E(4, -73, 8, 8, toad),
		Pup.E(26, -73, 8, 8, toad),
		Pup.EYE(4, -75, 5.5, "round", {"iris": "#d6a82a"}),
		Pup.EYE(26, -75, 5.5, "round", {"iris": "#d6a82a"}),
		Pup.MOUTH(18, -58, 22, "grin", {"atk": "o"}),
		Pup.P([[-8, -82], [18, -90], [34, -82], [12, -78]], "#3a6a9a", {"ow": 3.0}),
		Pup.P([[22, -86], [44, -112], [34, -84]], "#e8632b", {"ow": 3.0, "a": [A("rot", 8.0, 2.0, 0, 26, -86)]}),
		Pup.S(-34, -70, 6, 4, "#fff3a0", {"ow": 1.5, "a": [A("dy", 6.0, 1.0, 0.0)]}),
		Pup.E(-44, -88, 5, 4, "#ffffff", {"ow": 2.0, "a": [A("dy", 6.0, 1.0, 2.0)]}),
	])
	return parts

# Quillwyrm: Stone/Verdant. Shy echidna + Lambton Worm + pincushion
static func _quillwyrm() -> Array:
	var brown := "#7a5a4a"
	var cols := ["#ff5a7a", "#ffd23a", "#5ad0ff", "#9a7aff"]
	var parts: Array = [
		Pup.T([[-70, -14, 9], [-86, -26, 7], [-84, -42, 5]], "#6a4c3e", {"wave": 5.0}),
		Pup.E(-52, -16, 12, 10, "#6a4c3e"),
		Pup.E(-34, -22, 15, 13, brown),
		Pup.leg([[-24, -14, 9], [-26, -4, 8]], "#5a3f33", 0.0, -24, -16, 14.0),
		Pup.E(-14, -30, 19, 17, brown),
		Pup.E(8, -36, 26, 22, brown, {"wob": 0.04}),
	]
	for i in 9:
		var x := -26.0 + i * 6.5
		var y := -50.0 - (i % 3) * 2.0
		var lean := -8.0 + i * 3.0
		parts.append(Pup.T([[x, y + 6, 2.4], [x + lean * 0.5, y - 10, 2.4]], "#e8e8f0", {"ow": 1.2, "a": [A("rot", 5.0, 2.0, i * 0.7, x, y + 6)]}))
		parts.append(Pup.E(x + lean * 0.5, y - 13, 4.5, 4.5, cols[i % 4], {"ow": 1.8, "a": [A("rot", 5.0, 2.0, i * 0.7, x, y + 6)]}))
	parts.append_array([
		Pup.leg([[16, -18, 9], [18, -4, 8]], "#5a3f33", PI, 16, -20, 14.0),
		Pup.P([[24, -46], [60, -38], [24, -28]], "#a8826a", {"ow": 3.0}),
		Pup.E(60, -38, 4.0, 3.5, "#2b1a3d", {"ow": 0}),
		Pup.EYE(32, -42, 5.0, "round"),
		Pup.E(30, -34, 5.5, 3.8, "#ff9ab0aa", {"ow": 0}),
		Pup.MOUTH(46, -32, 8, "flat", {"atk": "o"}),
	])
	return parts

# Drumbeak: Gale/Spirit. Deadpan shoebill drummer + Thoth + drum kit
static func _drumbeak() -> Array:
	var grey := "#8a96b0"
	return [
		Pup.leg([[-4, -50, 6], [-6, -26, 5], [-10, -1, 5]], "#5a6580", 0.0, -4, -52, 12.0),
		Pup.E(-8, -2, 9, 3.5, "#5a6580", {"ow": 2.0}),
		Pup.E(0, -68, 22, 26, grey, {"wob": 0.04, "seed": 1.0}),
		Pup.E(4, -62, 17, 17, "#c46a3a", {"ow": 3.0}),
		Pup.RING(4, -62, 15, 3.5, "#f2d28a"),
		Pup.T([[-6, -62, 2], [14, -62, 2]], "#7a3a1a", {"ow": 0}),
		Pup.T([[4, -72, 2], [4, -52, 2]], "#7a3a1a", {"ow": 0}),
		Pup.leg([[8, -48, 6], [10, -26, 5], [16, -1, 5]], "#5a6580", PI, 8, -50, 12.0),
		Pup.T([[-4, -76, 7], [10, -66, 6], [22, -72, 5]], grey, {"wave": 3.0, "hand": true, "a": [A("rot", 14.0, 4.0, 0, -4, -76, 70.0)]}),
		Pup.T([[22, -72, 2.6], [36, -88, 2.6]], "#f2d28a", {"ow": 2.0, "a": [A("rot", 14.0, 4.0, 0, -4, -76, 70.0)]}),
		Pup.E(37, -89, 4.0, 4.0, "#f2d28a", {"ow": 2.0, "a": [A("rot", 14.0, 4.0, 0, -4, -76, 70.0)]}),
		Pup.T([[8, -88, 10], [14, -106, 9]], grey, {}),
		Pup.P([[10, -122], [14, -138], [20, -122]], "#5a6580", {"ow": 2.5}),
		Pup.E(16, -114, 13, 12, grey, {"wob": 0.03}),
		Pup.P([[22, -122], [46, -120], [52, -106], [46, -92], [26, -98]], "#d8c8a0", {"ow": 3.5}),
		Pup.P([[46, -92], [52, -106], [54, -92]], "#8a7a58", {"ow": 2.0}),
		Pup.E(40, -108, 2.2, 3.0, "#5a4a30", {"ow": 0}),
		Pup.EYE(19, -118, 5.0, "round", {"iris": "#ffd23a"}),
		Pup.T([[12, -124, 2.5], [26, -122, 2.5]], "#2b1a3d", {"ow": 0}),
		Pup.T([[26, -99, 2], [46, -99, 2]], "#8a7a58", {"ow": 0}),
	]
