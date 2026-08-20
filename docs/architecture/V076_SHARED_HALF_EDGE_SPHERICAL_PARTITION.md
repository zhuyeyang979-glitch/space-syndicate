# V0.7.6 Shared Half-Edge Spherical Partition

## Stage boundary

Stage 2 introduces an isolated deterministic geography authority. It does not
modify `project.godot`, `main.tscn`, the V0.7.5 composition, the inherited
V0.7.4 runtime owner, map presentation, facilities, movement, combat, save
composition, or current production gameplay. The production cutover remains a
later atomic stage.

The player-facing promise at this stage is narrower: a future match can refer
to one replay-safe shared spherical region topology without deriving gameplay
adjacency from rendered polygons.

## Frozen combinatorial sphere

`V076SphericalMicrogridIndexV1` constructs the level-2 subdivided icosahedron
from fixed integer face indices. Midpoints create new vertex identities from a
canonical undirected edge key; they do not calculate positions. The frozen
table contains:

- 162 vertex identities;
- 320 oriented triangular faces;
- 480 shared mesh edges;
- 960 directed half-edges;
- exact `origin`, `destination`, `face`, `next`, `previous`, and reciprocal
  `twin` links;
- three sorted neighboring face identities per face;
- an exact canonical SHA256 seal.

The frozen topology SHA256 is
`5cbd98e4027bc2cfd058c857e1a24a5f7c8c61291f1cb7ae7336bcf6851f6452`.

The validator requires `3F = H`, `2E = H`, reciprocal reversed twins, triangular
`next` cycles, reciprocal `next.previous = self` and `previous.next = self`,
continuous face-cycle endpoints, and `V - E + F = 2`.

No coordinate, normalized vector, spherical area, trigonometric value, color,
LOD, camera, screen, or elapsed-time value is part of authority. V0.7.4 float
geometry remains presentation/reference material only.

## Integer partition authority

The `map.partition` Domain RNG selects one initial face and one deterministic
tie anchor for each later seed. Subsequent seeds maximize integer graph
distance from the existing seed set. A multi-source integer heap assigns every
microface exactly once. Shape complexity is an independent closed request field:

- `SIMPLE` uses constant positive edge cost 100;
- `STANDARD` uses deterministic root-seed/edge jitter in the narrow range
  90 through 110;
- `COMPLEX` uses deterministic root-seed/edge jitter in the wide range 25
  through 175.

All three use the total ordering:

```text
(graph_cost, region_index, face_id)
```

This construction has no retry path and consumes exactly `region_count` Domain
RNG draws. Jitter does not consume hidden RNG draws. Every edge cost is a
positive integer, so every region remains connected to its seed through its
winning growth path. Complexity is not inferred from region count and changes
the integer owner/boundary projection, rather than attaching a presentation
label to identical authority.

The authority projection binds the generator version, root seed, positive
region count, shape complexity, frozen topology identity and SHA, owner per face, seed faces,
sorted membership and adjacency, canonical directed boundary cycles, each
shared cross-region twin pair, and the final Domain RNG snapshot. The complete
projection receives a canonical SHA256 through `V076AuthorityStateCodec`.

Validation replays the Domain RNG from the exact root seed and `map.partition`
domain for the declared draw count, then requires the resulting state and full
snapshot to match. It also independently invokes the canonical generator and
requires the complete partition projection to match. A re-signed structure
with synchronized seed, owner, membership, adjacency, and boundary mutations
therefore remains invalid even when its topology is internally coherent.

Positive integer region-count requests are legal. Generation fails closed when
the requested count exceeds the frozen topology's natural capacity of 320
microfaces. Thirty is not an architectural limit. The required release
acceptance matrix remains:

```text
6, 8, 12, 16, 20, 24, 30
```

Focused gates additionally prove 31 and 32 succeed and 321 fails at the
natural face-capacity boundary.

## Land and Ocean authority

Terrain is deterministic integer authority, not a shader choice. Every region
receives exactly one `Land` or `Ocean` value from the root seed, region identity,
and canonical seed face; for multi-region maps the canonical assignment ensures
both classes exist. `terrain_by_face` is a complete owner-derived projection of
all 320 microfaces. The validator independently re-derives both arrays and
requires complete equality.

Five replay-safe topology features are derived from terrain and region
adjacency:

- continents: connected Land components of at least three regions;
- archipelagos: connected Land components of one or two regions;
- bays: Ocean regions adjacent to at least three Land regions;
- peninsulas: Land regions with at least two Ocean neighbors and at most two
  Land neighbors;
- straits: Ocean regions with at least two Land neighbors and at most two Ocean
  neighbors.

These definitions, component membership, region lists, terrain arrays, and
feature lists are all hash-bound authority. The 2,000-seed audit requires each
feature class to occur at least once in aggregate, exact same-seed terrain
parity, changed-seed terrain delta, complete region/face coverage, and zero
float fields.

## Shared boundary contract

A region boundary consists only of half-edges whose face owner differs from
the twin face owner. Each mesh boundary edge therefore has one direction owned
by each adjacent region. Cycles retain the owner-facing direction, start at the
smallest unused half-edge identity, remain closed through destination-to-origin
continuity, and are sorted without flattening multiple loops.

Region adjacency is derived exclusively from cross-owner twins. Presentation
may later project the frozen vertex identities into `Vector3` positions, but
those positions cannot create or override ownership, adjacency, or boundaries.

## Stage 1 integration

`V076PartitionReducerV1` is an instantiable `Script` whose fresh instances are
created by `V076DeterministicKernel`. It declares the exact stateless,
deterministic, replay-safe, no-side-effect, no-presentation contract. One closed
`generate_shared_half_edge_partition` command commits one partition atomically;
a second generation in the same domain state fails closed.

Snapshots and replay use the existing Stage 1 canonical state codec, command
identity, Domain RNG cursor, execution log, tick hashes, and semantic replay
verification.

## Acceptance gates

`v076_shared_half_edge_partition_test.gd` covers the frozen topology including
previous/next reciprocity, closed request/state shapes, the 21-case seven-count
by three-complexity matrix, 31/32 acceptance, 321 capacity rejection, same-seed
fresh parity, changed-seed partition and terrain delta, deterministic terrain
tamper rejection, Stage 1 reducer execution, snapshot restore, presentation
mapping drift rejection, spherical-boundary hit resolution, and production
composition isolation.

`v076_shared_half_edge_partition_2000_seed_test.gd` executes 2,000 distinct
safe-integer seeds and a fresh same-seed regeneration for each. Samples cycle
across all 21 count/complexity cohorts. Aggregate count distribution is:

```text
6=288, 8=287, 12=285, 16=285, 20=285, 24=285, 30=285
```

Complexity distribution is `SIMPLE=667`, `STANDARD=667`, `COMPLEX=666`;
every individual cohort receives 95 or 96 samples.

Every sample must pass generation, exact topology validation, connected region
validation, canonical shared-boundary validation, complete terrain validation,
all-five-feature aggregate support, zero-float authority, and full partition
and terrain SHA parity. The editable Bench scene exposes the same gate to Godot
MCP. Runtime duration is diagnostic only and never contributes to the authority
identity.

## Interactive Debug Sphere

`V076SharedHalfEdgePartitionBench.tscn` is an isolated Node3D diagnostic scene,
not a production composition. It owns a region `MeshInstance3D`, a separate
shared-boundary line `MeshInstance3D`, a selection-highlight `MeshInstance3D`,
and a real `Camera3D`. The presentation-only V0.7.4 geodesic vectors project the
frozen V0.7.6 vertex and face identities; authority ownership and shared edges
still come exclusively from the integer V0.7.6 partition.

Before any V0.7.6 identity indexes a V0.7.4 presentation array, the Bench
requires exact vertex-count and face-ID/order equality and the sealed mapping
fingerprint
`01bdd9e9a5cbda0fd036c649b223ef8fa5bcdfd5c9dc51bad83b91199ef14959`.
Order drift fails closed.

The surface uses distinct Land and Ocean palettes while retaining region-level
variation, and the HUD reports shape complexity, Land/Ocean counts, all five
feature counts, and shared-edge count. The scene routes mouse-button and
mouse-motion events through Godot input:

- left-button drag rotates `PlanetRoot`;
- wheel input changes bounded camera distance;
- a click projects a camera ray onto the unit sphere and uses oriented spherical
  triangle half-space containment to resolve the microface. A hit exactly on a
  shared edge deterministically selects the smallest matching face ID. The
  authoritative owner is then selected and its faces are raised;
- every cross-owner half-edge pair is rendered once as a cyan shared-boundary
  segment.

The MCP Bench drives the same input path, records before/after rotation and
zoom, requires a successful hit-test and visible non-empty highlight, captures
a headed PNG, and includes this evidence in its final receipt. None of these
float vectors, colors, camera values, or screenshot bytes enters gameplay
authority.
