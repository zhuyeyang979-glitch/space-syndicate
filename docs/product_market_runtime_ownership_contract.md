# Product Market & Futures Runtime Ownership Contract

## Sprint 55 status

`ProductMarketRuntimeController` remains the only market and futures lifecycle owner. It now references `product_futures_terms_v04_catalog.tres`, locks margin and complete terms at effect open, settles capped gain/loss or warehouse HP loss exactly once, normalizes legacy positions once, and sanitizes public snapshots. Queue only authorizes funds; Formula Service remains pure arithmetic; AI scores the shared terms; Presentation, RightInspector, and CardCodex render the same terms.

The previous favorable-only payout and warehouse clear-only semantics are deleted. `main.gd` no longer contains copied financial fields or the six legacy product-futures balance-report functions. The existing Bench now reports **100/100 records**, including **76/76 live aligned** and **24/24 historical baseline integrity**, with zero design decisions.

## Sprint 52 status

`ProductMarketRuntimeCharacterizationBench.tscn` instantiates the real `main.tscn` and records fifty observations. This sprint is characterization only: no `ProductMarketRuntimeController` exists, no parallel market engine was introduced, and production `main.gd` remains at SHA-256 `3191405C4F34A002A658AB179020E01BEBDE67B1148EF1DCE3AF9F70DBBDB201` with 24,323 nonblank lines, 1,379 functions, 145 top-level variables, and 228 constants.

The gate reports 50/50 observed and 48/50 aligned. The two non-aligned records are explicit v0.4 design decisions, not test failures.

## Sprint 53 status

`ProductMarketRuntimeController.tscn` is now the single runtime owner. Its non-owning `ProductMarketRuntimeWorldBridge.tscn` supplies the existing shared RNG, pure world facts, RuntimeBalanceModel price calls, and narrow world mutations. The existing fifty-case gate was migrated from direct `main.gd` reflection to the Controller API and passes **50/50**, while the two documented v0.4 financial design differences remain **48/50 aligned**.

The Controller owns all three persistent states, the thirteen market constants, generation, catalog normalization, refresh, cadence, boon aging, speculation, futures, public sanitization, and current/legacy save data. `main.gd` no longer declares those states or constants and no longer contains the twenty-three mapped functions. It retains only narrow world adapters for city GDP sampling, player cash/event commits, callouts, clues, and cross-domain refresh hooks.

Production `main.gd` is now 23,659 nonblank lines, 1,377 functions, 142 top-level variables, and 215 constants with SHA-256 `58D1C52957A80ADC022AA9F3B1DB34B7F8841EA1F138C011E4E9D0352D942006`.

## Sprint 54 terms characterization

The existing real-main Bench now contains 74 cases: the original 50 market ownership/lifecycle cases plus 24 product-futures terms cases. It reports 74/74 observed, with the original market gate still 50/50 and the new terms gate 24/24. Contract alignment is reported separately because missing financial terms are design decisions, not harness failures.

The twelve real `商品看涨`, `商品看跌`, and `港仓囤货` I-IV cards are recorded in `product_futures_v04_terms_contract.md`. Current purchase cost, zero action fee, underlying/reference/duration/direction/multiplier locks, favorable-only payout, exact-once expiry, private owner save boundary, and warehouse-void behavior are now explicit evidence. The ten unresolved choices and recommendations live in `product_futures_v04_design_decisions.md`.

Sprint 54 changes no production formula. `main.gd` remains at the Sprint 53 SHA and metrics, and `ProductMarketRuntimeController` remains at SHA-256 `5B2E115A0D9C44623D48212BEC4C9C1B29C4C150C827370614D6D24BEB1B86EB`.

## Previous owner

Before Sprint 53, `main.gd` owned:

- `product_market`
- `business_cycle_count`
- `market_timer`
- initial market generation and catalog backfill
- supply, demand, disrupted-route, temporary-pressure, and contract-pressure aggregation
- price refresh, trend fields, volatility cap, and price history
- product growth and route-flow boon lifetime
- product futures creation, expiry, payout commit, and warehouse clearing
- market refresh cadence and v1 save compatibility

## Preserved external boundaries

- `CardEconomyProductRouteFormulaRuntimeService` owns pure deterministic boon, duration, payout, and route arithmetic. It does not own product-market state, RNG, cadence, or world mutation.
- `RuntimeBalanceModel` remains the product-price formula owner.
- `EconomyCashflowRuntimeController` owns per-second payout cadence and remainder planning, not market refresh.
- `GdpFormulaRuntimeController` owns city GDP calculation, not product price or futures state.
- `AiRuntimeController` reads market facts and chooses intents. It does not refresh or mutate the market.
- Weather, Monster, Military, and card/economy effect owners request the shared market route through world bridges; none stores a second `product_market`.
- `ProductCodexPublicSnapshotService` formats public display data only.

## Market entry shape

Every product entry is normalized to these fields:

- identity/price: `tier`, `base_price`, `price`, `trend`, `raw_trend`, `price_step_cap`, `driver_summary`, `volatility`, `price_history`
- observed world totals: `supply`, `demand`, `disrupted`
- transient speculation: `temporary_demand_pressure`, `temporary_supply_pressure`
- growth boon: `base_growth_multiplier`, `growth_multiplier`, `growth_seconds`, `growth_turns`, `growth_source`, `base_growth_source`
- route boon: `base_route_flow_multiplier`, `route_flow_multiplier`, `route_flow_seconds`, `route_flow_turns`, `route_flow_source`, `base_route_flow_source`
- contract pressure: `market_contract_demand`, `market_contract_supply`, `market_contract_seconds`, `market_contract_turns`, `market_contract_source`
- private positions: `futures_positions`

Old saves missing normalized fields are backfilled. A missing catalog entry is regenerated without replacing existing entries. A completely missing market regenerates from the restored shared RNG state.

## Generation and RNG order

For every `PRODUCT_CATALOG` entry, runtime performs:

1. Build the tier weight list `36 / 32 / 22 / 10`.
2. Consume the shared gameplay RNG in `_weighted_pick_index` for the tier.
3. Read the selected tier.
4. Consume the same shared RNG for a base price inside that tier.
5. Create a one-value price history containing the base price.

Fixed-seed generation produces byte-equivalent market dictionaries and the same final RNG state. No market-specific RNG exists.

## Refresh weights and order

Destroyed districts are excluded. For each live district:

- district product: supply +1
- active-city product: supply +2
- district demand: demand +1
- active-city demand: demand +3
- disrupted active-city route: disrupted +1
- temporary demand/supply pressure: contributes this refresh, then decays by one
- active contract demand/supply: contributes while its realtime duration remains

The refresh then calls `RuntimeBalanceModel` with base price, supply, demand, disrupted-route score, volatility noise from the shared RNG, and growth multiplier. It stores price, trend, raw trend, step cap, driver summary, observed totals, decayed temporary pressure, and a deduplicated history capped at twelve values.

`_market_tick` order is:

1. Increment `business_cycle_count` once.
2. Refresh city networks.
3. Refresh product prices.
4. Reset current cycle/cashflow display counters.
5. Sample active-city GDP and resolve GDP derivatives.
6. Run AI expansion and business intents through the AI owner.
7. Finalize AI rewards.
8. Record player cash history.

An empty-city tick still increments the cycle and revalues the public market safely.

## Boon lifetime

Temporary growth, route-flow, and contract effects age in realtime seconds. On expiry they reset to their stored baseline values and sources. Persistent Monster/economy boons update the baseline itself and therefore survive ordinary aging. City route-flow and city contract timers are aged by the same realtime pass, but their city state remains outside the future product-market Controller.

## Futures lifecycle

A product position stores:

- private `owner` and `source`
- `direction`
- `baseline_price`
- `expires_at`
- `multiplier`
- `units`
- optional `warehouse_district`

At expiry, the pure Formula Service calculates only favorable movement: positive price delta for `up`, negative price delta for `down`, multiplied by 10, units, and multiplier. The world owner pays once, records a private economic event, removes the position, and exposes only an anonymous public result. A second timer pass cannot pay the removed position again.

Warehouse positions require an active city owned by the acting player. Public snapshots may expose direction and count, but not owner, private source card, rival hand, or AI plan.

## v0.4 differences

Two observed behaviors require an explicit design decision:

1. The v0.4 rulebook requires margin, maximum gain, and maximum loss fields. Current product futures pay an uncapped favorable delta and have no explicit margin/loss envelope.
2. The v0.4 rulebook says warehouse destruction loss depends on card terms and remaining warehouse HP. Current runtime simply removes matching positions exactly once without a separate cash-loss settlement.

Sprint 52 records these differences and does not modify production rules to make the gate green.

## Sprint 53 deletion gate (complete)

Sprint 53 should create one scene-owned `ProductMarketRuntimeController` and a non-owning world bridge, migrate all three persistent states, shared-RNG requests, generation, refresh, boon/futures lifecycle, public/private snapshots, and current/legacy save fields, then delete the mapped `main.gd` implementation in the same change. It must not absorb Formula, Cashflow, GDP, AI, Weather, Monster, Military, card-effect, Card Execution, or Product Codex ownership.

Direct-reflection tests now use the Controller API or real runtime receipts. No silent fallback market remains.
