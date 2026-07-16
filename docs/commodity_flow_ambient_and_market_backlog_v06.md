# Commodity Flow Ambient Consumption and Market Backlog v0.6

## Purpose

This is the normative integration contract for ambient regional consumption,
concrete market-demand backlog, automatic allocation, warehouse buffering and
waste.

The narrower component contracts are:

- `commodity_flow_local_baseline_demand_v06.md`;
- `installed_commodity_continuous_economy_runtime_contract.md`;
- `multimodal_route_warehouse_runtime_contract.md`;
- `ai_v06_facility_bootstrap_contract.md`.

If an older active document describes isolated-factory self-sale,
isolated-market turnover, disappearing market demand or continuous
backpressure, that statement is stale and must not remain an implementation
oracle.

## Economic model

```text
factory production
        |
        v
explicit concrete market demand
  steady first, backlog recovery second
        |
        v
ambient regional consumption
  fresh output only, same region or adjacent land consumer
        |
        v
matching reachable warehouse
        |
        v
waste and disappearance
```

Warehouse inventory joins only the explicit-market phase. It does not flow into
ambient consumption.

## Authority matrix

| Domain | Sole authoritative owner | Explicit exclusions |
|---|---|---|
| Production/demand rates, fixed-point allocation, market backlog, inventory, waste, Sale Receipts | `CommodityFlowRuntimeController` | No duplicate state in Main, UI, AI or WorldBridge |
| Route legality, ID, mode, capacity, arrival time | `RouteNetworkRuntimeController` | No commodity quantity, backlog or visibility preference |
| Facilities, rank, ownership, lifecycle, integrity | `RegionInfrastructureRuntimeController` | No demand backlog or goods |
| Commodity price, trend, finance state | `ProductMarketRuntimeController` | No market-facility demand installation or backlog |
| Commodity/card installation transaction | Existing CardFlow and inventory owner | No flow allocation |
| Pure world fact capture and atomic application | WorldBridge surfaces | No economic planning |
| Public/player summaries | ViewModel/public snapshot services | No mutation |
| AI intent choice | `AiRuntimeController` | No economic or card state |

## Authored data

The implementation must add these terms to a Ruleset, Balance Resource or
commodity data Resource. They must not be constants in `main.gd`.

| Field | Scope | Initial/default contract |
|---|---|---|
| `ambient_consumption_units_per_minute` | each active commodity | Positive low value; first test may use one uniform value |
| `ambient_consumption_value_basis_points` | ruleset/balance | Low-value multiplier below normal market value |
| `market_backlog_horizon_seconds` | ruleset/balance | `120` |
| `market_backlog_recovery_extra_basis_points` | ruleset/balance | `10000` |
| `commodity_flow_terms_version` | ruleset/save | Monotonic schema/terms version |

The commodity field is resolved by stable `commodity_id`. Display names and
Chinese text are never balance keys.

## Ambient regional consumption

Every surviving, non-ruin region produces one ambient demand claim for every
active commodity each authoritative tick.

Eligible supply is fresh output left after explicit market allocation:

- same-region factory output; or
- output from a directly adjacent region when the consuming region is land.

Illegal sources include:

- a second-hop or more distant factory;
- any sea, air or multimodal delivery;
- warehouse inventory;
- output already committed to a market, storage or waste.

Ambient consumption needs no market, road, seaport, spaceport or warehouse.
Unfulfilled due expires at tick end and is never backlog.

The allocation is deterministic and fair across competing sources. Stable
source IDs plus a saved rotating residual cursor prevent Dictionary order and a
permanent first-source advantage.

Committed ambient kinds are:

- `ambient_local_consumption`;
- `ambient_adjacent_land_consumption`.

Both produce low commodity-owner cash and commodity GDP in the actual consuming
region. Neither produces distance premium, market rent, transport rent or a
fabricated market/route identity.

## Concrete market demand

High continuous market demand exists only when a specific commodity demand
installation is attached to an active market facility.

A market with only an industry color does not create high demand for every
commodity in that industry.

The authoritative key is:

```text
(market_facility_id, commodity_id)
```

Each key owns:

```text
steady_demand_rate_milliunits_per_minute
unmet_backlog_milliunits
backlog_cap_milliunits
backlog_recovery_budget_milliunits
steady_due_remainder
recovery_budget_remainder
backlog_revision
```

Backlog begins accruing even when:

- no matching factory exists;
- no legal route exists;
- production is insufficient;
- matching warehouse inventory is empty.

Backlog itself has no economic settlement.

## Backlog cap

The cap is based on normal installed demand after the market rank's ordinary
capacity limit at full integrity, before temporary damage or short-lived
efficiency modifiers:

```text
normal_rate
= capacity_limit(installed_concrete_demand, market_rank)

backlog_cap_milliunits
= floor(
     normal_rate_milliunits_per_minute
     * market_backlog_horizon_seconds
     / 60
   )
```

Temporary damage lowers current processing but does not erase backlog or
shrink the cap below valid existing backlog.

## Fixed-point tick

At tick start, for each market/commodity record:

```text
steady_due
= integrate(
     current_effective_steady_rate_milliunits_per_minute,
     tick_milliseconds,
     steady_due_remainder
   )

recovery_rate_limit
= current_effective_steady_rate_milliunits_per_minute
 * market_backlog_recovery_extra_basis_points
 / 10000

recovery_budget_milliunits
= integrate(
     recovery_rate_limit,
     tick_milliseconds,
     recovery_budget_remainder
   )

recovery_request
= min(
     old_backlog,
     recovery_budget_milliunits,
     market_processing_capacity_remaining_after_steady
   )

total_market_request
= steady_due + recovery_request
```

After route- and source-constrained allocation:

```text
fulfilled_steady
= min(actual_delivered, steady_due)

fulfilled_recovery
= min(
     max(0, actual_delivered - fulfilled_steady),
     old_backlog
   )

new_backlog
= clamp(
     old_backlog
     - fulfilled_recovery
     + (steady_due - fulfilled_steady),
     0,
     backlog_cap_milliunits
   )
```

Current steady demand is always fulfilled before old backlog. Supply equal to
steady demand holds old backlog constant. Only additional delivery may reduce
it.

Demand clipped only because `backlog_cap_milliunits` was reached expires as
unmet demand. It is not a sale, warehouse transfer or commodity waste and has
no economic settlement.

## Capacity and routes

Explicit market delivery may use fresh output and exact-commodity warehouse
inventory. It is constrained by:

- market processing capacity;
- route legality and all shared route capacity;
- warehouse outbound throughput for stored sources;
- source quantity;
- current facility and region lifecycle.

Route candidates retain the current deterministic ordering:

1. expected commodity-owner net cash descending;
2. arrival time ascending;
3. transfer count ascending;
4. stable route ID ascending.

Market processing remains the final hard ceiling. If installed steady demand
already fills capacity, there is no recovery headroom until effective capacity
increases, normally through a market upgrade or repaired integrity.

When several commodities share one market facility, steady processing is
reserved across the complete commodity set before recovery. Proportional
capacity allocation and stable IDs prevent Dictionary order from giving one
commodity permanent priority. Recovery for one commodity never substitutes for
another commodity's backlog.

## Backlog lifecycle

- A valid concrete demand installation starts steady demand immediately.
- No supply or no route grows backlog up to its cap.
- Backlog is commodity-specific and cannot substitute.
- Backlog has no cash, GDP, asset or rent.
- Only delivered and consumed quantity emits a Sale Receipt.
- Market rent applies only to actual delivered quantity.
- Market damage reduces current processing; it does not settle backlog.
- Market destruction clears all records for that facility ID exactly once.
- Pause freezes steady generation, recovery and backlog revisions.
- A rebuilt market has a new ID and starts with zero backlog.

## Full automatic order

For each commodity and tick:

1. Build explicit market steady and recovery requests.
2. Allocate fresh output and warehouse inventory through legal capacity-limited
   routes.
3. Apply actual market deliveries to steady first and recovery second.
4. Allocate still-fresh output to same-region/direct-adjacent-land ambient
   claims.
5. Route still-fresh output to matching warehouses under route, inbound and
   capacity limits.
6. Record all remaining fresh output as waste and remove it.
7. Atomically apply Sale Receipts and storage cash effects.
8. Commit backlog, inventory, waste, remainders, exact-once lineage and public
   flow summaries.

UI open state, map route visibility and AI inspection never affect these steps.

## Warehouse rule

Warehouse inventory is strategic buffer stock.

- It can satisfy explicit current market demand and market backlog.
- It cannot satisfy ambient consumption.
- Entering storage creates no GDP.
- Storage rent follows the existing authoritative warehouse terms.
- Outbound sale uses the same normal Sale Receipt as other market delivery.
- Inventory cannot be sold, stored and wasted twice.

Fresh surplus attempts a reachable matching-industry warehouse before waste.

## Waste rule

Output not consumed or stored in the current tick becomes waste and disappears.

The owner records:

```text
wasted_continuous_milliunits_by_source
wasted_continuous_milliunits_per_minute_by_source
cumulative_wasted_milliunits_by_source
cumulative_wasted_milliunits_by_commodity
cumulative_wasted_milliunits_by_region
waste_revision
```

Waste has no Sale Receipt and no economic benefit. A pure-data `FlowLossEvent`
is permitted only for telemetry and presentation.

Legacy `backpressured_milliunits_by_source` may migrate once into cumulative
waste history. It never becomes inventory or pending supply, and new saves must
not write the legacy field.

## Market-first integration scenario

The required end-to-end scenario is:

1. a random regional rack reveals a market facility card;
2. a player builds the market before any matching factory;
3. a concrete commodity demand is installed in that market;
4. backlog grows while supply or routes are absent;
5. a matching factory, stored inventory or legal route later becomes
   available;
6. automatic flow serves current steady demand;
7. extra allowed delivery gradually serves old backlog;
8. backlog reaches zero;
9. consumption returns to the steady rate.

The scenario does not require shared ownership, manual orders, player-drawn
routes, UI reopen or a persistent market window.

## Save contract

The flow save section must restore exactly:

- concrete installations and generations;
- ambient integration remainders and fairness cursors;
- `ambient_revision`;
- market backlog records, cap, recovery budget/remainders and revision;
- warehouse inventory, rent and throughput remainders;
- current and cumulative waste;
- recent Sale Receipts and short-window public flow summaries;
- receipt, batch, flow, backlog and waste revisions;
- exact-once transaction lineage;
- terminal legacy migration version.

Load is non-advancing. It must not:

- generate another steady-demand tick;
- duplicate a Sale Receipt;
- recompute another backlog value;
- release or reroute inventory;
- restore waste as goods;
- consume gameplay RNG.

## Public and private projection

Market backlog quantity may be public. Its projection may include:

- market facility and region;
- commodity;
- normal demand;
- unmet demand;
- maximum current recovery;
- coarse supply/capacity status;
- public revision.

It excludes:

- supplier identity;
- commodity-owner identity where private;
- private warehouse buckets and debt;
- AI plans and scores;
- source/demand pair candidates;
- fixed-point remainders;
- raw controller or snapshot terminology.

Public actual-flow summaries used for optional route presentation contain only
legally visible committed flow. They do not expose future candidate paths.

## Player-facing vocabulary

Use:

- 区域基础消费
- 市场正常需求
- 市场待满足需求
- 市场追赶消费
- 已售出
- 已入库
- 浪费产能

Do not show:

- backpressure
- milliunits
- recovery basis points
- sink
- source-to-demand pair
- backlog revision
- route candidate
- controller, owner, bridge or raw snapshot/state names.

Suggested market summary:

```text
正常需求：20/分钟
待满足需求：46
当前最多追赶：+20/分钟
当前供给：不足
```

Suggested factory summary:

```text
生产：40/分钟
市场销售：18/分钟
基础消费：6/分钟
入库：10/分钟
浪费：6/分钟
```

## Required focused tests

- `commodity_flow_ambient_consumption_v06_test.gd`
- `commodity_flow_market_backlog_v06_test.gd`
- `commodity_flow_warehouse_then_waste_v06_test.gd`
- `market_before_factory_integration_v06_test.gd`
- `commodity_flow_backlog_save_roundtrip_v06_test.gd`
- `commodity_flow_public_privacy_v06_test.gd`

Old local-baseline and backpressure expectations must be physically removed
from active tests rather than retained as silent compatibility branches.
