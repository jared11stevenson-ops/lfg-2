# Contracts between streams (frozen; change only via lead)

## Ownership
| Stream | Owns (only edit these) |
|---|---|
| Lead (integrator) | project.godot, main/**, docs/DESIGN.md, docs/INTERFACES.md, CHANGELOG.md |
| A Gameplay/rules | rules/**, data/**, tests/rules/** |
| B World/presentation | world/**, ui/**, art/**, tools/art_*, tests/world/** |
| C Integration/QA/net | persistence/**, net/**, tests/run_all.gd, tests/net/**, tests/persist/**, tools/ci_*, docs/TEST_REPORT.md |

## Rules API (A implements, B and C consume)
```
# rules/api.gd  class_name Rules
static func new_match(seed:int, class_id:StringName, opts:Dictionary={}) -> MatchState
static func apply(state:MatchState, cmd:Dictionary) -> Dictionary  # {ok:bool, error:String, events:Array[Dictionary]}
static func tick(state:MatchState, dt:float) -> Array[Dictionary]  # advance sim clock, returns events
```
- `MatchState` (RefCounted): `to_dict()->Dictionary`, `static from_dict(d)->MatchState`, `schema_version:int`, `seed:int`, `clock` (day, time_of_day), `phase` (&"PEACE" etc), `actors`, `holdings`, `world` (hex grid ref data), `rng_state`.
- Command: `{type:StringName, actor:int, seq:int, args:Dictionary}`. Types: move_intent, plant, water, harvest, craft, build, demolish, trade, eat, attack, use_ability, capture, steal, set_policy, rest.
- Events: `{type:StringName, ...}`; e.g. phase_changed, crop_grown, actor_damaged, actor_died, holding_captured, match_over{reason}.
- All commands validated before mutation; failed commands mutate nothing. Quantities are ints > 0, bounded.
- Hex coords: axial `Vector2i(q,r)`, 84 columns x 54 rows, odd-r offset storage. Util in `rules/hexgrid.gd` (A owns, B uses).
- Content IDs namespaced: `lfg:crop/glowfruit`, `lfg:class/judd`. Data in `data/*.json` loaded by `rules/content.gd`.

## Presentation (B) reads state via signals from `main/game.gd` autoload `Game` (lead provides): `Game.state`, `Game.submit(cmd)`, signals `events_emitted(events)`, `state_replaced()`.
## Persistence (C): `Persist.save_match(slot,state)`, `load_match(slot)`, `Persist.migrate(dict)`; meta in `user://meta.json`.
## Net (C): headless authority `net/server.gd` runs `Rules.apply/tick`; clients submit commands with session tokens; same Rules module.

## Testing
Each stream writes tests as `tests/<area>/test_*.gd` extending `TestCase` (lead provides `tests/test_case.gd`). Run: `/tmp/claude-0/godot --headless --path . -s tests/run_all.gd`.
Report only what you ran. Never claim Android/real-player/recording results.
