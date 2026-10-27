# LFG! Last Farm Standing — v0.5.0 (playable build)

Run `LFG.x86_64` (Linux) or `LFG.exe` (Windows). Single player, offline, no account.

## Goal
Thrive. Farm, build, explore, quest and rank up in peace; survive the weekly **Purge** (day 7: lawless, everyone can kill, steal and raid).
Your leader dying ends the match (permadeath). The only win is **Total Conquest** (every rival gone, whole map yours). Rivals can win it too.

## Controls (keyboard)
- WASD move · Q/E rotate camera · mouse wheel zoom
- E use / interact (water, harvest, plant, visit, POI) · F attack nearest · class ability on the bar (1-3)
- B build menu · K skill tree · P standing · N main menu
- Toolbar: BUILD CRAFT TRADE POLICY HOLD JOURNAL PETS · RANK (top right) · BAG, MAP, HEX buttons
Touch UI (joystick + buttons) is built in but untested on a real phone.

## First 10 minutes
A short tutorial chain starts automatically (harvest, plant, water, eat, craft, build, read the Purge card).

## Honest status
- Verified: 54 test suites / 577 tests / 31,590 checks pass (headless, Godot 4.4.1); scripted play-through captures; the exported Linux binary starts a match.
- NOT verified: human playtest, Windows binary run, Android, real online players, hosting. Multiplayer server code exists and is tested on localhost only; this build has no online menu.
- Balance comes from bot simulations (docs/SIM_REPORT_1.md), not from human play.
