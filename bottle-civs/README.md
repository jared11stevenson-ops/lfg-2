# Bottled Civilizations

Twelve jars on a shelf, each holding a civilization with its own race and specialty. Tubes link neighbouring jars.
**By day** the tubes are open: caravans trade, raiding parties go to war, envoys carry marriage proposals and imps steal gold.
**At dusk every jar locks.** Anyone still outside is stuck in the neighbour's jar until dawn - hostages, guests and, often, parents of hybrid children.

## Run
Open `index.html` in a browser (no build step). Optional query params: `?seed=7&speed=8`.
Keys: `space` pause, `1`-`5` speed (1x/2x/4x/8x/20x). Click a jar to inspect it.

Headless soak test: `node tools/headless.js 200 <seed>` (about 2000x realtime, checks for NaNs).

## Civilizations (10 live, 2 sealed)
Elves (Herbalism), Dwarves (Deep Mining), Humans (Trade & Diplomacy), Lizardfolk (Swamp Farming), Orcs (Warcraft),
Goblins (Tinkering), Skeletons (Undying - raise the fallen), Ogres (Brewing & Brawn), Imps (Trickery - spies), Wizards (Arcane Lore).
Jars XI (Chorts) and XII (Angels) are sealed placeholders; their sprites are already in `assets/`.

## Layout
- `js/data.js` race definitions, `js/sim.js` DOM-free simulation, `js/render.js` canvas renderer, `js/main.js` UI loop.
- Art: 0x72 "Dungeon Tileset II" (CC0) from itch.io, see `assets/CREDITS.md`.

## Not yet (by design)
The turn-based tactical war mode, player control of a civilization and win conditions. The sim currently runs on AI only.
