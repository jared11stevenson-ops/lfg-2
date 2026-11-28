# ASCENDANT mandate checklist

Sections 1-28 are the keeper's grouping of the condensed mandate (the original spec text was not available verbatim). Status values: NOT STARTED / PARTIAL / VERIFIED. VERIFIED requires real evidence (a run, a render, a test). Last updated by keeper after critic pass 1 (772 test checks, oracle t1-t10, playtest run1-3, 7 reviewed captures).


## 1 Core gameplay loop

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | World starts with primitive animals in a functioning ecosystem | PARTIAL | docs/oracle/t1.json: 129-144 alive, 27-36 extinct at 2 seeds; ecosim exists. Long-run balance unproven |
| [ ] | Player lives as mortal creature in the live world | PARTIAL | captures/play3.png; docs/playtest/run*.json (9 bot runs, all still 'playing', 0 kills in all, max_gen 2) |
| [ ] | Moment-to-moment loop (eat, survive, reproduce, explore) is fun and readable | NOT STARTED | - |
| [ ] | Observer mode optional | NOT STARTED | no evidence seen |

## 2 Ecosystem

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Producers/herbivores/predators/decomposers energy flow | NOT STARTED | - |
| [ ] | Population dynamics stable over long runs (no collapse/explosion) | NOT STARTED | - |
| [ ] | Biomes, climate, seasons affect life | NOT STARTED | - |

## 3 Genetics

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Heritable genome with mutation and recombination | PARTIAL | tests/test_core_systems.gd genome_constraints, inheritance_keeps_ancestry (772 checks pass) |
| [ ] | Anatomy, senses, metabolism derived from genome | PARTIAL | test_phenotype_valid_for_all_archetypes (300 checks) |
| [ ] | Speciation observed in long runs (reproductive isolation) | PARTIAL | oracle series show species counts rising/falling (docs/oracle/t1.json); isolation mechanism not independently verified |
| [ ] | Phylogeny tracking | NOT STARTED | - |

## 4 Intelligence dimensions

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Spatial | NOT STARTED | - |
| [ ] | Memory | NOT STARTED | - |
| [ ] | Communication | NOT STARTED | - |
| [ ] | Cooperation | NOT STARTED | - |
| [ ] | Tool manipulation | NOT STARTED | - |
| [ ] | Planning | NOT STARTED | - |
| [ ] | Experimentation | NOT STARTED | - |
| [ ] | Populations evolve intelligence independently, not scripted | PARTIAL | docs/oracle/t2,t3,t5-t10: sapient counts vary by seed (0 to 206); t9 overshot, t10 retuned. Payoffs are hand-tuned (niche cognition payoffs commit), so 'not scripted' is unproven |

## 5 Civilization emergence

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Requires communication+cooperation+opportunity+knowledge transmission | PARTIAL | sim/civ.gd exists; oracle dawn_species/first_dawn recorded; no ablation test yet |
| [ ] | No humans-in-costume: anatomy/senses/metabolism decide civilization form | NOT STARTED | - |
| [ ] | Distinct civ types (beaver dams, spider silk, mole tunnels, crow nests, ant castes) | PARTIAL | captures/structure_gallery_v1.png, civ_real_seed12.png; test_silk_only_for_secretors; castes not seen |

## 6 Technology / invention

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Materials with physical properties | PARTIAL | core/materials.gd; test_invention_is_property_based |
| [ ] | Property-based invention (material x biology x problem) | PARTIAL | test_invention_is_property_based (5 checks); captures/craft_bench.png shows body-gated problems |
| [ ] | No universal tech tree | PARTIAL | craft UI is per-body problem list, not a tree; no trade/steal/forget/rediscover evidence |
| [ ] | Knowledge discovered/taught/traded/stolen/forgotten/rediscovered | NOT STARTED | - |

## 7 Culture

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Cultural transmission with drift | NOT STARTED | - |
| [ ] | Culture differs between populations | NOT STARTED | - |

## 8 Ruins & persistence

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Civilizations leave permanent/decaying ruins | PARTIAL | art/structure_art.gd ruin param; structure_gallery_v1.png rows 3-4 render ruins; lifecycle in sim not verified |
| [ ] | World persists across player deaths | PARTIAL | captures/play3.png message 'You wake as another'; no test |

## 9 Player bloodline / permadeath

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Mortal bloodline with permadeath | NOT STARTED | - |
| [ ] | Heirs inherit | NOT STARTED | - |
| [ ] | Observer mode when no heir | NOT STARTED | - |

## 10 Combat

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Real-time skill-based combat | PARTIAL | HUD shows Strike/Dodge/Pounce; bots recorded 0 kills in run1-3, so combat is unevidenced |
| [ ] | Shaped by anatomy (reach, weapons, senses) | NOT STARTED | - |
| [ ] | Readable hit feedback | NOT STARTED | - |

## 11 Heirlooms

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Persistent item histories (creator, owners, repairs, battles) | PARTIAL | craft_items.png shows creator, kills, owners; test_item_legend_is_earned. Repairs not shown |
| [ ] | Legendary status earned, not random rarity | PARTIAL | test_item_legend_is_earned (6 checks) |

## 12 Multiplayer / PvP

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Server-authoritative design | NOT STARTED | - |
| [ ] | Tested with separate real clients (never claim otherwise) | NOT STARTED | - |

## 13 Procedural art - identity

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Beautiful, distinct identity, no programmer art | PARTIAL | docs/CRITIQUE.md: world/UI cohesive, mammals and boulders weak |
| [ ] | Silhouette/palette/readability/cohesion per asset | PARTIAL | assets/manifest/*.json: 1 approved (terrain shader), 5 quarantined with written reasons |

## 14 Asset quarantine pipeline

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Manifests + schema | VERIFIED | assets/manifest/_schema.json, tests/test_asset_gate.gd |
| [x] | Validation gate (reviewer!=creator, evidence images, floors, critical failures) | VERIFIED | tools/asset_gate.gd on tests/fixtures/manifests: 2 pass, 7 fail as intended |
| [x] | Approved-only runtime registry | VERIFIED | assets/approved_registry.gd; test_registry_only_approved |
| [ ] | Runtime generators: generator + validated output space; per-output deterministic validation | PARTIAL | Manifest requirement enforced in gate; no actual per-output validator or real generator yet |
| [ ] | Real approved assets with rendered evidence (none yet) | PARTIAL | 1 approved: terrain.painterly_shader (static). Generators unapproved: no deterministic output validator |

## 15 Animation

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Anatomy-driven locomotion/animation | PARTIAL | art/creature_art.gd gait phase, undulation, swim tail; only static captures reviewed |
| [ ] | Readable at game camera distance | NOT STARTED | - |

## 16 Audio

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Procedural/adaptive audio (dummy output in CI) | NOT STARTED | - |

## 17 UI/UX

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | No empty menus | PARTIAL | title, new world, settings, craft, heirloom ledger screens render with content; text clipping remains (ui_new.png) |
| [ ] | Menus functional and navigable | PARTIAL | captures only; no UI automation test |
| [ ] | Readable HUD | PARTIAL | captures/play3.png HUD readable; hotkey bar overlapped by message box |

## 18 Oracle: determinism

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Deterministic seeds | VERIFIED | test_sim_is_deterministic (2 checks) |
| [ ] | Snapshots save/load identical | PARTIAL | save roundtrip covers tick/species/generation/genome |

## 19 Oracle: headless sim

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Headless accelerated simulation | VERIFIED | docs/oracle/t1..t10.json produced headlessly (ms_per_tick recorded, ~100 ms/tick in t1: slow) |
| [ ] | Branching futures | NOT STARTED | no branch run seen |
| [ ] | Report JSON diffable (tools/future_report.py) | NOT STARTED | - |

## 20 Oracle: judging by output

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Systems judged by many-generation results | PARTIAL | oracle runs of 48-700+ ticks with series data; t9 overshoot caught and retuned (docs/oracle t8-t10) |
| [ ] | Automated player agents | PARTIAL | docs/playtest/run1-3.json: cautious/breeder/inventor bots, 4000-4800 steps; zero kills, no end states |

## 21 Playtest

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Automated playtest runs with logs | VERIFIED | docs/playtest/run1.json..run3.json |
| [ ] | Human-like session evidence (screens) | PARTIAL | captures/play*.png, ui_*.png |

## 22 Performance

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Target frame rate with N creatures documented | NOT STARTED | - |
| [ ] | Headless sim throughput numbers measured | PARTIAL | ms_per_tick in docs/oracle/*.json; no target or budget stated |

## 23 Testing

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Test harness (tools/run_tests.sh) | VERIFIED | `tools/run_tests.sh` 97 checks pass (2026-11-28) |
| [x] | Unit tests for genetics/sim/gate | VERIFIED | tools/run_tests.sh: 772 checks pass across 8 files (genetics, sim determinism, gate, save) |
| [x] | CI-style one command run | VERIFIED | tools/run_tests.sh |

## 24 Persistence/save

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Save/load world | VERIFIED | tests/test_save_load.gd test_roundtrip (12 checks) in tools/run_tests.sh |
| [ ] | Save/load bloodline | PARTIAL | roundtrip checks genome, species, generation, items; heirs/bloodline tree not checked |

## 25 Completeness

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | No placeholder-as-finished | NOT STARTED | - |
| [ ] | All spec systems present, none silently dropped | NOT STARTED | - |

## 26 Anti-slop

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | No fake simulation | PARTIAL | oracle outputs are real runs; cognition payoffs hand-tuned, disclosed in commits |
| [x] | No fabricated test results | VERIFIED | keeper reran tools/run_tests.sh: 772 passed 0 failed |
| [ ] | No empty menus | PARTIAL | title, new world, settings, craft, heirloom ledger screens render with content; text clipping remains (ui_new.png) |
| [ ] | Honest reporting (PROGRESS/CRITIQUE) | PARTIAL | docs/PROGRESS.md exists; CRITIQUE.md pending lead commits |

## 27 Documentation

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Architecture doc filled in | NOT STARTED | docs/ARCHITECTURE.md is a stub |
| [ ] | Progress log current | PARTIAL | docs/PROGRESS.md |
| [ ] | Player guide | NOT STARTED | - |

## 28 Release readiness

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Exports run | NOT STARTED | - |
| [ ] | Known failures listed | NOT STARTED | - |
| [ ] | Scope never silently shrunk | NOT STARTED | - |
