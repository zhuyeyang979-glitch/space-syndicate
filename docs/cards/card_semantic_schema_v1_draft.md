# Card Semantic Schema v1 Draft

Status: `WAVE_1_INTERFACE_DRAFT`

Schema ID: `space_syndicate.card_semantic_spec`

Wire version: `1.0.0`

Machine interface: `docs/cards/card_semantic_schema_v1_draft.json`

This document and the JSON Schema define a proposed interface only. They do
not enable cards, add runtime owners, change catalogs, add save sections, or
authorize gameplay. Production adoption requires a separate authority and
owner cutover.

## 1. Scope and authority

The contract separates five boundaries that must not be collapsed:

| Boundary | Type | Owns | Does not own |
| --- | --- | --- | --- |
| Static definition | `CardSemanticSpec` | Immutable card identity, costs, timing, target declarations, ordered effect operations, response and information policy | Inventory, owner, mutable cooldown, legality, AI scoring, display text |
| Instance state | `CardInstanceState` | State of one stable card instance | Static rules, hand/container membership, mutable owner, presentation |
| Legal action | `AiActionCandidate` | One already-authorized card-play action with revisions, payment allocation and selected targets | Ranking, projected outcome, mutation, display |
| Projected outcome | `AiProjectedOutcome` | Actor-private non-executable metric ranges for one candidate | Legality, authoritative receipts, mutation, player-facing explanation |
| Presentation | `PlayerFaceDTOBoundaryRef` | A reference to an independently validated player-facing DTO | Rules, legality, hidden information, save authority |

The v0.6 authority order in `AGENTS.md` applies. The player rulebook and runtime
directive outrank catalogs; catalogs outrank production code; code and tests do
not establish new product rules. A missing rule source is reported as
`RULE_AUTHORITY_NOT_ESTABLISHED`, not inferred from legacy code or card text.

## 2. Closed wire rules

All validators MUST enforce these rules before a value crosses a boundary:

1. The outer record MUST match exactly one root type in the JSON Schema.
2. Every object is closed. Missing required keys and every unlisted key are
   errors. There is no `extensions`, `metadata`, or arbitrary payload bag.
3. Optional data is represented by an omitted key. `null` is not accepted by
   any v1 field.
4. Values are JSON strings, booleans, safe integers, arrays, and closed JSON
   objects only. Floats, `NaN`, infinities, byte buffers, `StringName`, vectors,
   colors, `Resource`, `Node`, `Object`, `Callable`, signals and engine handles
   are forbidden.
5. Numeric values are integers in `[-9007199254740991,
   9007199254740991]`. Units are in field names or closed `unit_id` enums.
   Money is integer cents, duration is integer milliseconds, rates are integer
   units per minute, and percentages are integer basis points.
6. Stable IDs match
   `^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$`, are at most 160 ASCII characters,
   and are case-sensitive. Localized names are never IDs.
7. No semantic field may contain a method name, script path, callback, class
   name, scene path, RNG callback, formula expression, or executable text.
   Closed policy/profile IDs select only validator-owned tables.
8. No semantic value is derived by parsing Chinese or any other localized
   name, `rules_text`, tooltip, art key, or card title. A missing stable mapping
   blocks migration.
9. No type contains `ai_value`, utility, score, weight, rank score, method
   string, hidden reasoning, or a presentation fallback.
10. `owner`, `holder`, `controller`, `player_index`, `hidden_owner` and other
    mutable ownership mirrors are forbidden in `CardSemanticSpec` and
    `CardInstanceState`. Authoritative inventory/container owners hold custody
    membership separately by `instance_id`.

The current v0.6 catalog still contains localized commodity values in some
`effect_payload.product_id` fields. They cannot enter v1. A future migration
must use an approved explicit stable commodity-ID registry; transliteration,
name parsing, card-family guessing and hash-derived aliases are forbidden.

## 3. Required, optional and forbidden keys

The JSON Schema is the exact key oracle. The table below is a readable index;
all keys not shown in the required or optional column are forbidden.

| Type | Required keys | Optional keys | Notable forbidden examples |
| --- | --- | --- | --- |
| `CardIdentitySpec` | `card_id`, `family_id`, `rank`, `category_id`, `ruleset_id`, `definition_revision`, `tag_ids` | `industry_id`, `unique_scope_id` | name, localized text, art, owner, legacy kind |
| `CardCostSpec` | `acquisition_kind_id`, `purchase_cash_cents`, `play_cost_kind_id`, `colored_asset_cost_units`, `generic_asset_cost_units`, `submission_kind_id`, `card_disposition_id`, `transaction_policy_id` | none | mutable balances, affordability, seventh generic pool, play-time cash guess |
| `CardTimingSpec` | `timing_id`, `submission_phase_id`, `cadence_profile_id`, `clock_id` | none | timer state, callback, method, arbitrary duration |
| `CardTargetSpec` | `target_binding_id`, `target_id`, `selection_mode_id`, `minimum_count`, `maximum_count`, `allowed_entity_type_ids`, `revalidation_policy_id` | none | live target, player label, target query callback |
| `CardEffectOp` | The exact tagged branch selected by `op_id` and `op_version` | only the 1-2 declared fields inside `SupplyDemandFilterSpec` | arbitrary payload, script, method, owner, RNG callback, display text |
| `CardResponseSpec` | `response_id`, plus exact single-counter fields when applicable | none | generic continuation token, second response layer, contract response |
| `CardInformationPolicy` | all eight policy fields | none | viewer identity, live private values, presentation text |
| `CardSemanticSpec` | `schema_id`, `schema_version`, `identity`, `cost`, `timing`, `targets`, `effect_ops`, `response`, `information_policy`, `mechanic_family_ids`, `semantic_fingerprint` | none | instance state, AI fields, `PlayerFaceDTO`, localized fields |
| `CardInstanceState` | `schema_id`, `schema_version`, `instance_id`, `card_ref`, `instance_revision`, `lifecycle_state_id`, `cooldown_remaining_ms`, `use_count`, `state_fingerprint` | `binding_ref` | owner/holder/controller, hand/zone mirror, static effects, display |
| `AiActionCandidate` | all fields in its closed schema | none | `ai_value`, score, projected outcome, illegal reason, mutation callback, face DTO |
| `AiProjectedOutcome` | all fields in its closed schema | none | score, utility, legality claim, executable operation, hidden rival snapshot, face DTO |
| `PlayerFaceDTOBoundaryRef` | all fields in its closed schema | none | localized DTO body, authority, target truth, AI analysis |

`generic_asset_cost_units` is a requirement, not a seventh balance. A legal
candidate expands it into the six exact values in
`cost_payment.generic_asset_allocation_units`; their sum MUST equal the static
generic requirement.

## 4. Semantic validation after JSON Schema

JSON Schema validation is necessary but not sufficient. A deterministic
semantic validator MUST also enforce all cross-record constraints below.

### 4.1 Identity and cost

- `identity.card_id` MUST equal
  `<identity.family_id>.rank_<identity.rank>`.
- `industry_id` is required for commodity cards. Other category/industry
  combinations require an authority-backed catalog rule; absence fails closed.
- `tag_ids` and `mechanic_family_ids` MUST be unique and ASCII-sorted.
- `commodity_belt_free` requires zero purchase cash, `play_cost_kind_id=free`,
  and zero colored/generic play cost.
- `play_cost_kind_id=free` requires every play-cost integer to be zero.
- `play_cost_kind_id=assets` requires at least one positive colored or generic
  requirement.
- `not_acquirable` definitions MUST never produce an action candidate.
- A candidate payment MUST exactly satisfy the static cost. It cannot carry
  spare assets, a cash balance, or affordability evidence.

### 4.2 Targets and operations

- `targets` MUST be sorted by `target_binding_id`, and each binding ID MUST be
  unique.
- Every `effect_ops[*].target_binding_id` MUST resolve to exactly one target in
  the same definition.
- Every selected target MUST match the corresponding static `target_id`, count,
  entity types and revision policy.
- `effect_ops` order is semantic and MUST be preserved. Validation, preparation
  and commit run in that order under the existing atomic transaction owner.
- No effect op may read the result of localized presentation formatting.
- Multi-op definitions require one authority-approved atomic owner plan. A
  structurally valid multi-op definition is not executable merely because its
  individual ops are recognized.

The recognized v1 combinations are closed:

| `op_id` | Category | Required `target_id` | `timing_id` | Response | Readiness |
| --- | --- | --- | --- | --- | --- |
| `install_commodity_rate` | `commodity` | `same_industry_factory_or_market` | `shared_card_window` | `none` | owner established |
| `build_upgrade_or_repair_facility` | `facility` | `region_unique_facility_slot` | `shared_card_window` | `none` | owner established |
| `global_order_budget` | `supply_demand` | `global_matching_goods` | `shared_card_window` | `none` | owner established |
| `global_supply_spawn` | `supply_demand` | `global_matching_factories` | `shared_card_window` | `none` | owner established |
| `deploy_or_upgrade_monster` | `monster` | `region_or_existing_same_family_monster` | `shared_card_window` | `none` | blocked on atomic owner capability |
| `deploy_or_upgrade_military` | `military` | `region_or_owned_same_family_military` | `shared_card_window` | `none` | blocked on atomic owner capability |
| `player_hand_disrupt` | `interaction` | `opponent_discardable_hand` | `shared_card_window` | `single_counter` | owner established |
| `player_hand_steal` | `interaction` | `opponent_discardable_hand` | `shared_card_window` | `single_counter` | owner established |
| `card_counter` | `interaction` | `incoming_direct_player_interaction` | `counter_response_window` | `none` | owner established |
| `install_organization_upgrade` | `organization` | `self_organization_slot` | `shared_card_window` | `none` | not acquirable; owner absent |

`none` is a valid target declaration only for a future recognized op whose
authority explicitly requires no target. None of the ten current op branches
maps to it, so using it in a current v1 definition fails semantic validation.

### 4.3 Timing and response

- `shared_card_window_v06` refers to the controller-owned 30/20/5/5 cadence and
  opening 45/35/5/5 cadence. Definitions do not duplicate those durations.
- `single_counter_layer_v06` is the one five-second response layer for a
  counterable direct-player interaction. A counter never opens another layer.
- Conditional order/supply settlement is automatic and has no target-player
  consent, contract response, acceptance, rejection or timeout.
- Monster wager timing is not card response timing and cannot be represented by
  `CardResponseSpec`.

### 4.4 AI boundary checks

- A candidate exists only after the authoritative legality owner returns a
  current legal proof and all referenced op families report
  `production_readiness_id=owner_established`.
- Candidate target/card/timing/payment revisions MUST still match at commit;
  stale candidates are discarded, not repaired in place.
- A projected outcome MUST reference the exact candidate fingerprint and world
  revision from which it was computed.
- Each metric range MUST satisfy
  `minimum_delta <= expected_delta <= maximum_delta`, and `metric_id` MUST use
  its compatible `unit_id`.
- A projection is never accepted by a gameplay owner and never makes an action
  legal. It may consume public facts and actor-authorized private facts only.
- `projection_model_id` identifies a reviewed pure-data model. It is not a
  method, class, script or callback name.

## 5. Canonicalization and fingerprints

All fingerprints use profile `rfc8785_jcs_utf8_sha256_v1`:

1. Validate types, exact keys and semantic constraints first.
2. Remove only the record's own fingerprint field:
   `semantic_fingerprint`, `state_fingerprint`, `candidate_fingerprint`, or
   `projection_fingerprint`.
3. Normalize set-like arrays to required ASCII order before hashing:
   `tag_ids`, `mechanic_family_ids`, `assumption_ids` and `risk_flag_ids`.
   Reject duplicate members rather than silently deleting them.
4. Sort `targets` by `target_binding_id`. Sort projected metric rows by
   `(metric_id, subject_ref.entity_type_id, subject_ref.entity_id, horizon_ms)`.
5. Preserve semantic order for `effect_ops`, `selected_targets` and
   `entity_refs`.
6. Serialize the result with RFC 8785 JSON Canonicalization Scheme, encode as
   UTF-8, hash with SHA-256, and prefix lowercase hex with `sha256:`.
7. Compare the supplied fingerprint in constant time. Mismatch is invalid.

No timestamp, filesystem path, dictionary insertion order, engine frame,
locale, presentation text or process-specific object identity enters a
fingerprint. Optional omission and a present value are distinct; `null` cannot
be used to blur that distinction.

`PlayerFaceDTOBoundaryRef.dto_fingerprint` is the fingerprint supplied by the
separate PlayerFace DTO contract. It is a binding value, not a second semantic
fingerprint calculation.

## 6. Unknown and unsupported values fail closed

An unknown `schema_version`, `op_id`, `op_version`, `target_id`, `timing_id`,
policy ID, metric ID, entity type, authority status, or production readiness
has one behavior:

1. Reject the complete containing record before mutation.
2. Do not skip an unknown op or execute recognized siblings.
3. Do not create an AI candidate or projection from it.
4. Do not render a detailed face that implies the card is playable.
5. Do not consume a card, cash, assets, target reservation, RNG draw, cooldown
   or response slot.
6. On load, reject or quarantine the containing save section before apply; do
   not drop the card and continue the session.

Known but blocked op families use the same execution result until their
readiness gate changes through an approved rule/owner change. Recognition is
not enablement.

The following requested-looking families remain outside `CardEffectOp` v1 and
are machine-listed under `x-unrecognized-op-gaps`:

- `cash_delta`
- `financial_position`
- `information_reveal`
- `market_pressure`
- `region_damage`
- `route_modifier`
- `unit_bound_action`
- `weather_control`

Some related systems exist in v0.6, but a strict normalized card-op authority,
target contract, privacy policy and persistence owner have not all been mapped
for this interface. `RULE_AUTHORITY_NOT_ESTABLISHED` is safer than translating
historical effect strings.

## 7. Privacy

`CardInformationPolicy` declares projection policy; it never authorizes a
viewer by itself. The authoritative viewer-scoped owner applies it to facts the
viewer is already permitted to receive.

- A public catalog definition does not reveal a hidden live instance. In the
  commodity belt, an obscured card exposes color and motion only; card ID,
  family, rank, semantic fingerprint and effect ops stay absent until the
  viewer's visibility owner authorizes them.
- Ordinary play remains anonymous. Static specs and instance state contain no
  mutable actor identity. Public receipts receive only allowlisted aftermath
  and explicit authorized reveals.
- Affordability, exact asset allocation, target choice before lock, hand
  contents and response choice are actor/viewer private as specified.
- `AiActionCandidate` and `AiProjectedOutcome` are always actor-private. They
  must not enter player UI, public logs, public receipts, card history, telemetry
  or `PlayerFaceDTO`.
- Projections must not reconstruct rival cash, hands, discard choices, private
  routes, hidden owners, AI pressure buckets or future supply-bag order.
- Developer records may inspect rejected inputs in isolated tooling but cannot
  become a fallback player projection.

## 8. Persistence and ownership

This contract adds no save section.

| Record | Persistence rule |
| --- | --- |
| `CardSemanticSpec` | Catalog-owned immutable definition. Do not embed the full definition in each save. |
| `CardInstanceState` | Persist only through the established instance/inventory owner section, alongside separate authoritative container membership. |
| `AiActionCandidate` | Ephemeral; never saved, replayed as authority, or restored. |
| `AiProjectedOutcome` | Ephemeral actor-private analysis; never saved or used as replay input. |
| `PlayerFaceDTOBoundaryRef` | Presentation cache binding only; reconstruct after load from authorized sources. |

A persisted instance binds `card_id`, `semantic_schema_version` and
`semantic_fingerprint`. Load MUST resolve that exact static definition before
applying instance or containment state. A missing definition, changed
fingerprint, unsupported version, duplicate instance ID, invalid binding, or
owner-section mismatch aborts section apply without side effects.

Containment owners persist which `instance_id` is in a hand, rack, queue,
discard, installed slot or bound slot. `CardInstanceState` does not duplicate
that relationship as a mutable `owner`, `holder` or `zone` field. In-flight
prepare/commit/rollback journals remain with their established transaction and
domain owners; this schema is not a replacement checkpoint protocol.

## 9. Version and upgrade policy

- Readers support an explicit set of complete versions. Prefix matching such as
  "any v1" is forbidden.
- Patch releases may clarify documentation or tighten a validator around
  behavior already invalid. They cannot change accepted semantics or a
  fingerprint projection.
- A minor release may add a new closed tagged branch or optional capability
  only after rule authority, owner, privacy, persistence, fixtures and
  readiness are approved. Existing `1.0.0` bytes retain their meaning. An old
  reader rejects the new minor version rather than ignoring fields.
- A major release is required to rename/remove fields or IDs, change units,
  defaults, operation order, target meaning, privacy, persistence, or existing
  gameplay semantics.
- Every upgrader is a named, version-pair-specific, deterministic pure-data
  transform. It validates the exact source, creates a new record without
  mutation or gameplay side effects, validates the exact destination, and
  recomputes the destination fingerprint.
- No upgrader parses localized text, calls an RNG, invokes gameplay owners,
  invents IDs, guesses targets, or downgrades data.
- Save upgrades occur before any owner applies state. Failure preserves the
  original save and starts no partial session.

## 10. Mechanic authority and readiness

The complete machine-readable rows are in `x-op-family-registry`. This summary
records the v0.6 gate required by `AGENTS.md`.

| Mechanic family | Active source | Authoritative owner | Privacy | Persistence/readiness |
| --- | --- | --- | --- | --- |
| Commodity rate installation | Rulebook 5.3, 7.2 | `CommodityFlowRuntimeController` | Installation/location/owner public after commit; affordability private | Commodity installation owner; ready |
| Facility build/upgrade/repair | Rulebook 2.1-2.3 | `RegionInfrastructureRuntimeController` | Facility and region result public | Region infrastructure owner; ready |
| Conditional order | Rulebook 8; mechanic registry | `GlobalSupplyDemandRuntimeServiceV06` plus Commodity Flow atomic sink | Conditions/aggregate result public; owner inputs filtered | Resolution lineage plus Commodity Flow; ready |
| Conditional supply | Rulebook 8; mechanic registry | `GlobalSupplyDemandRuntimeServiceV06` plus Commodity Flow atomic sink | Conditions/aggregate result public; owner inputs filtered | Resolution lineage plus Commodity Flow; ready |
| Monster deploy/upgrade | Rulebook 9 | `MonsterRuntimeController` is the domain owner | Unit/target/result public, submitting actor anonymous unless revealed | Blocked: real owner lacks required atomic prepare/commit/rollback/finalize/checkpoint capability |
| Military deploy/upgrade | Rulebook 9 | `MilitaryRuntimeController` is the domain owner | Unit/target/result public, submitting actor anonymous unless revealed | Blocked: same atomic capability gap |
| Player hand disrupt | Rulebook 8 plus active v0.6 catalog | `PlayerHandInteractionRuntimeService` | Actor/target hand payload private; aftermath public | Inventory plus resolution history; ready |
| Player hand steal | Rulebook 8 plus active v0.6 catalog | `PlayerHandInteractionRuntimeService` | Actor/target hand payload private; aftermath public | Inventory plus resolution history; ready |
| Card counter | Rulebook 8; mechanic registry | `CardCounterRuntimeService` plus `ForcedDecisionRuntimeScheduler` | Response choice private; anonymous result public | Queue/history; ready |
| Organization install | Rulebook 7.3, 8 plus active v0.6 catalog | `RULE_AUTHORITY_NOT_ESTABLISHED` for a production owner | Installed axis clue public; affordability private | Not acquirable; no production persistence owner; blocked |

The authority rows intentionally distinguish an active player rule from a
production-ready mutation path. The schema cannot promote a blocked row.

## 11. PlayerFaceDTO boundary

`PlayerFaceDTO` belongs to presentation and is intentionally not defined here.
The only permitted semantic boundary is `PlayerFaceDTOBoundaryRef`, which binds
an external DTO to an exact `CardStaticRef`, presentation catalog revision,
locale, viewer scope and DTO fingerprint.

Data flow is one-way:

```text
CardSemanticSpec + authorized runtime projection + localization catalog
    -> PlayerFaceDTO owner
    -> PlayerFaceDTOBoundaryRef / rendered face
```

The face owner may format names, rank Roman numerals, cost chips, target labels,
short effects, icons and tooltips. It cannot change costs, timing, targets,
effects, response policy, legality or information scope. Semantic and AI
owners must never parse the resulting DTO.

## 12. Wave-1 acceptance checks

A future implementation change is not ready until focused tests prove at least:

- schema meta-validation and exact-key rejection for every root and union;
- unknown schema/op/target/timing/readiness rejection with zero side effects;
- stable-ID rejection of localized identifiers and explicit migration mapping;
- safe-integer, float, null, Object, Node, Resource and Callable rejection;
- deterministic JCS fingerprints, semantic array order and sorted set arrays;
- target-binding, op/category/timing/response and payment cross-validation;
- known-but-blocked family rejection before candidate generation;
- candidate staleness rejection and projection non-executability;
- public/viewer-private/developer leak scans;
- save definition-fingerprint binding and atomic failure before apply;
- proof that `PlayerFaceDTO` and localized text never feed semantics or AI.

This draft was designed against baseline `59756a2`. It deliberately leaves the
identified rule/owner gaps visible instead of inventing a universal card
language from historical handlers.
