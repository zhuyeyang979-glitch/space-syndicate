# AI Card Semantic Projection Validation

## Identity

- Wave: Card Semantic Phase 1, Wave 2 Subagent D
- Base: `a96c34f9d1a9f79fc20c4689b8d2ff82e22c623e`
- Required compiler ancestor: `cd8b593` (`CardSemanticSchemaV1`)
- Branch: `codex/card-semantic-wave2-d-ai-projection-a96c34f`
- Mechanic: `card_semantic_projection_v1_migration`
- Runtime mutation: none
- Persistence: none
- RNG: none

## Responsibilities

`AiCardSemanticProjectionService` is orchestration only. It validates the
semantic spec through the preloaded shared
`res://scripts/cards/semantic/card_semantic_schema_v1.gd`, gates readiness,
coordinates the AI input and outcome helpers, builds detached candidates, and
sorts them deterministically.

The production split is:

- `ai_card_semantic_projection_service.gd` (181 lines): request counters,
  active-readiness gate, candidate assembly, fingerprints, and ordering;
- `ai_card_semantic_projection_input_v1.gd` (295 lines): closed
  `CardInstanceState`, viewer-authorized observation, legal-target proof,
  privacy, provenance, and revision validation;
- `ai_outcome_vector_v1.gd` (118 lines): exact eleven-dimension vector and one
  neutral op-to-evidence projection registry.

There is no AI-owned `CardSemanticSpec` root/category/target/filter/op/facility
or organization schema table and no duplicate semantic validator. The shared
schema exclusively owns `validate_semantic_spec()`, pure-data validation,
canonical JSON, and semantic/candidate/observation fingerprints. The AI op
registry is projection only: a future shared-valid but unmapped op contributes
zero neutral evidence and is not rejected as an AI rule-schema decision.

## Delivered Boundary

`project_candidates()` accepts exactly three detached dictionaries:

1. an already-authorized `CardSemanticSpec` v1 accepted by the shared schema;
2. a closed `CardInstanceState` v1 from an authorized own-hand/public source;
3. a fingerprint-valid viewer observation carrying source provenance,
   matching semantic/instance/world revisions, and typed legal-target proofs.

Only `runtime_readiness_id=active` can reach candidate assembly.
`projection_only` and `not_acquirable` are valid semantic states but always
return an empty candidate array, even when a caller supplies a valid legal
target proof. Their rejections increment one count-only diagnostic.

Each accepted target produces one deterministic `AiActionCandidate` with the
frozen fields, detached activation cost, exact eleven-dimension neutral outcome
vector, uncertainty, counter risk, stable explanation tokens, and canonical
SHA-256 fingerprint. Numeric counter risk is copied only from the bounded,
viewer-authorized legal-target fact. `response_id=counterable` adds the stable
`semantic.response.counterable` explanation token but adds no numeric prior.

Candidates contain no scalar AI value, score, personality weight, mutation
request, gameplay receipt, hidden owner, rival-private value, or future bag
state. The projector has no catalog lookup/enumeration, runtime controller,
effect router, save owner, RNG, timer, process loop, Main/current-scene lookup,
or dynamic method dispatch.

## Closed Validation

The shared semantic validator rejects unknown/malformed semantic specs and
unknown ops. The AI input boundary rejects the whole request for:

- malformed or non-pure instance/observation/legal-target dictionaries;
- invalid observation or legality fingerprints;
- semantic, instance, source-slot, source, legal-target, or world revision
  mismatches;
- unsupported source kinds and source/scope combinations;
- response-window/main-action provenance mismatches;
- missing legal-target proof or target-contract mismatch;
- queued, locked, or cooling instances;
- `Node`, `Object`, `Resource`, `Callable`, or other non-data values;
- hidden/true owner fields, rival-private hands/cash, private target/discard,
  future bag/order/RNG state, save payloads, method/script paths, AI scalars,
  and policy weights.

Inputs are never mutated. Returned candidates are deep detached copies.
Candidate sorting uses target contract ID, stable target ID, action ID, and
fingerprint; it does not use input enumeration order or RNG.

Diagnostics expose ten integer counters only. No spec, instance, observation,
target, candidate, explanation, or owner payload is retained.

## Representative Coverage

The Bench and focused test cover stable candidates for:

- commodity `install_rate`;
- facility build, upgrade, and repair;
- unit deploy and same-family upgrade;
- supply and demand modification;
- random discard, steal, and lock;
- response-window `counter_action`.

Interaction fixtures additionally prove both non-executable readiness states
emit no legal candidate and counterability with zero authorized risk evidence
keeps candidate and outcome `counter_risk=0` while retaining its explanation
token.

## Godot MCP Evidence

- Role/endpoint: Role B, `http://127.0.0.1:8885/`
- Godot: `4.7-stable (official)`
- Endpoint root: exact Wave 2 D worktree
- Shared-schema dependency rebased first: `cd8b593`
- Production scripts and both editable scenes were written through Funplay MCP.
- Five changed GDScripts validated through MCP with zero diagnostics.
- Bench editor scene: two nodes, with one real instance of
  `res://scenes/runtime/AiCardSemanticProjectionService.tscn`.
- Final custom-scene run: `PASS`, 183 checks, 12 representative candidates,
  zero failures.
- Live count-only query: 10 counter fields and exactly 2 non-executable
  readiness rejections.
- MCP error-log query: zero lines.
- MCP play stop succeeded; `get_play_state` returned
  `is_playing_scene=false`.
- The normal editor close exceeded its 30-second grace period; an MCP-scheduled
  editor SceneTree quit then completed normally. PID `10488` exited, port
  `8885` closed, the PID file was cleared, and the role stop script reported
  `stopped=true` / `already_exited=true`.

## Focused Headless Evidence

Command:

```powershell
pwsh -File tools/invoke_godot_test.ps1 `
  -TestScript res://tests/ai_card_semantic_projection_test.gd `
  -TimeoutSeconds 59 `
  -ExpectedCompletionMarker AI_CARD_SEMANTIC_PROJECTION_TEST_COMPLETE
```

Final result against the MCP-written files:

- runner status: `passed`
- process/runner exit: `0 / 0`
- duration: `0.863s`
- assertions: 211
- script errors: 0
- completion marker: found
- 400 repeated projections: `275.661ms`
- remaining project runtime processes: 0

## Integration Order

The coordinator should apply compiler commit `cd8b593` first, then cherry-pick
the final AI projection commit reported in the handoff. No compiler-owned file
is modified by the AI commit.

## Deliberate Residuals

`scripts/runtime/ai_runtime_controller.gd` remains intentionally unchanged.
The 225 direct card-payload reads across 33 functions, including hidden-owner
blockers and repeated definition work, remain inventoried in
`reports/cards/ai_direct_field_read_migration.md`. This wave adds the typed
projection boundary and stable snapshots only; it does not perform the AI
consumer cutover or preserve a dual fallback.

`GameRuntimeCoordinator.tscn` is a later integration-writer file. The service
scene is ready to compose once the semantic cache, authorized instance adapters,
and viewer-authorized legal-target observation are integrated. No save section
or gameplay authority was added.

## Risks

1. Provenance authenticity remains the source owner's responsibility. This
   projector validates closed source/scope IDs, fingerprints, and cross-record
   revision binding; it intentionally owns no opaque capability.
2. Integration must preserve dependency order: `CardSemanticSchemaV1` before
   this AI commit. The AI code intentionally has no fallback semantic schema.
3. Neutral evidence counts are not utility or probability. A future shared-valid
   op is safe but projects zero until AI semantics deliberately register it.
4. Existing hand and public-rack ports still need a small adapter to emit the
   closed instance plus viewer observation; this wave does not widen those
   owners or read future supply state.

## UID Hygiene

Godot 4.7 generated 19 unrelated untracked baseline UIDs under existing tools
and tests. After stopping the editor, a dry run verified the exact allowlist,
existence, untracked status, worktree containment, and disjointness from owned
scripts. Those 19 files were removed. The only new UIDs retained are for
`ai_card_semantic_projection_input_v1.gd` and `ai_outcome_vector_v1.gd`;
the service, Bench, and focused-test UIDs were already owned by the prior AI
commit.
