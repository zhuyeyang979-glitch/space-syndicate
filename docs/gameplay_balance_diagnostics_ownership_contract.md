# Gameplay Balance Diagnostics Ownership Contract

## Sprint 62 Status

Gameplay balance diagnostics and development-route metadata are cut over from
`main.gd`. The runtime composition is:

- `RuntimeBalanceModel`: existing formula owner for balance gradients, prices,
  geometry, movement, damage, and statistics-hub calculations.
- `GameplayBalanceDiagnosticsRuntimeService`: read-only classification,
  aggregation, card budgets, ecosystem reports, and developer snapshots.
- `GameplayBalanceDiagnosticsWorldBridge`: non-mutating pure-fact adapter for
  cards, roles, products, monsters, districts, supply, and Eligibility facts.
- `DevelopmentRouteCatalogResource`: Inspector-editable source for the seven
  route profiles.

The diagnostics service is not a second balance engine. It may call
`RuntimeBalanceModel`, but it may not copy its formulas or mutate gameplay.

## Development Routes

The v0.4 catalog contains, in stable sort order:

1. `city_growth`
2. `contract_route`
3. `finance_speculation`
4. `monster_pressure`
5. `intel_supply`
6. `direct_interaction`
7. `tactical_support`

Each route Resource owns only `route_id`, display text, goal, play pattern,
counterplay, AI planning hint, strategy labels, baseline requirement, and sort
order. It does not own card legality, AI scoring, settlement, prices, GDP, or
supply selection.

## Pure Data Boundary

World snapshots, reports, manifests, and debug snapshots may contain only
`Dictionary`, `Array`, `String`, numeric values, `Bool`, and `null`. They must
not contain `Node`, `Object`, `Resource`, or `Callable` values.

Public and developer-safe snapshots must not include hidden owner identity,
private targets, private discards, opponent hands, or AI private plans. New
world facts are added to the WorldBridge only after this boundary is covered by
the existing `BalanceRuntimeBridgeBench`.

Implicit report requests reuse one pure-data world snapshot within the same
Godot process frame and sample mode. An explicit `refresh_world_snapshot()`
always rebuilds the facts. This cache is diagnostics-only: it does not retain
gameplay objects, mutate the world, or cross frame boundaries.

## Runtime Consumers

- `DeveloperBalancePanel` receives a service reference and requests a pure-data
  panel snapshot.
- Card Codex reads route labels, budget bands, and supply layers from the
  service.
- Product Codex reads product ecosystem diagnostics from the service.
- Bestiary reads monster ecology diagnostics from the service.
- `AiRuntimeController` reads route metadata and pressure reports from the same
  service; AI decision ownership remains in the AI controller.

## Deleted Main Ownership

Sprint 62 removes the `main.gd` families that owned development-route profiles,
card strength budgets, route audits, pressure reports, direct-interaction
reports, role reports, monster ecology, product ecology, supply/product audits,
card one-glance reports, temporary-economy diagnostics, resolution coverage,
and developer statistics snapshots.

No compatibility wrapper or main fallback is retained. Tests call the
Coordinator or the Diagnostics Service directly.

## QA Gate

`BalanceRuntimeBridgeBench.tscn` remains the single balance QA bench. It keeps
the original source-mode parity cases and adds at least 32 live diagnostics
cutover cases. Output is written to:

- `user://space_syndicate_design_qa/gameplay_balance_diagnostics/manifest.json`
- `user://space_syndicate_design_qa/gameplay_balance_diagnostics/report.md`
- `user://space_syndicate_design_qa/gameplay_balance_diagnostics_sprint_62.png`

City / Trade Network characterization and hard cutover are complete as of
Sprint 64. `CityTradeNetworkRuntimeController` now owns derived network state
and route/refresh orchestration; balance diagnostics remain read-only consumers
of its pure-data snapshots.
