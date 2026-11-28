# Bottled Civilizations 3D (Godot 4.7)

The Wall: twelve glass terrariums on a stepped steel rack, linked by tubes. Ten civilizations are awake, two jars are sealed.
By day lids retract and caravans, raiders, envoys and spies cross the tubes; at dusk every lid seals and bolts lock, trapping travellers in the neighbour's jar until dawn (where hybrids are born).

## Run
Open this folder in Godot 4.7 and press play (`scenes/main.tscn`). Controls: click a jar, wheel zoom, right-drag orbit, WASD pan, Esc overview, space pause, 1-5 speed.

Headless soak test: `godot --headless --script tools/soak.gd -- 100 3`
Screenshot test: `godot res://scenes/main.tscn -- --seed=3 --days=3 --at=0.3 --focus=2 --shot=/tmp/a.png --lowfx`

## How to play
Pick a civilization on the title screen (or Spectate). You get 3 actions per day (they refresh at dawn):
- **Your jar** (click it): set a policy (free), build houses, barracks (+army), walls (+defence) or the Great Work.
- **A connected jar**: trade, send envoys, gift, ally, declare war / sue for peace, raid, annex (at war, target 14 pop or fewer), spy (Imps).
- **Raids involving you** are fought as turn-based hex battles (click a unit, green = move, red = attack, flanking +25%, Defend halves damage, 10 rounds), or auto-resolved.
- **Win**: complete the Great Work (tech 5, 220 gold, 140 goods, 140 lore, then 8 days with 8+ citizens), ally with every living civ (Concord), or annex them all (Domination). AI civs also race for the Great Work. **Lose**: your civ dies out or a rival finishes first.

Also in the game:
- **Race specials** (1 action, 3-day recharge, button on your jar): Verdant Bloom, Mother Lode, Grand Market, Mass Hatching, War Cry, Salvage Run, Raise Legion, Ale Feast, Sow Discord, Arcane Surge.
- **Night guests**: choose to Host trapped visitors (friendly, hybrid children possible) or Ransom them (10 gold each, costs relations).
- **The Wall-keeper**: random dawn events (crumbs, shaken jar, sunbeam, cold snap, glittering debris).
- **Difficulty**: Easy (4 actions, gentler AI) / Normal / Hard (aggressive AI, faster rival wonders).
- **Audio** (CC0): day/night music cross-fade, lid/lock/battle/trade sounds. M mutes.

Bot playthrough: `godot --headless --script tools/playtest.gd -- <civ> <seed> <days> [agg]`

## Layout
`scripts/sim.gd` simulation (no scene access), `jar.gd` terrarium + citizens, `actor.gd` animated character with shared-rig retargeting, `main.gd` room/wall/tubes/loop, `hud.gd`, `cam.gd`, `battle.gd` + `battle_view.gd` (tactics), `menu.gd` (title, battle prompt, game over).

## Assets
All third-party CC0, none made in-house - see `assets/CREDITS.md`.

## Known gaps
Stylised low-poly, not photoreal. Only a subset of citizens is shown per jar (max 16). Per-civ visual identity is mostly tint/props on shared KayKit models; the free Quaternius Elf/Orc/Imp/Puglin models are bare base meshes and are used only for orcs, goblins and imps. No save/load yet. Only checked via software-rendered screenshots and headless bot runs, never on a real GPU.
