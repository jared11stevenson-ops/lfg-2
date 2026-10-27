# Incentives: why take risks, why the Purge compels everyone (design spec for pass 2)

## Principle
Standing is earned by **risk**, and standing pays in **production and access**. Small and safe is viable, never optimal. The Purge always offers every playstyle a way to participate and a cost for abstaining.

## Standing (per faction, recomputed each dawn, shown in HUD)
Score = holdings owned (weighted by tier) + rations in reserve (capped per tier) + Purge deeds (kills of leaders/raiders, successful steals, defended raids, captures, sabotage) with decay (deeds count ~3 weeks, then fade) so past glory must be renewed.
Standing Rank 0–5 (Settler, Steader, Holder, Baron, Warlord-class naming per theme, Sovereign). Thresholds scale with the number of live factions.

## What rank gives (all data-driven, in data/ranks.json)
- **Production:** +5% crop growth speed and +1 yield bonus steps per rank (cap), more plot slots, upgraded building tiers.
- **Access:** rank-gated crops and recipes (R1 Saltroot, R2 Sporebean variants, R3 Glowfruit Prime, R4 Moonbean/Purgebloom, R5 Crown seeds), advanced buildings (granary, watchtower, forge, shrine), merchant tiers and better trade prices.
- **Logistics:** larger carry capacity, longer supply range for troops, more garrison cap.
- **Deliberately NOT: raw combat power**, so ranks never hard-snowball a fight.

## Anti-snowball (empires must stay breakable)
- Upkeep scales with holdings (rations + coin per holding per week), stability falls with distance from capital and with unfed garrisons; unstable holdings produce less and can revolt.
- Rank buffs shrink if rations reserve falls below thresholds ("thin crown") or a holding is unstable.
- Highest-standing faction gets a visible **Mark**: raiders and the Purge target it (bounty: stealing from or striking the Marked pays bonus spoils).

## Purge participation (the Purge must pull in pacifists too)
1. **Purge-only crops/materials**: Purgebloom (grows and ripens only during PURGE_ACTIVE, needs tending outdoors) and Ashmarrow drops from raiders; both feed rank-gated recipes and top-tier buffs. Skipping the Purge = permanently capped crop access.
2. **Weekly Purge toll**: after each resolution every holding pays a Purge Levy in rations/coin scaled by its tier; factions with surplus defence deeds pay less (so defending and fighting both reduce the toll).
3. **Scarcity drift**: peacetime rations/materials trend scarcer each week (spoilage, upkeep); the cheapest sources are Purge spoils and stealing.
4. **Many valid ways to participate** (each earns deeds): defend (kill raiders/enemies at your holdings), steal (Vex-style, risk roll), kill (leaders, raiders, wild elites), capture, scout/mark targets, sabotage wells/stores, smuggle/tribute and truce brokering (Quill), field-heal/ration allies (Oren), escort supply (Pip). A pure pacifist still earns deeds by defending, healing, brokering and scouting; abstaining earns zero and pays the levy.
5. **Risk/reward legible in UI:** before each Purge show your Standing, what the next rank unlocks, the levy due, and the Marked faction.

## Total Conquest remains the only win; Prosperity (thriving) is the non-ending score.

## Testing (Grand Simulation hooks)
- Per-class deed counts, rank curves over time, share of factions at each rank, share that participate in the Purge, fraction of pacifist-persona factions that still earn deeds.
- Fail the sim if: any persona sits at Rank 0 for >8 weeks with 0 deeds and no penalty, or the top rank holder is never challenged.

## Class skill trees (owner suggestion, adopted with changes)
- 14 original trees (~15 nodes, 3 branches: Economy / Purge / Hybrid-utility) in data/skill_trees.json. Reset each match (permadeath); only cosmetic unlocks persist.
- **Skill points come only from Purge deeds** (kill > capture > steal > defend > heal/broker/scout/escort), weighted: leaders and the Marked count more than wild enemies. Nothing earns points in PEACE, so no tree progress without engaging the Purge, yet pacifist deeds still count.
- Economy-branch nodes (yield, plot slots, recipes) are also Purge-gated: a pure farmer hits a ceiling.
- Nodes mostly add options and tradeoffs; each tree has costed drawback nodes; flat stat nodes are small and capped, so a fight is never decided by tree alone.
- Interaction with Standing: points are per-leader power-of-choice; Standing is per-faction access/production. Both feed from deeds.
- Tests: no node reachable without points; points only granted via deed events (never in PEACE); each tree has >=1 viable pacifist-deed route; Grand Simulation tracks nodes taken per class and win/survival by build.
