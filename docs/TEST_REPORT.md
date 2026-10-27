# Test report (Stream C)
Run: `/tmp/claude-0/godot --headless --path . -s tests/run_all.gd [-- <path substring>]` (each test file runs in its own Godot process; exit code non-zero on any failure).

## Last full run (all streams' suites present at the time)
9 suites, 74 tests, 5355 checks, 0 failures. Stream C portion: 47 tests, 254 checks
(net/test_net 15/97, net/test_net_real_rules 5/49, persist/test_meta 7/27, persist/test_persist 16/66, persist/test_persist_real 2/12, runner selfcheck 2/3).

## What is covered
- Persistence: atomic temp+verify+rename writes, sha256 corruption detection, bit-flip/truncation/garbage fallback to rotating backups (2), explicit v1->v2->v3 migrations (each step + chain + rejects future/missing), state-level migration hook, permadeath tombstone that outranks backups (corrupting the primary cannot resurrect a dead leader), meta.json allowlist (ids only, no numbers) surviving match death.
- Net (real ENet sockets on 127.0.0.1, one process): token-bound actors, actor spoof rejection, command shape validation, seq dedupe (replays are idempotent), stale/jump seq, token-bucket rate limit on the server clock, garbage/oversize packets, hello timeout, reconnect (same actor, resend dedupe, replacement of old socket, restart with last_seq recovery), match_over blocks commands + tombstone, autosave.
- Real rules (tests/net/test_net_real_rules.gd): server holds a real `MatchState`, applies `Rules.apply/tick`; two clients; duplicate eat applied once; PvP/capture refused in PEACE and only the server's `advance()` clock opens PURGE_ACTIVE (client-supplied time/phase ignored); simultaneous captures conserve every item and leave one consistent owner.
- tests/net/test_net.gd uses `tests/net/fake_rules.gd`, a small stand-in kept for fast protocol tests; the real-rules suite above is the authority.

## Known limits / not claimed
- No hosting, accounts, TLS/DTLS, matchmaking, monitoring, or backups of server data exist. Tokens are issued by `NetServer.issue_token` and travel unencrypted. LAN/dev scaffolding only.
- Snapshots are the full unfiltered state (no fog-of-war filtering): a modified client can read everything.
- Save checksums detect accidental corruption only, not tampering; deleting a tombstone file re-enables a slot.
- Never run: Android, a real display/GPU, real remote players, long soak, packet loss/latency simulation.
- Finding for Stream A: `MatchState.from_dict(to_dict())` is not bit-identical (e.g. `energy` 0.0 becomes 0); stable after one pass.
- `net/server_main.gd` (dedicated entry point) is written but not exercised by any test.
- tools/ci_export.sh: Linux export succeeded (binary ~70MB built with downloaded 4.4.1 templates); the binary was started headless once and failed to load res://main/main.tscn because that scene did not exist yet. Not run with a display.

## Integrated run (lead, Godot 4.4.1 headless)
24 suites, 187 tests, 12175 checks, 0 failures. Journey: `xvfb-run ... -- --journey` planted 4 plots via Rules, ran to Purge day 7 (software GL, not a perf benchmark).
Not verified: human fun, Android/device, real online players, hosting. Only 5 of 14 classes have mechanics; 9 are data-only.
Known gaps: player-to-rules movement is hex-step sync (rules actor lags visual player); AI factions abstract; net snapshots unfiltered.

## Pass 1 integrated run (lead)
37 suites, 296 tests, 16025 checks, 0 failures (Godot 4.4.1 headless). Fixed a non-hermetic persist test (stale meta.json.bak2).
Journey (xvfb, software GL): plant x4 via session commands, build/holdings panels, class ability, Warning and Purge phases; no script errors. Captures in art/captures/integrated/.
Not verified: human play feel, touch on a real device, Android, real online players, hosting. Stream reports for pass 1 never arrived; contents verified from commits/tests only.
Still open: Dominion/Crowned wins still in rules (replace with Total Conquest), Standing/rank and skill trees unbuilt, AI factions class-agnostic, no match convergence (see docs/SIM_REPORT_0.md).

## Pass 2 integrated run (lead)
42 suites, 378 tests, 19086 checks, 0 failures. Journey (software GL) captured Standing and Skill panels with no script errors.
Sim (agent-run, 24 seeds x 336 days): territory still changes after week 24 in 24/24; non-raider personas earn deeds; Total Conquest 0/24; Vex eliminated in 100% of matches (class balance far outside band); several abilities never used by bots. See docs/SIM_REPORT_pass2.md.
Missing: meshes for shrine/greenhouse/forge (fallback hut), HUD standing strip (toast at WARNING only), scout/escort/truce/ransom/sabotage buttons.

## Pass 3 integrated run (lead)
47 suites, 456 tests, 25019 checks, 0 failures. Journey (software GL, 8 captures incl. quest journal, standing, skills) no script errors.
Agent-run sim (24 seeds x 336 days): Total Conquest 7/24; Vex eliminated 96%; 11 of 14 classes eliminated >60%; class land spread outside 0.5x-2x; Track/Truce unused by bots. Not a human playtest.

## Pass 4/5 integrated run (lead)
54 suites, 577 tests, 31590 checks, 0 failures. Journey (software GL, 9 captures) no script errors. Exported Linux binary: `--smoke` started a match, ticked 2 days, no script errors.
Sim after pass-5 fixes (20 seeds, 336d): survivors@wk48 3.0 (was 8.8), one-alive-ever 6/20 (was 3/20), Total Conquest 2/20 (was 1/20), CPU 1.37 ms/tick. Elimination rates up (bram/forge/rook/tavi 90%, judd/oren/vex 95%): the 'no class eliminated >75%' criterion conflicts with convergence and should be replaced by survival-time and win-share bands. Not a human playtest.
