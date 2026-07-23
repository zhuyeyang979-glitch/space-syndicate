# AI Market And Route Public Query Ports

## Market Boundary

`AiMarketPublicQueryPort` reads only
`ProductMarketRuntimeController.public_market_snapshot()`. It requires the
complete 46-product catalog and fails closed when the owner is not ready or a
product is missing. A query never calls `ensure_catalog()`, generates prices,
refreshes the market, or consumes the shared RNG.

Each product uses a strict public allowlist for price, supply/demand,
disruption, temporary pressure, contract pressure, growth, route flow, weather,
and anonymous futures facts. Futures owner, position ID, source card, margin,
warehouse identity, and settlement internals are rejected.

AI business and route-plan scoring now consume `public_product()` and
`public_price()`. `AiRuntimeController` no longer exposes ProductMarket's
private `runtime_state_snapshot()` or invokes query-time catalog generation.
The existing ProductMarket transaction remains the only AI market mutation
path and is not widened by this query cutover.

## Route Boundary

`AiRoutePublicQueryPort` reads only the Route owner's existing cached public
projection. It never calls `refresh_routes()`, `_ensure_cache()`, a world
bridge, or weather RNG.

The Route owner projection now uses the authoritative candidate field names:

- stable public `route_id`;
- source, market, and ordered public region IDs;
- `mode_tags`;
- actual and shortest legal distance;
- transfer count;
- bottleneck units per minute;
- route efficiency and effective bottleneck.

It excludes facility IDs, capacity-resource IDs, rent recipients, expected
rents, and topology fingerprints. AI route-load and route-row scoring consume
only a region summary from this Port; raw candidates are no longer returned to
those consumers.

## Persistence And Remaining Scope

Both Ports are stateless read-only adapters. They add no save section, owner,
journal, RNG, or Main caller. `FULL_RUN_RESUME_CLAIM` remains false.

Physical CommodityFlow activity, actor-owned facilities/inventory, product
flow, and all raw district targeting remain later boundaries. The inherited
`route_weather_integration_v1_test` has the same 11 failures on parent
`44dff18`; this commit does not alter weather formulas or claim that gate green.

## Evidence

- `tests/ai_market_route_public_query_ports_test.gd`: 15 focused checks.
- `tests/ai_business_action_transaction_boundary_test.gd`: pass.
- `tests/ai_card_phase_counter_owner_test.gd`: pass.
- `tests/product_market_owner_smoke_fixture_test.gd`: pass.
- `tests/main_runtime_composition_test.gd`: pass.
- Parent/candidate route-weather comparison: same 11 inherited failures.
