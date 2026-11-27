# Level 1 (Mossgate Lane): perfection plan and overnight log

Goal for 7 am (13:00 UTC): Level 1 feels finished. Every pass is brainstorm -> build -> verify -> commit.

## Brainstorm: what would make Level 1 feel AAA
**Feel and juice**
- Level-up flash and move-learned popup in battle, not only on the result screen
- Capture moment: lure throw, shake, burst, "NEW" fanfare, creature joins with a flourish
- Hit sparks, damage pops, tower attack anticipation, projectile art in the new painterly style
- Boss intro: banner with portrait, music swell, named health bar; boss death moment
- Wave banner polish, coin pops, combo/streak feedback, screen-shake tuning

**World**
- Living map: animated Well glow and pulse, drifting fireflies, swaying light, mist, rain that matches the map, day/dusk cycle by wave
- Soft ground shadows and contact shadows under every sprite, lit to match the key light
- Rune stones react when a matching type is placed (pulse, particles)

**Teaching and flow**
- Tutorial that teaches: place, start, upgrade, rune stone, capture (guaranteed first weak enemy), Lures
- Contextual hints; first win celebration; second-run hints for the rare Hutzin

**Systems and replay**
- Balance across skill levels; boss fairness; rare Hutzin rate and catchability; shiny rate
- Level 1 mastery goals (no leaks, capture both species, catch the rare, 3 stars) with small rewards
- Daily seed variety; endless mode check

**UI/UX**
- Upgrade panel shows level, XP, moves; shop cards with portraits; range ring; targeting modes readable
- Touch sizes, safe area, 20:9 phones, pause menu, speed toggle
- Result screen: story line, loot, level-ups, next-step buttons

**Audio**
- Ambient bed (crickets, wind), layered music by wave intensity, capture/level-up stingers, boss theme

**Robustness**
- Soak runs, many seeds, memory, errors, save corruption, mid-run quit, resize

## Backlog (priority order, tick when done)
1. [ ] Battle juice: level-up flash, capture animation, hit sparks (fx.gd)
2. [ ] Living map: Well pulse, fireflies, mist overlay, shadows
3. [ ] Boss intro + named boss bar; Glomm presentation
4. [ ] Tutorial: capture lesson + rune stone lesson
5. [ ] Balance sweep: 30 seeds x 3 skills, tune
6. [ ] UI: upgrade panel (level/moves), shop cards, HUD
7. [ ] Audio: ambient bed, stingers
8. [ ] Mastery goals + replay hooks
9. [ ] Mobile/aspect checks
10. [ ] Soak/QA, final build, morning report

## Log
- 05:15 UTC Pass 1 done: animated capture (Lure orb, shake, burst, held enemies immune), per-wave XP pops.
- 05:25 Pass 2 done: living map overlay (Well pulse, fireflies, motes).
- 05:45 Design change from user: NO boss on Level 1. Enemies steal the Well's gold (20 coins = lives, shown as a coin pile in the Well; thieves grab coins and run off). Survive 10 waves to win; wave 10 is a larger finale with an Alpha champion. Boss UI kept for other levels.
- 05:55 Level 1 roster restricted to creatures with models: Shuckit, Shuckit Pup, Shuckit Alpha (same rigged sprite, tinted/scaled), rare Hutzin. Glomm removed from Level 1.
- 06:00 Balance (bot, 6 seeds): skill 0.6 wins 6/6 with 5-14 gold left; skill 0.4 wins 2/6; skill 0.8 wins 6/6.
- 06:10 Rig/animation pass: weight smoothing, foot lift, bigger swings, squash/stretch attacks, Dugloom spine split; all four re-baked.
- 06:30 UI: upgrade panel portrait/XP bar/moves; tutorial capture lesson + gold-theft intro; HUD Lure counter + gold-stack icon; next-wave preview distinguishes Pup/Alpha.
- 06:50 Level 1 goals (5 goals, +60 gold once each) shown on setup panel; result screen trimmed to 6 lines.
- 07:10 Audio overhaul: offline-synthesized SFX/voices, layered music (battle drums fade in on waves), ambient bed, new capture/steal/goal/level-up sounds. (Not auditioned by ear: no audio device here.)
- 07:30 Mipmapped sprite filtering for smoother fur/edges.
- (old) NEXT: rig/animation quality pass (weight smoothing, 2-bone legs, better walk/attack), then tutorial, UI, audio, mastery goals.
