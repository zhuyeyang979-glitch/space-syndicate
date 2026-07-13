# City / Trade Network Runtime Ownership Contract

## SS05-02 status

SS05-02 completed the project identity hard cutover. `CityTradeNetworkRuntimeController` remains the single mutable owner for project sequence, five-slot generation/tombstone state, city/trade-network derivation, payout-source composition, and the domain save envelope. `CityTradeNetworkWorldBridge` remains non-owning.

The long-lived real-main gate now reports **88/88 observed**, **88/88 aligned**, and **0 design decisions**: the prior 68 City/Trade cases plus 20 v0.5 project-identity cases.

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

`product_id` is slot content, not identity. Two production or two demand slots can therefore hold the same product without collision. Ordinary project rank is clamped to I-IV. Contributions at IV can still change shares but cannot create rank V.

Shares always total exactly 10,000 basis points. Integer remainder uses deterministic largest-remainder allocation. A unique highest contributor is the controller; an exact highest-share tie sets `controller=-1`. Contribution time, founder identity, and player index are not tie-breakers.

## Generation and tombstones

An empty slot starts at generation 0. Opening a project increments it to generation 1. Tombstoning:

- sets the old project inactive;
- sets current GDP to zero;
- preserves the old identity and reason in `project_tombstones`;
- clears `active_project` from the slot;
- does not reset the slot generation.

Reopening that slot increments generation, so an old `project_id` is never reused even when the product is identical. Region destruction/revival orchestration will consume this API in SS05-09; SS05-02 establishes the authoritative identity and lifecycle transaction without prematurely rewriting region destruction.

## Ownership

### CityTradeNetworkRuntimeController

- Project sequence, generation registry, and tombstone registry.
- Canonical city normalization into five slots.
- Public slot/project snapshot orchestration.
- Active-city, competition, route, disruption, and refresh derivation.
- Project-share payout-source composition.
- One v0.5 project-domain save envelope.

### CityProductProjectState / CityProductProjectBridge

- Pure stable ID construction and slot normalization.
- Project contribution, rank IV clamp, 10,000bp allocation, and no-controller ties.
- Pure slot resolution, contribution staging, tombstone staging, GDP compatibility projection, and privacy snapshots.
- No Node, Resource, Callable, runtime state, save owner, or world mutation.

### Explicit migration boundary

`CityProjectStateMigrationV04ToV05` is the only reader of legacy project shapes. It may place explicit old project records into deterministic slots once. It never converts `city.owner`, `products`, or `demands` into ownership or shares. Slot overflow is reported as a migration issue instead of silently overwriting state.

### Preserved owners

- `CityDevelopmentRuntimeController`: development legality and settlement planning.
- `CityDevelopmentWorldBridge`: atomic world commit/rollback.
- `GdpFormulaRuntimeController`: current GDP arithmetic until SS05-03.
- `EconomyCashflowRuntimeController`: cadence and payout arithmetic.
- `ProductMarketRuntimeController`: market prices and lifecycle.
- Contract, military, weather, monster, AI, Queue, and Execution retain their existing boundaries.

## Save contract

The Controller writes only `city_trade_network_runtime` with:

- `terms_version = v0.5.project-slots.1`
- `project_schema_version = v0.5`
- `project_sequence`
- `generation_by_slot_id`
- `project_tombstones`
- `project_slot_counts`
- `maximum_project_rank`

It no longer writes a duplicate top-level `city_product_project_sequence`. The old flat key is accepted only by the explicit one-time migration read. Current snapshots, saves, manifests, and reports remain pure data.

## Privacy and text boundary

Public project snapshots expose stable identity, slot, product, direction, rank, active state, and current GDP. They carry `visibility_scope=public`, `presentation_key=ui.city.project.summary`, and an assistive key. They do not expose controller identity, contribution tables, share tables, hidden owner, private targets, private discard, or AI plans.

Private snapshots expose only the current viewer's share, contribution, and controller flag, with `visibility_scope=viewer_private`. Visibility filtering occurs before PlayerText resolution.

## Removed legacy semantics

The following paths are absent from the active project model:

- `district:product:direction` identity.
- `migrate_legacy_city()` owner/product synthesis.
- `apply_development()` as a second mutable writer.
- Earliest-contributor and lower-player-index tie-breaks.
- Owner-only city payout when no project shares exist.
- Duplicate flat project-sequence save output.

The transitional `city.owner` field may remain for domains scheduled after SS05-02, but project identity, shares, control, and payout never read it as authority.

## Route boundary

The existing route contract and refresh order are unchanged: competition, routes, GDP delegation, project allocation, then supply guarantee. Product market refresh remains a separate caller-owned request. `Line2D`, `Curve2D`, `AStar2D`, and `GraphEdit` may assist presentation or authoring but do not own route rules or state.

There is no parallel route engine, project engine, source-level fallback, or second city-network save owner.

Project-local Godot MCP tooling is an editor/development aid and is not a player runtime dependency.
