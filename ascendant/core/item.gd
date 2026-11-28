class_name Item
extends RefCounted
## Every crafted item has a persistent identity and a life story. Legend is EARNED from the history.
static var next_id := 1
var id := 0
var func_id := ""
var design: Dictionary = {}
var name := ""
var quality := 0.5
var creator := ""            # creator name/lineage
var made_tick := 0
var made_by_species := ""
var history: Array = []      # {tick, kind, text, weight}
var owners: Array = []       # names
var repairs := 0
var hits := 0
var kills := 0
var battles := 0
var wear := 0.0              # 0..1 destroyed
var lost := false
var epithet := ""            # earned names

static func create(func_id_: String, design_: Dictionary, quality_: float, creator_: String, tick: int, species_: String) -> Item:
	var it := Item.new()
	it.id = Item.next_id; Item.next_id += 1
	it.func_id = func_id_; it.design = design_.duplicate(); it.quality = quality_
	it.creator = creator_; it.made_tick = tick; it.made_by_species = species_
	it.name = Invention.design_name(func_id_, design_)
	it.owners = [creator_]
	it.log_event(tick, "made", "Made by %s of the %s from %s." % [creator_, species_, _mats(design_)], 1.0)
	return it

static func _mats(d: Dictionary) -> String:
	var parts := []
	for r in d: parts.append("%s (%s)" % [d[r], r])
	return ", ".join(parts)

func log_event(tick: int, kind: String, text: String, weight: float) -> void:
	history.append({"tick": tick, "kind": kind, "text": text, "weight": weight})
	if history.size() > 80: history.pop_at(1)

## Legend is the sum of accomplishments, not a random rarity roll.
func legend() -> float:
	var s := 0.0
	for h in history: s += h["weight"]
	s += kills * 0.6 + battles * 0.4 + owners.size() * 0.3 + repairs * 0.2
	return s

func legend_tier() -> int:
	var l := legend()
	if l >= 40.0: return 4   # legendary
	if l >= 20.0: return 3   # storied
	if l >= 9.0: return 2    # known
	if l >= 4.0: return 1    # used
	return 0

const TIER_NAMES := ["Plain", "Worn-in", "Known", "Storied", "Legendary"]

func power() -> float:
	var tier_bonus: float = [0.0, 0.05, 0.12, 0.22, 0.38][legend_tier()]
	return (quality - 0.4) * 0.8 * (1.0 - wear * 0.6) + tier_bonus

func record_kill(victim: String, tick: int) -> void:
	kills += 1; battles += 1
	log_event(tick, "kill", "Slew a %s." % victim, 0.8 if victim != "" else 0.4)
	_check_epithet(tick)

func _check_epithet(tick: int) -> void:
	if epithet == "" and kills >= 5:
		epithet = "the Reaper" if func_id in ["cut", "pierce"] else "the Breaker"
		log_event(tick, "epithet", "Is now called %s." % epithet, 2.0)
	elif kills >= 15 and not epithet.begins_with("Great"):
		epithet = "Great " + epithet.replace("the ", "")
		log_event(tick, "epithet", "Is now known as %s." % epithet, 3.0)

func transfer(new_owner: String, how: String, tick: int) -> void:
	owners.append(new_owner)
	log_event(tick, how, "%s by %s." % [how.capitalize(), new_owner], 1.2 if how in ["inherited", "captured"] else 0.6)

func display_name() -> String:
	return name + ((" " + epithet) if epithet != "" else "")

func to_dict() -> Dictionary:
	return {"id": id, "func": func_id, "design": design, "name": name, "quality": quality, "creator": creator, "made": made_tick, "sp": made_by_species, "history": history, "owners": owners, "repairs": repairs, "hits": hits, "kills": kills, "battles": battles, "wear": wear, "epithet": epithet}

static func from_dict(d: Dictionary) -> Item:
	var it := Item.new()
	it.id = d["id"]; it.func_id = d["func"]; it.design = d["design"]; it.name = d["name"]; it.quality = d["quality"]
	it.creator = d["creator"]; it.made_tick = d["made"]; it.made_by_species = d["sp"]; it.history = d["history"]; it.owners = d["owners"]
	it.repairs = d["repairs"]; it.hits = d["hits"]; it.kills = d["kills"]; it.battles = d["battles"]; it.wear = d["wear"]; it.epithet = d["epithet"]
	Item.next_id = maxi(Item.next_id, it.id + 1)
	return it
