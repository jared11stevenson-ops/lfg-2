extends RefCounted
# Creature designs batch D: Pyrelope, Mudskip, Thornarok, Ptarmitten.
const Pup = preload("res://art/puppet.gd")

static func A(kind: String, amp: float, cyc: float = 1.0, ph: float = 0.0, px: float = 0.0, py: float = 0.0, atk: float = 0.0) -> Dictionary:
	return Pup.A(kind, amp, cyc, ph, px, py, atk)

static func build(id: String) -> Array:
	match id:
		"pyrelope": return _pyrelope()
		"mudskip": return _mudskip()
		"thornarok": return _thornarok()
		"ptarmitten": return _ptarmitten()
	return []

# Pyrelope: Ember/Spirit. Cheerful saiga antelope + phoenix + birthday candles
static func _pyrelope() -> Array:
	var cream := "#e8c48a"
	return [
		Pup.P([[-24, -54], [-54, -74], [-42, -46]], "#ff8a2b", {"ow": 3.0, "a": [A("rot", 6.0, 2.0, 0.0, -24, -54)]}),
		Pup.P([[-24, -48], [-60, -54], [-42, -38]], "#ffd23a", {"ow": 3.0, "a": [A("rot", 6.0, 2.0, 0.8, -24, -48)]}),
		Pup.P([[-24, -58], [-46, -88], [-34, -54]], "#ff5a3a", {"ow": 3.0, "a": [A("rot", 6.0, 2.0, 1.6, -24, -58)]}),
		Pup.leg([[-12, -28, 7], [-14, -14, 6], [-18, -1, 5]], "#c49a5a", 0.0, -12, -30, 20.0),
		Pup.leg([[12, -28, 7], [14, -14, 6], [20, -1, 5]], "#c49a5a", PI, 12, -30, 20.0),
		Pup.E(0, -46, 28, 22, cream, {"wob": 0.04, "seed": 1.0}),
		Pup.E(6, -40, 18, 14, "#f8e8c8", {"ow": 0}),
		Pup.T([[16, -56, 12], [22, -70, 10]], cream, {}),
		Pup.T([[18, -80, 4], [14, -98, 4]], "#fff0f6", {"ow": 2.5}),
		Pup.S(14, -108, 8, 5, "#ffd23a", {"in": 0.45, "a": [A("dy", 2.0, 3.0)]}),
		Pup.T([[30, -82, 4], [34, -98, 4]], "#fff0f6", {"ow": 2.5}),
		Pup.S(34, -108, 8, 5, "#ff8a2b", {"in": 0.45, "a": [A("dy", 2.0, 3.0, 1.0)]}),
		Pup.E(24, -74, 16, 13, cream, {"wob": 0.03, "seed": 2.0}),
		Pup.E(42, -68, 13, 11, "#f4d6a8", {"ow": 3.0}),
		Pup.E(40, -68, 2.6, 2.6, "#2b1a3d", {"ow": 0}),
		Pup.E(46, -66, 2.6, 2.6, "#2b1a3d", {"ow": 0}),
		Pup.EYE(24, -78, 6.5, "bug"),
		Pup.E(30, -70, 5, 3.5, "#ff9ab0aa", {"ow": 0}),
		Pup.MOUTH(44, -57, 8, "smile", {"atk": "o"}),
	]

# Mudskip: Tide/Volt. Laid-back mudskipper + Nessie + rubber boot
static func _mudskip() -> Array:
	var teal := "#5ab0a0"
	return [
		Pup.E(-48, -18, 10, 10, teal, {"ow": 3.0}),
		Pup.E(-34, -24, 13, 13, teal, {"ow": 3.0}),
		Pup.T([[-56, -12, 8], [-70, -10, 5], [-82, -18, 3]], teal, {"wave": 4.0}),
		Pup.E(0, -34, 28, 21, teal, {"wob": 0.04, "seed": 1.0}),
		Pup.E(6, -28, 19, 13, "#d4e8a8", {"ow": 0}),
		Pup.E(-12, -42, 4, 3.5, "#2a6a62", {"ow": 0}),
		Pup.E(2, -46, 4, 3.5, "#2a6a62", {"ow": 0}),
		Pup.E(-6, -22, 11, 11, "#f2c94a", {"ow": 3.0, "a": [A("rot", 10.0, 1.0, 0.0, -6, -26)]}),
		Pup.E(-6, -31, 11, 4, "#c4962a", {"ow": 2.5, "a": [A("rot", 10.0, 1.0, 0.0, -6, -26)]}),
		Pup.T([[16, -30, 9], [26, -20, 8], [32, -6, 7]], teal, {"hand": true, "wave": 3.0, "a": [A("rot", 16.0, 1.0, PI, 16, -30, 40.0)]}),
		Pup.E(22, -52, 16, 12, teal, {"wob": 0.04, "seed": 3.0}),
		Pup.E(14, -66, 7.5, 7.5, teal, {"ow": 3.0}),
		Pup.E(30, -66, 7.5, 7.5, teal, {"ow": 3.0}),
		Pup.EYE(14, -68, 5.5, "round", {"iris": "#2b1a3d"}),
		Pup.EYE(30, -68, 5.5, "round", {"iris": "#2b1a3d"}),
		Pup.MOUTH(28, -48, 16, "grin", {"atk": "o"}),
		Pup.S(44, -34, 6, 4, "#ffe36a", {"ow": 1.5, "a": [A("rot", 40.0, 2.0)]}),
		Pup.S(-24, -52, 5, 4, "#ffe36a", {"ow": 1.5, "a": [A("rot", 40.0, 2.0, 1.0)]}),
	]

# Thornarok: Ember/Stone. Hot-headed thorny devil + Surtr + matchbox
static func _thornarok() -> Array:
	var sand := "#c9803a"
	var parts: Array = [
		Pup.T([[-34, -26, 12], [-50, -22, 8], [-64, -30, 5]], sand, {"wave": 4.0}),
		Pup.leg([[-18, -18, 11], [-20, -7, 10]], "#8a4a22", 0.0, -18, -20, 16.0),
		Pup.E(0, -32, 36, 19, sand, {"wob": 0.06, "seed": 2.0}),
		Pup.T([[-24, -36, 2.5], [-12, -30, 2.5], [-4, -38, 2.5], [8, -30, 2.5]], "#ff6a2a", {"ow": 0}),
	]
	for i in 8:
		parts.append(Pup.P([[-32 + i * 9, -44], [-28 + i * 9, -60 - (i % 2) * 6], [-23 + i * 9, -44]], "#e0a55a", {"ow": 2.5}))
	parts.append_array([
		Pup.leg([[16, -18, 11], [18, -7, 10]], "#8a4a22", PI, 16, -20, 16.0),
		Pup.P([[-14, -56], [14, -56], [14, -42], [-14, -42]], "#c43a3a", {"ow": 3.0}),
		Pup.P([[-14, -49], [14, -49], [14, -45], [-14, -45]], "#3a2a2a", {"ow": 0}),
	])
	for i in 5:
		parts.append(Pup.T([[-10 + i * 5, -56, 2.5], [-10 + i * 5, -66, 2.5]], "#f2e2b0", {"ow": 1.0}))
		parts.append(Pup.E(-10 + i * 5, -68, 3.2, 3.6, "#ff5a2a", {"ow": 1.5, "a": [A("dy", 1.0, 3.0, i)]}))
	parts.append_array([
		Pup.P([[28, -42], [24, -64], [38, -46]], "#e8602a", {"ow": 3.0}),
		Pup.S(24, -68, 6, 4, "#ffd23a", {"in": 0.45, "a": [A("dy", 2.0, 3.0)]}),
		Pup.P([[38, -44], [44, -62], [48, -44]], "#e8602a", {"ow": 3.0}),
		Pup.E(38, -34, 16, 13, sand, {"wob": 0.03, "seed": 4.0}),
		Pup.EYE(42, -38, 5.5, "angry", {"iris": "#ffe36a", "squint": true}),
		Pup.MOUTH(48, -26, 10, "fang", {"atk": "o"}),
	])
	return parts

# Ptarmitten: Frost/Gale. Polite ptarmigan + Snow Maiden + mitten
static func _ptarmitten() -> Array:
	return [
		Pup.leg([[-8, -18, 6], [-10, -8, 5], [-12, -1, 5]], "#f08a3a", 0.0, -8, -20, 18.0),
		Pup.E(-12, 0, 9, 3.5, "#f4f6fa", {"ow": 2.0}),
		Pup.E(0, -40, 28, 26, "#f4f6fa", {"wob": 0.05, "seed": 1.0}),
		Pup.E(6, -34, 18, 16, "#e4ecf8", {"ow": 0}),
		Pup.leg([[8, -18, 6], [10, -8, 5], [14, -1, 5]], "#f08a3a", PI, 8, -20, 18.0),
		Pup.T([[-4, -44, 8], [-14, -38, 7], [-8, -30, 6]], "#f4f6fa", {"wave": 3.0, "hand": true, "a": [A("rot", 12.0, 1.0, 0, -4, -44)]}),
		Pup.T([[-4, -58, 7], [-24, -52, 6], [-36, -60, 5]], "#4aa0d8", {"wave": 7.0, "wcyc": 2.0}),
		Pup.T([[-30, -54, 2], [-32, -62, 2]], "#f4f6fa", {"ow": 0, "wave": 3.0}),
		Pup.E(14, -62, 16, 14, "#f4f6fa", {"wob": 0.04, "seed": 3.0}),
		Pup.T([[2, -60, 9], [14, -56, 9], [26, -60, 8]], "#4aa0d8", {}),
		Pup.E(10, -86, 15, 20, "#d8403a", {"rot": 12.0}),
		Pup.E(-3, -88, 6, 9, "#d8403a", {"rot": 12.0}),
		Pup.E(14, -72, 15, 4.5, "#f6f0e0", {"rot": 12.0}),
		Pup.P([[24, -64], [36, -60], [24, -56]], "#f08a3a", {"ow": 2.5}),
		Pup.EYE(15, -66, 4.5, "dot"),
		Pup.EYE(24, -65, 4.0, "dot"),
		Pup.E(10, -58, 5, 3.2, "#ff9ab0aa", {"ow": 0}),
		Pup.MOUTH(28, -56, 6, "smile", {"atk": "o"}),
		Pup.E(-26, -74, 2.2, 2.2, Color.WHITE, {"ow": 0, "a": [A("dy", 5.0, 1.0)]}),
		Pup.E(36, -86, 2.2, 2.2, Color.WHITE, {"ow": 0, "a": [A("dy", 5.0, 1.0, 2.0)]}),
	]
