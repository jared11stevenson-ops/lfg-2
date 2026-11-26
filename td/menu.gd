extends Node2D
# Main menu: title, three map cards, parade of creatures.
const Maps = preload("res://maps.gd")
const Session = preload("res://session.gd")
const SpriteLib = preload("res://sprite_lib.gd")
const DrawUtil = preload("res://draw_util.gd")
const Sfx = preload("res://sfx.gd")
const CARD := Vector2(340, 290)
var clock := 0.0
var hover := -1

func _card_rect(i: int) -> Rect2:
	return Rect2(Vector2(110 + i * 370, 250), CARD)

func _ready() -> void:
	Sfx.start_music(self)

func _process(delta: float) -> void:
	clock += delta
	hover = -1
	var m := get_global_mouse_position()
	for i in Maps.ORDER.size():
		if _card_rect(i).has_point(m):
			hover = i
	queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and hover >= 0:
		Session.map_id = Maps.ORDER[hover]
		Sfx.play(self, "click")
		get_tree().change_scene_to_file("res://main.tscn")

func _text(s: String, pos: Vector2, size: int, col: Color, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, align, width, size, 8, Color(0.05, 0.1, 0.05))
	draw_string(f, pos, s, align, width, size, col)

func _draw() -> void:
	# sky-to-meadow backdrop
	draw_rect(Rect2(0, 0, 1280, 720), Color("5fae4f"))
	draw_rect(Rect2(0, 0, 1280, 220), Color("7fc4e8"))
	draw_rect(Rect2(0, 190, 1280, 40), Color("9ad0ee"))
	for i in 6:
		var x := fmod(i * 260.0 + clock * 14.0, 1500.0) - 120.0
		draw_circle(Vector2(x, 70 + (i % 3) * 36), 34, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(x + 34, 80 + (i % 3) * 36), 26, Color(1, 1, 1, 0.9))
	_text("WELLFALL", Vector2(0, 150), 110, Color("ffe36a"), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	_text("Tower defense for the last Wells", Vector2(0, 200), 30, Color.WHITE, 1280, HORIZONTAL_ALIGNMENT_CENTER)
	Session.load_save()
	for i in Maps.ORDER.size():
		var id: String = Maps.ORDER[i]
		var mp: Dictionary = Maps.MAPS[id]
		var r := _card_rect(i)
		if i == hover:
			r = r.grow(8)
		var sb := Color("1b2a1b")
		draw_rect(r.grow(5), sb)
		draw_rect(r, mp.grass)
		# mini path preview
		var pts := PackedVector2Array()
		for p in mp.path:
			pts.append(r.position + Vector2(clampf(p.x, 0, 1280) / 1280.0 * (r.size.x - 40) + 20, 20 + clampf(p.y, 0, 720) / 720.0 * (r.size.y - 150)))
		draw_polyline(pts, mp.path_edge, 14.0, true)
		draw_polyline(pts, mp.path_fill, 9.0, true)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 130), Vector2(r.size.x, 130)), Color(0.08, 0.12, 0.1, 0.9))
		_text(mp.name, r.position + Vector2(14, r.size.y - 98), 26, Color.WHITE)
		_text(Session.best_text(id, 8), r.position + Vector2(14, r.size.y - 68), 20, Color("ffd23a"))
		draw_multiline_string(ThemeDB.fallback_font, r.position + Vector2(14, r.size.y - 42), mp.blurb, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 15, 2, Color(0.88, 0.92, 0.96))
	# parade of starters and enemies
	var row := ["tickindle", "dugloom", "hutzin"]
	for i in 3:
		SpriteLib.draw(self, row[i], 2, 40.0, Vector2(250 + i * 390, 640 + sin(clock * 2.0 + i) * 4.0))
	var foes := ["shuckit", "zapnose", "glomm"]
	for i in 6:
		var x := fmod(clock * 70.0 + i * 260.0, 1500.0) - 110.0
		SpriteLib.draw(self, foes[i % 3], 0, 28.0, Vector2(x, 700 + sin(clock * 8.0 + i) * 3.0))
	_text("Tap a map to begin", Vector2(0, 596), 26, Color.WHITE, 1280, HORIZONTAL_ALIGNMENT_CENTER)
