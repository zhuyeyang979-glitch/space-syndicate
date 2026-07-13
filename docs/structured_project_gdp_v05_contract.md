# Structured Project GDP v0.5 Contract

## Purpose

SS05-03 replaces whole-city GDP splitting with deterministic, project-keyed receipts. GDP is produced by a concrete production, demand, or commerce project, or by an explicitly neutral adjustment. Attribution never relies on a city founder, city owner, project controller, localized text, or UI state.

## Source of truth

- Parameters: `res://resources/economy/space_syndicate_gdp_formula_v05.tres`
- Formula owner: `GdpFormulaRuntimeController`
- World-fact and refresh owner: `CityTradeNetworkRuntimeController`
- Pure project-share transform: `CityProductProjectState`
- Cash cadence and payout arithmetic: `EconomyCashflowRuntimeController`

The v0.4 GDP Profile is historical evidence only. Missing or invalid v0.5 Profile/catalog data fails closed; there is no runtime fallback.

## Receipt row schema

Every row contains only pure data and includes:

- `receipt_id`
- `region_id`
- `project_id`, `slot_id`, `project_generation`
- `product_id`, `industry_id`, `direction`
- `source_kind`
- `gross_gdp_per_minute`
- `penalty_gdp_per_minute`
- `net_gdp_per_minute`
- `visibility_scope`

Production, demand, and commerce rows require a live stable project identity. Unknown products, missing industries, invalid directions, or duplicate receipt IDs fail closed. Legacy bonuses are emitted as explicit neutral rows with no project identity.

## Arithmetic and pressure

The Inspector profile retains characterized production, demand, commerce, and pressure parameters while removing `minimum_city_gdp`. Pressure is allocated deterministically across positive gross rows by proportional gross and stable receipt ID. Net GDP is clamped at zero. Excess pressure is reported as `unabsorbed_penalty`; it does not create negative GDP or hidden debt.

## Attribution and conservation

Each project row is split using that project's share basis points. Every player allocation is floored independently. The remaining integer amount is a neutral remainder for that receipt. Explicit-neutral rows remain neutral.

Required identities:

```text
sum(row.net) = region_gdp
sum(rows for project) = project_gdp
sum(player attributions for row) + neutral remainder = row.net
sum(all player attributions) + sum(all neutral) = region_gdp
```

Cashflow source identity is `receipt_id + player_index`. Exact source identity survives payout planning and fractional-remainder carry; a city owner or aggregate player key is not a payout source.

## Lifecycle

- Inactive or destroyed regions emit no GDP rows.
- Tombstoned projects emit no current GDP.
- Reopened slots use a new project generation and therefore new receipt IDs.
- Refresh order is competition, routes, GDP rows, attribution, then supply guarantee.
- Automatic routes and realtime cashflow remain active.

## Visibility

Formula rows are public economic evidence, but private share attribution is viewer-scoped. Public snapshots may show region/project/product/industry/direction and aggregate GDP. They must not include controller identity, contribution/share tables, hidden owner, private targets, private discard, or AI plans.

## Non-goals

SS05-03 does not implement victory qualification, six-industry capacity aggregation, contracts, intelligence tracking, card-window migration, or the production-wide v0.5 switch. Those consumers must use this receipt contract in later gates.
