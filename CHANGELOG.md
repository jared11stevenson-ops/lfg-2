# Changelog

## Unreleased
- Skeleton, design and contracts.

## v0.1.0 — Integrated vertical slice
- Playable `main/main.tscn`: Rules (84x54 hex world, 14 class defs, Purge machine, farming, rations, permadeath) + 3D diorama world + HUD, wired via `Game` autoload.
- Headless authoritative ENet server, versioned saves, cosmetic-only meta store.
- Evidence: art/captures/integrated/ (scripted journey; positions set visually, all effects via Rules commands).

## v0.2.0 — Pass 1
- All 14 classes have real mechanics (data `implemented:true`); AI faction parties path and raid; authoritative `sync_position` movement (anti-teleport); buildings/production/merchant prices; exact save round trips.
- Menu, 14-class select, end screens; distinct class/enemy/NPC models; build/craft/trade/policy/holdings panels; combat FX, ability bar, danger indicator; roads, building/crop models.
- Sessions (local/online), autosave/continue + permadeath tombstone, cosmetic meta store; fog-filtered snapshots, token expiry, Purge disconnect lock; multi-process shared-world test.
- Grand Simulation #0 harness and report; docs for incentives, skill trees, Total Conquest.
