# Sessions: one interface for local and online play (Stream C)

Files: `main/session_base.gd` (GameSession), `main/session_local.gd` (LocalSession), `main/session_online.gd` (OnlineSession),
`persistence/menu_api.gd` (MenuApi), `persistence/meta_hooks.gd` (MetaHooks). Nothing here edits `main/main.gd`; wiring is yours.

## The interface (both implementations)
```
session.state                    MatchState the UI reads (stable instance for the whole session)
session.actor_id                 the viewer's leader id (state.player_id == actor_id in both cases)
session.command(type, args)      builds {type, actor, seq, args} with a safe seq, then submit()   <- use this instead of a private seq counter
session.submit(cmd) -> Dictionary
    Local : Rules.apply result {ok, error, events}, synchronous
    Online: {"ok":true,"pending":true,"seq":n} immediately (means "sent"); verdict arrives by signal
session.snapshot() -> Dictionary encoded state (online: fog-filtered)
signals: events_emitted(events)  state_replaced()  state_updated()  command_resolved(seq,result)  command_failed(seq,error)  session_ended(reason)
```
`events_emitted` is safe to feed straight to `stage.on_events(events, session.state)`: online delivers events together with the
snapshot that already contains their effects. `state_replaced` = new world/object (rebuild the stage); `state_updated` = in-place
refresh (online only; resync farm/HUD cheaply). Both sessions add `_process` ticking when added to the tree (`LocalSession.tick(dt)` also callable).

## Wiring sketch for Game / main.gd
```gdscript
# Game autoload: hold a session and forward its signals (keeps Game.state / Game.submit / events_emitted for existing code)
var session: GameSession
func use_session(s: GameSession) -> void:
    session = s; add_child(s)
    state = s.state
    s.events_emitted.connect(func(e): events_emitted.emit(e))
    s.state_replaced.connect(func(): state = s.state; state_replaced.emit())
    # online: s.state_updated -> stage.farm.sync_from_state(state) / stage.set_hud_model(...)
func submit(cmd): return session.submit(cmd)      # online callers must treat {"pending":true} as "sent"
# Game._process must no longer call Rules.tick itself when a session owns the clock.

# Local new game / continue:
var s := LocalSession.new_game(seed, &"lfg:class/judd", slot, MenuApi.new_match_opts(), MenuApi.meta())
var s := LocalSession.continue_slot(slot, MenuApi.meta())      # null -> LocalSession.last_error ("match_over", "no_valid_save", ...)
# Online:
var s := OnlineSession.join(host, port, token)                  # wait for s.joined / s.is_ready(); s.session_ended(reason) on fatal loss
```
Main.gd migration notes: `_cmd()` -> `session.command(type, args)`; read `res.get("ok")` only for local, otherwise connect `command_failed`
for the toast. `Game.state.player_id` is already the viewer in online mode. Position sync / movement commands are throttled by the server
(`move_rate`) and audited; the stage should not send more than one per ~0.15 s.

## Local persistence (LocalSession with slot >= 0)
Autosave: every `autosave_interval` session-seconds (30), and immediately on day change, phase change, holding captured, window close / app pause.
Writes are atomic (temp file + verify + rename, 2 rotating backups, sha256). Leader death (`match_over`) writes a tombstone that outranks every
save/backup: `continue_slot` returns null with `last_error == "match_over"`, `save_now` is refused, `MenuApi.continue_slot()` never offers it.
`LocalSession.new_game(..., slot)` wipes the slot first (explicit "new game here").

## Menu API (`MenuApi`, plain data)
`slots()` rows: `{slot, ok, status active|over|corrupt|empty, reason, saved_at, class_id, day, phase, seed, saves, recovered}`;
`continue_slot()` (-1 if none), `free_slot()`, `delete_slot(n)`, `codex()`, `titles()`, `equip_title(id)`, `new_match_opts(alt_start)`.
Meta hooks (cosmetic ids only): class first use -> `lfg:codex/class_<name>`; `victory` event -> `lfg:title/dominion|crowned`.
`session.unlocked` lists ids unlocked this session for a toast. Meta lives in `user://meta.json`, untouched by permadeath.

## Server-side rules a client will notice
- Snapshots are per viewer (`net/snapshot_filter.gd`): other factions' inventories/stores are empty (`inv_hidden` / `store_hidden`), far rival
  leaders are fogged stubs (`fogged`, hex -9999,-9999), wild enemies and drops only within 8 hexes of your units/holdings, `rng_state` zeroed.
  Plots, holding owners, garrisons and buildings are public. Any UI code reading a rival's `inv` must tolerate `{}`.
- `purge_disconnect_lock`: disconnecting during the Purge leaves your actor idle and attackable; reconnect works but commands are refused
  (`purge_disconnect_lock`, `locked_for` seconds) for 90 s or until the Purge ends.
- Tokens: 128-bit random, expire (6 h default, server clock), `bad_token` flood from one address locks that address out for 60 s.
- Position sync: the server accepts whatever command types `Rules.COMMAND_TYPES` declares; names containing "move"/"sync" share the move throttle.
