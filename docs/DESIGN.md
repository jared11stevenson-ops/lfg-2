# LFG! — Last Farm Standing (design decisions, v0)
Own take on the LFG! pitch. Not the competitor's game: match-based, hex-strategic world, diorama art.

## Format
- **Match-based.** A match = one world seed. Your leader dying in any way ends the match (permadeath, absolute). New match = new seed, fresh start.
- **Meta-progression (cosmetic/option only, never power):** Codex entries, class "alt starts" (different starting kit, same power budget), titles. Stored in `user://meta.json`, separate from match saves.
- **Win:** Dominion (hold >=60% of all holdings) or Survive 12 in-world weeks (Crowned). After winning you may continue in Endless; there is no global ending.
- **Loss:** leader death, or all holdings lost AND no way to farm (Starved Out).

## World
- Hex grid **84x54** (Civ 7 Standard). Deterministic seed gen. Biomes: Homestead Meadow, Living Shore, Fungal Grove, Ruins, Salt Flats, Highlands, Bog. ~40 AI-or-player holdings (villages), 3 capturable "frontier tiers".
- Each hex = 16 world metres. Player walks the real 3D terrain; fog of war on hexes. Roads cut travel. Chunked rendering (8x8 hex chunks) so it runs on phones.
- Strategic map view (hex overlay) toggles from the 3D view.

## Loop
- Calendar: 1 day = 6 real minutes (configurable). 7th day = Purge cycle.
- PEACE (days 1-5): farm, craft, build, trade with NPC merchants, explore, **ration**, fortify.
- WARNING (day 6): announcement, preparation. PURGE_ACTIVE (day 7 night): **lawless** — everyone (AI, other players) may kill, steal, raid, capture. No safe zones. RESOLUTION: settle once, back to PEACE.
- Rations: every person (leader + followers/garrison) eats 1 ration/day; starving = debuffs then desertion. Rations come from cooked crops (Cook class bonus). Rationing drives expedition range and army size.
- Stealing in Purge: carried items drop on death of carrier; storehouses can be looted by capturing the holding; thieves can steal from garrisoned stores with a risk roll.

## Classes (14). Each: peace perk, purge kit, weakness.
Judd Farmer/Monk, Mira Alchemist/Plaguebinder, Bram Forager/Berserker, Tavi Miner/Sentinel, Pip Courier/Skirmisher, Oren Cook/Medic,
Vex Thief/Cutpurse, Sable Hunter/Trapper, Quill Scribe/Envoy, Forge Smith/Siegewright, Nyx Fungal Shaman, Rook Banner/Warlord, Dune Tinker/Smuggler, Halo Pilgrim/Warden.

## Art
Low-poly **tilt-shift diorama**: flat-shaded chunky geometry, saturated psychedelic palette (magenta/teal/acid-yellow fungi on warm cozy ground), soft fog, toy-scale buildings, strong silhouettes, outline-free. Original assets only (procedural meshes first; GLB later with provenance in docs/ASSETS.md).

## Tech
Godot 4.4.1 stable, Compatibility renderer, typed GDScript. `rules/` is pure (no Node, no scene) so a headless authority can reuse it. Android is unvalidated until proven.
