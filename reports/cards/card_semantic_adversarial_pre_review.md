# Card Semantic Phase 1 Adversarial Architecture Pre-Review

## Review identity

- Review role: Subagent K, analysis-only adversarial architecture pre-review.
- Baseline: `59756a291f811a064726f59aed27efecc3590c9a`.
- Branch: `codex/card-semantic-wave1-k-review-59756a2`.
- Reviewed proposal surface: Phase 1 semantic schema/read integration for card catalogs, AI, and card presentation.
- Production implementation reviewed: none; the branch starts at the requested baseline.
- Files owned by this review: this Markdown report and its JSON twin only.

## Verdict

**Phase 1 verdict: `BLOCKED_PENDING_ARCHITECTURE_GATES`.**

The phase is viable as a read-only, parity-preserving projection over an
authoritative card definition. It is not safe to begin production integration
until the four blocker gates below are closed. In particular, the repository
does not currently establish a `mechanic_id` or rule mapping for a new card
semantic taxonomy, two catalog generations are consumed in production, and an
AI-facing lookup by arbitrary `card_id` would bypass the existing visibility
sources.

**Report merge readiness: `READY_TO_MERGE_REPORT_ONLY` after JSON validation and
the requested two-file diff check.** This report authorizes no production,
catalog, test, scene, rule, or balance change.

Severity summary:

| Severity | Count |
| --- | ---: |
| Blocker | 4 |
| Major | 7 |
| Minor | 3 |
| No finding | 4 |

## Authority gate

`AGENTS.md:373-404` requires a `mechanic_id`, active rule source, player-facing
meaning, owner, privacy, and persistence decision before adding an Owner, Port,
AI policy, save field, or effect kind. It also requires
`RULE_AUTHORITY_NOT_ESTABLISHED` when no active clause exists.

Related established mechanics are:

- `ai_runtime_world_interaction` is ACTIVE and requires typed, visibility-legal
  AI inputs without scoring, RNG, or gameplay-rule changes
  (`docs/rules/v06_mechanic_status_registry.json:18`).
- `ai_actor_hand_inventory_typed_port_migration` is MIGRATION_ONLY and leaves
  candidate scoring and card rules unchanged
  (`docs/rules/v06_mechanic_status_registry.json:21`).
- `card_target_choice` and `card_counter_response` already have active owners;
  a semantic layer may describe them but cannot own them
  (`docs/rules/v06_mechanic_status_registry.json:14-16`).
- Retired contract mechanics have no owner, UI, AI policy, timer, or save state
  (`docs/rules/v06_mechanic_status_registry.json:25-37`).

There is no baseline registry entry for a card-semantic projection/compiler or
for any new semantic field taxonomy. Therefore:

> `RULE_AUTHORITY_NOT_ESTABLISHED` applies to every proposed semantic field
> whose meaning cannot be traced to an active rule clause plus an existing
> machine/effect field. It may not be inferred from localized text, a card name,
> current UI behavior, AI weights, tests, or historical v0.4 content.

A safe migration record should use one approved migration-only identifier (name
chosen by the authority owner, for example
`card_semantic_projection_migration`) and enumerate every allowed semantic
operation against active rule sections. It must state that Phase 1 changes no
legality, settlement, balance, RNG, persistence, visibility, or AI score.

## Baseline ownership map

| Boundary | Current authority | Evidence | Phase 1 consequence |
| --- | --- | --- | --- |
| Legacy catalog API | `CardRuntimeCatalogService` over `card_runtime_catalog_v04.tres` | `scenes/runtime/CardRuntimeCatalogService.tscn:3-9`; `docs/runtime_card_catalog_ownership_contract.md:5-20` | Do not create a second legacy catalog, fallback, or semantic sidecar. |
| v0.6 catalog | `CardRuntimeCatalogV06Resource` over `data/cards/card_runtime_catalog_v06.json` | `scripts/cards/card_runtime_catalog_v06_resource.gd:24-55`; `resources/content/alpha01/alpha01_content_manifest.tres:4-14` | Prefer machine/effect fields from the v0.6 record for v0.6 semantics, but do not claim global cutover while legacy consumers remain. |
| Definition composition | `CardRuntimeDefinitionWorldBridge` for legacy definitions and external terms | `scripts/runtime/card_runtime_definition_world_bridge.gd:31-43`; `scripts/runtime/card_runtime_definition_world_bridge.gd:89-103` | A semantic reader must consume an already-resolved definition; it must not establish new source precedence. |
| Queue state | `CardResolutionQueueRuntimeService` | `docs/card_resolution_execution_runtime_contract.md:114-123` | Semantic code owns no current/active/next state or timing. |
| Execution lifecycle | `CardResolutionExecutionRuntimeService` plus transition sink | `docs/card_resolution_execution_runtime_contract.md:135-144`; `scripts/runtime/card_resolution_transition_sink.gd:23-64` | Semantic code is not an executor, router, legality checker, or continuation owner. |
| Concrete effects | Existing economy, infrastructure, commodity, monster, military, interaction, counter, and organization owners | `docs/card_resolution_execution_runtime_contract.md:142-171`; `docs/content/alpha01/dependency_and_privacy_audit.md:27-41` | Semantic operations describe existing effect facts only; executors continue to route by established effect kind/typed owner. |
| AI policy and scoring | `AiRuntimeController` | `docs/ai_runtime_ownership_contract.md:5-7`; `scripts/runtime/ai_runtime_controller.gd:7377-7444` | Definitions expose neutral mechanics, while all weights, contextual utility, ranking, and reasons stay private in AI. |
| Card-facing presentation | `CardPresentationRuntimeService` | `docs/card_presentation_viewmodel_runtime_contract.md:3-24` | It remains the sole owner of labels, icons, chips, quick copy, tooltips, and cinematic presentation. |
| Viewer-scoped table composition | `TablePresentationViewModelQuery` and `GameTableViewModelRuntimeService` | `scripts/presentation/table_presentation_viewmodel_query.gd:91-151`; `docs/card_presentation_viewmodel_runtime_contract.md:13-20` | Semantic data enters UI only after viewer authorization and through Presentation. |
| Save sections | `V06SaveOwnerRegistry` with exactly 19 sections | `docs/v06_save_owner_registry_contract.md:5-20`; `scripts/runtime/v06_save_owner_registry.gd:28-48` | Semantic definitions/cache add no save field or twentieth section. |
| Gameplay randomness | one scene-owned `RunRngService` | `scripts/runtime/run_rng_service.gd:8-22`; `scenes/runtime/RunRngService.tscn:5-7` | Semantic compile/read is deterministic and consumes zero draws. |
| Composition policy | editable scenes plus typed owners; Main is frozen | `AGENTS.md:222-225`; `AGENTS.md:406-428` | No Main call/get/set/has_method path; any new runtime responsibility needs production scene and Bench evidence. |

The current production table consumes both catalog generations. Legacy table
lookups prefer the v0.4 service, while only selected v0.6 categories are
normalized through the v0.6 resource
(`scripts/presentation/table_presentation_viewmodel_query.gd:632-683`). This is
transition debt, not permission for a third long-term authority.

## Findings

### BLOCKER B-01: Semantic field rule authority is not established

**Status:** open. **Authority:** `RULE_AUTHORITY_NOT_ESTABLISHED` for the new
taxonomy; authority gate at `AGENTS.md:373-404`.

The active registry defines card response, target choice, AI typed-port
migrations, and retired contract mechanics, but no semantic projection or field
vocabulary (`docs/rules/v06_mechanic_status_registry.json:13-37`). Production
code and tests cannot supply the missing product authority.

**Required gate:** approve one migration-only mechanic record and a field
authority matrix. Every operation/tag must cite the rulebook section, source
machine/effect fields, established gameplay owner, visibility, and persistence
(`none` for this phase). Unknown fields fail closed instead of receiving a
generic fallback meaning.

### BLOCKER B-02: A canonical source and deletion path are required before semantic authoring

**Status:** open. **Authority:** single-owner architecture in
`docs/runtime_card_catalog_ownership_contract.md:5-20,65-90`; migration order in
`docs/rules_v06_runtime_directive.md:246-260`.

`CardRuntimeCatalogService` still declares the v0.4 Resource authoritative,
while the v0.6 catalog independently carries 348 machine/player/developer
records and is already consumed by inventory, regional supply, facilities, and
presentation (`scripts/cards/card_runtime_catalog_v06_resource.gd:4-25`;
`scripts/runtime/game_runtime_coordinator.gd:1925-1933,2249-2254`). A standalone
`card_semantics.json`, a duplicate mapping in AI, and a duplicate mapping in
Presentation would create three drift points.

**Required gate:** select one canonical authored location. For v0.6 work, the
recommended location is a validated, neutral semantic block within the v0.6
machine definition or its typed Resource representation. Consumers receive it
through one typed read boundary. Any legacy adapter is explicitly transitional,
read-only, parity-tested, and assigned a deletion gate. No runtime sidecar may
outlive that cutover.

### BLOCKER B-03: An arbitrary card-id semantic query would expose hidden candidates

**Status:** open until the AI-facing request contract is specified.
**Authority:** `docs/tabletop_rulebook_v06.md:172-175,340-348` and
`docs/rules_v06_runtime_directive.md:145-163`.

AI may inspect its own authorized hand and currently public regional rack, but
not the future supply bag or an obscured commodity identity. A semantic API such
as `semantic_for_card_id(id)` or `all_semantics()` would allow AI to enrich an ID
obtained outside the visibility boundary. Filtering the returned keys would not
repair invalid candidate provenance.

**Required gate:** the AI-facing port accepts only an authorized, detached card
definition/provenance envelope produced by the existing own-hand or public-rack
port. It exposes no enumeration, search, future-bag, obscured-belt, or arbitrary
ID lookup. Authorization revision/source binding is checked before enrichment.
Candidate world/player/owner/target facts never enter the semantic snapshot.

### BLOCKER B-04: Scores and policy weights must not enter public card definitions

**Status:** open until schema rejection and public-recursive privacy gates exist.
**Authority:** AI ownership at `docs/ai_runtime_ownership_contract.md:5-7`; AI
score secrecy at `docs/tabletop_rulebook_v06.md:334` and
`docs/ai_runtime_ownership_contract.md:109-113`.

`AiRuntimeController` currently owns field weighting and contextual scoring
(`scripts/runtime/ai_runtime_controller.gd:7377-7444,8288-8302`). Public
presentation explicitly forbids `ai_utility_score`, route-plan score, learning
bonus, candidate weights, and score decomposition
(`docs/migration/table_presentation_privacy_review.md:286-317`). A catalog field
named `ai_score`, `utility`, unscoped `weight`, `priority`, or a disguised AI
coefficient
would move AI policy into a public definition and create a second policy owner.
The rule-authorized `region_supply_weight` remains a supply-owner catalog field;
it is not an AI utility and must not be copied into candidate scoring metadata.

**Required gate:** catalog and semantic validators recursively reject AI score,
policy-weight, reason, candidate, plan, learning, and policy fields. The semantic
snapshot carries only neutral, rule-backed operations and magnitudes. AI applies
its private policy after the typed read and preserves candidate/order/selection
parity in Phase 1.

### MAJOR M-01: The semantic layer must not become a second card engine

**Status:** mandatory boundary. **Authority:**
`docs/rules_v06_runtime_directive.md:39-45` and
`docs/card_resolution_execution_runtime_contract.md:112-144,227-229`.

The semantic layer may validate and project definitions. It may not decide play
legality, target legality, costs, queue order, execution, continuation,
settlement, cooldowns, inventory mutation, effect ownership, or world mutation.
Execution and concrete domain owners must not import the semantic reader. A
semantic projection is never an effect request or receipt.

### MAJOR M-02: No localized-text rules and no specific-card branching

**Status:** mandatory boundary. **Authority:** typed-source directive at
`docs/rules_v06_runtime_directive.md:9-11`; field-driven hard filtering at
`docs/tabletop_rulebook_v06.md:342-346`.

The current Presentation service contains extensive `kind`/tag-to-copy logic
and reads display text (`scripts/runtime/card_presentation_runtime_service.gd:27-48,451-506`).
That is presentation debt, not a machine-rule source. Semantic compilation must
not parse Chinese/English rules text, keyword tooltips, localized keys, card
names, family names, or UI labels. It also must not branch on a specific
`card_id`/name. Generic dispatch by a closed active `effect_kind` plus validated
machine fields is allowed; exceptional content requires an authored field with
authority, not code keyed to one card.

### MAJOR M-03: Presentation remains the sole UI-rule owner

**Status:** mandatory boundary. **Authority:**
`docs/card_presentation_viewmodel_runtime_contract.md:3-24,34-48`.

The semantic schema may expose neutral category, target, operation, and numeric
facts. It must not own colors, icons, chip order, line length, compact/full copy,
tooltips, animation styles, layout, card-face visibility, or action enablement.
`CardPresentationRuntimeService` converts authorized semantic facts into card
ViewModels; UI never feeds presentation-derived facts back into gameplay.

### MAJOR M-04: Compile once per definition fingerprint, never once per score

**Status:** mandatory performance/ownership boundary. **Authority:** repository
performance policy at `AGENTS.md:303-305`; current zero-RNG candidate performance
gate at `tests/ai_card_play_candidate_performance_parity_test.gd:147-170`.

The compiler must be deterministic and context-free. Compile at catalog
validation/configuration or lazily once for a stable
`semantic_schema_version + catalog_id + definition_fingerprint` key. Return
detached immutable snapshots. AI candidate scoring reads the cached snapshot;
it must not parse/normalize/recompile per card, target, district, score
component, comparison, or frame. Cache state is derived and disposable.

### MAJOR M-05: No save section, save payload, or RNG change

**Status:** mandatory boundary. **Authority:**
`docs/v06_save_owner_registry_contract.md:22-51,69-71` and
`scripts/runtime/run_rng_service.gd:44-61,167-187`.

Semantic definitions and compiled caches are static/derived data. They add no
save field, owner binding, restore hook, replay lineage, seed, stream, draw,
shuffle, tie-break, or random fallback. Compile/read must leave the shared RNG
checkpoint byte-equivalent. A cache is rebuilt from the canonical definition
after load; it is never serialized as a twentieth v0.6 section.

### MAJOR M-06: Integration must be typed, scene-owned, and Main-free

**Status:** mandatory boundary. **Authority:** `AGENTS.md:406-428` and scene/Bench
policy at `AGENTS.md:222-225,335-343`.

No new code may call Main through `call`, `get`, `set`, `has_method`, a string
method name, a Callable, `/root/Main`, `current_scene`, or a world bridge bound
to Main. Prefer a typed query port composed once under
`GameRuntimeCoordinator`; inject it directly into Presentation and AI. If a new
runtime responsibility is created, it needs an editable production `.tscn`, a
focused production-wiring Bench, Godot MCP run/debug/stop evidence, and a
negative dependency gate. Coordinator/Main hot-file wiring belongs to the
integration writer (`docs/development/current_file_ownership.json:5-35`).

### MAJOR M-07: Retired and unavailable mechanics must fail closed

**Status:** mandatory boundary. **Authority:** retirement directive at
`docs/rules_v06_runtime_directive.md:15-27`; registry at
`docs/rules/v06_mechanic_status_registry.json:25-37`.

The semantic validator must reject retired contract consent/accept/reject/
timeout/signature/penalty, retired contract-trace cards, retired project/share,
legacy heat/panic damage, route-HP ownership, and other retired identifiers.
It also must not activate content merely because a catalog record exists.
Organization cards remain unavailable in the current player pool
(`docs/tabletop_rulebook_v06.md:398-440`), and the current program state records
zero active organization cards and `DEFERRED` status
(`docs/development/current_program_state.json:183-196`). Their metadata may be
validated offline, but AI candidates and public acquisition surfaces must not
be created by semantic compilation.

### MINOR MIN-01: The snapshot needs closed schema identity and provenance

**Status:** required before Wave 3. **Authority:** pure-data catalog contract at
`docs/runtime_card_catalog_resource_schema.md:70-85`.

Include a schema version, catalog/ruleset identity, definition fingerprint,
card/family/rank identity, active mechanic IDs, and source effect kind. Reject
unknown keys and non-finite or Object/Node/Resource/Callable values. Do not
include file paths, implementation status, runtime owner objects, or mutable
source dictionaries in consumer snapshots.

### MINOR MIN-02: Parallel file ownership needs an explicit integration handoff

**Status:** open operational gate. **Authority:** one-writer policy at
`docs/development/current_file_ownership.json:5-38`.

The v0.6 catalog, v0.4 root catalog, coordinator script/scene, Main, and major UI
surfaces are shared hot files. Schema, AI, Presentation, and integration work
must not each edit them independently. Wave 3 should merge one owner at a time,
with catalog/schema first, then typed consumers, then the integration writer's
single production composition change.

### MINOR MIN-03: Diagnostics must report counts, not private payloads

**Status:** required before Wave 3. **Authority:** AI privacy at
`docs/ai_runtime_ownership_contract.md:109-113` and public presentation filter at
`docs/migration/table_presentation_privacy_review.md:286-317`.

Debug output may report schema version, source fingerprint, cache hit/miss/
compile counts, validation errors by public card ID, and consumer readiness. It
must not dump candidate lists, scores, reasons, private hands, owner truth,
targets, future bag order, or full private definitions.

### NO-FINDING N-01: Existing queue/execution ownership can remain untouched

The queue, timing, execution, transition, and concrete effect boundaries are
already explicit and do not require a semantic state owner
(`docs/card_resolution_execution_runtime_contract.md:112-171`). The safe Phase
1 design can remain read-only and outside the execution graph.

### NO-FINDING N-02: Save and RNG authorities are already unambiguous

The v0.6 registry has a fixed 19-section order and session owns the one shared
RNG continuation (`scripts/runtime/v06_save_owner_registry.gd:28-48`;
`docs/v06_save_owner_registry_contract.md:48-71`). No semantic persistence or
randomness is needed.

### NO-FINDING N-03: The current v0.6 catalog has no retired-identifier hit

A structured scan of all 348 v0.6 records found zero instances of the retired
contract identifiers and legacy `panic`/`heat` keys listed in the review scan.
The catalog's machine shape is already cleanly separated from player and
developer sections (`scripts/cards/card_runtime_catalog_v06_resource.gd:107-164`).
This does not waive the future negative validator.

### NO-FINDING N-04: Existing scene seams are suitable for typed consumers

`CardPresentationRuntimeService`, `AiRuntimeController`, and the catalog service
are each statically composed under `GameRuntimeCoordinator`
(`scenes/runtime/GameRuntimeCoordinator.tscn:24-52,254-258,334-337,394-430`).
A narrow semantic query port can be injected there without adding a Main
dependency or a second process loop.

## Hard invariants

These are rejection criteria, not preferences:

1. **HI-01 No second card state owner/engine.** Semantic code owns no card
   instance, hand, queue, timing, target, legality, execution, effect, cooldown,
   history, or settlement state.
2. **HI-02 No AI score in public definitions.** No AI score, utility,
   policy-weight, priority, reason, candidate, plan, learning, or policy
   coefficient is stored in public/catalog semantic output.
3. **HI-03 No localized-text rules.** Machine semantics never parse or match
   display/rules text, localization keys, tooltips, or translated keywords.
4. **HI-04 No UI rules.** Semantic data owns no color, icon, chip order, copy,
   layout, tooltip, animation, or action-state decision.
5. **HI-05 No save section.** No new save key, owner binding, restore hook, or
   twentieth v0.6 section; cache is rebuilt.
6. **HI-06 No RNG change.** Zero draws, streams, seeds, shuffles, random
   fallbacks, or tie-break changes; checkpoint equality is tested.
7. **HI-07 No retired mechanics.** Retired identifiers fail validation and
   cannot enter candidates, presentation, execution, AI, or persistence.
8. **HI-08 No untyped/Main bypass.** No Main/current-scene lookup, dynamic
   call/get/set/has_method, string callback, or compatibility fallback.
9. **HI-09 No candidate hidden information.** AI receives semantics only after
   own-hand/public-rack/belt visibility authorization; no arbitrary ID lookup or
   enumeration exists on the AI port.
10. **HI-10 No per-score compilation.** At most one compile per stable
    definition fingerprint and semantic schema version; scoring is cache-read
    only.
11. **HI-11 No specific-card branching.** No `card_id`, card-name, family-name,
    or localized-tag code branch; use closed active effect kinds and authored
    fields.
12. **HI-12 No dual long-term authority.** One canonical authored semantic
    source and one typed read path; temporary legacy adapters have a named
    deletion gate and are never writable authorities.
13. **HI-13 Fail closed on unknown meaning.** Any untraceable field is
    `RULE_AUTHORITY_NOT_ESTABLISHED`, not a generic inferred behavior.

## Recommended safe boundary

### Canonical data

Use the active v0.6 card machine definition as the eventual authoring authority.
Store only neutral, rule-backed operation descriptors and their existing
machine magnitudes. Do not add a parallel runtime JSON/TRES catalog. The v0.4
path may have a read-only normalization adapter only where parity is required,
and that adapter must be deleted with the catalog cutover.

An allowed snapshot is conceptually limited to:

```text
semantic_schema_version
ruleset_id
catalog_id
definition_fingerprint
card_id / family_id / rank
category_id / industry_id
effect_kind / target_kind
active mechanic_ids
closed operation descriptors
validated mechanical magnitude facts
```

It excludes all runtime state, visibility decisions, AI policy, presentation
copy/style, executable objects, and persistence.

### Compile/read service

Use one deterministic, context-free compiler/validator behind a typed,
scene-owned query port. Prefer an API that accepts an already resolved and
authorized definition snapshot rather than a raw ID. The port:

- validates source schema/fingerprint and active mechanic mapping;
- compiles or retrieves one cached neutral snapshot;
- returns a deep detached copy;
- exposes no mutation, enumeration, score, target selection, save, or RNG API;
- invalidates by catalog/definition fingerprint, not by frame or candidate;
- reports only public-safe counters and validation codes.

### AI integration

The flow must be:

```text
authorized own hand or public rack
  -> typed candidate provenance
  -> semantic query of that authorized definition
  -> neutral semantic snapshot
  -> AiRuntimeController private weights/context/score/rank
```

Phase 1 must preserve candidate membership, order, exact score, selected action,
decision metadata privacy, and RNG state. A later score change requires its own
AI policy/balance authority and is outside this migration.

### Presentation integration

The flow must be:

```text
viewer-authorized public/private card source
  -> neutral semantic snapshot
  -> CardPresentationRuntimeService
  -> CardViewSnapshot / table ViewModel
  -> UI
```

Presentation may use semantic operations to choose existing presentation
concepts, but it remains responsible for copy, iconography, chips, tooltips,
compact/full forms, and animation. No Presentation output returns to gameplay or
AI.

### Explicit non-consumers

Card Queue, Resolution Controller, Execution Service, Transition Sink, Effect
Router, domain effect owners, Save Registry, and Run RNG must have no dependency
on the semantic query port.

## Wave 3 review checklist

### Authority and scope

- [ ] W3-01 One approved migration-only `mechanic_id` exists with rule source,
  player meaning, owner, privacy, and persistence (`none`).
- [ ] W3-02 Every semantic operation has an active rule/effect-field mapping;
  gaps are reported as `RULE_AUTHORITY_NOT_ESTABLISHED`.
- [ ] W3-03 The diff contains no rule, balance, legality, target, effect, RNG, or
  persistence behavior change.

### Ownership and catalog

- [ ] W3-04 One canonical authored semantic source is named; no sidecar or
  writable duplicate exists.
- [ ] W3-05 Legacy adapter scope and physical deletion gate are documented.
- [ ] W3-06 Catalog validators reject unknown, non-data, AI-policy, UI, private,
  retired, and unavailable-active-surface fields.
- [ ] W3-07 All catalog outputs are detached pure data and fingerprint-bound.
- [ ] W3-08 No specific-card/name/family/localized-text branch exists.

### AI and hidden information

- [ ] W3-09 AI semantic reads originate only from typed own-hand/public-rack or
  viewer-legal belt candidates and bind source revision/provenance.
- [ ] W3-10 AI-facing API has no arbitrary-ID lookup, enumeration, future-bag,
  or obscured-card path.
- [ ] W3-11 Scores, weights, reasons, candidate lists, plans, and learning stay
  inside `AiRuntimeController` and private save state only.
- [ ] W3-12 Candidate set/order/scores/selection and RNG parity pass for play,
  buy, counter, and obscured/public supply cases.

### Presentation

- [ ] W3-13 `CardPresentationRuntimeService` remains the only card-facing UI
  rule owner.
- [ ] W3-14 Public, owner-private, rival-private, obscured-belt, and final-audit
  projections pass recursive leak tests.
- [ ] W3-15 Card faces consume semantic facts without parsing localized text,
  and no semantic field encodes icon/color/layout/copy.

### Runtime isolation

- [ ] W3-16 Queue, timing, execution, transition, effect router, and concrete
  owners have zero semantic-port imports/references.
- [ ] W3-17 Save manifest remains exactly 19 sections and save round-trip bytes
  are unchanged for this phase.
- [ ] W3-18 `RunRngService.capture_plan_checkpoint()` is identical before and
  after compile, query, presentation, candidate generation, and cache rebuild.
- [ ] W3-19 No Main/current-scene/dynamic method-name dependency or fallback is
  present; negative dependency scans pass.
- [ ] W3-20 Production composition contains one semantic query port and no
  second process/tick/execution path.

### Compile and evidence

- [ ] W3-21 Compile count is at most one per definition fingerprint/schema;
  repeated AI score and presentation reads are cache hits.
- [ ] W3-22 Cache invalidation on catalog/schema fingerprint change is
  deterministic, fail-closed, and unsaved.
- [ ] W3-23 A focused headless contract test covers positive and negative
  schema, privacy, authority, parity, and cache cases.
- [ ] W3-24 An editable production `.tscn` and production-wiring Bench exist for
  any new runtime responsibility.
- [ ] W3-25 Godot MCP opens the real scene/Bench, runs cleanly, reports zero
  debug errors, and stops cleanly; paths and results are recorded.
- [ ] W3-26 Final diff touches only assigned files, shared-hot-file integration
  is performed by the integration writer, JSON/resources validate, and no
  unrelated catalog/rule/balance churn is present.

## Merge recommendation

- This two-file analysis commit: **merge-ready after validation**.
- Phase 1 production implementation: **not merge-ready** until B-01 through
  B-04 and W3-01 through W3-12 are concretely satisfied in the proposed design.
- No Godot runtime/MCP acceptance is required for this analysis-only report;
  it becomes mandatory for any production semantic Port/Service/scene change.
