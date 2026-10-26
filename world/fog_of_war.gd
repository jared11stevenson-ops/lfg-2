class_name FogOfWar
extends RefCounted
## Per-hex exploration state. 0 unseen, 1 seen (remembered), 2 visible now.
## Presentation state only; the authoritative explored set may later come from Rules (set_explored).
signal changed
const UNSEEN := 0
const SEEN := 1
const VISIBLE := 2
var state: PackedByteArray = PackedByteArray()
var image: Image
var texture: ImageTexture
var vision_radius: int = 4
var _visible_cells: Array[int] = []
var reveal_all: bool = false

func _init() -> void:
	state.resize(HexMath.COLS * HexMath.ROWS)
	image = Image.create(HexMath.COLS, HexMath.ROWS, false, Image.FORMAT_R8)
	texture = ImageTexture.create_from_image(image)

func state_of(c: Vector2i) -> int:
	if not HexMath.in_bounds(c):
		return UNSEEN
	return state[HexMath.idx(c)]

func is_explored(c: Vector2i) -> bool:
	return state_of(c) != UNSEEN

func count_in_state(s: int) -> int:
	var n := 0
	for v in state:
		if v == s:
			n += 1
	return n

## Move the viewer. Previously visible hexes become SEEN, hexes within radius become VISIBLE.
func reveal(center: Vector2i, radius: int = -1) -> bool:
	if radius < 0:
		radius = vision_radius
	var changed_any := false
	var next: Array[int] = []
	for r in range(maxi(0, center.y - radius), mini(HexMath.ROWS, center.y + radius + 1)):
		for c in range(maxi(0, center.x - radius - 1), mini(HexMath.COLS, center.x + radius + 2)):
			var cc := Vector2i(c, r)
			if HexMath.distance(cc, center) <= radius:
				next.append(HexMath.idx(cc))
	var next_set := {}
	for i in next:
		next_set[i] = true
	for i in _visible_cells:
		if not next_set.has(i) and state[i] == VISIBLE:
			state[i] = SEEN
			changed_any = true
	for i in next:
		if state[i] != VISIBLE:
			state[i] = VISIBLE
			changed_any = true
	_visible_cells = next
	if changed_any:
		_push()
	return changed_any

func mark_explored(cells: Array[Vector2i]) -> void:
	for c in cells:
		if HexMath.in_bounds(c) and state[HexMath.idx(c)] == UNSEEN:
			state[HexMath.idx(c)] = SEEN
	_push()

func set_reveal_all(on: bool) -> void:
	reveal_all = on
	_push()

func _push() -> void:
	var bytes := PackedByteArray()
	bytes.resize(state.size())
	for i in state.size():
		bytes[i] = 255 if reveal_all else (0 if state[i] == UNSEEN else (128 if state[i] == SEEN else 255))
	image.set_data(HexMath.COLS, HexMath.ROWS, false, Image.FORMAT_R8, bytes)
	texture.update(image)
	changed.emit()
