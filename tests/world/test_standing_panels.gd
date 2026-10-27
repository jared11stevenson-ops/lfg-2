extends TestCase
## ui/standing_panel.gd and ui/skill_tree_panel.gd: pure views over Standing.hud_model and Skills.panel_model; they emit signals only.

var _emitted: Array = []

func _state(cls: String = "lfg:class/judd") -> MatchState:
	return Rules.new_match(11, StringName(cls), {"day_seconds": 60.0, "ai_enabled": false, "wild_enemies": false})

func test_standing_panel_shows_rank_levy_mark_prosperity_and_deeds() -> void:
	var s: MatchState = _state()
	s.set_time(7, 0.6)
	var ev: Array = []
	for i in range(3):
		s.factions[5]["pcap"] = {}
		Standing.record(s, 5, "kill_leader", ev)
	Standing.record(s, 0, "scout", ev)
	Standing.recompute(s, [])
	var p := StandingPanel.new()
	p.set_model(Standing.hud_model(s, 0))
	check(p.rank_label.text.begins_with("RANK 0"), "rank shown: %s" % p.rank_label.text)
	check(p.next_label.text.contains("Unlocks"), "next unlock shown: %s" % p.next_label.text)
	check(p.levy_label.text.contains("Purge Levy") and p.levy_label.text.contains("rations"), "levy due shown")
	check(p.mark_label.text.begins_with("Marked: "), "marked faction named: %s" % p.mark_label.text)
	check(p.prosperity_label.text.begins_with("Prosperity"), "prosperity shown")
	eq(p.deeds_box.get_child_count(), 1, "one recent deed row")
	check(p.skill_btn.text.contains("1 point"), "skill points on the button: %s" % p.skill_btn.text)
	eq(UiKit.small_buttons(p).size(), 0, "all buttons are touch-sized")
	# the Marked player is told
	var mine: Dictionary = Standing.hud_model(s, 5)
	p.set_model(mine)
	check(p.mark_label.text.begins_with("YOU are Marked"), "the Marked faction sees a warning")
	p.set_model({})
	check(p.rank_label.text != "", "empty model is safe")
	p.free()

func test_standing_panel_emits_only_a_signal_and_never_touches_rules() -> void:
	var s: MatchState = _state()
	var before: String = JSON.stringify(s.to_dict())
	var p := StandingPanel.new()
	p.set_model(Standing.hud_model(s, 0))
	_emitted.clear()
	p.skill_tree_requested.connect(func() -> void: _emitted.append("tree"))
	p.skill_btn.pressed.emit()
	eq(_emitted, ["tree"], "skill tree requested")
	eq(JSON.stringify(s.to_dict()), before, "the panel did not change state")
	p.free()

func test_standing_panel_thin_crown_and_top_rank() -> void:
	var s: MatchState = _state()
	var m: Dictionary = Standing.hud_model(s, 0)
	m["thin_crown"] = true
	m["rank"] = 5
	m["rank_name"] = "Sovereign"
	m["next_threshold"] = 0.0
	var p := StandingPanel.new()
	p.set_model(m)
	check(p.thin_label.visible and p.thin_label.text.begins_with("THIN CROWN"), "thin crown warning")
	check(p.next_label.text.contains("highest rank"), "top rank text")
	p.free()

func test_skill_panel_states_and_signal() -> void:
	var s: MatchState = _state("lfg:class/judd")
	s.actors[1]["sp"] = 1
	var model: Dictionary = Skills.panel_model(s.actors[1])
	eq(model["total"], 15, "15 nodes")
	var p := SkillTreePanel.new()
	p.set_model(model)
	eq(p.buttons.size(), 15, "a button per node")
	check(not p.buttons["judd.e1"].disabled and not p.buttons["judd.p1"].disabled and not p.buttons["judd.h1"].disabled, "the three affordable roots can be bought")
	check(p.buttons["judd.e2"].disabled, "a locked node is disabled")
	check(p.title_label.text.contains("WAY OF THE STAFF"), "tree name in the title: %s" % p.title_label.text)
	_emitted.clear()
	p.unlock_requested.connect(func(id: String) -> void: _emitted.append(id))
	p.buttons["judd.e1"].pressed.emit()
	eq(_emitted, ["judd.e1"], "emits the node id and nothing else")
	check(not s.actors[1].has("nodes") or (s.actors[1]["nodes"] as Array).is_empty(), "the panel itself bought nothing")
	# the lead wires the signal to the command
	var r: Dictionary = Rules.apply(s, {"type": &"unlock_skill", "actor": 1, "seq": 1, "args": {"node": _emitted[0]}})
	check(r["ok"], "unlock_skill from the signal: %s" % r["error"])
	p.set_model(Skills.panel_model(s.actors[1]))
	check(p.buttons["judd.e1"].disabled and p.buttons["judd.e1"].text.begins_with("Deep Furrows"), "taken nodes are shown, not buyable")
	eq(UiKit.small_buttons(p).size(), 0, "touch-sized buttons")
	p.free()

func test_skill_panel_model_marks_drawbacks_and_describes_effects() -> void:
	var s: MatchState = _state("lfg:class/judd")
	var m: Dictionary = Skills.panel_model(s.actors[1])
	var drawbacks: int = 0
	for b in m["branches"].values():
		for r in b:
			check((r["effects"] as Array).size() >= 1 and String(r["effects"][0]) != "", "%s has an effect text" % r["id"])
			if r["drawback"]:
				drawbacks += 1
	check(drawbacks >= 2, "drawback nodes flagged")
	eq(Skills.effect_text("growth_pct", 5.0), "+5% crop growth", "effect text")
	eq(Skills.effect_text("dmg_taken_mult", 0.1), "+0.10 damage taken", "decimal effect text")
