# District Supply Runtime Query Port Cutover

Status: cut over; actor-private capability hardening validated.

## Boundary

`DistrictSupplyRuntimeQueryPort` is the scene-owned, read-only boundary for
non-presentation consumers of the regional rack.

```text
WorldSessionState
RegionSupplyRuntimeController
CardMarketPricingRuntimeController
CardRuntimeCatalogService
CommodityCardInventoryRuntimeController / CardFlow transaction service
GameSessionRuntimeController
                    ↓
DistrictSupplyRuntimeQueryPort
       ├─ AiRuntimeController
       ├─ GameplayBalanceDiagnosticsWorldBridge
       └─ RegionInfrastructureWorldBridge
```

The existing `DistrictSupplyViewerQueryPort` remains the only player-facing
viewer-authorized query. The runtime query is not connected to UI targets.

## Public queries

The port exposes detached current-rack data only:

- public card IDs for a district;
- a current public listing;
- current rack revision;
- current market availability;
- a read-only listing price preview.

It never exposes the shuffle bag or future order and never opens a quote,
refills a slot, advances RNG or mutates purchase state.

## AI-private queries

The AI can ask for its own inventory receive preview and discardable slots by
seat index only while presenting the opaque `DistrictSupplyAiQueryCapability`
issued for that exact AI actor by the production coordinator. Human seats
receive no token, AI actors never share one, and player-roster replacement
rotates the complete set alongside the actor-state capabilities. A token for
AI B cannot query AI A. Missing, forged, stale, cross-actor, human-seat and
finished-session queries fail closed. These results are internal policy facts
and are never routed to presentation. `CommodityCardInventoryRuntimeController`
and its CardFlow transaction service remain the inventory authority; the query
calls the existing `player_snapshot`, `discardable_slots`, and
`region_supply_receive_preview` APIs rather than implementing another planner.

## Deleted Main surface

The cutover physically removes the Main wrappers for:

- district-to-region lookup;
- rack listing/card IDs/revision;
- selected rack choices and card cycling;
- district market availability and listing preview;
- district purchase inventory plan/discard feasibility;
- pending discard lookup;
- the retired facility-only rack source.

AI, region codex and developer diagnostics no longer call these Main methods.
Main's remaining legacy table formatting reads the typed query directly until
that formatting is removed by its own presentation boundary.

## Verification

- `district_supply_runtime_query_port_cutover_test.gd`
- `DistrictSupplyRuntimeQueryPortBench.tscn`
- `main_runtime_composition_test.gd`
- `district_supply_action_port_cutover_test.gd`
- `main_gd_architecture_gate_test.gd`

The actor-scoped focused run passes 31/31 checks
(`20260723-090537-962-district_supply_runtime_query_port_cutover_test-89718267`).
Actor-state regression remains 95/95 and Main composition remains green.

The focused test compares rack save/RNG state, inventory diagnostics and
purchase diagnostics before and after queries. It also scans the production
consumers and Main for the retired dynamic access paths, rejects unauthorized
private reads, and proves the injected AI capability can obtain only internal
feasibility facts.
