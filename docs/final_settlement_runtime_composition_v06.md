# Final Settlement Runtime Composition v0.6

## Ownership

`FinalSettlementRuntimeComposition.tscn` owns presentation composition only. It statically contains the existing `FinalSettlementPublicSourceAdapter` and one `FinalSettlementBoardPanel`, and calls the existing `FinalSettlementPublicSnapshotService` owned by `GameRuntimeCoordinator`.

It does not own Victory rules, rankings, cash, save data, or settlement calculations. The only accepted production input is a pure-data public context containing the authoritative Victory public projection, public participant names, and optional allowlisted public map counters.

## Public API

- `present(public_context) -> Dictionary`
- `compose_public_source(public_context) -> Dictionary`
- `compose_public_snapshot(public_context) -> Dictionary`
- `latest_public_summary() -> String`
- `last_public_snapshot() -> Dictionary`
- `board_node() -> Control`
- `debug_snapshot() -> Dictionary`

The scene emits `menu_open_requested`, `public_log_entry_requested`, and `action_requested`. `main.tscn` connects these signals to existing menu, log, and global navigation entry points.

## Privacy

Raw players, internal receipts, private hands, opponent hands, and AI plans are rejected. Exact cash can pass only when the Victory public projection explicitly provides `cash_visibility=public_audit` and includes that player in `audit_revealed_player_indices`. Missing authorization fails closed.

## Lifecycle

Opening and reopening reuse the same board node. Before the menu clears its preview host, the composition parks the board under itself; it then attaches the same node after the menu shell opens. Public outcome logs are emitted once per `outcome_id`, and board actions are forwarded once.

## Retired Main Surface

The cutover deletes the dynamic board builder, final settlement source/snapshot/summary assembly, action wrapper, and their final-only ranking/map/card/monster helper family from `main.gd`. No compatibility fallback remains.
