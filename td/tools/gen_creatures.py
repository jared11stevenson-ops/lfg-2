#!/usr/bin/env python3
"""Generates td/creatures.gd from the tables below (single source of truth for creature data).
Run from repo root:  python3 td/tools/gen_creatures.py"""
import json, os

def U(name, cost, desc, **mods):
    d = {"name": name, "cost": cost, "desc": desc}
    d.update(mods)
    return d

# ---------------- ENEMY SPECIES (all 17 non-starter creatures) ----------------
# cost = wave-budget weight used by the wave generator.
ENEMIES = {
 "hutzin":    dict(name="Hutzin", types=["verdant","venom"], hp=60, hp_wave=18, speed=108, reward=30, leak=2, cost=3.0, rare=True, blurb="Rare wanderer. A hoatzin in a teapot hut that only shows up on foggy nights. Catch it and it is yours."),
 "shuckit":   dict(name="Shuckit", types=["umbra","gale"], hp=18, hp_wave=7, speed=120, reward=5, leak=1, cost=1.0, blurb="Fast fodder. A fallen packmate whips others into a sprint."),
 "zapnose":   dict(name="Zapnose", types=["volt","aether"], hp=10, hp_wave=3, speed=190, reward=4, leak=1, cost=1.2, blurb="Caffeinated and fragile."),
 "glomm":     dict(name="Glomm", types=["stone","frost"], hp=70, hp_wave=22, speed=62, reward=14, leak=3, cost=4.0, blurb="Slow stoic tank."),
 "hoardillo": dict(name="Hoardillo", types=["stone","forge"], hp=45, hp_wave=14, speed=85, reward=10, leak=2, cost=3.0, armor=4.0, blurb="Armored: each direct hit loses 4 damage."),
 "mirewick":  dict(name="Mirewick", types=["verdant","spirit"], hp=30, hp_wave=9, speed=105, reward=8, leak=1, cost=2.0, regen=6.0, blurb="Regenerates unless poisoned."),
 "gloamoth":  dict(name="Gloamoth", types=["umbra","aether"], hp=28, hp_wave=8, speed=95, reward=9, leak=1, cost=2.5, flying=True, blurb="Flies straight over the lane, ignoring the path."),
 "bogbard":   dict(name="Bogbard", types=["tide","venom"], hp=40, hp_wave=12, speed=80, reward=11, leak=2, cost=3.5, heal_aura=5.0, blurb="Its banjo heals nearby herdmates."),
 "quillwyrm": dict(name="Quillwyrm", types=["stone","verdant"], hp=50, hp_wave=16, speed=75, reward=10, leak=2, cost=3.5, split=2, blurb="Splits into two smaller wyrms when defeated."),
 "drumbeak":  dict(name="Drumbeak", types=["gale","spirit"], hp=55, hp_wave=16, speed=70, reward=12, leak=2, cost=3.5, speed_aura=True, blurb="Its drumbeat speeds up everything nearby."),
 "pyrelope":  dict(name="Pyrelope", types=["ember","spirit"], hp=35, hp_wave=10, speed=100, reward=12, leak=2, cost=3.5, rebirth=1, blurb="Reborn once from its own ashes."),
 "mudskip":   dict(name="Mudskip", types=["tide","volt"], hp=32, hp_wave=9, speed=95, reward=8, leak=1, cost=2.2, jump_every=5.0, blurb="Hops ahead along the lane every few seconds."),
 "thornarok": dict(name="Thornarok", types=["ember","stone"], hp=60, hp_wave=18, speed=80, reward=12, leak=2, cost=3.5, enrage=True, blurb="Gets faster and angrier as it takes damage."),
 "ptarmitten":dict(name="Ptarmitten", types=["frost","gale"], hp=30, hp_wave=9, speed=90, reward=9, leak=1, cost=2.5, chill_aura=True, blurb="Chills nearby defenders: they attack 25% slower."),
 "tentbat":   dict(name="Tentbat", types=["verdant","umbra"], hp=25, hp_wave=7, speed=100, reward=8, leak=1, cost=2.0, dodge=0.25, blurb="Hides under its leaf: dodges 25% of hits."),
 "dumbomaton":dict(name="Dumbomaton", types=["forge","aether"], hp=50, hp_wave=14, speed=75, reward=13, leak=2, cost=3.5, shield=80.0, blurb="Wears a brass shield that soaks damage first."),
 "colukite":  dict(name="Colukite", types=["gale","aether"], hp=22, hp_wave=6, speed=140, reward=9, leak=1, cost=2.5, flying=True, blurb="Fast glider that ignores the lane."),
 "gilamancer":dict(name="Gilamancer", types=["venom","spirit"], hp=45, hp_wave=14, speed=90, reward=13, leak=2, cost=3.5, dodge=0.3, regen=2.0, blurb="Mirror magic: dodges 30% of hits."),
}

# ---------------- TOWERS ----------------
def up_set(names, a_specs, b_specs, base):
    """names: 8 names. a_specs/b_specs: dict tier-> (desc, mods) for tiers 3 and 4 (A) / 2 and 4 (B)."""
    f = [0.9, 1.5, 2.8, 5.6]
    c = [int(base * x // 5 * 5) for x in f]
    A = [
        U(names[0], c[0], "+25% attack speed", mul={"rate": 1.25}),
        U(names[1], c[1], "+30% damage", mul={"dmg": 1.3}),
        U(names[2], c[2], a_specs[0][0], **a_specs[0][1]),
        U(names[3], c[3], a_specs[1][0], **a_specs[1][1]),
    ]
    B = [
        U(names[4], c[0], "+30 range", add={"range": 30}),
        U(names[5], c[1], b_specs[0][0], **b_specs[0][1]),
        U(names[6], c[2], "+20% speed, +15% damage", mul={"rate": 1.2, "dmg": 1.15}),
        U(names[7], c[3], b_specs[1][0], **b_specs[1][1]),
    ]
    return {"a": A, "b": B}

def up_full(base, names, rows):
    """rows: 8 tuples (desc, mods) for A1..A4,B1..B4."""
    f = [0.9, 1.5, 2.8, 5.6]
    c = [int(base * x // 5 * 5) for x in f]
    A = [U(names[i], c[i], rows[i][0], **rows[i][1]) for i in range(4)]
    B = [U(names[4 + i], c[i], rows[4 + i][0], **rows[4 + i][1]) for i in range(4)]
    return {"a": A, "b": B}

TOWERS = {}

# --- starters (hand-tuned in earlier passes) ---
TOWERS["tickindle"] = dict(sprite="tickindle", name="Tickindle", types=["ember","forge"], cost=100, range=190.0, dmg=7.0, rate=1.6,
    upgrades={"a":[U("Greased Gears",90,"+20% attack speed",mul={"rate":1.2}),U("Tick-Tock Volley",150,"Longer wind-up (+3 stacks)",add={"windup_max":3}),U("Overwound",280,"+25% speed, +2 damage",mul={"rate":1.25},add={"dmg":2}),U("Clockwork Pyre",560,"Fires 2 bolts per shot",set={"multishot":2},add={"dmg":1})],
              "b":[U("Hot Iron",80,"+30% damage",mul={"dmg":1.3}),U("Longbarrel",130,"+35 range",add={"range":35}),U("Molten Rounds",300,"Molten every 5th shot, leaves burn patch",set={"molten_every":5,"burn_patch":True}),U("Anvil Drop",600,"Molten shots splash, +30% damage",set={"splash":70},mul={"dmg":1.3})]})
TOWERS["dugloom"] = dict(sprite="dugloom", name="Dugloom", types=["tide","spirit"], cost=120, unlock="frostrun", range=165.0, dmg=2.0, rate=0.8, slow=0.55, slow_t=2.0, pulse=True, wet=True,
    upgrades={"a":[U("Brighter Lamp",80,"+30 range",add={"range":30}),U("Slow Tide",140,"Stronger slow",set={"slow":0.45}),U("Lighthouse Pulse",260,"+5 damage, +20% speed",add={"dmg":5},mul={"rate":1.2}),U("Beaconmaid",520,"Pulse stuns 0.6s, +range, faster",set={"stun":0.6},add={"range":25},mul={"rate":1.2})],
              "b":[U("Undertow",90,"Pulse drags foes back",set={"pull":18.0}),U("Deeper Pull",150,"Stronger drag",set={"pull":36.0}),U("Drowned Chorus",270,"+40% speed, +2 damage",mul={"rate":1.4},add={"dmg":2}),U("Maelstrom",540,"Huge drag, +8 damage",set={"pull":70.0},add={"dmg":8})]})
TOWERS["hutzin"] = dict(sprite="hutzin", name="Hutzin", types=["verdant","venom"], cost=130, unlock="gloamwood", range=175.0, dmg=2.0, rate=0.9, stacks=1, splash_always=True,
    upgrades={"a":[U("Stronger Brew",90,"Poison hurts 40% more",set={"poison_mul":1.4}),U("Double Dose",150,"2 poison stacks per shot",set={"stacks":2}),U("Rolling Boil",280,"+30% speed, max 8 stacks",mul={"rate":1.3},set={"max_stacks":8}),U("Brewmother",560,"Poison hurts more, spreads to ALL nearby on death",set={"spread_all":True,"poison_mul":1.9})],
              "b":[U("Spore Puff",100,"Shots splash poison",set={"splash":50}),U("Wider Cloud",150,"Bigger splash",set={"splash":85}),U("Hex Teapot",290,"Poisoned foes take +20% damage, +3 dmg",set={"vuln":True},add={"dmg":3}),U("Walking Cottage",580,"Every 6th shot a poison stomp, +25 range",set={"burst_every":6},add={"range":25})]})

# --- allies from earlier passes ---
TOWERS["ally_shuckit"] = dict(sprite="shuckit", name="Shuckit", types=["umbra","gale"], cost=90, range=150.0, dmg=3.0, rate=2.8, unlock="mossgate",
    upgrades={"a":[U("Sharp Fangs",70,"+40% attack speed",mul={"rate":1.4}),U("Hunting Pack",140,"Fires 2 bites per shot",set={"multishot":2}),U("Alpha Howl",240,"Every 4th bite is a 3x crit",set={"crit_every":4}),U("Black Shuck",480,"3 bites per shot, +3 damage",set={"multishot":3},add={"dmg":3})],
              "b":[U("Tailwind",70,"+25 range",add={"range":25}),U("Cutting Wind",130,"Bites slow foes",set={"hit_slow":0.7}),U("Gale Force",250,"Bites briefly stun",set={"hit_stun":0.25}),U("Storm Dog",500,"+50% speed, heavy slow",mul={"rate":1.5},set={"hit_slow":0.5})]})
TOWERS["ally_zapnose"] = dict(sprite="zapnose", name="Zapnose", types=["volt","aether"], cost=140, range=170.0, dmg=6.0, rate=1.1, chain_n=2, unlock="stormspire",
    upgrades={"a":[U("Static",100,"+3 damage",add={"dmg":3}),U("Arc Jump",160,"Lightning jumps to 1 more foe",add={"chain_n":1}),U("Overcharge",300,"+30% speed, +4 damage",mul={"rate":1.3},add={"dmg":4}),U("Thunder Doorbell",600,"3 more jumps, longer reach",add={"chain_n":3},set={"chain_range":160.0})],
              "b":[U("Longer Nose",90,"+30 range",add={"range":30}),U("Ringing",160,"Shocks briefly stun",set={"hit_stun":0.3}),U("Static Field",280,"Shocks slow foes",set={"hit_slow":0.6}),U("Tesla's Gambit",580,"Longer stun, +50% damage",set={"hit_stun":0.6},mul={"dmg":1.5})]})
TOWERS["ally_glomm"] = dict(sprite="glomm", name="Glomm", types=["stone","frost"], cost=180, range=150.0, dmg=14.0, rate=0.5, splash=60.0, splash_always=True, hit_slow=0.6, unlock="frostrun",
    upgrades={"a":[U("Heavy Snow",120,"+8 damage",add={"dmg":8}),U("Wide Tumble",180,"Bigger splash",set={"splash":90.0}),U("Rime Slam",320,"+12 damage, +20% speed",add={"dmg":12},mul={"rate":1.2}),U("Golem's Fist",620,"+60% damage, huge splash",mul={"dmg":1.6},set={"splash":125.0})],
              "b":[U("Frost Fringe",110,"Stronger slow",set={"hit_slow":0.5,"hit_slow_t":2.0}),U("Permafrost",170,"Heavy slow",set={"hit_slow":0.35}),U("Flash Freeze",300,"Hits briefly freeze",set={"hit_stun":0.5}),U("Snowglobe Blizzard",600,"Long freeze, +40 range",set={"hit_stun":1.0,"hit_slow":0.3},add={"range":40})]})

def ally(id, sprite, name, types, cost, rng, dmg, rate, unlock, extra, names, a_specs, b_specs):
    d = dict(sprite=sprite, name=name, types=types, cost=cost, range=float(rng), dmg=float(dmg), rate=float(rate), unlock=unlock)
    d.update(extra)
    d["upgrades"] = up_set(names, a_specs, b_specs, cost)
    TOWERS["ally_" + id] = d

ally("hoardillo","hoardillo","Hoardillo",["stone","forge"],110,140,5,1.8,"brasswick",{"bounty":1},
 ["Coin Clink","Greedy Gnaw","Gilded Claws","Dragon's Hoard","Longer Snout","Gold Dust","Sticky Fingers","Fafnir's Vault"],
 [("Hits pay +2 coins",{"set":{"bounty":2}}),("Hits pay +4 coins, +60% damage",{"set":{"bounty":4},"mul":{"dmg":1.6}})],
 [("Gold dust slows foes",{"set":{"hit_slow":0.8}}),("Hits pay +6 coins, heavy slow",{"set":{"bounty":6,"hit_slow":0.7}})])
ally("mirewick","mirewick","Mirewick",["verdant","spirit"],120,150,2,0.9,"gloamwood",{"aura_range":0.1,"aura_r":150.0},
 ["Brighter Wick","Long Light","Will-o' Warmth","Marsh Beacon","Slowing Glow","Haunting Hum","Lantern Fog","Great Wisp"],
 [("Aura +15% range, bolts slow",{"add":{"aura_range":0.15},"set":{"hit_slow":0.7}}),("Aura also +10% speed",{"add":{"aura_rate":0.1,"aura_range":0.1}})],
 [("Bolts briefly stun",{"set":{"hit_stun":0.3}}),("Aura +25% range, bolts x2 damage",{"add":{"aura_range":0.25},"mul":{"dmg":2.0}})])
ally("gloamoth","gloamoth","Gloamoth",["umbra","aether"],130,170,3,1.0,"gloamwood",{"cloud":True,"cloud_slow":0.8,"cloud_dps":3.0,"cloud_r":48.0,"cloud_t":4.0},
 ["Dusky Dust","Thicker Dark","Moth Swarm","Eclipse Cloud","Wide Wings","Sleep Powder","Lunar Glow","Mothman's Gloam"],
 [("Clouds tick harder",{"set":{"cloud_dps":7.0}}),("Huge clouds, heavy damage",{"set":{"cloud_dps":12.0,"cloud_r":70.0}})],
 [("Clouds slow much more",{"set":{"cloud_slow":0.55}}),("Clouds last 7s, slow hard",{"set":{"cloud_t":7.0,"cloud_slow":0.45}})])
TOWERS["ally_bogbard"] = dict(sprite="bogbard", name="Bogbard", types=["tide","venom"], cost=140, range=130.0, dmg=0.0, rate=1.0, aura_rate=0.15, aura_r=150.0, unlock="bogwash",
    upgrades=None)
TOWERS["ally_bogbard"]["upgrades"] = up_full(140, ["Tuning Up","Louder Chorus","Foot-Stomper","Kappa's Concert","Learns to Sling","Poison Notes","Encore","Swamp Symphony"], [
 ("Aura +5% attack speed",{"add":{"aura_rate":0.05}}),("Aura radius +40",{"add":{"aura_r":40.0}}),("Aura +10% attack speed",{"add":{"aura_rate":0.1}}),("Aura +15% speed, radius +60",{"add":{"aura_rate":0.15,"aura_r":60.0}}),
 ("Slings notes: 4 damage",{"add":{"dmg":4.0}}),("Notes slow foes",{"set":{"hit_slow":0.75}}),("Notes +100% damage",{"mul":{"dmg":2.0}}),("2 notes per strum, heavy slow",{"set":{"multishot":2,"hit_slow":0.6}})])
ally("quillwyrm","quillwyrm","Quillwyrm",["stone","verdant"],150,170,5,1.3,"bogwash",{"multitarget":3},
 ["Sharper Pins","Longer Quills","Pincushion Volley","Wyrm's Barrage","Steady Aim","Venomous Tips","Prickly Hide","Lambton Lance"],
 [("Volley hits 4 foes",{"set":{"multitarget":4}}),("Volley hits 6 foes, +30% damage",{"set":{"multitarget":6},"mul":{"dmg":1.3}})],
 [("Quills slow foes",{"set":{"hit_slow":0.75}}),("Quills stun, +40 range",{"set":{"hit_stun":0.3},"add":{"range":40}})])
ally("drumbeak","drumbeak","Drumbeak",["gale","spirit"],160,110,14,0.9,"stormspire",{"nova":True,"pull":25.0,"hit_stun":0.2},
 ["Tighter Skins","Louder Beat","Thoth's Rhythm","Thunder Kit","Wider Boom","Shock Pulse","Syncopation","Ibis Apocalypse"],
 [("Pulse +10 damage",{"add":{"dmg":10.0}}),("Pulse x1.6 damage, faster",{"mul":{"dmg":1.6,"rate":1.2}})],
 [("Pulse knocks back farther",{"set":{"pull":45.0}}),("Pulse stuns longer, +30 radius",{"set":{"hit_stun":0.5},"add":{"range":30}})])
ally("pyrelope","pyrelope","Pyrelope",["ember","spirit"],200,280,20,0.4,"thornpeak",{"splash":70.0,"splash_always":True,"burn_patch":True},
 ["Hotter Wicks","Longer Fuse","Phoenix Feathers","Rebirth Blast","Candle Tips","Cinder Rain","Wide Flames","Sun Bird"],
 [("+12 damage",{"add":{"dmg":12.0}}),("x1.5 damage, bigger splash",{"mul":{"dmg":1.5},"set":{"splash":100.0}})],
 [("Burn patches last longer",{"set":{"patch_t":6.0}}),("Fires 2 shells",{"set":{"multishot":2}})])
ally("mudskip","mudskip","Mudskip",["tide","volt"],130,150,4,1.2,"lanterntide",{"wet":True},
 ["Slick Mud","Boot Stomp","Static Mud","Loch Surge","Longer Lob","Soak","Eel Charge","Nessie's Storm"],
 [("Hits chain to 1 more foe",{"set":{"chain_n":1}}),("Chain 3 jumps, +4 damage",{"set":{"chain_n":3},"add":{"dmg":4.0}})],
 [("Wet lasts much longer",{"set":{"wet_t":7.0}}),("Wet foes take +80% Volt damage",{"set":{"wet_mult":1.8}})])
ally("thornarok","thornarok","Thornarok",["ember","stone"],170,95,16,0.8,"emberflats",{"nova":True,"stomp_burn":False},
 ["Hot Thorns","Wider Stomp","Lava Cracks","Surtr's Fury","Thicker Hide","Ember Spray","Match Spark","Ragnarok Stomp"],
 [("+10 damage",{"add":{"dmg":10.0}}),("x1.7 damage",{"mul":{"dmg":1.7}})],
 [("Stomp leaves burning ground",{"set":{"stomp_burn":True}}),("Radius +40, stomp stuns",{"add":{"range":40.0},"set":{"hit_stun":0.4}})])
ally("ptarmitten","ptarmitten","Ptarmitten",["frost","gale"],120,165,3,1.4,"frostrun2",{"chill":1},
 ["Warmer Mittens","Snowball Fort","Powder Flurry","Snow Maiden's Gift","Longer Throw","Brittle Frost","Deep Freeze","Whiteout"],
 [("2 chill stacks per hit",{"set":{"chill":2}}),("2 chill stacks, +5 damage, faster",{"set":{"chill":2},"add":{"dmg":5.0},"mul":{"rate":1.2}})],
 [("Snowballs slow foes",{"set":{"hit_slow":0.7}}),("Hits stun and splash",{"set":{"hit_stun":0.4,"splash":70.0}})])
TOWERS["ally_tentbat"] = dict(sprite="tentbat", name="Tentbat", types=["verdant","umbra"], cost=150, range=140.0, dmg=0.0, rate=1.0, income=35, unlock="gloamwood2", upgrades=None)
TOWERS["ally_tentbat"]["upgrades"] = up_full(150, ["Better Tea","Second Cup","Leaf Tent","Green Man's Gold","Leaf Bolts","Sticky Sap","Tea Rooms","Evergreen Estate"], [
 ("+15 coins per wave",{"add":{"income":15}}),("+25 coins per wave",{"add":{"income":25}}),("+45 coins per wave",{"add":{"income":45}}),("+90 coins per wave",{"add":{"income":90}}),
 ("Throws leaf bolts: 3 damage",{"add":{"dmg":3.0}}),("Bolts slow foes",{"set":{"hit_slow":0.8}}),("+20 coins, bolts +3 damage",{"add":{"income":20,"dmg":3.0}}),("+60 coins, 2 bolts per throw",{"add":{"income":60},"set":{"multishot":2}})])
ally("dumbomaton","dumbomaton","Dumbomaton",["forge","aether"],190,150,3,1.6,"brasswick",{"multitarget":4},
 ["Oiled Joints","Eight Arms","Brass Fittings","Antikythera Core","Longer Arms","Spanner Blows","Gear Storm","Perfect Clockwork"],
 [("Arms hit 6 foes",{"set":{"multitarget":6}}),("Arms hit 8 foes, +3 damage",{"set":{"multitarget":8},"add":{"dmg":3.0}})],
 [("Arms briefly stun",{"set":{"hit_stun":0.2}}),("+50 range, +40% damage",{"add":{"range":50.0},"mul":{"dmg":1.4}})])
ally("colukite","colukite","Colukite",["gale","aether"],210,420,45,0.35,"stormspire2",{"mode":"strong"},
 ["Clean Lens","Tailwind","Wax Wings","Icarus Dive","Longer Glide","Steady Glide","Updraft","Sun-Piercer"],
 [("+30 damage",{"add":{"dmg":30.0}}),("x2 damage",{"mul":{"dmg":2.0}})],
 [("Shots splash",{"set":{"splash":40.0,"splash_always":True}}),("+120 range, +20% speed",{"add":{"range":120.0},"mul":{"rate":1.2}})])
ally("gilamancer","gilamancer","Gilamancer",["venom","spirit"],230,160,4,1.0,"lastwell",{"curse":True},
 ["Polished Mirror","Longer Look","Sly Hex","Circe's Gaze","Wider Glass","Echo Curse","Venom Reflection","Mirror Queen"],
 [("Curse lasts longer, +4 damage",{"set":{"curse_t":8.0},"add":{"dmg":4.0}}),("Cursed foes take +40% damage",{"set":{"curse_mul":1.4}})],
 [("Curse echoes 40% damage to cursed foes",{"set":{"curse_echo":0.4}}),("Curse spreads to 2 nearby foes",{"set":{"curse_spread":2}})])

def gd(v, ind=0):
    pad = "\t" * ind
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return repr(float(v))
    if isinstance(v, str): return json.dumps(v)
    if v is None: return "null"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "[" + ", ".join(gd(x) for x in v) + "]"
        return "[\n" + "".join(pad + "\t" + gd(x, ind + 1) + ",\n" for x in v) + pad + "]"
    if isinstance(v, dict):
        inline = all(not isinstance(x, (dict, list)) or (isinstance(x, list) and all(not isinstance(y, (dict, list)) for y in x)) for x in v.values()) and len(json.dumps(v)) < 150
        if inline:
            return "{" + ", ".join(json.dumps(k) + ": " + gd(x) for k, x in v.items()) + "}"
        return "{\n" + "".join(pad + "\t" + json.dumps(k) + ": " + gd(x, ind + 1) + ",\n" for k, x in v.items()) + pad + "}"
    raise ValueError(v)

def main():
    out = ["extends RefCounted", "# GENERATED by tools/gen_creatures.py. Edit the tables there, not this file.", "# TOWERS: placeable defenders (3 starters + befriended allies). ENEMIES: wild herd species (17).", ""]
    towers = {}
    for k, d in TOWERS.items():
        d = dict(d); d["id"] = k
        towers[k] = d
    enemies = {}
    for k, d in ENEMIES.items():
        d = dict(d); d["id"] = k
        enemies[k] = d
    out.append("const TOWERS := " + gd(towers))
    out.append("")
    out.append("const ENEMIES := " + gd(enemies))
    out.append("")
    out.append("# DEFS merges both so older code can look up any id (towers keyed by tower id, enemies by species id).")
    out.append("static func def(id: String) -> Dictionary:")
    out.append("\tif TOWERS.has(id):")
    out.append("\t\treturn TOWERS[id]")
    out.append("\treturn ENEMIES.get(id, {})")
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "..", "creatures.gd"), "w") as f:
        f.write("\n".join(out) + "\n")
    print("towers", len(towers), "enemies", len(enemies))

main()
