# Wellfall TD (pass 3)
Separate Godot project, targets Godot 4.7 (verified headless on 4.7-stable). Root project is the older farm game.
- Pick Tickindle / Dugloom / Hutzin from the bottom cards, tap grass to place, start waves, survive 8 waves (Shuckit, Zapnose, Glomm). 12-type chart with Super!/Resisted popups.
- Dugloom: lantern pulse slows everything in range. Hutzin: stacking poison that hops to the nearest foe when its host dies.
- Creature designs: `docs/creatures_v1.md`. Type chart so far: starter triangle only (`type_chart.gd`).
- Tests (headless): `godot --headless --path td -s tests/test_type_chart.gd`
  and `godot --headless --path td --fixed-fps 60 -s tests/sim_waves.gd` (balance smoke test; pass towers as `-- tickindle:500,260 dugloom:430,260`).
- Art is code-drawn placeholder. Balance sims (pass 3, free towers): 7 mixed towers lose at wave 8; 10 mixed towers win with 20 lives. Screenshots: `tests/shot.gd` under xvfb-run. Not yet run on a phone or by a human.
