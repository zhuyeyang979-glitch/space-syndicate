# Legacy Runtime Retirement Contract v0.6

## Purpose

This contract defines when an old runtime surface may be removed without reopening a second owner or breaking a still-live v0.4 compatibility path. A file being absent from `GameRuntimeCoordinator.tscn` is necessary but not sufficient: editor add-ons, tool scenes, tests, reflection, save keys, and indirect `call()`/property forwarding must also be migrated.

## Evidence states

- **production-active**: reachable from `main.tscn`, `GameRuntimeCoordinator.tscn`, `main.gd`, a composed owner, AI, or a production WorldBridge.
- **compatibility-active**: still serves the v0.4 catalog/save/runtime while v0.6 uses a different owner path. It is not safe to delete merely because v0.6 works.
- **historical-QA-only**: absent from player composition but referenced by tests, tool scenes, registries, or the enabled design-QA add-on.
- **orphaned**: only its own definition/scene remains, with no production, add-on, QA, reflection, or save consumer.

Only an orphaned surface may be physically deleted. Historical-QA-only surfaces first require a coordinated evidence migration; stale tests must be rewritten to assert the replacement owner, never satisfied by restoring retired behavior.

## Current v0.6 owner map

| Domain | Production owner / boundary |
| --- | --- |
| Facility roster, rank, region integrity | `RegionInfrastructureRuntimeController` |
| Facility-card composite lifecycle | `GameRuntimeCoordinator.play_v06_runtime_card` → shared CardFlow → `CoreEconomicCardRuntimeAdapterV06` → RegionInfrastructure/CommodityFlow |
| Commodity installation, flow, sale receipt, receipt GDP | `CommodityFlowRuntimeController` |
| Sale-receipt cash application | `CommodityFlowWorldBridge.apply_sale_receipt_batch` |
| Routes | `RouteNetworkRuntimeController` |
| Six-color assets | `PlayerManaRuntimeController` |
| v0.6 cards/cash/hand transaction | `CommodityCardInventoryRuntimeController` + the single `CardFlowTransactionServiceV06` + `CardPlayerStateProductionAdapterV06` |
| Monster roster and v0.6 card lifecycle | `MonsterRuntimeController.prepare/commit/rollback/finalize_unit_card_intent_v06` |
| v0.4 district purchase and hand mutation | `DistrictPurchaseSettlementRuntimeService` + `CardInventoryRuntimeService` (compatibility-active) |
| v0.4 direct-player hand effects | `PlayerHandInteractionRuntimeService` (compatibility-active) |
| Product futures / GDP derivative positions | their composed ProductMarket / CityGdpDerivative controllers (compatibility-active) |
| Player-facing visual events | scenario/main pure-data snapshot → `GameScreen` → `VisualEventLayer` |

There is no universal replacement for every legacy cash mutation yet. Domain owners still write the shared world player record through their existing bridges. Therefore removal of a retired cashflow shell does not authorize deleting player cash fields or active contract, wager, bid, derivative, purchase, or clue-settlement paths.

## Mandatory deletion gate

Every retirement change must prove all of the following in the same change:

1. **Zero production reachability**: no scene instance, preload, typed class reference, `get_node`, dynamic `call`, `set`, property proxy, signal, or save/load callback outside tests/tools/docs.
2. **Replacement is actually consumed**: at least one production callsite reaches the named owner API. Node existence or a debug `authoritative=true` flag is insufficient.
3. **No fallback**: failure of the replacement fails closed; it cannot fall back to the path being removed.
4. **QA/add-on migration**: the enabled `space_syndicate_design_qa` add-on, tool scenes, registries, reflection tests, and layout smoke no longer open or assert the old scene/API.
5. **Save boundary**: old save keys are either rejected or migrated once by the authoritative owner. Deleting a loader without a compatibility decision is forbidden.
6. **Exact-once and rollback evidence**: replacement tests cover duplicate transaction, failed commit, rollback/finalize, checkpoint, and save/load when the domain mutates state.
7. **Privacy evidence**: public output remains recursively free of rival hand/cash, hidden owner truth, and AI private data.
8. **Parse/composition evidence**: Godot 4.7 parse-load passes and a source gate asserts both old-node absence and replacement-node/API presence.

## Retirement batches

### Batch A — production-uncomposed historical owners

The CityDevelopment, CityTradeNetwork, EconomyCashflow, GdpFormula, and IndustryCapacity scenes are absent from current player composition. They may be deleted only after the enabled QA dock and historical tests are migrated to CommodityFlow, RouteNetwork, RegionInfrastructure, PlayerMana, and the current CardFlow composition. CityProductProject helpers can be removed only as part of the same call-graph-closed CityDevelopment batch.

### Batch B — orphan visual queue

**Completed.** `visual_event_smoke_test.gd` now instantiates the production `VisualEventLayer.tscn` and exercises `VisualEventSnapshot` → `set_visual_events` directly. The orphan `VisualEventQueue` script and UID are deleted, and non-historical source/test composition has a zero-reference gate. Event categories and presentation remain owned by the active snapshot/layer path.

### Batch C — live v0.4 effect paths

Do not delete the legacy `monster_card` or `public_facility` dispatch branches while v0.4 catalog cards can still reach them. First prove every production card in those effect families is intercepted by the v0.6 facade, or explicitly reject the old family before player resources commit. The replacement must have real human and AI callers and no legacy fallback.

### Batch D — shared player state

Do not remove `CardInventoryRuntimeService`, `DistrictPurchaseSettlementRuntimeService`, `PlayerHandInteractionRuntimeService`, or direct v0.4 cash adapters until all their real purchase, queue, counter, interaction, derivative, wager, contract, bid, clue, and save consumers have equivalent atomic production owners. `CardPlayerStateProductionAdapterV06` is authoritative for v0.6 CardFlow; it is not evidence that every v0.4 mutation has already migrated.

## Required retirement tests

- owner-composition source gate: old scene/class/callback count zero, replacement scene/API count one;
- human + AI production dispatch for each migrated card family;
- card leaves hand and cash/assets change exactly once; replay causes no second mutation;
- owner commit failure performs explicit compensation or fails before player-state commit;
- save/load round-trip and corrupt snapshot before/after equality;
- CommodityFlow sale receipt → GDP/cash ledger, not direct cash grants;
- monster first summon/duplicate/save-load/privacy through the four-stage owner;
- public recursive privacy scan;
- isolated Godot 4.7 parse-load, followed by the smallest focused replacement-owner suites.

Historical v0.4/v0.5 formulas and ownership documents may remain as archives, but must carry an explicit stale/historical label and must not be treated as production restoration requirements.
