class_name CraftUI
extends Control
## Workbench: choose a problem (function), assign materials to its roles, see a physical evaluation, craft.
## Also the heirloom ledger (history, equip). Immediate-mode, parchment style.
signal closed
var play: PlayScene
var tab := "craft"           # craft | items
var func_ids: Array = Invention.FUNCS.keys()
var sel_func := 0
var design: Dictionary = {}
var btns: Array = []
var item_sel := 0
var msg := ""

func _ready() -> void:
	UiKit.fit(self)
	_rebuild()

func _p() -> Critter: return play.player

func _rebuild() -> void:
	btns.clear()
	var x := 90.0; var y := 70.0
	for i in 2:
		var b := UiKit.Btn.new(); b.id = "tab_" + ["craft", "items"][i]; b.label = ["Workbench", "Heirlooms"][i]; b.rect = Rect2(x + i * 190, y, 180, 40); btns.append(b)
	var cb := UiKit.Btn.new(); cb.id = "close"; cb.label = "Close"; cb.rect = Rect2(size.x - 220, y, 130, 40); btns.append(cb)
	if tab == "craft":
		var res := _eval()
		var mk := UiKit.Btn.new(); mk.id = "make"; mk.label = "Craft"; mk.enabled = res["ok"] and _has_mats(); mk.rect = Rect2(size.x - 360, size.y - 120, 230, 52); btns.append(mk)
		var f: Dictionary = Invention.FUNCS[func_ids[sel_func]]
		var i := 0
		for role in f["roles"]:
			var rb := UiKit.Btn.new(); rb.id = "role_" + role; rb.label = "%s: %s" % [role, design.get(role, "—")]; rb.rect = Rect2(470, 250 + i * 54, 300, 44); btns.append(rb); i += 1
	else:
		var items: Array = play.items
		if items.size() > 0:
			var eb := UiKit.Btn.new(); eb.id = "equip"; eb.label = "Equip / unequip"; eb.rect = Rect2(size.x - 380, size.y - 120, 250, 52); btns.append(eb)

func _eval() -> Dictionary:
	var fid: String = func_ids[sel_func]
	var f: Dictionary = Invention.FUNCS[fid]
	for role in f["roles"]:
		if not design.has(role): return {"ok": false, "score": 0.0, "reasons": ["choose a material for: " + role], "parts": {}}
	return Invention.evaluate(fid, design, _p().genome)

func _has_mats() -> bool:
	var need := {}
	for r in design: need[design[r]] = need.get(design[r], 0) + 1
	for m in need:
		if _p().inv.get(m, 0) < need[m]: return false
	return true

func _process(_d: float) -> void: queue_redraw()

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		for b in btns: b.hover = b.rect.has_point(ev.position)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index != MOUSE_BUTTON_LEFT and ev.button_index != MOUSE_BUTTON_RIGHT: return
		var dir := 1 if ev.button_index == MOUSE_BUTTON_LEFT else -1
		for b in btns:
			if b.enabled and b.rect.has_point(ev.position): _press(b.id, dir); get_viewport().set_input_as_handled(); return
		if tab == "craft":
			for i in func_ids.size():
				if Rect2(90, 130 + i * 38, 330, 34).has_point(ev.position): sel_func = i; design = {}; msg = ""; _rebuild()
		else:
			for i in play.items.size():
				if Rect2(90, 130 + i * 40, 330, 36).has_point(ev.position): item_sel = i; _rebuild()
	elif ev is InputEventKey and ev.pressed and (ev.keycode == KEY_ESCAPE or ev.keycode == KEY_C or ev.keycode == KEY_I):
		closed.emit(); get_viewport().set_input_as_handled()

func _press(id: String, dir: int) -> void:
	if id == "close": closed.emit(); return
	if id.begins_with("tab_"): tab = id.substr(4); _rebuild(); return
	if id.begins_with("role_"):
		var role := id.substr(5)
		var mats := _mats_for_picker()
		if mats.is_empty(): msg = "You carry nothing to try. Gather with G."; return
		var cur: int = mats.find(design.get(role, ""))
		design[role] = mats[(cur + dir + mats.size()) % mats.size()]
		_rebuild(); return
	if id == "make":
		var res := _eval()
		if not (res["ok"] and _has_mats()): return
		for r in design: _p().inv[design[r]] -= 1
		_p().train("c_manip", 0.012); _p().train("c_plan", 0.006); _p().train("c_curio", 0.004)
		var fid: String = func_ids[sel_func]
		var it := Item.create(fid, design, res["score"], _p().display_name(), play.sim.tick, _p().sp_name)
		play.items.append(it)
		var first: bool = not play.known.has(fid)
		if first or res["score"] > play.known[fid]["score"] + 0.05:
			play.known[fid] = {"score": res["score"], "design": design.duplicate(), "name": it.name}
			if first:
				play.chronicle.append("Your line discovers the %s." % it.name)
				play.world.fx_text(_p().position, "New knowledge: " + it.name, Color(0.6, 1.0, 0.7))
		msg = "Crafted %s (%.0f%%)." % [it.name, res["score"] * 100]
		_rebuild(); return
	if id == "equip":
		if item_sel < play.items.size():
			var it: Item = play.items[item_sel]
			play.equip(_p(), it if _p().weapon.is_empty() or _p().weapon["item"] != it else null)
			_rebuild()

func _mats_for_picker() -> Array:
	var a := []
	for m in _p().inv: if _p().inv[m] > 0: a.append(m)
	a.sort()
	return a

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.1, 0.62))
	UiKit.panel(self, Rect2(60, 40, size.x - 120, size.y - 80))
	for b in btns: UiKit.draw_btn(self, b, 0.0)
	var p := _p()
	if tab == "craft": _draw_craft(p)
	else: _draw_items(p)
	if msg != "": UiKit.text_c(self, msg, Vector2(90, size.y - 60), 16, UiKit.RUST)

func _draw_craft(p: Critter) -> void:
	UiKit.text_c(self, "Problems you could solve", Vector2(90, 122), 15, UiKit.INK)
	for i in func_ids.size():
		var r := Rect2(90, 130 + i * 38, 330, 34)
		var f: Dictionary = Invention.FUNCS[func_ids[i]]
		var known: bool = play.known.has(func_ids[i])
		var can := true
		for need in f["need"]: if Genome.get_g(p.genome, need) < float(f["need"][need]): can = false
		draw_rect(r, Color(1, 0.95, 0.75) if i == sel_func else Color(0.88, 0.8, 0.62, 0.6)); draw_rect(r, UiKit.INK if i == sel_func else UiKit.INK.lightened(0.5), false, 1.5)
		UiKit.text_c(self, "%s  (%s)" % [func_ids[i].capitalize(), f["verb"]], r.position + Vector2(10, 23), 17, UiKit.INK if can else UiKit.INK.lightened(0.5))
		if known: UiKit.text_c(self, "known", r.position + Vector2(270, 23), 13, Color(0.2, 0.5, 0.3))
		elif not can: UiKit.text_c(self, "body can't", r.position + Vector2(246, 23), 13, UiKit.RUST)
	var fid: String = func_ids[sel_func]
	UiKit.text_c(self, "Assemble a %s" % Invention.FUNCS[fid]["verb"], Vector2(470, 160), 26, UiKit.INK)
	UiKit.text_c(self, "Left-click a part to cycle your gathered materials (right-click goes back).", Vector2(470, 190), 14, UiKit.INK.lightened(0.25), 520)
	var f2: Dictionary = Invention.FUNCS[fid]
	var i := 0
	for role in f2["roles"]:
		var rw: Dictionary = f2["roles"][role]
		var want := []
		for pr in rw: want.append(("low " if rw[pr] < 0 else "") + pr)
		UiKit.text_c(self, "wants: " + ", ".join(want), Vector2(780, 278 + i * 54), 13, UiKit.INK.lightened(0.3), 220)
		if design.has(role):
			var sc := Invention.score_role(rw, design[role])
			draw_rect(Rect2(470, 296 + i * 54, 300 * sc, 6), Color(0.4, 0.65, 0.35) if sc > 0.55 else (Color(0.85, 0.6, 0.2) if sc > 0.35 else UiKit.RUST))
		i += 1
	var res := _eval()
	var y := 250.0 + i * 54 + 20
	UiKit.text_c(self, "Verdict: %.0f%%  —  %s" % [res["score"] * 100.0, "it will work" if res["ok"] else "not yet"], Vector2(470, y), 20, Color(0.2, 0.5, 0.3) if res["ok"] else UiKit.RUST)
	for k in res["reasons"].size():
		UiKit.text_c(self, "• " + res["reasons"][k], Vector2(470, y + 26 + k * 20), 14, UiKit.INK, 560)
	# pack
	UiKit.text_c(self, "Pack (%d/%d)" % [p.inv_count(), p.carry_cap()], Vector2(size.x - 330, 150), 17, UiKit.INK)
	var j := 0
	var ms := _mats_for_picker()
	for m in ms:
		UiKit.text_c(self, "%s ×%d" % [m, p.inv[m]], Vector2(size.x - 330, 180 + j * 22), 15, UiKit.INK); j += 1
	if ms.is_empty(): UiKit.text_c(self, "Empty. Hold G to gather\nfrom the land (or F to\nsecrete, if your body can).", Vector2(size.x - 330, 180), 14, UiKit.INK.lightened(0.3))

func _draw_items(p: Critter) -> void:
	UiKit.text_c(self, "Heirlooms of your line", Vector2(90, 122), 15, UiKit.INK)
	if play.items.is_empty():
		UiKit.text_c(self, "Nothing crafted yet. Every object you make keeps its story —\nmakers, owners, battles. Legends are earned, never rolled.", Vector2(90, 170), 17, UiKit.INK.lightened(0.2)); return
	for i in play.items.size():
		var it: Item = play.items[i]
		var r := Rect2(90, 130 + i * 40, 330, 36)
		draw_rect(r, Color(1, 0.95, 0.75) if i == item_sel else Color(0.88, 0.8, 0.62, 0.6)); draw_rect(r, UiKit.INK, false, 1.5)
		var eq: bool = (not p.weapon.is_empty() and p.weapon["item"] == it)
		UiKit.text_c(self, ("◆ " if eq else "") + it.display_name(), r.position + Vector2(10, 24), 16, UiKit.INK, 230)
		UiKit.text_c(self, Item.TIER_NAMES[it.legend_tier()], r.position + Vector2(246, 24), 13, UiKit.GOLD.darkened(0.3))
	if item_sel < play.items.size():
		var it: Item = play.items[item_sel]
		UiKit.text_c(self, it.display_name(), Vector2(470, 160), 28, UiKit.INK)
		UiKit.text_c(self, "%s · quality %.0f%% · wear %.0f%% · %d kills · %d owners" % [Item.TIER_NAMES[it.legend_tier()], it.quality * 100, it.wear * 100, it.kills, it.owners.size()], Vector2(470, 188), 15, UiKit.INK.lightened(0.2), 560)
		var y := 226.0
		for h in it.history.slice(-12):
			UiKit.text_c(self, "Y%d  %s" % [h["tick"] / 4, h["text"]], Vector2(470, y), 14, UiKit.INK, 600); y += 22
