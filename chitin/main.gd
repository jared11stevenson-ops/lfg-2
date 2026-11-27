extends Node
## Flow controller: Menu -> Instar -> Pupation -> Instar -> ...

var current: Node

func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke()
		return
	_show_menu()

func _swap(n: Node) -> void:
	if is_instance_valid(current):
		current.queue_free()
	current = n
	add_child(n)

func _show_menu() -> void:
	var m := MainMenu.new()
	m.new_game.connect(func(): Lineage.new_lineage(); _start_instar())
	m.continue_game.connect(func():
		if Lineage.load_game(): _start_instar())
	_swap(m)

func _start_instar() -> void:
	var w := InstarWorld.new()
	w.finished.connect(_on_instar_finished)
	_swap(w)

func _on_instar_finished(cause: String) -> void:
	var summary := Lineage.end_instar(cause)
	var p := PupationScreen.new()
	p.setup(summary)
	p.emerged.connect(_start_instar)
	# defer: we are inside the world's own signal emission
	call_deferred("_swap", p)

# `godot --path chitin -- --smoke` plays a scripted life headlessly and exits.
func _smoke() -> void:
	Lineage.new_lineage(5)
	var w := InstarWorld.new()
	add_child(w)
	for i in 120:
		await get_tree().physics_frame
	var c := w.spawn_creature("mold_grub", w.player.global_position + Vector3(0, 0, -2))
	w.chord = c.sp.want
	var out := w.emit_scent(false)
	print("smoke parley: ", out)
	for i in 30:
		await get_tree().physics_frame
	w.player.facing = Vector3(0, 0, -1)
	var bug := w.spawn_creature("rust_beetle", w.player.global_position + Vector3(0, 0, -1.5))
	for i in 40:
		w.player.attack_cd = 0.0
		w.player.stamina = 100.0
		w.player.attack()
		await get_tree().physics_frame
	print("beetle hp after attacks: ", bug.hp if is_instance_valid(bug) else "dead")
	w.finish("molted")
	var s := Lineage.end_instar("molted")
	var screen := PupationScreen.new()
	screen.setup(s)
	add_child(screen)
	await get_tree().process_frame
	screen._emerge()
	print("smoke ok: generation ", Lineage.generation, " echoes ", Lineage.echoes.size(), " kills ", s.kills)
	get_tree().quit(0)
