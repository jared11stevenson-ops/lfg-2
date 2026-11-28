# ASCENDANT progress log
Honest status. Only things that were actually run are listed under "Verified".

## Verified (run by keeper, 2026-11-28)
- Test harness: `tools/run_tests.sh` -> 97 checks pass across 4 files (sample math/json, asset gate, registry). Exit code 0; gate CLI exits 1 on failing fixtures.
- Asset quarantine gate (`assets/asset_gate_lib.gd`, `tools/asset_gate.gd`): rejects self-approval (case-insensitive), missing/too-small evidence images, vague evidence, below-floor scores (including when the average would hide them), critical failures, mismatched declared average, runtime generators lacking validated_output_space. 9 fixtures.
- `ApprovedRegistry` returns only gate-valid approved manifests; fraudulent approvals are listed, not served.

## Decisions
- Test base class is referenced by path (`extends "res://tests/test_case.gd"`), not class_name, because headless runs without editor import do not register global classes (a class_name base made the runner hang silently during keeper development; the runner now fails loudly on parse errors).
- Score floor 6/10 per category; evidence >= 40 chars.

## Known failures / gaps
- No real asset manifests exist yet in assets/manifest (only fixtures). Nothing in the game is approved.
- Gate checks that evidence images exist and are loadable; it cannot verify they depict the asset (human/critic review needed).

## Remaining work
See MANDATE_CHECKLIST.md.

## Session log
- 2026-11-28 keeper: harness, gate, registry, fixtures, docs stubs.

## Lead session log — build night 1 (verified by running unless marked)
- VERIFIED: Godot 4.7 headless + software-GL screenshots (tools/shot.sh). `tools/run_tests.sh`: 765 checks pass (genome constraints, ancestry, phenotype validity for all archetypes, sim determinism, silk gating, property-based invention, item legend, save/load round trip incl. post-load determinism).
- VERIFIED (captures): creature lineup (captures/lineup_v2.png), structure gallery (CONSTRUCTED FIXTURE), title screen with live simulated backdrop (ui_title.png), world creation (ui_new.png), crafting workbench (craft_bench.png), real ant civilization from sim output (civ_real_seed12.png).
- VERIFIED (Oracle, docs/oracle/*.json): ecosystem runs 600-1000 seasons at ~100-180 ms/season (1024 regions); sapience emerged in different species per world (ants, rooks, minnows, hares, voles); fixes driven by Oracle: speciation rate limiter, shelter-demand explosion, per-deme civ spam -> merge, fish with no architecture, cognition genes drifting to 1.0 (anatomical manipulator caps + convex brain cost).
- KNOWN FAILURES / NOT DONE: mammal art weak (heads/ears); no multiplayer (NOT implemented — no claim); no tutorial hints yet; player cannot yet interact with civilizations directly (trade/diplomacy/raids as gameplay); ruins have no loot/rediscovery; no bot playstyle suite; audio untested by ear (synth only); mobile perf unmeasured.
