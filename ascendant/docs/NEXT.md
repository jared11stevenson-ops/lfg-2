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

## Update after build cycle 2 (evidence-driven)
DONE since: civilization layer + art, materials/invention/items, save/load, title/new world/settings/pause, crafting UI, heirloom ledger, mate chooser + practice inheritance, civ trade/provoke/ruin search, contextual hints, procedural audio, mammal heads, bot playtest tool (tools/playtest.gd), 771 test checks green.

Oracle findings still open:
- t6/t7: sapience in every world by ~tick 300, but ants dominated every world before COG_CAP per body plan (t7 run in progress: docs/oracle/t7.json). CHECK diversity of dawn species; want worlds dominated by different species (aquatic/subterranean/avian).
- `dawn` events are per-deme (inflated 20-46); civ count now bounded (2-11). Report per-civ in oracle.
- No wars/infrastructure-harm events in most worlds: relations only drop through harm; add resource-contention and border pressure triggers.
- Per-tick cost 100-150 ms with ~45 species: OK for 45s seasons but spiky; move sim.step to a Thread or time-slice regions.
Playtest findings (docs/playtest/run1.json, 200s each): all 8 bot runs survived, player almost never killed by predators -> RISK TOO LOW in the first minutes; raise predator pressure near player / add predator pursuit. Hunters (stoat) got only 8 kills in 200s.

Next priorities: (1) risk/danger tuning + death-by-predator test; (2) civ diversity tuning; (3) player-visible civ members: tools, weapons carried; (4) combat telegraph visuals; (5) multiplayer prototype (server-authoritative ENet) — NOT claimed until two real clients tested; (6) Keeper agent resume (it hit a rate limit; resume with SendMessage to a2b47c30385fb1b71) for critique + quarantine manifests + checklist.

## Tick 3 result (playtest run 3, docs/playtest/run3.json)
Fixed: predators' close-range attacks always missed (facing check on ~0 distance) and metabolism drained ~3x too fast (predators starved in ~25s). Test `test_predation` proves a hungry stoat kills an idle vole.
Effect: world deaths per 240s fell from 25-34 to 0-8 (less starvation churn), but NO bot player died to a predator in 9 runs. Danger is still low for fleeing bots. Next: ambush/pack predators, predator density near player, check whether wild prey ever die to predators in the headless sim (log kill counts by cause), possibly raise world churn back via harsher winters.

## Tick 4 Oracle (docs/oracle/t8.json, seeds 30-34, 500 seasons, current build)
Civilizations emerged in 5/5 worlds at ~year 100. Civ species per world: Ash Rook | Dune Hare | Ash Rook | Ash Rook+Hare | Reed-Gnawer. Ant dominance is gone (COG_CAP worked). Remaining problem: still only 3 founder species ever become civilizations (rook, hare, reed-gnawer); never spiders, moles, frogs, squirrels. Rooks win 3/5. Next: per-niche cognition benefits for burrowers (mole), silk-weavers (spider), amphibians; check per-species ci distributions; per-tick cost 115-155ms.
