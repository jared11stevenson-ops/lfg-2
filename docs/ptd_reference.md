# Pokemon Tower Defense: reference notes (mechanics study, not a copy)

Sources: community walkthroughs (ptd-walkthrough.weebly.com, rewatchingpokemonblog.wordpress.com, a 2012 walkthrough blog) and wiki search snippets.
The fan wiki itself refused automated access (HTTP 402). **Numbers marked UNKNOWN were not found; do not treat them as facts.**

## Verified from sources
- **Level order (early):** Oak's Lab, Route 1, Route 2, Viridian Forest 1, Pewter Gym (a challenge level), Route 3 (training), then Viridian Forest 2, Mt. Moon, Cerulean Gym...
- **Oak's Lab (level 1):** very easy. Only Rattata is catchable. Six placement squares. A bar flashes when a Pokemon levels up. You do not need a full team. Catch rule: an enemy's HP bar is green while catchable; lower it, then drag a Poke Ball onto it.
- **Route 1 (level 2):** only Rattata and Pidgey appear. **12 placement spots** (vs 4 close ones in level 1), at least 3 Pokemon recommended. Wave 6 is the boss: a Pidgey controlled by Team Rocket with more HP and a **blue life bar = can never be caught**. Beating it triggers a cutscene that frees a companion (Joey). Early waves are easy enough to "bunch together".
- **Lives are "candies":** about 5 per level; an enemy that reaches the end takes one at a time.
- **XP:** shared among all attackers; same-type attacks get 1.5x; starters should be levelled first. Shiny Pokemon appear with a pop-up, give extra XP (sources say 1.5x to 2x) and are catchable in the same way.
- **Catch tip:** space towers with an open spot between them so wild Pokemon can be caught without overkill; remove towers when a shiny shows up so it isn't killed.
- **Pewter Gym (challenge):** you start with 5 fixed level-6 Pokemon, defend one Poke Ball from 4 Onix; reward is a shiny Geodude. No catching.
- **Economy:** money is tight early; about $5 per kill on weak enemies; TM/move purchases are expensive (about $10,000).

## UNKNOWN (not found)
Energy cost per placement, starting energy, income, exact wave lists with levels, catch success formula, potions, speed controls, evolution and move levels.

## What makes PTD level 1 work (design takeaways)
1. **Tiny and forgiving:** one catchable species, one lesson per level, almost impossible to lose.
2. **Level 2 widens the board** (12 spots) and introduces a *story boss*, a visible "can't catch this" signal (blue bar) and a payoff cutscene.
3. **Catching is a reward loop**, not a menu: weak enemy, ball, new team member.
4. **Shinies** are the surprise: rare, flashy, worth more.
5. **Level-up flash** gives constant small rewards.

## How Wellfall compares (after this pass)
| PTD | Wellfall |
|---|---|
| Catch with unlimited Poke Balls after lowering HP | Lures (3 + 1 per wave), tap a weak enemy ring |
| Blue HP bar = uncatchable boss | Boss bar now blue, same rule |
| Shiny pop-up, extra XP | Shiny variants: gold tint, 3x coins, double XP on capture |
| XP shared among attackers | XP banked per placed creature each wave, +win bonus |
| Candies (about 5 lives) | 20 lives (kept; each leak costs 1) |
| Level-up bar flashes | Result screen lists level-ups (in-battle flash still to do) |
