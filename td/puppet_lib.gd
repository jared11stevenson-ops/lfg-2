extends RefCounted
# Loads and draws baked puppet frames (tools/bake_puppets.gd). Sprites face right; pass flip for left.
const FRAMES := {"idle": 6, "walk": 8, "attack": 5}
const ORIGIN := Vector2(105, 173)   # ground point inside the 192px frame
const SIZE := 192.0
static var _cache := {}
const BLENDER_DIR := "res://art/blender/frames/"   # frames baked from Blender models take priority over 2D puppets

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

static func frame_count(state: String) -> int:
	return int(FRAMES.get(state, 1))

# Draws the creature with its ground point at the CanvasItem origin + off. scale = px per design unit.
static func draw(ci: CanvasItem, id: String, state: String, frame: int, flip: bool, scale: float, off: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE, rot: float = 0.0, squash: Vector2 = Vector2.ONE) -> bool:
	var f := posmod(frame, frame_count(state))
	var t := tex(id, state, f)
	if t == null and id.contains("_"):
		t = tex(id.get_slice("_", 0), state if state != "walk" else "walk", f)
	if t == null:
		return false
	ci.draw_set_transform(off, rot, Vector2(squash.x * (-1.0 if flip else 1.0), squash.y))
	ci.draw_texture_rect(t, Rect2(-ORIGIN * scale, Vector2(SIZE, SIZE) * scale), false, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
