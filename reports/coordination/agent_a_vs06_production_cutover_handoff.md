# Agent A - VS06 Production Cutover Handoff

## Status

VS06-A production composition is closed at focused-evidence level. Godot 4.7 project parse/load passes, and the owned facility lifecycle gate passes `64/64`. Final vertical-slice, privacy, AI, save-isolation, and headed acceptance belong to the coordinator/C after their acceptance fixture is repaired.

## Frozen v0.6 facade

`GameRuntimeCoordinator` now exposes the only production-facing v0.6 card facade:

- `refresh_v06_production_player_bindings(world)`
- `v06_card_definition(card_id)`
- `v06_rank_i_facility_cards()`
- `v06_first_table_facility_card()`
- `v06_starter_monster_card_by_name(monster_name)`
- `v06_card_player_snapshot(actor_id)`
- `v06_first_table_facility_market_snapshot(actor_id)`
- `purchase_v06_first_table_facility_card(actor_id, source_item_id, transaction_id)`
- `v06_runtime_card_route(card)`
- `play_v06_runtime_card(request)`

The production owner chain is:

```text
main UI/world facts
-> GameRuntimeCoordinator routing
-> CardPlayerStateProductionAdapterV06
-> CommodityCardInventoryRuntimeController / shared CardFlow transaction
-> CoreEconomicCardRuntimeAdapterV06 or MonsterCardEffectAdapterV06
-> RegionInfrastructure / CommodityFlow / MonsterRuntimeController
```

The v0.4 catalog remains the legacy primary catalog. The v0.6 facade uses canonical nested `machine.card_id`, `effect_kind`, and `purchase_cash`; it does not flatten v0.6 cards into legacy district definitions or create a second catalog owner.

## Main routing points

- After seats and regions exist, `_new_game()` calls `refresh_v06_production_player_bindings(self)`; strict readiness requires a nonempty actor map plus ready state, inventory, economic, and monster adapters.
- `_make_starting_monster_card()` resolves the canonical v0.6 rank-I starter card.
- `_use_skill()` and `_queue_skill_resolution()` intercept nested v0.6 cards before the legacy queue.
- `_play_v06_runtime_card_for_player()` sends one stable transaction to the Coordinator facade.
- The district drawer appends one canonical rank-I v0.6 facility listing without modifying legacy `district.card_choices`.
- Facility purchase uses the canonical price and production state port; facility play routes through shared CardFlow.
- Revisioned monster region/profile/rule fact callbacks feed `MonsterRuntimeWorldBridge`; rank-I first summon uses the four-stage Monster owner. Any future cross-owner patch remains fail-closed.
- Root menu `new_run` opens setup; an empty session cannot close into an empty table.
- AI starter identity is anonymous, and district supply private cash/hand facts are pinned to the local human viewer.

## Deleted legacy item

- Removed `scenes/runtime/CommodityCardInventoryWorldBridge.tscn`.
- Replacement owner: `CardPlayerStateProductionAdapterV06`.
- Production reference scan is zero; the remaining tool reference asserts the old bridge is absent.
- No other legacy shell was removed because it still has production or test consumers.

## Facility gradient update

`tests/facility_card_production_unlock_v06_test.gd` now matches the frozen catalog:

- rank I: purchase cash `4`, play assets `0`, so life assets remain `3 -> 3` through success, finalize, and replay;
- rollback/compensation coverage uses rank II over a seeded finalized rank-I facility.

## Minimal evidence

- `godot --headless --path . --editor --quit-after 1`: PASS, exit `0`.
- `godot --headless --path . --script res://tests/facility_card_production_unlock_v06_test.gd`: PASS, `64/64`, failures `0`.
- Focused `git diff --check`: PASS.
- No full regression, MCP/headed run, default `user://` access, commit, push, merge, or staging was performed.

## Known risks

- The legacy `_summon_monster_from_card` remains only for v0.4 cards. Coordinator acceptance must prove human and AI v0.6 starters never reach it.
- Agent B's AI intent must consume the same Coordinator facade; this task does not claim a completed AI cycle.
- Income, countdown/recap, save isolation, recursive privacy, and 1600x960 click-through remain coordinator acceptance items.
- The dedicated first-table facility listing fails closed when another canonical v0.6 listing owns the market; no content is synthesized.
- Shared-worktree changes outside this owner slice remain unvalidated here.

## Lessons for other agents

- **invariant:** post-seat player binding is required; static scene composition is not readiness.
- **failed approach:** a global v0.6 catalog switch breaks legacy machine IDs and was not retained.
- **stable API:** machine IDs enter `play_v06_runtime_card`; presentation names never become runtime keys.
- **test oracle:** rank-I facility exact-once play preserves assets and terminal replay succeeds after the slot empties.
- **integration trap:** pre-seat adapter configuration creates an empty actor map and false readiness.
- **reusable pattern:** narrow facade plus one CardFlow transaction authority, with domain owners handling mutation.
- **stale evidence:** rank-I one-asset debit assertions are obsolete.
- **next dependency:** coordinator/C runs the isolated vertical slice after the acceptance fixture and Agent B AI route settle.

Detailed implementation notes remain in `reports/coordination/agent_a_vs06_production_integration_handoff.md`.
