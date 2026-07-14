# Agent A VS06-A14 Final Settlement Runtime Composition Handoff

## Status

Frozen and ready for coordinator integration. No commit, push, merge, reset, or default `user://` access was performed.

## Production Composition

- `res://scenes/main.tscn` owns exactly one `RuntimeServices/FinalSettlementRuntimeComposition` instance.
- The composition statically owns the existing `FinalSettlementPublicSourceAdapter` and exactly one `FinalSettlementBoardPanel`.
- It consumes the existing `FinalSettlementPublicSnapshotService` under `GameRuntimeCoordinator`; it does not duplicate that service or any Victory/cash owner.
- Production signals route directly to the existing main menu, public log, and global navigation entry points.

Public API:

- `present(public_context: Dictionary) -> Dictionary`
- `compose_public_source(public_context: Dictionary) -> Dictionary`
- `compose_public_snapshot(public_context: Dictionary) -> Dictionary`
- `latest_public_summary() -> String`
- `last_public_snapshot() -> Dictionary`
- `sanitize_public_log_entries(entries: Array) -> Array`
- `board_node() -> Control`
- `debug_snapshot() -> Dictionary`

The accepted context is pure public data. Raw players, internal receipts, private/opponent hands, and AI plans fail closed. Audit cash is forwarded only when the authoritative Victory public projection supplies `cash_visibility=public_audit` and the matching `audit_revealed_player_indices` allowlist.

## Modified Files

- Added `scripts/runtime/final_settlement_runtime_composition.gd`.
- Added `scenes/runtime/FinalSettlementRuntimeComposition.tscn`.
- Added `scripts/tools/final_settlement_runtime_composition_v06_bench.gd`.
- Added `scenes/tools/FinalSettlementRuntimeCompositionV06Bench.tscn`.
- Added `tests/final_settlement_runtime_composition_v06_test.gd`.
- Added `docs/final_settlement_runtime_composition_v06.md`.
- Modified `scenes/main.tscn` for the single production instance and signal wiring.
- Modified `scripts/main.gd` for the thin composition lookup/outcome forwarding and physical legacy deletion.
- Updated current ownership assertions in `tests/main_runtime_composition_test.gd` and `tests/layout_scene_smoke_test.gd`.

## Main Deletion Evidence

Start checkpoint: 20,409 total lines, 17,934 nonblank lines, 1,165 functions.

Frozen checkpoint: 20,147 total lines, 17,702 nonblank lines, 1,150 functions.

Net deletion: 262 total lines, 232 nonblank lines, 15 functions. This exceeds the A14 gate of 150 nonblank lines and 6 functions.

Zero-symbol scan returned zero references in `main.gd` for all requested retired builders/formatters/action wrappers, the direct adapter lookup, the dynamic board preload, and the final-only top-player/city/card/monster helper family. `main.tscn` contains exactly one `FinalSettlementRuntimeComposition` node.

## Verification

- Isolated Godot 4.7 focused test: `FINAL_SETTLEMENT_RUNTIME_COMPOSITION_V06_TEST|status=PASS|checks=7|failures=0`.
- Godot MCP scene: `res://scenes/tools/FinalSettlementRuntimeCompositionV06Bench.tscn`.
- MCP result: `FINAL_SETTLEMENT_RUNTIME_COMPOSITION_V06_BENCH|status=PASS|checks=11|failures=0`.
- MCP `get_debug_output`: `errors=[]`.
- MCP `stop_project`: `finalErrors=[]`.
- Bench evidence covers normal/audit privacy, missing authorization, illegal raw context rejection, open/reopen exact-once, one board, nonzero geometry, single action emission, and public log exact-once.
- Scoped `git diff --check` has no errors; the only output is the pre-existing CRLF normalization warning for `layout_scene_smoke_test.gd`.

## Known Integration Follow-ups

Some older QA callers still reflect deleted main methods and were outside the A14 write boundary: `tomorrow_playable_vertical_slice_bench.gd`, `final_settlement_public_snapshot_cutover_bench.gd`, `main_victory_public_privacy_v06_test.gd`, `human_first_table_playability_v06_test.gd`, and `ui_snapshot_capture.gd`. They must consume `RuntimeServices/FinalSettlementRuntimeComposition` in the integration worktree. No production fallback or wrapper was retained for them.

The composition intentionally no longer derives optional recap color from raw players, districts, resolved-card history, or monster internals. Future richer recap fields must arrive through a dedicated authoritative public projection, not by restoring main-owned reads.

## Lessons for Other Agents

- **Invariant:** Victory and exact cash remain owned by VictoryControl; presentation receives only its public projection.
- **Failed approach:** Reopening the menu while the board remained in `MenuPreviewBox` caused `clear_preview()` to free the authoritative board instance.
- **Stable API:** `FinalSettlementRuntimeComposition.present()` is the sole production presentation entry; `compose_public_snapshot()` is its pure-data QA port.
- **Test oracle:** Reopen must preserve the board instance ID, one log set per outcome ID, nonzero visible geometry, and zero unauthorized cash sentinels.
- **Integration trap:** A dynamically cleared preview host cannot safely own a long-lived scene instance between opens; park the instance under the composition before reopening.
- **Reusable pattern:** Scene-own one presentation component, signal-route commands, and call existing domain services through narrow NodePaths without duplicating ownership.
- **Stale evidence:** Reflection tests that call deleted main methods are not proof that a production owner is missing; update them to the scene API instead of restoring wrappers.
- **Next dependency:** Coordinator integration must migrate the listed stale QA callers before running the shared full regression.

## Lease

Godot MCP project was stopped cleanly. **MCP lease released.**
