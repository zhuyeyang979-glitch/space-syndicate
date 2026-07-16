# Roguelike Remote Trade Opportunity Policy v0.6

## Ownership boundary

The generated district map remains the only map owner. `RoguelikeEconomicViabilityPolicy` is a stateless pure-data normalizer/auditor invoked after terrain, topology, production, and demand are generated and before those facts are forwarded to RegionInfrastructure. It does not retain a map, create an economy ledger, install facilities, or calculate income.

CommodityFlow owns ambient regional consumption, concrete market backlog,
automatic allocation, storage, waste and trade settlement. This policy never
encodes ambient demand or market backlog into district demand and never creates
orders, routes, cash, GDP, inventory, waste or production capacity.

## Input contract

`normalize(request)` and `audit(request)` require pure-data copies of:

- `districts`: at least two rows with unique `region_id`, known `terrain`, integer `neighbors`, exactly one `products` entry, and exactly one `demands` entry;
- `catalog_products`: the allowed product identifiers;
- `terrain_product_pools`: the legal production pool for each terrain.

Production must belong to the district terrain pool. Production and demand must be catalog products and must differ within each district. Topology is validated but is not a viability condition.

## Relaxed planet invariant

A map is viable when at least one source district's sole production product is the exact demand product of a different district, and that destination does not itself produce that product. The destination may be adjacent or remote across multiple regions.

There is no per-source coverage requirement. A viable map may have isolated sources, zero direct matches, or a coverage ratio below 1.0. Those values are diagnostic only.

If a valid map already has any cross-district exact match, normalization is a byte-for-byte economic no-op. If it has none, the policy deterministically replaces at most one destination demand with an existing source production product. It never changes production, terrain, topology, region identity, slot counts, or catalog membership.

If no different destination can demand any source product without becoming self-demanding, normalization returns `global_remote_trade_destination_unavailable`, `changed=false`, and the complete original district copy. There is no partial patch or fallback product fabrication.

## Audit schema v3

The audit exposes:

- `global_remote_match_count`: all legal cross-district exact source/destination pairs;
- `direct_remote_match_count`: the subset whose destination is in the source's neighbor list;
- `source_with_remote_count` and `isolated_source_count`;
- `coverage_ratio`: covered sources divided by total sources, informational only;
- deterministic `assignments`, one proof destination per covered source;
- `changed`, `mutation_count`, and `changed_destination_indices`;
- `repair` identifying the sole source, destination, and product when a repair occurs.

`viable` means `global_remote_match_count > 0`; it does not mean 100% coverage.

## Integration and evidence boundary

`main.gd` accepts only a complete valid result and rejects any patch set larger than one demand slot before applying it. RegionInfrastructure is initialized from the final district facts, so its authoritative production/demand snapshot must equal the map after the optional patch.

The earlier C9 full-map direct-neighbor coverage contract and its
`coverage_ratio_bp == 10000` oracle are retired as an overconstraint. They
must not be restored. No region is required to begin with a directly adjacent
exact-product market: low ambient consumption already gives fresh production a
small local outlet, while concrete markets may legally begin without supply and
accumulate backlog. The focused test proves deterministic pure-data behavior,
at-most-one mutation across seeded shapes, seed 60610 production integration,
and RegionInfrastructure fact equality. Ambient/backlog/warehouse/waste
behavior remains separate CommodityFlow owner evidence.
