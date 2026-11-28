# Critique (keeper, pass 1)
Reviewed by eye: lineup_v2, mammals_v1, structure_gallery_v1, civ_real_seed12, ui_title, ui_new, craft_bench, craft_items, play2, play3. Tests: 772 checks pass (tools/run_tests.sh). Asset gate: 1 approved, 5 quarantined (assets/manifest).

## What works
- World/UI cohesion: ui_title.png is the strongest frame. Inked coast, foam, muted watercolour palette, parchment UI with gold studs read as one identity.
- Non-mammal creatures (frog, toad, spider, ant, bird, fish in lineup_v2.png) have distinct silhouettes; hue-shifted shadows give them volume.
- Structures (structure_gallery_v1, civ_real_seed12) share the creature lighting/ink rule; ruin variants are legible; ant mounds and granaries read at world zoom.

## What is bad (ranked)
1. **Mammal body plan still reads as lizard/newt.** mammals_v1.png: ears were added (pink on the hare) but every mammal is the same flat sausage torso with stick legs splayed sideways, huge glossy blue eyes, and a tail swapped in. A vole, hare and gnawer cannot be told apart at play zoom (play3.png: they look like crickets). Fix: upright/under-body limb posture, distinct head and snout shape per archetype, eyes scaled to head, ears on every mammal.
2. **Rock props are a visual and gameplay problem.** play2.png: hundreds of near-identical boulders, dark outline rings drawn offset from the fill (double outline), and they hide the player. Fix outline registration, cap density, vary form and add surface detail.
3. **UI text clipping.** ui_new.png: 'Meadow Vol', 'Canopy Squir', 'gra' truncated; a stale label ('THE WORLD') collides with the title; cards overlap borders; backdrop water is blocky/pixelated there while ui_title.png is smooth. craft_bench/craft_items: HUD panels bleed through the modal and the message box overlaps the hotkey bar (LMB 'Strike' is covered).
4. **Terrain, grey biome.** play2.png rocky ground is low-contrast mud grey; the hare nearly vanishes. civ_real_seed12.png also renders only ~60% of the viewport (grey right-hand panel): capture/viewport sizing bug.
5. **Eye language.** Every animal gets the same cartoonish ringed eye; it fights the 'illuminated bestiary' tone and makes predators look friendly.
6. **Structure distinctiveness.** Several mound types are brown blobs; dam arcs and the dotted arc (gallery row 2 col 8) are almost invisible on green.
7. **Plants repeat.** Tree canopies are one template (play3.png); flowers are uniform confetti dots.

## Gameplay evidence concerns (not art)
- docs/playtest run1-3: all 9 bot runs end 'playing', zero kills everywhere, species always vole: combat and permadeath are unevidenced.
- docs/oracle t9 overshot (82-206 sapient) and was halved by hand in t10 (9-180). Intelligence payoffs are tuned numbers; 'emergent, not scripted' is not yet defended. t1 runs at ~100 ms/tick.
- No runtime-generator output validator exists, so creature/structure generators cannot be approved under our own rules.

## Actions, in order
1. Redesign mammals (item 1) and resubmit with a new lineup.
2. Fix prop outline registration and density (2).
3. Fix UI clipping with ellipsis/word-wrap and resize cards (3).
4. Write a determinism test for creature/structure draw output across N seeds (unblocks approval).
5. Contrast pass on rocky biome; fix viewport sizing in captures.
6. Make playtest bots actually fight; report kills and deaths by cause.
