# City / Trade Network Runtime Ownership Contract

## SS05-03 status

SS05-03 completed the structured project GDP hard cutover. `CityTradeNetworkRuntimeController` remains the single mutable owner for project sequence, five-slot generation/tombstone state, route derivation, structured GDP attribution, payout-source composition, and the domain save envelope. `CityTradeNetworkWorldBridge` remains non-owning.

The long-lived real-main gate now reports **108/108 observed**, **108/108 aligned**, and **0 design decisions**: 68 established City/Trade cases, 20 SS05-02 project-identity cases, and 20 SS05-03 structured-GDP cases. There is no parallel route engine, project engine, or whole-city GDP allocation engine.

## v0.5 project contract

Every buildable region has five canonical slots in this stable order:

1. `production:0`
2. `production:1`
3. `demand:0`
4. `demand:1`
5. `commerce:0`

Stable identity is independent of localized product content:

- Region: `region.0007`
- Slot: `region.0007.slot.production.0`
- Project generation: `region.0007.slot.production.0.project.g1`

`product_id` is slot content, not identity. Two production or demand slots can hold the same product without collision. Ordinary project rank is clamped to I-IV. Contributions at IV can still change shares but cannot create rank V.

Shares total exactly 10,000 basis points. Deterministic largest-remainder allocation produces project shares. A unique highest contributor is the controller; an exact highest-share tie sets `controller=-1`. Contribution time, founder identity, and player index do not break a tie.

## Structured GDP ownership

`GdpFormulaRuntimeController` consumes project-keyed production, demand, and commerce facts and emits public GDP receipt rows. Each row carries stable region, project, slot, generation, product, industry, direction, source kind, gross, pressure, net, and visibility fields.

`CityProductProjectState.attribute_gdp_rows()` is a pure attribution transform. It applies each project's share basis points to that project's own GDP rows, floors every player share independently, and records the integer neutral remainder. It never redistributes a project's GDP through another project, founder, controller, or `city.owner`.

Unassigned bonuses and legacy adjustments are explicit neutral rows. They do not create ownership. A region can have zero GDP; there is no minimum-city floor.

The conservation gates are:

- sum of GDP row net values equals regional GDP;
- rows grouped by `project_id` equal project GDP;
- player attribution plus neutral attribution equals project GDP;
- all project and explicit-neutral totals equal regional GDP.

Realtime cashflow consumes `receipt_id + player_index` attribution source IDs. Fractional cash remainders are stored by source ID, not by city owner or player-only aggregate.

## Refresh order

The authoritative refresh order is:

1. competition facts;
2. automatic trade routes;
3. structured GDP receipt rows;
4. project/player/neutral attribution;
5. supply guarantee.

Product-market refresh remains a separate caller-owned request. Automatic routes and realtime cashflow cadence are preserved.

## Generation and tombstones

An empty slot starts at generation 0. Opening a project increments it to generation 1. Tombstoning deactivates the old project, zeroes its current GDP, records its identity and reason, clears the active slot, and retains the slot generation. Reopening increments generation, so an old `project_id` is never reused.

## Ownership boundaries

### CityTradeNetworkRuntimeController

- Project sequence, generation registry, and tombstone registry.
- Canonical city normalization into five slots.
- Competition, route, disruption, refresh, and structured GDP fact orchestration.
- Project/player/neutral GDP attribution and cashflow-source composition.
- Public/private project, route, and regional GDP snapshots.
- One v0.5 city/trade-network save envelope.

### CityProductProjectState / CityProductProjectBridge

- Pure stable-ID construction and slot normalization.
- Project contribution, rank-IV clamp, 10,000bp allocation, and no-controller ties.
- Pure GDP-row attribution and public/private projection.
- No Node, Resource, Callable, runtime state, save ownership, or world mutation.

### Preserved owners

- `CityDevelopmentRuntimeController`: development legality and settlement planning.
- `CityDevelopmentWorldBridge`: atomic world commit/rollback.
- `GdpFormulaRuntimeController`: structured GDP row arithmetic.
- `EconomyCashflowRuntimeController`: cadence and payout arithmetic over authorized attribution sources.
- `ProductMarketRuntimeController`: market prices and lifecycle.
- Contract, military, weather, monster, AI, Queue, and Execution retain their existing boundaries.

## Save contract

The Controller writes one `city_trade_network_runtime` envelope with:

- `terms_version = v0.5.structured-project-gdp.1`
- `project_schema_version = v0.5`
- project sequence, slot generations, tombstones, slot counts, and rank limit.

City snapshots store `gdp_rows`, project/player/neutral attribution, conservation evidence, and `gdp_cashflow_remainder_by_source_id`. Old remainder keys are accepted only at normalization and are immediately erased. There is no active legacy settlement branch or duplicate top-level project sequence.

## Privacy and text boundary

Public GDP snapshots expose region/project identity, product, industry, direction, public source kind, and aggregate GDP. They never expose controller identity, contribution tables, share tables, private targets, private discard, or AI plans.

Private snapshots add only the current viewer's attribution. Visibility filtering occurs before PlayerText resolution. Raw private ownership data never enters a public receipt, manifest, or report.

## Removed legacy semantics

The active runtime no longer contains:

- `assign_city_gdp`, `gdp_by_player`, or `player_gdp` whole-city allocation;
- `project_gdp_by_player` and player-only remainder maps;
- owner-only city payout or same-owner competition exemption;
- the minimum-40 GDP floor;
- product-based project identity or owner-synthesized project migration;
- duplicate city-owner cashflow sources.

The v0.4 GDP Profile remains only as historical characterization evidence. The composed runtime controller references the v0.5 Profile and has no fallback to v0.4.

Project-local Godot MCP tooling is an editor/development aid and is not a player runtime dependency.
