# Semantic Kernel v1 Contract

Status: `ARCHITECTURE_WAVE_1_FROZEN`

Contract version: `1`

Integration baseline: `39ec00854d7f0439aab6f053948e5a58088ba2d5`

Upstream baseline: `59756a291f811a064726f59aed27efecc3590c9a`

Machine-readable companion:
`docs/architecture/semantic_kernel_v1_contract.json`

This contract defines the first shared boundary for executable semantics across
Space Syndicate. It is architecture only. It does not change a catalog, rule,
balance value, RNG sequence, save envelope, runtime owner, or production route.

## 1. Decision

Every authored gameplay definition is compiled once into one immutable,
domain-specific semantic specification. That specification has three
projections:

```text
authoritative domain catalog
    -> domain SemanticCompiler
    -> immutable domain SemanticSpec
        -> RulesProjection  -> RuleExecutionPlan -> existing domain owners
        -> PlayerProjection -> PlayerPresentationDTO
        -> AiProjection     -> AiActionCandidate
```

The shared kernel supplies identity, condition, target, operation, visibility,
randomness, validation, registration, references, and projection envelopes. It
does not replace domain schemas with a generic payload bag.

The following specifications remain separate:

- `CardSemanticSpec`
- `RoleSemanticSpec`
- `MonsterSemanticSpec`
- `MonsterBehaviorSpec`
- `MilitaryUnitSemanticSpec`
- `WeatherSemanticSpec`
- `ProductSemanticSpec`
- `FacilitySemanticSpec`
- `VictorySemanticSpec`

The same stable `operation_id` and the same registered domain handler bundle
drive all three projections. Production execution and AI training use the same
`RuleExecutionPlan`, registry, transaction coordinator, and domain handlers.
An AI outcome projection is an estimate and is never an alternate executor.

## 2. Non-Negotiable Invariants

1. Localized names, text, art, colors, tooltips, and filename suffixes never
   select a rule, target, handler, rank, or AI behavior.
2. Static semantic definitions are immutable and never contain instance state,
   mutable ownership, current legality, AI scores, or UI state.
3. Dynamic state remains in the existing authoritative domain owner.
4. Each active `operation_id + operation_version` has exactly one registered
   domain handler bundle.
5. Unknown condition, target, operation, policy, projection schema, or handler
   ID fails closed.
6. A `projection_only` or `not_acquirable` definition cannot produce
   `legal=true` or an executable plan.
7. Compilation occurs during catalog configuration or explicit tooling only.
   Runtime ticks, rendering, candidate enumeration, and candidate scoring never
   compile.
8. The authorized viewer boundary clips source data before Player or AI
   projection. A projector cannot recover data that was clipped.
9. Random behavior names its `SemanticRandomnessPolicy`; no semantic record
   contains an RNG callback, seed override, or hidden global draw.
10. Execution preserves the current domain transaction, exact-once journal,
    rollback, commit, public receipt, and RNG order.
11. The registry is a sealed dispatch table, not a state owner, catalog owner,
    save owner, or general service locator.
12. There is no scalar `ai_value` in authored content or semantic output.
13. There is no second catalog, second world state, second card state owner, or
    simplified training rules engine.
14. No shared semantic service depends on `Main`, current scene lookup,
    autoload discovery, method-name strings, or `Callable` values in wire data.
15. Canonical output contains pure JSON data only and returns detached copies.
16. Retired or rule-unestablished mechanics cannot compile as active, register
    a production handler, produce a legal candidate, or enter a plan.

## 3. Authority And Ownership

The authority order remains the existing ruleset order: accepted rulebook and
runtime directive, authoritative domain catalogs, domain owners, then
presentation and AI projections. Tests and compatibility code do not establish
new product rules.

| Concern | Sole authority after cutover | Kernel responsibility |
| --- | --- | --- |
| Authored definitions | One catalog per domain | Validate and compile a detached snapshot |
| Card instances and custody | Existing inventory, queue, and card owners | Stable references only |
| Players and world state | Existing session and domain owners | No storage |
| Legality | Existing typed legality/authorization owner | Consume a proof, never infer it |
| Mutation | Existing domain transaction owner | Resolve a registered handler and preserve order |
| RNG | `RunRngService` and existing domain draw order | Declare and validate a policy |
| Localization and art | Presentation/localization catalogs | Emit stable message, keyword, icon, and color token IDs |
| AI strategy | Existing AI policy/personality owner | Emit neutral candidate features, never a score |
| Persistence | Existing 19-section Save Registry and envelope | Resolve stable refs; add no section |
| Replay | Existing transaction journals and future replay bridge | Validate semantic and registry fingerprints |

`SemanticCompiler` owns no authored record. Its cache is derived, immutable,
disposable, and rebuildable. `OperationHandlerRegistry` owns no handler state;
it stores composition-time references to existing typed handler ports and
publishes only detached descriptors.

Every active operation descriptor cites one or more accepted `mechanic_id`
values and exact rule-source references. The current
`card_semantic_projection_v1_migration` record authorizes only its documented
card migration surface. It does not authorize new Role, Monster, Weather, or
other domain behavior. Missing authority is
`RULE_AUTHORITY_NOT_ESTABLISHED` and blocks activation.

## 4. Closed Wire Profile

All v1 boundary values follow one profile:

- JSON-compatible `Dictionary`, `Array`, `String`, `bool`, and safe integer
  values only.
- Every object is closed. An unlisted key is an error.
- Optional keys are omitted; `null` is forbidden.
- Stable IDs match `^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$`, are ASCII,
  case-sensitive, and at most 160 characters.
- Fingerprints are lowercase SHA-256 over canonical UTF-8 JSON. Dictionary
  keys are sorted lexicographically and array order is preserved. A fingerprint
  field is omitted from its own input.
- `Node`, `Object`, `Resource`, `PackedScene`, `Callable`, signals, vectors,
  colors, executable expressions, script paths, and method names are forbidden.
- Units are explicit in field names or stable `unit_id` values. Floating-point
  gameplay values require an existing deterministic fixed-point contract before
  entering the kernel.
- Error codes are stable IDs. Localized error prose is produced later by the
  Player projection.

The machine-readable companion is the key and lifecycle oracle for this Wave 1
contract. Domain PRs add closed tagged parameter schemas; they do not widen
`parameters` into an arbitrary extension bag.

## 5. Shared Value Types

### 5.1 SemanticIdentity

`SemanticIdentity` identifies one immutable authored definition. It contains:

- `schema_version=1`
- `domain_id`
- `definition_id`
- `definition_revision`
- `ruleset_id`
- `source_catalog_id`
- `source_definition_fingerprint`
- `identity_fingerprint`

Domain values for `domain_id` are `card`, `role`, `monster`,
`monster_behavior`, `military_unit`, `weather`, `product`, `facility`, and
`victory`. Rank, family, stats, costs, triggers, and display names remain in the
corresponding domain specification. An identity never carries a live instance,
owner, controller, viewer, or localized label.

`SemanticDefinitionRef` is the detached reference used by plans and
projections. It contains `schema_version=1`, `domain_id`, `definition_id`,
`definition_revision`, `semantic_schema_version`, and
`semantic_fingerprint`.

### 5.2 SemanticCondition

`SemanticCondition` is a closed tagged condition declaration:

- `schema_version=1`
- `condition_binding_id`, unique inside one definition
- `condition_id`
- `condition_version`
- `subject_binding_id`
- `parameter_schema_id`
- `parameters`, validated by the exact tagged schema

There is no generic expression language. Boolean combinations that are real
domain rules receive their own stable `condition_id` and schema. The registered
operation handler descriptor lists every supported condition ID. A condition
is re-evaluated by the authoritative legality or domain owner at the revision
declared in the execution plan.

### 5.3 SemanticTargetSpec

`SemanticTargetSpec` declares target shape, not a selected target:

- `schema_version=1`
- `target_binding_id`, unique inside one definition
- `target_id`
- `target_version`
- `selection_mode_id`
- `minimum_count`
- `maximum_count`
- ordered `allowed_entity_type_ids`
- ordered `filter_condition_binding_ids`
- `revalidation_policy_id`
- `target_visibility_policy_id`

It contains no live target, player label, lookup callback, or hidden owner.
Selected targets exist only in an authorized legality receipt and
`RuleExecutionPlan`.

### 5.4 SemanticOperation

`SemanticOperation` is the sole rule dispatch identity:

- `schema_version=1`
- `operation_instance_id`, unique inside one definition
- `operation_id`
- `operation_version`
- `domain_id`
- ordered `target_binding_ids`
- ordered `condition_binding_ids`
- `parameter_schema_id`
- `parameters`, validated by the operation's exact tagged schema
- `randomness_policy_id`
- `result_visibility_policy_id`
- `atomic_group_id`
- `sequence_index`

Array order and `sequence_index` must agree. The record contains no handler,
owner object, method name, localized text, AI weight, or mutation callback.
An operation's meaning cannot change in place. A breaking semantic change uses
a new `operation_version` or a new `operation_id`.

### 5.5 SemanticVisibilityPolicy

`SemanticVisibilityPolicy` contains:

- `schema_version=1`
- `visibility_policy_id`
- `definition_visibility_id`
- `source_identity_visibility_id`
- `actor_visibility_id`
- `target_choice_visibility_id`
- `outcome_visibility_id`
- `private_value_visibility_id`
- `ai_analysis_visibility_id`
- `redaction_policy_id`

It declares policy but grants no authority. It never contains a viewer, actor
index, hand, hidden card, capability token, or current private value.

### 5.6 SemanticRandomnessPolicy

`SemanticRandomnessPolicy` contains:

- `schema_version=1`
- `randomness_policy_id`
- `mode_id`
- `rng_owner_id`
- `stream_id`
- `draw_schedule_id`
- `draw_count_policy_id`
- `selection_order_id`
- `commit_policy_id`
- `failure_consumption_policy_id`
- `rollback_policy_id`
- `replay_policy_id`
- `result_visibility_policy_id`

`none` is an explicit policy. Other policies are registered only after a parity
test proves the existing `RunRngService` owner, stream, draw count, ordering,
failure behavior, rollback, and visibility. Policies never contain a seed,
sample, callback, or instruction to call a global random function.

## 6. Domain Specifications Stay Separate

Every domain specification embeds or references the shared value types, then
adds one closed domain body. There is no generic `domain_payload` escape hatch.

Every compiled domain spec has this common closed envelope:

- a domain-specific `schema_id` and integer `schema_version`;
- `identity: SemanticIdentity`;
- ordered `conditions: Array[SemanticCondition]`;
- ordered `targets: Array[SemanticTargetSpec]`;
- ordered `operations: Array[SemanticOperation]`;
- closed `visibility_policies` and `randomness_policies` referenced by ID;
- sorted accepted `mechanic_ids`;
- `execution_readiness_id`: `active`, `projection_only`, or `unavailable`;
- `semantic_fingerprint`.

Arrays may be empty when a domain has no such concept. An `active` spec must
have complete handler, mechanic, rule-source, transaction, privacy, and RNG
coverage. The current card-only `not_acquirable` readiness maps explicitly to
shared `unavailable`; it is not inferred from purchase cost or UI visibility.
The closed domain body is named in that domain's schema rather than stored in a
generic payload field.

| Domain spec | Domain-only authority | Existing dynamic owner remains |
| --- | --- | --- |
| `CardSemanticSpec` | identity, acquisition and activation costs, timing, targets, ordered effects, response | CardInventory, queue, resolution, and effect owners |
| `RoleSemanticSpec` | stable role identity, public role profile, passive trigger references | Player/session role assignment and passive runtime owners |
| `MonsterSemanticSpec` | family, rank, immutable stats, behavior refs, deploy/upgrade capabilities | Monster runtime controller |
| `MonsterBehaviorSpec` | trigger, target, condition, ordered behavior operations | Monster runtime state machine |
| `MilitaryUnitSemanticSpec` | family, rank, immutable stats, move/guard/strike capabilities | Military runtime controller |
| `WeatherSemanticSpec` | weather identity, zone/timing declarations, ordered effects | Weather runtime controller and state |
| `ProductSemanticSpec` | stable product identity, public tags, market units | Product market and commodity owners |
| `FacilitySemanticSpec` | facility kind, rank profile, capacities, lifecycle capabilities | Region infrastructure owner |
| `VictorySemanticSpec` | objective identities, conditions, progress and resolution declarations | Victory control owner |

An immutable spec never receives current HP, controller, ownership, balance,
inventory, cooldown, weather zone state, victory progress, or AI memory.

## 7. Shared Protocols

The signatures below are target API shapes for later small implementation PRs.
They are protocols, not new production code in this commit.

### 7.1 SemanticCompiler

```gdscript
class_name SemanticCompiler
extends RefCounted

func compiler_descriptor() -> Dictionary
func validate_source_catalog(source_snapshot: Dictionary) -> Dictionary
func compile_catalog(source_snapshot: Dictionary) -> Dictionary
func compile_authorized_definition(source_envelope: Dictionary) -> Dictionary
func validation_snapshot() -> Dictionary
func cache_metrics() -> Dictionary
```

Rules:

- One domain compiler consumes only that domain's authoritative catalog
  snapshot and explicit compatibility tables.
- A compiler may not discover another catalog, world owner, UI, AI, `Main`, or
  current scene.
- `compile_catalog` runs at configuration time and returns a complete detached
  catalog result or one failed report. It never partially publishes.
- `compile_authorized_definition` exists for current authorized-source bridges.
  It cannot enumerate the cache or accept an arbitrary ID as authorization.
- A compiler has no `_process`, timer, RNG call, save registration, or mutation
  API.

### 7.2 SemanticValidationReport

`SemanticValidationReport` contains:

- `schema_version=1`
- `report_id`
- `phase_id`
- `valid`
- the source manifest fingerprint
- the semantic catalog fingerprint after compilation
- the registry fingerprint after registry sealing
- sorted `issues`
- one closed `domain_summary` per participating domain
- sorted unknown condition, target, operation, randomness, and visibility IDs
- sorted unknown mechanic IDs and retired-identifier hits
- sorted active and projection-only operation IDs
- `report_fingerprint`

The semantic and registry fingerprints are omitted in earlier phases that have
not produced them. A later-phase report must contain all predecessor
fingerprints. Any blocker or error sets `valid=false`. Warning-only reports may
be valid but cannot silently widen runtime readiness. Reports contain stable
codes and paths, not localized rules text.

### 7.3 OperationHandlerRegistry

```gdscript
class_name OperationHandlerRegistry
extends Node

func register_handler(handler: SemanticOperationHandlerPort) -> Dictionary
func seal(compiled_manifests: Array[Dictionary]) -> Dictionary
func validation_snapshot() -> Dictionary
func descriptor_for(operation_id: String, operation_version: int) -> Dictionary
func build_rule_plan(request: Dictionary) -> Dictionary
func build_player_projection(request: Dictionary) -> Dictionary
func build_ai_projection(request: Dictionary) -> Dictionary
```

Registration occurs through explicit scene composition under
`GameRuntimeCoordinator`, never through an autoload or `Main`. The registry is
mutable only before `seal()`. After sealing, registration, replacement, and
duplicate IDs fail closed.

Each detached handler descriptor names the operation ID and version, domain,
logical handler owner, accepted mechanic IDs and rule-source refs, exact tagged
parameter schema, supported condition/target/randomness/transaction IDs,
supported plan versions, and preflight/checkpoint/apply/rollback plus
Rules/Player/AI projection capabilities.

One `SemanticOperationHandlerPort` bundle supplies the common meaning for an
operation:

```gdscript
func handler_descriptor() -> Dictionary
func validate_operation(operation: Dictionary) -> Dictionary
func project_rule(operation: Dictionary, authorized_context: Dictionary) -> Dictionary
func project_player(operation: Dictionary, clipped_context: Dictionary) -> Dictionary
func project_ai(operation: Dictionary, observation_slice: Dictionary) -> Dictionary
func preflight(plan_step: Dictionary, transaction_context: Dictionary) -> Dictionary
func capture_checkpoint(plan_step: Dictionary, transaction_context: Dictionary) -> Dictionary
func apply(plan_step: Dictionary, transaction_context: Dictionary) -> Dictionary
func rollback(plan_step: Dictionary, checkpoint: Dictionary, transaction_context: Dictionary) -> Dictionary
```

The port is a stateless adapter owned by, or narrowly delegating to, the
existing authoritative domain owner. It is not a second rules engine. Runtime
references remain private inside composition; descriptors and snapshots are
detached pure data.

`descriptor_for` is available only to the rule/projection services composed
inside the runtime. AI and UI receive no registry enumeration or arbitrary
semantic lookup API.

## 8. RuleExecutionPlan

`RuleExecutionPlan` is immutable, pure data built after authorization and
legality validation. It contains:

- `schema_version=1`
- `plan_id` and `request_id`
- `ruleset_id`
- `semantic_ref`
- `actor_ref` and `source_instance_ref`
- `source_revision` and `world_revision`
- `legality_proof_ref`
- `registry_fingerprint`
- ordered resolved target bindings
- ordered condition proof refs
- ordered rule execution steps
- `transaction_policy_id`
- `rng_precondition_revision`
- `visibility_policy_id`
- `plan_fingerprint`

Each rule execution step contains its stable operation identity, detached
validated parameters, resolved binding refs, randomness policy ID, sequence,
and atomic group. It contains no `Node`, owner, handler pointer, callback, or
method name.

Plan construction is deterministic and consumes no RNG. The plan does not
claim that a target is still legal at apply time; each declared revalidation
policy is checked by the authoritative owner.

### 8.1 Domain transaction integration

The existing action transaction coordinator remains the execution engine. For
plans spanning one or more owners it performs:

1. Validate request identity, revisions, semantic fingerprint, registry
   fingerprint, and exact-once key.
2. Resolve every operation to exactly one sealed handler.
3. Preflight every step and cross-owner reference before mutation.
4. Capture every required owner checkpoint before the first apply.
5. Apply steps in plan order and preserve each owner's established domain
   ordering and RNG calls.
6. On failure, roll back successful applies in strict reverse order, including
   the RNG checkpoint when the policy requires it.
7. Commit existing lifecycle and transaction journals only after all business
   owners succeed.
8. Publish public receipts, signals, logs, presentation refresh, and sounds only
   after commit.

The registry resolves handlers; it does not coordinate or retain a transaction.
Domain checkpoints are transient, never semantic definitions or save sections.

## 9. PlayerProjection

`PlayerPresentationDTO` is the only semantic input available to new UI code. It
contains:

- `schema_version=1`
- `presentation_id`
- `domain_id`
- `semantic_ref`
- `surface_id`, `locale_id`, and `viewer_scope_id`
- stable title and subtitle message tokens
- ordered, explicitly typed cost rows
- ordered presentation sections
- ordered keyword tokens
- stable art, icon, and color token IDs
- `visibility_receipt_ref`
- `dto_fingerprint`

Presentation sections use stable IDs such as `timing`, `target`, `condition`,
`effect`, `duration`, `response`, and `information`. Text is represented by a
stable message ID plus typed arguments. Localization may resolve those tokens
to text, but text never flows back into rules, legality, or AI.

Domain-specific DTOs such as `PlayerCardFaceDTO`, `PlayerRoleCardDTO`, and
`MonsterCodexDTO` wrap or specialize this common envelope with closed schemas.
They do not add aliases such as `cost/price/play_cost`,
`effect/text/description`, or `type/category`.

Current UI compatibility dictionaries may be produced by a temporary adapter
outside the DTO. New UI code may not read that adapter, and every alias has a
named retirement gate.

## 10. AiProjection

### 10.1 AiObservationSnapshot

`AiObservationSnapshot` is built by existing typed query ports after viewer
authorization. It contains:

- `schema_version=1`
- `observation_id`
- `viewer_actor_ref`
- `session_revision` and `world_revision`
- `projection_manifest_fingerprint`
- ordered public observation slices
- ordered actor-private observation slices
- authorized action-source refs
- `visibility_receipt_ref`
- `snapshot_fingerprint`

Each observation slice declares `domain_id`, a registered closed `schema_id`,
schema version, source revision, closed facts, and a fingerprint. There is no
opaque unvalidated fact bag. Unknown slice schemas fail closed. Opponent hands,
private cards, hidden ownership, hidden monster control, rival AI state,
authorization capabilities, and save payloads are forbidden unless an existing
rules owner explicitly exposes a public or inferred fact in a typed slice.

### 10.2 AiActionCandidate

`AiActionCandidate` contains:

- `schema_version=1`
- `candidate_id`, `action_id`, and `action_kind_id`
- `semantic_ref`
- `actor_ref` and authorized `source_instance_ref`
- ordered target identities
- source, world, and legality revisions
- `legal` and stable `rejection_reason_id`
- detached activation/payment requirements
- `AiOutcomeVector`
- bounded `uncertainty`, mirrored authorized `counter_risk`, and
  `information_scope_id=actor_private`
- stable explanation token IDs
- non-executable `plan_preview_fingerprint`
- `candidate_fingerprint`

AI policy receives only observation snapshots and candidates. It cannot read a
raw catalog record, `effect_payload`, `skill`, Player DTO, registry cache, or
arbitrary definition lookup. Candidate generation consumes typed legality
proofs. Projection-only content always returns `legal=false` with a stable
reason.

Candidate explanation tokens describe stable legality or semantic facts only.
They never contain private AI scoring rationale, learned weights, policy
features, or hidden chain-of-thought.

### 10.3 AiOutcomeVector

`AiOutcomeVector` contains exactly these dimensions:

- `self_economy`
- `opponent_economy`
- `board_control`
- `route_control`
- `hand_advantage`
- `tempo`
- `defense`
- `information`
- `victory_progress`
- `variance`
- `counter_risk`

Each dimension is a bounded signed integer neutral-evidence value, matching the
current `AiOutcomeVectorV1` compatibility shape. It is not utility, a policy
weight, a probability, or an authoritative receipt. `counter_risk` is copied
only from an authorized bounded fact; candidate `uncertainty` remains a
separate bounded field. The AI personality and strategy owner combines these
features at decision time. Hidden random outcomes are represented by
uncertainty evidence, never sampled during projection. A future interval or
unit-bearing shape requires a new AiOutcomeVector schema version.

## 11. Authorized-Viewer Clipping Order

The order is mandatory:

```text
authoritative owner state
    -> existing viewer authorization capability
    -> domain-specific clipping/query port
    -> closed authorized snapshot
    -> PlayerProjection or AiProjection
    -> UI or AI consumer
```

Forbidden orders include projecting a full private state and redacting later,
letting AI request semantics by card ID, and letting UI receive raw skills then
hide fields. Projection services validate the viewer receipt and source
revision, reject recursively private keys, and return detached data.

Rules execution uses a separate private authorization context. Player and AI
DTOs are never accepted as execution requests.

## 12. Startup, Validation, And Cache Timing

Startup proceeds in this fixed order:

1. Existing authoritative domain catalogs load and validate.
2. Each domain compiler validates and compiles its complete source snapshot in
   deterministic source order.
3. Each compiled domain catalog is held in a private derived cache keyed by
   domain, semantic schema version, compiler version, source catalog ID, source
   revision, ruleset ID, and source fingerprint.
4. Existing domain handler ports register through scene composition.
5. The registry verifies exact handler coverage, tagged parameter schemas,
   conditions, targets, policies, transaction capabilities, and projection
   capabilities for every `active` operation.
6. The registry seals and publishes one registry fingerprint.
7. The runtime exposes readiness only after all required reports are valid.

Any failure leaves semantic readiness false. No partial cache becomes active.
Unknown IDs and duplicate handlers are blockers. `projection_only` definitions
may be inspected and projected but cannot execute or become legal.

Compilation cache misses are legal only during steps 2 and explicit
developer tooling. After readiness, a source fingerprint not found in the
sealed cache is `semantic_cache_miss_after_seal` and fails closed. Candidate
loops, frames, rendering, and training episodes must report zero compile calls.

## 13. Versioning

Every wire type uses an integer schema version and readers accept only exact
supported versions. Closed-object shape or field-meaning changes increment that
type's schema version. An authored value change under unchanged meaning
increments `definition_revision` and changes the source and semantic
fingerprints; it does not invent a schema version.

An operation meaning change uses a new `operation_version` or a new stable
`operation_id`. A handler descriptor cannot claim two behaviorally different
meanings for one key. Compilers declare exact supported source and output
versions. Compatibility migration is an explicit, deterministic adapter with a
source version, target version, and deletion gate; readers never guess, parse a
name, or silently down-convert.

Registry, semantic catalog, plan, DTO, observation, and candidate fingerprints
bind their exact component versions. A save or replay referencing an unsupported
version fails closed unless a registered migration proves the conversion.

## 14. Randomness And RNG Ordering

Semantic compilation, validation, Player projection, AI observation, candidate
projection, and plan construction have RNG delta zero.

Execution obtains RNG only from the existing `RunRngService` capability named
by a validated randomness policy. The plan preserves operation order. A domain
handler preserves its existing draw schedule and target ordering until a
separate parity migration proves an equivalent transactional fork.

For a random operation, startup validation requires:

- an approved `randomness_policy_id`;
- the authoritative RNG owner and stream;
- deterministic candidate ordering before a draw;
- expected draw-count policy;
- failure and rollback behavior;
- replay evidence requirements;
- public/private result visibility.

AI projection never rolls the effect in order to score it. Failed planning
consumes no RNG. Failed execution must follow the existing owner contract: no
live RNG delta through delayed commit or checkpoint restoration. A new policy
cannot silently alter the current draw count or order.

## 15. Persistence And Replay Bridge

This architecture adds no Save Registry section and does not change the v3
save envelope. Static specs and compiler caches are not saved. Existing owners
continue to save dynamic state in their current sections.

Future owner schema revisions may persist a `SemanticDefinitionRef` beside the
existing stable gameplay identity. Load then:

1. validates the save and owner section normally;
2. resolves the stable ID through the sole authoritative domain catalog;
3. compiles or loads the startup cache, never during owner apply;
4. compares schema version and semantic fingerprint;
5. applies an explicit migration table or fails closed.

Replay records use stable request IDs, semantic refs, plan and registry
fingerprints, operation IDs and versions, selected target refs, RNG policy and
draw evidence, and authoritative domain receipts. They do not embed localized
names, semantic spec bodies, handler names, save payloads, or AI analysis.

Production and AI training both submit a `RuleExecutionPlan` to the same
transaction/execution path. Training may run the same owner classes inside an
isolated simulation instance with an authorized state snapshot. It may not use
a simplified rule interpreter. A predictor that returns `AiOutcomeVector` is
not called execution and cannot produce authoritative receipts.

## 16. Compatibility With Current CardSemanticSpec v1

The current Phase 1 card compiler at this baseline is a valid read-only bridge:

- source authority is the v0.6 `machine` block;
- schema version is integer `1`;
- all 348 definitions compile deterministically;
- 256 are `active` projections and 92 are `projection_only`;
- compilation and cache are RNG-free and mutation-free;
- AI authorized-source envelopes do not permit arbitrary catalog enumeration.

This contract does not edit that schema. A later adapter maps it as follows:

| Current CardSemanticSpec v1 | Shared kernel view | Migration rule |
| --- | --- | --- |
| identity plus source fields | `SemanticIdentity` and card-only identity fields | Preserve IDs, rank, family, and fingerprints exactly |
| target | one `SemanticTargetSpec` | Map only through an explicit versioned table |
| effect_ops | ordered `SemanticOperation` records | Preserve op order and values; add instance IDs and policy refs deterministically |
| information_policy | `SemanticVisibilityPolicy` | Preserve `authorized_source_only`; never widen |
| random op IDs | `SemanticRandomnessPolicy` refs | Use approved current-order bridge policies only after RNG parity |
| runtime_readiness_id | startup and candidate readiness | `projection_only` never becomes executable |
| cost and timing | card domain body | Keep acquisition and activation cost separate |

The current v0.4 catalog remains a production compatibility authority outside
this compiler. That is a known program blocker, not permission to feed v0.4
and v0.6 into the same compiler or declare two sources canonical. A later card
catalog cutover must select one authority, migrate consumers, and then remove
the other production path atomically.

Current localized product values are preserved only inside their existing
source compatibility boundary. `ProductSemanticSpec` requires an approved
ASCII product identity registry; transliteration or name parsing is forbidden.

The current `AiCardSemanticProjectionService` is also a valid read-only
compatibility boundary: it rejects non-active semantics, validates authorized
source and legal-target provenance, emits the eleven-dimension integer vector,
and consumes no RNG. It is not yet consumed by `AiRuntimeController`. Its
`AiOutcomeVectorV1.OP_NEUTRAL_PROJECTIONS` table is an explicit migration
bridge. When the shared registry is adopted, those op-to-outcome entries move
into the corresponding registered handler bundles and the standalone table is
removed; the two tables may not become long-term co-authorities.

The current `CardPlayerFaceProjectionService` and `PlayerFaceDTOv1` form the
card-domain Player projection compatibility boundary. They preserve separate
acquisition and activation costs, stable message/keyword/icon/color IDs,
authorized localization provenance, ordered effect steps, explicit duration
fields, and zero RNG/mutation. They are not yet wired to production UI. During
shared-kernel adoption, `PlayerFaceDTOv1` becomes the closed
`PlayerCardFaceDTO` specialization under `PlayerPresentationDTO`; it is adapted,
not copied into a second card DTO or replaced by a generic open payload.

## 17. Staged Adoption

### Stage 1: Kernel validation shadow

- Add shared pure-data validators, refs, reports, and registry descriptors.
- Adapt current CardSemanticSpec v1 without changing runtime execution.
- Register no operation as executable unless its existing typed route passes
  transaction, privacy, and RNG parity.

### Stage 2: Registry and RulesProjection

- Compose the sealed registry under `GameRuntimeCoordinator`.
- Migrate one existing atomic domain route at a time to RuleExecutionPlan.
- Run old and new planning in parity shadow; only the existing executor mutates.
- Cut over after exact plan, receipt, RNG, and rollback parity.

### Stage 3: PlayerProjection

- Introduce domain DTOs and move kind/color/route/use-case inference into the
  registered semantic projection.
- Keep legacy alias adapters only for named old consumers.
- New UI reads DTOs only; retire adapters consumer by consumer.

### Stage 4: AiProjection

- Build clipped observation slices from existing typed ports.
- Replace each approved raw payload read with candidate fields.
- Keep remaining reads in an explicit allowlist with an owner and deletion
  gate. New raw reads fail scanning tests.

### Stage 5: Domain expansion and legacy retirement

- Add Role, Product, Facility, Monster, MonsterBehavior, MilitaryUnit, Weather,
  and Victory specs in independent reviewable PRs.
- Migrate save/replay identities only with explicit compatibility tables.
- Remove duplicate catalogs, name branches, rank suffix inference, dual runtime
  paths, and alias adapters only after all production consumers are migrated.

## 18. KEEP / MOVE / REMOVE Decisions

### KEEP

- Existing domain state owners, typed command/query ports, transaction
  coordinators, exact-once journals, rollback logic, and public receipt owners.
- `RunRngService` as the only gameplay RNG authority and current draw ordering
  until parity proves a deliberate change.
- The 19-section Save Registry and current envelope shape.
- Current CardSemanticSpec v1 as a deterministic migration bridge.
- Separate acquisition and activation costs.
- Domain-specific state machines for card response, monster behavior, military,
  weather, economy, and victory.

### MOVE

- Stable kind/effect mapping from AI, UI, diagnostics, and controllers into the
  relevant domain compiler and operation descriptor.
- Handler selection from localized names, kind tables, and controller branches
  into `operation_id + operation_version` registration.
- UI rule inference into Player projection and localization tokens.
- AI raw payload interpretation into authorized candidates and outcome vectors.
- The current AI-only op-to-neutral-outcome table into shared registered
  operation handler bundles.
- Diagnostic rule interpretation into SemanticSpec or a standard diagnostic
  projection.
- Random-effect declarations into explicit randomness policies while keeping
  the actual RNG owner and order unchanged.
- Static role passive, monster behavior, military type, product, facility,
  weather, and victory definitions out of controller-local duplicate tables and
  into their single authoritative domain catalogs.

### REMOVE

- Chinese or other localized name branches that select gameplay behavior.
- Direct AI reads of unapproved `skill` or `effect_payload` fields.
- UI reads of raw skill data and UI-maintained rule mappings.
- `cost/price/play_cost`, `effect/text/description`, `type/category`, and similar
  alias chains after their last compatibility consumer is migrated.
- Name-suffix rank inference.
- v0.4/v0.6 dual execution routes after one authoritative card cutover.
- Per-frame, per-render, per-candidate, and per-training-step compilation.
- Unregistered operation fallback and dynamic method-name dispatch.
- Duplicate catalogs, semantic state mirrors, `Main` callbacks, and simplified
  training execution.

## 19. Blockers And Required Evidence

| ID | Blocker | Required resolution before cutover |
| --- | --- | --- |
| `blocker.domain_rule_authority` | Whole-game domains do not yet have a complete operation-to-mechanic-to-rule-source matrix | Accepted mechanic records, field authority, owner, privacy, persistence, and retirement status for every active operation |
| `blocker.card_single_authority` | v0.4 remains a production card authority while v0.6 feeds the semantic compiler | Consumer inventory, one selected authority, atomic route migration, parity, and deletion gate |
| `blocker.product_identity` | Current product IDs include localized authority values | Product owner-approved ASCII identity registry and explicit migration map |
| `blocker.role_persistence_identity` | Role index/name semantics participate in persistence and runtime behavior | Stable role IDs, index parity table, save migration, portrait and passive parity |
| `blocker.monster_behavior_identity` | Name maps and controller-local behavior thresholds are not yet one catalog | Stable family/behavior IDs and owner-approved behavior schemas |
| `blocker.transaction_capability` | Several card routes are still `projection_only` | Preflight, checkpoint, apply, rollback, exact-once, and fault-injection proof for each owner |
| `blocker.rng_policy_inventory` | Random effects lack a complete stable draw-policy inventory | Baseline checkpoints, draw order/count parity, failure rollback, and replay evidence |
| `blocker.viewer_slice_registry` | Whole-game AI and UI facts do not yet share a closed slice manifest | Per-domain typed slice schemas and recursive privacy tests |
| `blocker.replay_contract` | A whole-game semantic replay envelope is not yet established | Owner and format decision that preserves existing journals and save boundary |
| `blocker.ui_alias_consumers` | Legacy presentation aliases still have active consumers | Consumer list, DTO adapter, snapshot parity, and deletion sequence |
| `blocker.training_execution` | Training entrypoints are not yet proven to share every production handler | Bounded parity test using the same plan, registry, owner classes, RNG, and receipts |

No blocker authorizes a fallback. A domain remains compatibility-only or
projection-only until its evidence is green.

## 20. Required Gates For Implementation PRs

Each implementation PR adds focused tests, normally under 60 seconds:

- closed-schema validation and unknown-ID rejection;
- accepted mechanic/rule-source coverage and retired-identifier rejection;
- deterministic compile and fingerprint parity;
- one handler per active operation and sealed-registry immutability;
- no active plan for projection-only content;
- all preflights and checkpoints before apply;
- reverse rollback and exact-once replay;
- zero RNG delta for compile, validation, UI, AI, and planning;
- execution RNG checkpoint and draw-order parity;
- viewer clipping before projection and recursive private-key rejection;
- Rules, Player, and AI projection consistency for the same semantic fixture;
- no catalog load or compile inside candidate loops;
- production and training execution receipt parity;
- no new save section, no Main dependency, and no second owner/catalog/engine;
- scanners for localized-name routing, raw AI/UI payload reads, alias growth,
  dual-path fallback, and unregistered operations.

## 21. First Small Implementation PR

The first code PR after this contract should remain narrow:

1. Add pure-data validators and canonical fingerprint helpers for the six
   shared value types and `SemanticValidationReport`.
2. Add an uncomposed `OperationHandlerRegistry` with registration, duplicate
   rejection, sealing, descriptor snapshots, and no execution cutover.
3. Add a read-only adapter from current CardSemanticSpec v1 to the shared value
   types. Its `SemanticDefinitionRef` retains the existing card semantic
   fingerprint; adapter-owned values receive separate deterministic
   fingerprints. Readiness behavior remains unchanged.
4. Add focused schema, fail-closed, cache-timing, and registry tests plus one
   real Godot MCP Bench scene.
5. Do not add a save section, handler mutation, UI consumer, AI consumer,
   catalog replacement, or Main route in that PR.

That PR establishes an auditable kernel without pretending the whole-game
cutover is complete.
