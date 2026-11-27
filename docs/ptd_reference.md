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

## Observed by actually playing PTD1 (Android build v3.6.6, run in Ruffle) - 2026-11-27
How it was run: the APK is an Adobe AIR wrapper (PTD1.swf, 129 KB) that downloads the real game (13.6 MB SWF, AS3, 800x480) from ptd.onl and caches it. In headless Chromium I ran the wrapper in Ruffle (0.9 nightly) and served the two ptd.onl requests (game SWF, version check `version=1`) from local files. Account creation/login worked with a throwaway email/password; profile saving worked.

Flow: Start -> account (email + password) -> 3 profile slots -> Oak intro (pick Bulbasaur/Charmander/Squirtle, pick Red/Blue) -> main menu (Story Mode, Challenge Mode, Multiplayer, PokeMart, PokeCenter, Pokedex, Mystery Gift, Wiki, Save) -> Story Mode -> Chapters (1 to 7 + Epilogue; Chapter 1 = Oak's Lab, Route 1, Route 2, Viridian Forest 1, Pewter Gym) -> **Team screen** -> battle.
- **Team screen**: six team slots; the new starter is a Lvl 5 in "Storage"; drag from storage to a slot; tap a Pokemon to level up / change moves / release; Level, Number, Name sort buttons.
- **Battle (Oak's Lab)**: 5 waves; start money 50 (shown as P50); six party cards with HP and EXP bars, plus six "Empty / Capture Pokemon" cards; speed x1-x4 and zoom 100/75/50/25 controls; a Pokeball button (catching) and a "x6" count (6 balls/candies shown near the pile); a pile of blue candies at the right = what you protect.
- **Placement**: only on **four fixed orange squares** along the bottom of the room (the whole map is one room 625 px wide). Dropping anywhere else shows a red X. The card dims when placed. Placement is a drag-and-drop of the party card, not a tap.
- **Enemies**: Rattata only, walking one lane left to right along the row above the spots toward the candies; each leaker grabs a candy and carries it back out. Waves start automatically (about 5 s apart on x1), no "Start wave" button. All 5 waves arrived within about 30 s of real time at x1.
- **A single level-5 Charmander on one spot was enough**; Ember hits at range with a small fire effect on the target.
- **Scripted finale**: after wave 5, Gary Oak appears with a Blastoise and says "tackle attack", the cutscene clears the remaining Rattatas, then the level ends (the win is scripted, not earned by kills).
- **Result**: Route 1 unlocked.
- **Dialogue boxes** have a green Next button at the lower right; a red Skip button appears in cutscenes.

Take-aways for Wellfall Level 1: (1) one lane, one enemy species, four fixed tower spots and one starter is the entire first lesson; (2) tutorial is a short skippable drag-and-drop lesson; (3) the lose condition is visible and tactile (candies being carried off), which our coin pile now copies; (4) the first level ends with a payoff cutscene and an unlock.

## Progress log: beating PTD1 story mode (Ruffle harness, tools/ptd_harness)
**Beaten: Oak's Lab, Route 1.** Route 2 unlocked. Lost twice on Route 1 first (see below).

### Economy and progression (read off the screens)
- Money is **persistent** and earned per kill and per level (Oak's Lab + a few kills gave P74 to start; money is kept after a defeat).
- **Level Up** costs money AND needs a full Exp bar: P30 (Lv5->6), P35 (6->7), P40 (7->8), i.e. 5 x (level+1). After a level-up the Exp bar empties.
- **Relearn** a move P1,000; **TMs/HMs** P10,000; **PokeMart** sells Moon/Leaf/Thunder/Water/Fire stones at P10,000 each (evolution items). PokeCenter and Wiki are links to the website; Mystery Gift is a web redeem.
- A new level-up can teach a move: Charmander Lv5 Scratch + Growl; **Lv7 learns Ember**.
- **Move card fields**: Type, Attack Cooldown (frames), Attack Power, Category (Physical/Special), Accuracy, plus status data (Ember: burn chance 10%, burn power 20). Scratch: Normal, cooldown 18, power 40, Physical, accuracy 100%. Ember: Fire, cooldown 18, power 40, Special, accuracy 100%.
- Team: 6 slots + Storage; sort by Level / Number / Name; a white or red up-arrow on a card means "enough Exp to level up".

### Levels
| Level | Waves | Layout | Enemies seen | Free spots | Win |
|---|---|---|---|---|---|
| Oak's Lab | 5 | 1 room, lane left to right to the candy pile | Rattata | 4 fixed squares | scripted Gary/Blastoise finale |
| Route 1 | 6 | tall vertical map (zoom to 50% to see all), lane down the left, bend right, down to the candies | Rattata, Pidgey, more per wave | **12 fixed squares** | wave 6 triggers a story cutscene (Drowzee / mind-controlled boy), then the level ends |
- Lose condition: all candies taken (6 shown as "x6"); Route 1 was LOST twice with a single Charmander at Lv6 (boss wave stole everything), WON with a Lv7 Charmander (Ember) placed at the bend of the lane.
- Each level is preceded by a long dialogue cutscene (Skip button appears top-left in some).
- Catching: the Poke Ball card at lower right is dragged onto an enemy (big ball cursor). I did not manage to land a catch by hand (the game runs in real time and my screenshots lag).

### What to copy / change for Wellfall
1. Persistent money + level-up cost that rises each level and is gated by Exp: copy (we have gold + XP; add the money cost curve).
2. Move card with cooldown/power/category/accuracy/status: copy the data model; our moves are plain stat boosts.
3. Fixed placement squares (4 then 12): our free placement is a bigger departure; fixed spots make balancing exact.
4. Story cutscene as the win trigger instead of a boss fight: matches the user's "no boss" request.

### Route 2 (level 3) - beaten
- 4 waves, one lane that runs right then bends toward the candy pile, **8 free squares**. **Joey** (freed on Route 1) fights for you from the start: his Rattata and Pidgey are pre-placed on two of the squares (a scripted NPC ally).
- Money: P117 on arrival -> Charmander Lv7 -> Lv8 for P40.
- The last wave has a blue-health-bar boss (uncatchable). Win trigger: Joey says "We did it! We WON!", then the unlock of Viridian Forest 1.
- Practical notes: the intro dialogue has a **Skip** button (top-left) on Route 1/2 cutscenes; extra Next clicks open the in-battle menu (Music / Sound FX / **Damage Text** toggles, Exit, Back). Progress only persists after pressing Save in the main menu.
- Win/lose timing mattered: the same single Charmander lost twice at full speed and won at normal speed, so speed x4 is a real risk.

### Features taken from PTD into Wellfall after beating level 3
Added (all Level-1-safe, tests green, 36 capture/feature checks): **floating damage numbers** (Settings > "Damage numbers", like PTD's Damage Text toggle); **burn status** from Ember/Forge attacks (10% chance, damage over time, flame on the enemy, "Burn!" text); **speed x4** (we had x1-x3); **Auto-start waves** toggle (PTD waves start by themselves); **full move stats** in the Team screen (type, power, cooldown, accuracy, physical/special, burn chance).
Not added (bigger changes): bought level-ups gated by Exp, fixed placement squares, pre-placed NPC ally (Joey), drag-the-Pokeball capture, PokeMart evolution stones.

## Chapter 1 playthrough findings (PTD1 via Ruffle harness)

Result: Oak's Lab, Route 1, Route 2 beaten. Viridian Forest 1 lost twice (waves ~9-10); Pewter Gym not reached.

- Catching: drag the Poké Ball only onto enemies whose HP bar is red/yellow. Only Pidgey/Rattata appeared catchable on early routes; Pidgeys caught at Lv2-5. Boss (blue bar) is uncatchable.
- Economy: money persists between levels; level-up cost is 5x(level+1) and gated by Exp. Spending everything on levels before VF1 left too little for placement.
- VF1: 10 waves, Metapod/Pikachu arrive from both sides late (waves 9-10), which overran 4 units (Charmander Lv9 + three Pidgeys). Few free squares (~6).
- Lessons: bank money for late waves, grind Routes 1-2 for levels/catches first, catch Caterpie/Metapod early in VF1 for more bodies, save from the main menu after each win.
- Harness: Ruffle + AIR wrapper (needs version=1 reply); capture automated by pixel-detecting bar colours.
