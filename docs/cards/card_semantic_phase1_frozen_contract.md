# Card Semantic Phase 1 Frozen Contract

Status: `FROZEN_FOR_PHASE_1_IMPLEMENTATION`

Baseline: `59756a291f811a064726f59aed27efecc3590c9a`

Schema version: `1`

Mechanic ID: `card_semantic_projection_v1_migration`

## Authority And Ownership

The active authored input is the `machine` block returned by
`CardRuntimeCatalogV06Resource` from
`res://data/cards/card_runtime_catalog_v06.json`. The compiler may use the
matching `player` block only as an already-authorized localization source for a
PlayerFace projection; it may not parse that text to recover rules.

The v0.4 catalog remains an unrelated compatibility owner and is not an input
to this compiler. Phase 1 does not replace or edit either catalog.

The semantic layer is a deterministic read-only projection. It owns no card
instance, hand, rack, queue, target, legality, execution, resolution, domain
state, AI score, UI state, RNG, save data, or gameplay mutation. Its cache is
derived and disposable.

Rule authority remains:

- card timing and interaction: rulebook sections 7 and 8;
- facility, commodity, supply and demand effects: rulebook sections 5, 7, 8;
- monster and military definitions: rulebook section 9;
- exact numeric values: the active v0.6 machine definition and its established
  domain owner;
- counter response: active `card_counter_response` mechanic;
- conditional global settlement: active
  `conditional_order_auto_settlement` mechanic.

Compilation never makes an unsupported runtime path executable. A recognized
definition can carry `projection_only=true`; AI legality must still come from
the existing typed legality owner.

Privacy is `authorized_source_only`. Persistence is `none`. RNG use is zero.

## Closed Types

Every record is detached pure data and uses `schema_version=1`.

`CardSemanticSpec` contains exactly:

- `schema_version`
- `source_catalog_id`
- `source_definition_fingerprint`
- `semantic_fingerprint`
- `identity: CardIdentitySpec`
- `cost: CardCostSpec`
- `timing: CardTimingSpec`
- `target: CardTargetSpec`
- `effect_ops: Array[CardEffectOp]`
- `response: CardResponseSpec`
- `information_policy: CardInformationPolicy`
- `runtime_readiness_id`

`CardIdentitySpec` contains stable `card_id`, `family_id`, integer `rank`,
`category_id`, optional `industry_id`, and `available_for_acquisition`.

`CardCostSpec` always separates:

- `acquisition`: current authored `acquisition_kind` and integer
  `purchase_cash`;
- `activation`: the seven-key authored integer `asset_cost` vector.

No generic `cost`, `price`, or `play_cost` alias is emitted.

`CardTimingSpec` uses only:

- `main_action`
- `response_window`

`CardTargetSpec.target_id` uses only:

- `facility.same_industry`
- `district.active`
- `unit.same_family`
- `player.opponent`
- `response.incoming_direct_interaction`
- `world.global`
- `organization.self_slot`

It also carries stable selection/cardinality/filter IDs, never a live target or
target lookup callback.

`CardEffectOp.op_id` is a closed enum. Phase 1 catalog compilation may emit:

- `install_rate`
- `build_facility`
- `upgrade_facility`
- `repair_facility`
- `deploy_unit`
- `upgrade_same_family_unit`
- `extend_presence`
- `heal_unit`
- `modify_supply`
- `modify_demand`
- `discard_random`
- `steal_random`
- `lock_random`
- `counter_action`
- `install_organization_upgrade`

The unit fixture contract additionally recognizes these rule-backed capability
IDs without claiming that the current catalog has an executable card route:

- `military_move`
- `military_guard`
- `military_strike`
- `global_order`
- `global_supply_spawn`

Each op has an exact required/allowed parameter table in the GDScript schema.
Unknown op IDs, fields, target IDs, or missing required values fail closed. No
op may contain a `Node`, `Object`, `Resource`, `Callable`, method name, script
path, localized rule text, AI weight, score, or live owner identity.

`CardResponseSpec` uses `none`, `counterable`, or `counter`. Counterable direct
interaction has one existing five-second response layer; a counter does not
open another layer.

`CardInformationPolicy` declares only stable visibility policy IDs. It never
authorizes a viewer and never contains a live actor, target, hand, or owner.

`CardInstanceState` is an ephemeral typed shape for an already-authorized
instance: `instance_id`, `card_id`, `source_slot`, `instance_revision`,
`queued`, `locked`, `cooldown_remaining_seconds`, and optional stable binding
refs. Phase 1 does not add it to Save Registry or copy custody ownership into
the semantic service.

## Authorized Definition Envelope

AI-facing semantic compilation has no arbitrary card-ID lookup and no catalog
enumeration API. It accepts an envelope containing:

- `schema_version=1`
- `source_kind`: `own_hand`, `public_rack`, `public_reveal`, or
  `response_window`
- `source_revision`
- `visibility_scope_id`
- one detached `card_record`

The caller must obtain that envelope from an existing typed visibility owner.
The compiler validates the envelope and compiles/cache-hits the enclosed
definition. A card ID alone is never sufficient authorization.

Tooling and the production cache may compile the complete public catalog during
configuration, but the AI projection receives only an authorized semantic
snapshot and cannot enumerate or query the cache by ID.

## AiActionCandidate

The versioned candidate contains:

- `schema_version`, `action_id`, `card_id`, `source_slot`
- `source_revision`, `world_revision`
- `target_identity`
- `legal`, `rejection_reason_id`
- detached `activation_cost`
- `projected_outcomes`
- `uncertainty`, `counter_risk`
- `information_scope_id=actor_private`
- stable `explanation_tokens`
- `candidate_fingerprint`

Projected outcomes have exactly these neutral dimensions:

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

They are context estimates, not gameplay receipts. No scalar `ai_value`, policy
weight, hidden reasoning, rival private value, or mutation request is allowed.
The existing AI remains the only score and personality owner.

## PlayerFaceDTO

The detached DTO contains:

- `schema_version`, `card_id`, `family_id`, `rank`, `surface_id`
- separate `acquisition_cost` and `activation_cost`
- `timing`, `targets`, `conditions`, ordered `effect_steps`, `duration`
- `counterability`, `information_scope`
- `keywords`, each with stable `keyword_id`, text refs, icon ID, and color token
- `dto_fingerprint`

Market emphasis is acquisition cost. Hand emphasis is activation cost. Detail
shows both. The DTO contains no legacy aliases and no live legality unless a
separate authorized action projection supplies it. Existing UI compatibility
fields remain outside this DTO and are recorded for later deletion.

Localization uses stable message/keyword IDs plus typed arguments. UI text,
colors, icons, and tooltips never flow back to rules or AI.

## Determinism And Cache

The source definition and semantic fingerprints use one recursive canonical
JSON profile: dictionary keys sorted lexicographically, array order preserved,
UTF-8 JSON, SHA-256 lowercase hex. Fingerprint fields are omitted from their
own hash input.

The compiler is context-free and runs once per
`schema_version + source_definition_fingerprint`. Repeated projection reads
return detached copies and increment cache-hit counters. Candidate loops may
not call catalog loading, definition resolution, compiler normalization, or
presentation formatting.

Compilation, cache reads, AI projection, and PlayerFace projection consume no
RNG and mutate no live owner.

## Phase 1 Integration Boundary

Production composition is an editable scene under `GameRuntimeCoordinator`.
It provides one read-only semantic cache, one AI projection service, and one
PlayerFace projection service. It has no `_process`, timer, save registration,
autoload, Main dependency, current-scene lookup, dynamic method call, or effect
router dependency.

The queue, execution, transition, effect router, domain owners, Save Registry,
and RunRngService are explicit non-consumers.

Wave 3 must prove deterministic compilation, unknown-op rejection, detached
pure data, no hidden information, no per-candidate compile, zero RNG delta, no
new save section, no Main dependency, focused performance parity, real Bench
execution through Funplay Godot MCP, zero debug errors, and a clean stop.
