# Agent C VS06-C14 — VisualEventQueue Retirement Handoff

## Outcome

Batch B is complete and frozen. The orphan `scripts/runtime/visual_event_queue.gd` and its `.uid` were physically deleted after migrating their only live test consumer to the production `VisualEventLayer.tscn` + `VisualEventSnapshot` path. No production UI, GameScreen, main, Coordinator, event category, or presentation behavior was modified.

## Changed files

- `tests/visual_event_smoke_test.gd`
- deleted `scripts/runtime/visual_event_queue.gd`
- deleted `scripts/runtime/visual_event_queue.gd.uid`
- `docs/legacy_runtime_retirement_v06.md` (Batch B status only)
- `reports/coordination/agent_c_vs06_visual_event_queue_retirement_handoff.md`

## Evidence

- Non-historical scan excluding `docs/**`, `reports/**`, and generated `.godot/**`: `VisualEventQueue|visual_event_queue.gd` references = 0.
- Godot `4.7.stable.official.5b4e0cb0f`, isolated `APPDATA`/`LOCALAPPDATA`.
- `VISUAL_EVENT_SMOKE_TEST|status=PASS|checks=38|failures=0`.
- The focused test explicitly load/instantiates `res://scenes/ui/VisualEventLayer.tscn`, calls production `set_visual_events`, and reads `get_visual_event_snapshot`.
- Covered production limit 32, card/monster/economy/route classes, reduced motion, deterministic repeat refresh, upstream-expiry replacement, explicit clear, visible non-zero layer/label geometry, and recursive fixture/snapshot privacy.
- `git diff --check`: PASS.

No full smoke, MCP, headed run, default `user://`, commit, push, merge, reset, or production-layer edit was performed.

## Existing API boundary and honest gap

The active chain remains event snapshot/data → `GameScreen._sync_visual_events` → `VisualEventLayer.set_visual_events(events, reduced_motion)`.

`VisualEventSnapshot` currently has no first-class weather event type/class and the retired queue never supplied one. Its current production behavior safely normalizes an unsupported public weather-origin cue to `target_arrow`; the test records that behavior instead of adding a new production category. Automatic wall-clock expiry is likewise upstream-owned: the layer preserves `duration` and clears when the producer supplies the post-expiry snapshot, or through `clear_events()`.

## Lessons for other agents

- **Invariant:** production visual state is the normalized event array rendered by the one active `VisualEventLayer`; no second queue owns it.
- **Failed approach:** retaining a test-only queue to preserve old characterization made an orphan helper look production-relevant.
- **Stable API:** `set_visual_events`, `get_visual_event_snapshot`, and `clear_events` on the production scene are the supported test/integration surface.
- **Test oracle:** instantiate the real scene, feed more than 32 normalized public events, then prove cap, classes, reduced motion, stable refresh, clear, geometry, and privacy.
- **Integration trap:** an empty `GameScreen` event list currently does not call the layer; upstream expiry must explicitly publish replacement/clear semantics rather than assuming the layer owns a timer.
- **Reusable pattern:** migrate the sole non-production consumer to the active owner, prove zero references, then delete script and UID in the same closed batch.
- **Stale evidence:** any test/report treating `VisualEventQueue.active_count()` or `to_snapshot()` as the current production route is obsolete.
- **Next dependency:** if weather needs a first-class visual class, the UI owner must intentionally add it to `VisualEventSnapshot`/layer with its own focused contract; retirement does not authorize that expansion.
