# Changelog

## Unreleased
- Skeleton, design and contracts.

## v0.1.0 — Integrated vertical slice
- Playable `main/main.tscn`: Rules (84x54 hex world, 14 class defs, Purge machine, farming, rations, permadeath) + 3D diorama world + HUD, wired via `Game` autoload.
- Headless authoritative ENet server, versioned saves, cosmetic-only meta store.
- Evidence: art/captures/integrated/ (scripted journey; positions set visually, all effects via Rules commands).

## v0.2.0 — Pass 1
- All 14 classes have real mechanics (data `implemented:true`); AI faction parties path and raid; authoritative `sync_position` movement (anti-teleport); buildings/production/merchant prices; exact save round trips.
- Menu, 14-class select, end screens; distinct class/enemy/NPC models; build/craft/trade/policy/holdings panels; combat FX, ability bar, danger indicator; roads, building/crop models.
- Sessions (local/online), autosave/continue + permadeath tombstone, cosmetic meta store; fog-filtered snapshots, token expiry, Purge disconnect lock; multi-process shared-world test.
- Grand Simulation #0 harness and report; docs for incentives, skill trees, Total Conquest.

## v0.3.0 — Pass 2
- Total Conquest is the only win (Dominion/Crowned removed); Prosperity score; any leader's death eliminates its faction; rival-conquest game-over.
- Standing/ranks (0-5, no combat stat), deeds with decay, Mark + bounty, Purge Levy, upkeep/stability, thin crown; Purge-only purgebloom/ashmarrow; escalating waves; scout/escort/truce/ransom/sabotage commands.
- 14 skill trees (15 nodes each) fed only by Purge deeds; Standing and Skills panels wired (RANK button, P/K keys).
- Class-aware AI leaders; passive personas earn deeds. See docs/SIM_REPORT_pass2.md.

## v0.4.0 — Pass 3
- Quest engine + 8 class questlines (6 stubs), converging solo-completable steps; quest journal.
- 40 POIs per world (7 types, weekly respawn, discovery rewards), props and map markers; T2/T3 resources, 4 stations, 14 new buildings with models.
- Balance: Vex survivability, Halo Ward trigger, costlier skill nodes, empires of 12+ holdings, last-rival hunt. Total Conquest reached in 7/24 sim seeds (was 0/24). See docs/SIM_REPORT_pass3.md.

## v0.4.1 — Pass 3b (balance, questlines)
- Class-balance work (mercy, settlers, conquerors, escape, home ground, ration discipline), six more full questlines (14/14 lines), death-log harness, killer-faction heir rule (AI that kills a leader inherits its realm). 48 suites / 481 tests green.
