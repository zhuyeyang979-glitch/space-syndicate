# Installed Commodity Continuous Economy Runtime Contract v0.6

## Status

This is the active target contract for the v0.6 continuous commodity economy.
It supersedes the former remote-first/local-baseline/backpressure ordering.

The design model is:

- factory = power source;
- automatic commodity transport network = circuit;
- ambient regional consumption = small non-accumulating natural load;
- installed market demand = load that accumulates unmet demand and can catch
  up when supply returns;
- warehouse = battery or buffer;
- output that can neither sell nor enter storage = waste and disappears.

This is one economy. No compatibility branch may keep the former baseline or
backpressure behavior active beside it.

## Single-owner boundaries

### `CommodityFlowRuntimeController`

The sole owner of:

- installed production and concrete commodity-demand rates;
- fixed-point rate, pair, ambient and backlog remainders;
- facility-capacity and region-integrity scaling of installed rates;
- deterministic commodity allocation;
- market backlog by market facility and commodity;
- warehouse commodity inventory and storage debt;
- current and cumulative waste accounting;
- the unique Sale Receipt ledger and receipt-derived GDP observations;
- flow revisions, exact-once lineage and commodity-flow save state.

It does not own player cash records, route topology, facilities, product prices,
regional card supply, presentation or AI decisions.

### Preserved owners

- `RouteNetworkRuntimeController` alone owns route legality, stable route
  identity, modes, capacity, arrival time and route rebuilds.
- `RegionInfrastructureRuntimeController` alone owns factory, market, road,
  seaport, spaceport and warehouse facilities, their rank, ownership,
  lifecycle and regional integrity.
- `ProductMarketRuntimeController` owns commodity prices, trends and financial
  market state only. It never owns facility demand installations or unmet
  market backlog.
- the active CardFlow/commodity-installation path owns card inventory and the
  transaction that installs a concrete commodity rate.
- `CommodityFlowWorldBridge` captures pure facts and atomically applies a
  committed owner plan. It never computes demand, backlog, allocation, storage
  or waste.
- `GameTableViewModel` and public snapshot services format sanitized summaries
  only.

`main.gd`, UI, AI and WorldBridge code must not copy any authoritative flow
state.

## Installed rates and market identity

A production installation is keyed by stable installation ID and contributes
an authored commodity production rate.

A demand installation is attached to one active market facility and one
concrete `commodity_id`. A bare market with only an industry color does not
create high demand for every commodity of that color.

For each `(market_facility_id, commodity_id)`, the flow owner keeps one market
demand record:

| Field | Meaning |
|---|---|
| `steady_demand_rate_milliunits_per_minute` | Current effective installed demand after facility capacity, integrity and active modifiers. |
| `unmet_backlog_milliunits` | Demand from prior ticks that was not actually fulfilled. |
| `backlog_cap_milliunits` | Public data-driven cap derived from normal installed demand, not temporary damage. |
| `backlog_recovery_budget_milliunits` | Extra recovery request allowed for the current committed tick before facility and route bottlenecks. |
| `steady_due_remainder` | Fixed-point remainder for current steady demand integration. |
| `recovery_budget_remainder` | Fixed-point remainder for recovery-rate integration. |
| `backlog_revision` | Monotonic revision for this facility/commodity record. |

No supply, route or factory is required for the record to accrue backlog. The
market facility and a valid concrete demand installation are sufficient.

## Market backlog terms

Ruleset or Balance Resource data owns:

- `market_backlog_horizon_seconds`, initially `120`;
- `market_backlog_recovery_extra_basis_points`, initially `10000`;
- public cap and recovery calculation versions.

`10000` extra basis points means that a normal demand rate `X` may request up to
an additional `X` for recovery, so total consumption may approach `2X` only
when facility capacity, route capacity and supply all permit it.

The cap uses the installed normal demand rate after the market's rank capacity
limit at full integrity, but before temporary damage, weather or other
short-lived efficiency loss:

```text
backlog_cap_milliunits
= normal_capacity_limited_rate_milliunits_per_minute
 * market_backlog_horizon_seconds
 / 60
```

Temporary region damage may reduce current steady generation and recovery
processing, but it does not delete existing backlog or lower the cap in a way
that clips valid prior backlog.

## Fixed-point backlog tick

At the start of one atomic flow tick:

```text
steady_due
= current_effective_steady_rate * tick_duration

recovery_rate_limit
= current_effective_steady_rate
 * market_backlog_recovery_extra_basis_points
 / 10000

recovery_request
= min(
     old_backlog,
     recovery_rate_limit_for_this_tick,
     market_facility_capacity_remaining_after_steady
   )

total_market_request
= steady_due + recovery_request
```

Route planning and source allocation then determine `actual_delivered`.
Current demand always has priority inside the market/commodity record:

```text
fulfilled_steady
= min(actual_delivered, steady_due)

fulfilled_recovery
= min(
     max(0, actual_delivered - fulfilled_steady),
     old_backlog
   )

new_backlog
= old_backlog
 - fulfilled_recovery
 + (steady_due - fulfilled_steady)

new_backlog
= clamp(new_backlog, 0, backlog_cap_milliunits)
```

Consequences:

- no supply or no legal route makes backlog grow;
- supply equal to current steady demand prevents new growth but does not erase
  old backlog;
- supply above steady demand may reduce old backlog gradually;
- backlog cannot be consumed beyond recovery rate, facility processing or
  route capacity;
- backlog never creates cash, GDP, rent, assets or a Sale Receipt by itself;
- different commodities never substitute for one another.

Demand clipped only because the public backlog cap was reached expires as
unmet demand. It is neither a sale nor commodity waste and creates no
settlement event.

Destroying a market facility clears all of that facility ID's backlog exactly
once. Rebuilding creates a new facility identity and no inherited backlog.
Pausing freezes the authoritative economy clock, so no steady due, recovery
budget or backlog revision advances while paused.

## Authoritative per-commodity allocation order

Every fixed-point tick uses the following order.

### Phase 1: explicit market demand

Requests contain current steady demand followed by allowed backlog recovery.
Eligible sources are:

- fresh output of the exact commodity;
- matching warehouse inventory of the exact commodity.

Every delivery requires a route fact from `RouteNetworkRuntimeController`,
including its legal direct-delivery representation where applicable. Candidate
routes use existing ordering:

1. commodity-owner expected net cash descending;
2. arrival time ascending;
3. transfer count ascending;
4. stable route ID ascending.

Shared route, facility, warehouse-outbound and market-processing capacity are
hard limits. Actual consumption emits normal market Sale Receipts and may pay
commodity cash, commodity GDP, applicable production-facility rent, market
rent, transport rent and storage charges. Rent is a cash transfer, not a
second GDP event.

When several commodity records share one market, the controller reserves the
facility's steady capacity across the complete set before assigning recovery
headroom. Proportional allocation and stable IDs prevent commodity Dictionary
order from taking the remaining recovery capacity.

### Phase 2: ambient regional consumption

Only fresh output not used in phase 1 is eligible. Warehouse inventory is
excluded.

The consumer may be the source region or a directly adjacent land region.
There is no second hop, route facility, route rent, market rent or distance
premium. Actual consumption emits
`ambient_local_consumption` or
`ambient_adjacent_land_consumption` at the low authored value.

Unfulfilled ambient demand expires at the end of the tick.

### Phase 3: warehouse

Fresh output still unused after phases 1 and 2 attempts to enter the best
reachable matching-industry warehouse. Storage is bounded by:

- route legality and shared route capacity;
- warehouse industry color;
- inbound throughput;
- remaining physical capacity;
- active facility and region lifecycle.

Entering storage produces no commodity GDP and no sale. Storage fee accounting
begins under the existing warehouse rules.

### Phase 4: waste

Fresh output still unused and unstored is committed as waste and disappears.
It is not inventory and can never be sold later.

Waste produces no cash, GDP, asset, mana, market rent, route rent or warehouse
rent. It is never a Sale Receipt. A pure-data `FlowLossEvent` may describe the
loss for presentation and telemetry, but it must not enter any settlement
ledger.

One milliunit can be sold, ambient-consumed, stored or wasted exactly once.

## Waste state and migration

The active owner records:

| Field | Meaning |
|---|---|
| `wasted_continuous_milliunits_by_source` | Continuous output wasted in the most recently committed accounting interval. |
| `wasted_continuous_milliunits_per_minute_by_source` | Current player-summary waste rate derived from the committed observation window. |
| `cumulative_wasted_milliunits_by_source` | Exact cumulative waste by production installation. |
| `cumulative_wasted_milliunits_by_commodity` | Exact cumulative waste by commodity. |
| `cumulative_wasted_milliunits_by_region` | Exact cumulative waste by source region. |
| `waste_revision` | Monotonic revision of committed waste state. |

Player-facing whole-unit summaries such as
`cumulative_wasted_units_by_commodity` are derived projections. They do not
replace fixed-point authority.

Legacy `backpressured_milliunits_by_source` is accepted only by one explicit
save migration:

1. validate the legacy field and migration source version;
2. copy its historical non-sale quantity into cumulative waste history;
3. record a terminal migration version/lineage;
4. never create warehouse inventory, pending supply or a saleable claim;
5. omit the legacy field from every newly written save.

A payload containing both unmigrated legacy backpressure and authoritative new
waste state is ambiguous and must fail closed. No runtime path may continue to
write backpressure after migration.

## Sale Receipt and FlowLoss boundaries

Normal market receipts record stable market, source, route, pricing and rent
lineage. Ambient receipts record the consuming region and ambient kind but have
empty market and route identity. Warehouse entry and waste emit no Sale
Receipt.

Only units actually consumed produce:

- commodity-owner cash;
- consuming-region commodity GDP;
- applicable facility rents for normal market delivery;
- observer intents bound to the unique receipt ID.

Public receipt projection removes commodity-owner identity, private
installation IDs, warehouse-owner private debt detail and rent recipients as
required by viewer policy. Public backlog may show facility, commodity and
quantity, but never supplier identity.

## Atomic commit order

1. Capture immutable RegionInfrastructure, ProductMarket and RouteNetwork
   facts.
2. Build all market records, backlog deltas, source allocations, storage
   changes, waste changes and receipt/loss batches without mutating live state.
3. Validate cash and rent effects against cloned player records.
4. Apply the cash batch atomically through the non-owning bridge.
5. Commit fixed-point remainders, backlog, inventory, waste, sequences and
   revisions exactly once.
6. Publish sanitized receipt, loss and summary projections.

A rejected batch leaves cash, backlog, warehouse inventory, waste totals,
remainders, receipt sequence and revisions unchanged.

## Privacy

Viewer-safe flow snapshots may expose public market backlog, commodity,
consuming region, facility capacity status and legally visible committed flow.
They must remove supplier identity, private commodity ownership, source
installation identity, warehouse-owner private debt detail, rival cash/hand
state, AI plans and all fixed-point remainder or pair-allocation internals.

Public backlog never implies who will supply it. Presentation and AI adapters
consume these sanitized owner projections and cannot request a richer snapshot
merely because route lines are visible.

## Save boundary

The CommodityFlow save section contains:

- installations, generations and installation exact-once journals;
- rate, route-pair, ambient, steady-demand and recovery-budget remainders;
- market backlog records and revisions;
- warehouse inventory, throughput/rent remainder and exact-once lineage;
- current and cumulative waste fields;
- recent Sale Receipts and receipt/batch sequences;
- recent public flow summaries required for short-window route presentation;
- one-time migration lineage.

Loading must not advance time, generate another steady-demand tick, duplicate a
Sale Receipt, release inventory, clear backlog or recompute a different state.
All payloads are recursively pure data.

## Verification gate

The active focused gates must replace old baseline/backpressure oracles and
prove:

- market-first installation accrues concrete commodity backlog without supply;
- steady demand precedes recovery and recovery respects every capacity;
- equal steady supply leaves old backlog unchanged;
- excess supply drains backlog gradually and stops at zero;
- ambient consumption exists without markets, is local/adjacent-land only and
  never accumulates;
- warehouse inventory serves explicit market demand but never ambient demand;
- surplus stores before waste;
- waste has no economic settlement;
- legacy backpressure migrates once into non-saleable waste history;
- save/load preserves backlog, inventory, waste, remainders and exact-once
  sequences;
- public snapshots expose no supplier identity, private owner, hand, cash or AI
  scoring.
