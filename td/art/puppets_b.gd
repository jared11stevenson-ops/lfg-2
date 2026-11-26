extends RefCounted
# Creature designs batch B: Zapnose, Glomm, Hoardillo, Mirewick.
const Pup = preload("res://art/puppet.gd")

static func A(kind: String, amp: float, cyc: float = 1.0, ph: float = 0.0, px: float = 0.0, py: float = 0.0, atk: float = 0.0) -> Dictionary:
	return Pup.A(kind, amp, cyc, ph, px, py, atk)

static func build(id: String) -> Array:
	match id:
		"zapnose": return _zapnose()
		"glomm": return _glomm()
		"hoardillo": return _hoardillo()
		"mirewick": return _mirewick()
	return []

# Zapnose: Volt/Aether. Caffeinated elephantnose fish + Nikola Tesla + doorbell
static func _zapnose() -> Array:
	var blue := "#3b57d6"
	return [
		Pup.P([[-24, -44], [-54, -64], [-50, -34]], "#2c40a8", {"a": [A("rot", 10.0, 2.0, 0.0, -24, -44)]}),
		Pup.leg([[-8, -22, 5], [-10, -11, 5], [-14, -1, 5]], "#ffd23a", 0.0, -8, -24, 24.0),
		Pup.E(0, -46, 28, 23, blue, {"wob": 0.04, "seed": 2.0}),
		Pup.E(6, -40, 18, 14, "#9fb4ff", {"ow": 0}),
		Pup.T([[-16, -62, 4], [-10, -46, 4], [-4, -62, 4], [2, -46, 4], [8, -62, 4]], "#ffd23a", {"ow": 1.2}),
		Pup.leg([[10, -22, 5], [12, -11, 5], [18, -1, 5]], "#ffd23a", PI, 10, -24, 24.0),
		Pup.T([[10, -46, 6], [22, -38, 5], [30, -46, 5]], blue, {"hand": true, "wave": 3.0, "a": [A("rot", 28.0, 2.0, 0, 10, -46, 70.0)]}),
		Pup.P([[4, -82], [-4, -106], [12, -86]], "#fff3a0", {"a": [A("rot", 8.0, 3.0, 0, 8, -84)]}),
		Pup.P([[12, -86], [14, -114], [22, -88]], "#ffffff", {"a": [A("rot", 8.0, 3.0, 1.0, 16, -86)]}),
		Pup.P([[20, -84], [34, -104], [30, -80]], "#fff3a0", {"a": [A("rot", 8.0, 3.0, 2.0, 24, -84)]}),
		Pup.E(16, -70, 18, 16, blue, {"wob": 0.04, "seed": 4.0}),
		Pup.T([[28, -68, 10], [44, -62, 8], [56, -70, 7], [60, -84, 6]], "#6c8cff", {"wave": 4.0, "wcyc": 2.0}),
		Pup.E(60, -90, 15, 15, "#ffe68066", {"ow": 0}),
		Pup.E(60, -90, 8, 8, "#ffd23a", {"ow": 3.0, "a": [A("sq", 0.12, 2.0, 0, 60, -90)]}),
		Pup.EYE(12, -74, 7.5, "bug", {"squint": false}),
		Pup.EYE(24, -72, 5.0, "bug"),
		Pup.MOUTH(30, -58, 8, "o", {"atk": "grin"}),
	]

# Glomm: Stone/Frost. Gruff yeti-crab golem + Golem of Prague + snow globe
static func _glomm() -> Array:
	var stone := "#7b8aa8"
	var fur := "#eef5fb"
	var parts: Array = [
		Pup.leg([[-20, -22, 8], [-36, -14, 7], [-44, 0, 7]], "#59647c", 0.0, -20, -24, 14.0),
		Pup.leg([[-6, -20, 8], [-14, -10, 7], [-16, 0, 7]], "#59647c", PI, -6, -22, 14.0),
		Pup.E(-46, -36, 14, 12, fur, {"wob": 0.1}),
		Pup.E(0, -44, 42, 34, stone, {"wob": 0.04, "seed": 1.0}),
		Pup.T([[-24, -64, 2.5], [-16, -52, 2.5], [-22, -42, 2.5]], "#4c5670", {"ow": 0}),
		Pup.T([[22, -60, 2.5], [28, -50, 2.5], [22, -44, 2.5]], "#4c5670", {"ow": 0}),
		Pup.P([[-22, -54], [24, -54], [20, -42], [-18, -42]], "#59647c", {"ow": 3.5}),
		Pup.EYE(-8, -48, 5.5, "glow", {"iris": "#9be7ff"}),
		Pup.EYE(12, -48, 5.5, "glow", {"iris": "#9be7ff"}),
		Pup.MOUTH(2, -30, 18, "flat", {"atk": "o"}),
	]
	for i in 8:
		parts.append(Pup.P([[-34 + i * 10, -14], [-29 + i * 10, -3], [-24 + i * 10, -14]], fur, {"ow": 2.0}))
	parts.append_array([
		Pup.T([[34, -40, 12], [48, -34, 11]], stone, {}),
		Pup.S(56, -34, 26, 9, fur, {"in": 0.6, "ow": 2.5}),
		Pup.E(56, -34, 17, 15, fur, {"wob": 0.08, "ow": 3.0, "a": [A("rot", 10.0, 1.0, 0, 40, -36, 40.0)]}),
		Pup.P([[-14, -78], [14, -78], [10, -68], [-10, -68]], "#a2763a", {"ow": 3.0}),
		Pup.E(0, -96, 22, 22, "#cfeaffaa", {"ow": 3.0}),
		Pup.P([[-7, -90], [0, -110], [7, -90]], "#3f8a3a", {"ow": 2.0}),
		Pup.E(-9, -100, 2, 2, Color.WHITE, {"ow": 0, "a": [A("dy", 4.0, 1.0, 0.0)]}),
		Pup.E(8, -96, 2, 2, Color.WHITE, {"ow": 0, "a": [A("dy", 4.0, 1.0, 2.0)]}),
		Pup.E(2, -104, 2, 2, Color.WHITE, {"ow": 0, "a": [A("dy", 4.0, 1.0, 4.0)]}),
	])
	return parts

# Hoardillo: Stone/Forge. Smug pink fairy armadillo + Fafnir's hoard + piggy bank
static func _hoardillo() -> Array:
	var pink := "#e69ab0"
	var plate := "#c46f8e"
	return [
		Pup.P([[-30, -30], [-56, -26], [-30, -20]], pink, {"a": [A("rot", 8.0, 2.0, 0, -30, -26)]}),
		Pup.leg([[-14, -18, 11], [-16, -7, 10]], "#d07a98", 0.0, -14, -20, 16.0),
		Pup.E(0, -40, 36, 28, pink, {"wob": 0.04, "seed": 1.0}),
		Pup.E(-14, -56, 13, 8, plate, {"rot": -25.0}),
		Pup.E(2, -64, 15, 8, plate, {"rot": -5.0}),
		Pup.E(18, -58, 13, 8, plate, {"rot": 25.0}),
		Pup.P([[-9, -72], [9, -72], [9, -67], [-9, -67]], "#2a1a22", {"ow": 2.0}),
		Pup.E(0, -80, 9, 11, "#ffd23a", {"ow": 3.0, "a": [A("dy", -3.0, 2.0)]}),
		Pup.T([[0, -86, 1.8], [0, -75, 1.8]], "#c4962a", {"ow": 0, "a": [A("dy", -3.0, 2.0)]}),
		Pup.leg([[16, -18, 11], [18, -7, 10]], "#d07a98", PI, 16, -20, 16.0),
		Pup.P([[24, -54], [26, -70], [32, -54]], "#f6ecd0", {"ow": 2.5}),
		Pup.P([[34, -52], [40, -68], [42, -50]], "#f6ecd0", {"ow": 2.5}),
		Pup.E(32, -40, 17, 15, pink, {"wob": 0.03, "seed": 3.0}),
		Pup.E(46, -35, 10, 8, "#f4c4d2", {"ow": 3.0}),
		Pup.E(48, -37, 1.6, 1.6, "#2b1a3d", {"ow": 0}),
		Pup.EYE(30, -46, 4.5, "dot"),
		Pup.EYE(40, -45, 4.0, "dot"),
		Pup.T([[24, -52, 2.2], [35, -54, 2.2]], "#2b1a3d", {"ow": 0}),
		Pup.MOUTH(42, -29, 11, "grin", {"atk": "o"}),
		Pup.E(44, -26, 1.8, 2.4, "#ffd23a", {"ow": 0}),
		Pup.S(-26, -74, 6, 4, "#fff3a0", {"ow": 1.5, "a": [A("rot", 30.0, 1.0)]}),
	]

# Mirewick: Verdant/Spirit. Creepy-curious aye-aye + will-o'-the-wisp + kettle
static func _mirewick() -> Array:
	var kettle := "#3d6b56"
	var moss := "#5f9c7e"
	return [
		Pup.leg([[-8, -22, 6], [-10, -11, 5], [-16, -1, 5]], "#2f5545", 0.0, -8, -24, 22.0),
		Pup.E(0, -44, 28, 25, kettle, {"wob": 0.03, "seed": 2.0}),
		Pup.E(-6, -38, 14, 11, "#4f8a6e", {"ow": 0}),
		Pup.leg([[10, -22, 6], [12, -11, 5], [18, -1, 5]], "#2f5545", PI, 10, -24, 22.0),
		Pup.E(-12, -67, 13, 5, "#2f5545", {"ow": 3.0}),
		Pup.E(-12, -73, 3.5, 3.5, "#2f5545", {"ow": 2.0}),
		Pup.P([[-22, -76], [-12, -108], [-2, -76]], "#7fffd0", {"ow": 2.5, "a": [A("rot", 6.0, 2.0, 0.0, -12, -76)]}),
		Pup.P([[-17, -76], [-12, -96], [-7, -76]], "#d8fff0", {"ow": 0, "a": [A("rot", 8.0, 2.0, 0.6, -12, -76)]}),
		Pup.E(-34, -94, 3.0, 3.0, "#b6ffe8", {"ow": 1.5, "a": [A("dy", 5.0, 1.0, 0.0)]}),
		Pup.T([[8, -44, 7], [22, -34, 5], [34, -42, 4], [42, -54, 3]], "#2f5545", {"wave": 3.0, "hand": true, "a": [A("rot", 12.0, 1.0, 0, 8, -44, 50.0)]}),
		Pup.E(44, -62, 12, 12, "#fff3a055", {"ow": 0}),
		Pup.E(44, -60, 6, 7.5, "#fff3a0", {"ow": 2.5}),
		Pup.E(-2, -86, 13, 17, moss, {"rot": -15.0}),
		Pup.E(-2, -86, 8, 12, "#2a1f2e", {"rot": -15.0, "ow": 0}),
		Pup.E(14, -70, 17, 15, moss, {"wob": 0.03, "seed": 1.0}),
		Pup.E(30, -84, 13, 17, moss, {"rot": 15.0}),
		Pup.E(30, -84, 8, 12, "#2a1f2e", {"rot": 15.0, "ow": 0}),
		Pup.EYE(10, -72, 7.5, "glow", {"iris": "#c8ff6a"}),
		Pup.EYE(24, -70, 6.0, "glow", {"iris": "#c8ff6a"}),
		Pup.MOUTH(21, -59, 9, "o", {"atk": "fang"}),
	]
