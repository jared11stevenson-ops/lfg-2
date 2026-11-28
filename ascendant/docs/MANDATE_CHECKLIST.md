# ASCENDANT mandate checklist

Sections 1-28 are the keeper's grouping of the condensed mandate (the original spec text was not available verbatim). Status values: NOT STARTED / PARTIAL / VERIFIED. VERIFIED requires real evidence (a run, a render, a test). Last updated 2026-11-28 by keeper; lead code not yet reviewed.


## 1 Core gameplay loop

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | World starts with primitive animals in a functioning ecosystem | NOT STARTED | - |
| [ ] | Player lives as mortal creature in the live world | NOT STARTED | - |
| [ ] | Moment-to-moment loop (eat, survive, reproduce, explore) is fun and readable | NOT STARTED | - |
| [ ] | Observer mode optional | NOT STARTED | - |

## 2 Ecosystem

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Producers/herbivores/predators/decomposers energy flow | NOT STARTED | - |
| [ ] | Population dynamics stable over long runs (no collapse/explosion) | NOT STARTED | - |
| [ ] | Biomes, climate, seasons affect life | NOT STARTED | - |

## 3 Genetics

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Heritable genome with mutation and recombination | NOT STARTED | - |
| [ ] | Anatomy, senses, metabolism derived from genome | NOT STARTED | - |
| [ ] | Speciation observed in long runs (reproductive isolation) | NOT STARTED | - |
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
| [ ] | Populations evolve intelligence independently, not scripted | NOT STARTED | - |

## 5 Civilization emergence

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Requires communication+cooperation+opportunity+knowledge transmission | NOT STARTED | - |
| [ ] | No humans-in-costume: anatomy/senses/metabolism decide civilization form | NOT STARTED | - |
| [ ] | Distinct civ types (beaver dams, spider silk, mole tunnels, crow nests, ant castes) | NOT STARTED | - |

## 6 Technology / invention

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Materials with physical properties | NOT STARTED | - |
| [ ] | Property-based invention (material x biology x problem) | NOT STARTED | - |
| [ ] | No universal tech tree | NOT STARTED | - |
| [ ] | Knowledge discovered/taught/traded/stolen/forgotten/rediscovered | NOT STARTED | - |

## 7 Culture

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Cultural transmission with drift | NOT STARTED | - |
| [ ] | Culture differs between populations | NOT STARTED | - |

## 8 Ruins & persistence

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Civilizations leave permanent/decaying ruins | NOT STARTED | - |
| [ ] | World persists across player deaths | NOT STARTED | - |

## 9 Player bloodline / permadeath

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Mortal bloodline with permadeath | NOT STARTED | - |
| [ ] | Heirs inherit | NOT STARTED | - |
| [ ] | Observer mode when no heir | NOT STARTED | - |

## 10 Combat

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Real-time skill-based combat | NOT STARTED | - |
| [ ] | Shaped by anatomy (reach, weapons, senses) | NOT STARTED | - |
| [ ] | Readable hit feedback | NOT STARTED | - |

## 11 Heirlooms

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Persistent item histories (creator, owners, repairs, battles) | NOT STARTED | - |
| [ ] | Legendary status earned, not random rarity | NOT STARTED | - |

## 12 Multiplayer / PvP

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Server-authoritative design | NOT STARTED | - |
| [ ] | Tested with separate real clients (never claim otherwise) | NOT STARTED | - |

## 13 Procedural art - identity

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Beautiful, distinct identity, no programmer art | NOT STARTED | - |
| [ ] | Silhouette/palette/readability/cohesion per asset | NOT STARTED | - |

## 14 Asset quarantine pipeline

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Manifests + schema | VERIFIED | assets/manifest/_schema.json, tests/test_asset_gate.gd |
| [x] | Validation gate (reviewer!=creator, evidence images, floors, critical failures) | VERIFIED | tools/asset_gate.gd on tests/fixtures/manifests: 2 pass, 7 fail as intended |
| [x] | Approved-only runtime registry | VERIFIED | assets/approved_registry.gd; test_registry_only_approved |
| [ ] | Runtime generators: generator + validated output space; per-output deterministic validation | PARTIAL | Manifest requirement enforced in gate; no actual per-output validator or real generator yet |
| [ ] | Real approved assets with rendered evidence (none yet) | NOT STARTED | - |

## 15 Animation

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Anatomy-driven locomotion/animation | NOT STARTED | - |
| [ ] | Readable at game camera distance | NOT STARTED | - |

## 16 Audio

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Procedural/adaptive audio (dummy output in CI) | NOT STARTED | - |

## 17 UI/UX

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | No empty menus | NOT STARTED | - |
| [ ] | Menus functional and navigable | NOT STARTED | - |
| [ ] | Readable HUD | NOT STARTED | - |

## 18 Oracle: determinism

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Deterministic seeds | NOT STARTED | - |
| [ ] | Snapshots save/load identical | NOT STARTED | - |

## 19 Oracle: headless sim

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Headless accelerated simulation | NOT STARTED | - |
| [ ] | Branching futures | NOT STARTED | - |
| [ ] | Report JSON diffable (tools/future_report.py) | NOT STARTED | - |

## 20 Oracle: judging by output

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Systems judged by many-generation results | NOT STARTED | - |
| [ ] | Automated player agents | NOT STARTED | - |

## 21 Playtest

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Automated playtest runs with logs | NOT STARTED | - |
| [ ] | Human-like session evidence (screens) | NOT STARTED | - |

## 22 Performance

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Target frame rate with N creatures documented | NOT STARTED | - |
| [ ] | Headless sim throughput numbers measured | NOT STARTED | - |

## 23 Testing

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [x] | Test harness (tools/run_tests.sh) | VERIFIED | `tools/run_tests.sh` 97 checks pass (2026-11-28) |
| [ ] | Unit tests for genetics/sim/gate | PARTIAL | gate only; no genetics/sim tests yet |
| [x] | CI-style one command run | VERIFIED | tools/run_tests.sh |

## 24 Persistence/save

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | Save/load world | NOT STARTED | - |
| [ ] | Save/load bloodline | NOT STARTED | - |

## 25 Completeness

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | No placeholder-as-finished | NOT STARTED | - |
| [ ] | All spec systems present, none silently dropped | NOT STARTED | - |

## 26 Anti-slop

| Done | Requirement | Status | Evidence |
|---|---|---|---|
| [ ] | No fake simulation | NOT STARTED | - |
| [ ] | No fabricated test results | NOT STARTED | - |
| [ ] | No empty menus | NOT STARTED | - |
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
