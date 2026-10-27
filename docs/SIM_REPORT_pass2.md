# Grand Simulation, pass 2 rehearsal (24 seeds x 336 days, new rules)
Harness: `tools/sim_match.gd` (real Rules module; 14 classes as competing bot-run factions in one 84x54 world, classes and personas shuffled by seed; after setup the harness only ticks, every decision is made by `rules/ai_factions.gd` + `rules/ai_leaders.gd` through ordinary rules code). Aggregation: `python3 tools/sim_report.py docs/sim_pass2` (full tables in `docs/sim_pass2/report.txt`, raw per-seed JSON beside it).
Run: `for s in 1..24: godot --headless --path . -s tools/sim_match.gd -- --seed=$s --days=336 --out=...` (4 parallel, ~52 s per seed, ~5.5 min for the batch). Bots, not humans: this measures balance and stalls, not fun. Pass 5 is the real Grand Simulation.

## Headline (against docs/SIM_REPORT_0.md)
| criterion (SIM_REPORT_0 / task) | baseline | pass 2 (24 seeds) | verdict |
|---|---|---|---|
| territory keeps changing after week 8 | frozen by day 36-71 (avg 52) in 20/20 | still changing after week 8 in **24/24**, after week 24 in **24/24**; last change at day 330 on average (min 211); 4.5 holding changes per week after week 8 | **met** |
| non-raider personas earn deeds | 0 captures, no deed system | hoarder 92%, trader 100%, turtle 100% of factions earned >= 1 deed (24-64 deeds each); 0 factions sat at Rank 0 for > 8 weeks with 0 deeds | **met** |
| factions eliminated | 0 in 960 faction-matches | 8.7 of 14 per match (first at day ~48, 1.1 by week 8, 3.8 by week 12, 8.0 by week 24, 8.7 by week 48) | converging, see below |
| leader deaths | 24 total in 20 matches | **153 in 24 matches (6.4 per match)**: 130 by raid parties/sieges (105 by the party itself, 20 by a leader marching with it, 5 other), 11 leader duels, 5 spore swarms, 4 sorties, 3 famine/unknown | met |
| >= 80% of seeds with exactly one faction alive by week 24 (stretch) | 0% | **0/24**. Alive at week 24: mean 6.0 (min 4, max 8); week 48: mean 5.3 (min 3, max 8) | **missed** |
| Total Conquest reached | n/a | **0/24** (no seed gets below 3 survivors; 7-23 holdings, mean 14.8, are neutral at day 336) | **missed** |
| class decides, persona biases | persona decided everything | share of variance in final holdings: class 13% vs persona 6%; in survival: class 27% vs persona 8%; but persona still explains more of captures (25% vs 19%) and peak rank (39% vs 13%). Capture-biased classes (Rook/Bram/Forge) out-capture other classes inside every persona: trader 17.0 vs 7.3, turtle 29.5 vs 6.4, hoarder 2.8 vs 1.6, raider 32.2 vs 24.8 | partly met |
| no class > 2x or < 0.5x fair share | n/a (needs wins) | **missed badly**: average final holdings per class run from 4.33 (Judd) and 3.83 (Oren) down to 0.00 (Vex, 100% eliminated, avg day 79); see below | **missed** |
| CPU: tick < 3 ms avg with 14 factions | n/a | **0.86 ms** mean per `Rules.tick(2 s)` (worst seed 0.96 ms); `test_fourteen_faction_tick_stays_under_three_milliseconds` asserts it | met |
| ability usage: every class kit exercised | pip, forge, vex, dune, oren, ~mira at 0 | 14 of 18 abilities fired (dash, ram, cache, field dressing, plague cloud ... see table). **Pickpocket (Vex), Warding Aura (Halo), Track (Sable peace) and Truce Flag (Quill) had 0 attempts** in this batch | partly met |

## What the new rules do (measured)
- Per match: 162 holding captures, 6.4 leader deaths, 8.7 eliminations (208 in 24 matches). 60% of eliminations are a leader killed in a raid/siege (125), 26% the loss of the last holding (55) - the leader-kill route finally works for AI leaders.
- Elimination causes: raid_party 125, holdings_lost 55, famine 12, leader_duel 11, spores 5. Leader damage taken: raid_party 29785, sortie 4432, leader_duel 1474, spores 729, poison 504, sentinel 337, dash 127.
- Rank curve (share of faction-weeks): R0 3%, R1 35%, R2 24%, R3 9%, R4 15%, R5 14%. Max rank reached: R0 1, R1 34, R2 110, R3 33, R4 27, R5 131 factions of 336. The Mark rotated across a mean of 4.9 factions per match; no match kept one permanent Mark (0/24).
- Anti-snowball works too well for bots: the survivors average 4.95 holdings each (40 - 14.8 neutral = 25 owned by 5.3 survivors). Upkeep (n^1.4/3.5 coin/day), the weekly Levy and distance stability keep every empire near 5-8 holdings, revolts and unpaid levies hand land back to neutral, so total conquest of 40 holdings is out of reach of every bot.
- Skills: mean 99 skill points per faction over 48 weeks, mean 13.1 of 15 nodes, 234 of 336 factions finished their whole tree. All 210 nodes were bought at least once; branch split 1480 purge / 1486 hybrid / 1451 economy (the AI branch preference by persona is mild). Points are too plentiful: scouting alone is 7452 of 14,000 deeds.
- Deeds in the run: scout 7452, capture 3898, broker 3359, defend 1930, escort 441, kill_leader 141, heal 127, steal 60, kill_raider 36, kill_wild 5. Halo (pure pacifist, never captures or kills) earned 2204 scout + 426 broker deeds across 24 matches, stayed alive in 24/24 and finished 15 nodes, but sits at 1.0 holdings and rank 0.9.

## By persona (24 seeds)
| persona | factions | avg final holdings | captures/faction | leader kills | % with a deed | deeds/faction | avg final rank | avg max rank | eliminated |
|---|---|---|---|---|---|---|---|---|---|
| raider | 91 | 2.56 | 24.3 | 73 | 100% | 56.0 | 2.93 | 4.64 | 54% |
| turtle | 85 | 2.49 | 10.0 | 45 | 100% | 64.1 | 2.09 | 3.29 | 48% |
| trader | 76 | 1.59 | 9.0 | 17 | 100% | 62.5 | 1.86 | 3.22 | 63% |
| hoarder | 84 | 0.46 | 1.8 | 6 | 92% | 25.7 | 1.26 | 2.01 | 83% |
Turtles and traders now capture (class-biased warlords inside those personas and the late-game "fat garrison" ambition rule), tribute is paid 861/1173/1162 times by hoarders/traders/turtles (raiders 163). Hoarders remain the weakest persona: low-garrison thieves that raiders eat first.

## By class (average final holdings, 24 seeds each)
| class | final holdings | alive at end | eliminated | avg elim day | captures | leader kills | deeds/faction | nodes | elimination causes |
|---|---|---|---|---|---|---|---|---|---|
| judd | 4.33 | 67% | 33% | 99 | 21.2 | 12 | 70.7 | 13.0 | raid 2, holdings 5, famine 1 |
| oren | 3.83 | 58% | 42% | 89 | 22.9 | 18 | 73.7 | 12.6 | holdings 10 |
| bram | 3.67 | 46% | 54% | 99 | 21.2 | 13 | 50.2 | 13.8 | raid 8, holdings 5 |
| rook | 2.54 | 33% | 67% | 110 | 16.2 | 16 | 45.9 | 13.0 | holdings 6, raid 7, famine 1, spores 2 |
| forge | 2.29 | 46% | 54% | 116 | 19.2 | 22 | 46.0 | 13.1 | holdings 7, raid 3, famine 2, spores 1 |
| sable | 1.62 | 42% | 58% | 95 | 6.7 | 9 | 53.4 | 13.0 | holdings 5, raid 7, duel 2 |
| pip | 1.33 | 17% | 83% | 113 | 13.2 | 15 | 33.6 | 11.9 | raid 14, holdings 5, duel 1 |
| tavi | 1.33 | 46% | 54% | 137 | 14.4 | 10 | 60.0 | 13.8 | raid 6, holdings 5, famine 2 |
| halo | 1.00 | 100% | 0% | - | 0.0 | 0 | 109.6 | 15.0 | none |
| mira | 1.00 | 17% | 83% | 71 | 6.0 | 3 | 30.4 | 12.5 | raid 16, duel 3, spores 1 |
| dune | 0.92 | 12% | 88% | 103 | 6.2 | 4 | 31.8 | 13.4 | raid 18, holdings 2, duel 1 |
| nyx | 0.83 | 33% | 67% | 122 | 7.5 | 15 | 64.1 | 13.5 | raid 11, famine 1, holdings 4 |
| quill | 0.50 | 17% | 83% | 113 | 6.2 | 3 | 41.5 | 14.5 | raid 15, duel 1, famine 3, holdings 1 |
| vex | 0.00 | 0% | 100% | 79 | 1.7 | 1 | 16.3 | 11.1 | raid 18, duel 3, famine 2, spores 1 |
Reading: the brittle classes (effective HP < 70: Vex 49, Mira 49, Quill 56, Dune 64) die at home sieges; the sturdy classes (Judd, Oren, Bram, Rook, Forge) hold the map; the pacifist is unkillable but passive. That is class identity showing, but the spread is far outside the 0.5x-2x band, so **the fairness criterion is not met**. Per-class win counts are 0 (no Total Conquest).

## Per-ability attempts (AI leaders, same Abilities.use path as a player)
bless 2304 ok, mine 5463 ok, forage 4963 ok (1 bad_terrain), cache 276 ok, rally 309 ok, siege_ram 200 ok, field_dressing 133 ok, rage 105 ok, spore_swarm 94 ok, dash 85 ok / 8 occupied, plague_cloud 84, sentinel_post 79, guard 47, snare 81 ok / 73 occupied. **Not exercised: pickpocket (Vex), ward (Halo), track (Sable's peace ability), truce flag (Quill: her tribute goes through PurgeActions.sign_truce, not the ability)**. Leaders pre-check cooldown and energy, so failure counts are not spam (cooldown failures were 70-80% of attempts before that fix).

## Instrumentation delivered (Sim #0 findings 5)
Per-ability attempts/failure reasons (`state.sim_acc.ablog` with `opts.ai_log`), kill causes (last damage tag + source kind), leader damage by tag, deeds by kind per faction, rank curve per week, skill nodes taken, tributes, unpaid levies, starvation days, revolts, idle bleeds, parties and leader-led parties, tick time and wall time.

## Missed criteria and next fixes (in priority order)
1. **No Total Conquest, no seed with one survivor (stretch 0/24).** The anti-snowball brake (upkeep + Levy + stability) caps bots at ~5-8 holdings and neutral land (mean 14.8 holdings) is never re-absorbed. Next: let rank, the Shrine/Granary line and conquered-land "pacify" actions reduce revolts so a leader can hold 12+; make raiders prefer unowned holdings once the last rivals are strong; shorten ACT_COOLDOWN further late; a "last rival" hunt mission (all survivors target the weakest survivor's leader). Re-measure with the 80%-by-week-24 target.
2. **Class fairness.** Fragile classes die at home sieges. Next: a stealth/escape option for thieves and scribes (Vex's `steal` mission should not expose the leader and should use pickpocket), a retreat-to-neighbour rule for leaders under 40% HP, and let diplomats' tribute work against raiders earlier. Give Halo's Ward a reliable trigger (it needs an adjacent hostile at its own holding) so the pacifist class is a participant.
3. **Skill points are too cheap for bots.** Scouting yields 7452 deeds; AI finishes trees in ~25 weeks. Next: lower scout/escort standing, raise node costs or add a per-week point cap, and give bots wider branch preferences (the branch split is nearly even).
4. **Hoarders (83% eliminated)** need either better defence use of their loot (granary shield, more recruits) or a stronger steal route (60 steal deeds in 24 matches is almost nothing).
5. **Nobody fights wild beasts** (5 kill_wild deeds): beast waves only threaten the human player; give AI garrisons a role against waves so ashmarrow flows to AI (salvage picks up what parties drop, but only raiders create that).
6. Presentation/net untested here: AI leaders marching with parties move without `actor_moved` events.

## Tests run for this pass
Full suite `godot --headless --path . -s tests/run_all.gd`: 42 suites, 378 tests, 19086 checks, 0 failures (baseline 296 tests). New suites: test_standing (26 tests), test_purge_pressure (14), test_skills (14), test_ai_classes (20), test_standing_panels (5).
