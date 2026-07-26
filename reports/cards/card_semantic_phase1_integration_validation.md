# Card Semantic Phase 1 Integration Validation

## Scope

- Task start HEAD: `1552c39dc405dd336fa5a00848b3d3425a0ee9a4`
- Final commit parent: `bd24b463660e55d83fc63deaab650c64c134be20` (concurrent analysis-only product/facility/economy audit)
- Verified `origin/main`: `59756a291f811a064726f59aed27efecc3590c9a`
- Production edit: compose three read-only Phase 1 semantic services under the existing `GameRuntimeCoordinator`.
- No gameplay executor connection, consumer cutover, Save section, RNG route, Main edit, catalog edit, rule edit, or balance edit.

## Production Composition

`res://scenes/runtime/GameRuntimeCoordinator.tscn` now contains exactly one instance of each:

- `CardSemanticCatalogService`
- `AiCardSemanticProjectionService`
- `CardPlayerFaceProjectionService`

The services are direct editable scene instances under the existing coordinator. The integration adds no second coordinator, catalog authority, card state owner, or world state owner. There are no signal connections from these nodes to gameplay executors.

## Manifest Evidence

The real MCP Bench exposed a detached pure-data manifest with:

- status: `PASS`
- checks: `46`
- failures: `0`
- duration: `1576.055 ms`
- compiled definitions: `348`
- active definitions: `256`
- projection-only definitions: `92`
- normalized operations: `606`
- semantic catalog fingerprint: `1db2ac3fefdeebcdf2a28525be089cdc2fef383aeebf46f9962a23b8c49d1288`
- service counts: `1 / 1 / 1`
- v3/v0.6 Save sections: `19`
- semantic/setup projection Save sections: `0`
- live RNG delta: `0`
- gameplay executor connections: `0`

Representative compiled definitions:

- active: `commodity.star_dew_berry.rank_1`
- projection-only monster: `unit.monster.spore_tide_emperor.rank_1`
- projection-only interaction: `interaction.starlink_dismantle.rank_1`

The active semantic produced one legal `AiActionCandidate` and one valid PlayerFace DTO. Both were bound to the same card identity and semantic fingerprint. Monster and interaction semantics produced zero AI candidates while still producing static PlayerFace DTOs.

## Determinism And Boundaries

- Repeated authorized compilation returned the same detached semantic spec.
- Repeated AI projection returned the same detached candidate.
- Repeated PlayerFace projection returned the same detached DTO.
- Mutating returned copies did not affect later results.
- Repeating AI projection 64 times left catalog cache metrics unchanged:
  - cache entries: `348 -> 348`
  - compile count: `348 -> 348`
  - cache hits: `5 -> 5`
  - compile failures: `0 -> 0`
- `RunRngService.debug_snapshot()` was byte-equivalent before and after compilation/query/projection work.
- All semantic specs, candidates, DTOs, and the exposed manifest passed the shared pure-data policy; no Node, Object, or Callable crossed an output boundary.
- Catalog debug output is aggregate-only and exposes no arbitrary card-ID lookup or cache enumeration.
- New production service source has no Main, current-scene, RNG, Save owner, `_process`, or `_physics_process` dependency.
- AI projection source does not call or preload the semantic compiler.
- Shared `CardSemanticSchemaV1` remains the sole Card semantic validator; the Bench adds no duplicate semantic enum.

## Test Evidence

| Gate | Result | Checks / work | Runner time | Suite evidence |
| --- | --- | ---: | ---: | ---: |
| `card_semantic_phase1_integration_test.gd` | PASS | 27 outer assertions, 46 manifest checks | 8.717 s | 2586.569 ms |
| `card_semantic_schema_compiler_test.gd` | PASS | 5290 | 2.274 s | 1682.595 ms, compile 522.403 ms |
| `ai_card_semantic_projection_test.gd` | PASS | 211 | 1.030 s | 400 projections in 313.369 ms |
| `card_player_face_projection_test.gd` | PASS | 57 | 2.186 s | 600 projections in 1571.141 ms |
| `v06_save_owner_registry_test.gd` | PASS | 12 | 6.884 s | fixed 19-section registry |
| `main_runtime_composition_test.gd` | PASS | composition gate | 10.259 s | `MAIN RUNTIME COMPOSITION PASS` |

All wrapper results reported process exit `0`, runner exit `0`, no timeout, no remaining scoped process, and script error count `0`.

## Godot MCP Evidence

- Role: `Supervisor`
- Endpoint: `http://127.0.0.1:8975/`
- Godot: `4.7-stable (official)`
- Editor PID for accepted run: `16072`
- Editable Bench: `res://scenes/tools/CardSemanticPhase1IntegrationBench.tscn`
- Production composition: real `res://scenes/runtime/GameRuntimeCoordinator.tscn`
- MCP runtime manifest: `PASS`, `46/46`, `1576.055 ms`
- MCP error log lines after Bench: `0`
- Bench play stopped: confirmed `is_playing_scene=false`
- Formal main scene started through MCP and exposed `/root/Main` from `res://scenes/main.tscn` plus the real production coordinator subtree.
- Main-scene MCP error log lines: `0`
- Main-scene play stopped normally.

The Funplay `save_scene` helper recursed while serializing the large Coordinator and crashed the first editor process. That generated formatting churn was fully restored. The accepted edit used the same role-local Funplay MCP `write_file` tool, which reloaded and identity-verified the open scene while preserving a minimal 13-line scene diff.

## Environment Notes

The headless integration, Save registry, and pre-existing main composition gates emit Windows Unicode/NUL warnings while loading the large legacy composition. The pre-existing `main_runtime_composition_test.gd` emits six such lines independently. They are not GDScript parse errors: wrapper script-error counts remain zero, all completion markers are present, and the MCP runtime error log is empty. No timeout was raised to hide this noise.

## Remaining Risk And Claims

- This commit composes and proves the Phase 1 services only.
- Existing gameplay, UI, and AI consumers are unchanged.
- Monster and interaction semantics intentionally remain `projection_only`.
- The Bench uses authorized stable localization message IDs solely to prove PlayerFace projection; it is not a production localization cutover.
- No Save/resume schema change was made and no full-resume claim is made.
- No rule result, balance value, target, RNG order, or legacy consumer path was changed.

Mergeability verdict: `MERGEABLE` after final diff, UID, process, and clean-worktree checks.
