# Grand Simulation, pass 5 (owner rule: every 5th pass, all 14 classes in one world)
Build v0.4.1 (commit 5a3ab08, pinned copy in a git worktree so the concurrent pass-4 edits could not leak in). Harness `tools/sim_match.gd` (real Rules module, 14 classes as bot-run factions in an 84x54 world, after setup it only ticks; every decision comes from `rules/ai_factions.gd` + `rules/ai_leaders.gd`). Latin-square persona assignment (each class meets each persona equally often).
Runs, all fresh seeds (pass 2/3 tuned on seeds 1-24, these were never tuned on):
- **A: 40 seeds (101-140) x 336 days** (48 weeks). Raw: `docs/sim1/336/`, tables `report.txt` (tools/sim_report.py), `extra.txt` (tools/sim_extra.py).
- **B: 10 seeds (201-210) x 700 days** (100 weeks, covers `hunt.late_week` 99). Raw: `docs/sim1/700/`.
- **C: two rule variants, 12 seeds x 336 days (101-112)**, via the harness `--over=` JSON (no rule files edited): `docs/sim1/varA.json`, `varB.json`, results `docs/sim1/varA|varB/`.
4 parallel processes; ~90 s/seed (336 d), ~160 s/seed (700 d). Bots, not humans: this measures balance, stalls and convergence, not fun.

## 1. Headline: the match does not converge
| measure | pass 3 rehearsal (24 seeds, 336 d) | **A: 40 seeds, 336 d** | **B: 10 seeds, 700 d** |
|---|---|---|---|
| Total Conquest | 7/24 (29%) | **1/40 (2.5%)** day 245 (Oren) | **3/10** days 364 (Oren), 378 (Rook), 686 (Sable) |
| exactly one faction left at some point | 9/24 | 6/40 (15%) | 6/10 |
| survivors at end (mean) | ~5 | **7.4** (13+ alive in 12/40 seeds) | 4.2 (11-12 alive in 3/10 seeds at day 700) |
| factions eliminated per match | 9.6 | 6.6 (47% of 560) | 9.8 |
| eliminations by day | first ~day 69 | 5 before day 84, 18 before day 112, then 53 in days 112-140 (all 560 factions) | 6 before day 112 (of 140) |
| longest stretch with no territory change | not logged | mean 36 d, **max 119 d**; 4/40 seeds > 56 d | mean 68 d, **max 245 d (35 weeks)**; 3/10 seeds > 56 d |
| neutral (unowned) holdings at end, non-conquest seeds | n/a | **10.3** of ~40 | **13.9** |
| leader deaths per match | 5.6 | 2.9 (92% at home, 90% by raid party, mean HP before the blow 25%) | 4.3 |
| tick CPU (`Rules.tick(2 s)`) | 0.98 ms | 1.05-1.22 ms alone, **1.50 ms** mean / 2.08 max with 4 parallel jobs | 1.38 (max 1.51) |

So pass 3b (mercy: nobody raids a last roof before the hunt; settlers; ration discipline) made the field far safer (47% eliminated at week 48 vs ~70%+) and almost removed Total Conquest at the design horizon. At 700 days it happens in 30%, i.e. around week 52-98.

## 2. Pass criteria (owner list)
| criterion | A (336 d) | B (700 d) | verdict |
|---|---|---|---|
| no class eliminated in > 75% of matches | max Vex 62% (0 classes > 75%) | Mira, Forge, Rook 80% (3/14 > 75%; n=10 only) | **PASS at 336, FAIL at 700** (small n) |
| per-class mean final land within 0.5x-2x of the mean | 12/14 inside; **Oren 2.09x, Vex 0.30x** out; excluding the conquest seed Oren 1.68x (in), Vex 0.31x out | 9/14 outside (dominated by 3 winners holding 39) | **FAIL (Vex)** |
| per-class win share within 0.5x-2x of fair where wins exist | 1 win total: unmeasurable | 3 wins by 3 classes (1 each = 4.7x fair, n too small) | **cannot be judged** |
| Total Conquest reached in a meaningful fraction | 2.5% | 30% | **FAIL at 336, marginal at 700** |
| no stall > 8 weeks | 4/40 seeds (max 17 weeks) | 3/10 seeds (max 35 weeks) | **FAIL** |
| CPU < 3 ms/tick | 1.05-1.5 ms | 1.4 ms | **PASS** |
Also: exactly one alive by week 24: 1/40 (stretch goal, miss).

## 3. Per class, 40 seeds x 336 days (sorted by final land)
| class | survive | eliminated | mean elim day | final holdings (x mean) | wk24 (x mean) | peak | leader kills | captures | nodes | wins |
|---|---|---|---|---|---|---|---|---|---|---|
| oren | 55% | 45% | 197 | 4.47 (2.09x) | 2.83 (1.12x) | 8.2 | 30 | 14.0 | 12.9 | 1 |
| pip | 68% | 32% | 211 | 3.42 (1.60x) | 3.95 (1.57x) | 6.3 | 6 | 11.7 | 13.6 | 0 |
| nyx | 55% | 45% | 221 | 2.62 (1.23x) | 2.67 | 6.4 | 21 | 10.4 | 12.6 | 0 |
| sable | 55% | 45% | 212 | 2.58 (1.20x) | 2.62 | 5.0 | 1 | 7.1 | 12.2 | 0 |
| mira | 58% | 42% | 245 | 2.48 (1.16x) | 3.45 | 6.6 | 14 | 10.3 | 13.7 | 0 |
| quill | 60% | 40% | 220 | 2.15 (1.01x) | 2.75 | 5.1 | 5 | 7.5 | 13.8 | 0 |
| bram | 52% | 48% | 182 | 1.95 (0.91x) | 2.27 | 5.3 | 10 | 8.5 | 11.9 | 0 |
| tavi | 52% | 48% | 215 | 1.93 (0.90x) | 2.98 | 5.2 | 5 | 8.4 | 13.0 | 0 |
| judd | 50% | 50% | 189 | 1.82 (0.85x) | 1.50 (0.59x) | 4.2 | 4 | 7.7 | 12.7 | 0 |
| rook | 45% | 55% | 204 | 1.77 (0.83x) | 1.43 (0.57x) | 4.1 | 12 | 7.0 | 12.2 | 0 |
| halo | 65% | 35% | 264 | 1.60 (0.75x) | 2.30 | 2.6 | 0 | 0.0 | 13.8 | 0 |
| forge | 42% | 58% | 217 | 1.27 (0.60x) | 2.50 | 5.0 | 6 | 8.5 | 13.2 | 0 |
| dune | 42% | 58% | 218 | 1.23 (0.57x) | 2.73 | 4.6 | 0 | 5.4 | 12.8 | 0 |
| vex | 38% | 62% | 204 | **0.65 (0.30x)** | 1.32 (0.53x) | 3.1 | 0 | 2.6 | 11.5 | 0 |
Mean days alive: all 14 classes 0.91x-1.12x of the mean (survival time is balanced). Per-class table for the 700-day batch is in `docs/sim1/700/report.txt` (n=10; too noisy to rank classes, except Vex/Quill/Halo/Judd ending at 0.3-0.6 holdings).

Verdicts:
- **Oren** (Overseer, Bless): the only class that converts the late game (8/40 seeds largest holder at the end, 30 leader kills, 1 of 1 conquests at 336, 1 of 3 at 700). Mild over-performer: land 2.1x. Watch, do not nerf yet.
- **Sable**: 1 leader kill in 40 matches but 3/10 largest-holder at 700 days and the 700-day conquest. Tracks (11,182 `track` attempts across all leaders, 87% ok) feed it; slow compounding class. Fine.
- **Pip, Nyx, Mira**: healthy (1.2-1.6x land, 32-45% eliminated).
- **Quill, Bram, Tavi, Judd, Rook**: in band, but Rook and Judd are 0.57-0.59x of mean land at week 24 (pass 3 Rook was the dominant converter at 2.4x peak; the pass 3b mercy rule removed its edge).
- **Halo**: 0 captures by design, 35% eliminated, 1.60 land; healthy as a pacifist.
- **Forge, Dune**: 58% eliminated, 0.57-0.60x land, die to raid parties (Dune 15 of 23 eliminations, 17 leader deaths at home, the most killed class). Low leader kills (0-6).
- **Vex: the one outlier.** 62% eliminated (17 of 25 by simply losing the last holding), 0.65 final holdings (0.30x), 2.6 captures, 51 deeds (lowest with Sable), 11.5 skill nodes. Vex's kit (stealth, pickpocket 320 ok, 2805 stealth jobs overall) does not produce land.

## 4. Why people die, and when
- Eliminations (265 of 560): losing the last holding **151 (57%)**, raid party kills on the leader 103 (39%), spores 5, duels 4, sentinel 2. **Famine: 0 collapses** (pass 3: 50 per 24 matches), though 343/560 factions starved for at least one day (11,092 starving faction-days): `subsist` fixed collapse, not hunger.
- Leader deaths (114): 105 at the leader's home, 7 in the open, 2 in foreign holdings; 90 by raid parties, 24 by another leader (marching, duel, spores, sentinel). Mean HP before the killing blow 25%: leaders are worn down, not one-shot (4% had >= 90%). Killer classes: Oren 30, Nyx 21, Mira 14, Rook 12, Bram 10, Pip/Forge 6, Tavi/Quill 5, Judd 4, Sable 1; Halo/Dune/Vex 0.
- Timing (all 560 factions): 18 eliminated before day 112, 87 in days 112-168, then 16/20/29/36/32/27 per 28-day block up to day 336 (160 in days 168-336). The Reckoning (`hunt.late_week` 99 = day 693) never arrives inside the 336-day horizon, and `live_at` 5 is reached in only 17/40 seeds (mean day 244).
- Personas matter more than classes: final holdings turtle 4.39, raider 2.04, trader 1.11, hoarder 1.01; eliminated turtle 37%, raider 42%, hoarder 54%, trader 56%. 3 of 4 conquests (336 + 700 batches) went to turtle personas, 1 to a hoarder. The Latin square keeps class rows fair; it does not make the persona mix fair.

## 5. Snowball vs comeback
Largest holder at the snapshot day is also the largest holder at the end: day 57 7/40 (17.5%; random would be 7%), day 85 11/40, day 169 17/40 (42%), day 253 **30/40 (75%)**. Mean final rank of the week-8 leader 3.8, week-24 leader 1.8, week-36 leader 1.4. So early leads are mostly overturned (comebacks work through week 24), but from about week 36 the order is frozen: the leader survives 38/40 and does not lose land. Marked-faction rotation works (5.5 distinct marked factions per match, 0 permanent marks). Rank curve: R0 5%, R1 26%, R2 25%, R3 22%, R4 15%, R5 8% (healthier than pass 3). Land curve (mean over classes) rises to ~3.0 holdings by day 29-85 and then slowly falls (2.2 at day 253) as the field thins; only the winner class grows (Oren 2.4 -> 4.5 from day 197).

## 6. Stalls and degenerate strategies
1. **Mercy turtle-lock (stall).** `data/ranks.json` `mercy.until_week` 99: a rival on its last roof is never raided before the hunt, and the hunt needs <= 5 survivors (or one faction with 11 holdings / 28%). Seeds 201, 202, 205 (700-day batch) sat at 11-14 alive with 0-1 territory changes per week for 245/133/126 days; in the 336 batch 7 seeds still had 13 survivors at the end and 5 had all 14.
2. **Lone-survivor treadmill.** Six seeds in the 336 batch and six in the 700 batch reached one survivor; only 1 (336) and 3 (700) finished. Survivors hold 10-24 of ~40 holdings with 16-26 unowned and gain about 2 captures/week, while **revolts** (45-86 per survivor over the run; 1106 in batch A, 28/match; 617 in B) hand holdings back to neutral. Seed 207: Sable holds 11-24 holdings for 210 days after becoming sole survivor and never reaches 40.
3. No steal loop: 156 steals in 40 matches (3.9/match). No ability spam: all non-passive abilities succeed 100% (snare 69%, `occupied`; track 87%, `no_targets`); mine/forage/track/bless dominate by count (11k/10k/11k/3.7k) because they are routine economy abilities. Tributes 9,997 (Hoarder/Trader brokers) are the bulk of deeds.
4. **Bots do not do quests or POIs at all** (no `Quests.`/`Pois.` call in `rules/ai_*.gd`); quest/POI participation in this sim is therefore 0 by construction and says nothing about those systems. Purge participation by persona (parties/faction over 336 d): turtle 74, hoarder 61, raider 60, trader 46; captures: turtle 11.9, raider 8.7, trader 5.4, hoarder 5.2. Raiders launching fewer parties than turtles is an inversion (cause not isolated: possibly mercy filtering their targets); worth a look in the persona table.
5. Skill trees: 257/560 finished (median week 32), 12.8 of 15 nodes; branches evenly used (e 2320, h 2421, p 2448), all 210 nodes bought at least once. Rank-0 idle bleed: none.

## 7. Variant test (what a fix does, 12 seeds, 336 days; same seeds as baseline)
| | baseline (101-112) | **A** mercy.until_week 99->24, hunt.late_week 99->40, hunt.live_at 5->7 | **B** = A + stability.revolt_chance 0.2->0.1, per_extra_holding 2->1 |
|---|---|---|---|
| Total Conquest | 1 | 0 | **2** (Rook, Nyx) |
| mean survivors at end | 7.8 | 3.2 | 3.5 |
| eliminated per match | 6.2 | 10.8 | 10.5 |
| seeds with a stall > 56 d / max | 3 / 119 d | 3 / 84 d | 2 / 63 d |
| unowned holdings at end (non-conquest) | 7.6 | 15.3 | 13.8 |
| one survivor ever | 2 | 2 | 2 |
Reading: A and B converge the field (survivors 7.8 -> 3.3) and shorten stalls, but turn the problem into the bottleneck of section 6.2: with fewer rivals the map is **more** unowned (15 holdings), and conquest needs the survivors to re-own it. B's lower revolt rate gives 2 conquests in 12 (small n, not significant) and no class collapse. Neither is shipped; they were measured only through the harness override. Not tested: the changes below that need code.

## 8. Research (short, decision-focused)
- **Forced convergence**: battle royale games solve "last survivor" with a shrinking, ever-more-damaging zone that forces contact and prevents camping ([Wikipedia: Battle royale game](https://en.wikipedia.org/wiki/Battle_royale_game); PUBG/Apex zone notes, e.g. [Apex Legends wiki: Ring](https://apexlegends.wiki.gg/wiki/Ring) and [PUBG zone damage](https://mein-mmo.de/en/pubg-todeszone-testserver,201912/)). Our analogue is the Reckoning at `late_week`; at week 99 it is too late and arrives as a switch, not a ramp. Use a ramp (mercy decays with week), not a cliff.
- **Anti-snowball / comeback in 4X**: diminishing returns and non-linear power curves are the natural brakes, catch-up mechanics help but a late leader is hard to stop, and fame-only/score-only wins make war pointless and passive ([Wayward Strategy: anti-snowball design](https://waywardstrategy.com/2020/07/06/anti-snowball-design/), [PCGamesN: strategy game endgame design](https://pcgamesn.com/civilization-vi/strategy-game-endgame-design), [Humankind forum: fame as sole win condition](https://community.amplitude-studios.com/amplitude-studios/humankind/forums/169-game-design/threads/38484-fame-as-the-sole-win-condition-is-too-snowbally), [Kaj Sotala: 4X end-game](https://kajsotala.fi/2017/04/fixing-the-4x-end-game-boringness-by-simulating-legibility/)). Our week-8 and week-24 leaders mostly lose their lead (comeback works); the freeze after week 36 is the gap, so fix it with forced contact, not with more brakes.
- **Win-rate bands**: Games Workshop's Age of Sigmar / 40K teams target 45-55% per faction as "balanced" and warn against tuning many things at once ([Warhammer Community: Metawatch](https://www.warhammer-community.com/2022/09/29/metawatch-how-the-warhammer-age-of-sigmar-team-uses-tournament-data-to-balance-the-game/)); a Goonhammer simulation shows a 5-point gap doubles a faction's odds in a large field ([Goonhammer: hammer of math](https://www.goonhammer.com/hammer-of-math-impact-of-win-percentage)). In a 14-way free-for-all fair is 7%, so the 0.5x-2x band means 3.5-14%: it needs about 14 x 14 = 200 conquests to see (we saw 4). Judge classes on land and survival until conquest is common; use win share only after.
- **Bots versus humans**: not found in the search; stated from design practice, see section 10.

## 9. Ranked findings and proposed changes
1. **Convergence stalls and the late freeze (fail: stall, conquest, survivors).** Cause: `mercy.until_week` 99 plus hunt `live_at` 5. Change in `data/ranks.json`: `mercy.until_week` 99 -> 24, and make mercy decay (`last_roof` 0.0 -> 0.35 at week 24, 0.7 at week 36) instead of a cliff; `hunt.late_week` 99 -> 40, `hunt.live_at` 5 -> 7 (variant A cut survivors 7.8 -> 3.2). Expect elimination of Dune/Forge/Vex to rise (they are the raid-party victims), so ship together with finding 4.
2. **Lone-survivor treadmill (revolts).** `data/ranks.json` `stability.revolt_chance` 0.2 -> 0.1 and `per_extra_holding` 2 -> 1 (variant B: 2/12 conquests, revolts per match fell 37 -> 28 despite more land); better, in `rules/standing.gd` (revolt roll at ~line 564) skip the revolt roll and auto-pacify while `AIFactions.hunting` or only one rival lives. Also let a hunter keep the captured holding's garrison (`rules/conquest.gd`, line ~144) instead of leaving it at the 1-2 raid survivors that revolt next week.
3. **Neutral pool (10-14 unowned at end).** The source was not isolated by the logs (candidates: revolts 28/match, holdings of factions with no AI heir per `rules/combat.gd` `_heir_of`, initial merchant villages). Log `holding_revolted`/elimination-to-neutral counts in the harness next, then give a faction with `conqueror()` true a `neutral_only` mission at unlimited range (today `rules/ai_factions.gd` `_try` limits it to intel and `RANGE + 2*min(week,8)`).
4. **Vex is under the band (0.30x land, 62% eliminated).** `data/ai_kits.json` Vex: stealth steal jobs should end in capture of the weakest neutral/lightly held holding (pickpocket works, 320/320); add a Vex `mods` land bonus (e.g. +1 free holding upkeep) or a settler-style grant like the one pass 3b gave other classes (check `data/classes.json` mods before copying). Rook/Judd (0.57-0.59x at week 24) need only the `mercy` rebalance in finding 1 (their strength was hunting weak neighbours).
5. **Persona imbalance (turtle 4.4 land / 37% eliminated vs hoarder 1.0 / 54%).** `rules/ai_factions.gd` persona table: give hoarder and trader a pacify/garrison routine (pass-2 finding 4, still open) and let raiders target neutral holdings first; broker (tribute) deeds are 9,997 of the ~39,000 deeds and let hoarder/trader rank without land.
6. **Starvation without collapse.** 343/560 factions starved at least once (11,092 days): keep `subsist.per_holding` 3 but add a ration alert in the AI governor to avoid the stability penalty (`stability.hunger_per_day` 12) so revolts do not feed finding 2.
7. **Harness/instrument gaps for pass 6**: bots never do quests/POIs (add an AI quest routine or a "quest bot" sim mode before judging quest rewards); Purge participation is not logged per Purge; `event` counters were not recorded.

## 10. What this cannot tell us
- Bots are not people. Humans would exploit the mercy lock (turtle up), negotiate, ignore ration discipline, and hunt a leader on sight; real matches would likely converge faster or very differently. Nothing here says the game is fun, that classes feel fair, or that the 10-hour real-time pace works.
- Only the AI path was exercised: quests, POIs, building tiers, the HUD and the player's Purge actions (stealth, duels) are untested. The harness replaces the player with a bot faction.
- 40 seeds give about +-8 points on a 50% rate and one conquest: class win shares are not measurable yet (1 win at 336 d, 3 at 700 d). The 700-day class table is n=10. The variant test is n=12, one pair of settings, no significance.
- Persona-by-class interactions are confounded (Latin square balances rows, not combinations); CPU was measured under 4-way parallel load (1.5 ms vs 1.1 ms alone).
- The 84x54 map with ~40 holdings and 14 starting factions is a harness invention; the shipped game's player counts and map will differ.

## 11. Reproduce
`git worktree add /tmp/claude-0/simtree HEAD` then `godot --headless --path . --import`, and per seed: `godot --headless --path . -s tools/sim_match.gd -- --seed=101 --days=336 --out=docs/sim1/336/s101.json`; variants: `--over=docs/sim1/varA.json`. Aggregate with `python3 tools/sim_report.py <dir>`, `python3 tools/sim_extra.py <dir>`, `python3 tools/sim_variant.py <dir...>`. Harness changes this pass: `tools/sim_extra.py`, `tools/sim_variant.py` (new analysis); `tools/sim_match.gd` unchanged in behaviour.
