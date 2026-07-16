# Multimodal Route, Warehouse and Waste Runtime Contract v0.6

## Ownership

`RouteNetworkRuntimeController` is the only owner of:

- route legality and stable route identity;
- ordered regions and legs;
- transport mode tags;
- direct-delivery exemptions;
- shared route/facility capacity;
- transfer count and arrival time;
- topology and facility revision invalidation.

It never owns commodity quantity, market demand, backlog, warehouse inventory,
waste, cash, GDP or presentation visibility.

`CommodityFlowRuntimeController` remains the only owner of goods:

- fresh production and one-shot supply;
- allocation to explicit market demand;
- ambient regional consumption;
- colored warehouse inventory and storage debt;
- market backlog;
- waste quantity and Sale Receipts.

`RegionInfrastructureRuntimeController` owns every road, seaport, spaceport and
warehouse facility, including rank, industry color, ownership, lifecycle and
region integrity. WorldBridge code supplies pure facts and atomically applies
an already planned result; it does not choose routes, destinations, storage or
loss.

## Route facts for explicit market demand

Normal market delivery always consumes a route fact, including a canonical
direct-delivery fact when transport infrastructure is exempt.

- Same-region and directly adjacent factory-to-market delivery may use the
  existing direct-delivery exemption.
- Longer land legs require active roads under RouteNetwork rules.
- Sea legs require active seaports and valid water topology.
- Air legs require active spaceports.
- Multimodal routes expose ordered legs, mode tags, transfer count, actual
  arrival time, canonical shortest legal distance and every shared capacity
  resource.

Economic distance premium uses only canonical shortest legal distance. A
detour cannot manufacture a larger premium.

For an eligible source/demand pair, actual route priority remains:

1. commodity-owner expected net cash descending;
2. arrival time ascending;
3. transfer count ascending;
4. stable route ID ascending.

Capacity is reserved from shared route resources once. Parallel flows cannot
each consume the full capacity of the same road, seaport, spaceport or other
bottleneck.

## Ambient consumption is not a routed shipment

Ambient regional consumption uses only same-region or direct-adjacent
land-consumer eligibility. It does not ask RouteNetwork for a road, sea, air or
multimodal candidate and consumes no transport-facility capacity or rent.

The world fact boundary may expose stable adjacency and terrain needed by the
flow owner. It may not derive a second-hop path or convert a chain of adjacent
regions into ambient eligibility.

An optional map arrow for adjacent ambient flow is presentation of a committed
one-hop result. It is not a route object and does not alter the economy.

## Six-color warehouses

Each region has one warehouse slot for each v0.6 industry:
`life`, `energy`, `industry`, `technology`, `commerce` and `shipping`.
A generic-mana warehouse card chooses one industry at resolution. An uncolored
warehouse request fails closed.

A warehouse accepts only commodities whose catalog industry equals its
`industry_id`. Capacity, inbound throughput and outbound throughput are
independent per warehouse facility.

| Rank | Capacity | Inbound / outbound per minute | Storage rent per minute |
|---|---:|---:|---:|
| I | 200 | 50 | 25 bp of product base price per stored unit |
| II | 400 | 100 | 20 bp |
| III | 700 | 175 | 15 bp |
| IV | 1100 | 275 | 10 bp |

Region integrity scales current inbound and outbound throughput. It does not
silently delete inventory already stored and does not turn stored inventory
into waste. Warehouse destruction clears its inventory exactly once under the
facility-destruction receipt lineage.

## Goods order

For each commodity and fixed-point tick:

### 1. Explicit markets

Fresh output and matching warehouse inventory may satisfy concrete market
steady demand and then allowed backlog recovery. Every delivery is constrained
by:

- the selected legal route and all shared route capacity;
- source availability;
- warehouse outbound throughput when the source is stored inventory;
- market facility processing capacity;
- steady-before-recovery priority.

Stored inventory is eligible only for explicit market demand. It is never
automatically released for low-value ambient consumption.

### 2. Ambient regional consumption

Only fresh output left from phase 1 may be consumed by the source region or a
directly adjacent land region. This phase consumes no warehouse inventory.

### 3. Warehouse inbound

Fresh output left from phases 1 and 2 attempts storage in the best reachable
matching-industry warehouse. The selected inbound route is constrained by:

- current route legality and capacity;
- warehouse inbound throughput;
- free inventory capacity;
- warehouse lifecycle and regional integrity.

Warehouse ordering must be deterministic and auditable. It may optimize owner
net value, arrival time and capacity, but final ties use stable warehouse and
route IDs. Dictionary or scene-tree order cannot choose the winner.

### 4. Waste

Any fresh quantity still unmatched after storage is committed as waste and
disappears. This includes continuous production and already-materialized
one-shot supply. Neither form becomes future inventory.

The same milliunit cannot be sold, ambient-consumed, stored and wasted in more
than one phase.

## Storage settlement

Storage rent starts when quantity enters inventory. Inventory entry itself
creates no commodity GDP and no sale.

When stored goods later satisfy explicit market demand:

- the exact stored quantity is removed once;
- outbound throughput and route capacity are consumed once;
- accrued storage debt is settled through the same market Sale Receipt;
- the commodity owner receives the recorded net cash;
- applicable production-facility, warehouse, transport and market rents remain
  cash transfers;
- commodity gross value is the only GDP value.

The active bridge keeps cash application atomic. A rejected cash/rent batch
does not remove inventory or advance storage debt lineage.

No UI or AI action manually creates a one-to-one order between an inventory
bucket and a market. Once a legal profitable/canonical route exists, automatic
CommodityFlow allocation may use that inventory.

## Waste settlement and migration

Waste:

- produces no cash, GDP, asset, mana or rent;
- is not a Sale Receipt;
- cannot be restored as inventory;
- cannot be sold on a later tick;
- may emit only a pure-data `FlowLossEvent`.

Player-facing surfaces call it **浪费产能** and show whole-unit summaries such
as 已售出、区域基础消费、已入库 and 已浪费. They do not display `backpressure`,
milliunits, owner fields or internal loss-event lineage.

Legacy continuous `backpressured_milliunits_by_source` may be copied once into
cumulative waste history by the CommodityFlow save migration. RouteNetwork and
RegionInfrastructure do not participate in that migration, and no legacy
quantity becomes a route claim or warehouse bucket.

## Capacity sharing across phases

Explicit market delivery reserves route capacity before warehouse inbound.
Ambient consumption consumes no route capacity. Warehouse inbound uses only
capacity left after explicit market delivery.

Warehouse outbound and inbound are distinct throughput budgets unless an
authored Resource explicitly defines a shared budget. Market processing
capacity is always the final limit for steady plus recovery consumption.

Topology or facility revision changes invalidate route candidates before the
next flow plan. Destroyed paths disappear; the flow owner does not retain a
stale route merely to consume backlog or save surplus.

## Save and privacy

Route candidates and route caches are derived and rebuilt from restored
RouteNetwork and RegionInfrastructure facts. Stable route identity and revision
continuation follow the RouteNetwork save contract.

CommodityFlow saves:

- colored warehouse buckets and exact milliunit quantities;
- commodity owner in the private authoritative bucket;
- source and inbound route lineage;
- inbound/outbound fixed-point remainders;
- storage-rent rate, debt and remainder;
- pending one-shot exact-once state;
- waste totals and migration lineage;
- recent committed public flow summaries used by an optional short observation
  window.

Loading does not release inventory, duplicate rent, consume backlog or route
the same goods again.

Public inventory and flow projections remove commodity-owner identity, private
source installation, private debt details and supplier identity. Public
facility ownership, rank, industry color, capacity status and legally visible
actual flow may remain visible.

Map route visibility is a local presentation preference. Whether routes are
shown, hidden or filtered by commodity never changes route derivation,
allocation, AI behavior, save economics or revisions.

## Focused acceptance

The route/warehouse gate must prove:

- warehouse inventory and fresh output can satisfy explicit market demand and
  backlog under the same route constraints;
- ambient consumption never drains inventory;
- explicit market routes reserve shared capacity before storage routes;
- surplus enters a reachable matching warehouse before any waste is recorded;
- a full, wrong-color, unreachable or throughput-exhausted warehouse rejects
  only the unavailable quantity, which then becomes waste;
- waste produces no cash, GDP, asset or rent;
- destroyed warehouse inventory is cleared exactly once;
- route ties are stable and a detour cannot increase distance premium;
- save/load preserves inventory, rent, waste and route lineage without
  duplicate movement;
- route presentation visibility has no economic effect and reveals no private
  supplier identity.
