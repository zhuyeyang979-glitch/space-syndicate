# District Supply Runtime Query Port Cutover

Status: cut over locally; no commit or push was requested.

## Boundary

`DistrictSupplyRuntimeQueryPort` is the scene-owned, read-only boundary for
non-presentation consumers of the regional rack.

```text
WorldSessionState
RegionSupplyRuntimeController
CardMarketPricingRuntimeController
CardRuntimeCatalogService
CardInventoryRuntimeService
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
injected by the production coordinator. The capability is identity checked,
rotated whenever the composition is rewired, and additionally requires an
active session and an AI seat. Missing, forged, human-seat and finished-session
queries fail closed. These results are internal policy facts and are never
routed to presentation. `CardInventoryRuntimeService` remains the single
inventory rule owner; the query uses `preview_receive`, not a second planning
or mutation implementation.

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

The focused test compares rack save/RNG state, inventory diagnostics and
purchase diagnostics before and after queries. It also scans the production
consumers and Main for the retired dynamic access paths, rejects unauthorized
private reads, and proves the injected AI capability can obtain only internal
feasibility facts.
