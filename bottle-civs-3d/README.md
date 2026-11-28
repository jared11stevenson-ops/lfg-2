# Bottled Civilizations 3D (Godot 4.7)

The Wall: twelve glass terrariums on a stepped steel rack, linked by tubes. Ten civilizations are awake, two jars are sealed.
By day lids retract and caravans, raiders, envoys and spies cross the tubes; at dusk every lid seals and bolts lock, trapping travellers in the neighbour's jar until dawn (where hybrids are born).

## Run
Open this folder in Godot 4.7 and press play (`scenes/main.tscn`). Controls: click a jar, wheel zoom, right-drag orbit, WASD pan, Esc overview, space pause, 1-5 speed.

Headless soak test: `godot --headless --script tools/soak.gd -- 100 3`
Screenshot test: `godot res://scenes/main.tscn -- --seed=3 --days=3 --at=0.3 --focus=2 --shot=/tmp/a.png --lowfx`

## Layout
`scripts/sim.gd` simulation (no scene access), `jar.gd` terrarium + citizens, `actor.gd` animated character with shared-rig retargeting, `main.gd` room/wall/tubes/loop, `hud.gd`, `cam.gd`.

## Assets
All third-party CC0, none made in-house - see `assets/CREDITS.md`.

## Known gaps
Stylised low-poly, not photoreal. Only a subset of citizens is shown per jar (max 16). Per-civ visual identity is mostly tint/props on shared KayKit models; the free Quaternius Elf/Orc/Imp/Puglin models are bare base meshes and are used only for orcs, goblins and imps. No player control or tactical war mode yet.
