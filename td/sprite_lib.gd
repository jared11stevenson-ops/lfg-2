extends RefCounted
# Loads pre-rendered 8-direction creature sprites (see tools/render_sprites.gd). Returns false if missing, so callers fall back to code art.
const SIZE := 256.0
const GROUND_UNITS := 0.79   # ground contact sits this many world units below sprite centre
# Orthographic camera size (world units across the 256px frame) per creature; keeps big models from clipping.
const CAM := {"tickindle": 4.0, "dugloom": 5.4, "hutzin": 4.5, "shuckit": 4.3, "zapnose": 5.2, "glomm": 4.6}
static var _cache := {}

static func tex(id: String, k: int) -> Texture2D:
	var key := "%s_%d" % [id, k]
	if not _cache.has(key):
		var path := "res://art/sprites/%s.png" % key
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]

static func dir_from_angle(a: float) -> int:
	return posmod(roundi(a / (PI / 4.0)), 8)

# Draws creature `id` facing dir k at `ppu` pixels per world unit, ground point at the origin + off. Returns true if drawn.
static func draw(ci: CanvasItem, id: String, k: int, ppu: float, off: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> bool:
	var t := tex(id, k)
	if t == null:
		return false
	var s: float = float(CAM.get(id, 4.0)) * ppu
	ci.draw_texture_rect(t, Rect2(off + Vector2(-s / 2.0, -s / 2.0 - GROUND_UNITS * ppu), Vector2(s, s)), false, tint)
	return true
