# Wellfall TD (pass 1 skeleton)
Separate Godot project (open `td/` in Godot 4.x). Root project is the older farm game.
- Place Tickindle on grass (100 coins), start waves, survive 5 waves of Shuckits.
- Creature designs: `docs/creatures_v1.md`. Type chart so far: starter triangle only (`type_chart.gd`).
- Tests (headless): `godot --headless --path td -s tests/test_type_chart.gd`
  and `godot --headless --path td --fixed-fps 60 -s tests/sim_waves.gd` (balance smoke test).
- Art is code-drawn placeholder. Verified on Godot 4.4.1 headless only; not yet run on 4.7 or a phone.
