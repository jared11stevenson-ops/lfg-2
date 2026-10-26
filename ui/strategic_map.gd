class_name StrategicMap
extends Control
## Full-screen strategic hex map. Shows biome colours for explored hexes only (fog of war aware),
## holdings, the player marker. Toggle with toggle(); tap a hex for an info line.
signal hex_selected(hex: Vector2i)
signal closed

const UNSEEN_COLOR := Color("1a1030")
var world: WorldData
var fog: FogOfWar
var player_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var selected: Vector2i = Vector2i(-1, -1)
var _verts: PackedVector2Array = PackedVector2Array()
var _idx: PackedInt32Array = PackedInt32Array()
var _mesh: ArrayMesh
var _dirty := true
var _xform: Transform2D = Transform2D()
var _info: Label
var _title: Label
var _legend: VBoxContainer
const MARGIN_TOP := 58.0

func _ready() -> void:
	name = "StrategicMap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = UiStyle.label("STRATEGIC MAP", 30, UiStyle.WARN)
	_title.position = Vector2(24, 10)
	add_child(_title)
	_info = UiStyle.label("", 22)
	_info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = 24
	_info.offset_top = -42
	add_child(_info)
	_legend = VBoxContainer.new()
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_legend.anchor_left = 1.0
	_legend.anchor_right = 1.0
	_legend.offset_left = -200
	_legend.offset_top = 10
	add_child(_legend)
	for b in 7:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(18, 18)
		sw.color = Biomes.GROUND[b]
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
		row.add_child(UiStyle.label(" " + Biomes.NAMES[b], 16))
		_legend.add_child(row)
	resized.connect(func() -> void: _update_xform(); queue_redraw())
	_build_geometry()

func setup(w: WorldData, f: FogOfWar) -> void:
	world = w
	fog = f
	fog.changed.connect(func() -> void: _dirty = true; if visible: queue_redraw())
	_dirty = true

func toggle() -> void:
	set_open(not visible)

func set_open(open: bool) -> void:
	visible = open
	if open:
		_update_xform()
		queue_redraw()
	else:
		closed.emit()

func set_player(pos: Vector3, yaw: float) -> void:
	player_pos = pos
	player_yaw = yaw
	if visible:
		queue_redraw()

func _build_geometry() -> void:
	_verts = PackedVector2Array()
	_idx = PackedInt32Array()
	var s: float = HexMath.SIZE * 0.93
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			var cen: Vector2 = HexMath.offset_center(c, r)
			var base: int = _verts.size()
			_verts.append(cen)
			for k in 6:
				var a: float = deg_to_rad(60.0 * float(k) - 30.0)
				_verts.append(cen + Vector2(cos(a), sin(a)) * s)
			for k in 6:
				_idx.append(base)
				_idx.append(base + 1 + k)
				_idx.append(base + 1 + (k + 1) % 6)

func _update_xform() -> void:
	var ext: Rect2 = HexMath.world_extent()
	var avail := Vector2(size.x - 24.0, size.y - MARGIN_TOP - 50.0)
	var sc: float = minf(avail.x / ext.size.x, avail.y / ext.size.y)
	var origin := Vector2(12.0 + (avail.x - ext.size.x * sc) * 0.5, MARGIN_TOP + (avail.y - ext.size.y * sc) * 0.5)
	_xform = Transform2D(Vector2(sc, 0), Vector2(0, sc), origin - ext.position * sc)

func _hex_color(i: int) -> Color:
	var st: int = FogOfWar.VISIBLE if fog == null else (FogOfWar.VISIBLE if fog.reveal_all else fog.state[i])
	if st == FogOfWar.UNSEEN:
		return UNSEEN_COLOR
	var c: Color = Biomes.GROUND[world.biome[i]]
	if world.biome[i] == Biomes.B.WATER:
		c = Color("2a8fb0")
	if st == FogOfWar.SEEN:
		c = c.darkened(0.42).lerp(UNSEEN_COLOR, 0.2)
	return c

func _refresh_mesh() -> void:
	if world == null:
		return
	var cols := PackedColorArray()
	cols.resize(_verts.size())
	for i in HexMath.COLS * HexMath.ROWS:
		var c: Color = _hex_color(i)
		var b: int = i * 7
		for k in 7:
			cols[b + k] = c
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = _idx
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_dirty = false

func _draw() -> void:
	if not visible or world == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.1, 0.97))
	if _dirty or _mesh == null:
		_refresh_mesh()
	_update_xform()
	draw_mesh(_mesh, null, _xform)
	# holdings (only where explored)
	for h in world.holdings:
		var hex: Vector2i = h["hex"]
		if fog != null and not fog.reveal_all and not fog.is_explored(hex):
			continue
		var p: Vector2 = _xform * HexMath.offset_center(hex.x, hex.y)
		var col: Color = Color("19e0c8") if int(h["owner"]) == 0 else Biomes.FUNGI[int(h["owner"]) % Biomes.FUNGI.size()]
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("1d1030"))
		draw_rect(Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), col)
	# selection
	if HexMath.in_bounds(selected):
		var sp: Vector2 = _xform * HexMath.offset_center(selected.x, selected.y)
		draw_arc(sp, 9.0, 0.0, TAU, 20, Color.WHITE, 2.0)
	# player marker
	var pp: Vector2 = _xform * Vector2(player_pos.x, player_pos.z)
	var fwd := Vector2(-sin(player_yaw), -cos(player_yaw))
	var side := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([pp + fwd * 11.0, pp - fwd * 7.0 + side * 7.0, pp - fwd * 7.0 - side * 7.0]), Color("ffe82e"))
	draw_polyline(PackedVector2Array([pp + fwd * 11.0, pp - fwd * 7.0 + side * 7.0, pp - fwd * 7.0 - side * 7.0, pp + fwd * 11.0]), Color("1d1030"), 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_select_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_at(event.position)

func _select_at(p: Vector2) -> void:
	var wp: Vector2 = _xform.affine_inverse() * p
	var hex: Vector2i = HexMath.world_to_offset(wp.x, wp.y)
	if not HexMath.in_bounds(hex):
		return
	selected = hex
	var txt := "Hex %d,%d" % [hex.x, hex.y]
	if fog != null and not fog.reveal_all and not fog.is_explored(hex):
		txt += "  -  unexplored"
	else:
		txt += "  -  " + Biomes.name_of(world.biome_hex(hex))
		var hi: int = world.holding_at(hex)
		if hi >= 0:
			txt += "  -  " + String(world.holdings[hi]["name"])
	_info.text = txt
	hex_selected.emit(hex)
	queue_redraw()
