# V0.7.1 Canonical Adapter Atomic Cutover Manifest

LANE=B
STATUS=V071_DETACHED_ADAPTER_PREFLIGHT_READY
CANONICAL_ADAPTER_IMPLEMENTATION_STATUS=IMPLEMENTED_DETACHED_NOT_CONNECTED
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_RULESET=V0.7.1
PRODUCTION_CUTOVER_AUTHORIZED=false
V06_SAVE_TO_V071_DIRECT_LOAD=false
V07_SAVE_TO_V071_DIRECT_RESUME=false
V06_SAVE_REJECTION_REASON=v06_save_backup_required
ALLOWED_SESSION_ENTRYPOINTS=[NEW_V071_GAME]
PRODUCTION_SCENE_CHANGE=false
MAIN_CHANGE=false
DUAL_WRITE_ALLOWED=false
LATEST_MAIN_BASELINE_SHA=95aca23eb0d1f572025776902519f494ee3778d4
V071_REQUIRED_PRE_CUTOVER_GATES=[batch_boundary_owner_ready,replacement_claim_lock_ready,minimum_deck_count_ready,l1_supply_only_ready,commodity_availability_batch_ready,invalid_target_policy_ready,soft_hidden_lead_ready,balance_profile_ready]
V071_PRODUCTION_CONNECTION_COUNT=0
V071_V06_MUTATION_COUNT=0
V071_DUAL_WRITE_COUNT=0
COMMERCIAL_ART_FOUNDATION=GREEN
PRESENTATION_ASSET_CATALOG_READY=true

The canonical Save, RNG, AI-observation, and player-projection adapters are detached `RefCounted` implementations targeting V0.7.1. They have no production scene, Main, V0.6 runtime, or V06 Save Registry connection. This document is a future atomic owner-replacement checklist, not production cutover authorization.

A V0.6 Save is recognized and rejected with `v06_save_backup_required`; a detached V0.7 Save also fails closed unless a future test-only migration is explicitly selected. The adapter never guesses the unified track, personal DBG order, independent commodity inventory, 5+5 capacities, asset reservations, anonymous resolution order, balance profile, or complete-macro-round state. A future production V0.7.1 release starts only through `NEW_V071_GAME`.

Every player-visible cutover below declares presentation dependencies through stable semantic asset keys owned by the existing Presentation Asset Catalog. The detached Player adapter emits only `asset_key` entries; Core, AI, and Save remain asset-key agnostic, and no adapter or cutover entry names a vendor filename or third-party resource path. Presentation consumes authorized projections; it never becomes a gameplay, sunlight, Save, or RNG owner.

## 1. unified_card_track

- **V0.6 current owner:** CommoditySushiTrackRuntimeService, RegionSupplyRuntimeController, and ordinary-card acquisition routes.
- **V0.7.1 target owner:** V07UnifiedCardTrackCore.
- **Core port:** `v071.unified_track.core_authority.v2`.
- **AI port:** `v071.unified_track.ai_observation.v2`.
- **Player port:** `v071.unified_track.player_projection.v2`.
- **Save adapter:** `V07CanonicalSaveAdapter#unified_card_track_cycle`.
- **RNG streams:** unified track type, color, normal-card, commodity, and initial hidden-lead streams.
- **Required asset keys:** `card.frame.normal`, `card.frame.commodity`, all six `icon.asset.*` keys, and `ui.panel.primary`.
- **Required player projection:** `v071.unified_track.player_projection.v2`.
- **Required AI observation:** `v071.unified_track.ai_observation.v2`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#unified_card_track_cycle`.
- **Required RNG streams:** `unified_track_type_draw`, `unified_track_color_draw`, `unified_track_normal_card_draw`, `unified_track_commodity_draw`, and `initial_hidden_lead_order`.
- **Production scene target:** `scenes/ui/PublicTrack.tscn`.
- **Old-surface deletion gate:** Retire TopCommoditySushiTrack and regional ordinary-card surfaces only after PublicTrack renders the authorized mixed-track projection with every required key.
- **Rollback surface:** Rebind PublicTrack to the unchanged V0.6 public-track projection and render no detached V0.7.1 track state.
- **Pre-cutover gate:** Validate one mixed-track snapshot, stable identities, six-color cycle, hidden lead order, receipts, and five embedded RNG streams.
- **Cutover step:** Replace every NEW_V071_GAME Core, AI, player, Save, and RNG route in one transaction.
- **Rollback step:** Restore the detached track checkpoint and retain all V0.6 routes.
- **Old-path deletion gate:** Delete commodity-only and regional ordinary-card authorities only after the V0.7.1 Core is the sole published owner.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 2. normal_dbg_deck

- **V0.6 current owner:** WorldSessionState card slots, PlayerHandInteractionRuntimeService, and card_inventory Save owner.
- **V0.7.1 target owner:** V07DbgDeckCore personal deck and zone authority.
- **Core port:** `v071.personal_dbg.core_authority.v2#normal_dbg_deck`.
- **AI port:** `v071.personal_dbg.ai_observation.v2#normal_dbg_deck`.
- **Player port:** `v071.personal_dbg.player_projection.v2#normal_dbg_deck`.
- **Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_dbg_deck`.
- **RNG streams:** starter-deck shuffle and per-player reshuffle.
- **Required asset keys:** `card.frame.normal`, `card.back.normal`, `icon.board.draw_pile`, `icon.board.discard_pile`, and `icon.board.shuffle`.
- **Required player projection:** `v071.personal_dbg.player_projection.v2#normal_dbg_deck`.
- **Required AI observation:** `v071.personal_dbg.ai_observation.v2#normal_dbg_deck`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_dbg_deck`.
- **Required RNG streams:** `starter_deck_shuffle` and `normal_deck_reshuffle_by_player`.
- **Production scene target:** `scenes/ui/table/PlayerCardDock.tscn`.
- **Old-surface deletion gate:** Retire shared-hand zones and disappearance fallbacks only after PlayerCardDock renders the authorized private DBG projection with draw, discard, shuffle, and card-back assets.
- **Rollback surface:** Rebind PlayerCardDock to the unchanged V0.6 hand projection and expose no candidate DBG order or private zone state.
- **Pre-cutover gate:** Validate one private 12-card DBG owner per player, all zones, capacities, identities, cursors, and quiescence.
- **Cutover step:** Atomically replace normal-card commands, observations, projections, Save fields, and draw ownership.
- **Rollback step:** Restore every per-player DBG checkpoint without a card draw or move.
- **Old-path deletion gate:** Delete shared-hand and duplicate inventory writers only after all player owners publish.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 3. normal_card_merge

- **V0.6 current owner:** Ordinary-card lifecycle and effect routes without one canonical optional merge owner.
- **V0.7.1 target owner:** V07DbgDeckCore typed normal-card merge authority.
- **Core port:** `v071.personal_dbg.core_authority.v2#normal_card_merge`.
- **AI port:** `v071.personal_dbg.ai_observation.v2#normal_card_merge`.
- **Player port:** `v071.personal_dbg.player_projection.v2#normal_card_merge`.
- **Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_card_merge`.
- **RNG stream:** `NONE`.
- **Required asset keys:** `card.frame.normal`, `icon.board.merge`, `audio.card.merge`, and `vfx.card.merge`.
- **Required player projection:** `v071.personal_dbg.player_projection.v2#normal_card_merge`.
- **Required AI observation:** `v071.personal_dbg.ai_observation.v2#normal_card_merge`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_card_merge`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/table/PlayerCardDock.tscn`.
- **Old-surface deletion gate:** Retire automatic, name-based, and independently mutating merge affordances only after PlayerCardDock renders typed candidates and receipt-driven feedback.
- **Rollback surface:** Restore the pre-cutover PlayerCardDock card projection, clear candidate merge feedback, and publish no output card or receipt.
- **Pre-cutover gate:** Validate typed inputs, output identity, lineage, cost, capacity, receipts, rollback, and zero RNG draws.
- **Cutover step:** Replace all optional normal-card merge commands and receipts inside the DBG owner cutover.
- **Rollback step:** Restore the DBG checkpoint and discard unpublished outputs.
- **Old-path deletion gate:** Delete name-based, automatic, and independently mutating merge routes after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 4. commodity_inventory_merge

- **V0.6 current owner:** Commodity inventory fields split across player state, claim routes, and card_inventory Save ownership.
- **V0.7.1 target owner:** V07DbgDeckCore independent commodity inventory and typed merge authority.
- **Core port:** `v071.personal_dbg.core_authority.v2#commodity_inventory_merge`.
- **AI port:** `v071.personal_dbg.ai_observation.v2#commodity_inventory_merge`.
- **Player port:** `v071.personal_dbg.player_projection.v2#commodity_inventory_merge`.
- **Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.commodity_inventory_merge`.
- **RNG stream:** `NONE`.
- **Required asset keys:** `card.frame.commodity`, `icon.board.merge`, `audio.card.merge`, and `vfx.card.merge`.
- **Required player projection:** `v071.personal_dbg.player_projection.v2#commodity_inventory_merge`.
- **Required AI observation:** `v071.personal_dbg.ai_observation.v2#commodity_inventory_merge`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#personal_dbg_and_merge.commodity_inventory_merge`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/table/PlayerCardDock.tscn`.
- **Old-surface deletion gate:** Retire shared-capacity commodity surfaces and duplicate inventory writers only after PlayerCardDock renders the independent commodity projection and typed merge receipts.
- **Rollback surface:** Restore the V0.6 commodity presentation and publish no candidate inventory or merge receipt.
- **Pre-cutover gate:** Validate independent commodity capacity, typed lineage, privacy, and no implicit V0.6 capacity interpretation.
- **Cutover step:** Route NEW_V071_GAME acquisition, inventory, merge, projection, and Save through each player's DBG Core.
- **Rollback step:** Restore the commodity checkpoint and emit no claim or merge receipt.
- **Old-path deletion gate:** Delete shared capacity aliases and duplicate inventory writers after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 5. six_color_assets

- **V0.6 current owner:** PlayerManaRuntimeController, WorldSessionState resource fields, and player_mana Save owner.
- **V0.7.1 target owner:** V07AssetBatchCore six-color asset authority.
- **Core port:** `v071.six_color_assets.core_authority.v2`.
- **AI port:** `v071.six_color_assets.ai_observation.v2`.
- **Player port:** `v071.six_color_assets.player_projection.v2`.
- **Save adapter:** `V07CanonicalSaveAdapter#six_color_assets_and_reservations.assets`.
- **RNG stream:** `NONE`.
- **Required asset keys:** `icon.asset.life`, `icon.asset.energy`, `icon.asset.industry`, `icon.asset.technology`, `icon.asset.commerce`, and `icon.asset.shipping`.
- **Required player projection:** `v071.six_color_assets.player_projection.v2`.
- **Required AI observation:** `v071.six_color_assets.ai_observation.v2`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#six_color_assets_and_reservations.assets`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/table/PlayerCardDock.tscn`.
- **Old-surface deletion gate:** Retire mana-named counters and V0.6 resource surfaces only after PlayerCardDock renders all six authorized values with shape-and-icon identification.
- **Rollback surface:** Restore the V0.6 resource presentation and clear candidate six-color balances, reservations, and refresh feedback.
- **Pre-cutover gate:** Validate exactly six colors, cap six, remainders, revisions, privacy, and shared asset-batch lineage.
- **Cutover step:** Replace NEW_V071_GAME resource reads and writes while the candidate remains detached.
- **Rollback step:** Restore the shared asset-batch checkpoint once and publish no asset delta.
- **Old-path deletion gate:** Delete V0.6 mana and resource writers only after Core, ports, Save, and reservation parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 6. card_batch

- **V0.6 current owner:** RuntimeLoop action cadence plus card submission and resolution services.
- **V0.7.1 target owner:** V07AssetBatchCore 30-second five-action batch authority.
- **Core port:** `v071.card_batch.core_authority.v2#card_batch`.
- **AI port:** `v071.card_batch.ai_observation.v2#card_batch`.
- **Player port:** `v071.card_batch.player_projection.v2#card_batch`.
- **Save adapter:** `V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.card_batch`.
- **RNG stream:** `NONE`.
- **Required asset keys:** `card.frame.normal`, `card.frame.commodity`, `card.frame.bound_action`, `ui.panel.primary`, `icon.board.card_count`, `icon.board.turn`, and `icon.board.target`.
- **Required player projection:** `v071.card_batch.player_projection.v2#card_batch`.
- **Required AI observation:** `v071.card_batch.ai_observation.v2#card_batch`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.card_batch`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/table/PlayerCardDock.tscn`.
- **Old-surface deletion gate:** Retire V0.6 multi-window collection and resolution-time targeting surfaces only after PlayerCardDock renders one authorized five-action local ordering projection.
- **Rollback surface:** Restore the pre-cutover command surface, discard the candidate batch, and consume neither time nor actions.
- **Pre-cutover gate:** Validate the one-shot window, five-action limit, local order, targets, revision, and exact-once journal.
- **Cutover step:** Replace NEW_V071_GAME action collection in the same atomic owner switch.
- **Rollback step:** Restore the shared checkpoint and discard the batch without consuming time or actions.
- **Old-path deletion gate:** Delete V0.6 multi-window and resolution-time collection only after timing parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 7. asset_reservation

- **V0.6 current owner:** Execution-time affordability and resource consumers without complete pre-reservation.
- **V0.7.1 target owner:** V07AssetBatchCore reservation ledger authority.
- **Core port:** `v071.six_color_assets.core_authority.v2#asset_reservation`.
- **AI port:** `v071.six_color_assets.ai_observation.v2#asset_reservation`.
- **Player port:** `v071.six_color_assets.player_projection.v2#asset_reservation`.
- **Save adapter:** `V07CanonicalSaveAdapter#six_color_assets_and_reservations.reservations`.
- **RNG stream:** `NONE`.
- **Required asset keys:** all six `icon.asset.*` keys plus `icon.board.lock`, `audio.card.lock`, and `vfx.card.lock`.
- **Required player projection:** `v071.six_color_assets.player_projection.v2#asset_reservation`.
- **Required AI observation:** `v071.six_color_assets.ai_observation.v2#asset_reservation`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#six_color_assets_and_reservations.reservations`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/table/PlayerCardDock.tscn`.
- **Old-surface deletion gate:** Retire execution-time affordability and duplicate cost surfaces only after PlayerCardDock renders exact reserved and available six-color values from the authorized projection.
- **Rollback surface:** Clear candidate reservation highlights and restore the V0.6 affordability presentation without charging or releasing an authoritative asset.
- **Pre-cutover gate:** Validate one complete reservation identity, six-color cost, batch identity, journal, and balance per action.
- **Cutover step:** Make reservation acceptance the only NEW_V071_GAME affordability and cost-consumption authority.
- **Rollback step:** Restore the shared checkpoint and release every candidate reservation without charge.
- **Old-path deletion gate:** Delete execution-time affordability fallbacks and duplicate cost consumers after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 8. anonymous_resolution

- **V0.6 current owner:** CardResolutionQueueRuntimeService plus execution and history services.
- **V0.7.1 target owner:** V07AssetBatchCore anonymous round-robin resolution authority.
- **Core port:** `v071.card_batch.core_authority.v2#anonymous_resolution`.
- **AI port:** `v071.card_batch.ai_observation.v2#anonymous_resolution`.
- **Player port:** `v071.card_batch.player_projection.v2#anonymous_resolution`.
- **Save adapter:** `V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.anonymous_resolution`.
- **RNG stream:** `NONE`.
- **Required asset keys:** `card.frame.bound_action`, `ui.panel.primary`, `icon.board.player_order`, and `icon.board.target`.
- **Required player projection:** `v071.card_batch.player_projection.v2#anonymous_resolution`.
- **Required AI observation:** `v071.card_batch.ai_observation.v2#anonymous_resolution`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.anonymous_resolution`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/CardResolutionTrack.tscn`.
- **Old-surface deletion gate:** Retire owner-contiguous queues, counter controls, and late-targeting surfaces only after CardResolutionTrack renders anonymous entries without portraits, player-specific colors, or owner identity.
- **Rollback surface:** Restore the V0.6 resolution track projection and remove every unpublished anonymous entry, receipt, target, and owner-safe placeholder.
- **Pre-cutover gate:** Validate anonymous order, hidden owner binding, lead cursor, targets, reservations, receipts, and privacy.
- **Cutover step:** Replace NEW_V071_GAME queue, execution, and history publication with one anonymous port.
- **Rollback step:** Restore the shared checkpoint and publish no queue entry, effect, receipt, or owner identity.
- **Old-path deletion gate:** Delete owner-contiguous queues, counters, late targeting, and duplicate writers after parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 9. solar_efficiency

- **V0.6 current owner:** SolarAvailabilityRuntimeService and world-time-derived facility efficiency.
- **V0.7.1 target owner:** V07SolarVictoryCore solar facility efficiency authority.
- **Core port:** `v071.solar_victory.core_authority.v2#solar_facility_efficiency_state_v1`.
- **AI port:** `v071.solar_victory.ai_observation.v2#solar`.
- **Player port:** `v071.solar_victory.player_projection.v2#solar`.
- **Save adapter:** `V07CanonicalSaveAdapter#solar_facility_and_macro_victory.solar`.
- **RNG stream:** `NONE`.
- **Required asset keys:** `shader.planet.body`, `shader.planet.cloud`, `shader.planet.atmosphere`, `environment.night_sky_hdri_001`, and the four stable `model.facility.*.base` keys.
- **Required player projection:** `v071.solar_victory.player_projection.v2#solar`.
- **Required AI observation:** `v071.solar_victory.ai_observation.v2#solar`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#solar_facility_and_macro_victory.solar`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/PlanetBoard.tscn`.
- **Old-surface deletion gate:** Retire V0.6 solar-rate presentation bindings only after PlanetBoard renders the public Core projection on the opaque day/night planet and facility models without becoming the sunlight owner.
- **Rollback surface:** Restore the V0.6 public solar snapshot on PlanetBoard; keep the opaque planet presentation while removing detached V0.7.1 efficiency labels.
- **Pre-cutover gate:** Validate tagged time, sunlit state, 2.0/1.0 rates, revision, and no card or presentation authority.
- **Cutover step:** Replace facility efficiency queries without advancing world time.
- **Rollback step:** Restore solar state without ticking facilities, time, cards, or presentation.
- **Old-path deletion gate:** Delete V0.6 solar-rate authority only after formula parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## 10. macro_round_victory_gate

- **V0.6 current owner:** VictoryControlRuntimeController, RuntimeVictoryPort, and RuntimeLoop settlement routing.
- **V0.7.1 target owner:** V07SolarVictoryCore complete-macro-round victory and FinalSettlement authority.
- **Core port:** `v071.solar_victory.core_authority.v2#macro_round_victory_gate_state_v1`.
- **AI port:** `v071.solar_victory.ai_observation.v2#victory_gate`.
- **Player port:** `v071.solar_victory.player_projection.v2#victory_gate`.
- **Save adapter:** `V07CanonicalSaveAdapter#solar_facility_and_macro_victory.victory_gate`.
- **RNG stream:** `NONE`.
- **Required asset keys:** `ui.panel.popup`, `icon.board.settlement`, `audio.settlement.complete`, `vfx.settlement.complete`, and `font.display`.
- **Required player projection:** `v071.solar_victory.player_projection.v2#victory_gate`.
- **Required AI observation:** `v071.solar_victory.ai_observation.v2#victory_gate`.
- **Required Save adapter:** `V07CanonicalSaveAdapter#solar_facility_and_macro_victory.victory_gate`.
- **Required RNG stream:** `NONE`.
- **Production scene target:** `scenes/ui/FinalSettlementBoard.tscn`.
- **Old-surface deletion gate:** Retire direct audit-to-settlement and duplicate victory surfaces only after FinalSettlementBoard renders one authorized complete-macro-round result and exact-once receipt.
- **Rollback surface:** Restore the pre-publication settlement surface and render no candidate winner, ranking, effect, or completion receipt.
- **Pre-cutover gate:** Validate complete-macro-round proof, pending qualification, lead parity, receipts, and zero-or-one settlement.
- **Cutover step:** Replace victory evaluation and settlement publication in the atomic owner switch.
- **Rollback step:** Restore the detached checkpoint before publication and never reverse a committed settlement.
- **Old-path deletion gate:** Delete direct V0.6 audit-to-settlement and duplicate victory writers after exact-once parity.
- **Task scope:** `production_scene_change=false`, `main_change=false`, `dual_write_allowed=false`.

## Acceptance Gate

The future production cutover may begin only after PR #77 lands, this adapter PR is synchronized with that main, all ten domains pass together, and one authorized task replaces the old owners atomically. Every domain has a complete projection, Save, RNG, production-surface, deletion, rollback, and stable-asset-key contract. Every domain has `dual_write_allowed=false`; no compatibility writer or implicit V0.6 Save migration may survive the commit.
