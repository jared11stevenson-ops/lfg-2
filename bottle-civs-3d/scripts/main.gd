extends Node3D
## Builds the room, the Wall of twelve jars, the tubes between them, and runs the simulation.
## Command line (after `--`):  --seed=7  --speed=4  --shot=/tmp/a.png  --days=3  --focus=2  --night  --size=1600x900

const SPX := 19.8
const SPZ := 15.6
const ROW_STEP := 3.2
const FLOOR_Y := -7.5

var sim: BCSim
var jars: Array = []
var tubes: Array = []                 # [{a,b,from,to,mesh}]
var party_actors := {}                # party id -> Array[BCActor]
var cam: BCCamRig
var hud: BCHud
var sun: DirectionalLight3D
var env: Environment
var speed := 1.0
var paused := false
var acc := 0.0
var ui_t := 0.0
var selected := -1
var hover := -1
var args := {}
var clock_now := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	sim = BCSim.new(int(args.get("seed", -1)))
	speed = float(args.get("speed", 1.0))
	_build_environment()
	_build_room()
	_build_wall()
	_build_tubes()
	cam = BCCamRig.new()
	add_child(cam)
	hud = BCHud.new()
	add_child(hud)
	hud.build(sim)
	hud.speed_changed.connect(func(m): speed = m; paused = false; hud.set_speed_ui(speed, paused))
	hud.pause_toggled.connect(func(): paused = not paused; hud.set_speed_ui(speed, paused))
	hud.civ_picked.connect(_select)
	hud.overview_pressed.connect(func(): _select(-1))
	hud.set_speed_ui(speed, paused)
	if args.has("shot"):
		_run_shot()

# ------------------------------------------------------------------ scene
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/pbr/brown_photostudio_02_1k.hdr")
	sky.sky_material = pano
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.0
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.5, 0.62)
	env.fog_density = 0.0016
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	if args.has("lowfx"):
		env.ssil_enabled = false
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.fog_enabled = false
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -25, 0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.5
	add_child(sun)

func jar_origin(i: int) -> Vector3:
	var col := i % BCData.COLS
	var row := i / BCData.COLS
	return Vector3((float(col) - 1.5) * SPX, float(BCData.ROWS - 1 - row) * ROW_STEP, (float(row) - 1.0) * SPZ)

func _build_room() -> void:
	var floor_m := BCAssets.pbr("concrete_floor_worn_001", Vector3(0.08, 0.08, 0.08), Color(0.85, 0.85, 0.9))
	var wall_m := BCAssets.pbr("concrete_wall_004", Vector3(0.07, 0.07, 0.07), Color(0.75, 0.8, 0.9))
	var floor_ := BCAssets.box(Vector3(260, 1.0, 200), floor_m, Vector3(0, FLOOR_Y - 0.5, -10))
	add_child(floor_)
	add_child(BCAssets.box(Vector3(260, 90, 1.0), wall_m, Vector3(0, FLOOR_Y + 45, -SPZ - 17.0)))
	add_child(BCAssets.box(Vector3(1.0, 90, 200), wall_m, Vector3(-100, FLOOR_Y + 45, -10)))
	add_child(BCAssets.box(Vector3(1.0, 90, 200), wall_m, Vector3(100, FLOOR_Y + 45, -10)))
	# stepped steel terraces the jars sit on
	var steel := BCAssets.pbr("box_profile_metal_sheet", Vector3(0.18, 0.18, 0.18))
	for row in BCData.ROWS:
		var y := float(BCData.ROWS - 1 - row) * ROW_STEP - 2.75
		var h := y - FLOOR_Y
		var z := (float(row) - 1.0) * SPZ
		add_child(BCAssets.box(Vector3(4 * SPX + 6.0, h, SPZ - 1.0), steel, Vector3(0, FLOOR_Y + h / 2.0, z)))
		var trim := BCAssets.box(Vector3(4 * SPX + 6.4, 0.35, SPZ - 0.6), BCAssets.pbr("metal_plate", Vector3(0.3, 0.3, 0.3), Color(0.8, 0.85, 1.0)), Vector3(0, y + 0.1, z))
		add_child(trim)
	# overhead strip lights (emissive panels) for cool highlights on the glass
	for i in 5:
		add_child(BCAssets.box(Vector3(60, 0.3, 3), BCAssets.emissive(Color(0.8, 0.9, 1.0), 4.0), Vector3(0, 80, -50 + i * 24)))

func _build_wall() -> void:
	for i in 12:
		var j := BCJar.new()
		add_child(j)
		j.position = jar_origin(i)
		j.setup(sim, i)
		jars.append(j)

func _build_tubes() -> void:
	var glass := BCAssets.glass(Color(0.55, 0.95, 0.85, 0.16))
	var collar := BCAssets.pbr("metal_plate", Vector3(0.3, 0.3, 0.3), Color(0.9, 0.95, 1.0))
	var idx_n := 0
	for l in sim.links:
		var a: int = l.x
		var b: int = l.y
		var pa := jar_origin(a)
		var pb := jar_origin(b)
		var off := 0.0
		if b - a == BCData.COLS - 1: off = 2.2          # keep the two diagonals from intersecting
		var from := pa + Vector3(0, 1.3 + off, 0)
		var to := pb + Vector3(0, 1.3 + off, 0)
		var dir := (to - from)
		var dxz := Vector2(dir.x, dir.z)
		var n2 := dxz.normalized()
		# clip the segment to the jar rim on both ends
		var ex := (BCJar.HALF_X + 0.9) / maxf(absf(n2.x), 0.0001)
		var ez := (BCJar.HALF_Z + 0.9) / maxf(absf(n2.y), 0.0001)
		var clip := minf(ex, ez)
		var total := dxz.length()
		var t0 := clip / total
		var s := from.lerp(to, t0)
		var e := from.lerp(to, 1.0 - t0)
		var node := Node3D.new()
		node.name = "Tube_%d_%d" % [a, b]
		add_child(node)
		var len := s.distance_to(e)
		var cyl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.95; cm.bottom_radius = 0.95; cm.height = len; cm.radial_segments = 20
		cyl.mesh = cm
		cyl.material_override = glass
		cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(cyl)
		var mid := (s + e) / 2.0
		var axis := (e - s).normalized()
		var q := Quaternion(Vector3.UP, axis)
		cyl.global_transform = Transform3D(Basis(q), mid)
		for end in [s, e]:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.95; tm.outer_radius = 1.2
			ring.mesh = tm
			ring.material_override = collar
			node.add_child(ring)
			ring.global_transform = Transform3D(Basis(q) * Basis(Vector3.RIGHT, 0.0), end)
			ring.global_transform.basis = Basis(q)
		# glowing strip on the bottom of the tube
		var strip := BCAssets.box(Vector3(0.12, len, 0.12), BCAssets.emissive(Color(0.4, 1.0, 0.8), 2.0), Vector3.ZERO)
		node.add_child(strip)
		strip.global_transform = Transform3D(Basis(q), mid + Vector3(0, -0.7, 0))
		tubes.append({"a": a, "b": b, "s": s, "e": e, "strip": strip})
		idx_n += 1

# ------------------------------------------------------------------ loop
func _process(dt: float) -> void:
	clock_now += dt
	if not paused:
		acc += dt * speed
		var n := 0
		while acc >= 0.05 and n < 300:
			sim.step(0.05); acc -= 0.05; n += 1
		if n >= 300: acc = 0.0
	_update_lighting(dt)
	for j in jars:
		j.update_visuals(dt, clock_now)
	_update_tubes(dt)
	_update_parties(dt)
	ui_t += dt
	if ui_t > 0.25:
		ui_t = 0.0
		hud.refresh()

func _update_lighting(dt: float) -> void:
	var t := sim.t()
	var day_f := 1.0
	if t > BCSim.DUSK - 0.04: day_f = clampf(1.0 - (t - (BCSim.DUSK - 0.04)) / 0.08, 0.0, 1.0)
	elif t < 0.05: day_f = clampf(0.2 + t / 0.05 * 0.8, 0.0, 1.0)
	if sim.locked: day_f = minf(day_f, 0.12)
	var f := lerpf(0.12, 1.0, day_f)
	sun.light_energy = lerpf(sun.light_energy, 1.5 * f, minf(1.0, dt * 2.0))
	sun.light_color = Color(0.55, 0.62, 1.0).lerp(Color(1.0, 0.96, 0.9), f)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.25 + 0.7 * f, minf(1.0, dt * 2.0))
	env.fog_light_color = Color(0.08, 0.1, 0.2).lerp(Color(0.45, 0.5, 0.62), f)

func _update_tubes(dt: float) -> void:
	for tb in tubes:
		var m: MeshInstance3D = tb.strip
		var active := not sim.locked
		var war: bool = sim.civs[tb.a].war.has(tb.b)
		var c := Color(0.35, 1.0, 0.75) if active else Color(1.0, 0.2, 0.15)
		if war and active: c = Color(1.0, 0.45, 0.25)
		var mat: StandardMaterial3D = m.material_override
		mat.albedo_color = mat.albedo_color.lerp(c, minf(1.0, dt * 4.0))
		mat.emission = mat.albedo_color

func _tube_for(a: int, b: int) -> Dictionary:
	for tb in tubes:
		if (tb.a == a and tb.b == b) or (tb.a == b and tb.b == a): return tb
	return {}

func _update_parties(dt: float) -> void:
	var live := {}
	for p in sim.parties:
		if p.state != "out" and p.state != "back": continue
		var tb := _tube_for(p.from, p.to)
		if tb.is_empty(): continue
		live[p.id] = true
		var forward: Vector3 = (tb.e - tb.s).normalized() if tb.a == p.from else (tb.s - tb.e).normalized()
		var a_pos: Vector3 = tb.s if tb.a == p.from else tb.e
		var b_pos: Vector3 = tb.e if tb.a == p.from else tb.s
		var base := a_pos.lerp(b_pos, clampf(p.p, 0.0, 1.0))
		if not party_actors.has(p.id):
			party_actors[p.id] = []
		var list: Array = party_actors[p.id]
		var want := mini(3, p.members.size())
		while list.size() < want:
			var m = p.members[list.size()]
			var act := BCActor.new()
			add_child(act)
			act.setup(BCData.RACES[sim.dominant(m)])
			list.append(act)
		for i in list.size():
			var act: BCActor = list[i]
			var side := (float(i) - float(list.size() - 1) / 2.0) * 0.8
			var perp := Vector3(-forward.z, 0, forward.x)
			var run_dir := forward if p.state == "out" else -forward
			act.global_position = base + Vector3(0, -0.72, 0) + perp * side
			act.rotation.y = lerp_angle(act.rotation.y, atan2(run_dir.x, run_dir.z), minf(1.0, dt * 8.0))
			act.play("run" if p.kind == "raid" else "walk")
	for id in party_actors.keys():
		if not live.has(id):
			for act in party_actors[id]: (act as Node).queue_free()
			party_actors.erase(id)

# ------------------------------------------------------------------ input
func _select(i: int) -> void:
	selected = i
	for k in jars.size(): jars[k].selected = (k == i)
	hud.set_selected(i)
	if i >= 0: cam.focus(jar_origin(i))
	else: cam.overview()

func _pick(mouse: Vector2) -> int:
	var from := cam.cam.project_ray_origin(mouse)
	var dir := cam.cam.project_ray_normal(mouse)
	var best := -1
	var best_t := INF
	for i in jars.size():
		var bb: AABB = jars[i].rect_aabb
		bb.position += jars[i].global_position
		var hit = bb.intersects_ray(from, dir)
		if hit != null:
			var d := from.distance_to(hit)
			if d < best_t: best_t = d; best = i
	return best

func _unhandled_input(ev: InputEvent) -> void:
	cam.handle_input(ev)
	if ev is InputEventMouseMotion:
		var h := _pick(ev.position)
		for k in jars.size(): jars[k].hovered = (k == h)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var h2 := _pick(ev.position)
		_select(h2)
	elif ev is InputEventKey and ev.pressed:
		match ev.keycode:
			KEY_ESCAPE: _select(-1)
			KEY_SPACE: paused = not paused; hud.set_speed_ui(speed, paused)
			KEY_1: speed = 1.0; paused = false; hud.set_speed_ui(speed, paused)
			KEY_2: speed = 2.0; paused = false; hud.set_speed_ui(speed, paused)
			KEY_3: speed = 4.0; paused = false; hud.set_speed_ui(speed, paused)
			KEY_4: speed = 8.0; paused = false; hud.set_speed_ui(speed, paused)
			KEY_5: speed = 20.0; paused = false; hud.set_speed_ui(speed, paused)

# ------------------------------------------------------------------ screenshots (testing)
func _run_shot() -> void:
	var days := float(args.get("days", 0.0))
	var target_t := float(args.get("at", 0.35))
	var goal_day := 1 + int(days)
	var guard := 0
	while (sim.day < goal_day or sim.t() < target_t) and guard < 400000:
		sim.step(0.1); guard += 1
	if args.has("night"):
		while not sim.locked and guard < 800000:
			sim.step(0.1); guard += 1
		for i in 40: sim.step(0.1)
	if args.has("focus"):
		_select(int(args.focus))
		cam.jump_to_goal()
	# let animations / smoothing settle
	for i in int(args.get("frames", 60)):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(args.shot)
	print("shot saved ", args.shot, " day ", sim.day, " t ", sim.t(), " locked ", sim.locked, " pop ", sim.total_pop())
	get_tree().quit()
