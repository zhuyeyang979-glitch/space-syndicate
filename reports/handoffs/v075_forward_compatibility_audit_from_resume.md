# V0.7.5 Forward-Compatibility Audit From Resume

## Declaration

```text
LANE=D
AUDIT_ID=v075.forward_compatibility.audit.from_resume.v1
AUDIT_DATE=2026-08-07
CURRENT_RUNNING_TASK_ID=ALPHA_0_5_C2_V075_MONSTER_AUTONOMY_PRIVATE_INSTANT_SKILLS_AND_MILITARY_ASSAULT_MISSIONS_PRODUCTION_CUTOVER
CURRENT_RUNNING_RULESET_ID=v0.7.5
CURRENT_RUNNING_BRANCH=codex/v075-monster-military-combat-bd0af5c
CURRENT_RUNNING_HEAD=a4a06b96d39b20a94418c4a1c02c74e6af17b9c6
BASE_MAIN_SHA=bd0af5c99c5267cdbe7d66c01034f80db4d704fd
CURRENT_WORKTREE_PRESERVED=true
CURRENT_TASK_NO_RESET=true
V076_STARTED=false
PROHIBITED_SUITES_RUN_BY_THIS_LANE=0
LANE_D_AUDIT_STATUS=GREEN_FOR_HANDOFF
CURRENT_TASK_STATUS=PARTIAL
SUCCESSOR_START_AUTHORIZED=false
```

This report is the only file owned and created by this resume audit. Frozen
V0.7.5/V0.7.4 constitution files, combat source, scenes, resources, and
other lane files were read-only. No implementation, MCP, test, branch, stash,
reset, or commit action was performed by Lane D.

The recorded base SHA above is the current task's known base from the resume
context. It is intentionally retained as audit metadata and is not a claim
that the current task has already been merged or that the successor may start.

## Working-Tree Context

At audit time the current worktree was the existing V0.7.5 worktree, not a new
successor worktree. `git status --porcelain` reported 72 modified entries and
207 untracked entries, including generated import/UID/log artifacts and
ongoing runtime work. They are user progress and remain untouched. The branch
had no matching remote ref according to `git ls-remote --heads origin
codex/v075-monster-military-combat-bd0af5c`.

The current V0.7.5 combat simulation report is explicitly `PARTIAL`, with
`COMBAT_RUNTIME_ERROR_COUNT=78` and missing positive combat-coverage counters.
That evidence is sufficient to keep Stage A open; this lane does not convert
it to GREEN and does not authorize Stage B.

## Execution-Mode Audit

| Contract or flag | Current rule/source state | Audit result | Forward-compatible disposition |
| --- | --- | --- | --- |
| `MILITARY_PUBLIC_BATCH_QUEUE_MEMBER` | `true` in `v075_game_constitution.json`; military selection calls `queue_military_card_action`, which calls `queue_card_action` and appends to `_queued_by_player`; `resolve_next_action` invokes `PublicActionBatchCore.resolve_next_authority_owned` for the resulting `action_domain=military`. | `CURRENTLY_TRUE` and concretely reachable. | Treat as a V0.7.5 implementation/contract conflict with the newest user direction. Do not add more code on this path. Successor amendment must set it to `false`. |
| `MILITARY_INDEPENDENT_SETTLEMENT_LANE` | No independent military owner or settlement queue is present. The application flow exposes `combat.military_mission.select`, but dispatch ends at the public queue path. | `ABSENT` | Mark `pending_v076_private_direct_intervention` in the successor handoff/contract only. Reuse the existing military Core through a typed request port. |
| `DIRECT_ATTACK_PUBLIC_BATCH_QUEUE_MEMBER` | No generic direct-action contract, owner, or application intent was found in the V0.7.5 source. Military is currently modeled as the combat-specific public action domain. | `UNDEFINED`, not safely assumable as `false` in the frozen V0.7.5 contract. | Define one generic successor lane; military is its first `normal_subtype`, and future direct attacks reuse the same owner. |
| `DIRECT_ATTACK_INDEPENDENT_SETTLEMENT_LANE` | No `DirectAction` runtime owner, pending-request list, asset reservation contract, physical arrival contract, or observatory intervention receipt is connected. | `ABSENT` | Implement only in V0.7.6. Do not create a second military-only authority. |
| Military tasks | `V075MilitaryMissionCore` accepts exactly `assault_region` and `assault_monster`; its locks prohibit retargeting, persistent sources, and bound actions. | `CORE_SEMANTICS_REUSABLE` | Preserve the pure Core and its typed damage/DBG/withdrawal intents. Move only submission, travel, and settlement ownership. |
| Military public UI | Existing V0.7.5 military mission selection exposes the two assault task choices. It is not evidence of an independent private intervention lane. | `PUBLIC-SURFACE-CURRENT` | Keep the two task choices, but move the interaction to a private direct-action surface in the successor; add no guard or public queue surface. |

### Evidence for the current military path

- `scripts/v075_runtime/v075_runtime_owner.gd:1121` starts
  `queue_selected_military_mission`; the method forwards to
  `queue_military_card_action`.
- `scripts/v075_runtime/v075_runtime_owner.gd:1020`-`1080` routes military
  options through `queue_card_action`, which writes `_queued_by_player` and
  emits the ordinary queued-action receipt.
- `scripts/v075_runtime/v075_runtime_owner.gd:1257` calls
  `PublicActionBatchCore.resolve_next_authority_owned`, and
  `scripts/v075_runtime/v075_runtime_owner.gd:1286` includes `military` in
  the public combat-action branch.
- `scripts/v075_runtime/v075_application_flow.gd:141`-`147` dispatches the
  military intent to that queueing method; there is no independent direct
  action dispatch.
- `docs/rules/v075_game_constitution.json:341`-`356` freezes the contradictory
  `public_anonymous_batch_member=true` value. The same file still correctly
  records no bound actions at `:403`-`:414` and no guard task at `:415`-`:430`.
- `reports/v075/coordination/lane_e_handoff.md` confirms that Lane E delivered
  a reusable pure Core and explicitly left runtime composition to the
  coordinator. This is the correct reuse boundary for the successor.

## Region Partition And Rendering Audit

| Contract or flag | Current rule/source state | Audit result | Forward-compatible disposition |
| --- | --- | --- | --- |
| `CURRENT_REGION_PARTITION_AUTHORITY` | `V074MapGenesisCore` consumes `V074GeodesicMicrogrid`; the microgrid emits triangular faces, shared undirected mesh edges, face adjacency, and surface area. | `V074_AUTHORITATIVE_SOURCE_PRESENT` | Retain V0.7.4 Genesis and its typed receipt. V0.7.6 should strengthen the receipt contract without replacing the map owner. |
| `CURRENT_REGION_RENDERING_MODE` | `V074PlanetPresentationAdapterV1` emits a per-region `polygon` from a boundary loop; `PlanetMapView` instantiates one `PlanetDistrictPolygon` per region; that node calls `draw_colored_polygon` and `draw_polyline`. | `INDEPENDENT_REGION_POLYGON_RENDERING_ACTIVE` | Must be replaced by one region-ID surface/mesh pass and one border overlay source in V0.7.6. Do not inflate polygons or add overlap masks. |
| `REGION_SHARED_TOPOLOGY_RENDERING` | The adapter can reconstruct a region loop from shared boundary records, and Genesis derives both sides from the same mesh edge. The renderer still rasterizes each region independently. | `SOURCE_SHARED_BUT_RENDER_NOT_SHARED` | Do not call this seamless rendering. Carry the shared-edge source into the successor's single-surface renderer. |
| `CURRENT_REGION_HIT_TEST_MODE` | `PlanetMapView:_v074_authoritative_district_at_control_position` maps screen input to a sphere point, chooses the greatest-dot `hit_test_cell`, then falls back to spherical polygon containment. | `AUTHORITATIVE_MICROCELL_PROJECTION_WITH_NONCANONICAL_FALLBACK` | V0.7.6 must resolve a ray to one authoritative face/microcell and use the same region ownership data used by rendering. Remove polygon containment as a competing authority. |
| `REGION_INDEPENDENT_POLYGON_RENDERING` | `true` in the production sceneized path. | `FAILS_SUCCESSOR_SEAMLESSNESS_PRECONDITION` | No new independent Polygon2D/Control fill code, polygon inflation, alpha seam masking, or z-order ownership. |
| `REGION_PRESENTATION_GAP_COUNT` | No exact screen-pixel gap audit was run by this lane. Existing V0.7.4 generator tests report abstract boundary gap/overlap counters, not the V0.7.6 multi-resolution pixel contract. | `UNMEASURED`, not zero | Leave the field unknown until the successor's pixel audit. Never infer zero from a generated-geometry counter. |
| `REGION_PRESENTATION_OVERLAP_COUNT` | Same limitation as gaps; independent translucent fills make an overlap/coverage audit necessary. | `UNMEASURED`, not zero | Measure at all required resolutions and LODs in V0.7.6. |

### Evidence for the current map path

- `scripts/v074/map/v074_geodesic_microgrid.gd:31`-`58` builds triangular
  microcells and returns `edge_faces`, `edge_vertex_ids`,
  `closed_edge_count`, `nonmanifold_edge_count`, and spherical area.
- `scripts/v074/map/v074_map_genesis_core.gd:649`-`745` only treats an edge
  with two incident faces as a region boundary and derives one shared boundary
  record for the two owner regions. The record currently uses
  `boundary_id`/`mesh_edge_key`; it is not yet the V0.7.6 explicit reversible
  `edge_id`/half-edge contract.
- `docs/rules/v074_game_constitution.json:75`-`93` and
  `docs/rules/v074_game_constitution.md:28`-`32` already prohibit independently
  authored neighbor boundaries at the authoritative Genesis level. This is a
  useful predecessor invariant, not proof that the current Canvas renderer is
  a single shared surface.
- `scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd:100`-`106`
  creates a `polygon` field per district; `:863`-`:869` converts each loop to
  a separate world polygon.
- `scripts/ui/planet_map_view.gd:1047`-`1073` creates one
  `PlanetDistrictPolygon` node per district and
  `scripts/ui/map/planet_district_polygon.gd:45`-`60` fills it independently.
- `scripts/ui/planet_map_view.gd:357`-`393` confirms that hit testing and
  rendering are currently separate paths: hit testing first uses the nearest
  microcell center and then a region polygon fallback, while the visible fill
  uses projected boundary loops.

## Frozen-Flag Verification

### `pending_v076_private_direct_intervention`

```text
PRESENT_IN_V075_CONSTITUTION=false
PRESENT_IN_V075_AUTHORITY_MANIFEST=false
PRESENT_IN_PRODUCTION_RUNTIME=false
CURRENT_V075_MILITARY_MODE=public_batch_queue
MUST_BE_TREATED_AS=pending_successor_migration_marker
```

The marker is therefore not falsely reported as an already-frozen V0.7.5
production rule. The V0.7.5 constitution is historically frozen and contains
the older public-batch wording; it must not be edited in place. The marker
belongs in the successor amendment/authority manifest and in the current-task
handoff metadata until that successor is actually implemented and accepted.

### `exact_shared_topology_required`

```text
PRESENT_IN_V075_CONSTITUTION=false
PRESENT_IN_V075_AUTHORITY_MANIFEST=false
V074_PREDECESSOR_INVARIANT=closed_geodesic_microcell_partition_plus_shared_boundary_single_authority
CURRENT_RENDERER=independent_per_region_projected_polygon_fill
MUST_BE_TREATED_AS=pending_successor_topology_contract
```

The existing V0.7.4 map contract is a strong authoritative-generation
precondition, but it does not freeze the V0.7.6 requirements for a closed
manifold face assignment, explicit two-face edges, exact surface coverage,
single-pass region-ID rendering, or render/Hit Test parity. Those requirements
must be introduced as a new V0.7.6 contract, not retroactively written into a
V0.7.4 or V0.7.5 historical file.

## Minimal Forward-Compatible Amendments

These are recommendations for the coordinator and successor task. They are
not edits made by this lane.

1. Preserve the supply/DBG lifecycle exactly: military remains a
   `normal_card`, remains a member of the ten-slot shared sushi supply track,
   purchases to personal discard, reshuffles, enters the normal hand, and
   returns to personal discard after resolution. The amendment changes only
   execution: `public_anonymous_batch_member=false`,
   `public_action_slot_cost=0`, and
   `execution_lane=pending_v076_private_direct_intervention`.
2. Define one generic `DirectAction` request/receipt contract and one runtime
   owner. Military is `normal_subtype=military`; future direct attacks must
   reuse the owner and typed ports rather than create per-card runtime
   branches. Keep the existing `V075MilitaryMissionCore` as a pure planner.
3. Add the minimum direct-action envelope: card instance/generation, owner,
   launch-origin binding, target binding, six-color asset cost, reservation
   receipt, physical travel profile, authority receive sequence, accepted
   world revision, and post-resolution DBG destination. Keep pending card,
   target, cost, and ordering private until a public effect receipt begins.
4. Add physical arrival/ETA fields to the typed military path. Instant commit
   means card removal and full asset reservation; it must not imply teleport.
   A military intervention may affect a monster battle only when its
   authoritative spherical path and authored speed prove arrival by the
   intervention deadline. Late requests reject or become later authored tasks
   without retargeting.
5. Reuse V0.7.4 Genesis as the map owner, but add a V0.7.6 exact-partition
   contract: every triangular face has one region, every mesh edge has exactly
   two incident faces, adjacent regions share one canonical edge identity with
   reverse orientation, land and ocean have no unassigned background, and
   area sums cover the sphere within the specified tolerance.
6. Replace only the presentation authority: one spherical surface/mesh with a
   region-ID attribute or texture, one shared-border extraction pass, and a
   ray-to-authoritative-face Hit Test. Keep labels, routes, facilities, and
   combat effects as overlays. Do not change V0.7.4 map generation, region
   count support, warehouse slots, or combat distance math in this audit.
7. Add explicit transition labels to the Stage A handoff:
   `superseded_by_v076_direct_intervention` for the current military public
   queue path and `superseded_by_v076_exact_partition` for independent polygon
   presentation. These labels prevent the current implementation from being
   mistaken for the successor's final contract while preserving all existing
   progress.

## Required Successor Gates

Before any Stage B branch is created, Stage A still needs its own production
completion, PR, merge, pushed tag, clean worktree, and local-main/origin sync.
For the successor, the minimum relevant flags are:

```text
MILITARY_UNIFIED_SUPPLY_TRACK_MEMBER=true
MILITARY_NORMAL_DBG_MEMBER=true
MILITARY_PUBLIC_BATCH_QUEUE_MEMBER=false
DIRECT_ATTACK_PUBLIC_BATCH_QUEUE_MEMBER=false
DIRECT_ACTION_RUNTIME_OWNER_COUNT=1
DIRECT_ACTION_PUBLIC_PENDING_LIST_COUNT=0
DIRECT_ACTION_FULL_ASSET_RESERVATION_GREEN=true
MILITARY_INSTANT_COMMIT=true
MILITARY_INSTANT_TELEPORT=false
MILITARY_PHYSICAL_TRAVEL_REQUIRED=true
MILITARY_LATE_ARRIVAL_AFFECT_CURRENT_COMBAT_COUNT=0
SPHERE_MANIFOLD_GREEN=true
SPHERE_UNASSIGNED_FACE_COUNT=0
SPHERE_MULTI_ASSIGNED_FACE_COUNT=0
MESH_EDGE_NON_TWO_FACE_COUNT=0
REGION_ID_SURFACE_SINGLE_PASS_GREEN=true
SHARED_BORDER_SINGLE_SOURCE_GREEN=true
MAP_HIT_TEST_RENDER_REGION_MISMATCH_COUNT=0
```

No value above is claimed as green by this handoff. They are the minimum
acceptance targets that the V0.7.6 task must establish and prove on its own
SHA.

## Final Lane Decision

```text
CURRENT_TASK_ORIGINAL_SCOPE_RETAINED=true
CURRENT_TASK_NEW_USER_FILES_PRESERVED=true
CURRENT_TASK_NO_RESET=true
MILITARY_PUBLIC_QUEUE_NEW_CODE_ADDED_BY_THIS_LANE=0
DIRECT_ATTACK_PUBLIC_QUEUE_NEW_CODE_ADDED_BY_THIS_LANE=0
INDEPENDENT_REGION_POLYGON_INFLATION_ADDED_BY_THIS_LANE=0
PENDING_V076_PRIVATE_DIRECT_INTERVENTION_FALSELY_FROZEN=false
EXACT_SHARED_TOPOLOGY_FALSELY_FROZEN=false
STAGE_A_COMPLETION=NOT_YET
STAGE_B_START=FORBIDDEN_UNTIL_STAGE_A_GREEN_AND_MERGED
```

The current task remains `PARTIAL`. Preserve the worktree and continue Stage A
on its original scope, with the two transition labels above. Do not start
`ALPHA_0_5_C3_V076_EXACT_SPHERICAL_PARTITION_AND_PRIVATE_DIRECT_COMBAT_INTERVENTION_LANE`
from this state.
