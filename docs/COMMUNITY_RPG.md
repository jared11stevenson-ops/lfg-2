# Peace as a community RPG; the Purge as a moral choice (design spec, owner direction 2026-10-27)

## Tone
PEACE is warm, busy and social: a giant community RPG. The PURGE is scary, unwanted and arguably unnecessary, but the rewards (see INCENTIVES.md) are large enough that almost everyone is tempted. Personal tension is the point: the gentlest player might kill once for an edge; the fiercest player might refuse to hurt a friend.

## Bonds and the moral cost
- Bonds (NPC and, online, player): built in PEACE through shared quests, gifts, trades, co-builds. A Bond has a level; levels unlock concrete perks (shared storage, joint defence, trade discounts, a signature favour).
- Harming a Bond during the Purge pays the most deed points but costs trust: lose Bond perks, a reputation tag visible to others ("Oathbreaker"), possible revenge quest from their allies, merchants raise prices.
- **Spare / ransom / truce**: defeat without killing (capture, ransom, truce terms) for lower payout. A real middle path for the reluctant, a flexible tool for the ruthless.
- Both tensions must be playable and tested: pacifist route to points, ruthless route, spare route all viable; none strictly dominant.

## Class quest lines (14, original)
- ~6–8 steps each, each ending in a signature unlock (a recipe, an ability upgrade, a building).
- **Converging quests:** at fixed steps 2–3 class lines need each other (farmer needs miner ore, cook needs farmer and forager; online they link real players, solo they link AI Bonded NPCs of those classes).
- Data in data/quests/*.json, validated by tests (no unreachable step, every item obtainable, ids namespaced).

## Points of interest
Ruins, fungal caves, wrecks, shrines, derelict farms, sunken stairs, a travelling merchant, hermit NPCs: each with a distinct reward, a puzzle or fight, and a reason to return (respawning-by-week, not hourly). Placed by worldgen per biome; fog-of-war discovery rewards.

## Resource tiers and buildables (inspired by tech-tier survival/crafting games; all names, assets and recipes original)
- Tiers: T1 common (timber, stone, glowfruit), T2 regional (saltroot, bog iron, reed fibre), T3 rare/dangerous (ruin glass, spore silk, kiln clay from POIs), T4 Purge-only (ashmarrow, purgebloom).
- Stations unlock tiers (workbench → kiln → loom → spore forge → rift anvil), each needing a rarer input.
- New buildables (examples): beacon tower (vision + Purge warning range), spore greenhouse (extra crop yield, rank-gated), brew vat (potions), fortified gate, signal post (truce/ally signals), cistern, kennel/stable for companion creatures, trophy hall (Standing).
- Companion creatures (original designs): tamed/fostered small fungal creatures that help in PEACE (carry, tend) and add a small Purge role.
- Boss-gated progression: each region has a guardian whose drop gates the next tier.

## Pass plan (single agent per pass; lead integrates)
- Pass 2: Total Conquest win, convergence/escalation, Standing/ranks, class-aware AI, Purge deeds, skill-tree data+rules.
- Pass 3: Bonds + moral costs + spare/ransom; class quest engine + first 6 questlines; POI generation and 5 POI types.
- Pass 4: resource tiers, stations, 12+ buildables, companions, remaining questlines, region guardians; playtest-driven fixes.
- Pass 5: Grand Simulation #1 (all 14 classes) + study + findings-driven build.
