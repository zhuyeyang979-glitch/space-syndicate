# Card Player Face Projection Validation

Status: `PASS`

Branch: `codex/card-semantic-wave2-f-face-dto-a96c34f`

Base: `a96c34f9d1a9f79fc20c4689b8d2ff82e22c623e`

Compiler prerequisite: `cd8b593e3090ba9fc2b76090148cc6edf4d430db`

Mechanic: `card_semantic_projection_v1_migration`

## Implemented Boundary

- `PlayerFaceDTOv1` seals one exact-key, detached dictionary schema and validates
  every nested cost, timing, target, condition, effect-step, duration,
  counterability, information-scope, keyword, message-ref, typed-argument, and
  token row.
- Every surface carries stable `name_ref` and `family_name_ref` records. Their
  only typed arguments are the matching `card_id` and `family_id`; the source is
  rejected unless its card and semantic fingerprint match before those message
  IDs are read.
- Acquisition remains `{acquisition_kind, purchase_cash}` and activation remains
  the seven-key asset vector. No `cost`, `price`, `play_cost`, prose, color value,
  or glyph alias is emitted.
- `CardPlayerFaceProjectionService` preloads
  `res://scripts/cards/semantic/card_semantic_schema_v1.gd` and delegates every
  Card semantic admission decision to
  `CardSemanticSchema.validate_semantic_spec()`. PlayerFace owns zero Card root,
  category, target, filter, effect, response, or readiness tables and zero
  duplicate semantic validators.
- Market, hand, and detail use stable `market_acquisition`, `hand_activation`, and
  `detail_complete` profiles. Profiles change only section order and
  `emphasis_id`; semantic content remains identical.
- Localization input is a card/fingerprint-bound public authorization envelope.
  Authorization, source scope, and recursive hidden/private key rejection execute
  before any message identifier is read.
- Message, keyword, icon, and color values are stable IDs. Message args are typed
  rows built from semantic values; localization input cannot supply rule values.
  Formatting uses an exact declared field/type table plus primitive Variant type
  fallback, never substring or suffix inference.
- Effect-step order is contiguous from 1. Duration promotion uses only the exact
  closed IDs `duration_seconds`, `counter_window_seconds`, and `persistence_id`.
  It contains no suffix, prefix, or substring classification and never parses text
  or converts retired turn units.
- The service is stateless and has no cache, RNG, legality, save, world, mutation,
  current-scene, timer, `Main`, Node payload, Object payload, or Callable payload.

## Exact Files

- `scripts/presentation/player_face_dto_v1.gd`
- `scripts/presentation/player_face_dto_v1.gd.uid`
- `scripts/runtime/card_player_face_projection_service.gd`
- `scripts/runtime/card_player_face_projection_service.gd.uid`
- `scenes/runtime/CardPlayerFaceProjectionService.tscn`
- `scripts/tools/card_player_face_projection_bench.gd`
- `scripts/tools/card_player_face_projection_bench.gd.uid`
- `scenes/tools/CardPlayerFaceProjectionBench.tscn`
- `tests/card_player_face_projection_test.gd`
- `tests/card_player_face_projection_test.gd.uid`
- `reports/cards/card_player_face_projection_validation.md`

No existing `CardPresentationRuntimeService`, `CardViewSnapshot`, card UI, catalog,
runtime coordinator, or legacy alias file was edited or deleted.

## Single-Purpose Size Rationale

- `player_face_dto_v1.gd` is 650 lines. It was reviewed as one cohesive,
  fail-closed DTO boundary: exact DTO field constants and three emphasis profiles,
  nested DTO validators, typed message-ref validation, detached pure-data checks,
  and canonical sealing/fingerprinting. Every helper participates in accepting or
  sealing this one shape. It contains no source authorization, Card semantic
  validation/transformation, localization resolution, runtime state, or renderer
  behavior. Splitting validation from sealing would create two files that must
  evolve atomically for the same closed schema without isolating a separate owner.
- `card_player_face_projection_service.gd` is 597 lines after removal of all
  duplicate Card semantic tables and validators. Its remaining stages form one
  stateless projection pipeline: privacy/authorization gate the localization
  envelope, delegate semantic admission to the shared schema, bind authorized
  message/token rows, group typed presentation fields, and seal the DTO. Moving
  localization-envelope checks into the DTO would mix source authorization with
  output validation; moving projection builders into the semantic schema would
  make that gameplay contract own UI grouping. The current split therefore keeps
  the two real responsibilities on their correct sides of the DTO boundary.

## Focused Test

Command:

```powershell
pwsh -File tools/invoke_godot_test.ps1 -TestScript res://tests/card_player_face_projection_test.gd -TimeoutSeconds 55 -ExpectedCompletionMarker CARD_PLAYER_FACE_PROJECTION_TEST
```

Result:

- Exit code: `0`
- Runner duration: `1.804 s` (under the mandatory 60-second bound)
- Checks: `57/57 PASS`
- Bounded loop: `600/600` projections
- Measured loop duration: `1,225,891 us`
- Covered: exact keys, cost separation, all emphasis profiles, canonical
  fingerprinting, detached copies, input non-mutation, authorized name/family refs
  on all three surfaces, ordered effects, explicit allowlisted duration parameters,
  duration-lookalike rejection, raw-name rejection, structured conditions/scope,
  stable token IDs, shared-schema delegation, zero duplicated semantic tables,
  exact typed-argument mapping, privacy-before-localization,
  unauthorized/private/hidden source rejection, source binding, unknown fields and
  operations, fingerprint tampering, non-finite/runtime-object/callable rejection,
  and dependency scans.

## Godot MCP Evidence

Role C editor:

- Endpoint: `http://127.0.0.1:8895/`
- Godot: `4.7-stable (official)`
- Renderer: `compatibility`
- Assigned worktree identity was verified by the launcher.

Required inspection:

- Opened and read `res://scenes/runtime/CardPresentationRuntimeService.tscn`.
- Opened and read `res://scenes/CardUI.tscn`.
- Read `res://scenes/ui/CardFace.tscn`, confirming it instances `CardUI.tscn`.
- Opened the new production service scene; MCP reported one Node and zero children.
- Opened the new Bench; MCP reported two Nodes and the real production service
  scene as its only child.

Production writes and validation:

- `edit_script` wrote the DTO, production service, Bench, and focused test through
  the Role C endpoint.
- `write_file` wrote both production and Bench scenes through the Role C endpoint.
- MCP `validate_script` returned `ok=true`, `diagnostic_count=0` for all four new
  scripts after final alignment.

Final MCP Bench run:

- Scene: `res://scenes/tools/CardPlayerFaceProjectionBench.tscn`
- Runtime node: `/root/CardPlayerFaceProjectionBench`
- Manifest: `22/22 PASS`
- Warmup: `9,627 us`
- Accepted projections: `900/900`
- Projection total: `2,208,876 us` against `5,000,000 us` target
- Projection average: `2,454.3067 us` against `6,000 us` target
- DTO fingerprint: `c01896f8f612ce85a95932ee63553143322da0bd6eef2b856a7473be8d4f92a8`
- MCP error-log query: `line_count=0`
- `exit_play_mode`: `Stopped the running scene.`
- Post-stop state: `is_playing_scene=false`
- Role editor shutdown: PID `28852` exited normally and port `8895` reported
  `port_open=false`.
- UID cleanup dry-run identified exactly 19 untracked UIDs, each inside this
  worktree and paired with a tracked pre-existing script. Those 19 were removed;
  the four UIDs for this wave's new scripts were retained.

## Risks And Follow-up

- This wave intentionally does not wire a production consumer. Wave 3/integration
  must compose the service under `GameRuntimeCoordinator` and migrate consumers
  atomically; the old presentation aliases remain untouched until that cutover.
- Per-op and complete Card semantic authority stays in the independent shared
  schema owner. PlayerFace calls that owner once and performs no root/category/
  target/filter/effect/response/readiness validation of its own.
- The authorized localization envelope still needs authored message/keyword/token
  IDs for the complete catalog. This wave proves the contract with an interaction
  fixture; the 348-card completeness gate belongs to integrated catalog validation.
- Response counterability preserves the semantic `response_id` and does not invent
  a duration absent from the semantic record. Dynamic/legal response state remains
  outside this static DTO.
- Final implementation commit SHA is reported in the handoff because a commit
  cannot self-contain its own SHA.
