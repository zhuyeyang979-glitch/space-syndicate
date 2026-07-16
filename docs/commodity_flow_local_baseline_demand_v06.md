# CommodityFlow Ambient Regional Consumption v0.6

## Status and authority

This contract replaces the retired isolated-factory and isolated-market baseline
model. The active player-facing rule is **区域基础消费** (ambient regional
consumption).

`CommodityFlowRuntimeController` remains the only owner of continuous commodity
rates, fixed-point demand integration, allocation, Sale Receipts, warehouse
inventory and waste accounting. Ambient consumption is one phase inside that
owner. It is not a market facility, a demand installation, a route, an order, a
second cashflow service or a second GDP ledger.

## Demand coverage

Every region that is both surviving and not ruined has ambient demand for every
active commodity in the current ruleset.

- A market facility is not required.
- A demand installation is not required.
- Facility ownership does not create, remove or redirect ambient demand.
- Ruined, destroyed or retired regions generate no ambient demand.
- A newly revived region begins generating new ambient demand on a later
  authoritative flow tick; it does not recreate missed demand from the ruined
  interval.

Each active commodity resolves a positive
`ambient_consumption_units_per_minute` from authored commodity balance data.
The first balance pass may assign the same low value to every commodity, but the
runtime must read the field by stable `commodity_id`; it must not branch on a
Chinese display name, industry label or catalog position.

`ambient_consumption_value_basis_points` is a Ruleset or Balance Resource term.
It prices ambient consumption below normal market consumption. The aggregate
planet-wide ambient ceiling must remain materially lower than the demand of a
mature installed market network.

## Eligible supply

Ambient demand may consume only fresh continuous or one-shot factory output
that remains unallocated after explicit market demand for the same tick.
Warehouse inventory is never an ambient source.

An eligible factory source is:

1. in the consuming region; or
2. in a directly adjacent region while the consuming region is land.

No second hop is legal. Ambient consumption never uses a sea, air, road or
multimodal route, and it does not require a road, seaport, spaceport, warehouse
or market. World facts provide stable region identity, lifecycle, terrain and
direct adjacency only. Neither `CommodityFlowWorldBridge` nor UI may turn a
candidate path into ambient eligibility.

The two receipt kinds are:

- `ambient_local_consumption`;
- `ambient_adjacent_land_consumption`.

The adjacent kind is a one-hop land-consumer relationship, not a normal
`RouteNetworkRuntimeController` shipment and not a distance-premium route.

## Fixed-point tick and expiry

For each `(region_id, commodity_id)`:

```text
ambient_due_milliunits
= ambient_consumption_units_per_minute
 * 1000
 * tick_milliseconds
 / 60000
```

Sub-milliunit integration remainder is retained so the authored rate is
frame-rate independent. This arithmetic remainder is not unpaid demand.

After eligible fresh output is allocated, all unfulfilled
`ambient_due_milliunits` from that tick expire. The next tick creates only its
new due amount. No save, snapshot or UI field may represent ambient backlog,
resident debt or an order waiting for later supply.

## Deterministic fair allocation

For one commodity and tick, the controller builds the complete bipartite set of
eligible fresh sources and ambient region claims before assigning any units.
Allocation must not depend on Dictionary order, scene-tree order or the order
in which installations were visited.

Symmetric competing sources use deterministic proportional allocation.
Integer residual milliunits use a saved
`ambient_fairness_cursor_by_region_commodity` over stable source installation
IDs. The cursor advances only when residual allocation occurs. Therefore:

- equal eligible sources differ by at most one milliunit in one allocation;
- repeated residuals rotate instead of permanently favoring the first ID;
- save/load continues the same sequence;
- no system time, frame count, pointer event or UI open count affects the
  result.

The controller may use an equivalent deterministic fair-allocation algorithm
if it proves the same per-tick and long-run properties.

## Settlement

Ambient consumption is a real low-value sale and may emit a Sale Receipt only
for commodity quantity actually consumed.

- Gross value uses the commodity price fact multiplied by
  `ambient_consumption_value_basis_points`.
- The commodity owner receives the resulting low cash value.
- Commodity GDP is recorded in the actual consuming region.
- The receipt has no market rent, transport rent, warehouse rent or distance
  premium.
- It does not fabricate a market facility, demand installation or route ID.
- Any already-authored production-facility obligation remains governed by the
  existing installation/facility contract; this ambient rule does not invent a
  new rent recipient.

The public label is **区域基础消费**. Player-facing surfaces must not call it a
market sale. They also must not expose milliunits, source-to-demand pairs,
remainders, owner fields or controller terminology.

## Allocation boundary with the other phases

The authoritative per-commodity order is:

1. explicit installed market demand, including allowed backlog recovery;
2. ambient regional consumption from still-unallocated fresh output;
3. storage of still-unallocated fresh output in a reachable matching
   warehouse;
4. waste of output that was neither consumed nor stored.

One milliunit may be committed to only one phase. Warehouse inventory can serve
phase 1 but can never serve phase 2. Ambient allocation does not consume route
capacity and cannot reserve capacity that explicit market or warehouse
transport needs.

## Persistence and privacy

`CommodityFlowRuntimeController` saves:

- ambient terms version and authored term fingerprints;
- ambient rate integration remainders by region and commodity;
- ambient fairness cursors;
- `ambient_revision` and the enclosing flow revision;
- receipt sequence, recent receipts and exact-once lineage already required by
  the Sale Receipt ledger;
- committed aggregate flow summaries needed by save/replay and public
  presentation.

Loading restores the same remainder and cursor values and must not generate an
extra tick. Missing or incompatible active terms fail closed unless covered by
an explicit schema migration.

Public summaries may expose commodity, consuming region, local/adjacent kind,
actual consumed units and low-value GDP. They remove commodity-owner identity,
private installation identity and all pair/cursor/remainder internals.

## Retired behavior

Active code, tests and current-rule documents must not preserve:

- `local_production_baseline`;
- `local_market_baseline`;
- isolated-factory self-sale;
- isolated-market public turnover;
- a production-percentage self-absorption cap;
- ambient demand supplied from warehouse inventory;
- ambient demand that accumulates across ticks;
- ambient distance premium or facility rent;
- continuous overflow retained as saleable backpressure.

Legacy names may appear only in an explicit one-time save migration or
historical evidence that is not an active oracle.

## Focused acceptance

The focused gate must prove:

- every active commodity has low ambient demand in every surviving non-ruin
  region without a market;
- same-region and direct-adjacent land-consumer supply are legal;
- second-hop, sea, air and multimodal supply are illegal;
- unfulfilled ambient demand does not accumulate;
- warehouse inventory is not drawn down by ambient consumption;
- receipts have no market rent, transport rent or distance premium;
- GDP belongs to the consuming region and low cash belongs to the commodity
  owner;
- symmetric sources are deterministic and fair;
- save/load preserves fixed-point remainders and fairness continuation without
  duplicating a tick.
