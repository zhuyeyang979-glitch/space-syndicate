# Public Gameplay Surface Wiring v0.6

## Purpose

This contract joins three already-owned public facts into the scene-owned game
table without creating another gameplay owner:

1. the viewer-filtered active forced decision;
2. the authoritative `public_bid` phase and its viewer-safe BidBoard data;
3. actual/recent public commodity flow plus public route geometry.

`GameTableViewModelRuntimeService`, `TableSnapshot`, `GameScreen`,
`OverlayLayer`, and `PlanetMapView` only normalize and present those facts.
They do not own decision timing, bids, cash, commodity allocation, route
legality, inventory, or AI state.

## Viewer surface input

The table ViewModel accepts an optional top-level `viewer_surfaces` dictionary:

```gdscript
{
    "table_source": {...},
    "card_surfaces": {...},
    "viewer_surfaces": {
        "active_forced_decision": scheduler.active_decision(viewer_index),
        "public_bid": public_bid_phase_and_viewer_actions,
        "optional_route_presentation": {
            "source_bound": true,
            "public_flow_snapshot": commodity_flow.recent_actual_flow_snapshot(),
            "route_geometry_by_route_id": public_route_geometry,
            "world_effective_seconds": world_effective_seconds,
        },
    },
}
```

The `active_forced_decision` value must already be produced by
`ForcedDecisionRuntimeScheduler.active_decision(viewer_index)`. The table
ViewModel and `TableSnapshot` apply a second allowlist and remove owner index,
source reference, notes, and all handler-private data before the value reaches
`GameScreen`.

If the active decision belongs to another player, the scheduler emits only the
existing `private_forced_decision` waiting hint. The table shows no target,
discard, contract, hand, cash, or owner detail.

## Public bid derivation

An arbitrary candidate dictionary may not create `public_bid`.

`ForcedDecisionRuntimeScheduler.sync_candidates` now accepts a second,
authoritative phase snapshot:

```gdscript
scheduler.sync_candidates(other_candidates, {
    "phase_id": "public_bid",
    "active": true,
    "visible": true,
    "window_sequence": current_window_sequence,
})
```

The scheduler derives the lowest-priority public candidate only when all four
facts are valid. `planning`, `lock`, `resolve`, `idle`, a missing sequence, or
an external forged `public_bid` candidate produces no bid decision.

The full BidBoard appears only when:

- the scheduler selected the derived `public_bid`;
- that decision is visible to the current viewer;
- its presentation surface is `overlay`;
- the viewer-safe bid snapshot still reports `phase_id=public_bid`;
- no higher forced decision is active.

This keeps bid timing and money outside the presentation layer.

## Actual route presentation

`OptionalRoutePublicSnapshot` is the shared fail-closed public projection.
It accepts only:

- the existing CommodityFlow public actual-flow wrapper;
- current/recent committed flow rows;
- geometry keyed by a route ID used by one of those committed rows;
- public region paths or already-projected `Vector2` paths.

Geometry for an unused route ID is discarded even when the upstream
RouteNetwork snapshot contains it. Candidate routes, planned routes, supplier
identity, facility binding, transaction lineage, AI plans, and raw scores are
rejected recursively.

The preferred geometry form is:

```gdscript
{
    "route:<stable-id>": {
        "ordered_region_ids": ["region.a", "region.b", "region.c"],
        "transport_modes": ["land"],
    },
}
```

`PlanetMapView` resolves those public region IDs against the current live map.
It therefore follows map movement, projection, and resizing without storing
screen coordinates in the economy.

The local route view remains hidden by default. Selecting a commodity changes
only local presentation state. Hiding, switching, or reopening the route view
does not advance CommodityFlow, rebuild RouteNetwork, alter AI, or enter the
economic save.

## Required upper-layer injection

The C2 presentation path is complete, but the remaining production composition
must be performed by the current integration owner without adding logic to
`main.gd`:

1. pass the authoritative card-window phase snapshot as the second argument of
   `sync_candidates`;
2. pass `active_forced_decision(viewer_index)` and the viewer's current BidBoard
   snapshot through `viewer_surfaces`;
3. pass `CommodityFlowRuntimeController.recent_actual_flow_snapshot()` and a
   RouteNetwork-derived public `route_id -> ordered_region_ids` projection
   through `viewer_surfaces.optional_route_presentation`.

The RouteNetwork projection may contain several legal routes upstream because
the ViewModel filters it to route IDs referenced by actual committed flow.
Nevertheless, the player-facing `TableSnapshot` contains geometry only for
actual/recent flow.

No second owner, queue, economic ledger, route planner, or hidden-info cache is
permitted.

## Acceptance

The focused gates are:

- `tests/public_gameplay_surface_wiring_v06_test.gd`;
- `tests/transient_gameplay_windows_v06_test.gd`;
- `tests/route_visibility_opt_in_v06_test.gd`;
- `tests/card_presentation_viewmodel_runtime_test.gd`;
- `scenes/tools/PublicGameplaySurfaceWiringV06Bench.tscn`.

They prove:

- viewer filtering survives GameTable ViewModel and `TableSnapshot`;
- public bid is phase-derived and lowest priority;
- planning removes stale bid state;
- another player's private decision suppresses bid without revealing content;
- only one forced surface occupies the 1280×720 table;
- Back cannot bypass the forced surface and focus is restored after resolution;
- routes remain hidden until local opt-in;
- geometry follows live public region positions;
- unused candidate geometry and private owner/AI fields do not reach the table.
