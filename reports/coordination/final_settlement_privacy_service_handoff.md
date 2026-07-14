# Final Settlement Public Snapshot v0.6 Handoff

## Status

COMPLETE AND FROZEN. `FinalSettlementPublicSnapshotService` now enforces state-aware exact-cash visibility and passed both isolated focused tests and the required Godot 4.7 MCP scene gate.

MCP lease was released after `stop_project`; no Godot project owned by this task remains running.

## Frozen files

- `scripts/runtime/final_settlement_public_snapshot_service.gd`
- `tests/final_settlement_public_snapshot_service_test.gd`
- `tests/final_settlement_public_privacy_v06_test.gd`
- `docs/final_settlement_public_privacy_v06.md`
- `scenes/tools/FinalSettlementPublicSnapshotServiceV06Bench.tscn`
- `reports/coordination/final_settlement_privacy_service_handoff.md`

No changes were made to `main.gd`, `GameRuntimeCoordinator`, `FinalSettlementPublicSourceAdapter`, Victory owner/controller/bridge, scenes outside the dedicated Bench, or UI layout.

## State-aware rule

Exact per-seat cash is rendered only when all of the following are true:

1. source contains `cash_visibility="public_audit"`;
2. source contains an integer `audit_revealed_player_indices` array;
3. the entry's integer `player_index` is in that authoritative array;
4. canonical `rank_entries` contains an integer `cash_ledger_cents` for that seat;
5. duplicate canonical records do not disagree.

The service never derives authority from cash-field presence, winner, `game_over`, final rank, viewer identity, available cash, or escrow. Missing/malformed/partial authority fails closed. Authorized cash is formatted only after recursive sanitization through an internal structured marker; arbitrary source text cannot manufacture it. Non-audit seats retain `现金为最终并列判定项，数值保密`.

Available/escrow components are never rendered. Public rank order, winners, Top-K GDP, controlled regions, and comparison order remain source/receipt owned; the service does not sort or recalculate them.

## SourceAdapter owner gap

The current A14 `FinalSettlementPublicSourceAdapter` remains cash-free and does not forward Victory-owned `cash_visibility` or `audit_revealed_player_indices`. Therefore today's production path correctly fails closed and shows no exact cash. Enabling rulebook §4.3 disclosure requires those two authority facts to be published by the Victory owner and forwarded by its adapter owner. This service does not invent a roster and did not modify A14/B8 files.

## Focused test evidence

Both tests ran with isolated locations:

- `APPDATA=C:\Users\ADMINI~1\AppData\Local\Temp\space-syndicate-final-settlement-handoff-ef6e5d4000b942209090317cf32f7c02\appdata`
- `LOCALAPPDATA=C:\Users\ADMINI~1\AppData\Local\Temp\space-syndicate-final-settlement-handoff-ef6e5d4000b942209090317cf32f7c02\localappdata`

Results:

- `res://tests/final_settlement_public_snapshot_service_test.gd` — `FINAL SETTLEMENT PUBLIC SNAPSHOT SERVICE PASS`, exit 0.
- `res://tests/final_settlement_public_privacy_v06_test.gd` — `FINAL_SETTLEMENT_PUBLIC_PRIVACY_V06_TEST|status=PASS|checks=31|failures=0`, exit 0.

The privacy oracle uses the production service scene and real `compose()` path. It covers one authoritative audit-public seat, one non-audit hidden seat, available/escrow hiding, summary/KPI/money-source/rank surfaces, cash plus winner/game-over without visibility, public-audit visibility without roster, malformed/empty input, recursive scan, source immutability, and repeated-compose output purity. The pre-fix implementation was observed red with 12 leakage assertions before the service change.

## Godot MCP product gate

- MCP engine: `4.7.stable.official.5b4e0cb0f`.
- Ran `res://scenes/tools/FinalSettlementPublicSnapshotServiceV06Bench.tscn` through `run_project`.
- Bench root: `FinalSettlementPublicSnapshotServiceV06Bench`.
- Production node: instantiated from `res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn`.
- Production APIs exercised: `configure({})`, `compose(source)`, `debug_snapshot()`.
- Coverage: authoritative public-audit cash visible in KPI/money-source/rank; non-audit exact cash hidden; cash plus winner/game-over without visibility hidden; public-audit visibility without roster hidden; raw cash keys absent.
- Debug output: `FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_V06_BENCH|status=PASS|checks=15|failures=0|service_ready=true|policy=authoritative_public_audit_allowlist|fail_closed=true`.
- `get_debug_output`: `errors=[]`.
- `stop_project`: `Godot project stopped`; `finalErrors=[]`.

## Static and run boundaries

- Scoped `git diff --check`: PASS.
- No legacy public-cash fallback remains in the service.
- No commit, push, merge, rollback, full smoke, MCP editor mutation, manual headed playthrough, or default `user://` access was performed.
- Full vertical-slice and integration gates remain coordinator-owned.
