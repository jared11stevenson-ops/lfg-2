# ASCENDANT — overnight backlog (lead agent). Update after every cycle.
Started ~11pm user-local (container 2026-11-28 ~05:10 UTC). HARD STOP after the 11th hourly wake-up (~10am). Never stop earlier because of difficulty: find workarounds.

## Verified so far (see PROGRESS.md for evidence)
Genome(47 loci)->Phenotype->procedural creature art; EcoSim (plants, predation, selection, migration, speciation, extinction, cognition ratchet); Oracle headless runner; terrain shader; props; Critter AI; player combat/abilities; heirs; HUD; first playable frame.

## Oracle findings to act on
- Speciation ~1/yr too fast; per-tick cost grows to ~180ms with ~170 species. Needs niche competition + merge/cap.
- Sapience emerged in 2/3 seeds (ants, rooks, minnows, hares) — need civilization layer to consume `sim.sapient_events`.

## Priority queue
1. Civilization layer (sim/civ.gd): tribes from dawn events; settlements via environmental operations derived from anatomy (excavate/deposit/bind/weave/cultivate/redirect water); structures in world; ruins on collapse; draw them (art/structure_art.gd).
2. Invention system (core/materials.gd, core/invention.gd): property-based; knowledge states; player crafting UI.
3. Items with persistent history (core/item.gd) + heirlooms inheritance across deaths + legendary derivation from deeds.
4. Title screen, world creation (seed), save/load (full sim+player), settings, observer mode, tutorial prompts.
5. Art constitution doc + quarantine manifests for creature families/props/terrain; independent critic passes with screenshots (Keeper agent).
6. Procedural audio (AudioStreamWAV synth): ambience, footsteps, bites, UI.
7. Multiplayer: ENet authoritative server; ONLY claim after two real clients tested.
8. Oracle: branching timelines, bot playstyles, perf benchmarks.
9. Art debt: mammal heads/ears, fur look, evolved-descendant lineup, ruin/structure variety.
