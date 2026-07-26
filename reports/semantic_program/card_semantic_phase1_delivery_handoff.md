# Card Semantic Phase 1 Delivery Handoff

## Verdict

`STATUS=PASSIVE_PROJECTIONS_ONLY`

The reviewed Phase 1 tip is `a0a745b5511060fe22e6363a88f573e831a6147d`,
based on `59756a291f811a064726f59aed27efecc3590c9a`. The latest verified
`origin/main` is `b53223ea722bb21556f38b73614d665cc33e957d`, after PR #61 and
PR #62 merged.

Phase 1 delivers a deterministic Card semantic compiler, a sealed read-only
semantic catalog, a passive AI candidate projection, and a passive PlayerFace
projection. The three services are composed once under the existing runtime
coordinator on the current topic tip, but no production AI decision path,
production UI renderer, or gameplay executor consumes them.

This handoff does not claim:

- production AI cutover;
- production UI cutover;
- RulesProjection or gameplay executor cutover;
- a trusted operation-handler registry;
- save/replay migration;
- full-run resume completion;
- removal of the v0.4/v0.6 compatibility bridge.

No rule result, balance value, target contract, RNG order, Save envelope, or
live state owner changed in this phase.

## Delivery State

| Delivery | State | Head or merge SHA | Scope |
| --- | --- | --- | --- |
| PR #61 | MERGED | `68aa1779fd56d8e9bd8d806402d5f188a5052cf0` | Audits, frozen Card semantic contract, schema draft, migration inventories |
| PR #62 | MERGED | `b53223ea722bb21556f38b73614d665cc33e957d` | Deterministic compiler/catalog, representative fixtures, compiler gates |
| PR3 | PENDING / NOT_OPENED | none | Passive AI and PlayerFace projections, composition, security closure, Wave 3 gates, this handoff |

PR #61: `https://github.com/zhuyeyang979-glitch/space-syndicate/pull/61`

PR #62: `https://github.com/zhuyeyang979-glitch/space-syndicate/pull/62`

The current topic branch descends from the validated PR #62 head, while GitHub
wrapped PR #61 and PR #62 in merge commits on `main`. Therefore the two merge
commit objects are not ancestors of the topic tip even though their delivered
content is present. PR3 must construct and validate a real merge head against
the then-current `origin/main` before it is opened. No PR3 number exists yet.

## Delivered Contracts

| Contract | Version | Repository path | Phase 1 responsibility |
| --- | ---: | --- | --- |
| Card source authority | v0.6 machine envelope | `data/cards/card_runtime_catalog_v06.json` | Sole compiler input; player/developer text is not interpreted as rules |
| CardSemanticSpec schema | 1 | `scripts/cards/semantic/card_semantic_schema_v1.gd` | Closed fields, allowed targets/operations, validation, canonical JSON and fingerprints |
| Card semantic compiler/cache | 1 | `scripts/cards/semantic/card_semantic_compiler_v1.gd` | Deterministic v0.6 machine-to-semantic compilation and source-fingerprint cache |
| Semantic catalog service | 1 | `scripts/runtime/card_semantic_catalog_service.gd` | Eager compile, sealed catalog membership, detached authorization, aggregate diagnostics |
| Catalog service scene | 1 | `scenes/runtime/CardSemanticCatalogService.tscn` | One composed read-only service instance |
| AI projection input | 1 | `scripts/runtime/ai_card_semantic_projection_input_v1.gd` | Card instance, viewer observation and legal-target proof validation |
| AiActionCandidate | 1 | `scripts/runtime/ai_card_semantic_projection_service.gd` | Closed candidate assembly and deterministic ordering; no scalar `ai_value` |
| AiOutcomeVector | 1 | `scripts/runtime/ai_outcome_vector_v1.gd` | Eleven normalized outcome dimensions |
| AI projection scene | 1 | `scenes/runtime/AiCardSemanticProjectionService.tscn` | Passive projection service only |
| PlayerFaceDTO | 1 | `scripts/presentation/player_face_dto_v1.gd` | Closed player-facing DTO with separate acquisition and activation costs |
| PlayerFace projection | 1 | `scripts/runtime/card_player_face_projection_service.gd` | Stateless semantic-to-DTO projection with stable message/token IDs |
| PlayerFace scene | 1 | `scenes/runtime/CardPlayerFaceProjectionService.tscn` | Passive projection service only |

`AiActionCandidate` is currently an exact-key v1 dictionary contract owned by
the AI projection service rather than a standalone script class. Both AI and
PlayerFace admission delegate to the same CardSemanticSpec validator; neither
owns a second Card schema.

The runtime composition is in `scenes/runtime/GameRuntimeCoordinator.tscn` and
contains exactly one catalog service, one AI projection service, and one
PlayerFace projection service. There are zero connections from those nodes to
gameplay executors or legacy consumers.

## Catalog Result

| Measure | Result |
| --- | ---: |
| v0.6 definitions | 348 |
| Normalized operations | 606 |
| Active definitions | 256 |
| `projection_only` definitions | 92 |
| Compile errors | 0 |

Semantic catalog fingerprint:

`1db2ac3fefdeebcdf2a28525be089cdc2fef383aeebf46f9962a23b8c49d1288`

Readiness is deliberately honest:

- Active: commodity 184, facility 64, supply/demand 8.
- Projection-only: monster 32, military 28, interaction/counter 12,
  organization 20.

Catalog availability does not imply executable readiness. Projection-only
definitions compile for inspection and future adapters, but they cannot emit a
legal AI candidate.

## Representative Fixtures

| Fixture | Cards | Contract |
| --- | ---: | --- |
| `tests/fixtures/card_semantic_phase1/facility_commodity_golden.json` | 12 | Exact facility and commodity specs/fingerprints |
| `tests/fixtures/card_semantic_phase1/unit_supply_golden.json` | 16 | Monster, military and supply/demand specs/fingerprints |
| `tests/fixtures/card_semantic_phase1/interaction_counter_golden.json` | 12 | Declared interaction/counter semantics plus independently computed fingerprints |

The final golden gate covers 40 real cards and preserves operation order,
target, cost, readiness and pure-data shape.

Six active representative operations produce six legal candidates:

- `install_rate`
- `build_facility`
- `upgrade_facility`
- `repair_facility`
- `modify_supply`
- `modify_demand`

Six projection-only scenarios fail closed and produce zero legal candidates:

- `deploy_unit`
- `upgrade_same_family_unit`
- `discard_random`
- `steal_random`
- `lock_random`
- `counter_action`

The earlier 12-positive-candidate evidence was based on hand-built specs that
incorrectly marked projection-only operations active. The authorization fix
removed those false positives without reducing active mechanism coverage.

## Audit Synthesis

The canonical name/kind scan contains 57 grouped findings:

- `REMOVE=16`
- `MOVE=33`
- `KEEP=8`

The broader cross-domain sum is 403 findings:

| Audit | Findings | REMOVE | MOVE | KEEP |
| --- | ---: | ---: | ---: | ---: |
| Name and kind special cases | 57 | 16 | 33 | 8 |
| Role and passive semantics | 27 | 6 | 13 | 8 |
| Product, facility and economy | 32 | 9 | 15 | 8 |
| Monster behavior | 41 | 10 | 19 | 12 |
| Military and weather | 35 | 4 | 21 | 10 |
| Save, replay, privacy and RNG | 33 | 4 | 18 | 11 |
| UI and presentation inference | 52 | 9 | 30 | 13 |
| Content authority duality | 55 | 14 | 22 | 19 |
| Victory semantics | 39 | 4 | 21 | 14 |
| Training and execution parity | 32 | 6 | 15 | 11 |
| Aggregate | 403 | 82 | 207 | 114 |

This is an overlapping review aggregate, not 403 unique defects. Several
reports intentionally inspect the same branch, directory, field read or
authority conflict through different domain, privacy, presentation and
execution lenses. The canonical 57-item scan remains the non-duplicated
name/kind migration inventory for its defined scope.

Production AI still has explicitly ratcheted legacy debt:

- raw value reads: 225;
- raw presence checks: 5;
- affected functions: 33;
- distinct keys: 71.

The architecture scanner permits only those audited signatures to remain and
reports zero new violations. Phase 1 does not claim that debt has been removed.

## Target Authorities

| Domain | Unique target authority | Target owner | Current state |
| --- | --- | --- | --- |
| Card | CardSemanticSpec compiled from v0.6 machine blocks | CardSemanticCatalogService | Compiler/catalog implemented; not an execution input |
| Role | RoleSemanticSpec keyed by stable ASCII `role_id` | RoleCatalogRuntimeService after in-place cutover | Not implemented |
| Monster | MonsterSemanticSpec plus MonsterBehaviorSpec keyed by stable family ID | MonsterCatalogV06 after semantic/behavior/presentation split | Not implemented |
| Product | ProductSemanticSpec with frozen deterministic product order | ProductIndustryCatalogResource after parity expansion | Blocked by order/profile parity |
| Facility | FacilitySemanticSpec keyed by `facility_kind_id` | One immutable facility semantic catalog compiled from v0.6 rules | Not implemented |
| Military | MilitaryUnitSemanticSpec keyed by stable family ID | One immutable military semantic catalog | Blocked by incomplete authoritative profiles |
| Weather | WeatherSemanticSpec projected from existing WeatherDefinition resources | WeatherDefinitionCatalog | Near-ready; duplicate maps remain |
| Victory | VictorySemanticSpec compiled once from v0.6 rules and clock registry | VictoryControlRuntimeController as read-only dependency | Near-ready; schema boundary missing |

These are target authorities, not permission to add parallel live-state owners.
Dynamic card, player, monster, market, weather and victory state stays with its
existing runtime owner and must never be written back into an immutable spec.

## Migration Matrix

### Completed In Phase 1

- Closed, versioned CardSemanticSpec v1 and deterministic v0.6 compiler/cache.
- Sealed catalog membership and exact semantic authorization.
- Stable 348-definition, 606-operation catalog fingerprint.
- Passive AiActionCandidate v1 and eleven-dimension outcome projection.
- Passive PlayerFaceDTO v1 with acquisition/activation cost separation.
- Three representative golden fixture families covering 40 cards.
- Six active legal candidates and six projection-only fail-closed scenarios.
- Coordinator composition with one instance of each passive service.
- Automatic scanners for new raw AI reads, UI aliases, localized rule branches,
  per-candidate compilation and duplicate Card schema tables.
- Cross-domain authority, privacy, RNG, Save, presentation and execution audits.

### Compatibility Bridges Still Present

- v0.4 global card authority and v0.6 domain paths still coexist.
- Card submission/execution still contains v0.6 and legacy handling.
- Production AI still interprets the 225 audited raw payload values.
- Production CardPresentation/CardUI/CardViewSnapshot still use raw skill data
  and legacy aliases such as cost/price/play_cost and effect/text/description.
- Role save identity remains coupled to legacy index/name semantics.
- Product catalogs have equal membership but RNG-significant order differences.
- Monster, military, weather, diagnostics and victory consumers retain
  domain-specific maps or raw-definition interpretation.
- Localized v0.6 product IDs remain opaque source facts; no unreviewed ASCII
  replacement was invented.

### Not Migrated

- RulesProjection, RuleExecutionPlan and production handler dispatch.
- Trusted OperationHandlerRegistry with real handler/capability attestation.
- Gameplay execution parity from SemanticSpec to actual owner transaction.
- Production AI consumption of AiObservation/AiActionCandidate.
- Production UI consumption of PlayerFaceDTO.
- RoleSemanticSpec, MonsterSemanticSpec, MonsterBehaviorSpec,
  ProductSemanticSpec, FacilitySemanticSpec, MilitaryUnitSemanticSpec,
  WeatherSemanticSpec and VictorySemanticSpec implementations.
- Save/replay semantic migration and shared formal-game/training execution.
- Legacy catalog, raw payload and presentation alias retirement.

### Blockers Before Production Cutover

- AI observations, legal-target facts, stable IDs and explanation tokens need a
  viewer-owner-attested authorization boundary to close hidden-value channels.
- PlayerFace localization authorization must come from a trusted owner rather
  than caller assertion.
- Source visibility must be separated from effect/result disclosure policy.
- Random operations need explicit, authoritative randomness policies before
  interaction/counter routes become active.
- RulesProjection and handler registration must attest real production handlers,
  target/condition coverage and authoritative catalog membership.
- Semantic execution must prove result, transaction, rollback, RNG, Save and
  replay parity before replacing a legacy route.
- Product order/profile, role identity/passive authority, monster behavior,
  military profiles and Victory visibility gaps require their domain-specific
  parity decisions before those domains cut over.

## Final Gates At Reviewed Tip

All commands used `tools/invoke_godot_test.ps1` with isolated user data and
bounded timeouts. These runs were performed on the reviewed tip on 2026-07-27.

| Gate | Result | Checks/work | Wrapper time | Focused evidence |
| --- | --- | ---: | ---: | ---: |
| Authorization boundary | PASS | 24/24 | 1.164 s | 627.029 ms |
| Schema/compiler | PASS | 5290/5290 | 1.963 s | 1433.843 ms; compile 261.494 ms |
| AI projection | PASS | 157/157 | 2.780 s | 400 projections 220.021 ms |
| PlayerFace projection | PASS | 57/57 | 1.706 s | 600 projections 1.143148 s |
| Golden fixtures | PASS | 417/417, 40 cards | 0.558 s | 131.133 ms |
| Architecture scanner | PASS | 106/106 | 4.466 s | 79.766 ms; new violations 0 |
| Phase 1 integration | PASS | 27/27 plus 46 manifest checks | 6.957 s | 1902.082 ms |
| v0.6 catalog | PASS | 2894/2894 | 0.564 s | test emits no inner duration |
| Candidate performance parity | PASS | 32/32 | 9.742 s | candidate call 1454 ms; query delta 23 |
| Save owner registry | PASS | 12/12 | 5.554 s | fixed sections 19 |
| Main runtime composition | PASS | composition contract | 8.645 s | completion marker present |
| Smoke check-only | PASS | parse/load check | 4.831 s | exit 0 |

Every wrapper reported process exit 0, runner exit 0, zero script errors and
zero remaining scoped Godot processes. Candidate count remained one, the
candidate/order/selection/memory/RNG fingerprints stayed frozen, and candidate
generation consumed zero RunRngService draws.

The final security report additionally records the real AI scene Bench at
141/141 with six legal representatives in 2.351 s. PlayerFace's real scene
Bench records 22/22 with 900 accepted projections and zero runtime-console
errors. Those scene results are supporting MCP evidence; the table above is the
fresh same-tip headless gate set.

## Privacy, RNG And Save

- Privacy: Phase 1 adds no hidden-information field expansion and no production
  consumer. The remaining AI value-channel and PlayerFace authorization risks
  are mandatory blockers before those consumers cut over.
- RNG: compiler, catalog authorization, AI projection and PlayerFace projection
  consume zero live RNG. The integration gate records live RNG delta 0, and the
  performance parity gate preserves the terminal RNG fingerprint. Random
  operation policy is still unimplemented and must fail closed before activation.
- Save: the fixed registry remains 19 sections, with 0 semantic or setup
  projection sections. The Save registry gate is 12/12. No envelope, restore
  order, replay record or full-resume claim changed.
- Rules and balance: representative semantic values and ordering match the
  v0.6 source. No production rule executor consumes the projection, so Phase 1
  cannot change a live resolution result.

## Production Files Above 500 Lines

| File | Lines | Bounded responsibility |
| --- | ---: | --- |
| `scripts/cards/semantic/card_semantic_compiler_v1.gd` | 715 | One closed compile boundary: validate one source envelope, normalize operations, validate output and own the source-fingerprint cache transaction |
| `scripts/presentation/player_face_dto_v1.gd` | 650 | One exact output DTO boundary: fields, nested validators, pure-data checks, canonical sealing and profiles; no source authorization or runtime state |
| `scripts/runtime/card_player_face_projection_service.gd` | 597 | One stateless projection pipeline: authorize localization input, delegate semantic admission, construct presentation sections and seal the DTO |
| `scripts/cards/semantic/card_semantic_schema_v1.gd` | 539 | Sole Card schema oracle for closed tables, validation, canonicalization and fingerprints |

These files are large, but each remains pure or stateless and has one ownership
boundary. Splitting their closed tables from their validators would create
drift-prone duplicate authorities. None owns gameplay state, AI policy, UI
nodes, Save state, RNG state or execution transactions.

## Reconciled Inconsistencies

1. Earlier AI evidence reported 211 checks and 12 legal representatives. The
   final authorized evidence is 157 checks and six legal active representatives;
   six projection-only scenarios now correctly fail closed.
2. Older catalog reports contain earlier check counts such as 1363. The current
   same-tip catalog gate is authoritative at 2894/2894.
3. Two historical golden fixture families used different numeric normalization
   conventions for fingerprints. The 417-check gate computes each declared
   contract correctly and proves all rule-facing semantic fields are equal.
4. The source compiler carries localized product IDs as opaque authored facts
   and currently binds `install_rate` to `card_family`. A reviewed
   ProductSemanticSpec identity remains unresolved; Phase 1 does not invent one.
5. `docs/architecture/semantic_kernel_v1_contract.*` specifies the future
   shared kernel, but this topic tip does not implement a trusted
   OperationHandlerRegistry or RulesProjection.
6. PR #61/#62 merge commits live on `main`, while this topic branch retains the
   linear validated commit lineage. PR3 requires a real merge-head validation.

## 后续架构兼容性 / Next Boundary

- Phase 1 introduces no new name-, localized-text-, raw-payload- or alias-based
  rule special case. New paths consume stable IDs and the shared compiled spec;
  the scanner reports zero new violations beyond the frozen legacy allowance.
- The versioned immutable CardSemanticSpec, stable fingerprint and detached
  passive services provide one reusable source for future Player, AI and Rules
  projections without making any of those later consumers complete today.
- Static definitions remain separate from instance and decision state. No live
  cooldown, hand slot, legal target, owner or world revision is written into
  CardSemanticSpec or retained by CardSemanticCatalogService.
- CardSemanticCatalogService is composed exactly once in production under the
  existing coordinator, but remains read-only and passive. The next boundary
  must authorize its detached output; it must not add another catalog, make the
  service an instance-state owner, or connect PR3 to gameplay execution.
- The next atomic boundary is an authorized semantic envelope plus a separate
  `CardInstanceDecisionState`. Both are backlog items, not Phase 1 claims.

Recommended backlog order:

1. Authorized semantic envelope plus `CardInstanceDecisionState`.
2. Codex-first Player projection through a public, read-only consumer.
3. AI privacy authorization and raw-read ratchet migration.
4. Only later, RulesProjection and real registered handler dispatch with full
   execution, transaction, RNG, Save and replay parity.

PR3 remains passive throughout this sequence and does not claim any later
boundary is complete.

## Next Recommended Batches

1. Open PR3 from a real merge head against current `origin/main`, delivering
   only the passive AI/PlayerFace projections, composition, authorization fixes,
   Wave 3 gates and this handoff.
2. Add the authorized semantic envelope and separate
   `CardInstanceDecisionState` without changing the passive catalog owner.
3. Cut over one Codex-first public Player projection, then close AI viewer
   authorization and reduce the raw-read allowlist monotonically.
4. Implement RulesProjection and real handler dispatch only after those read
   boundaries, with trusted manifests and full execution parity gates.

## Handoff Validation

- JSON parse: PASS.
- `git diff --check`: PASS.
- Commit scope: exactly this Markdown file and its JSON companion.
- Absolute device/worktree paths in either report: 0.
- Push performed by this handoff: false.
