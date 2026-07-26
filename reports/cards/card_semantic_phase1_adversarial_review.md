# Card Semantic Phase 1 Adversarial Architecture Review

## Verdict

`CHANGES_REQUIRED`

The composition commit is passive: it adds one semantic cache, one AI projector,
and one PlayerFace projector under the existing coordinator, with no gameplay,
AI-runtime, UI, save, RNG, or executor connection. The focused gates are green.

Phase 1 is nevertheless not ready to be treated as an authorized or executable
boundary. Two blocker-class trust gaps remain:

1. `compile_authorized()` accepts a structurally valid full card record that is
   not a member of the configured v0.6 catalog, compiles it on a cache miss, and
   adds it to the production cache.
2. `runtime_readiness_id` is self-asserted data. A caller can recompute the plain
   SHA fingerprint and make the AI projector emit `legal=true` for a semantic
   combination that was never emitted by the compiler and has no registered
   executable handler.

These are dormant in the current composition because no production consumer is
connected, but they must be fixed before this boundary is advertised to AI, UI,
or gameplay code.

## Reviewed State

- Integration baseline: `59756a291f811a064726f59aed27efecc3590c9a`
- Reviewed integration tip: `4f50cc439d2879849ca1c125a320af8a18c7465e`
- Composition commit: `ebdd30512c52ac082354052bd1c798905896058e`
- Fixture source commits inspected: `42b492b2b505ad908f7df13b45fa299d5a4c0acc`, `8194efd4349ffbeb8358de45eb851ca625356c9c`
- Integrated fixture equivalents: `dc004bf`, `f08dfe9`
- Review worktree: isolated from the coordinator worktree

The corrected facility/commodity fixture now matches the compiler dialect and
all three golden files cite the current catalog SHA
`b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40`.

## Blockers

### CSAR-B01: Authorized compilation is not bound to the configured catalog

Severity: `blocker`

Evidence:

- `scripts/runtime/card_semantic_catalog_service.gd:70` accepts an envelope and
  delegates its enclosed record directly to the compiler at line 75.
- `scripts/cards/semantic/card_semantic_schema_v1.gd:111` validates envelope
  shape, source kind, and visibility scope, but line 128 only checks that
  `card_record` is a dictionary.
- `scripts/cards/semantic/card_semantic_compiler_v1.gd:78` derives a cache key
  from caller-provided machine data; lines 82-89 compile and cache any valid
  cache miss after the production catalog has already been configured.
- `scripts/tools/card_semantic_phase1_integration_bench.gd:289` records
  `arbitrary_card_lookup=false` as a literal rather than testing a forged full
  record. The existing negative test at
  `tests/card_semantic_schema_compiler_test.gd:224` only adds an extra envelope
  field; it does not replace the enclosed record with a new valid identity.

Impact:

A caller does not need the prohibited card-ID lookup API. It can submit a new
schema-valid `machine` block with a new `card_id`/`family_id`, valid payload, and
arbitrary legal values. The service will compile it, increase the cache size,
and return a semantic spec under the configured catalog ID. A SHA fingerprint
detects accidental mutation; it does not authenticate catalog membership.

Required fix:

- Seal the source-definition fingerprints and card identities during
  `configure()`.
- After sealing, `compile_authorized()` must be cache-hit only and reject an
  unknown source fingerprint without changing cache metrics.
- Bind the envelope to an existing typed visibility-owner receipt; do not trust
  a caller-authored `source_kind`/scope tuple as authorization.
- Add a test that mutates a valid record into a new valid card identity and
  proves rejection, zero cache delta, and zero returned spec.

### CSAR-B02: Executable readiness is caller-controlled, not registry-attested

Severity: `blocker`

Evidence:

- `scripts/cards/semantic/card_semantic_schema_v1.gd:96` checks only that
  `runtime_readiness_id` is one of three strings. It does not bind readiness to
  source identity, effect contract, operation set, or a handler registry.
- `scripts/cards/semantic/card_semantic_compiler_v1.gd:12` statically labels four
  effect families active; no registered handler or capability receipt is read.
- `scripts/runtime/ai_card_semantic_projection_service.gd:41` accepts any
  self-consistent spec and line 48 gates solely on the spec's readiness string.
- `scripts/tools/ai_card_semantic_projection_bench.gd:557` creates every
  representative scenario as active, including compiler-projection-only
  mechanisms. `tests/ai_card_semantic_projection_test.gd:403` then expects an
  active interaction fixture to emit a legal candidate.
- `scenes/runtime/GameRuntimeCoordinator.tscn:522` composes the semantic service,
  but no operation registry or executable readiness attestation is composed.

Impact:

A caller can take a valid projection-only spec, change readiness to `active`,
recompute the unkeyed semantic/world fingerprints, and receive `legal=true`.
The same path accepts schema-valid capability-only operations that the card
compiler never emits. This makes `legal` and `active` stronger claims than the
system can prove.

Required fix:

- Separate catalog projection status from executable runtime readiness.
- Make legal candidate emission require a coordinator-owned, sealed readiness
  receipt covering semantic fingerprint, operation IDs, legality revision, and
  registered handler capability.
- Reject active readiness that is not the exact sealed value for that compiled
  source fingerprint.
- Add negative tests for a re-signed projection-only spec and a schema-valid
  operation that has no registered card handler.

## Major Findings

### CSAR-M01: Non-card capability operations are admitted by CardSemanticSpec

Severity: `major`

`scripts/cards/semantic/card_semantic_schema_v1.gd:63` admits
`military_move`, `military_guard`, `military_strike`, `global_order`, and
`global_supply_spawn` as parameterless card effect operations. The compiler
does not emit them. `tests/card_semantic_schema_compiler_test.gd:168` explicitly
asserts that these synthetic operations are valid, and
`scripts/runtime/ai_outcome_vector_v1.gd:29` projects several of them.

Move military actions into `MilitaryUnitSemanticSpec` and move shared
capabilities into the operation registry. CardSemanticSpec should admit only
operations that can occur in a compiled card effect plan.

### CSAR-M02: AI privacy validation blocks key names, not hidden value channels

Severity: `major`

`scripts/runtime/ai_card_semantic_projection_input_v1.gd:229` recursively
rejects forbidden keys, but lines 219-226 accept any stable string as a target
identity and lines 197-200 accept any stable explanation tokens. The projector
copies both into the candidate at
`scripts/runtime/ai_card_semantic_projection_service.gd:122` and line 154.

A buggy producer can encode a hidden owner, hidden card ID, or private target in
an allowed `stable_id` or token. Before AI cutover, compose a viewer-scoped
observation owner with closed target-reference and explanation-token registries;
add sentinel tests for hidden values, not only hidden key names.

### CSAR-M03: PlayerFace localization authorization is self-asserted

Severity: `major`

`scripts/runtime/card_player_face_projection_service.gd:298` trusts the input
boolean `authorized`, scope string, and positive revision. Lines 311-349 bind
the card/fingerprint and validate stable message IDs, but do not prove that a
localization owner issued those IDs or that an effect message describes the
bound `op_id`. The integration Bench fabricates the authorization and message
rows at `scripts/tools/card_semantic_phase1_integration_bench.gd:384`.

No production UI currently consumes this service, so there is no present UI
regression. Before UI cutover, use a real localization/query port that maps
semantic IDs to message/token IDs and emits a bound receipt; remove the
caller-controlled authorization boolean.

### CSAR-M04: Information scope describes source access, not effect disclosure

Severity: `major`

`scripts/cards/semantic/card_semantic_schema_v1.gd:283` permits only
`authorized_source_only`, which describes access to the definition rather than
what an effect reveals after resolution. PlayerFace exposes that value as the
card's information scope at
`scripts/runtime/card_player_face_projection_service.gd:246`. Its helper at
line 492 also treats `visibility_policy_id` as a scope row because it excludes
the nonexistent key `policy_id` at line 496.

Introduce explicit effect/result visibility policies before interaction and
counter cards become active. Player text and AI observations must project from
that policy rather than from independently selected localization messages.

### CSAR-M05: Golden fixtures are corrected but have no automated consumer

Severity: `major`

The three files under `tests/fixtures/card_semantic_phase1/` are now internally
current, but repository search finds zero test or tool references to their file
names outside their own declarations. The compiler test entrypoint at
`tests/card_semantic_schema_compiler_test.gd:53` compiles the live catalog and
runs inline assertions through line 131; it never loads a golden fixture.

Add one focused fixture gate that loads all three files, verifies source SHA,
compiles every referenced card, and compares the exact semantic body and both
fingerprints. Current manual evidence is useful but is not a regression gate.

### CSAR-M06: v0.4 and v0.6 catalog authority remain composed together

Severity: `major`

The coordinator still instances the v0.4 authoritative
`CardRuntimeCatalogService` at `scenes/runtime/GameRuntimeCoordinator.tscn:257`
and the v0.6-derived semantic cache at line 522. The v0.4 scene explicitly loads
`card_runtime_catalog_v04.tres` at
`scenes/runtime/CardRuntimeCatalogService.tscn:4`.

This is an acknowledged compatibility bridge, not a newly created second
semantic state owner. It must still be retired before claiming one authoritative
card catalog or a unified rules execution path.

### CSAR-M07: Production AI still reads raw card fields and localized names

Severity: `major`

The new AI projector itself has no raw payload read, but it has no production
consumer. Existing AI still reads dedicated fields at
`scripts/runtime/ai_runtime_controller.gd:3909` through line 3916 and many other
locations; the audited baseline is 225 value reads across 33 functions. It also
uses the localized fallback `相位否决` at lines 6854-6855.

Keep this as an explicit compatibility allowlist and ratchet it downward. Do
not claim AI cutover until the authorized observation/candidate path replaces
these reads without changing scores, ordering, privacy, or RNG.

### CSAR-M08: Production UI still uses raw skill data and alias chains

Severity: `major`

The new PlayerFace DTO emits no aliases, but no production UI consumes it.
`scripts/ui/hand_rack.gd:137` still falls through
`cost -> price -> play_cost`, while `scripts/runtime/card_presentation_runtime_service.gd:44`
and lines 54-56 still derive text/rank/price from legacy fields.

Keep these consumers on the documented compatibility bridge until a single
DTO adapter is ready, then cut them over atomically and delete the aliases.

### CSAR-M09: RulesProjection and execution parity are not implemented

Severity: `major`

The integration intentionally proves zero executor connections at
`tests/card_semantic_phase1_integration_test.gd:63`. It proves the same semantic
spec reaches AI and PlayerFace, but there is no `RuleExecutionPlan`, operation
handler registry, or semantic-to-existing-executor parity test.

This does not contradict the narrow Phase 1 claim. It remains a mandatory later
boundary before describing the architecture as a complete three-projection
system or sharing execution with AI training.

### CSAR-M10: Random operations have no explicit randomness policy

Severity: `major`

`scripts/cards/semantic/card_semantic_schema_v1.gd:58` defines random discard,
steal, and lock operations without a randomness policy, RNG owner/stream, or
draw-order contract. They remain projection-only, so current compile/projection
RNG delta is correctly zero.

Add approved randomness-policy references and existing-owner draw parity before
any random operation can become active. Do not make the projector roll outcomes.

## Minor Findings

### CSAR-m01: Integration evidence contains hard-coded boundary conclusions

Severity: `minor`

`scripts/tools/card_semantic_phase1_integration_bench.gd:289` and line 290 write
the arbitrary-lookup and cache-enumeration conclusions as constants. The test at
`tests/card_semantic_phase1_integration_test.gd:64` therefore verifies the Bench
literal, not the production behavior. Replace these with adversarial calls and
metric assertions.

### CSAR-m02: Performance gates are absolute, not comparative

Severity: `minor`

The focused performance tests are bounded and green, but they do not compare
against the pre-Phase-1 startup or projection baseline. The reviewed run spent
281.339 ms compiling the 348-card catalog, 276.093 ms projecting 400 AI cases,
and 1.440 s projecting 600 PlayerFace cases. Add a stable startup/projection
baseline before these services become hot-path consumers; do not raise the
60-second cap.

## No Findings

- No second Card semantic state owner was introduced. The semantic cache is
  derived, detached, disposable, and owns no card instance or world state.
- No AI scalar score, personality weight, or localized rule text is stored in a
  compiled semantic spec.
- New PlayerFace code does not parse localized prose or color to choose rules.
- New AI code does not read `effect_payload` or `skill`; raw access is confined
  to the compiler input and unchanged legacy consumers.
- The direct readiness gate rejects genuine compiler-produced
  `projection_only` and `not_acquirable` specs. The blocker is provenance of the
  readiness claim, not the comparison itself.
- New production services contain no RNG, Save, Main, current-scene, timer,
  `_process`, or `_physics_process` dependency.
- AI candidate projection does not invoke the compiler; repeated projection
  leaves compiler cache metrics unchanged.
- No production branch on a specific card name or family was added, and no new
  legacy alias chain was introduced.
- Composition commit `ebdd305` adds no signal connection or gameplay executor
  dependency.

## Independent Verification

| Gate | Result | Evidence |
| --- | --- | --- |
| Phase 1 integration | PASS | 27 checks, 1.816 s suite, 7.129 s wrapper |
| Schema/compiler | PASS | 5290 checks, 1.373 s suite, 281.339 ms compile |
| AI projection | PASS | 211 checks, 400 projections in 276.093 ms |
| PlayerFace projection | PASS | 57 checks, 600 projections in 1.440 s |
| Source catalog SHA vs all golden fixtures | PASS | all four values equal `b59b7348...0fcb40` |
| Godot process cleanup | PASS | wrapper reported zero remaining scoped processes |

The first integration invocation failed only because the isolated worktree had
no Godot global script-class cache. A bounded `-EnsureImported` bootstrap built
the cache, after which the same test passed with zero script errors. This is an
entrypoint/import precondition, not a product finding.

## Required Disposition

Fix `CSAR-B01` and `CSAR-B02`, add their adversarial regression tests, and rerun
the four focused gates before merging Phase 1. The major findings may remain
only as explicit, non-executable compatibility bridges with owners and deletion
milestones; none may be used to claim AI, UI, rules, save/replay, or training
cutover.
