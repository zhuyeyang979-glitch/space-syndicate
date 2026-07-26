# Authorized Semantic Envelope And Instance Decision State Validation

## Scope

- Task: `AUTHORIZED_SEMANTIC_ENVELOPE_AND_CARD_INSTANCE_DECISION_STATE`
- Integration baseline: `origin/main@6bb2842791bdd1592f17c308111caffab93c087b`
- Mode: passive projection only; no production AI, UI, Codex, rules, or handler cutover
- Supported source: `own_hand`
- Fail-closed sources: `public_rack`, `public_reveal`, `response_window`, arbitrary card ID, catalog enumeration, rival hand, and human hand

## Authority Graph

```text
WorldSessionState.players[*].slots
  -> GameRuntimeCoordinator actor-scoped source token
  -> AiActorHandInventoryQueryPort
       -> actor_hand_slot_attestation()
       -> is_current_slot_attestation()
  -> CardSemanticSourceAuthorizationPort
       -> AuthorizedCardSemanticEnvelopeV1
       -> CardInstanceDecisionStateV1
       -> bounded fingerprint-only replay journal
  -> CardSemanticCatalogService
       -> catalog-owned CardSemanticSpec copy
  -> AiCardSemanticProjectionService.project_authorized_source()
       -> passive AiActionCandidate
```

There is one scene-composed source authorization Port and no second hand, card-instance, cooldown, Save, RNG, or semantic catalog owner. `GameRuntimeCoordinator` binds the existing root `AiActorHandInventoryCapability` once for the legacy multi-AI query Port. Because that root intentionally remains broad for the unchanged production AI path, the Coordinator also one-shot registers and seals actor-scoped opaque tokens of the same capability type for semantic source authorization. The source Port accepts only the exact token registered for the requested actor and uses the root token internally. Root, forged, foreign-composition, cross-actor, and post-seal rebind attempts fail closed. Tokens never enter wire data, debug snapshots, or Save. The new Port retains no hand or card body.

## Authorized Envelope V1

`AuthorizedCardSemanticEnvelopeV1` is exact-key, closed pure data with these fields:

```text
schema_version
envelope_id
request_id
source_kind
source_owner_id
attestation_port_id
visibility_scope_id
viewer_ref { schema_version, actor_ref_id, actor_index }
session_id
session_revision
hand_source_revision
hand_source_fingerprint
card_id
source_slot
runtime_instance_id
static_record_fingerprint
source_definition_fingerprint
semantic_fingerprint
instance_revision
instance_state_fingerprint
authorization_receipt_ref
envelope_fingerprint
```

Frozen authority constants are `source_kind=own_hand`, `source_owner_id=world_session_state.actor_hand`, `attestation_port_id=ai_actor_hand_inventory_query_port`, and `visibility_scope_id=actor_private`. The caller cannot supply an accepted flag, owner attestation, readiness, semantic body, or visibility entitlement.

The authorization receipt is also exact-key, closed data:

```text
schema_version
receipt_id
request_id
accepted
reason_id
envelope_ref
source_attestation_fingerprint
static_record_fingerprint
source_definition_fingerprint
semantic_fingerprint
instance_revision
instance_state_fingerprint
receipt_fingerprint
```

The result bundle is exact-key data containing only `schema_version`, `accepted`, `reason_id`, `authorized_envelope_ref`, `semantic_spec`, `instance_decision_state`, `authorization_receipt`, and `bundle_fingerprint`.

## Card Instance Decision State V1

`CardInstanceDecisionStateV1` contains exactly:

```text
schema_version
instance_id
card_id
source_kind
visibility_scope_id
viewer_ref { schema_version, actor_ref_id, actor_index }
session_id
session_revision
source_revision
source_slot
instance_revision
queued
locked
cooldown_remaining_microseconds
state_fingerprint
```

Mappings are authoritative: `instance_id <- runtime_instance_id`, `card_id <- slot/card machine identity`, `source_slot <- slot_index`, `queued <- queued_for_resolution`, `locked <- lock_left > 0`, and cooldown uses a nonnegative integer microsecond wire field. The state contains no card record or machine/player/developer block, effect payload, skill, legal target, target recommendation, world fact, rival fact, AI score/value/plan, RNG state, Save payload, or UI/presentation state.

`instance_revision` and `state_fingerprint` are deterministic hashes. They are not mutable ownership counters and are not persisted. The compatibility adapter `CardInstanceDecisionStateV1.to_ai_projection_input()` converts the integer microseconds back to the existing passive AI input's seconds field without changing old field semantics. No Card-v1-to-shared-kernel reference adapter was required.

## Staleness And Replay

The hand source revision binds session identity/revision, actor, slot records, inventory policy facts, and the existing query Port's monotonic source generation. That generation advances on authoritative player replacement, world restore, session configure/start/plan/rollback/pause/resume/finish/save-apply/load/reset, dependency rebinding, and the existing `CardCooldownRuntimeController`'s narrow `card_instance_decision_state_changed` signal. This prevents an old attestation from reviving after slot A-to-B-to-A, slot move A-to-B-to-A, cooldown/lock A-to-B-to-A, identical session restart, pause/resume, or restore. The cooldown owner compares exact stored values for revision invalidation, so a sub-tolerance `0 -> 1e-7 -> 0` ABA also leaves both the intermediate and original bundles stale. The narrow cooldown signal does not advance `AiActorStatePort` generation or rebase production AI memory.

The authorization Port re-queries the authoritative slot before returning and again before passive projection. The active validation journal retains at most `128` bundle fingerprints. A separate fail-closed request-binding registry retains only request and binding fingerprints up to `4096`; it never evicts a binding or permits that request identity to bind different content. Once the registry reaches its fixed limit, new request identities fail closed. Active-journal eviction makes an identical replay return `request_not_journaled`, while a different slot or instance using the retired request identity returns `request_id_collision`. Neither structure stores actor-private card bodies.

## Security And Privacy

Focused adversarial coverage rejects null/forged/cross-instance capability, cross-actor and human actor requests, eliminated actors, stopped or stale sessions, invalid/empty/replaced/moved slots, empty or malformed runtime instance IDs, nonfinite or negative timing values, non-pure card records, external or mutated catalog records, re-signed semantic readiness changes, arbitrary IDs, unsupported source kinds, malformed/re-signed bundles, replay collisions, post-eviction request rebinding, and stale source generations.

Closed-data validation rejects `Node`, `Object`, `Resource`, `Callable`, script paths, method names, owner or hidden-owner channels, rival/opponent hands, exact cash, private or route plans, future bags, RNG state, Save payload, AI score/value, and raw card blocks. Public debug snapshots contain only counters, booleans, and fingerprints.

## Performance And Determinism

Latest final-worktree benchmark evidence compared with the prior committed checkpoint:

| Work | Iterations | Prior checkpoint | Final worktree |
| --- | ---: | ---: | ---: |
| Direct compatibility projection | 400 | 287.189 ms | 416.312 ms |
| Authorized projection with current-source revalidation | 400 | 1816.118 ms | 2160.046 ms |
| Authorized bundle construction | 400 | 2710.478 ms | 2711.000 ms |

The final MCP authorized/direct ratio was `5.189x`, below the unchanged explicit `10x` order-of-magnitude guard; the final headless run measured `7.613x`. This is a bounded no-order-of-magnitude-regression result, not performance parity. One development run under scheduler contention measured `10.346x`; no timeout or threshold was raised. Each authorized projection performs one current hand attestation and one catalog-owned spec authorization. Each bundle build performs its initial attestation plus current revalidation. The benchmark asserts explicit query/copy counters, deterministic candidates, a bounded active journal and fail-closed binding registry, zero catalog reload, and zero candidate-loop compilation. Actor-state and inventory-policy counters are documented proxies/lower bounds rather than independent owner counters.

- Semantic compile delta: `0`
- RNG checkpoint delta: `0`
- Unauthorized rejection cache delta: `0`
- Save Registry sections: `19`
- Semantic Save sections: `0`
- Main responsibility delta: `0` methods/wrappers; two existing legacy nested slot writes now commit through `WorldSessionState.replace_players`
- Production AI/UI/executor consumers: `0`
- AI raw-read ratchet: `225` value reads, `5` presence checks, `33` functions, `71` keys; unchanged

## Focused Gates

| Gate | Result | Godot process time |
| --- | --- | ---: |
| `card_instance_decision_state_test.gd` | PASS | 0.575 s |
| `ai_actor_hand_inventory_typed_port_migration_test.gd` | PASS, 93 checks | 5.470 s |
| `card_cooldown_runtime_controller_cutover_test.gd` | PASS, 23 checks | 6.942 s |
| `card_semantic_source_authorization_test.gd` | PASS, 187 checks | 7.434 s |
| `CardSemanticSourceAuthorizationBench.tscn` | PASS, 39 checks | 10.992 s |
| `card_semantic_authorized_projection_integration_test.gd` | PASS, 14 checks | 10.319 s |
| `game_session_save_characterization_test.gd` | PASS | 6.055 s |
| `card_semantic_architecture_scan_test.gd` | PASS, 142 checks | 4.351 s |
| `main_runtime_composition_test.gd` | PASS | 9.956 s |
| `run_rng_service_cutover_test.gd` | PASS | 6.062 s |
| `v06_save_owner_registry_test.gd` | PASS | 5.976 s |
| `ai_card_semantic_projection_test.gd` | PASS | 3.058 s |
| `card_semantic_phase1_integration_test.gd` | PASS | 7.454 s |
| `card_semantic_schema_compiler_test.gd` | PASS | 2.248 s |
| `semantic_kernel_v1_test.gd` | PASS | 0.577 s |

Every listed test used the bounded project wrapper with a 60-second limit or less. No long smoke or FullRun was used.

## Godot MCP

Funplay Godot MCP `0.9.6` on the worktree-local authenticated endpoint `8995` completed final acceptance under Godot `4.7-stable`:

- opened and inspected `CardSemanticSourceAuthorizationPort.tscn`;
- opened the real `GameRuntimeCoordinator.tscn` (`162` nodes) and found exactly one Catalog, Hand Port, Source Authorization Port, and passive Projection service;
- validated `400` GDScript files through MCP `get_script_errors` with `error_count=0`;
- ran `CardSemanticSourceAuthorizationBench.tscn` and queried live runtime state: `PASS 39/39`, direct `416.312 ms`, authorized `2160.046 ms`, ratio `5.189x`, bundle build `2711.000 ms`, `402/4096` request bindings, compile delta `0`, RNG unchanged, and no raw debug leak;
- queried the task-filtered MCP error console while the Bench was live and found `0` lines; the unfiltered isolated editor log retained `5` shader-cache-directory errors and `4` Unicode NUL log-reader messages, but no task script, runtime, or Bench error;
- stopped the scene normally and confirmed `is_playing_scene=false`;
- stopped the editor normally, leaving zero Godot processes and zero listening endpoint;
- removed the `19` unrelated untracked `.uid` files generated by editor import.

After play-mode stop, the isolated long-path user directory logged known engine shader-cache directory failures and Unicode NUL log-reader messages. They appeared only after the clean runtime query, contain no task script path or GDScript diagnostic, and are not a product/Bench failure.

## Cutover Flags

```text
STATUS=AUTHORIZED_SEMANTIC_ENVELOPE_AND_CARD_INSTANCE_DECISION_STATE_GREEN
PASSIVE_PROJECTIONS_ONLY=true
PRODUCTION_AI_SEMANTIC_CUTOVER=false
PRODUCTION_UI_SEMANTIC_CUTOVER=false
RULES_PROJECTION_CUTOVER=false
FULL_GAME_SEMANTIC_CUTOVER=false
```

`OperationHandlerRegistry` remains metadata-only: real handler registration, active-handler readiness, RulesProjection capability, handler identities, Callables, method names, and owner Nodes are absent from wire data.

## Follow-up

The next atomic task is `CODEX_FIRST_PLAYERFACE_CUTOVER`. It is intentionally not implemented here.
