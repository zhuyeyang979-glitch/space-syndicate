# SS06-03 Multimodal Route And Warehouse Runtime Contract

## Ownership

`RouteNetworkRuntimeController` is the only owner of v0.6 route legality, stable route identity, direct-delivery exemptions, multimodal path derivation, facility bottlenecks, arrival estimates and topology-revision rebuilds. It never owns goods, cash, GDP or inventory.

`CommodityFlowRuntimeController` remains the only owner of installed commodity rates, fixed-point many-source/many-sink allocation, warehouse inventory, backpressure, one-shot overflow loss and Sale Receipts. `RouteNetworkWorldBridge` and `CommodityFlowWorldBridge` expose pure world facts and do not choose routes or mutate economic state.

The retired `CityTradeNetworkRuntimeController` and `CityTradeNetworkWorldBridge` are non-production evidence shells. They contain no project, route, cashflow or save algorithm and are not composed under `GameRuntimeCoordinator`.

## Route Rules

- Same-region and directly adjacent factory-to-market delivery is legal without transport facilities or transport rent.
- Longer land legs require active roads at both endpoints.
- Sea legs require active ports at both endpoints and a water-touching adjacency.
- Air legs require active spaceports at both endpoints.
- A route records ordered regions, ordered legs, a set of transport-mode tags, actual distance, canonical shortest legal distance, transfer count, arrival time, facility IDs and shared capacity resources.
- Product price uses only the canonical shortest legal distance. A longer actual route cannot manufacture extra distance premium.
- Actual route priority is commodity-owner expected net cash descending, arrival time ascending, transfer count ascending, then stable route ID.
- Shared facilities are capacity resources. Multiple flows cannot independently consume the full capacity of the same road, port or spaceport in one tick.
- Region or facility revision changes invalidate the derived route cache. Destroyed paths disappear and subsequent flow queries rebuild from current facts.

## Six-Color Warehouses

Each region has one warehouse slot for each v0.6 industry: `life`, `energy`, `industry`, `technology`, `commerce`, and `shipping`. A generic-mana warehouse card must choose one industry when it resolves. An uncolored warehouse action fails closed.

A warehouse accepts only commodities whose catalog industry equals its own `industry_id`. Inventory capacity, inbound throughput and outbound throughput are independent for each colored warehouse. I-IV defaults are:

| Rank | Capacity | Inbound / outbound per minute | Storage rent per minute |
| --- | ---: | ---: | ---: |
| I | 200 | 50 | 25 bp of product base price per stored unit |
| II | 400 | 100 | 20 bp |
| III | 700 | 175 | 15 bp |
| IV | 1100 | 275 | 10 bp |

Region integrity scales new inbound and outbound throughput. It does not silently delete inventory already stored. Warehouse destruction clears its inventory exactly once.

## Storage And Settlement Order

1. Storage rent starts accruing as soon as goods enter a warehouse. The commodity owner is the payer and the warehouse owner is the recipient; no inventory entry means no storage rent.
2. Warehouse inventory may flow toward matching demand, bounded by outbound throughput and the selected route.
3. Fresh continuous production and one-shot physical supply compete for legal demand using the same route candidates.
4. Unmatched goods try reachable same-color warehouses, bounded by route capacity, inbound throughput and free inventory capacity.
5. Unstored continuous production becomes backpressure and is never materialized.
6. Unstored one-shot supply is lost exactly once and produces no cash, GDP or mana.
7. Accrued storage debt is deducted from the commodity owner's sale proceeds and paid to the warehouse owner through the same Sale Receipt when goods leave storage.
8. Commodity gross value remains the only GDP value. Facility and warehouse rent are cash transfers and do not create a second GDP or mana event.

The current bridge preserves cash conservation by limiting the total rent paid by a single receipt to its gross cash value. The v0.6 rule that active storage debt may itself trigger immediate bankruptcy remains an explicit SS06-09 integration item; this sprint does not create a second bankruptcy owner.

## Save And Privacy

Route candidates are derived cache and are rebuilt after load. CommodityFlow saves colored warehouse buckets, fixed-point quantities, accrued debt, rent remainder, pending one-shot supplies and exact-once transaction receipts. Public inventory projections remove commodity owner and private source-installation identity. Facility ownership, facility rank, warehouse color and public rent terms remain visible.

All route, inventory, receipt, save and debug payloads contain only Dictionary, Array, String, Number, Bool or null.

## Deferred Map Generation

Procedural region topology remains a separate lower-priority project recorded in `res://docs/roguelike_region_topology_generation_backlog.md`. The future generator must emit the same region adjacency and terrain facts consumed here: an all-land tutorial topology with more regions, followed by irregular country-like polygons and seeded 10%-60% water-area maps. Route and flow controllers must not own polygon generation.
