extends RefCounted
# Loads and draws baked puppet frames (tools/bake_puppets.gd). Sprites face right; pass flip for left.
const FRAMES := {"idle": 6, "walk": 8, "attack": 5}
const AnimMeta = preload("res://anim_meta.gd")
const ORIGIN := Vector2(105, 173)   # ground point inside the 192px frame
const SIZE := 192.0
static var _cache := {}
const BLENDER_DIR := "res://art/blender/frames/"   # frames baked from Blender models take priority over 2D puppets

# Soft contact shadow matching the map's key light (upper left): offset to the lower right, layered for a soft edge.
static func shadow(ci: CanvasItem, k: float = 1.0, base: Vector2 = Vector2(0, 8)) -> void:
	ci.draw_set_transform(base + Vector2(9, 5) * k, 0.1, Vector2(1.35 * k, 0.42 * k))
	ci.draw_circle(Vector2.ZERO, 24.0, Color(0.02, 0.0, 0.06, 0.12))
	ci.draw_circle(Vector2.ZERO, 19.0, Color(0.02, 0.0, 0.06, 0.16))
	ci.draw_circle(Vector2.ZERO, 13.0, Color(0.02, 0.0, 0.06, 0.2))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Starts loading every frame of the given sprite ids in the background so a species' first appearance never hitches.
static func prewarm(ids: Array) -> void:
	for id in ids:
		var m := meta(String(id))
		for state in FRAMES:
			var n := int(m.counts.get(state, FRAMES[state])) if not m.is_empty() else int(FRAMES[state])
			for i in n:
				var key := "%s_%s_%d" % [id, state, i]
				var bpath := BLENDER_DIR + key + ".png"
				if ResourceLoader.exists(bpath):
					ResourceLoader.load_threaded_request(bpath)

static func tex(id: String, state: String, i: int) -> Texture2D:
	var key := "%s_%s_%d" % [id, state, i]
	if not _cache.has(key):
		var bpath := BLENDER_DIR + key + ".png"
		var path := "res://art/puppets/%s.png" % key
		if ResourceLoader.exists(bpath):
			_cache[key] = load(bpath)
		else:
			_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]

# Per-creature animation data from the Blender rig bakes (frame counts, strike frame, anchors); empty for 2D puppet creatures.
static func meta(id: String) -> Dictionary:
	return AnimMeta.META.get(id.get_slice("_", 0), {})

static func frame_count(state: String, id: String = "") -> int:
	var m := meta(id) if id != "" else {}
	if not m.is_empty():
		return int(m.counts.get(state, 1))
	return int(FRAMES.get(state, 1))

# Draws the creature with its ground point at the CanvasItem origin + off. scale = px per design unit.
static func draw(ci: CanvasItem, id: String, state: String, frame: int, flip: bool, scale: float, off: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE, rot: float = 0.0, squash: Vector2 = Vector2.ONE) -> bool:
	var f := posmod(frame, frame_count(state, id))
	var t := tex(id, state, f)
	if t == null and id.contains("_"):
		t = tex(id.get_slice("_", 0), state if state != "walk" else "walk", f)
	if t == null:
		return false
	ci.draw_set_transform(off, rot, Vector2(squash.x * (-1.0 if flip else 1.0), squash.y))
	var m := meta(id)
	var org: Vector2 = ORIGIN if (m.is_empty() or not m.has("origin")) else Vector2(float(m.origin[0]), float(m.origin[1]))
	ci.draw_texture_rect(t, Rect2(-org * scale, Vector2(SIZE, SIZE) * scale), false, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
