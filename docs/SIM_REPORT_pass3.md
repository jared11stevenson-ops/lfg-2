# Grand Simulation, pass 3 rehearsal (24 seeds x 336 days, after the pass-2 findings were fixed)
Harness: `tools/sim_match.gd` (real Rules module; 14 classes as bot-run factions in one 84x54 world; after setup it only ticks, every decision is made by `rules/ai_factions.gd` + `rules/ai_leaders.gd` through ordinary rules code). Aggregation: `python3 tools/sim_report.py docs/sim_pass3` (full tables in `docs/sim_pass3/report.txt`, raw per-seed JSON beside it). Seeds 1-24, a match ends early on Total Conquest. 4 parallel processes, ~57 s per seed. Bots, not humans: this measures balance and stalls, not fun.
This is the 7th 24-seed batch of the pass (plus a one-seed smoke run); the earlier six were tuning runs. The tuning path (all on the same 24 seeds): everything on at once (hunt at <= 6 survivors from week 8) gave Total Conquest in 23/24 seeds; a "last stand" bonus with a late hunt gave 0/24 conquests; the shipped setting (below) gives 7/24. Nothing was tuned per seed.

## What changed in the rules (pass-2 findings 1-3, plus Vex/Halo)
- **Hold many holdings**: `pacify` (command + AI governor): stability +30, floor 62, no revolt for 6 days, 1 ration + 2 coin per tier from the faction's stores; the AI only pays while fed.
- **Last-rival hunt**: week >= 12 and <= 5 factions alive: every non-pacifist survivor raids, x3 party size, +4 dispatch slots, musters from the whole realm, stages from outposts, accepts power ratio 0.7, favours the weakest survivor's home.
- **Last stand** x1.4 defence for a faction on its last holding (anti-wipe-out; trades against conquest speed).
- **Parties no longer march when they cannot arrive before the Purge ends** (they used to be recalled at dawn and the troops wasted). This is the single biggest change in territory dynamics.
- **Leader escape** (`data/ai_kits.json`): `escape.slip` makes raiders miss (Vex .6, Quill .4, Mira/Dune .25); under 40% HP a leader falls back to another own holding (not under siege) or, with `flee`, hides in open ground until dawn. Vex joins steal parties unseen (`stealth`: immune to sorties and raiders) and picks the holding leader's pocket with the real Pickpocket when it stands at the door. Halo casts Warding Aura the moment any siege of its holdings begins.
- **Slower skill trees**: non-root nodes cost x2 (a whole tree = 69 points), a leader earns at most 3 skill points per calendar week, scout/escort deeds pay once per Purge at Standing 1.

## Headline against SIM_REPORT_pass2.md and the pass criteria
| criterion | pass 2 | pass 3 (24 seeds) | verdict |
|---|---|---|---|
| Total Conquest achievable | 0/24 | **7/24** (days 238, 259, 259, 301, 322, 322, 336; winners rook x4, oren, tavi, forge) | **met** |
| exactly one faction alive by week 24 (stretch, >= 80%) | 0/24 | **0/24** (alive at week 24: mean 8.2, min 6). One survivor at some point: 9/24 (7 conquests + 2 seeds where the last survivor ran out of days with 1 neutral holding left) | **missed** |
| a leader can hold 12+ holdings | nobody (survivors ~5) | **24/24 seeds** have a faction that peaked >= 12, 17/24 >= 20, max 39. 50 of 336 factions (14.9%) ever held >= 12 | **met** |
| territory keeps changing after week 8 / 24 | 24/24, 24/24 | 24/24, 24/24 (last change day mean 318) | met |
| Vex not eliminated 100% | 100% eliminated, mean day 79, 18 raid deaths | **96% (23/24)**, mean day 163, 1 death by raid party (19 by losing the last holding, 2 famine, 1 sentinel) | **barely met**: the leader now survives raids, but a 1-holding hoarder Vex still loses its only holding |
| Halo's Ward has a reliable trigger | 0 casts | **25 casts** (any siege of its holdings); Halo is no longer unkillable: eliminated 10/24 (the hunt reaches it) | met |
| pickpocket used | 0 attempts | **128 attempts** (stealth steal jobs, real `Abilities.use`) | met |
| `track` (Sable) and Truce Flag (Quill) used by bots | 0 | **still 0** (AI uses neither; Quill's tribute goes through PurgeActions) | missed |
| skill trees not finished by bots in ~25 weeks | 234/336 finished (70%), mean 13.1 of 15 nodes, 99 points | **83/336 finished (25%); by week 25 only 6 (1.8%)**; median finish week 36; mean 10.9 nodes, 50 points. All 210 nodes still bought at least once | met |
| scouting does not dominate deeds | scout 7452 of 14,000 (53%) | scout 4251 of 15,683 (27%), broker 4507, defend 3015, capture 3288 | met |
| no class eliminated > 60% | 7 of 14 above 60% | **11 of 14 above 60%** (range 42% Halo to 96% Vex); eliminations per match 9.6 (was 8.7) | **missed** |
| no class finishing < 0.5x or > 2x fair share | final holdings 4.33 .. 0.00 | mean days alive: all 14 classes within **0.80x-1.37x** of the mean. Peak holdings: Halo 0.18x (pacifist, 1 holding by design), Rook 2.36x. Final holdings per class 12.92 (Rook) .. 0.04 (Vex): far outside the band | **partly**: survival is in the band, land is not |
| CPU | 0.86 ms per `Rules.tick(2 s)` | **0.98 ms** mean (max 1.14), still < 3 ms | met |
| leader deaths per match | 6.4 | 5.6 (135: 96 by raid parties, 12 by a leader marching with them, 11 sorties, 3 duels, 3 spores, 8 unknown) | n/a |
| first elimination | day ~48 | day 69 on average (earliest 35) | n/a |

## Per class (24 seeds each; `docs/sim_pass3/report.txt`)
| class | mean days alive (vs mean) | peak holdings | final holdings | eliminated | wins |
|---|---|---|---|---|---|
| halo | 293 (1.37x) | 1.00 | 0.58 | 42% | 0 |
| oren | 250 (1.17x) | 9.58 | 5.08 | 54% | 1 |
| rook | 236 (1.10x) | 13.42 | 12.92 | 50% | 4 |
| tavi | 234 (1.10x) | 6.67 | 2.42 | 62% | 1 |
| judd | 233 (1.09x) | 5.83 | 2.50 | 62% | 0 |
| nyx | 218 (1.02x) | 5.17 | 1.75 | 67% | 0 |
| dune | 207 (0.97x) | 3.67 | 0.58 | 75% | 0 |
| mira | 205 (0.96x) | 6.92 | 2.25 | 75% | 0 |
| forge | 202 (0.94x) | 7.33 | 2.75 | 67% | 1 |
| sable | 198 (0.93x) | 3.17 | 0.46 | 83% | 0 |
| bram | 190 (0.89x) | 4.88 | 1.12 | 71% | 0 |
| quill | 185 (0.86x) | 3.62 | 0.92 | 71% | 0 |
| pip | 171 (0.80x) | 5.29 | 0.33 | 83% | 0 |
| vex | 171 (0.80x) | 3.21 | 0.04 | 96% | 0 |
Reading: Rook (Banner/Warlord) is the only class that converts the new "hold many" rules into conquests (4 of 7); Oren, Tavi and Forge win once each. Vex, Pip, Sable and Dune remain the weakest; their losses are the persona and a single holding (`hoarder` 81% eliminated, `trader` 72%, `raider` 63%, `turtle` 59%) more than the class kit.

## Honest reading of the misses
1. **Elimination > 60% is structural.** A seed that ends in Total Conquest eliminates 13 of 14 factions by definition, and the field also thins through lost last holdings and famine (50 famine collapses in 24 matches: passive single-holding factions that nobody raids still starve in the end). With conquests possible at all, the mean elimination rate cannot sit under 60%. The only way down is fewer raids or no elimination by capture, which would change the owner's rule "losing your last holding eliminates you".
2. **"One survivor by week 24" is far off** (0/24; the earliest conquest is day 238): the anti-snowball brakes, last stand and Purge-window travel limits make the endgame slow by design. Conquests land at weeks 34-48, consistent with a ~10-hour real-time match.
3. **Class fairness in land** is not met; survival time is. Vex still loses its only holding. Next levers: a granary/recruit routine for hoarders (pass-2 finding 4), letting hoarder/trader leaders garrison with their loot, and AI use of `track`/`truce`.
4. Two seeds ended with one survivor and one neutral holding left at day 336 (seeds 4 and 22): the final holding is far from every outpost; a longer horizon or a nearer staging rule would finish them.

## Other measured effects
- 3288 captures, 626 revolts in 24 matches (up from 62 earlier in the pass when the AI paid for Pacify from the last of its rations; the feeding rule trades revolts for fewer famines), 14,983 pacify actions.
- Retreats/hides: 481; stealth steal jobs: 1578; warding aura casts: 25; pickpocket 128 (all resolved through `Abilities.use`).
- Ability attempts (AI leaders): mine 5608, forage 4531, bless 2012, rally 444, plague cloud 261, snare 254 (50% `occupied`), siege ram 217, dash 171, pickpocket 128, spore swarm 130, cache 279, field dressing 134, sentinel post 97, rage 87, guard 63, ward 25; `track` and `truce` 0.
- Rank curve (faction-weeks): R0 5%, R1 38%, R2 24%, R3 8%, R4 9%, R5 15% (see report.txt); the Mark rotated across 4.0 factions per match, no permanent Mark.

## Tests run for this pass
Full suite `godot --headless --path . -s tests/run_all.gd`: 47 suites, 456 tests, 25,019 checks, 0 failures (pass 2: 42 suites, 378 tests). New suites: `test_quests` (22), `test_pois` (14), `test_tiers` (14), `test_hold_hunt` (19), `test_pass3_world` (9). Three pass-2 tests were updated on purpose (skill costs/weekly cap in `test_skills`, per-deed points in `test_standing`, last-stand-neutral defence numbers in `test_depth`); `test_purge_pressure` now counts POI loot as a solo source; `test_world_layers` lost the `model_pending` allowance. Screenshots (software GL, evidence only): `art/captures/pass3/*.png`.
