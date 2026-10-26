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
