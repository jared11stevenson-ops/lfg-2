extends Node2D
# Enemy with 2D puppet sprites and a trait system (see creatures.gd for per-species values).
const PuppetLib = preload("res://puppet_lib.gd")
const FxScript = preload("res://fx.gd")
const BASE_SCALE := 0.56
signal died(e)
signal leaked(e)

var path: PackedVector2Array
var zones: Array = []
var kind := "shuckit"
var sprite_id := "shuckit"
var seg := 0
var travelled := 0.0
var speed := 120.0
var hp := 18.0
var max_hp := 18.0
var types: Array = []
var reward := 5
var leak := 1
var armor := 0.0
var regen := 0.0
var shield := 0.0
var dodge := 0.0
var rebirth := 0
var enrage := false
var heal_aura := 0.0
var speed_aura := false
var chill_aura := false
var jump_every := 0.0
var split := 0
var flying := false
var is_boss := false
var elite := false
var scale_mul := 1.0
var boost_t := 0.0
var slow_t := 0.0
var slow_f := 1.0
var poison := 0
var poison_t := 0.0
var poison_mul := 1.0
var spread_all := false
var stun_t := 0.0
var stun_immune_t := 0.0
var pulled_total := 0.0
const MAX_PULL := 450.0   # anti-exploit: total drag-back an enemy can ever suffer
var vuln_t := 0.0
var vuln_f := 1.2
var wet_t := 0.0
var chill_stacks := 0
var chill_t := 0.0
var jump_cd := 0.0
var face_left := false
var dead := false
var flash_t := 0.0
var anim := 0.0
var tint := Color.WHITE
var rare := false         # level rare encounter (e.g. Hutzin on Mossgate): worth catching
var shiny := false        # rare gold variant: tougher, pays 3x, double XP when captured
var capture_pct := 0
var spawn_t := 0.0        # seconds since spawning (drives the pop-in)
var held := false         # sealed in a Lure orb during the capture animation
var capturable := false   # set by main each frame: weak enough, not a boss, and a defender species exists

func setup(p: PackedVector2Array, d: Dictionary, wave: int) -> void:
	path = p
	kind = d.id
	sprite_id = d.get("sprite", d.id)
	hp = float(d.hp) + float(d.hp_wave) * wave
	max_hp = hp
	speed = float(d.speed)
	types = d.types
	reward = int(d.reward)
	leak = int(d.leak)
	armor = float(d.get("armor", 0.0))
	regen = float(d.get("regen", 0.0))
	shield = float(d.get("shield", 0.0))
	dodge = float(d.get("dodge", 0.0))
	rebirth = int(d.get("rebirth", 0))
	enrage = bool(d.get("enrage", false))
	heal_aura = float(d.get("heal_aura", 0.0))
	speed_aura = bool(d.get("speed_aura", false))
	chill_aura = bool(d.get("chill_aura", false))
	jump_every = float(d.get("jump_every", 0.0))
	split = int(d.get("split", 0))
	flying = bool(d.get("flying", false))
	is_boss = bool(d.get("boss", false))
	scale_mul = float(d.get("scale", 1.0))
	if d.has("tint"):
		tint = Color(String(d.tint))
	jump_cd = jump_every

func make_elite() -> void:
	elite = true
	hp *= 2.2
	max_hp = hp
	reward *= 2
	scale_mul *= 1.3

func _ready() -> void:
	add_to_group("enemies")
	position = path[0]
	anim = randf() * 10.0

func boost(t: float) -> void:
	boost_t = maxf(boost_t, t)

func apply_slow(f: float, t: float) -> void:
	slow_f = minf(slow_f if slow_t > 0.0 else 1.0, f)
	slow_t = maxf(slow_t, t)

func add_poison(n: int, mul: float = 1.0, cap: int = 5, spread: bool = false) -> void:
	poison = mini(poison + n, cap)
	poison_mul = maxf(poison_mul, mul)
	spread_all = spread_all or spread
	poison_t = 4.0

func stun(t: float) -> void:
	# Anti-exploit: after a stun ends the enemy is immune for 1s; bosses only take half.
	if stun_immune_t > 0.0:
		return
	stun_t = maxf(stun_t, t * (0.5 if is_boss else 1.0))

# Chill stacks (Ptarmitten): 3 stacks freeze for 1s.
func add_chill(n: int) -> void:
	chill_stacks += n
	chill_t = 3.0
	if chill_stacks >= 3:
		chill_stacks = 0
		stun(1.0)
		apply_slow(0.6, 2.0)

# Drag the enemy back along its path by px pixels.
func rewind(px: float) -> void:
	if is_boss:
		px *= 0.25
	px = minf(px, MAX_PULL - pulled_total)
	if px <= 0.0:
		return
	pulled_total += px
	while px > 0.0:
		var start := path[seg]
		var d := position.distance_to(start)
		if px < d:
			position += (start - position).normalized() * px
			travelled -= px
			return
		position = start
		travelled -= d
		px -= d
		if seg == 0:
			return
		seg -= 1

func advance(px: float) -> void:
	while px > 0.0 and seg + 1 < path.size():
		var d := position.distance_to(path[seg + 1])
		if px < d:
			position += position.direction_to(path[seg + 1]) * px
			travelled += px
			return
		position = path[seg + 1]
		travelled += d
		px -= d
		seg += 1

func _zone_mult(delta: float) -> float:
	var m := 1.0
	if flying:
		return m
	for z in zones:
		if position.distance_to(z.pos) < float(z.r):
			match String(z.kind):
				"bog": m *= 0.6
				"ice": m *= 1.35
				"belt": m *= 1.5
				"burn": take_damage(7.0 * delta)
	return m

func _process(delta: float) -> void:
	if dead or held:
		return
	spawn_t += delta
	boost_t = maxf(0.0, boost_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	poison_t = maxf(0.0, poison_t - delta)
	wet_t = maxf(0.0, wet_t - delta)
	chill_t = maxf(0.0, chill_t - delta)
	if chill_t <= 0.0:
		chill_stacks = 0
	var was_stunned := stun_t > 0.0
	stun_t = maxf(0.0, stun_t - delta)
	stun_immune_t = maxf(0.0, stun_immune_t - delta)
	if was_stunned and stun_t <= 0.0:
		stun_immune_t = 1.0
	vuln_t = maxf(0.0, vuln_t - delta)
	if poison_t <= 0.0:
		poison = 0
		poison_mul = 1.0
		spread_all = false
	if regen > 0.0 and poison == 0:
		hp = minf(max_hp, hp + regen * delta)
	if poison > 0:
		take_damage(2.5 * poison_mul * poison * delta)
		if dead:
			return
	_auras(delta)
	if seg + 1 >= path.size():
		dead = true
		leaked.emit(self)
		queue_free()
		return
	if stun_t > 0.0:
		queue_redraw()
		return
	if jump_every > 0.0:
		jump_cd -= delta
		if jump_cd <= 0.0:
			jump_cd = jump_every
			advance(90.0)
			FxScript.text_at(get_parent(), position + Vector2(0, -50), "Hop!", Color("9be7ff"))
	var target := path[seg + 1]
	var rage := 1.0 + (0.7 * (1.0 - hp / max_hp) if enrage else 0.0)
	var step := speed * rage * _zone_mult(delta) * (1.3 if boost_t > 0.0 else 1.0) * (slow_f if slow_t > 0.0 else 1.0) * delta
	var d := position.distance_to(target)
	var dir := (target - position).normalized() if d > 0.001 else Vector2.RIGHT
	if absf(dir.x) > 0.3:
		face_left = dir.x < 0.0
	if step >= d:
		position = target
		seg += 1
		travelled += d
	else:
		position += dir * step
		travelled += step
	anim += step * 0.09
	queue_redraw()

func _auras(delta: float) -> void:
	if heal_aura <= 0.0 and not speed_aura and not chill_aura:
		return
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or o.dead:
			continue
		if position.distance_to(o.position) < 150.0:
			if heal_aura > 0.0:
				o.hp = minf(o.max_hp, o.hp + heal_aura * delta)
			if speed_aura:
				o.boost(0.3)
	if chill_aura:
		for t in get_tree().get_nodes_in_group("towers"):
			if position.distance_to(t.position) < 140.0:
				t.chilled_t = 0.3

func take_damage(amount: float) -> void:
	if dead or held:
		return
	if amount >= 1.5:
		if dodge > 0.0 and randf() < dodge:
			FxScript.text_at(get_parent(), position + Vector2(0, -50), "Miss!", Color("e0c8ff"))
			return
		if armor > 0.0:
			amount = maxf(1.0, amount - armor)
	amount *= (vuln_f if vuln_t > 0.0 else 1.0)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	hp -= amount
	flash_t = 0.12
	load("res://sfx.gd").play(self, "hit", -20.0, 70)
	if hp <= 0.0:
		if rebirth > 0:
			rebirth -= 1
			hp = max_hp * 0.5
			FxScript.text_at(get_parent(), position + Vector2(0, -50), "Reborn!", Color("ffb040"))
			return
		dead = true
		died.emit(self)
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var s := BASE_SCALE * scale_mul
	var lift := -16.0 if flying else 0.0
	var big := scale_mul >= 1.3
	if slow_t > 0.0:
		draw_circle(Vector2(0, 6), 26 * scale_mul, Color(0.4, 0.8, 1.0, 0.3))
	if poison > 0:
		draw_circle(Vector2(0, 6), (20 + poison * 2) * scale_mul, Color(0.6, 0.2, 0.8, 0.3))
	if wet_t > 0.0:
		draw_circle(Vector2(0, 6), 22 * scale_mul, Color(0.3, 0.6, 1.0, 0.25))
	if heal_aura > 0.0:
		draw_arc(Vector2.ZERO, 150.0, 0, TAU, 40, Color(0.5, 1.0, 0.6, 0.18), 2.0, true)
	if speed_aura:
		draw_arc(Vector2.ZERO, 150.0, 0, TAU, 40, Color(1.0, 0.9, 0.4, 0.18), 2.0, true)
	if chill_aura:
		draw_arc(Vector2.ZERO, 140.0, 0, TAU, 40, Color(0.6, 0.85, 1.0, 0.22), 2.0, true)
	if shield > 0.0:
		draw_arc(Vector2(0, -26 * scale_mul), 34 * scale_mul, 0, TAU, 28, Color(0.6, 0.9, 1.0, 0.8), 3.0, true)
	PuppetLib.shadow(self, scale_mul * (0.8 if flying else 1.0), Vector2(0, 8 + (10 if flying else 0)))
	var moving := stun_t <= 0.0
	var state := "walk" if moving else "idle"
	var frame := int(anim) if moving else int(Time.get_ticks_msec() / 160.0)
	var hurt := Color(1.0, 0.55, 0.55) if flash_t > 0.0 else (Color(1.3, 1.1, 0.5) if shiny else (Color(1.0, 0.9, 0.55) if elite else tint))
	var fl := sin(Time.get_ticks_msec() / 220.0 + anim) * 3.0 if flying else 0.0
	var pop_in := minf(1.0, spawn_t / 0.35)
	var pop_s := 1.0 + 0.25 * sin(pop_in * PI) * (1.0 - pop_in) if pop_in < 1.0 else 1.0
	PuppetLib.draw(self, sprite_id, state, frame, face_left, s * (1.0 + flash_t * 1.2) * lerpf(0.4, 1.0, pop_in) * pop_s, Vector2(0, lift + fl + 6), Color(hurt.r, hurt.g, hurt.b, lerpf(0.0, 1.0, minf(1.0, pop_in * 1.6))))
	if capturable:
		var pr := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		draw_arc(Vector2(0, -22 * scale_mul), 34.0 * scale_mul + pr * 3.0, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.9), 3.0, true)
		var ly := -62.0 * scale_mul - 14.0
		if global_position.y < 190.0:
			ly = 34.0 * scale_mul + 8.0
		draw_string_outline(ThemeDB.fallback_font, Vector2(-60, ly), "Capture %d%%" % capture_pct, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, 5, Color(0.1, 0.05, 0.2))
		draw_string(ThemeDB.fallback_font, Vector2(-60, ly), "Capture %d%%" % capture_pct, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 0.95, 0.6))
	if rare:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -92 * scale_mul - (14 if shiny else 0)), "RARE", HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color(0.7, 1.0, 0.8))
	if shiny:
		var tw := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0 + anim)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -92 * scale_mul), "✦ SHINY ✦", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1.0, 0.92, 0.4, 0.6 + 0.4 * tw))
	if elite:
		draw_string(ThemeDB.fallback_font, Vector2(-8, -80 * scale_mul - 8), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd23a"))
	if hp < max_hp or is_boss:
		var w := 90.0 if is_boss else (50.0 if big else 34.0)
		var y := (-100.0 if is_boss else -78.0 * scale_mul) + lift
		draw_rect(Rect2(-w / 2, y, w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2 + 1, y + 1, (w - 2) * clampf(hp / max_hp, 0.0, 1.0), 4), Color("5aa8ff") if is_boss else Color("7bdc6a"))
