class_name DangerIndicator
extends Control
## Screen-edge danger arrows for threats that are off-screen (enemies near the player, live telegraphs).
## Feed `threats` (world positions) each frame; needs the 3D camera to project them.
const MARGIN := 46.0
const MAX_ARROWS := 6
var camera: Camera3D
var threats: Array[Vector3] = []
var player_pos: Vector3 = Vector3.ZERO
var max_range: float = 70.0
var purge: bool = false
var markers: Array[Dictionary] = [] # computed this frame: {pos, angle, strength}
var _t: float = 0.0

func _init() -> void:
	name = "DangerIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Pure geometry: where does the arrow for a threat at `screen_pos` sit when it is off-screen?
## Returns {on_screen:bool, pos:Vector2, angle:float(rad, arrow points outward)}.
static func edge_marker(screen_pos: Vector2, view: Vector2, margin: float = MARGIN) -> Dictionary:
	var inner := Rect2(Vector2(margin, margin), view - Vector2(margin, margin) * 2.0)
	if Rect2(Vector2.ZERO, view).has_point(screen_pos) and inner.has_point(screen_pos):
		return {"on_screen": true, "pos": screen_pos, "angle": 0.0}
	var center: Vector2 = view * 0.5
	var dir: Vector2 = screen_pos - center
	if dir.length() < 0.001:
		dir = Vector2.UP
	var half: Vector2 = view * 0.5 - Vector2(margin, margin)
	var sx: float = half.x / maxf(absf(dir.x), 0.0001)
	var sy: float = half.y / maxf(absf(dir.y), 0.0001)
	var k: float = minf(sx, sy)
	return {"on_screen": false, "pos": center + dir * k, "angle": dir.angle()}

func set_threats(list: Array[Vector3], from: Vector3) -> void:
	threats = list
	player_pos = from

func compute_markers() -> void:
	markers.clear()
	if camera == null or not is_inside_tree():
		return
	var view: Vector2 = size if size.x > 1.0 else get_viewport_rect().size
	for p in threats:
		var d: float = Vector2(p.x - player_pos.x, p.z - player_pos.z).length()
		if d > max_range:
			continue
		var sp: Vector2 = camera.unproject_position(p + Vector3(0, 1.0, 0))
		if camera.is_position_behind(p):
			sp = view - sp
			sp = view * 0.5 + (sp - view * 0.5) * 100.0
		var m: Dictionary = edge_marker(sp, view)
		if m["on_screen"]:
			continue
		m["strength"] = clampf(1.0 - d / max_range, 0.25, 1.0)
		markers.append(m)
	markers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["strength"] > b["strength"])
	if markers.size() > MAX_ARROWS:
		markers.resize(MAX_ARROWS)

func _process(dt: float) -> void:
	_t += dt
	compute_markers()
	queue_redraw()

func _draw() -> void:
	var col: Color = Color("ff3a6a") if not purge else Color("ff2fd0")
	for m in markers:
		var a: float = float(m["angle"])
		var p: Vector2 = m["pos"]
		var pulse: float = 0.75 + 0.25 * sin(_t * 8.0)
		var s: float = 20.0 + 10.0 * float(m["strength"])
		var fwd := Vector2(cos(a), sin(a))
		var side := Vector2(-fwd.y, fwd.x)
		var pts := PackedVector2Array([p + fwd * s, p - fwd * s * 0.6 + side * s * 0.8, p - fwd * s * 0.6 - side * s * 0.8])
		var c2 := Color(col.r, col.g, col.b, (0.35 + 0.6 * float(m["strength"])) * pulse)
		draw_colored_polygon(pts, c2)
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.8 * pulse), 2.0, true)
