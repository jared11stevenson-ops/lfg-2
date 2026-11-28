# Raceborn: Ages (Godot 4.7)

A Civilization VII-style 4X with fantasy races. Lead a people through Antiquity, Exploration and Modern; at every Age change you choose a NEW race (Elves, Dwarves, Humans, Lizardfolk, Orcs, Goblins, Skeletons, Ogres, Imps, Wizards), keeping your cities and Legacy.

## Run
Open this folder in Godot 4.7, play `scenes/main.tscn`. (Assets are shared with `../bottle-civs-3d` through the `assets` symlink.)

## Play
- Pick a race and a leader (Conqueror, Sage, Magnate, Visionary), then found your capital with the Settler (B).
- Left-click selects units and cities; right-click moves or attacks. F fortify, Space = next unit / end turn.
- Cities build units and buildings; Towns (non-capital) cannot build but grow and make gold - buy things, or upgrade to a City (pop 3, 80 gold).
- Research (T) and Civics (C), Legacy paths (L), Diplomacy (D). War must last 4+ turns before peace can be accepted.
- Each Age ends when its progress bar fills: a crisis hits, then you pick your next race (AI civs swap too). Win by Domination or by highest score after the Modern Age.
- WASD pan, Q/E rotate, wheel zoom, M mute.

## Dev
Headless AI game: `godot --headless --script tools/test_game.gd -- <seed> <turns>`
Screenshot: `godot res://scenes/main.tscn -- --race=2 --seed=3 --autoplay=12 --select=city --shot=/tmp/a.png --lowfx`

## Not done (honest list)
No naval units or commanders/army packing, no independent powers, no save/load, no multiplayer. Leaders are simple bonuses, not full attribute trees. Balance is untuned and only AI-vs-AI games and screenshots were tested - no full human playthrough on a real GPU.
