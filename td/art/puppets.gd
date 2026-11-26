extends RefCounted
# Creature designs as 2D puppets. Origin = ground point between the feet, y grows downward (so up is negative).
# Everything faces +x (right); the game flips for the other direction. See puppet.gd for the part vocabulary.
const Pup = preload("res://art/puppet.gd")

static func A(kind: String, amp: float, cyc: float = 1.0, ph: float = 0.0, px: float = 0.0, py: float = 0.0, atk: float = 0.0) -> Dictionary:
	return Pup.A(kind, amp, cyc, ph, px, py, atk)

static func leg(pts: Array, col, ph: float, px: float, py: float, amp: float = 22.0) -> Dictionary:
	return Pup.leg(pts, col, ph, px, py, amp)

static func build(id: String, variant: String = "") -> Array:
	var parts: Array = []
	match id:
		"tickindle": parts = _tickindle()
		"dugloom": parts = _dugloom()
		"hutzin": parts = _hutzin()
		"shuckit": parts = _shuckit()
		_: parts = _other(id)
	if variant != "":
		parts.append_array(_evolve(id, variant))
	return parts

static func _other(id: String) -> Array:
	for path in ["res://art/puppets_b.gd", "res://art/puppets_c.gd", "res://art/puppets_d.gd", "res://art/puppets_e.gd"]:
		if ResourceLoader.exists(path):
			var r: Array = load(path).build(id)
			if not r.is_empty():
				return r
	return [Pup.E(0, -30, 20, 20, "#ff00ff")]

# Anchors (head top / shoulder) for evolved-form accessories.
const ANCHOR := {
	"tickindle": {"head": [8, -90], "back": [-20, -50]},
	"dugloom": {"head": [20, -80], "back": [-14, -50]},
	"hutzin": {"head": [18, -112], "back": [-14, -60]},
	"shuckit": {"head": [26, -96], "back": [-6, -46]},
	"zapnose": {"head": [14, -104], "back": [-14, -60]}, "glomm": {"head": [0, -112], "back": [-30, -60]},
	"hoardillo": {"head": [32, -64], "back": [-20, -60]}, "mirewick": {"head": [14, -100], "back": [-16, -60]},
	"gloamoth": {"head": [8, -104], "back": [-14, -60]}, "bogbard": {"head": [16, -90], "back": [-14, -50]},
	"quillwyrm": {"head": [30, -56], "back": [-10, -58]}, "drumbeak": {"head": [16, -128], "back": [-6, -84]},
	"pyrelope": {"head": [22, -92], "back": [-14, -62]}, "mudskip": {"head": [22, -78], "back": [-10, -48]},
	"thornarok": {"head": [36, -52], "back": [-20, -50]}, "ptarmitten": {"head": [10, -102], "back": [-10, -56]},
	"tentbat": {"head": [8, -78], "back": [-14, -62]}, "dumbomaton": {"head": [2, -100], "back": [-24, -72]},
	"colukite": {"head": [14, -86], "back": [-12, -60]}, "gilamancer": {"head": [34, -62], "back": [-20, -50]},
}

static func _evolve(id: String, variant: String) -> Array:
	var an: Dictionary = ANCHOR.get(id, {"head": [0, -90], "back": [-10, -50]})
	var h: Array = an.head
	var b: Array = an.back
	var out: Array = []
	if variant == "a":   # ascended: halo + orbiting stars
		out.append(Pup.RING(h[0], h[1] - 16, 16, 5, "#ffe36a", {"a": [A("dy", 3.0, 1.0)]}))
		for i in 3:
			out.append(Pup.S(h[0] - 34 + i * 34, h[1] + 6 - (i % 2) * 22, 7, 5, "#fff3a0", {"a": [A("dy", 5.0, 1.0, i * 2.1), A("rot", 25.0, 1.0, i, 0, 0)]}))
	else:                # armored: spiked pauldrons + warband
		out.append(Pup.E(b[0] + 6, b[1] - 6, 14, 10, "#59607a", {"ow": 3.5}))
		for i in 3:
			out.append(Pup.P([[b[0] - 6 + i * 9, b[1] - 12], [b[0] - 2 + i * 9, b[1] - 28], [b[0] + 4 + i * 9, b[1] - 12]], "#c9d0e4", {"ow": 2.5}))
		out.append(Pup.P([[h[0] - 16, h[1] + 12], [h[0] + 16, h[1] + 12], [h[0] + 16, h[1] + 20], [h[0] - 16, h[1] + 20]], "#d8504a", {"ow": 3.0}))
	return out

# --- Tickindle: Ember/Forge. Grumpy manul + Hephaestus's automatons + pocket watch ---
static func _tickindle() -> Array:
	var fur := "#7a6a8e"
	var dark := "#4f4263"
	return [
		Pup.T([[-24, -34, 13], [-38, -48, 11], [-46, -66, 9]], fur, {"wave": 4.0, "wcyc": 1.0}),
		Pup.S(-46, -82, 13, 5, "#ff8a2b", {"in": 0.45, "a": [A("dy", 2.0, 2.0)]}),
		Pup.S(-46, -80, 7, 5, "#ffd94a", {"in": 0.45, "ow": 0}),
		leg([[-12, -14, 11], [-14, -7, 10]], dark, 0.0, -12, -16, 18.0),
		leg([[16, -14, 11], [18, -7, 10]], dark, PI, 16, -16, 18.0),
		Pup.E(0, -38, 31, 26, fur, {"wob": 0.05, "seed": 1.0}),
		Pup.E(8, -32, 20, 17, "#f2dfc0", {"ow": 0}),
		Pup.P([[-30, -58], [-22, -66], [-14, -58], [-22, -52]], "#e8c15a", {"a": [A("rot", 25.0, 1.0, 0, -22, -58)]}),
		Pup.E(10, -32, 11, 11, "#f0c94a", {"ow": 3.0}),
		Pup.E(10, -32, 7, 7, "#fff4d0", {"ow": 1.5}),
		Pup.T([[10, -32, 2.5], [10, -39, 2.5]], "#c43c00", {"ow": 0.5, "a": [A("rot", 360.0 * 0.5, 1.0, 0, 10, -32)]}),
		Pup.P([[-6, -88], [0, -106], [8, -88]], fur, {"ow": 3.0, "a": [A("rot", 6.0, 2.0, 0, 0, -86)]}),
		Pup.P([[18, -88], [26, -104], [32, -86]], fur, {"ow": 3.0}),
		Pup.E(10, -66, 29, 22, fur, {"wob": 0.04, "seed": 2.0}),
		Pup.E(-12, -62, 9, 8, "#9a8cae", {"ow": 0}),
		Pup.E(32, -62, 9, 8, "#9a8cae", {"ow": 0}),
		Pup.EYE(1, -70, 7, "angry", {"iris": "#ffe36a", "squint": true}),
		Pup.EYE(20, -70, 7, "angry", {"iris": "#ffe36a", "flip": true, "squint": true}),
		Pup.E(10, -60, 3.5, 2.6, "#ee9aa8", {"ow": 2.0}),
		Pup.MOUTH(10, -52, 12, "frown", {"atk": "o"}),
	]

# --- Dugloom: Tide/Spirit. Dreamy dugong + selkie lore + lighthouse lamp ---
static func _dugloom() -> Array:
	var teal := "#58b6b0"
	var light := "#b8e6df"
	return [
		Pup.T([[-30, -30, 15], [-44, -28, 12], [-52, -36, 10]], teal, {"wave": 3.0}),
		Pup.E(-56, -46, 14, 7, teal, {"rot": -35.0, "a": [A("rot", 8.0, 1.0)]}),
		Pup.E(-56, -26, 14, 7, teal, {"rot": 35.0, "a": [A("rot", -8.0, 1.0)]}),
		Pup.T([[0, -34, 11], [-8, -24, 10], [-12, -16, 9]], "#47a39d", {"wave": 2.0, "wcyc": 1.0}),
		Pup.E(0, -34, 35, 29, teal, {"wob": 0.05, "seed": 0.5}),
		Pup.E(6, -24, 25, 18, light, {"ow": 0}),
		Pup.T([[10, -30, 12], [20, -20, 11], [28, -12, 10]], teal, {"wave": 4.0, "a": [A("rot", 14.0, 1.0, 0, 10, -30)], "hand": true}),
		Pup.E(20, -58, 23, 21, teal, {"wob": 0.04, "seed": 1.4}),
		Pup.E(37, -53, 13, 10, "#d4f2ec", {"ow": 3.0}),
		Pup.P([[34, -45], [37, -45], [35.5, -36]], "#ffffff", {"ow": 2.0}),
		Pup.E(38, -57, 1.8, 1.8, "#2b1a3d", {"ow": 0}),
		Pup.E(26, -52, 6, 4, "#ff9ab0aa", {"ow": 0}),
		Pup.EYE(26, -66, 6.5, "sleepy", {"lid": "#58b6b0"}),
		Pup.T([[40, -50, 1.8], [54, -52, 1.4]], "#2b1a3d", {"ow": 0}),
		Pup.T([[40, -47, 1.8], [54, -44, 1.4]], "#2b1a3d", {"ow": 0}),
		Pup.MOUTH(37, -47, 9, "smile", {"atk": "o"}),
		Pup.T([[14, -76, 3.5], [8, -96, 3.5], [20, -112, 3.5], [34, -112, 3.5]], "#9a7a5a", {"wave": 3.0, "wcyc": 1.0}),
		Pup.E(36, -108, 17, 17, "#ffe68055", {"ow": 0, "a": [A("sq", 0.08, 1.0, 0, 36, -108)]}),
		Pup.E(36, -108, 9, 9, "#ffe680", {"ow": 3.0, "a": [A("sq", 0.08, 1.0, 0, 36, -108)]}),
		Pup.E(-8, -74, 3.5, 3.5, "#bff6ff", {"ow": 1.5, "a": [A("dy", 5.0, 1.0, 0)]}),
		Pup.E(-20, -62, 2.5, 2.5, "#bff6ff", {"ow": 1.2, "a": [A("dy", 4.0, 1.0, 2.0)]}),
	]

# --- Hutzin: Verdant/Venom. Manic hoatzin + Baba Yaga's hut + teapot ---
static func _hutzin() -> Array:
	var green := "#9cc54a"
	return [
		Pup.P([[-22, -50], [-50, -64], [-44, -48]], "#e8632b", {"ow": 3.0, "a": [A("rot", 5.0, 2.0, 0, -22, -50)]}),
		Pup.P([[-22, -44], [-52, -46], [-44, -34]], "#d4a62a", {"ow": 3.0}),
		leg([[-6, -24, 6], [-8, -12, 5.5], [-14, -1, 5]], "#e0a23b", 0.0, -6, -26, 24.0),
		Pup.E(0, -46, 27, 25, green, {"wob": 0.05, "seed": 3.0}),
		Pup.E(7, -40, 17, 16, "#e6f3a8", {"ow": 0}),
		leg([[10, -24, 6], [12, -12, 5.5], [18, -1, 5]], "#e0a23b", PI, 10, -26, 24.0),
		Pup.T([[-4, -50, 8], [-14, -40, 7], [-8, -28, 6]], green, {"wave": 6.0, "wcyc": 2.0, "hand": true, "a": [A("rot", 35.0, 2.0, 0, -4, -50, 60.0)]}),
		Pup.T([[10, -62, 9], [16, -74, 8]], green, {}),
		Pup.T([[10, -66, 11], [-4, -70, 5]], "#00000000", {"ow": 0}),
		Pup.E(-10, -72, 21, 17, "#a8743f", {"wob": 0.03, "seed": 2.0}),
		Pup.P([[-34, -80], [-10, -106], [14, -80]], "#cf4b4b", {"ow": 3.0}),
		Pup.E(-10, -68, 5.5, 7.5, "#3b2412", {"ow": 2.0}),
		Pup.P([[-4, -100], [3, -100], [3, -114], [-4, -114]], "#8a8a96", {"ow": 2.5}),
		Pup.T([[10, -70, 7], [24, -78, 6], [30, -90, 5]], "#a8743f", {"wave": 1.5}),
		Pup.E(0, -122, 6, 6, "#d09aff", {"ow": 1.8, "a": [A("dy", -5.0, 1.0, 0)]}),
		Pup.E(6, -132, 4.5, 4.5, "#d09aff", {"ow": 1.5, "a": [A("dy", -5.0, 1.0, 2.0)]}),
		Pup.P([[6, -94], [-2, -114], [14, -98]], "#e8632b", {"ow": 3.0, "a": [A("rot", 5.0, 2.0, 0.4, 14, -94)]}),
		Pup.P([[14, -98], [14, -124], [24, -100]], "#f08a3a", {"ow": 3.0, "a": [A("rot", 5.0, 2.0, 1.2, 14, -98)]}),
		Pup.P([[22, -98], [32, -116], [30, -94]], "#e8632b", {"ow": 3.0, "a": [A("rot", 5.0, 2.0, 2.0, 24, -98)]}),
		Pup.E(19, -86, 14, 13, green, {"wob": 0.03, "seed": 5.0}),
		Pup.E(25, -83, 9, 8, "#59d2e6", {"ow": 2.0}),
		Pup.P([[31, -86], [46, -80], [31, -75]], "#f6c342", {"ow": 3.0}),
		Pup.EYE(15, -90, 6.5, "bug", {"iris": "#d6362b"}),
		Pup.EYE(26, -88, 4.5, "bug", {"iris": "#d6362b"}),
		Pup.MOUTH(34, -76, 10, "zig", {"atk": "o"}),
	]

# --- Shuckit: Umbra/Gale. Cheeky bat-eared fox + Black Shuck + broken umbrella ---
static func _shuckit() -> Array:
	var ink := "#4b4478"
	var rib := "#b0aed8"
	return [
		Pup.T([[-22, -36, 10], [-36, -42, 8], [-46, -56, 6], [-50, -70, 4]], ink, {"wave": 6.0}),
		leg([[-10, -26, 7], [-14, -13, 6], [-16, -1, 5]], "#332e58", 0.0, -10, -28, 26.0),
		leg([[8, -28, 7], [12, -14, 6], [16, -1, 5]], "#332e58", PI, 8, -28, 26.0),
		Pup.E(0, -40, 27, 15, ink, {"wob": 0.05, "seed": 4.0}),
		Pup.E(8, -36, 15, 8, "#6a64a4", {"ow": 0}),
		leg([[-4, -28, 7], [-6, -14, 6], [-8, -1, 5]], ink, PI, -4, -30, 26.0),
		leg([[16, -30, 7], [22, -15, 6], [26, -1, 5]], ink, 0.0, 16, -30, 26.0),
		Pup.P([[24, -62], [10, -100], [24, -104], [34, -64]], "#37316a", {"ow": 3.0, "a": [A("rot", 8.0, 2.0, 0.5, 28, -62)]}),
		Pup.T([[22, -64, 1.6], [14, -96, 1.2]], rib, {"ow": 0, "a": [A("rot", 8.0, 2.0, 0.5, 28, -62)]}),
		Pup.E(31, -52, 17, 14, ink, {"wob": 0.04, "seed": 1.0}),
		Pup.P([[38, -58], [58, -49], [38, -42]], ink, {"ow": 3.0}),
		Pup.E(58, -49, 3.5, 3, "#14121a", {"ow": 0}),
		Pup.T([[48, -41, 6], [49, -33, 6]], "#ff7a9a", {"ow": 2.5}),
		Pup.P([[30, -62], [26, -104], [42, -98], [42, -64]], ink, {"ow": 3.0, "a": [A("rot", -8.0, 2.0, 0.0, 36, -62)]}),
		Pup.T([[34, -64, 1.6], [34, -98, 1.2]], rib, {"ow": 0, "a": [A("rot", -8.0, 2.0, 0.0, 36, -62)]}),
		Pup.P([[24, -86], [20, -96], [28, -92]], "#00000000", {"ow": 0}),
		Pup.EYE(35, -56, 5.5, "glow"),
		Pup.EYE(25, -55, 4.2, "glow"),
		Pup.MOUTH(46, -46, 10, "smile", {"atk": "o"}),
	]
