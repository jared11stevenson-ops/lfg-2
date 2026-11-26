# Wellfall TD
Godot 4.7 tower defense: **10 levels, 20 creatures**, hand-drawn 2D cartoon art. Open the `td/` folder in Godot 4.7 and press F5, or run the exported build.

## What's in
- **20 original creatures** (`docs/lore_v2.md`), all animated 2D puppets with their own personality. 3 starters you raise from day one; the other 17 are wild herd species that you befriend as allies by clearing levels.
- **10 levels**, each with its own lanes (1-3, merging, crossing or alternating), rune stones, hazard zones, weather, roster and boss.
- **Replayability:** procedural seeded waves, 4 difficulty tiers, 10 mutators, 3-star scoring that unlocks bonus allies, Daily Challenge, Endless mode.
- **Depth:** 20 defenders x 2 upgrade paths x 4 tiers (evolved forms at tier 3+), targeting modes, 12-type chart, weather, support auras, economy defenders, status combos, enemy traits (flying, armor, regen, shield, rebirth, enrage, dodge, healing and speed auras, splitting, chill aura), the Well Surge ability.
- Procedural sound effects and music, saved progress. Tip: the menu has an "Unlock all (test)" toggle for playtesting.

## Tools
- `tools/gen_creatures.py` generates `creatures.gd` (all stats and upgrade trees live in that script's tables).
- `art/puppets*.gd` + `art/puppet.gd` define the creature designs; `tools/bake_puppets.gd` bakes them to sprite frames (`art/puppets/`).
  Bake: `xvfb-run godot --path td --rendering-driver opengl3 -s tools/bake_puppets.gd -- all`
- `tools/level_sheet.gd` renders a contact sheet of every level backdrop.

## Tests (headless)
`GODOT=/path/to/godot tests/run_all.sh` runs the type-chart, upgrade-rule and level-data tests plus a wave sim.
Auto balance sim: `godot --headless --path td --fixed-fps 60 -s tests/sim_auto.gd -- level=lastwell diff=hard n=10 tiers=2 seed=5`
Screenshots: `xvfb-run godot --path td --rendering-driver opengl3 --fixed-fps 60 -s tests/shot.gd -- out.png 600 level=gloamwood wave=4 tickindle:430,330:aab`

## Honest status
Verified: headless tests and balance sims, in-engine screenshots (software rendering), exported pack boots. Not verified: human playtest, real phone, touch feel, audio on hardware, balance against real players.
