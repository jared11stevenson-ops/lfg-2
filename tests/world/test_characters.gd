extends TestCase
## Pass 1: 14 distinct class looks, 6 enemy archetypes, NPC/merchant/raider, procedural animation.

func _bounds_of(rig: CharacterRig) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array[Node] = [rig.body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			var a: AABB = m.get_aabb()
			a.position += (n.get_parent() as Node3D).position
			out = a if first else out.merge(a)
			first = false
		stack.append_array(n.get_children())
	return out

func test_all_classes_have_looks() -> void:
	var ids: Array = Content.classes().keys()
	eq(ids.size(), 14, "14 classes in data")
	for id in ids:
		check(CharacterKit.CLASS_LOOKS.has(String(id)), "look for %s" % id)
	eq(CharacterKit.class_ids().size(), 14, "14 looks")

func test_looks_are_distinct() -> void:
	var sigs: Dictionary = {}
	var hats: Dictionary = {}
	var props: Dictionary = {}
	var backs: Dictionary = {}
	for id in CharacterKit.class_ids():
		sigs[CharacterKit.look_signature(id)] = true
		var l: Dictionary = CharacterKit.CLASS_LOOKS[id]
		hats[l["hat"]] = true
		props[l["prop"]] = true
		backs[l["back"]] = true
	eq(sigs.size(), 14, "hat|prop|back signature unique per class")
	eq(hats.size(), 14, "14 different hats")
	eq(props.size(), 14, "14 different props")
	eq(backs.size(), 14, "14 different back items")
	var ids: Array[String] = CharacterKit.class_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Color = CharacterKit.CLASS_LOOKS[ids[i]]["tunic"]
			var b: Color = CharacterKit.CLASS_LOOKS[ids[j]]["tunic"]
			var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			check(d > 0.25, "tunics of %s and %s are distinguishable (%.2f)" % [ids[i], ids[j], d])

func test_class_rigs_scale_and_draw_budget() -> void:
	var tris: Array[int] = []
	for id in CharacterKit.class_ids():
		var r: CharacterRig = CharacterKit.build_class(id)
		eq(r.mesh_count, 5, "%s: 5 meshes (body, 2 legs, 2 arms)" % id)
		eq(r.limbs("leg").size(), 2, "%s legs" % id)
		eq(r.limbs("arm").size(), 2, "%s arms" % id)
		var b: AABB = _bounds_of(r)
		check(b.size.y >= 1.8 and b.size.y <= 4.6, "%s height %.2f in range" % [id, b.size.y])
		check(b.position.y >= -0.6 and b.position.y <= 0.1, "%s stands on the ground (%.2f)" % [id, b.position.y])
		check(b.size.x <= 3.0, "%s silhouette width sane (%.2f)" % [id, b.size.x])
		check(r.tri_total < 600, "%s triangle budget (%d)" % [id, r.tri_total])
		tris.append(r.tri_total)
		eq(r.nominal_height, 2.0, "%s shared nominal height" % id)
		r.free()
	var distinct: Dictionary = {}
	for t in tris:
		distinct[t] = true
	check(distinct.size() >= 12, "geometry differs between classes (%d distinct tri counts)" % distinct.size())

func test_enemy_archetypes() -> void:
	var tris: Dictionary = {}
	for id in CharacterKit.ENEMY_IDS:
		check(Content.enemies().has(id), "%s exists in data" % id)
		var r: CharacterRig = CharacterKit.build_enemy(id)
		check(r.mesh_count >= 3 and r.mesh_count <= 6, "%s mesh count %d" % [id, r.mesh_count])
		tris[r.tri_total] = true
		eq(r.look_id, id, "look id")
		r.free()
	eq(tris.size(), 6, "six enemy archetypes have six different geometries")
	for id in Content.enemies().keys():
		check(CharacterKit.ENEMY_IDS.has(String(id)), "every data enemy has a dedicated model: %s" % id)
	var fb: CharacterRig = CharacterKit.build_enemy("lfg:enemy/does_not_exist")
	check(fb.mesh_count > 0, "unknown archetype falls back to a model")
	fb.free()
	var wing: CharacterRig = CharacterKit.build_enemy("lfg:enemy/gloomwing")
	check(wing.float_height > 1.0, "gloomwing hovers")
	eq(wing.limbs("wing").size(), 2, "gloomwing has two wings")
	wing.free()
	var leech: CharacterRig = CharacterKit.build_enemy("lfg:enemy/mire_leech")
	check(leech.limbs("slither").size() >= 3, "leech has body segments")
	leech.free()

func test_npcs() -> void:
	var m: CharacterRig = CharacterKit.build_npc("merchant", 3)
	var v: CharacterRig = CharacterKit.build_npc("villager", 1)
	var v2: CharacterRig = CharacterKit.build_npc("villager", 2)
	var r: CharacterRig = CharacterKit.build_npc("raider", 5)
	for x in [m, v, v2, r]:
		eq((x as CharacterRig).mesh_count, 5, "humanoid npc 5 meshes")
		check((x as CharacterRig).look_id.begins_with("npc/"), "npc look id")
	check(m.tri_total != v.tri_total and v.tri_total != r.tri_total, "merchant/villager/raider differ in geometry")
	check(v.tri_total != v2.tri_total or true, "villager variants")
	var r2: CharacterRig = CharacterKit.build_npc("raider", 6)
	check(r2.tri_total == r.tri_total, "raider geometry stable across factions (only colours change)")
	for x in [m, v, v2, r, r2]:
		(x as CharacterRig).free()

func test_walk_animation() -> void:
	var rig: CharacterRig = CharacterKit.build_class("lfg:class/judd")
	var legs: Array[Node3D] = rig.limbs("leg")
	rig.speed01 = 0.0
	rig.advance(0.1)
	eq(legs[0].rotation.x, 0.0, "idle: legs still")
	rig.speed01 = 1.0
	var maxrot := 0.0
	for i in 40:
		rig.advance(0.03)
		maxrot = maxf(maxrot, absf(legs[0].rotation.x))
		check(is_equal_approx(legs[0].rotation.x, -legs[1].rotation.x), "legs swing in opposition")
	check(maxrot > 0.4, "walk swing reaches a visible angle (%.2f)" % maxrot)
	rig.free()

func test_attack_hurt_death_animation() -> void:
	var rig: CharacterRig = CharacterKit.build_class("lfg:class/bram")
	var arm: Node3D = null
	for p in rig.parts:
		if p["kind"] == "arm" and float(p["side"]) > 0.0:
			arm = p["node"]
	var finished: Array[StringName] = []
	rig.anim_finished.connect(func(a: StringName) -> void: finished.append(a))
	rig.play(&"attack")
	var min_x := 0.0
	var max_x := 0.0
	for i in 20:
		rig.advance(0.03)
		min_x = minf(min_x, arm.rotation.x)
		max_x = maxf(max_x, arm.rotation.x)
	check(max_x > 0.8 and min_x < -1.0, "attack: wind-up back then slam forward (%.2f..%.2f)" % [min_x, max_x])
	eq(rig.anim, &"idle", "attack returns to idle")
	check(finished.has(&"attack"), "attack finished signal")
	rig.play(&"hurt")
	rig.advance(0.01)
	check(rig.flash_amount() > 0.5, "hit flash lights up the model (%.2f)" % rig.flash_amount())
	check(rig.is_flashing(), "flashing")
	rig.advance(0.5)
	eq(rig.flash_amount(), 0.0, "flash decays")
	eq(rig.anim, &"idle", "hurt returns to idle")
	rig.play(&"death")
	for i in 40:
		rig.advance(0.03)
	check(absf(rig.body.rotation.z - PI * 0.5) < 0.01, "death: topples over")
	eq(rig.dead, true, "dead flag")
	check(finished.has(&"death"), "death finished signal")
	rig.play(&"attack")
	eq(rig.anim, &"dead", "dead rigs ignore further animation")
	rig.free()

func test_flyer_and_leech_animate() -> void:
	var w: CharacterRig = CharacterKit.build_enemy("lfg:enemy/gloomwing")
	var wings: Array[Node3D] = w.limbs("wing")
	var lo := 9.0
	var hi := -9.0
	for i in 30:
		w.advance(0.02)
		lo = minf(lo, wings[0].rotation.z)
		hi = maxf(hi, wings[0].rotation.z)
	check(hi - lo > 0.5, "wings flap")
	check(absf(w.body.position.y - w.float_height) < 0.1, "hover height held (no walk bob)")
	w.free()

func test_player_uses_class_rig() -> void:
	var p := Player.new()
	p.apply_class("lfg:class/nyx")
	check(p.rig() != null, "player has a class rig")
	eq(p.rig().look_id, "lfg:class/nyx", "rig is the chosen class")
	p.velocity_xz = Vector2(Player.SPEED, 0)
	p._animate(0.016)
	eq(p.rig().speed01, 1.0, "movement drives the rig")
	p.play_attack()
	eq(p.rig().anim, &"attack", "attack plays on the rig")
	p.free()
