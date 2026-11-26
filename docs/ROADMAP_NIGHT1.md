# Wellfall TD: Night 1 Roadmap (05:05 to 11:30 UTC)

## North-star: what the game looks like when it's "advanced"
**Battle screen (Bloons TD6 bar, 2026 polish)**
- Creatures are lit, outlined, animated characters (3D-rendered sprites, see Art Pipeline). Idle breathing, attack anticipation and recoil, hit flashes, death poofs, squash and stretch on everything.
- World: a stylised painted map with depth (cliffs, water, trees with sway), soft shadows and ambient occlusion on the ground, weather (rain/snow/dust) that changes matchups (rain buffs Tide/Volt, snow slows Ember).
- HUD: BTD6 layout. Top bar with lives, coins, wave. Right-side creature shop. Tapping a placed creature opens a bottom-left upgrade panel (2 paths, 4 tiers, cross-path rule). 1x/2x/3x speed and pause.
- Juice: projectile trails, screen shake on bosses, coin pops, "Super!" popups, wave banners, boss intros.

**Systems (beyond PTD)**
- Evolution paths that change a creature's *role*, not just stats (e.g. Tickindle: Clockwork Pyre rapid-fire vs Anvilmanul armor-pierce).
- Targeting modes (First / Last / Strong / Fast). Sell for refund.
- Weather and terrain modifiers, a boss wave with an intro, 12-type chart (done).
- Capture loop (PTD DNA): defeated enemy types unlock as new creatures to field.
- Meta: starter pick, campaign map of biome regions, save/progress.

**Presentation by 11:30 UTC:** zip with project source, Windows export if templates download works, screenshots, a short changelog, and an honest list of what is and isn't verified.

## Art pipeline (the outside-the-box bet)
Bloons TD6 uses pre-rendered 3D sprites. We do the same with AI:
1. Tripo (connected via the environment proxy) generates a 3D model per creature from its design text.
2. A Godot SubViewport rig renders each model from a 3/4 camera to transparent PNGs (turntable directions for enemies, one hero angle for towers).
3. Shaders in-engine: outline, rim light, soft ground shadow, hit flash.
4. Fallback if generation is poor or too costly: upgrade the procedural vector rigs with the same shaders and animation.
Credits are the user's, so the plan is: balance check first, 6 base creatures only, no regenerate loops.

## Schedule (UTC). Each block ends with a commit and push.
| Block | Window | Goal |
|---|---|---|
| 1 | 05:05-06:15 | Plan, Tripo balance check + kick off 6 model generations (async). Gameplay: upgrade framework, tap-select panel, targeting, sell, 1x/2x/3x speed |
| 2 | 06:15-07:45 | Upgrade trees for all 3 starters (2 paths x 4 tiers), effects, UI polish, tests and balance sim |
| 3 | 07:45-09:00 | Art pipeline: render models to sprites (or fallback rigs), shaders, animation, juice (particles, shake, trails) |
| 4 | 09:00-10:00 | Map and UX: second map, menu, game-over screen, weather system, boss wave |
| 5 | 10:00-11:00 | Audio (procedural SFX), save/progress, balance pass, export attempt (templates), bug sweep |
| 6 | 11:00-11:30 | Package zip, screenshots, README, present to user |

## Risks
- Tripo quality/credits: capped at 6 base models, fallback above.
- Export templates are a large download: try once in block 5, else deliver source zip.
- Software-rendered screenshots are slow: use short captures only.
- Timezone unknown: deadline set conservatively at 11:30 UTC.
