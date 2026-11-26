# Wellfall TD
Godot 4.7 tower defense. Open the `td/` folder in Godot 4.7 and press F5, or run the exported build.

## What's in
- 6 creatures you place (3 starters + 3 befriended allies), each with 2 upgrade paths x 4 tiers (only one path past tier 2). Tier 3+ switches to an evolved 3D model.
- 12-type chart (every type beats 2, is beaten by 2), weather that shifts matchups, 3 maps, 8 waves + boss, Endless mode.
- 7 enemy kinds including an armored one (Hoardillo) and a regenerating one (Mirewick).
- Well Surge active ability, targeting modes, sell, 1x/2x/3x speed, procedural SFX and music, saved progress.
- Art: creatures are built from primitives in 3D, toon-shaded with outlines, and pre-rendered to 8-direction sprites (`tools/render_sprites.gd`). Code-drawn fallbacks exist for the starters and enemies.

## Docs
`docs/creatures_v1.md`, `docs/lore_v1.md` (world, types, roster), `docs/ROADMAP_NIGHT1.md`.

## Tests (headless)
`GODOT=/path/to/godot tests/run_all.sh` runs the type-chart test, upgrade-rule test and a full-wave balance sim.
Single sim: `godot --headless --path . --fixed-fps 60 -s tests/sim_waves.gd -- map=frostrun tickindle:500,260:aab ally_zapnose:430,260:bb`
Screenshots: `xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tests/shot.gd -- out.png 600 wave=4 select=1 tickindle:430,260:aab`
Re-render sprites: `xvfb-run godot --path . --rendering-driver opengl3 -s tools/render_sprites.gd -- [ids]`

## Honest status
Verified: headless tests and sims, in-engine screenshots under software rendering, exported pack boots. Not verified: human playtest, real phone, touch feel, audio on hardware (no audio device here), balance against real players.
