extends Node
## Autoload "Lineage": the persistent state of YOUR bloodline across every
## life. Owns the genome, eaten (latent) genes, echoes, ecology and saves.

signal instar_started
signal instar_ended(summary: Dictionary)

const SAVE_PATH := "user://lineage.json"
const MAX_ECHOES := 10
const MAX_LATENT := 10
const INSTAR_SECONDS := 420.0

var generation := 1
var genome: Genome = Genome.new()
var latent: Array = []            # eaten alleles awaiting expression
var bile := 0                     # currency of the body
var echoes: Array = []            # Echo dictionaries
var ecology: Ecology = Ecology.new()
var district_seed := 1
var run := {}                     # live counters for the current instar
var last_summary := {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_install_input()
	rng.randomize()

func _install_input() -> void:
	var binds := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_J, KEY_SPACE], "ability_1": [KEY_K], "ability_2": [KEY_L],
		"ability_3": [KEY_SEMICOLON], "scent_toggle": [KEY_Q], "molt": [KEY_E],
		"emit": [KEY_F],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in binds[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------- lifecycle
func new_lineage(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	generation = 1
	genome = Genome.new()
	# A first body worth playing: one common gene per slot-pair seeded by fate.
	genome.set_pair(0, Genome.make_allele("mandible_shear"), Genome.make_allele(GeneDB.baseline(0)))
	genome.set_pair(3, Genome.make_allele("saltatorial_legs"), Genome.make_allele(GeneDB.baseline(3)))
	genome.set_pair(5, Genome.make_allele("chitin_plate"), Genome.make_allele(GeneDB.baseline(5)))
	latent = []
	bile = 0
	echoes = []
	ecology = Ecology.new()
	district_seed = rng.randi_range(1, 999999)
	ecology.step(rng, 2)

func start_instar() -> void:
	var st := genome.stats()
	run = {"kills": 0, "recruits": 0, "calms": 0, "bile": 0, "damage_taken": 0.0,
		"stress": 0.0, "time": 0.0, "eaten": [], "scent": [0.5, 0.5, 0.5, 0.5],
		"max_hp": st.hp, "cause": "molted", "parleys": 0}
	instar_started.emit()

func add_latent(allele: Dictionary) -> void:
	latent.append(allele.duplicate())
	if latent.size() > MAX_LATENT:
		latent.pop_front()
	(run.eaten as Array).append(allele.id)

## Closes the current life: bank bile, mint an Echo, advance the ecosystem.
func end_instar(cause: String) -> Dictionary:
	run["cause"] = cause
	var summary: Dictionary = run.duplicate(true)
	bile += int(run.bile)
	# Dying costs you half the bile you were carrying home; molting is safe.
	if cause == "died":
		bile -= int(run.bile / 2)
	var echo := Echo.make(genome, generation, summary, rng)
	echoes.push_front(echo)
	if echoes.size() > MAX_ECHOES:
		echoes.pop_back()
	# The world keeps living while you pupate: more steps the longer you lived.
	ecology.step(rng, 2 + int(clampf(float(run.time) / 120.0, 0.0, 4.0)))
	summary["echo"] = echo
	last_summary = summary
	instar_ended.emit(summary)
	return summary

func complete_pupation(new_genome: Genome, bile_spent: int) -> void:
	genome = new_genome
	bile = maxi(0, bile - bile_spent)
	generation += 1
	save_game()

func stress_value() -> float:
	return clampf(float(last_summary.get("stress", 0.0)), 0.0, 1.0)

# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	return {"v": 1, "generation": generation, "genome": genome.to_dict(), "latent": latent,
		"bile": bile, "echoes": echoes, "ecology": ecology.to_dict(), "district_seed": district_seed}

func from_dict(d: Dictionary) -> void:
	generation = int(d.get("generation", 1))
	genome = Genome.from_dict(d.get("genome", {}))
	latent = []
	for a in d.get("latent", []):
		if not GeneDB.get_gene(String(a.id)).is_empty():
			latent.append({"id": String(a.id), "mut": int(a.mut)})
	bile = int(d.get("bile", 0))
	echoes = d.get("echoes", [])
	ecology = Ecology.from_dict(d.get("ecology", {}))
	district_seed = int(d.get("district_seed", 1))

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	from_dict(parsed)
	return true
