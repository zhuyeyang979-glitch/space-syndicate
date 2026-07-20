# District Supply Surface Query Cutover

Status: **cut over** on 2026-07-21.

## Atomic scope

This change moves district/region card-rack presentation query and drawer
application out of `scripts/main.gd`. It does not move purchase, quote, discard
or open/close command ownership, and it does not change rack RNG, pricing,
inventory or purchase rules.

## Authority graph

```text
RegionSupply / Pricing / Purchase / Catalog / Inventory / Session
                              +
                 TablePresentationQueryPorts
                              ↓
              DistrictSupplyViewerQueryPort
                              ↓
        full TablePresentationViewModel snapshot
                              ↓
                 GameScreen typed target
                              ↓
              OverlayLayer → DistrictSupplyDrawer
```

The production query node is
`GameRuntimeCoordinator/DistrictSupplyViewerQueryPort`. It is composed by
`GameRuntimeCoordinator.tscn`; it performs no node discovery and has no Main
callback or fallback.

## Viewer authorization and privacy

The envelope is bound to a viewer index and authorization revision. Its scope
is one of:

- `viewer_private`: only when viewer and subject are the authorized local seat;
- `public`: opponent and otherwise unauthorized browsing;
- `closed`: no valid open district or a failed dependency/query.

Private surfaces may include the local player's formatted cash/hand summary and
purchase readiness. Public surfaces are browse-only. They omit opponent cash,
hand/discard state, hidden ownership, AI plans and score metadata. Quote IDs,
fingerprints, bindings, supply revisions and exact internal timestamps are
never carried into the drawer snapshot. Rebinding the viewer or changing the
authorization revision clears an already rendered private drawer immediately.

## Read-only and deterministic behavior

`snapshot_for_viewer()` consumes only current public rack state and authorized
query projections. The focused test compares authoritative state before and
after every query and proves:

- region rack and gameplay RNG/save state are unchanged;
- no price quote is created or renewed;
- inventory and inventory diagnostics are unchanged;
- open/preview presentation selection is unchanged;
- future shuffle-bag order is never exposed.

Opening, hovering, full refresh and repeated query therefore cannot refill or
reshuffle a rack and cannot lock a five-second quote.

## Refresh lifecycle and target

The full table viewmodel contains the `district_supply` envelope. The live
viewmodel intentionally does not. `SpaceSyndicateGameScreen` applies that
envelope through the typed `SpaceSyndicateOverlayLayer` target. Live refreshes
do not clear or reapply an existing drawer.

The Overlay target validates viewer identity, authorization revision and
viewer-private subject identity before applying data. Public card rows cannot
emit `district_supply_purchase_card`, even through double-click or keyboard
confirmation.

## Deleted Main path

The following methods were physically deleted:

- `_refresh_district_supply_overlay`
- `_district_supply_snapshot_source`
- `_district_supply_private_viewer_authorized`
- `_district_supply_public_card_source`
- `_district_supply_card_source`
- `_district_supply_target_kind`
- `_district_supply_purchase_state`
- `_active_card_market_quote`

Main changed from 8,199 to 7,933 physical lines, from 7,012 to 6,760 nonblank
lines and from 556 to 548 methods. Top-level fields, constants and preloads are
unchanged. External Main caller files remain at the pre-task count; the global
budget tool still reports an older 104-versus-102 repository baseline debt,
not an increase from this cutover.

## Verification

- `district_supply_surface_query_cutover_test.gd`: PASS, 38 checks.
- `DistrictSupplySurfaceQueryCutoverBench.tscn`: PASS, 23 checks under Godot
  4.7 MCP using the production scene/session/coordinator/query/target chain.
- `district_supply_drawer_live_refresh_test.gd`: PASS.
- `transient_gameplay_windows_v06_test.gd`: PASS, 42 checks.
- `region_supply_full_randomization_v06_test.gd`: PASS.
- `region_supply_rng_save_roundtrip_v06_test.gd`: PASS.
- `main_runtime_composition_test.gd`: PASS.
- `main_gd_architecture_gate_test.gd`: PASS.
- `ui_text_smoke_test.gd`: PASS.
- `visual_snapshot.gd`: PASS.
- `smoke_test.gd --check-only`: PASS.

The isolated full `smoke_test.gd` run loaded and instantiated `main.tscn`,
entered the main menu, and then timed out at its pre-existing retired fixture
call to `Main._new_game` (`tests/smoke_test.gd:77`). That compatibility entry
was removed by an earlier application-flow cutover and was not restored. The
run reported no district-supply query, target, privacy or scene-composition
failure before the obsolete fixture stopped progression.

Godot MCP reported the pre-existing project warning set, including historical
Unicode/NUL warnings, but no parse or runtime error from the new query, target
or Bench files.

## Remaining debt and next boundary

This cutover deliberately retains the existing Main command routes for drawer
open/close, card preview intent, quote creation, purchase and private discard.
The broad `presentation_action_routing` ledger entry remains pending.

Next: create a typed district purchase/quote/discard intent and command port,
migrate all human and AI consumers, prove exact-once behavior, then physically
delete the remaining Main district-supply action branches in the same change.
