# v0.6 Save Owner Registry Contract

## Boundary

`V06SaveOwnerRegistry` is the single production composition that maps every required v3
section to exactly one versioned gameplay owner. It is a child of
`GameSessionRuntimeController`, beside `GameSaveRuntimeCoordinator`.

The registry stores bindings only. It does not:

- own gameplay state;
- discover owners dynamically;
- calculate region supply, commodity flow, routes, prices or decisions;
- call UI or `main.gd`;
- publish or write an envelope;
- split one business owner into multiple transactional restore owners.

Capture and apply operate on pure-data snapshots supplied by the bound production nodes.
Every required owner must provide validation-before-commit, an exact checkpoint, apply,
and exact rollback. Until every section is transactional, resume fails closed.

## v0.6 target manifest

The target remains exactly 18 required sections. This round replaces the obsolete
`installed_commodities` + `sale_receipts` split with one `commodity_flow` section and
uses the released slot for `region_supply`.

| Fixed order | Section | Sole gameplay owner | Required state |
| ---: | --- | --- | --- |
| 1 | `ruleset` | Ruleset runtime | Ruleset/profile identity, balance-resource versions and schema compatibility facts; no dynamic gameplay copy |
| 2 | `region_infrastructure` | `RegionInfrastructureRuntimeController` | Factories, markets, roads, ports, spaceports, warehouses, ranks, ownership, region integrity, destruction generations and exact-once facility lineage |
| 3 | `region_supply` | Active Region Supply / CardFlow / DistrictPurchase owner | Every region rack slot, deterministic bag order/cursor, unique-card claims, refresh sequence/revision, purchase/quote lineage and active 5-second quote binding |
| 4 | `commodity_flow` | `CommodityFlowRuntimeController` | Installed production/demand rates, fixed-point remainders, ambient budgets, market backlog, warehouse inventory/debt, waste accounting, Sale Receipts, recent public flow summary, revisions and exact-once lineage |
| 5 | `routes` | `RouteNetworkRuntimeController` | Stable route identities, legal topology/facility generations, transport modes, capacity state, arrival-time state and route revision; derived candidate cache is not saved |
| 6 | `player_mana` | `PlayerManaRuntimeController` | Six-color assets, reservations, remainders, revision and terminal receipts |
| 7 | `commodity_belt_visibility` | Existing commodity-belt owner | Top free commodity belt slots, visibility and refresh lineage; it remains separate from regional ordinary-card supply |
| 8 | `card_inventory` | Existing card-inventory owner | Hands, ranks, locks, private discard state, inventory revision and exact-once card mutation lineage |
| 9 | `player_organization` | `PlayerOrganizationRuntimeController` | Organization assets, bindings, revision and receipts |
| 10 | `monsters` | `MonsterRuntimeController` | Roster, lifecycle, movement/combat state, wager lifecycle and monster exact-once lineage |
| 11 | `military` | Military runtime owner | Units, commands, movement/combat state, revision and receipts |
| 12 | `weather` | `WeatherRuntimeController` | Forecast/active lifecycle, timers, region history, revision and receipts |
| 13 | `card_resolution_queue` | Card Resolution Queue owner | Current/waiting entries, shared window sequence, reservations and queue lineage |
| 14 | `card_resolution_execution` | Card Resolution Execution owner | Active execution, continuation, committed intents and exact-once execution lineage |
| 15 | `ai` | `AiRuntimeController` | AI-private continuation and learning state required for exact resume; never a public projection |
| 16 | `bankruptcy_neutral_estate` | `BankruptcyNeutralEstateRuntimeController` | Estate lifecycle journal, neutral-rent journal, sanitized public receipt and trigger marker |
| 17 | `victory_control` | `VictoryControlRuntimeController` | Qualification/audit state, authoritative outcome receipt and exact continuation facts |
| 18 | `session` | `GameSessionRuntimeController` | Session lifecycle, authoritative clocks, the single shared gameplay RNG continuation, save-operation identity and session revision |

No nineteenth section is introduced. Presentation-only route selection, open-window state,
focus state and overlay layout are not gameplay sections.

## Region supply requirements

`region_supply` must restore exactly:

- the current card in every regional listing slot;
- deterministic bag contents and cursor, or an equivalent order that is fully reproducible;
- the global unique-card set;
- per-region refresh sequence and supply revision;
- exact-once purchase/removal/refill lineage;
- an active quote's listing binding, locked public price facts and
  `expires_at_world_effective`, when still valid.

Opening, closing, hovering, scrolling or restoring the UI does not consume RNG and does
not change any of this state. The section stores no future public projection for AI;
AI reads only the currently exposed rack.

The shared gameplay RNG remains a single continuation authority under `session`.
`region_supply` stores its already materialized bag/order and draw lineage, not a second
global RNG object.

## Commodity flow requirements

`commodity_flow` is one atomic owner snapshot. It must include:

- installation IDs, generations, production and concrete demand rates;
- rate, tick and allocation remainders needed for frame-rate-independent continuation;
- non-accumulating ambient-consumption budget remainders;
- for each `market_facility_id + commodity_id`:
  `steady_demand_rate_milliunits_per_minute`,
  `unmet_backlog_milliunits`, `backlog_cap_milliunits`,
  `backlog_recovery_budget_milliunits` and `backlog_revision`;
- colored warehouse quantities, capacity/throughput state, accrued storage debt and remainders;
- current waste rate, per-source cumulative waste, per-commodity cumulative waste,
  per-region cumulative waste and FlowLossEvent lineage;
- Sale Receipt sequence, recent receipts and exact-once transaction IDs;
- the recent viewer-safe route-flow summary needed to restore the short observation window.

Market backlog is restored exactly and does not advance during apply. Loading must not:

- create a new tick of demand;
- repeat a Sale Receipt;
- withdraw warehouse inventory twice;
- turn waste or legacy backpressure into inventory;
- clear or recalculate backlog from current damaged capacity.

`ProductMarketRuntimeController` does not receive market-facility backlog state. It keeps
only commodity price, trend and financial-market state under its existing owner boundary.

## Apply transaction

Apply uses this fixed sequence:

1. Validate the registry against the authoritative 18-section manifest.
2. Validate the complete envelope through `RulesetSaveHandshakeService`.
3. Decode exact wrappers and run each owner's declared pure live-owner preflight,
   or a detached-probe apply when the owner has no explicit preflight API.
4. Reject unknown fields, non-finite values, invalid revisions, duplicate lineage or
   cross-section identity mismatch before live mutation.
5. Capture every live owner's rollback checkpoint.
6. Apply live owners in fixed order, with `session` last.
7. Re-capture and compare normalized encoded owner state after each apply.
8. On any failure or mismatch, roll back every touched owner, including the failing owner,
   in exact reverse order.
9. Re-capture every rolled-back owner and require exact encoded equality with its checkpoint.

No live owner is mutated until the complete envelope and every pure or detached
preflight succeeds.
A registry-busy request fails closed.

## Cross-section consistency

Preflight must reject:

- a region-supply quote that references a missing listing or mismatched supply revision;
- commodity backlog for a missing/destroyed market generation;
- warehouse inventory for a missing/destroyed warehouse generation;
- a Sale Receipt or public flow summary with unknown commodity, facility or route identity;
- duplicate exact-once transaction lineage across restored receipts;
- route capacity state bound to a different infrastructure generation;
- multiple owners claiming the same shared RNG continuation;
- a local route-presentation preference inside the shared gameplay envelope.

Owner apply does not recalculate another owner's business state. WorldBridge may only apply
an already validated owner plan atomically.

## Migration

- The old `installed_commodities` and `sale_receipts` sections may be accepted only by one
  explicit, versioned migration that normalizes both into `commodity_flow` before live apply.
  Partial presence or duplicate receipt lineage fails closed.
- Legacy `backpressured_milliunits_by_source` may migrate once into cumulative waste
  accounting. It never becomes inventory and can never generate a Sale Receipt.
- A pre-randomization regional rack that depends on guaranteed factory, market, city-development
  or monster slots is inspect-only/new-session-only. Production must not silently preserve
  those obsolete guarantees.
- Local route visibility is never imported as shared gameplay state; every new run starts with
  routes hidden.

## Privacy

Authorized save data may contain the private state required for exact resume, but public
receipts, QA reports and presentation snapshots are separate allowlisted projections.

Public surfaces may expose:

- regional listing cards already visible to all players;
- market backlog amount by market and commodity;
- viewer-legal current/recent commodity flow strength;
- public facility/rank/transport facts;
- aggregate save success/failure counts.

They must not expose:

- commodity supplier identity or source-installation owner;
- exact opponent cash, hand or discard;
- private quote authorization payload;
- AI plans, weights, scores or learning samples;
- future region-supply bag order;
- raw envelope sections, fingerprints or rollback section IDs.

## Current capability baseline

The production registry currently reports 11 transactional / 7 unsupported
bindings. Transactional bindings are:

- `region_infrastructure`
- `region_supply`
- `player_mana`
- `player_organization`
- `monsters`
- `weather`
- `bankruptcy_neutral_estate`
- `commodity_flow`
- `card_resolution_execution`
- `victory_control`
- `session`

The seven unsupported bindings are `ruleset`, `routes`,
`commodity_belt_visibility`, `card_inventory`, `military`,
`card_resolution_queue`, and `ai`. Full resume therefore remains fail-closed;
the ready transactional sections do not imply that the complete envelope can
already be captured or restored.

## Gates

Required focused evidence after implementation:

- `tests/v06_save_owner_registry_test.gd`
- `tests/commodity_flow_backlog_save_roundtrip_v06_test.gd`
- `tests/region_supply_rng_save_roundtrip_v06_test.gd`
- `tests/commodity_flow_public_privacy_v06_test.gd`
- `tests/full_run_quality_driver_contract_test.gd`

The gates must prove exact manifest mapping, pure or detached preflight,
zero-mutation rejection, fixed-order apply, reverse-order rollback, exact
checkpoint restoration, no reshuffle, no duplicate backlog tick, no duplicate
Sale Receipt, exact warehouse/waste restoration and public privacy.
