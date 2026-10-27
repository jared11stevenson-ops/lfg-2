# Rules notes, pass 2 (for the lead: what exists, exactly what to wire)
Everything below lives in `rules/`, `data/`, `ui/standing_*.gd`, `ui/skill_tree_*.gd`, `tools/sim_*`. Nothing in `main/` or `world/` was touched.

## 1. Win and score
- **Total Conquest is the only win.** `Economy.check_victory` fires `victory{kind:"total_conquest", faction:int, player:bool, holdings, day, faction_name}` once, when exactly one faction is alive AND it owns every holding. `state.won == "total_conquest"`; the match does not end (Endless is the player's choice). Dominion (60%) and Crowned (12 weeks) are gone (`Calendar.CROWNED_WEEKS`, `Economy.DOMINION_FRACTION` removed).
- `MetaHooks`: title `lfg:title/total_conquest`, granted only when `player == true`. `lfg:title/dominion|crowned` no longer exist.
- **TODO for you:** `ui/game_end_screen.gd` still has `"dominion"`/`"crowned"` strings and `tools/art_capture_pass1.gd` calls `show_victory({"kind":"dominion"})`; switch both to `total_conquest` (info keys: `day`, `class_label`, `holdings`, `total_holdings`, plus `Standing.hud_model` prosperity for the end screen).
- **A leader's death eliminates ANY faction** (`Combat.kill`): player faction = `match_over` (permadeath, as before); AI/bot faction = `faction_eliminated`, its holdings become neutral, the garrison routs (`garrison/3`) and its walls and towers fall. `faction_eliminated` also runs `check_victory`.
- **Prosperity** (non-ending thriving score): `state.factions[fid]["prosperity"] = {score, output, reserves, holdings, ration_days, thriving}`, recomputed each dawn; `Standing.prosperity(state, fid)` computes it live. Output accrues from harvests, production buildings and AI farming (`Standing.note_output`).
- An AI faction that starves for 28 days collapses (`famine_collapse`, its leader perishes). The player keeps the old Starved Out rule.

## 2. Standing, ranks, deeds (data/ranks.json, rules/standing.gd)
- Standing = holdings by tier + capped ration reserve + **Purge deeds** that decay linearly over 21 days. Thresholds `[0,6,14,26,42,64]` scale by `sqrt(14 / live factions)` clamped to 0.8-2.5. Recomputed at every dawn (`Standing.recompute`), also exposes `Standing.score/threshold/rank_for_score`.
- Rank effects are production/access/logistics only (growth %, harvest yield steps, plot slots, carry cap for capped classes, garrison cap, supply range, merchant price %). No combat stat reads rank (a test asserts it).
- Access gates: crops (`rank` in crops.json: saltroot R1, glowfruit_prime R3, moonbean R4, purgebloom R4, crownwheat R5), recipes (`rank`), buildings (`rank`: barracks/granary/wall_stone R1, watchtower/cookhouse/steam sawmill/shrine R2, beacon/greenhouse/forge R3). Commands answer `rank_required`.
- **Thin crown:** rations under 3 days or any holding with stability < 40 -> `eff_rank = rank - 1` for buffs (access still uses `rank`).
- **The Mark:** the top-standing faction with rank >= 2 (`state.sim_acc["mark"]`, -1 = none). Striking the Marked (kill leader, capture, steal, ...) multiplies the deed's standing and skill points by 1.5; AI target score x1.35; waves also spawn at a human Mark; an AI Mark loses garrison at Purge start (`mark_pressure`).
- **Deeds** are derived from the event stream by `Standing.observe` (called by `Rules.tick` per step and by `Rules.apply`) and only count in PURGE_ACTIVE, with per-Purge caps (data). Kinds: `kill_leader capture kill_raider ransom steal defend sabotage kill_wild heal broker scout escort`. Every deed pays skill points to the faction leader.
- **Anti-snowball:** `dawn_upkeep` charges coin upkeep growing as `n^1.4/3.5` beyond 2 holdings (tax income `tier` coin/holding/day), per-holding stability (distance from the capital, extra holdings, hunger, unpaid upkeep), revolt at stability <= 12 (never the capital), unstable holdings produce less, and an **idle bleed** drains single-holding factions with no deed for 14 days. Peacetime spoilage grows with the week (granary halves it).
- **Purge Levy** after RESOLUTION starts (`Sim.settle` -> `Standing.charge_levy`): per holding rations+coin by tier, growing 12%/week (cap x1.6), cut by fighting deeds (up to 80%), a Shrine (25%) and tree nodes. Unpaid: stability -12 on every holding and a garrison deserts. `Standing.levy_due(state, fid)` previews it.

## 3. Purge pressure and ways in
- **Purgebloom** (`purge_only` crop, rank 4): plant >= 2 hexes from the holding; it never grows in peace and never withers; `water` it during PURGE_ACTIVE to tend it (`tended`); each tended Purge (at `Sim.settle` -> `Farming.purge_growth`) grows one stage; ripe after 2. **Ashmarrow** drops from wave beasts and raider parties and feeds the rank-4/5 seed and ration recipes.
- Escalation: wave size `2 + week` (cap 14) around the player and the Mark; AI dispatch slots, party size and party count grow with the weeks (`AIFactions.max_dispatch/party_cap/max_parties`).
- Scarcity: AI production `x(1 - 2%/week)` (floor 0.5), harvest yield loses steps from week 3 on, spoilage.
- New ordinary commands (all Purge-only, none needs another player; pacifist-legal except sabotage):
  - `scout {holding}` within 3 hexes of a rival holding, once per holding per Purge -> `scouted`.
  - `escort {holding, qty>=3}` stand at an own holding >= 5 hexes from the capital -> rations move into its store -> `escorted`.
  - `truce {faction}` (WARNING or PURGE_ACTIVE) within 3 hexes of that AI faction's holding; pays 15 coin into its store; mutual truce 45 s x tscale -> `truce_signed`. Quill's ability also writes `factions[x].truces`.
  - `ransom {target}` adjacent enemy leader at <= 40% HP: up to 30 coin moves to you, 45 s mutual truce, once per victim per week -> `ransomed`.
  - `sabotage {holding}` adjacent rival: steal-chance roll, burns up to 5 rations (destroyed) -> `sabotaged` / `sabotage_failed`.
  - `unlock_skill {node}`: see 4. There is **no respec**: `respec` is an unknown command.
- Errors you may see: `rank_required needs_outdoors purge_only already_scouted no_rival not_outlying already_escorted already_truced not_beaten already_ransomed nothing_to_burn node_locked not_enough_points already_taken unknown_node`.

## 4. Skill trees (data/skill_trees.json, rules/skills.gd)
- 14 trees x 15 nodes, branches `economy / purge / hybrid`, each branch has a cost-1 root; `h3` needs an economy and a purge node; 2-3 costed drawback nodes per tree (cost >= 3, a real penalty). Effects are small deltas with per-key caps (`caps` in the file); max_hp/atk/def/max_energy apply once at unlock, the rest live in `actor["skill_fx"]` and reach the rules through `Combat.class_mod` (so `yield_bonus`, `steal_bonus`, `build_cost_mult`, ... just work) and `Skills.tune_ability` (cooldown, energy, duration, power).
- **Points come only from Purge deeds** (`Skills.grant`, refuses outside PURGE_ACTIVE). Actor fields: `sp` (unspent), `sp_total`, `nodes` (taken ids), `skill_fx`. AI/bot leaders spend at once (`auto_buy`, branch order by persona).

## 5. Class-aware AI (data/ai_kits.json, rules/ai_leaders.gd, rules/ai_factions.gd)
- `Setup.build` deals the 13 non-player classes to the 12 AI leaders (seeded; opt `ai_classes:false` keeps them classless). Leaders have real class stats (`Setup.set_leader_class`).
- Dawn: peace routines through the real abilities (mine, forage, bless; abstract tonic/gadgets/hunt/trade/yield/grove/ration bonuses). Purge start: non-raider personas and diplomats pay tribute for a truce (`truce_signed`); Dune stashes a real cache.
- Raids/defence: brawler/warlord/skirmisher/thief classes march with capture/steal parties, hostile parties harass any hostile leader next to them, leaders trade blows and cast their kit with real arguments (`AILeaders.siege_cast`: rage, plague cloud, dash with target and free hex, pickpocket target, ram holding, swarm at foe, ...). Brittle leaders (effective HP < 70) stay home. Leaders within 6 hexes reinforce a besieged holding (`defend_call`/`recall`). Pacifist classes never raid. Passive personas run `scout` and `supply` parties that earn deeds; late-game/fat-garrison factions turn ambitious.
- Bounded CPU: nothing here runs per tick except sieges; measured in `tests/rules/test_ai_classes.gd` and the sim report.

## 6. State fields added (all saved; old saves are repaired by `Standing.ensure`)
- `factions[fid]`: `rank eff_rank thin standing deeds[{k,w,deed_t}] dcount{} pcap{} scouted[] escorted[] last_deed truces{fid:until} prosperity{} out_day out_ema spoils tribute_week ransomed_week upkeep_unpaid`.
- `holdings[id]`: `stab` (0-100). Buildings may carry `rank`, `levy_cut`, `yield_bonus`. Plots: `gx` (growth carry), `tended`.
- `actors[id]`: `rank eff_rank sp sp_total nodes skill_fx`; leaders: `ai.party ai.defending ai.from_hex ai.cache_hex`; parties: `ai.leader ai.strike`, missions `capture steal scout supply`.
- `state.sim_acc`: `mark`, `ablog` (only with `opts.ai_log`).
- `FLOAT_KEYS` gained `deed_t last_deed gx out_ema standing ration_days`; `FLOAT_VALUE_DICTS` gained `truces`.

## 7. Events to handle in the HUD/log
`deed{faction,kind,label,standing,sp,victim,marked,actor,ai}` `skill_points{actor,faction,gained,points,kind}` `skill_unlocked{actor,node,name,branch}` `rank_changed{faction,from,to,name}` `mark_changed{from,faction}` `levy_paid{faction,rations,coin,unpaid_rations,unpaid_coin,reduction}` `upkeep_paid{faction,cost,unpaid}` `idle_bleed` `holding_revolted{holding,faction}` `mark_pressure` `famine_collapse` `scouted` `escorted` `ransomed` `sabotaged` `sabotage_failed` `truce_signed{actor,faction,by,holding,until}` `faction_eliminated` `victory{kind:"total_conquest"}`. Filter by `faction == 0` (or `!ai`) for the player's toasts.

## 8. Wiring checklist
1. HUD strip: `var m := Standing.hud_model(Game.state, 0)` once per dawn and after any `deed`/`rank_changed` event. Fields: `rank rank_name eff_rank thin_crown standing next_threshold to_next next_unlock prosperity{score,thriving,...} levy{rations,coin,reduction} days_to_purge marked{faction,name,is_you} skill_points nodes_taken recent_deeds[] upkeep_coin live_factions holdings total_holdings`.
2. `StandingPanel` (`ui/standing_panel.gd`): `set_model(Standing.hud_model(state, 0))`; connect `skill_tree_requested` to open the tree panel; add it to `UiPanels` like `HoldingPanel`.
3. `SkillTreePanel` (`ui/skill_tree_panel.gd`): `set_model(Skills.panel_model(state.player()))`; connect `unlock_requested(node_id)` to `session.command("unlock_skill", {"node": node_id})`, then `set_model` again from the result.
4. Buttons for `scout`, `escort`, `truce`, `ransom`, `sabotage` (targets as above). The `class_ability` bar is unchanged.
5. Show the Mark and the levy in the WARNING banner ("what the next rank unlocks, the levy due, the Marked faction" from INCENTIVES.md); all three are in `hud_model`.
6. World models: `lfg:building/shrine`, `greenhouse`, `forge` carry `"model_pending": true` and use the fallback hut until `world/` ships meshes (`tests/world/test_world_layers.gd` skips them while the flag is set; delete the flag with the mesh).
7. Net: `Rules.COMMAND_TYPES` gained the six commands above, nothing else changed in the protocol. Snapshots expose other factions' `deeds/standing/prosperity` unfiltered (public information by design).

## 9. Test and sim helpers
`Standing.set_rank(state, fid, r)` pins a rank for tests. `Setup.build(..., {ai_classes:false})`, `{ai_log:true}` for the harness. `tools/sim_match.gd` (Grand Simulation harness), `tools/sim_report.py <dir>` (aggregation). New suites: `tests/rules/test_standing.gd`, `test_purge_pressure.gd`, `test_skills.gd`, `test_ai_classes.gd`, `tests/world/test_standing_panels.gd`.

## 10. Known gaps
No quest engine, POIs or companion content (passes 3-4). Capture of a leader is the `ransom` command only; there is no prisoner state. The AI does not use trade routes between factions. Presentation of AI leaders marching with parties is by position only (no `actor_moved` events for them). Sim numbers: docs/SIM_REPORT_pass2.md.
