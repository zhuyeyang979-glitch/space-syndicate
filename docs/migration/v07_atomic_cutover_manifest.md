# V0.7 Canonical Adapter Atomic Cutover Manifest

LANE=B
STATUS=DETACHED_ADAPTER_PREFLIGHT_READY
CANONICAL_ADAPTER_IMPLEMENTATION_STATUS=IMPLEMENTED_DETACHED_NOT_CONNECTED
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_RULESET=V0.7
PRODUCTION_CUTOVER_AUTHORIZED=false
V06_SAVE_TO_V07_DIRECT_LOAD=false
V06_SAVE_REJECTION_REASON=v06_save_backup_required
ALLOWED_SESSION_ENTRYPOINTS=[NEW_V07_GAME]
PRODUCTION_SCENE_CHANGE=false
MAIN_CHANGE=false
DUAL_WRITE_ALLOWED=false

The canonical Save, RNG, AI-observation, and player-projection adapters are detached `RefCounted` implementations. They consume the merged V0.7 semantic Core but have no production scene, Main, V0.6 runtime, or V06 Save Registry connection. This document is a future atomic owner-replacement checklist, not production cutover authorization.

A V0.6 Save is recognized and rejected with `v06_save_backup_required`. The adapter never guesses the unified track, personal DBG order, independent commodity inventory, 5+5 capacities, asset reservations, anonymous resolution order, or complete-macro-round state. The first production V0.7 release starts only through `NEW_V07_GAME`.

## 1. unified_card_track

- **V0.6 current owner:** CommoditySushiTrackRuntimeService, RegionSupplyRuntimeController, and ordinary-card acquisition routes.
- **V0.7 target owner:** V07UnifiedCardTrackCore.
- **Core port:** `v07.unified_track.core_authority.v1`.
- **AI port:** `v07.unified_track.ai_observation.v1`.
- **Player port:** `v07.unified_track.player_projection.v1`.
- **Save adapter:** `V07CanonicalSaveAdapter#unified_card_track_cycle`.
- **RNG streams:** unified track type, color, normal-card, commodity, and initial hidden-lead streams.
- **Pre-cutover gate:** Validate one mixed-track snapshot, stable identities, six-color cycle, hidden lead order, receipts, and five embedded RNG streams.
- **Cutover step:** Replace every NEW_V07_GAME Core, AI, player, Save, and RNG route in one transaction.
- **Rollback step:** Restore the detached track checkpoint and retain all V0.6 routes.
- **Old-path deletion gate:** Delete commodity-only and regional ordinary-card authorities only after the V0.7 Core is the sole published owner.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 2. normal_dbg_deck

- **V0.6 current owner:** WorldSessionState card slots, PlayerHandInteractionRuntimeService, and card_inventory Save owner.
- **V0.7 target owner:** V07DbgDeckCore personal deck and zone authority.
- **Core port:** `v07.personal_dbg.core_authority.v1#normal_dbg_deck`.
- **AI port:** `v07.personal_dbg.ai_observation.v1#normal_dbg_deck`.
- **Player port:** `v07.personal_dbg.player_projection.v1#normal_dbg_deck`.
- **Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_dbg_deck`.
- **RNG streams:** starter-deck shuffle and per-player reshuffle.
- **Pre-cutover gate:** Validate one private 12-card DBG owner per player, all zones, capacities, identities, cursors, and quiescence.
- **Cutover step:** Atomically replace normal-card commands, observations, projections, Save fields, and draw ownership.
- **Rollback step:** Restore every per-player DBG checkpoint without a card draw or move.
- **Old-path deletion gate:** Delete shared-hand and duplicate inventory writers only after all player owners publish.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 3. normal_card_merge

- **V0.6 current owner:** Ordinary-card lifecycle and effect routes without one canonical optional merge owner.
- **V0.7 target owner:** V07DbgDeckCore typed normal-card merge authority.
- **Core port:** `v07.personal_dbg.core_authority.v1#normal_card_merge`.
- **AI port:** `v07.personal_dbg.ai_observation.v1#normal_card_merge`.
- **Player port:** `v07.personal_dbg.player_projection.v1#normal_card_merge`.
- **Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_card_merge`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate typed inputs, output identity, lineage, cost, capacity, receipts, rollback, and zero RNG draws.
- **Cutover step:** Replace all optional normal-card merge commands and receipts inside the DBG owner cutover.
- **Rollback step:** Restore the DBG checkpoint and discard unpublished outputs.
- **Old-path deletion gate:** Delete name-based, automatic, and independently mutating merge routes after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 4. commodity_inventory_merge

- **V0.6 current owner:** Commodity inventory fields split across player state, claim routes, and card_inventory Save ownership.
- **V0.7 target owner:** V07DbgDeckCore independent commodity inventory and typed merge authority.
- **Core port:** `v07.personal_dbg.core_authority.v1#commodity_inventory_merge`.
- **AI port:** `v07.personal_dbg.ai_observation.v1#commodity_inventory_merge`.
- **Player port:** `v07.personal_dbg.player_projection.v1#commodity_inventory_merge`.
- **Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.commodity_inventory_merge`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate independent commodity capacity, typed lineage, privacy, and no implicit V0.6 capacity interpretation.
- **Cutover step:** Route NEW_V07_GAME acquisition, inventory, merge, projection, and Save through each player's DBG Core.
- **Rollback step:** Restore the commodity checkpoint and emit no claim or merge receipt.
- **Old-path deletion gate:** Delete shared capacity aliases and duplicate inventory writers after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 5. six_color_assets

- **V0.6 current owner:** PlayerManaRuntimeController, WorldSessionState resource fields, and player_mana Save owner.
- **V0.7 target owner:** V07AssetBatchCore six-color asset authority.
- **Core port:** `v07.six_color_assets.core_authority.v1`.
- **AI port:** `v07.six_color_assets.ai_observation.v1`.
- **Player port:** `v07.six_color_assets.player_projection.v1`.
- **Save adapter:** `V07CanonicalSaveAdapter#six_color_assets_and_reservations.assets`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate exactly six colors, cap six, remainders, revisions, privacy, and shared asset-batch lineage.
- **Cutover step:** Replace NEW_V07_GAME resource reads and writes while the candidate remains detached.
- **Rollback step:** Restore the shared asset-batch checkpoint once and publish no asset delta.
- **Old-path deletion gate:** Delete V0.6 mana and resource writers only after Core, ports, Save, and reservation parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 6. card_batch

- **V0.6 current owner:** RuntimeLoop action cadence plus card submission and resolution services.
- **V0.7 target owner:** V07AssetBatchCore 30-second five-action batch authority.
- **Core port:** `v07.card_batch.core_authority.v1#card_batch`.
- **AI port:** `v07.card_batch.ai_observation.v1#card_batch`.
- **Player port:** `v07.card_batch.player_projection.v1#card_batch`.
- **Save adapter:** `V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.card_batch`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate the one-shot window, five-action limit, local order, targets, revision, and exact-once journal.
- **Cutover step:** Replace NEW_V07_GAME action collection in the same atomic owner switch.
- **Rollback step:** Restore the shared checkpoint and discard the batch without consuming time or actions.
- **Old-path deletion gate:** Delete V0.6 multi-window and resolution-time collection only after timing parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 7. asset_reservation

- **V0.6 current owner:** Execution-time affordability and resource consumers without complete pre-reservation.
- **V0.7 target owner:** V07AssetBatchCore reservation ledger authority.
- **Core port:** `v07.six_color_assets.core_authority.v1#asset_reservation`.
- **AI port:** `v07.six_color_assets.ai_observation.v1#asset_reservation`.
- **Player port:** `v07.six_color_assets.player_projection.v1#asset_reservation`.
- **Save adapter:** `V07CanonicalSaveAdapter#six_color_assets_and_reservations.reservations`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate one complete reservation identity, six-color cost, batch identity, journal, and balance per action.
- **Cutover step:** Make reservation acceptance the only NEW_V07_GAME affordability and cost-consumption authority.
- **Rollback step:** Restore the shared checkpoint and release every candidate reservation without charge.
- **Old-path deletion gate:** Delete execution-time affordability fallbacks and duplicate cost consumers after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 8. anonymous_resolution

- **V0.6 current owner:** CardResolutionQueueRuntimeService plus execution and history services.
- **V0.7 target owner:** V07AssetBatchCore anonymous round-robin resolution authority.
- **Core port:** `v07.card_batch.core_authority.v1#anonymous_resolution`.
- **AI port:** `v07.card_batch.ai_observation.v1#anonymous_resolution`.
- **Player port:** `v07.card_batch.player_projection.v1#anonymous_resolution`.
- **Save adapter:** `V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.anonymous_resolution`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate anonymous order, hidden owner binding, lead cursor, targets, reservations, receipts, and privacy.
- **Cutover step:** Replace NEW_V07_GAME queue, execution, and history publication with one anonymous port.
- **Rollback step:** Restore the shared checkpoint and publish no queue entry, effect, receipt, or owner identity.
- **Old-path deletion gate:** Delete owner-contiguous queues, counters, late targeting, and duplicate writers after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 9. solar_efficiency

- **V0.6 current owner:** SolarAvailabilityRuntimeService and world-time-derived facility efficiency.
- **V0.7 target owner:** V07SolarVictoryCore solar facility efficiency authority.
- **Core port:** `v07.solar_victory.core_authority.v1#solar_facility_efficiency_state_v1`.
- **AI port:** `v07.solar_victory.ai_observation.v1#solar`.
- **Player port:** `v07.solar_victory.player_projection.v1#solar`.
- **Save adapter:** `V07CanonicalSaveAdapter#solar_facility_and_macro_victory.solar`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate tagged time, sunlit state, 2.0/1.0 rates, revision, and no card or presentation authority.
- **Cutover step:** Replace facility efficiency queries without advancing world time.
- **Rollback step:** Restore solar state without ticking facilities, time, cards, or presentation.
- **Old-path deletion gate:** Delete V0.6 solar-rate authority only after formula parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 10. macro_round_victory_gate

- **V0.6 current owner:** VictoryControlRuntimeController, RuntimeVictoryPort, and RuntimeLoop settlement routing.
- **V0.7 target owner:** V07SolarVictoryCore complete-macro-round victory and FinalSettlement authority.
- **Core port:** `v07.solar_victory.core_authority.v1#macro_round_victory_gate_state_v1`.
- **AI port:** `v07.solar_victory.ai_observation.v1#victory_gate`.
- **Player port:** `v07.solar_victory.player_projection.v1#victory_gate`.
- **Save adapter:** `V07CanonicalSaveAdapter#solar_facility_and_macro_victory.victory_gate`.
- **RNG stream:** `NONE`.
- **Pre-cutover gate:** Validate complete-macro-round proof, pending qualification, lead parity, receipts, and zero-or-one settlement.
- **Cutover step:** Replace victory evaluation and settlement publication in the atomic owner switch.
- **Rollback step:** Restore the detached checkpoint before publication and never reverse a committed settlement.
- **Old-path deletion gate:** Delete direct V0.6 audit-to-settlement and duplicate victory writers after exact-once parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## Acceptance Gate

The future production cutover may begin only after PR #77 lands, this adapter PR is synchronized with that main, all ten domains pass together, and one authorized task replaces the old owners atomically. Every domain has `dual_write_allowed=false`; no compatibility writer or implicit V0.6 Save migration may survive the commit.
