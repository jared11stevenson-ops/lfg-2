class_name MatchState
extends RefCounted
## Authoritative match state. Plain data only. Hex values are Vector2i in memory, {"_v":[q,r]} in to_dict().
const SCHEMA_VERSION := 1
const SAVE_FIELDS: Array[String] = ["schema_version", "seed", "rng_state", "clock", "phase", "day_seconds", "actors", "holdings",
	"factions", "plots", "drops", "player_id", "next_id", "settled_week", "over", "result", "won", "ai_t", "opts", "sim_acc"]

var schema_version: int = SCHEMA_VERSION
var seed: int = 0
var rng_state: int = 1
var clock: Dictionary = {"day": 1, "time_of_day": 0.0, "elapsed": 0.0, "day_t": 0.0}  # day_t = seconds into the day (authoritative)
var phase: StringName = &"PEACE"
var day_seconds: float = 360.0
var actors: Dictionary = {}     # id -> actor dict
var holdings: Dictionary = {}   # id -> holding dict
var factions: Dictionary = {}   # faction id -> {id,name,is_ai,leader,home,alive,hunger_days,persona}
var plots: Dictionary = {}      # "q,r" -> {crop, age, watered, dry_days, holding}
var drops: Dictionary = {}      # "q,r" -> inventory dict
var world: Dictionary = {}      # generated terrain (not serialised; regenerated from seed)
var player_id: int = 1
var next_id: int = 100
var settled_week: int = -1
var over: bool = false
var result: Dictionary = {}     # {reason, day} once match_over
var won: String = ""            # "", "dominion", "crowned" (match continues in Endless)
var ai_t: float = 0.0
var sim_acc: Dictionary = {}    # misc timers
var opts: Dictionary = {}

## Quantise floats to 1e-6 so JSON round trips are bit-exact.
static func q(x: float) -> float:
	return roundf(x * 1000000.0) / 1000000.0

func set_time(day: int, tod: float) -> void:
	clock["day"] = day
	clock["day_t"] = q(tod * day_seconds)
	clock["time_of_day"] = q(tod)
	phase = Calendar.phase_for(day, tod)

func tod() -> float:
	return float(clock["day_t"]) / day_seconds

func rand_f() -> float:
	var r := Rng.new(1)
	r.state = rng_state
	var v: float = r.rand_f()
	rng_state = r.state
	return v

func rand_i(n: int) -> int:
	return 0 if n <= 1 else int(rand_f() * float(n))

func new_id() -> int:
	next_id += 1
	return next_id

func player() -> Dictionary:
	return actors.get(player_id, {})

func week() -> int:
	return (int(clock["day"]) - 1) / 7

func day_of_week() -> int:
	return ((int(clock["day"]) - 1) % 7) + 1

func holdings_of(faction: int) -> Array[int]:
	var out: Array[int] = []
	for id in holdings.keys():
		if int(holdings[id]["owner"]) == faction:
			out.append(int(id))
	out.sort()
	return out

static func plot_key(h: Vector2i) -> String:
	return "%d,%d" % [h.x, h.y]

# ---------- serialisation ----------
static func _enc(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2I:
			return {"_v": [v.x, v.y]}
		TYPE_STRING_NAME:
			return String(v)
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in (v as Dictionary).keys():
				d[str(k)] = _enc(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for e in (v as Array):
				a.append(_enc(e))
			return a
		_:
			return v

static func _dec(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var src: Dictionary = v
			if src.size() == 1 and src.has("_v"):
				return Vector2i(int(src["_v"][0]), int(src["_v"][1]))
			var d: Dictionary = {}
			for k in src.keys():
				var key: Variant = k
				if typeof(k) == TYPE_STRING and (k as String).is_valid_int():
					key = int(k)
				d[key] = _dec(src[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for e in (v as Array):
				a.append(_dec(e))
			return a
		TYPE_FLOAT:
			var f: float = v
			if f == floorf(f) and absf(f) < 9007199254740992.0:
				return int(f)
			return f
		_:
			return v

func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for f in SAVE_FIELDS:
		out[f] = _enc(get(f))
	out["world_gen"] = {"version": WorldGen.VERSION}
	return out

static func from_dict(d: Dictionary) -> MatchState:
	var s := MatchState.new()
	for f in SAVE_FIELDS:
		if d.has(f):
			s.set(f, _dec(d[f]))
	s.phase = StringName(String(s.phase))
	s.day_seconds = float(s.day_seconds)
	s.clock["time_of_day"] = float(s.clock["time_of_day"])
	s.clock["day_t"] = float(s.clock.get("day_t", float(s.clock["time_of_day"]) * s.day_seconds))
	s.clock["elapsed"] = float(s.clock["elapsed"])
	s.ai_t = float(s.ai_t)
	s.world = WorldGen.generate(s.seed)
	return s
