# V0.7.6 deterministic Monster L1 directional geodesic movement

Status: **ISOLATED Stage 3 candidate**. There is no production composition
cutover in this stage.

## Authority boundary

`monster.l1.move` owns movement intent, route progress, asset activation,
cooldown, region crossings, and ground-trample distance. It binds the Stage 2
topology SHA exactly:

`5cbd98e4027bc2cfd058c857e1a24a5f7c8c61291f1cb7ae7336bcf6851f6452`

The authority metric is a deterministic weighted spherical geodesic on the
sealed 320-face graph. A 960-slot table binds each sorted face-neighbor slot to
one of six rounded great-circle face-center arc lengths in integer
microradians. Its seal is
`33ec702946b6d4bb5c417e4203b85ccb4d787547cb543c1f133f9c23ff1d07d5`.
Canonical integer Dijkstra ordering is `(distance, face_id)` with a stable
predecessor tie-break. Segment lengths range from 155,593 to 185,653 μrad;
the ownership boundary is the deterministic quantized arc midpoint. Route
identity binds the start, exact target point, full face path, every segment
arc, total distance, metric ID, arc-table seal, and topology SHA. Float,
`Vector3`, render geometry, camera state, and wall time never enter authority.

The target is not only a face label. It is a closed spherical point record:
the exact face ID and ordered topology vertex IDs with equal integer
barycentric weights under a normalized spherical projection rule. The target
point is validated against the sealed topology and cross-bound into the route,
monster record, command, receipt, and replay hash.

The authoritative spherical position is the route segment index plus integer
segment progress. `current_face_id` changes at the exact segment midpoint,
while terminal mid-segment progress remains preserved. Movement records bind
target face, maximum distance, speed per tick, accepted tick, accepted
Authority Sequence, last move tick/sequence, route SHA, revision, and source
asset.

## Root, derived, fizzle, and asset rules

A legal root `start_directional_geodesic_move` activates one preferred-color
asset unit exactly once
and emits the first future `advance_directional_geodesic_move`. Each advance
uses the Kernel V2 outbox to emit at most one next-tick advance. Replay submits
only the start root and must regenerate every derived command and lineage SHA.

Stale revisions, an already-moving monster, invalid gameplay target, missing
gameplay entity, cooldown conflict, or non-center restart are consumed legal
fizzles with append-only receipts and no derived output. Malformed envelopes or
invalid authority state reject the whole tick. Asset activation records bind
command ID, monster, preferred color, quantity before/after, tick, Authority
Sequence, and cooldown end. Activation count must equal both unique activation
log cardinality and `total_quantity - quantity_remaining`. A cooling asset
fizzles without decrement; after cooldown expiry, a remaining unit can be
reused and decrements exactly once.

GROUND movement allocates every travelled arc microunit to the physical region
on the source or destination half of each segment. Its distance ledger must
sum exactly to total travelled distance. At root acceptance, the reducer
freezes the command's integer PPM modifier list. Effective efficiency is the
monster base efficiency multiplied by each frozen modifier with deterministic
integer floor at every step. Per-region damage is then exactly
`floor(region_distance_mu * effective_efficiency_ppm / 1_000_000)`; total
damage is the sum of that canonical ledger. FLYING and PHASE default to exact
empty/zero distance and damage ledgers. Region crossings are counted only when
a GROUND interval passes the sealed midpoint between faces owned by different
regions.

## Acceptance surface

- `res://tests/v076_monster_l1_directional_geodesic_move_test.gd`
- `res://tests/v076_monster_l1_directional_geodesic_move_1000_seed_test.gd`
- `res://scenes/tools/v076/V076MonsterL1DirectionalGeodesicMoveBench.tscn`

The focused gate covers canonical integer routes, segment allocation,
mid-segment position, distance caps, root/derived replay, outbox lineage,
Authority Sequence, legal cooldown fizzle, exact-once activation, all three
movement classes, topology tamper rejection, and zero-float terminal state.
The sampled gate uses 1,000 distinct seeds across the seven required Stage 2
region counts, all three shape complexities, and all three movement classes;
every seed executes two fresh root-only replays with zero mismatch.

The isolated Godot Bench renders the sealed face mapping, canonical route, and
terminal monster marker using V0.7.4 float geometry only after exact face-order
and mapping-SHA parity. It is diagnostic presentation evidence only. Its HUD
and receipt explicitly state `human_golden_step_06_09=false`; it is not a
human-operated Golden STEP06-09 result and must never be represented as one.

This work is classified `CROSS_DOMAIN_INTEGRATION`: in addition to the Monster
authority surface and its isolated tests/Bench/docs, it directly changes Kernel
V2 and replay ownership for root/derived/outbox/fizzle semantics. Those direct
Owner changes pass the `74/74` focused gate with `2,000` deterministic replays.
Stage 2 generator, topology, validator, and codec bytes remain unchanged; only
the Stage 2 map reducer changes for the Kernel V2 reducer-ABI adaptation, with
the Stage 2 focused `90/90` sentinel passing.

This stage does not modify `project.godot`, `main.tscn`, V0.7.5/V0.7.4
production code, autoloads, or production composition.
