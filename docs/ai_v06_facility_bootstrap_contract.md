# AI v0.6 Facility and Commodity-Network Bootstrap Contract

## Status

This contract removes the factory-first bootstrap assumption. A market-first
opening is legal and may be strategically useful when it is paired with a
concrete commodity-demand installation plan.

`AiRuntimeController` chooses intents. It never owns or mutates cash, cards,
regional supply listings, facilities, production rates, market backlog, routes,
warehouse inventory, waste, transaction journals or queues.

## Owner-routed mutation

The only mutation path remains:

```text
AiRuntimeController
  -> AiV06EconomyActionPort
  -> production Coordinator adapter
  -> canonical CardFlow / inventory owner
  -> RegionInfrastructureRuntimeController
  -> CommodityFlowRuntimeController / RouteNetworkRuntimeController
```

The port is a pure-data forwarding boundary. A delegate reference is not state
ownership. Missing capability, malformed data, stale revision or non-pure data
fails closed.

`ProductMarketRuntimeController` remains the price/trend/financial-market
owner. AI may read its viewer-safe price facts but must not treat it as the
owner of market-facility backlog.

The AI must not:

- write a facility directly;
- write a demand installation or backlog;
- draw or replace a regional supply slot;
- inspect the future regional supply bag;
- create a manual source-to-demand order;
- draw a route or change player route-visibility preferences;
- release warehouse inventory with a private shortcut;
- recreate a local economy or settlement formula.

## Read surfaces

The production action port may normalize the following owner snapshots. Method
names may be adapted to existing production conventions, but responsibilities
must remain separate.

```gdscript
actor_id_for_player_index(player_index: int) -> Dictionary
current_region_supply_snapshot(actor_id: String) -> Dictionary
player_snapshot(actor_id: String) -> Dictionary
commodity_flow_opportunity_snapshot(actor_id: String) -> Dictionary
route_network_opportunity_snapshot(actor_id: String) -> Dictionary
purchase_region_supply_card(request: Dictionary) -> Dictionary
play_runtime_card(request: Dictionary) -> Dictionary
```

The frozen v0.6 port retains the compatibility method name
`market_snapshot(actor_id)`, but that method is now only a deterministic,
viewer-safe projection of the current public `RegionSupply` racks. It is not a
second facility market. Its `revision` is the authoritative RegionSupply state
revision, and its selected listing is present in a currently revealed rack
slot. The former fixed first-table facility listing, category rotation, and
Inventory-owned facility-market source are physically retired from the
production Coordinator.

Every response is recursively pure data and includes:

- `available: bool`;
- `revision: int >= 0`;
- non-empty stable `reason_code`.

### Current regional supply

The AI may read only the same currently revealed regional rack slots that are
legally public to players. A normalized listing may include:

- region and slot identity;
- card identity, family, rank and enabled mode;
- purchase price and current legal target conditions;
- quote and source revisions;
- current purchase eligibility.

It excludes:

- future shuffle-bag order;
- RNG state;
- hidden supply weights;
- other players' private quotes or purchase intents.

The AI evaluates whatever card is currently revealed. A market card does not
need a prior factory card, and a factory card does not need a prior market
card. Temporary inability to afford or play a listing lowers or blocks the
current action; it does not cause the AI to treat that card family as illegal.

### Commodity-flow opportunity

A viewer-scoped flow snapshot may contain:

- public market backlog by `market_facility_id` and `commodity_id`;
- public steady-demand and capacity status;
- public production, ambient-consumption, warehouse-capacity and waste
  summaries;
- the acting AI's own commodity ownership and warehouse inventory only where
  normal player visibility permits it;
- public revisions and stable reason codes.

It does not contain supplier identities for public backlog, rival commodity
owners, rival cash or hands, pair candidates, fixed-point remainders, route
candidate internals or future flow plans.

### Route opportunity

The route snapshot exposes legally visible current topology, facilities,
capacity status and reachability facts from `RouteNetworkRuntimeController`.
The AI may evaluate whether building or repairing infrastructure would connect
an existing source or warehouse to a backlog market.

The snapshot is independent from the local human player's “查看商路” toggle.
AI behavior must be identical whether map routes are visible or hidden.

## Legal opening strategies

The AI policy recognizes all of the following as legal:

### Market-first preparation

The AI may build a market before any corresponding factory exists. A useful
market-first candidate should identify a concrete commodity demand that can be
installed now or through a visible/owned follow-up card.

A bare market color alone does not create high demand or backlog for every
commodity of that industry. The AI must not fabricate that demand when scoring
the action.

Once a concrete demand installation exists, lack of supply or route is not an
illegality. It is a preparation state in which backlog can accumulate.

### Supply for known backlog

The AI may value a matching factory when a public market has backlog for that
commodity. The market and factory may have different owners. Factory ownership
is not required to satisfy the market.

### Route connection for known backlog

The AI may value a road, seaport, spaceport, repair or other existing route
facility when it would create or restore a legal route between:

- fresh production and a backlog market; or
- matching warehouse inventory and a backlog market.

The AI submits only the normal facility/card intent. Automatic logistics, route
choice and backlog fulfillment remain owner-controlled.

### Warehouse buffer

The AI may value a matching warehouse when expected fresh surplus would
otherwise become waste. It may value route infrastructure that lets its legally
visible inventory reach explicit market demand.

The AI must not expect low-value ambient consumption to empty warehouse stock.

### Factory-first and infrastructure-first

Factory-first remains legal, as do openings that temporarily reveal or buy only
transport, warehouse, tactical or unit cards. There is no required economic
family sequence.

## Candidate policy

A facility/network candidate exists only when:

1. the seat is a live AI seat and actor identity resolves through the canonical
   production map;
2. all required owner snapshots are authoritative and revisions are current;
3. the card is present in a current revealed regional slot or the acting AI's
   legal private hand;
4. the card and target are enabled, not retired and have at least one
   authoritative legal target;
5. purchase cash and normal action rules permit the action;
6. the candidate uses only current public facts plus that AI seat's own private
   facts;
7. mutation can be submitted through the canonical purchase/play owner.

The policy must not require:

- a starter monster summon;
- an existing factory before market construction;
- an existing market before factory construction;
- current supply before a concrete market demand installation;
- an open UI window;
- a player-drawn route;
- a one-to-one order.

Internal candidates may carry strategy kind, commodity, target region, current
listing ID and expected revisions. They never contain raw owner snapshots,
future rack order, caller-selected prices, owner receipts or presentation
state.

## Evaluation inputs

The AI may compare, without publishing its score:

- current public backlog quantity and steady demand;
- market facility headroom and damage;
- matching public production availability;
- current legal route reachability and bottlenecks;
- acting-seat inventory that could serve explicit demand;
- warehouse space that could prevent acting-seat waste;
- purchase/play cost and ordinary strategic risk;
- time-to-connect based on current legal infrastructure.

Backlog is an opportunity signal, not a promise of exclusive profit. The
snapshot does not identify which supplier will win allocation.

The policy must distinguish:

- **market normal demand** from **market unmet demand**;
- **backlog recovery headroom** from current steady demand;
- **ambient regional consumption** from normal market sales;
- **stored inventory** from fresh output;
- **waste** from inventory or delayed supply.

No player-facing surface receives the score, rejected candidate details,
pressure buckets or route plan.

## Transaction flow

1. Read actor, current supply, player, flow and route revisions.
2. Prefer a legal already-owned card when normal policy considers it better;
   this avoids a second charge after a successful purchase and failed play.
3. Otherwise lock the canonical listing through the existing five-second quote
   path. AI does not echo or override authored price.
4. Submit the deterministic purchase transaction through
   `GameRuntimeCoordinator.purchase_region_supply_card`, which delegates to the
   canonical Inventory/CardFlow transaction and RegionSupply slot-refill
   lifecycle.
5. Re-read the authoritative player snapshot after purchase.
6. Locate the stable runtime card instance and submit the normal play request.
7. Count success only from the canonical committed and terminal owner result.
8. Re-read owner snapshots on later ticks; no local AI journal marks facilities,
   backlog, inventory or route completion.

Transaction IDs bind immutable actor, listing/card, target and expected
revisions. Retrying the same intent reuses the same ID; a changed authoritative
revision requires reevaluation.

## Scheduling

Facility/network evaluation runs on the existing AI decision cadence. It does
not pause the world and does not depend on OverlayLayer visibility.

The policy may alternate among market preparation, supply, route and storage
opportunities as public facts change. It must not cache a permanent
factory-first phase or infer the next regional listing family from the last
purchased card.

## Privacy

Public AI snapshots expose only coarse availability, aggregate action counts
and sanitized outcome/reason families. They exclude:

- actor identity where hidden;
- cash, hand, discard and card-instance data;
- transaction IDs and exact owner receipts;
- future regional supply order or RNG state;
- supplier identity behind backlog or flow;
- AI scores, rankings, route plans, pressure, training metadata and rejection
  reasons;
- another player's local route-visibility preference.

The AI itself receives no greater rival-private visibility than the same seat's
normal legal viewer scope.

## Persistence

AI save state does not copy regional rack slots, future bag order, market
backlog, route candidates, warehouse inventory, waste totals or Sale Receipts.
Those values restore only through their authoritative owners.

After load, the AI re-reads current owner snapshots and revisions before
choosing another intent. A restored cooldown or general learned policy may
continue under its existing AI owner, but no saved candidate score or route
plan may override the restored economy.

## Acceptance

Focused AI and integration gates must prove:

- a currently revealed market can be selected before any factory exists;
- concrete demand installed in that market accumulates backlog without supply;
- the AI can later value a matching factory, route connection or owned
  warehouse opportunity;
- a bare market color does not fabricate all-commodity backlog;
- factory-first remains legal but is not a mandatory phase;
- current unaffordable/unplayable listings remain visible inputs;
- future regional supply order is absent from every AI snapshot;
- hidden-route presentation state does not change AI decisions;
- no AI mutation bypasses CardFlow, `RegionInfrastructureRuntimeController`,
  `RouteNetworkRuntimeController` or `CommodityFlowRuntimeController`;
- save/load restores no AI-owned copy of rack, backlog, inventory or waste;
- public AI output reveals no score, hand, cash, supplier or private plan.
