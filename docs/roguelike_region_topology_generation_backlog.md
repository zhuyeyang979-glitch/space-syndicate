# Roguelike Region Topology Generation Backlog

## Why this is separate

This work follows CommodityFlow and the SS06-03 route cutover. Region topology is a world-generation owner; it must not be hidden inside commodity allocation, `Line2D`, map presentation or pathfinding UI.

## Product requirements

### Tutorial planet

- land only; water ratio is exactly 0%;
- more regions than the current beginner map;
- teach land adjacency, facilities, installed production/demand and automatic commodity flow before introducing ocean transport;
- guarantee at least one reachable factory-to-market teaching chain without requiring water infrastructure.

### Standard and deeper planets

- seeded deterministic generation;
- irregular, country-like region polygons rather than uniform cells;
- land may form multiple shapes and subcontinents, while every required gameplay component remains reachable;
- water ratio is sampled from 10% to 60% according to challenge profile;
- land and water are topology facts, not decorative colors.

## Proposed deterministic model

1. Sample a seeded water target `water_ratio` in `[0.10, 0.60]` for non-tutorial runs.
2. Generate weighted seed sites with blue-noise spacing, then build a Voronoi/Delaunay region graph.
3. Perturb borders with bounded midpoint noise to produce country-like silhouettes while enforcing minimum area, minimum edge length and polygon validity.
4. Grow ocean from selected boundary/coastal seeds until the target area ratio is reached; preserve land component constraints.
5. Repair topology so required land components, coastal access and tutorial chains satisfy reachability rules.
6. Assign terrain and facility slots after topology is frozen; never infer topology from rendered polygons.
7. Hash seed + generator version + normalized graph for save/replay determinism.

## Required constraints

- no self-intersecting polygons, zero-area regions or duplicate stable region IDs;
- configurable region-count distribution by challenge depth;
- bounded area variance and border complexity;
- explicit adjacency symmetry;
- tutorial land graph connected;
- standard maps expose enough land and optional water routes for all six industries;
- placement validator guarantees at least one valid factory, market and transport progression path;
- water ratio measured by polygon area, not region count;
- generator retries are bounded and record rejection reasons.

## QA gate for the future sprint

- deterministic same-seed graph and different-seed diversity;
- tutorial 0% water and teaching-chain reachability;
- standard water area always within 10%-60%;
- polygon validity, stable IDs and symmetric adjacency;
- country-like shape metrics: area spread, compactness and border complexity within authored bands;
- 3/4/8-player spawn fairness and 2-7 AI reachability;
- CommodityFlow one-to-many/many-to-one/many-to-many fixtures remain valid on generated graphs;
- shortest legal distance is derived from the generated graph and remains the only input to linear distance pricing.

## Deferred decisions

- exact region counts by challenge depth;
- whether deep runs permit disconnected land continents before transport unlock;
- terrain biome weights and ocean transport unlock timing;
- final compactness/border-complexity bands after visual playtesting.
