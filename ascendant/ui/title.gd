class_name TitleScreen
extends Control
## Title, world creation (seed, founding species, history depth), generation progress, settings, load.
signal start_new(seed_: int, arch: String, ticks: int)
signal start_continue(slot: String)
signal quit_game
var mode := "title"          # title | new | settings | generating
var btns: Array = []
var t := 0.0
var seed_text := "1"
var arch_idx := 0
var depth_idx := 1
const DEPTHS := [["Young world", 120, "30 years of history"], ["Mature world", 320, "80 years of history"], ["Ancient world", 800, "200 years of history"]]
var cards: Array = []        # CreatureNodes for species selection
var typing := false
var gen_progress := 0.0
var gen_lines: Array = []
var save_info := ""
var rng := RandomNumberGenerator.new()
var card_rects: Array = []
var seed_rect := Rect2()

func _ready() -> void:
	UiKit.fit(self)
	rng.randomize()
	seed_text = str(rng.randi() % 100000)
	save_info = SaveGame.summary("autosave")
	var r := RandomNumberGenerator.new(); r.seed = 5
	var k := 0
	for a in Archetypes.LIST:
		var c := CreatureNode.new().setup(Archetypes.make_genome(a, r, 0.02), a["bp"], 40 + k)
		c.pose["spd"] = 0.35; c.visible = false
		add_child(c); cards.append(c); k += 1
	_build_title()

func _btn(id: String, label: String, r: Rect2, enabled: bool = true) -> void:
	var b := UiKit.Btn.new(); b.id = id; b.label = label; b.rect = r; b.enabled = enabled
	btns.append(b)

func _build_title() -> void:
	btns.clear(); mode = "title"
	for c in cards: c.visible = false
	var x := 90.0; var y := 300.0
	_btn("continue", "Continue", Rect2(x, y, 300, 52), save_info != "")
	_btn("new", "New World", Rect2(x, y + 66, 300, 52))
	_btn("settings", "Settings", Rect2(x, y + 132, 300, 52))
	_btn("quit", "Quit", Rect2(x, y + 198, 300, 52))

func _build_new() -> void:
	btns.clear(); mode = "new"
	_btn("back", "Back", Rect2(60, size.y - 90, 160, 48))
	_btn("rand", "Reroll", Rect2(430, 118, 110, 38))
	_btn("begin", "Begin the Age", Rect2(size.x - 330, size.y - 90, 270, 52))

func _build_settings() -> void:
	btns.clear(); mode = "settings"
	_btn("back", "Back", Rect2(size.x * 0.5 - 80, size.y - 120, 160, 48))

func _process(dt: float) -> void:
	t += dt
	queue_redraw()
	if mode == "new":
		var k := 0
		for c in cards:
			c.pose["t"] = t + k; c.pose["phase"] = t * 4.0 + k; c.pose["rot"] = 0.0
			k += 1

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		for b in btns: b.hover = b.rect.has_point(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var hit := false
		for b in btns:
			if b.enabled and b.rect.has_point(ev.position): _press(b.id); hit = true
		if hit: return
		if mode == "new":
			typing = seed_rect.has_point(ev.position)
			for i in card_rects.size():
				if card_rects[i].has_point(ev.position): arch_idx = i
			for i in 3:
				if Rect2(60 + i * 200, size.y - 170, 190, 60).has_point(ev.position): depth_idx = i
		elif mode == "settings":
			_settings_click(ev.position)
	elif ev is InputEventKey and ev.pressed and mode == "new" and typing:
		if ev.keycode == KEY_BACKSPACE: seed_text = seed_text.substr(0, seed_text.length() - 1)
		elif ev.unicode >= 48 and ev.unicode <= 57 and seed_text.length() < 9: seed_text += char(ev.unicode)
		elif ev.keycode == KEY_ENTER: typing = false

func _press(id: String) -> void:
	match id:
		"new": _build_new()
		"back": _build_title()
		"settings": _build_settings()
		"quit": quit_game.emit()
		"continue": start_continue.emit("autosave")
		"rand": seed_text = str(rng.randi() % 1000000)
		"begin":
			var s := int(seed_text) if seed_text != "" else 1
			start_new.emit(s, Archetypes.LIST[arch_idx]["id"], DEPTHS[depth_idx][1])

func _settings_click(p: Vector2) -> void:
	var x0 := size.x * 0.5 - 200.0
	var rows := [[Rect2(x0, 190, 400, 20), "master"], [Rect2(x0, 250, 400, 20), "sfx"], [Rect2(x0, 310, 400, 20), "music"], [Rect2(x0, 370, 400, 20), "ui_scale"]]
	for r in rows:
		if Rect2(r[0].position - Vector2(0, 10), r[0].size + Vector2(0, 30)).has_point(p):
			var v := clampf((p.x - r[0].position.x) / r[0].size.x, 0.0, 1.0)
			match r[1]:
				"master": Settings.master = v
				"sfx": Settings.sfx = v
				"music": Settings.music = v
				"ui_scale": Settings.ui_scale = lerpf(0.8, 1.5, v)
	var chk := [Vector2(x0, 430), Vector2(x0, 464), Vector2(x0, 498), Vector2(x0, 532)]
	for i in chk.size():
		if Rect2(chk[i], Vector2(300, 24)).has_point(p):
			match i:
				0: Settings.hints = not Settings.hints
				1: Settings.show_numbers = not Settings.show_numbers
				2: Settings.reduce_motion = not Settings.reduce_motion
				3: Settings.high_contrast = not Settings.high_contrast
	Settings.apply(); Settings.save_all()

func _draw() -> void:
	var sz := size
	# veil over the live world behind
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.04, 0.12, 0.42 if mode == "title" else 0.7))
	match mode:
		"title":
			UiKit.title_text(self, "ASCENDANT", Vector2(80, 190), 104)
			UiKit.text_c(self, "Every world writes its own evolution.", Vector2(92, 232), 22, Color(0.95, 0.88, 0.7))
			UiKit.text_c(self, "An evolutionary civilization sandbox", Vector2(92, 258), 16, Color(0.8, 0.75, 0.65))
			if save_info != "": UiKit.text_c(self, save_info, Vector2(92, 590), 14, Color(0.9, 0.85, 0.7))
			UiKit.text_c(self, "v0.1 — in development", Vector2(sz.x - 190, sz.y - 20), 13, Color(0.8, 0.75, 0.65, 0.7))
		"new": _draw_new(sz)
		"settings": _draw_settings(sz)
		"generating": _draw_gen(sz)
	for b in btns: UiKit.draw_btn(self, b, t)

func _draw_new(sz: Vector2) -> void:
	UiKit.title_text(self, "Found a World", Vector2(60, 90), 48)
	UiKit.text_c(self, "World seed", Vector2(60, 130), 16, Color(0.95, 0.9, 0.75))
	seed_rect = Rect2(60, 118, 360, 38)
	draw_rect(seed_rect, UiKit.PARCH); draw_rect(seed_rect, UiKit.INK if not typing else UiKit.RUST, false, 2.5)
	UiKit.text_c(self, seed_text + ("|" if typing and int(t * 2) % 2 == 0 else ""), Vector2(72, 145), 22, UiKit.INK)
	UiKit.text_c(self, "Choose the animal your bloodline begins as. Evolution decides everything after.", Vector2(60, 184), 16, Color(0.95, 0.9, 0.75))
	card_rects.clear()
	var i := 0
	for a in Archetypes.LIST:
		var col := i % 5; var row := i / 5
		var r := Rect2(60 + col * 232, 200 + row * 128, 220, 118)
		card_rects.append(r)
		var sel := i == arch_idx
		UiKit.panel(self, r, 0.97 if sel else 0.82)
		if sel: draw_rect(r.grow(3), UiKit.RUST, false, 3.0)
		var c: CreatureNode = cards[i]
		c.visible = true; c.position = r.position + Vector2(66, 66); c.scale = Vector2.ONE * clampf(84.0 / maxf(c.ph["L"] + c.ph["tail_len"] * 0.8, 1.0), 0.35, 1.0)
		var diet := "hunter" if a["g"].get("carniv", 0.3) > 0.6 else ("grazer" if a["g"].get("carniv", 0.3) < 0.25 else "forager")
		UiKit.text_c(self, a["name"], r.position + Vector2(12, 24), 16, UiKit.INK, 200)
		UiKit.text_c(self, Genome.BP_NAMES[a["bp"]], r.position + Vector2(128, 58), 12, UiKit.INK.lightened(0.25), 88)
		UiKit.text_c(self, diet, r.position + Vector2(128, 76), 12, UiKit.INK.lightened(0.25), 88)
		UiKit.text_c(self, _blurb(a), r.position + Vector2(12, 108), 12, UiKit.RUST.darkened(0.2), 200)
		i += 1
	for d in 3:
		var r := Rect2(60 + d * 200, size.y - 170, 190, 60)
		UiKit.panel(self, r, 0.97 if d == depth_idx else 0.7)
		if d == depth_idx: draw_rect(r.grow(3), UiKit.RUST, false, 3.0)
		UiKit.text_c(self, DEPTHS[d][0], r.position + Vector2(10, 26), 16, UiKit.INK)
		UiKit.text_c(self, DEPTHS[d][2], r.position + Vector2(10, 46), 12, UiKit.INK.lightened(0.25))

func _blurb(a: Dictionary) -> String:
	var g: Dictionary = a["g"]
	var tags := []
	if g.get("burrow", 0.0) > 0.6: tags.append("digs")
	if g.get("climb", 0.0) > 0.6: tags.append("climbs")
	if g.get("aqua", 0.0) > 0.6: tags.append("swims")
	if g.get("wing", 0.0) > 0.5: tags.append("flies")
	if g.get("secrete", 0.0) > 0.6: tags.append("spins silk")
	if g.get("social", 0.0) > 0.7: tags.append("social")
	if g.get("toxin", 0.0) > 0.6: tags.append("toxic")
	if g.get("speed", 0.0) > 0.8: tags.append("swift")
	return ", ".join(tags) if not tags.is_empty() else "adaptable"

func _draw_settings(sz: Vector2) -> void:
	var x0 := sz.x * 0.5 - 200.0
	UiKit.panel(self, Rect2(x0 - 40, 100, 480, 530))
	UiKit.text_c(self, "Settings", Vector2(x0, 150), 34, UiKit.INK)
	UiKit.slider(self, Rect2(x0, 190, 400, 20), Settings.master, "Master volume")
	UiKit.slider(self, Rect2(x0, 250, 400, 20), Settings.sfx, "Effects")
	UiKit.slider(self, Rect2(x0, 310, 400, 20), Settings.music, "Ambience & music")
	UiKit.slider(self, Rect2(x0, 370, 400, 20), (Settings.ui_scale - 0.8) / 0.7, "Interface size")
	UiKit.checkbox(self, Vector2(x0, 430), Settings.hints, "Teaching hints")
	UiKit.checkbox(self, Vector2(x0, 464), Settings.show_numbers, "Damage numbers")
	UiKit.checkbox(self, Vector2(x0, 498), Settings.reduce_motion, "Reduce motion")
	UiKit.checkbox(self, Vector2(x0, 532), Settings.high_contrast, "High-contrast outlines")

func _draw_gen(sz: Vector2) -> void:
	UiKit.title_text(self, "The world is waking...", Vector2(sz.x * 0.5 - 280, 150), 50)
	var r := Rect2(sz.x * 0.5 - 300, 190, 600, 22)
	draw_rect(r, Color(0.2, 0.15, 0.2, 0.6)); draw_rect(Rect2(r.position, Vector2(r.size.x * gen_progress, r.size.y)), UiKit.GOLD); draw_rect(r, UiKit.INK, false, 2.0)
	var y := 250.0
	for l in gen_lines.slice(-12):
		UiKit.text_c(self, l, Vector2(sz.x * 0.5 - 300, y), 16, Color(0.95, 0.9, 0.75)); y += 24
