# Agent A VS06-A5 Dispatch / Replay Handoff

## Scope closed

- Reproduced the pre-owner starter rejection as `assets_insufficient`.
- Kept the canonical rank-I monster definition unchanged at two assets.
- Marked only the authoritative starting card instance with `machine.starter_entitlement=true` and an empty `machine.asset_cost`; requests cannot supply or override this card payload.
- Routed the real hand action through `_queue_skill_resolution -> GameRuntimeCoordinator.play_v06_runtime_card -> CommodityCardInventory/CardFlow -> MonsterCardEffectAdapterV06 -> MonsterRuntimeController`.
- Added replay-before-current-slot handling for consumed v0.6 facility and monster cards. Replay reads the existing Inventory/CardFlow transaction journal, validates transaction/actor/slot/card/effect/target intent hashes, and re-enters the same owner API. No second journal or mutation owner was added.
- Made `main.gd` derive the play transaction from the authoritative production inventory `runtime_instance_id`, avoiding the legacy `slot:N` identity guess.

## Files changed by A5

- `scripts/main.gd`
- `scripts/runtime/game_runtime_coordinator.gd`
- `tests/vs06_production_dispatch_replay_test.gd` (new)
- This handoff

`tests/main_runtime_composition_test.gd` remains the accepted A4 production composition gate and was only rerun here.

## Stable production interfaces

- `GameRuntimeCoordinator.play_v06_runtime_card(request: Dictionary) -> Dictionary`
- `GameRuntimeCoordinator.v06_card_player_snapshot(actor_id: String) -> Dictionary`
- `CommodityCardInventoryRuntimeController.transaction_journal_snapshot() -> Dictionary` remains the sole replay source.
- `MonsterRuntimeController.monster_starter_state_snapshot_v06(actor_id)` remains the non-recursive starter-state query.

## Atomicity and canonicality evidence

- Human starter: one consumed card, one roster addition, one finalized Monster terminal.
- Same monster transaction replay: returns the original terminal result with `idempotent_replay=true`; player state and roster are unchanged.
- Same facility transaction replay after the slot is empty: returns the original terminal result; cash, hand, facilities, and revisions are unchanged.
- Changed actor, slot, target, or transaction does not hit an old terminal.
- Catalog rank-I monster cost remains two assets; only the server-created starter instance carries the one-use free entitlement.

## Minimal verification

- `godot --headless --path . --script res://tests/vs06_production_dispatch_replay_test.gd` with isolated `APPDATA`: PASS, 30/30.
- `godot --headless --path . --script res://tests/main_runtime_composition_test.gd` with isolated `APPDATA`: PASS.
- `godot --headless --path . --script res://tests/monster_deploy_atomic_lifecycle_v06_test.gd` with isolated `APPDATA`: PASS, 61/61.
- Targeted `git diff --check`: PASS.

Per unified acceptance policy, Agent A did not run the full vertical slice, full smoke, MCP bench, or headed capture. The coordination thread should rerun the canonical tomorrow-playable slice.

## Known risk / next integration check

- Replay target reconstruction is deliberately fail-closed and must reproduce the original target hash. A later request with altered region, game time, actor, or slot is rejected rather than treated as replay.
- The coordination thread still owns the full Stage 3/4 vertical-slice rerun and player-facing privacy sweep.
- No legacy card path was deleted in A5; deletion remains gated on the canonical vertical slice proving the new dispatch in the real table flow.

## Lessons for other agents

- **Invariant:** consumed-card replay must consult the authoritative CardFlow journal before inspecting the current slot.
- **Failed approach:** deriving a transaction ID from `slot:N` produced a false missing-terminal diagnosis; the production inventory had already assigned a stable `world:...` instance ID.
- **Stable API:** use `v06_card_player_snapshot()` for production instance identity and `play_v06_runtime_card()` for both first execution and replay.
- **Test oracle:** require one finalized owner terminal plus unchanged player/owner snapshots on replay; a boolean `submitted` value is insufficient.
- **Integration trap:** a starter entitlement is instance data, not a catalog rewrite and not a caller-provided request flag.
- **Reusable pattern:** journal-first gate, binding reconstruction, canonical hash comparison, then re-entry through the same transaction owner.
- **Stale evidence:** the earlier `new_terminal_count=0` report reflected rejection before the starter entitlement fix; the owned focused gate now observes the finalized owner terminal.
- **Next dependency:** coordination must rerun the real Stage 3/4 harness and only then authorize deletion of the corresponding legacy summon/play branches.
