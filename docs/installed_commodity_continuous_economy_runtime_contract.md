# SS06-02B Commodity Flow Runtime Ownership Contract

## Status

SS06-02B is the hard cutover from project GDP and periodic project-share payouts to continuous installed-commodity flow. `CommodityFlowRuntimeController` is the only owner of installed rates, fixed-point flow, allocation, backpressure and Sale Receipts.

The production `GameRuntimeCoordinator` no longer composes `EconomyCashflowRuntimeController`, `GdpFormulaRuntimeController`, `IndustryCapacityRuntimeService` or `IndustryCapacityWorldBridge`. The first two remain loadable retired shells for historical tools only and expose no runtime algorithm or fallback.

## Ownership

### CommodityFlowRuntimeController

Owns:

- stable commodity installation IDs, generations and exact-once installation transaction receipts;
- rank I-IV authored rates of 10/20/40/80 units per minute;
- fixed-point rate and source-to-demand pair remainders;
- factory/market capacity scaling and region-integrity scaling;
- deterministic many-source/many-sink allocation;
- unmatched supply backpressure;
- the unique Sale Receipt ledger and receipt-derived GDP/mana observations;
- v0.6 flow save data.

Does not own world cash, route topology, facilities, product prices or presentation.

### CommodityFlowWorldBridge

Captures pure RegionInfrastructure, ProductMarket and transitional route facts. It validates a full receipt batch against cloned player records, applies cash and facility rent deltas once, then commits the player array atomically. It does not choose routes or allocate flow.

### Preserved owners

- `RegionInfrastructureRuntimeController`: facility roster, rank, lifecycle, shared region integrity and revision.
- `ProductMarketRuntimeController`: public commodity base prices and price history only.
- `CityTradeNetworkRuntimeController`: temporary read-only route candidate adapter until SS06-03. It owns no project, GDP, cash, receipt or save algorithm.
- `VictoryControlWorldBridge`: observes GDP from committed Sale Receipts.

## Automatic many-to-many flow

Commodity movement is automatic, like an electrical or water network. There is no authored one-to-one producer/consumer pairing.

For each commodity and tick:

1. Convert each active production and demand installation to fixed-point milliunits.
2. Scale all installations sharing one facility proportionally when their total authored rate exceeds facility capacity.
3. Scale each rate by its region integrity.
4. Build every legal production-to-demand pair.
5. Allocate the minimum of total supply and total demand across source/sink pairs in stable installation-ID order, constrained by source, sink and route capacity.
6. Preserve sub-unit pair remainders; unmatched production becomes backpressure and creates no cash or GDP.
7. Emit exactly one Sale Receipt per whole unit consumed by a market.

This supports one-to-many, many-to-one and many-to-many networks. SS06-03 may improve alternate-route spillover and multimodal bottleneck selection, but must not move endpoint allocation ownership out of CommodityFlow.

## Linear distance price

Economic distance is the shortest legal route measured in region-diameter hops, not world-space pixels or meters.

```text
premium_bp = min(12000, 1200 * max(0, distance - 1))
unit_price_cents = round(base_unit_price_cents * (10000 + premium_bp) / 10000)
```

- distance 0: base price;
- distance 1: base price;
- distance 2: +12%;
- distance 3: +24%;
- maximum premium: +120%.

Every receipt records `base_unit_price_cents`, `shortest_legal_distance`, `distance_premium_basis_points` and `unit_price_cents`, so the price can be audited without rerunning route logic.

## Unique Sale Receipt

Each sold unit produces one receipt with at least:

- identity: `receipt_id`, `commodity_id`, `color`, `units`;
- private owner: `commodity_owner`;
- endpoints: `source_region_id`, `market_region_id`, `route_id`;
- price evidence: base price, shortest legal distance, premium basis points and unit price;
- settlement: `gross_value`, `rent_rows`, `owner_net_cash`, `gdp_value`, `settled_at`;
- observer intents for cash, rent, GDP and mana using the same receipt ID.

Rent is a cash transfer, never a second GDP event. Public receipt snapshots remove commodity owner and rent-recipient identities.

## Atomic order

1. Capture immutable world facts.
2. Build the flow plan and receipt batch without mutating players or controller state.
3. Validate and atomically apply all cash/rent deltas in the WorldBridge.
4. Commit fixed-point remainders, receipt sequence, recent receipts and flow revision once.
5. Notify presentation, derivative observers and victory observers from the committed batch.

A rejected batch leaves cash, ledger, remainders, GDP observations and receipt sequence unchanged.

## Save boundary

The v0.6 flow payload stores installations, generations, processed installation transaction IDs, fixed-point remainders, recent receipts and sequences. Legacy project slots, project shares, project GDP rows, cashflow remainders and route-damage state are rejected rather than migrated into a parallel economy.

## Deleted legacy ownership

- CityTrade project slots, project attribution, project-share payouts, project cash mutation and project save shape were removed.
- periodic `main.gd` cashflow update and settlement entries were removed;
- ProductMarket cycle no longer computes or records GDP;
- EconomyCashflow and GdpFormula are non-runtime retired shells;
- Industry Capacity is absent from production composition because v0.6 has no GDP capacity reservation.

Old v0.4/v0.5 characterization tests that directly call deleted project/cash APIs are historical evidence, not compatibility requirements. No one-line wrappers may be restored for them.

## Verification gate

`InstalledCommodityContinuousEconomyCharacterizationBench` is the long-lived SS06-02B gate. Its 40 cases cover scene composition, real catalog/schema use, installation exact-once, distance pricing, many-to-many allocation, capacity, integrity, backpressure, receipt identity, privacy, save round-trip, atomic cash application and legacy-owner absence.

UI/card-art files and shared QA registries remain outside this cutover because a parallel agent owns those surfaces.
