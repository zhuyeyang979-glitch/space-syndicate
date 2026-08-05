# Space Syndicate V0.7.4 Complete Constitution

```text
CONSTITUTION_ID=space_syndicate.v074.complete
RULESET_ID=v0.7.4
STATUS=approved_and_frozen_for_atomic_production_cutover
```

V0.7.4 inherits every V0.7.3 rule outside the amended map, facility-registry,
warehouse, solar, projection, presentation, targeting, and legacy-bootstrap
domains, plus the explicitly amended local unified-track capacity/timing and
asset-pool presentation contracts. Historical V0.7.3 files and tags remain
immutable.

## Authoritative Roguelike Planet

`V074MapGenesisCore` is the one geography owner. A typed request supplies a
seed, an independent region count, geography complexity, and land/ocean
profile. The Core emits `MapGenesisReceiptV1`; UI and presentation may project
that receipt but cannot choose region IDs, terrain, adjacency, facility slots,
sunlight, or legal targets.

The currently verified range is 6 through 30 regions. Thirty is an engineering
support boundary for this release, not a constitutional hard maximum. IDs use
stable ordered values such as `region.000`; the historical alpha-zeta set is
not a production fallback.

The planet is partitioned by a closed geodesic microcell mesh. Every microcell
has exactly one owner region, every region is edge-connected, and the combined
region adjacency graph is connected. Shared boundaries reference the same
authoritative mesh edges from both sides. This topology, rather than two
independently approximated polygons, proves no gaps, overlaps, or seams.
The Receipt also publishes ordered closed `Vector3` boundary loops at far,
medium, and near LOD plus top-level microcell centers. Presentation consumes
those arrays directly and cannot synthesize a replacement coastline.

`SIMPLE`, `STANDARD`, and `COMPLEX` control mesh detail and low-frequency
organic growth independently from region count. The generator may create
concave coastlines, bays, peninsulas, straits, and archipelago patterns, but
cannot call a triangle, quadrilateral, or high-frequency sawtooth a finished
region.

## Land, Ocean, And Sun

Every region is exactly `land` or `ocean`; both classes must exist in every
accepted map and the combined graph remains connected. In V0.7.4 terrain is
authoritative identity, presentation, hit-test, and future-extension data.
It adds no construction restriction, economy modifier, movement cost, track
modifier, or facility bonus.

The one authoritative `sun_direction` is generated with the map. A region is
sunlit only when its surface normal passes the configured dot-product
threshold. Array index, batch parity, and fixed-half shortcuts are forbidden.
The same solar fact drives factory, market, warehouse, and globe presentation.

## Complete Facility Registry

The complete production registry is:

```text
REGISTERED_FACILITY_TYPES=[factory,market,warehouse]
STARTER_FACILITY_TYPES=[factory,market]
STANDARD_TRACK_FACILITY_TYPES=[factory,market,warehouse]
```

Starter eligibility is a subset and never defines the complete registry.
Warehouse has zero Starter cards. Every region receives one potential slot for
each `facility_type + industry_id` pair. Three facility types and six industry
colors therefore produce 18 slots per region, calculated from registry sizes.

Warehouse is a normal card family in the unified track and personal DBG. It
supports `BUILD_NEW`, `UPGRADE_OWN`, `REPAIR_OWN`, and the inherited
`FIZZLE_FULL_ASSET_REFUND` contention policy. It has owner, rank, capacity,
ingress and egress throughput, damage, and generation state. Numeric capacity
and throughput values must come from existing authoring or the versioned
balance defaults; absent stock economics cannot be fabricated.

Sunlit warehouse ingress and egress use `2.0`; dark uses `1.0`. Sunlight does
not change capacity, rank, HP, card cost, asset supply, or unified-track supply.
Public projection may show capacity and throughput but never stock detail,
private routes, future logistics, rival actions, or AI plans.

## Shared Sushi Track

Each player sees only the authorized local segment of one shared sushi track.
That segment has ten physical path positions and begins a new game with ten
distinct real card instances. This capacity change does not alter the inherited
long-run supply ratio: normal cards remain 6000 basis points and commodities
remain 4000 basis points. Other players' segments and future supply stay
private.

Acquiring a card removes that exact instance and leaves a public,
noninteractive vacancy at its shared path position. The acquisition consumes no
future supply card, supply RNG draw, supply cursor, or instance sequence, and it
does not slide later cards forward. Surviving cards retain their path positions
and segment owners. Only natural shared track advancement moves cards and the
vacancy, draws at the queue head, and eventually restores full capacity after
the vacancy exits the shared tail. The track keeps a slow directional
presentation motion, but that motion owns no gameplay state and cannot advance
the authoritative queue.

## Compact Asset Pips

The local six-color asset pool uses `repeated_symbol_pips` instead of primary
fraction text. Every color group contains exactly six symbol positions: bright
available symbols, locked reserved symbols, dim empty positions, and ghosted
projected-refresh overlays all reuse those same six positions. No seventh or
trailing refresh slot may imply capacity beyond six.

Pips consume only the local player projection. Numeric current, available,
reserved, cap, projected refresh, and overflow details remain available through
tooltip, focus, and accessibility text. Pips own no gameplay, Save, RNG, world,
or player mutation and disclose no opponent asset balance.

## Runtime And Architecture Boundary

The amended domains switch atomically. Fixed-six, alpha-zeta,
factory/market-only, twelve-slots-per-region, index-sunlight, six-button target,
and static-disc fallbacks are forbidden. Save and Continue remain disabled for
the new-game-only V0.7.4 sample.

`scripts/main.gd` must be physically removed after reusable pure algorithms are
extracted. The application bootstrap may compose owners, forward typed intents
and receipts, refresh presentation, navigate, and report faults. It may not own
map generation, warehouse rules, facility contention, AI policy, solar rules,
Save, RNG, or Victory.
