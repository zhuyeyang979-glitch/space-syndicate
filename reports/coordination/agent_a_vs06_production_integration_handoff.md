# Agent A - VS06-A Production Integration Handoff

## Outcome

The production composition now has one post-seat v0.6 player-state binding, strict readiness, a narrow v0.6 facility/monster card facade, and a real main-table dispatch into the existing CardFlow transaction path. The v0.4 catalog remains the legacy primary catalog; v0.6 cards keep their canonical nested `machine.card_id` namespace and are never inserted into legacy district `card_choices`.

This is **focused evidence**, not final production evidence. Godot 4.7 parse/load and the owned facility lifecycle test pass. The coordinator still owns the vertical-slice, privacy, save isolation, AI-cycle, and headed acceptance runs.

## Unique owner graph

```text
main.gd (UI, world facts, existing signals)
  -> GameRuntimeCoordinator (composition and narrow routing)
     -> CardPlayerStateProductionAdapterV06 (only card/cash state port)
     -> CommodityCardInventoryRuntimeController (only v0.6 inventory transaction source)
        -> CardFlowTransactionService (single transaction lifecycle)
        -> CoreEconomicCardRuntimeAdapterV06
           -> RegionInfrastructureRuntimeController (facility owner)
           -> CommodityFlowRuntimeController (commodity-flow owner)
        -> MonsterCardEffectAdapterV06
           -> MonsterRuntimeController (monster roster/lifecycle owner)
```

`CommodityCardInventoryWorldBridge` is not composed and its obsolete scene was removed. No second inventory journal, lock owner, catalog owner, or card transaction service was introduced.

## Implemented production routes

### Post-seat binding and readiness

- `GameRuntimeCoordinator.refresh_v06_production_player_bindings(world)` binds the real player array only after seats exist, builds the actor map, configures the economic and monster adapters, and recomputes strict readiness.
- `main._new_game()` refreshes the binding after player creation and region initialization. A missing actor map or unavailable state/inventory/effect adapter fails closed instead of exposing a false-ready table.
- Resetting the session clears runtime readiness; pre-player composition readiness no longer implies production player readiness.

### Narrow v0.6 card facade

Public Coordinator surface:

- `v06_card_definition(card_id)`
- `v06_rank_i_facility_cards()`
- `v06_first_table_facility_card()`
- `v06_starter_monster_card_by_name(monster_name)`
- `v06_card_player_snapshot(actor_id)`
- `v06_first_table_facility_market_snapshot(actor_id)`
- `purchase_v06_first_table_facility_card(actor_id, source_item_id, transaction_id)`
- `v06_runtime_card_route(card)`
- `play_v06_runtime_card(request)`

The first-table facility listing is a dedicated canonical v0.6 market item. Its price is read from `machine.purchase_cash`; callers cannot override it. A successful purchase uses `purchase_market_card`, so card and cash mutation remain exact-once in the production state port. The listing is not flattened into a v0.4 definition and is not routed through legacy district settlement.

Nested v0.6 hand cards are detected by `machine.card_id` and `machine.effect_kind`. Core economic cards route to `CoreEconomicCardRuntimeAdapterV06`; starter monster cards route through `CommodityCardInventoryRuntimeController.play_core_card()` and the existing monster adapter. Legacy v0.4 cards continue through the existing queue/resolution path.

### Starter monster world facts

`main.gd` now supplies the revisioned callbacks consumed by `MonsterRuntimeWorldBridge`:

- `monster_deploy_cross_owner_capabilities_v06()`
- `monster_deploy_rule_snapshot_v06(actor_id)`
- `monster_deploy_profile_snapshot_v06(family_id, rank)`
- `monster_deploy_region_snapshot_v06(region_id)`
- four no-patch prepare/commit/rollback/finalize callbacks

The current P0 rank-I profiles declare no bound-skill, economy, or role-cash patch. The callbacks therefore accept only an empty participant set and fail closed with `monster_cross_owner_atomicity_unavailable` if a future profile introduces any patch without a real four-stage owner. Rank II-IV remain blocked by `monster_upgrade_duration_policy_conflict` in the monster owner.

### Menu and privacy

- The root lobby now exposes `new_run -> NewGameSetup`.
- Closing the menu with no session reopens the root menu instead of revealing an empty table.
- AI setup cards use an anonymous starter face and do not reveal the selected monster.
- District supply always derives private cash/hand facts from the local human seat, even after another seat is selected.

## Files in this integration slice

- `scripts/runtime/game_runtime_coordinator.gd`
- `scripts/main.gd`
- `scenes/runtime/GameRuntimeCoordinator.tscn` (existing static v0.6 owner composition is the consumed production graph)
- `tests/facility_card_production_unlock_v06_test.gd`
- removed obsolete `scenes/runtime/CommodityCardInventoryWorldBridge.tscn`
- this handoff

No `scripts/cards/v06/**`, Agent B tests, Agent C files, global v0.4 catalog scene/service, card data, formulas, or UI layout files were edited by this closure.

## Facility gradient synchronization

The owned facility production oracle now follows the frozen catalog rule:

- rank I: purchase cash `4`, play assets `0`; successful/finalized/replayed paths preserve life assets `3 -> 3`.
- compensation coverage uses rank II with a finalized rank-I fixture, so its nonzero asset payment and rollback remain meaningful.

## Safe retirement

- Removed: `scenes/runtime/CommodityCardInventoryWorldBridge.tscn`.
- Replacement: `CardPlayerStateProductionAdapterV06` is the only production state port.
- Zero-reference evidence: production `scripts/`, `scenes/`, `addons/`, and `project.godot` contain no reference. The remaining tool assertion explicitly verifies the old bridge is absent.
- No other legacy shell was removed; the current City/GDP/Save/GameScreen/FirstTable compatibility surfaces still have production or test consumers.

## Minimal verification

- `godot --headless --path . --editor --quit-after 1` - PASS, exit `0` (Godot `4.7.stable`; expected editor scan-abort warning on timed quit only).
- `godot --headless --path . --script res://tests/facility_card_production_unlock_v06_test.gd` - PASS, `64/64`, failures `0`.
- `git diff --check -- scripts/main.gd scripts/runtime/game_runtime_coordinator.gd tests/facility_card_production_unlock_v06_test.gd` - PASS.
- No new editor/MCP process, default `user://` smoke, commit, push, merge, or staging operation was performed.

Suggested coordinator integration commands:

- `godot --headless --path . --script res://tests/monster_deploy_atomic_lifecycle_v06_test.gd`
- `godot --headless --path . --script res://tests/core_economy_production_integration_v06_test.gd`
- `godot --headless --path . --script res://tests/tomorrow_playable_vertical_slice_test.gd` with isolated save root
- one headed `scenes/main.tscn` run at 1600x960 for menu, first summon, facility purchase/play, income, AI progression, victory, and privacy

## Known risks and remaining acceptance

- The old `_summon_monster_from_card` remains inside the v0.4 resolution route. v0.6 nested cards are intercepted before that route, but the coordinator must prove this with a real human and AI first summon.
- Agent B owns AI intent generation. Its latest change must target this same Coordinator facade; this handoff does not claim a completed AI turn.
- The dedicated first-table facility market intentionally fails closed if another canonical v0.6 listing already owns the market. It does not synthesize content.
- Full income, victory/recap, save isolation, recursive privacy scanning, and second-monitor input were not rerun here by coordination instruction.
- The shared worktree contains unrelated concurrent changes; this handoff does not attribute or validate them.

## Lessons for other agents

- **invariant:** bind production player state after seats exist; scene composition alone is not runtime readiness.
- **failed approach:** globally switching `CardRuntimeCatalogService` to v0.6 broke legacy IDs (`family1` versus `family.rank_1`) across supply, AI, and monster slots. Keep explicit namespaces and one v0.6 transaction authority.
- **stable API:** use `play_v06_runtime_card(request)` and the canonical facility market facade; pass machine IDs end-to-end and use `player.name` only for presentation.
- **test oracle:** rank-I facility play leaves assets unchanged and exact-once replay still sees the terminal journal after the hand slot is empty (`64/64`).
- **integration trap:** configuring adapters before player creation yields an empty actor map and a false-ready coordinator; always call `refresh_v06_production_player_bindings` after seat creation/load.
- **reusable pattern:** route by nested `machine.effect_kind`, then let the shared inventory/CardFlow transaction own card, cash, rollback, and finalize.
- **stale evidence:** any assertion that rank-I facility play debits one life asset is obsolete; nonzero compensation belongs to rank II.
- **next dependency:** the coordinator must run the isolated real vertical slice after Agent B's AI intent handoff settles, then retire only legacy paths proven to have zero production callers.
