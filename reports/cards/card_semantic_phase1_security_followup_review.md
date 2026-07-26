# Card Semantic Phase 1 Security Follow-up Review

## Verdict

`PASSIVE_PHASE1_MERGE_READY`

Open severity count:

- Blocker: 0
- Major: 9
- Minor: 3

Both blocker exploits from
`reports/cards/card_semantic_phase1_adversarial_review.{md,json}` are closed at
`b16b5fecf35578516f612c56acddbd985df73795`. The result is merge-ready only
for the stated passive Phase 1: the semantic catalog, AI projection, and
PlayerFace projection remain unconnected to production gameplay execution,
production AI decisions, and production UI rendering.

The remaining PlayerFace authorization gap, AI value-channel gap, missing
RulesProjection, and missing handler registry are major findings in this passive
scope. Each becomes a blocker before its corresponding production consumer is
cut over. They do not permit a current gameplay, UI, save, RNG, or balance
regression because there is no such consumer connection in Phase 1.

## Reviewed State

- Integration baseline:
  `59756a291f811a064726f59aed27efecc3590c9a`
- Prior reviewed tip:
  `4f50cc439d2879849ca1c125a320af8a18c7465e`
- Prior report commit:
  `13dad88`
- Catalog/readiness security fix:
  `6c6268bb21f7d30251706fcca0f85feefe6f2078`
- Architecture scan oracle update:
  `b16b5fecf35578516f612c56acddbd985df73795`
- Follow-up review branch:
  `codex/card-semantic-phase1-security-followup-b16b5fe`
- Worktree: isolated from the integration branch
- Production or test edits by this review: none

## Previous Blockers

### CSAR-B01: Closed - configured catalog membership is sealed

`CardSemanticCatalogService.configure()` now compiles the configured catalog
and seals canonical copies of every full source record and compiled semantic
spec at
`scripts/runtime/card_semantic_catalog_service.gd:40-76` and
`scripts/runtime/card_semantic_catalog_service.gd:149-196`.

`compile_authorized()` validates the envelope, extracts the card ID, rejects
unregistered IDs, compares the complete canonical record, and only then reaches
the compiler at
`scripts/runtime/card_semantic_catalog_service.gd:80-107`. An exact registered
record is therefore a cache hit; a structurally valid foreign record cannot add
a cache entry.

Adversarial outcomes from
`tests/card_semantic_authorization_boundary_test.gd:76-107`:

- New valid `card_id` and `family_id`: rejected.
- Registered ID with a changed effect magnitude: rejected.
- Compiler cache entry, compile, hit, and failure metrics: unchanged on both
  rejection paths.
- Returned semantic spec on either rejection path: empty.

The pure compiler remains capable of compiling arbitrary valid records when
used directly. That is intentional compiler behavior, not authorization. The
runtime catalog service and AI projector no longer treat direct compiler output
as catalog membership.

A typed source-owner receipt is still absent from the caller-authored envelope.
That is pre-cutover authorization debt, but it can no longer inject or mutate
catalog semantics and has no production consumer in this phase. It is therefore
not a blocker for this passive merge.

### CSAR-B02: Closed - AI readiness is catalog-authorized

`AiCardSemanticProjectionService.project_candidates()` now resolves the
composed catalog service, asks it to authorize the exact semantic spec, and
checks readiness only on the detached catalog-owned copy at
`scripts/runtime/ai_card_semantic_projection_service.gd:42-83`.

The catalog service compares the complete canonical semantic spec against the
sealed compiled spec at
`scripts/runtime/card_semantic_catalog_service.gd:110-132`. A caller cannot
change `runtime_readiness_id`, recompute the ordinary SHA, and retain
authorization.

Adversarial outcomes from
`tests/card_semantic_authorization_boundary_test.gd:109-176`:

- Genuine registered `projection_only` spec: zero legal candidates.
- Same spec changed to `active` and re-fingerprinted: rejected by catalog
  authorization and emits zero candidates.
- Registered active spec with a changed source-definition fingerprint and fresh
  semantic fingerprint: rejected.
- Genuine registered active spec: one legal candidate.
- AI projection: zero compiler cache metric delta.

No handler registry is yet consulted. The fixed exploit was caller-controlled
readiness, not the later executor-attestation boundary. Handler attestation
remains `CSAR-M09` and becomes blocking before execution or training cutover.

Commit `b16b5fe` adds the new
`authorize_semantic_spec` method to the scanner's exact public surface and
permits the service's `NodePath` locator. It does not add another production
authorization path.

## Bypass Matrix

| Attempt | Expected | Result |
| --- | --- | --- |
| Valid foreign record with new identity | Fail closed, no cache delta | PASS |
| Registered identity with changed payload | Fail closed, no cache delta | PASS |
| Projection-only spec re-signed as active | No legal candidate | PASS |
| Active spec with re-signed source fingerprint | No legal candidate | PASS |
| Genuine projection-only catalog spec | No legal candidate | PASS |
| Genuine active catalog spec | One candidate, no compile | PASS |

The practical residual bypass is outside these two fixed boundaries: a future
caller could still place hidden meaning in an otherwise allowed target
`stable_id` or explanation token, or fabricate an unkeyed legal-world
projection. That is the existing viewer-authorization/value-channel major
finding, not a regression introduced by `6c6268b`.

## AI Coverage Reduction

The reduction from 211 to 157 script checks and from 183 to 141 scene checks is
not a loss of required active mechanism coverage.

Before `6c6268b`, the Bench synthesized 12 semantic specs and marked all of
them `active`, including compiler-declared projection-only mechanisms. Those
positive assertions tested an invalid authorization assumption.

After `6c6268b`, all scenarios use real v0.6 catalog records:

| Readiness | Representative operations | Candidate result |
| --- | --- | --- |
| active | `install_rate`, `build_facility`, `upgrade_facility`, `repair_facility`, `modify_supply`, `modify_demand` | 6 legal representatives |
| projection_only | `deploy_unit`, `upgrade_same_family_unit`, `discard_random`, `steal_random`, `lock_random`, `counter_action` | 0 legal candidates, fail closed |

These six active operations cover every active Phase 1 category: commodity,
facility, and supply/demand. The integration gate still freezes
`348 compiled / 256 active / 92 projection_only / 606 operations`.

The 417-check golden gate independently validates 40 real cards: 12
facility/commodity, 16 unit/supply-demand, and 12 interaction/counter records.
It checks exact operation order, readiness, source fingerprint, semantic
fingerprint, and pure-data shape. Projection-only mechanisms retain semantic
coverage while correctly losing positive candidate assertions.

One minor oracle weakness remains: `representative_op_ids()` is satisfied from
scenario-declared labels before comparing projection-only labels with the
compiled spec. Golden fixtures catch current drift, but the AI Bench itself
would not identify a future label-to-record mismatch for a projection-only
scenario.

## Preserved Invariants

- Semantic catalog fingerprint:
  `1db2ac3fefdeebcdf2a28525be089cdc2fef383aeebf46f9962a23b8c49d1288`
- Catalog totals: `348 / 256 / 92 / 606`
- Candidate-loop compilation: 0
- New AI raw payload reads: 0
- Existing AI raw-field debt: `225 reads / 5 presence checks / 33 functions / 71 keys`
- New architecture violations: 0
- Save Registry: 19 sections
- New semantic Save sections: 0
- Live RNG delta: 0
- Gameplay executor connections: 0
- Candidate schema expansion: none
- Hidden-information field expansion: none
- Source catalog, compiler, schema, rules, balance, RNG, Save, and gameplay
  executor files changed by `6c6268b..b16b5fe`: none

The AI input validator and PlayerFace projector are byte-unchanged relative to
the prior report. Candidate construction copies the same target identity and
explanation-token fields as before. Thus there is no hidden-information
expansion, while the pre-existing allowed-value-channel risk remains open.

## Open Major Findings

The following prior findings remain major for passive Phase 1:

1. `CSAR-M01`: Card schema still admits synthetic non-card capability ops.
2. `CSAR-M02`: AI validation rejects forbidden keys but cannot prove allowed
   target IDs and explanation-token values are viewer-safe.
3. `CSAR-M03`: PlayerFace localization authorization is caller-asserted.
4. `CSAR-M04`: source visibility is not an effect/result disclosure policy.
5. `CSAR-M06`: v0.4 and v0.6 card authority remain composed as an explicit
   compatibility bridge.
6. `CSAR-M07`: production AI still has the frozen raw-field debt.
7. `CSAR-M08`: production UI still uses raw skill data and alias chains.
8. `CSAR-M09`: RulesProjection, RuleExecutionPlan, handler registry, and
   executor parity are absent.
9. `CSAR-M10`: random interaction operations have no explicit RNG policy.

Severity boundary:

- `CSAR-M02` becomes a blocker before production AI consumes candidates.
- `CSAR-M03` becomes a blocker before production UI consumes PlayerFace DTOs.
- `CSAR-M09` becomes a blocker before semantics can claim executable readiness,
  gameplay execution, or shared AI-training execution.
- `CSAR-M04` and `CSAR-M10` become blockers before interaction/counter
  mechanisms can become active.

`CSAR-M05` is closed by
`tests/card_semantic_golden_fixture_test.gd`, which loads and verifies all
three golden files.

## Open Minor Findings

1. `CSAR-m01`: the integration manifest still hard-codes two catalog-surface
   conclusions, although the new authorization test now supplies real evidence.
2. `CSAR-m02`: performance gates remain absolute rather than comparative.
3. `CSSF-m03`: the AI representative-op coverage counter uses scenario labels
   rather than compiled operation IDs for rejected projection-only scenarios.

## Verification

| Gate | Result | Checks | Wrapper | Focused timing |
| --- | --- | ---: | ---: | ---: |
| Authorization boundary | PASS | 24 | 1.176 s | 709.699 ms |
| Schema/compiler | PASS | 5290 | 2.145 s | 1632.954 ms; compile 312.616 ms |
| AI projection | PASS | 157 | 2.977 s | 400 projections 231.430 ms |
| Golden fixtures | PASS | 417 | 0.696 s | 155.385 ms |
| Architecture scanner | PASS | 106 | 4.741 s | 81.561 ms |
| Phase 1 integration | PASS | 27 outer | 7.419 s | 1932.923 ms |
| AI scene Bench | PASS | 141 | 2.351 s | 6 legal representatives |

All wrappers reported exit code 0, zero script errors, and zero remaining scoped
Godot processes. The isolated worktree needed one bounded import bootstrap
(25.391 s); that is an entrypoint precondition, not a product failure.

## Diff Scope

Relative to the prior report commit, production changes are limited to:

- `scripts/runtime/card_semantic_catalog_service.gd`
- `scripts/runtime/ai_card_semantic_projection_service.gd`

The remaining changes are the focused authorization test, AI test/Bench
corrections, the Bench scene, architecture scan oracle, UID, and one portable
report-path cleanup. No production catalog definition, compiler mapping, schema,
rule handler, balance value, RNG owner, Save owner, or gameplay route changed.

## Disposition

The two required blocker fixes from the prior report are complete and
independently green. Phase 1 may merge with the explicit claim
`PASSIVE_PROJECTIONS_ONLY=true`.

Do not use this verdict to claim production AI cutover, production UI cutover,
RulesProjection, handler registration, executable parity, save/replay migration,
or shared AI-training execution.
