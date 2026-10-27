# Grand Simulation #0 (baseline, before pass 2)
Harness: `tools/sim_match.gd` (real Rules module; all 14 classes as competing faction leaders in one 84x54 world, shuffled over slots by seed;
a 14th faction is placed on the most remote neutral holding; every leader may use its class ability via ordinary `use_ability` commands during the Purge).
Aggregation: `tools/sim_report.py docs/sim`. Raw results: `docs/sim/s1..s20.json`.
Run: 20 seeds x 336 in-world days (48 weeks), ~3m20s wall on 4 cores. Bots, not humans: this measures balance and stalls, not fun.

## Headline: the match never ends
- 20/20 matches ended with all 14 factions alive. **0 eliminations, 0 winners** in 960 faction-matches over 48 weeks.
- Territory freezes early: last holding change at day 36–71 (avg 52, i.e. by week 8). Weeks 9–48 are completely static.

## Why (measured)
| persona | factions | captures/faction | avg final holdings |
|---|---|---|---|
| raider | 76 | 4.59 | 5.26 |
| hoarder | 69 | 0.00 | 1.00 |
| trader | 63 | 0.00 | 1.00 |
| turtle | 72 | 0.00 | 1.00 |
- **Persona decides everything; class decides nothing.** Only raiders ever capture. Class-to-outcome ranking (tavi 3.2 … quill 1.45 average final holdings, n=20 each) is explained by which persona the slot happened to get, not by the class kit (AI factions are class-agnostic: only starting stats/kit differ).
- Leaders essentially never fight: 24 leader kills total. AI leaders stay home.
- **Ability usage by the bot was 0 for pip, forge, vex, dune, oren and ~0 for mira**: these abilities need targets/arguments the generic bot does not supply, so their per-class numbers are NOT evidence of weakness. Also: the player-facing balance cannot be inferred from this run.
- Raiders stop once nearby weak targets are gone (no escalation, no attrition, no pressure on 1-holding factions), so a stalemate forms.

## Findings → pass-2 build list (priority order)
1. **Convergence mechanics** so a match can end with one left standing: Purge escalation (each week's Purge is larger/wider; raiders gain strength from stolen stock), a shrinking-safe-zone-style "Blight Tide" that taxes outlying holdings, and upkeep that bleeds passive 1-holding factions so turtles/traders cannot idle forever. Design reference points: battle-royale contraction and 4X snowball/anti-snowball tension (decline pressure on passives, instability cost on large empires).
2. **Class-aware faction AI**: every faction leader acts through its class kit (target selection, ability args, peace perks used for economy) so the 14 classes differ in outcomes. Persona should bias behaviour, not replace class identity.
3. **Leader vulnerability & elimination path**: leaders join raids/defence; defeat of a leader eliminates a faction even if a holding remains (permadeath for every competitor, as for the player).
4. **Non-raider relevance**: hoarders/traders/turtles need real win routes (economic dominion share, alliance, trade-for-protection) rather than 0 captures forever.
5. **Sim instrumentation**: log per-ability attempts/failure reasons, kill causes, and food/hunger deaths; re-run next Grand Simulation at pass 5.
Success criterion for the next sim: >=80% of seeds end with exactly one faction alive by week 24, and no class wins >2x or <0.5x the fair share (1/14) over >=40 seeds.
