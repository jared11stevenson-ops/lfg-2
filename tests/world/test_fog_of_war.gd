extends TestCase

func test_initial_all_unseen() -> void:
	var f := FogOfWar.new()
	eq(f.count_in_state(FogOfWar.UNSEEN), HexMath.COLS * HexMath.ROWS, "everything unseen at start")
	eq(f.image.get_width(), HexMath.COLS, "texture width = hex columns")
	eq(f.image.get_height(), HexMath.ROWS, "texture height = hex rows")

func test_reveal_radius_and_texture() -> void:
	var f := FogOfWar.new()
	var c := Vector2i(40, 25)
	f.reveal(c, 3)
	eq(f.count_in_state(FogOfWar.VISIBLE), 37, "radius 3 reveals 37 hexes")
	eq(f.state_of(c), FogOfWar.VISIBLE, "centre visible")
	eq(f.state_of(Vector2i(40, 30)), FogOfWar.UNSEEN, "far hex untouched")
	eq(int(round(f.image.get_pixel(c.x, c.y).r * 255.0)), 255, "visible hex = 255 in texture")
	eq(int(round(f.image.get_pixel(0, 0).r * 255.0)), 0, "unseen hex = 0 in texture")

func test_moving_leaves_remembered_hexes() -> void:
	var f := FogOfWar.new()
	f.reveal(Vector2i(20, 20), 2)
	var first_visible: int = f.count_in_state(FogOfWar.VISIBLE)
	f.reveal(Vector2i(30, 20), 2)
	eq(f.count_in_state(FogOfWar.SEEN), first_visible, "old area becomes SEEN")
	eq(f.state_of(Vector2i(20, 20)), FogOfWar.SEEN, "old centre remembered")
	eq(int(round(f.image.get_pixel(20, 20).r * 255.0)), 128, "seen = 128 in texture")
	check(f.is_explored(Vector2i(20, 20)), "explored")
	check(not f.is_explored(Vector2i(0, 0)), "unexplored")

func test_reveal_all_and_edges() -> void:
	var f := FogOfWar.new()
	f.reveal(Vector2i(0, 0), 4) # must not crash at the map corner
	check(f.count_in_state(FogOfWar.VISIBLE) > 0, "corner reveal works")
	f.set_reveal_all(true)
	eq(int(round(f.image.get_pixel(83, 53).r * 255.0)), 255, "reveal_all lights the whole texture")
	f.reveal(Vector2i(83, 53), 4)
	check(true, "bottom-right corner reveal survived")

func test_changed_signal() -> void:
	var f := FogOfWar.new()
	var counter := [0]
	f.changed.connect(func() -> void: counter[0] += 1)
	f.reveal(Vector2i(10, 10), 2)
	eq(counter[0], 1, "changed emitted on reveal")
	var again: bool = f.reveal(Vector2i(10, 10), 2)
	eq(again, false, "revealing same spot is a no-op")
	eq(counter[0], 1, "no signal when nothing changed")
