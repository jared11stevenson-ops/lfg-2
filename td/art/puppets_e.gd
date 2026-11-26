extends RefCounted
# Creature designs batch E: Tentbat, Dumbomaton, Colukite, Gilamancer.
const Pup = preload("res://art/puppet.gd")

static func A(kind: String, amp: float, cyc: float = 1.0, ph: float = 0.0, px: float = 0.0, py: float = 0.0, atk: float = 0.0) -> Dictionary:
	return Pup.A(kind, amp, cyc, ph, px, py, atk)

static func build(id: String) -> Array:
	match id:
		"tentbat": return _tentbat()
		"dumbomaton": return _dumbomaton()
		"colukite": return _colukite()
		"gilamancer": return _gilamancer()
	return []

# Tentbat: Verdant/Umbra. Sleepy leaf-tent bat + Green Man + teacup
static func _tentbat() -> Array:
	return [
		Pup.P([[-38, -2], [0, -108], [38, -2]], "#5aa84a", {"ow": 3.5}),
		Pup.T([[0, -100, 3], [0, -6, 3]], "#3a7a32", {"ow": 0}),
		Pup.T([[-4, -78, 2], [-20, -60, 2]], "#3a7a32", {"ow": 0}),
		Pup.T([[4, -62, 2], [22, -44, 2]], "#3a7a32", {"ow": 0}),
		Pup.leg([[-6, -18, 6], [-8, -8, 5], [-10, -1, 5]], "#c8c8d8", 0.0, -6, -20, 14.0),
		Pup.E(2, -40, 19, 19, "#f4f4f8", {"wob": 0.14, "seed": 2.0}),
		Pup.leg([[8, -18, 6], [10, -8, 5], [12, -1, 5]], "#c8c8d8", PI, 8, -20, 14.0),
		Pup.E(-8, -62, 7, 12, "#f4f4f8", {"rot": -10.0}),
		Pup.E(22, -62, 7, 12, "#f4f4f8", {"rot": 10.0}),
		Pup.E(8, -56, 15, 13, "#f4f4f8", {"wob": 0.08, "seed": 1.0}),
		Pup.P([[18, -54], [28, -64], [30, -50]], "#ffd23a", {"ow": 2.5}),
		Pup.EYE(5, -60, 5.5, "sleepy", {"lid": "#f4f4f8", "iris": "#2b1a3d"}),
		Pup.EYE(15, -59, 4.5, "sleepy", {"lid": "#f4f4f8", "iris": "#2b1a3d"}),
		Pup.T([[-2, -70, 3], [6, -78, 3], [16, -74, 3]], "#3a9a3a", {"ow": 1.8, "wave": 2.0}),
		Pup.S(6, -80, 5, 5, "#ff9ab0", {"ow": 1.5}),
		Pup.T([[6, -38, 6], [20, -34, 6]], "#e4e4f0", {"a": [A("rot", 6.0, 1.0, 0, 6, -38, 30.0)]}),
		Pup.E(28, -40, 9, 7, "#8ad0f0", {"ow": 3.0, "a": [A("rot", 6.0, 1.0, 0, 6, -38, 30.0)]}),
		Pup.E(40, -40, 4, 4, "#8ad0f000", {"ow": 0}),
		Pup.E(26, -52, 3.5, 3.5, "#ffffffcc", {"ow": 0, "a": [A("dy", -6.0, 1.0)]}),
		Pup.E(32, -60, 3.0, 3.0, "#ffffffcc", {"ow": 0, "a": [A("dy", -6.0, 1.0, 2.0)]}),
	]

# Dumbomaton: Forge/Aether. Fussy clockwork dumbo octopus + Antikythera mechanism + clock
static func _dumbomaton() -> Array:
	var body := "#7a8fc8"
	var brass := "#d6a84a"
	var parts: Array = []
	for i in 4:
		var x := -24.0 + i * 16.0
		parts.append(Pup.leg([[x, -26, 8], [x + (i - 1.5) * 4, -14, 7], [x + (i - 1.5) * 9, -2, 6]], "#5f73ad", i * 1.3, x, -28, 22.0))
	parts.append_array([
		Pup.E(-30, -64, 14, 18, "#9aaee0", {"rot": -20.0, "a": [A("rot", 14.0, 2.0, 0.0, -22, -56)]}),
		Pup.E(0, -54, 30, 28, body, {"wob": 0.03, "seed": 2.0}),
		Pup.E(30, -64, 14, 18, "#9aaee0", {"rot": 20.0, "a": [A("rot", -14.0, 2.0, 0.0, 22, -56)]}),
		Pup.E(-14, -46, 2.8, 2.8, brass, {"ow": 1.5}),
		Pup.E(16, -42, 2.8, 2.8, brass, {"ow": 1.5}),
		Pup.E(10, -72, 2.8, 2.8, brass, {"ow": 1.5}),
		Pup.S(2, -90, 17, 10, brass, {"in": 0.78, "a": [A("rot", 30.0, 1.0, 0, 0, 0)]}),
		Pup.E(2, -90, 6, 6, "#fff4d0", {"ow": 2.5}),
		Pup.EYE(6, -58, 11, "bug"),
		Pup.EYE(-14, -62, 5.5, "bug"),
		Pup.RING(6, -58, 13.5, 3.5, brass),
		Pup.MOUTH(4, -40, 12, "flat", {"atk": "o"}),
		Pup.T([[-8, -44, 1.6], [0, -44, 1.6]], "#2b1a3d", {"ow": 0}),
		Pup.T([[26, -46, 6], [40, -58, 5], [46, -72, 5]], "#5f73ad", {"wave": 3.0, "a": [A("rot", 16.0, 2.0, 0, 26, -46, 60.0)], "hand": true}),
		Pup.P([[44, -72], [56, -78], [58, -70], [48, -66]], "#c9d0e4", {"ow": 2.5, "a": [A("rot", 16.0, 2.0, 0, 26, -46, 60.0)]}),
	])
	return parts

# Colukite: Gale/Aether. Thrill-seeking colugo + Icarus + kite
static func _colukite() -> Array:
	var fur := "#9a8a78"
	var mem := "#d8c8aa"
	return [
		Pup.P([[-6, -56], [-56, -100], [-74, -40], [-30, -30]], mem, {"ow": 3.0, "a": [A("rot", 7.0, 1.0, 0.0, -6, -50)]}),
		Pup.T([[-10, -52, 2], [-56, -94, 2]], "#a89878", {"ow": 0}),
		Pup.T([[-10, -50, 2], [-66, -44, 2]], "#a89878", {"ow": 0}),
		Pup.T([[-68, -42, 2.2], [-82, -30, 2.2], [-92, -46, 2.2], [-104, -34, 2.2]], "#f0e8d0", {"wave": 6.0, "wcyc": 2.0, "ow": 1.5}),
		Pup.E(-84, -32, 4, 4, "#d8403a", {"ow": 1.8, "a": [A("dy", 3.0, 2.0)]}),
		Pup.E(-98, -42, 4, 4, "#4aa0d8", {"ow": 1.8, "a": [A("dy", 3.0, 2.0, 2.0)]}),
		Pup.leg([[-4, -24, 6], [-6, -12, 5], [-10, -1, 5]], "#7a6a58", 0.0, -4, -26, 20.0),
		Pup.leg([[10, -24, 6], [12, -12, 5], [16, -1, 5]], "#7a6a58", PI, 10, -26, 20.0),
		Pup.E(2, -42, 17, 22, fur, {"wob": 0.04, "seed": 2.0}),
		Pup.E(6, -38, 10, 14, "#cdbfae", {"ow": 0}),
		Pup.E(14, -70, 14, 13, fur, {"wob": 0.03, "seed": 3.0}),
		Pup.E(4, -80, 5, 6, fur, {"rot": -10.0}),
		Pup.E(26, -80, 5, 6, fur, {"rot": 10.0}),
		Pup.P([[10, -84], [8, -98], [16, -88]], "#ffe08a", {"ow": 2.0}),
		Pup.P([[16, -86], [20, -100], [24, -86]], "#ffffff", {"ow": 2.0}),
		Pup.EYE(18, -72, 6.5, "bug"),
		Pup.RING(18, -72, 8.8, 3.0, "#4a6a8a"),
		Pup.T([[10, -74, 2.5], [4, -72, 2.5], [-2, -66, 2.5]], "#4a6a8a", {"ow": 0}),
		Pup.MOUTH(26, -62, 9, "grin", {"atk": "o"}),
		Pup.P([[10, -52], [48, -90], [60, -44], [24, -34]], mem, {"ow": 3.0, "a": [A("rot", -9.0, 1.0, 0.0, 10, -50)]}),
		Pup.T([[14, -50, 2], [52, -84, 2]], "#a89878", {"ow": 0, "a": [A("rot", -9.0, 1.0, 0.0, 10, -50)]}),
	]

# Gilamancer: Venom/Spirit. Sly beaded-lizard sorceress + Circe + hand mirror
static func _gilamancer() -> Array:
	var ink := "#4a3f66"
	var parts: Array = [
		Pup.T([[-34, -26, 12], [-50, -22, 8], [-64, -30, 5]], ink, {"wave": 4.0}),
		Pup.leg([[-18, -18, 11], [-20, -7, 10]], "#352c4e", 0.0, -18, -20, 16.0),
		Pup.E(0, -32, 34, 18, ink, {"wob": 0.05, "seed": 2.0}),
	]
	for i in 8:
		parts.append(Pup.E(-26 + i * 7.5, -42 + (i % 2) * 5, 3.2, 3.2, "#ff8a2b", {"ow": 1.5}))
	parts.append_array([
		Pup.leg([[16, -18, 11], [18, -7, 10]], "#352c4e", PI, 16, -20, 16.0),
		Pup.T([[20, -30, 7], [32, -22, 6], [40, -32, 5]], ink, {"wave": 3.0, "hand": true, "a": [A("rot", 10.0, 1.0, 0, 20, -30, 40.0)]}),
		Pup.E(46, -48, 14, 14, "#9fd8ff55", {"ow": 0}),
		Pup.RING(46, -48, 11.5, 4.0, "#d6a84a", {"a": [A("dy", 2.0, 1.0)]}),
		Pup.E(46, -48, 9, 9, "#9fd8ff", {"ow": 0, "a": [A("dy", 2.0, 1.0)]}),
		Pup.S(46, -48, 5, 4, "#ffffff", {"ow": 0, "a": [A("rot", 40.0, 1.0)]}),
		Pup.E(36, -36, 17, 13, ink, {"wob": 0.04, "seed": 3.0}),
		Pup.E(46, -32, 9, 7, "#5e5280", {"ow": 0}),
		Pup.EYE(40, -40, 5.5, "angry", {"iris": "#c8a2ff", "squint": true}),
		Pup.MOUTH(50, -29, 10, "fang", {"atk": "o"}),
		Pup.E(55, -22, 2.2, 3.4, "#b44bd8", {"ow": 0, "a": [A("dy", 3.0, 2.0)]}),
		Pup.E(48, -52, 26, 5, "#4a1f70", {"ow": 3.0}),
		Pup.P([[32, -52], [44, -90], [60, -52]], "#5a2a8a", {"ow": 3.0}),
		Pup.P([[34, -58], [58, -58], [58, -54], [34, -54]], "#d6a84a", {"ow": 0}),
		Pup.S(46, -76, 6, 5, "#ffe36a", {"ow": 1.5, "a": [A("rot", 30.0, 1.0)]}),
	])
	return parts
