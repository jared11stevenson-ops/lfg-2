extends RefCounted
# 10 levels. Each has its own lanes, rune stones (buff pads), ground zones, weather, species roster and boss.
# Layout rules: lanes may merge; flyers cross in a straight line; lane_mode picks which lane each spawn uses.
const ORDER := ["mossgate", "frostrun", "emberflats", "gloamwood", "bogwash", "stormspire", "brasswick", "lanterntide", "thornpeak", "lastwell"]
const TOTAL_WAVES := 10

const LEVELS := {
	"mossgate": {
		"name": "Mossgate Lane", "style": "meadow", "blurb": "A dusk meadow at the edge of the Green Hollow. A gentle first lesson.", "art": "res://art/maps/mossgate.png",
		"rule": "Rain rolls in on later waves.", "lane_mode": "random", "hp_mult": 0.8, "coins": 350,
		"colors": {"g1": "#274e63", "g2": "#3f8a6a", "accent": "#9fe8b8", "path": "#e2bd8a", "edge": "#4a2f55", "glow": "#ffe9a8", "moon": "#fff3c8"},
		"weather": ["clear", "clear", "rain", "clear", "rain", "clear", "rain", "clear", "rain", "rain"],
		"paths": [[[-40, 360], [300, 360], [300, 160], [700, 160], [700, 560], [1000, 560], [1000, 300], [1320, 300]]],
		"stones": [[460, 250, "verdant"], [560, 470, "tide"], [880, 420, "ember"], [150, 230, "umbra"]],
		"zones": [],
		"roster": [["shuckit", 1, 10], ["shuckit_pup", 2, 6], ["shuckit_alpha", 4, 3]],
		"boss": "", "boss_extra": {}, "early": [0.5, 0.6, 0.7, 0.74, 0.7, 0.72, 0.72, 0.7, 0.76, 0.86], "gift": "shuckit",
		"steal": true, "finale": 1.0, "tower_cap": 8, "flank": {"path": [[1000, 740], [1000, 560], [1000, 300], [1320, 300]], "wave": 6, "share": 0.28}, "champion": "shuckit_alpha",
		"goals": [["win", "Clear all 10 waves"], ["gold15", "Finish with 15+ gold"], ["perfect", "Lose no gold at all"], ["capture", "Capture a Shuckit"], ["rare", "Catch the rare Hutzin"]],
		"rare": {"id": "hutzin", "chance": 0.14, "wave_min": 3, "wave_max": 8},
		"story": {
			"intro": [
				["The Wells are failing. At the edge of the Green Hollow the old Mossgate still guards its Well, and in the Well sit twenty gold coins: the last of its power. Every herd in the Hollow can smell them.", "shuckit"],
				["You are a Wellkeeper. You cannot hold a lane alone. Tickindle, a grumpy manul who keeps time with a stolen pocket watch, has decided to stand with you. Do not ask it why.", "tickindle"],
				["Tonight a pack of Shuckit runs the lane. They do not want a fight. They want the gold. Each one that reaches the Well grabs a coin and bolts. Lose all twenty and the Well goes dark. Hold for ten waves and it shines.", "shuckit"],
				["Weaken a thief and a Lure can turn it into a friend. And old keepers whisper about a Hutzin, a bird in a teapot hut, that wanders in on foggy nights. Nobody knows when.", "hutzin"],
			],
			"win": "Ten waves, and the Well still shines with every coin you saved. Beyond the hedge the Shuckit pack lingers, watching. They are ready to follow a Wellkeeper who held the gate.",
			"lose": "The last coin is gone and the Well goes dark. Mossgate is patient. Old gates always get a second chance.",
		},

	},
	"frostrun": {
		"name": "Frostrun Pass", "style": "snow", "blurb": "Switchbacks under the White Lantern. Ice patches make the herd slide.",
		"rule": "Ice patches speed enemies up. Spirit towers love the cold.", "lane_mode": "random", "hp_mult": 1.08, "coins": 300,
		"colors": {"g1": "#2a3b78", "g2": "#6f93d0", "accent": "#d8f0ff", "path": "#aab8e0", "edge": "#27356a", "glow": "#5f9ad0", "moon": "#e8f4ff"},
		"weather": ["snow", "snow", "clear", "snow", "snow", "clear", "snow", "snow", "clear", "snow"],
		"paths": [[[-40, 140], [900, 140], [900, 300], [240, 300], [240, 470], [1000, 470], [1000, 330], [1320, 330]]],
		"stones": [[560, 220, "frost"], [560, 390, "spirit"], [1100, 250, "gale"], [130, 420, "ember"]],
		"zones": [{"pos": [450, 140], "r": 80, "kind": "ice"}, {"pos": [750, 140], "r": 80, "kind": "ice"}, {"pos": [600, 300], "r": 80, "kind": "ice"}],
		"roster": [["shuckit", 1, 7], ["shuckit_pup", 2, 4], ["glomm", 2, 6], ["icewake", 4, 2], ["shuckit_alpha", 5, 2]],
		"boss": "glomm", "boss_extra": {"shield": 180.0, "leak": 6}, "boss_mult": 4.0, "early": [0.6, 0.7, 0.78, 0.74, 0.78, 0.8, 0.8, 0.8, 0.76, 0.9], "art": "res://art/maps/frostrun.png", "tower_cap": 10,
		"goals": [["win", "Clear all 10 waves"], ["gold15", "Finish with 15+ lives"], ["perfect", "Lose no lives at all"], ["capture", "Capture a Glomm"]],
		"story": {
			"intro": [
				["Past Mossgate the road climbs into Frostrun Pass, where the White Lantern burns above the snow and has never once gone out. Tonight it is flickering.", "tickindle"],
				["The pass is four switchbacks of packed ice. The Shuckit pack followed you up and still wants the Well at the top. Worse, the ice patches on the road make every thief slide twice as fast.", "shuckit"],
				["Something heavy walks the snow behind them: Glomm, a crab as big as a cart, with a whole winter sealed in the glass globe on its back. It is slow, stubborn and very hard to move.", "glomm"],
				["Glomm will not be bullied, but it can be befriended. Wear one down, throw a Lure, and a frost crab will hold a lane for you all winter. Hold the Well for ten waves, and an Elder Glomm waits at the end.", "glomm"],
			],
			"win": "The Elder Glomm folds its claws and sits down in the snow. Above you the White Lantern steadies and burns bright again. The road to the Kindling Deep is open.",
			"lose": "The Well freezes over and the Lantern goes dark. Frostrun waits, patient as snow, and the pass will still be there tomorrow.",
			"boss": "Elder Glomm: it shrugs off the cold and most of your damage. Keep hitting it, and keep the thieves behind it from slipping past.",
		},
	},
	"emberflats": {
		"name": "Emberflats", "style": "desert", "blurb": "A zig-zag desert over the Kindling Deep. Lava vents scorch whatever walks over them.",
		"rule": "Vents burn enemies. Heatwaves empower Ember and Forge.", "lane_mode": "random", "hp_mult": 1.15, "coins": 250,
		"colors": {"g1": "#5e2f55", "g2": "#c4694a", "accent": "#ffc07a", "path": "#e8a870", "edge": "#552a3a", "glow": "#ffb060", "moon": "#ffd8a0"},
		"weather": ["heat", "clear", "heat", "heat", "clear", "heat", "heat", "clear", "heat", "heat"],
		"paths": [[[-40, 540], [220, 540], [220, 200], [520, 200], [520, 460], [820, 460], [820, 160], [1100, 160], [1100, 420], [1320, 420]]],
		"stones": [[370, 370, "ember"], [670, 300, "stone"], [960, 300, "forge"], [100, 350, "spirit"]],
		"zones": [{"pos": [220, 370], "r": 60, "kind": "burn"}, {"pos": [520, 330], "r": 60, "kind": "burn"}, {"pos": [820, 310], "r": 60, "kind": "burn"}],
		"roster": [["shuckit", 1, 6], ["hoardillo", 2, 5], ["thornarok", 3, 5], ["mirewick", 4, 3], ["zapnose", 5, 3], ["pyrelope", 8, 3]],
		"boss": "thornarok", "boss_extra": {},
	},
	"gloamwood": {
		"name": "Gloamwood", "style": "forest", "blurb": "A midnight forest where two trails merge. Moths drift over the trees, ignoring the path.",
		"rule": "Two lanes merge. Gloamoths fly straight over the forest.", "lane_mode": "split", "hp_mult": 1.2, "coins": 260,
		"colors": {"g1": "#14283a", "g2": "#2b5a5a", "accent": "#7fffd0", "path": "#7a6aa8", "edge": "#1a1030", "glow": "#a07aff", "moon": "#c8e8ff"},
		"weather": ["clear", "rain", "clear", "rain", "clear", "rain", "clear", "rain", "rain", "clear"],
		"paths": [[[-40, 190], [360, 190], [360, 400], [640, 400], [640, 250], [960, 250], [960, 480], [1320, 480]],
				[[-40, 540], [500, 540], [500, 400], [640, 400], [640, 250], [960, 250], [960, 480], [1320, 480]]],
		"stones": [[180, 330, "umbra"], [520, 300, "verdant"], [800, 380, "spirit"], [1130, 360, "aether"]],
		"zones": [],
		"roster": [["shuckit", 1, 6], ["mirewick", 2, 5], ["gloamoth", 2, 5], ["tentbat", 4, 4], ["quillwyrm", 6, 4], ["zapnose", 5, 2]],
		"boss": "gloamoth", "boss_extra": {"rebirth": 1},
	},
	"bogwash": {
		"name": "Bogwash Marsh", "style": "marsh", "blurb": "A slow marsh at the Sour Spring. Bogs drag at everyone's feet, including yours.",
		"rule": "Bog patches slow enemies. Bogbards heal their herd.", "lane_mode": "random", "hp_mult": 1.2, "coins": 260,
		"colors": {"g1": "#243a2e", "g2": "#4f6a3c", "accent": "#d0ff70", "path": "#a89868", "edge": "#2a2a1a", "glow": "#c8ff6a", "moon": "#f0ffc0"},
		"weather": ["rain", "clear", "rain", "rain", "clear", "rain", "rain", "clear", "rain", "rain"],
		"paths": [[[-40, 330], [240, 330], [240, 170], [520, 170], [520, 470], [800, 470], [800, 200], [1080, 200], [1080, 540], [1320, 540]]],
		"stones": [[380, 320, "tide"], [660, 320, "venom"], [940, 350, "verdant"], [120, 180, "stone"]],
		"zones": [{"pos": [380, 170], "r": 75, "kind": "bog"}, {"pos": [660, 470], "r": 75, "kind": "bog"}, {"pos": [940, 200], "r": 75, "kind": "bog"}, {"pos": [240, 250], "r": 60, "kind": "bog"}],
		"roster": [["shuckit", 1, 5], ["mudskip", 2, 5], ["bogbard", 3, 5], ["quillwyrm", 4, 4], ["hoardillo", 6, 3], ["mirewick", 7, 3]],
		"boss": "bogbard", "boss_extra": {"heal_aura": 20.0},
	},
	"stormspire": {
		"name": "Stormspire Heights", "style": "mesa", "blurb": "Wind-scoured mesas where two lanes cross. Colugos glide over everything.",
		"rule": "The lanes cross. Fast fliers cut straight across.", "lane_mode": "random", "hp_mult": 1.25, "coins": 270,
		"colors": {"g1": "#2a2a52", "g2": "#6a6aa0", "accent": "#ffe36a", "path": "#b8a8d8", "edge": "#241f4a", "glow": "#ffe36a", "moon": "#fff0b0"},
		"weather": ["clear", "rain", "rain", "clear", "rain", "rain", "clear", "rain", "rain", "rain"],
		"paths": [[[-40, 150], [500, 150], [500, 520], [900, 520], [900, 300], [1320, 300]],
				[[-40, 520], [250, 520], [250, 330], [700, 330], [700, 150], [1320, 150]]],
		"stones": [[380, 230, "gale"], [620, 430, "volt"], [800, 410, "aether"], [1100, 225, "spirit"], [150, 420, "umbra"]],
		"zones": [],
		"roster": [["zapnose", 1, 6], ["shuckit", 1, 4], ["colukite", 2, 5], ["drumbeak", 3, 5], ["ptarmitten", 5, 3], ["gloamoth", 6, 3]],
		"boss": "drumbeak", "boss_extra": {"speed_aura": true},
	},
	"brasswick": {
		"name": "Brasswick Works", "style": "factory", "blurb": "A clockwork foundry of conveyor belts. Belts rush the herd forward; sticky vats slow it.",
		"rule": "Conveyors speed enemies up. Glue vats slow them.", "lane_mode": "random", "hp_mult": 1.35, "coins": 280,
		"colors": {"g1": "#3a2a22", "g2": "#80603a", "accent": "#ffc860", "path": "#5a5a6a", "edge": "#1c1a24", "glow": "#ffc860", "moon": "#ffe0a0"},
		"weather": ["clear", "heat", "clear", "heat", "clear", "heat", "clear", "heat", "clear", "heat"],
		"paths": [[[-40, 150], [1000, 150], [1000, 330], [280, 330], [280, 510], [1320, 510]]],
		"stones": [[640, 240, "forge"], [640, 430, "aether"], [1130, 420, "volt"], [140, 400, "stone"]],
		"zones": [{"pos": [300, 150], "r": 70, "kind": "belt"}, {"pos": [560, 150], "r": 70, "kind": "belt"}, {"pos": [700, 330], "r": 70, "kind": "bog"}],
		"roster": [["hoardillo", 1, 6], ["zapnose", 1, 4], ["dumbomaton", 2, 5], ["glomm", 3, 4], ["drumbeak", 5, 3], ["mirewick", 6, 3]],
		"boss": "dumbomaton", "boss_extra": {"shield": 600.0},
	},
	"lanterntide": {
		"name": "Lantern Tide", "style": "coast", "blurb": "A spirit coast under a thousand lanterns. The herd alternates between two shores.",
		"rule": "Waves alternate between two lanes.", "lane_mode": "alternate", "hp_mult": 1.46, "coins": 280,
		"colors": {"g1": "#123a5a", "g2": "#2f7a8a", "accent": "#9fffe0", "path": "#e8c8a0", "edge": "#183050", "glow": "#ffd0a0", "moon": "#e0fff0"},
		"weather": ["clear", "rain", "clear", "rain", "clear", "rain", "clear", "rain", "clear", "rain"],
		"paths": [[[-40, 250], [300, 250], [300, 150], [900, 150], [900, 300], [1320, 300]],
				[[-40, 500], [400, 500], [400, 380], [1000, 380], [1000, 520], [1320, 520]]],
		"stones": [[600, 270, "spirit"], [150, 380, "tide"], [1150, 420, "spirit"], [700, 500, "aether"]],
		"zones": [],
		"roster": [["mudskip", 1, 5], ["gloamoth", 2, 4], ["pyrelope", 3, 5], ["mirewick", 3, 4], ["tentbat", 5, 3], ["colukite", 6, 3], ["bogbard", 7, 3]],
		"boss": "pyrelope", "boss_extra": {"rebirth": 2},
	},
	"thornpeak": {
		"name": "Thornpeak Ridge", "style": "volcano", "blurb": "A volcanic ridge of tight switchbacks. Vents burn, belts of hot air shove the herd forward.",
		"rule": "Vents burn enemies. Hot updrafts speed them up.", "lane_mode": "random", "hp_mult": 1.5, "coins": 290,
		"colors": {"g1": "#3a1c2a", "g2": "#8a3a2a", "accent": "#ff7a3a", "path": "#d0906a", "edge": "#2a1020", "glow": "#ff7a3a", "moon": "#ffc890"},
		"weather": ["heat", "heat", "clear", "heat", "heat", "clear", "heat", "heat", "heat", "heat"],
		"paths": [[[-40, 520], [200, 520], [200, 200], [480, 200], [480, 480], [760, 480], [760, 160], [1040, 160], [1040, 440], [1320, 440]]],
		"stones": [[340, 350, "ember"], [620, 320, "stone"], [900, 300, "forge"], [100, 330, "spirit"], [1150, 300, "gale"]],
		"zones": [{"pos": [200, 360], "r": 60, "kind": "burn"}, {"pos": [480, 340], "r": 60, "kind": "burn"}, {"pos": [760, 320], "r": 60, "kind": "burn"}, {"pos": [900, 160], "r": 70, "kind": "belt"}],
		"roster": [["thornarok", 1, 6], ["hoardillo", 1, 4], ["pyrelope", 2, 5], ["quillwyrm", 3, 4], ["gilamancer", 4, 4], ["glomm", 5, 3], ["colukite", 6, 3]],
		"boss": "thornarok", "boss_extra": {"rebirth": 1, "shield": 400.0},
	},
	"lastwell": {
		"name": "The Last Well", "style": "well", "blurb": "Three lanes converge on the last Well. Everything the Wells ever fed comes for it.",
		"rule": "Three lanes merge into one. The whole herd is here.", "lane_mode": "random", "hp_mult": 1.55, "coins": 300,
		"colors": {"g1": "#241a4a", "g2": "#5a2f7a", "accent": "#ff9ad8", "path": "#c8a8f0", "edge": "#1a1030", "glow": "#9fffe0", "moon": "#ffe0ff"},
		"weather": ["clear", "rain", "snow", "heat", "rain", "snow", "heat", "rain", "snow", "heat"],
		"paths": [[[-40, 150], [420, 150], [420, 330], [720, 330], [720, 460], [1320, 460]],
				[[-40, 330], [720, 330], [720, 460], [1320, 460]],
				[[-40, 520], [420, 520], [420, 330], [720, 330], [720, 460], [1320, 460]]],
		"stones": [[200, 240, "aether"], [200, 430, "spirit"], [570, 240, "umbra"], [570, 430, "venom"], [900, 330, "ember"], [1100, 300, "verdant"]],
		"zones": [],
		"roster": [["shuckit", 1, 4], ["zapnose", 1, 3], ["glomm", 2, 3], ["mirewick", 2, 3], ["gloamoth", 2, 3], ["bogbard", 3, 3], ["drumbeak", 3, 3], ["gilamancer", 3, 4], ["pyrelope", 4, 3], ["dumbomaton", 4, 3], ["colukite", 5, 3], ["thornarok", 5, 3], ["quillwyrm", 5, 3], ["tentbat", 6, 2], ["ptarmitten", 6, 2], ["mudskip", 6, 2], ["hoardillo", 6, 2]],
		"boss": "gilamancer", "boss_extra": {"rebirth": 1, "dodge": 0.25, "heal_aura": 15.0},
	},
}

static func all_points(level: Dictionary) -> Array:
	var pts := []
	for p in level.paths:
		for q in p:
			pts.append(Vector2(q[0], q[1]))
	return pts

static func to_paths(level: Dictionary) -> Array:
	var out := []
	for p in level.paths:
		var pv := PackedVector2Array()
		for q in p:
			pv.append(Vector2(q[0], q[1]))
		# lanes start at a spawn gate and end at the Well, both inside the screen
		if pv[0].x < 0.0:
			pv[0].x = 54.0
		if pv[pv.size() - 1].x > 1280.0:
			pv[pv.size() - 1].x = 1190.0
		out.append(pv)
	return out
