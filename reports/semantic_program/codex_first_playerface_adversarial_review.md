# CODEX_FIRST_PLAYERFACE_CUTOVER Final Adversarial Review

## Findings First

### Blockers

None.

### P2 ARGS-001: Message arguments remain globally typed, not message-specific

resolve_at_presentation() requires a closed message_ref shape, stable message ID, exact typed-argument fields, unique argument IDs, approved value types, and no private/value-channel argument segments. It also verifies the sealed bundle before resolving and does not return caller arguments. The remaining hardening gap is that argument membership is validated against one global typed profile rather than an exact expected argument set per message_id.

This is non-blocking for this Codex-only cutover because production refs originate in sealed catalog-owned DTOs and argument values are not interpolated or exposed. Before future interpolation, each message ID should declare its exact canonical argument contract.

## Verdict

- Static architecture: **PASS**
- Recorded focused/runtime evidence: **PASS**
- Code blockers: **0**
- Evidence blockers: **0**
- Merge recommendation: **PASS**
- Claim limit: **PRODUCTION_UI_SEMANTIC_CUTOVER=CODEX_ONLY**

No full UI, AI, Rules, Save, RNG, Main, market, hand, or card-track cutover is claimed.

## Projector Owner Attestation

Status: **PASS**

The prior integrity gap is closed in the production projector:

1. CardPlayerFaceProjectionService.project_authorized_public_detail() accepts a semantic spec, the exact catalog record, and a typed CardPlayerFacePublicLocalizationSourceService Owner. A missing or wrong Owner type fails closed before any projection (scripts/runtime/card_player_face_projection_service.gd:283-300).
2. The projector invokes Owner.issue_verified_for_exact_record() itself. It no longer accepts a caller-supplied verified report as the production input (lines 292-304).
3. The Owner rechecks registered card membership, exact full-record fingerprint, and the semantic registry binding before issuing anything (scripts/runtime/card_player_face_public_localization_source_service.gd:337-366).
4. issue_verified_for_exact_record() builds the verified report only after that exact-record path succeeds (lines 369-385). The report builder rechecks the sealed bundle and semantic fingerprint binding (lines 425-438).
5. The projector then validates the closed verified-report schema, semantic schema, localization structure, and detached output before returning only PlayerFace/Codex presentation data (scripts/runtime/card_player_face_projection_service.gd:302-361).
6. CardCodexPublicSourceService is the sole production caller found. It passes the catalog-authorized semantic, a detached exact record, and the one composed localization Owner (scripts/runtime/card_codex_public_source_service.gd:457-466).

The exact record is transient authorization input. It is not retained in the returned bundle; the result is limited to detail_face, localization_binding, taxonomy, presentation_tokens, presentation_copy, and a bundle fingerprint.

Negative evidence is explicit:

- Caller-forged authorization cannot be substituted for the exact record (tests/card_codex_playerface_privacy_test.gd:295-311).
- A caller-modified and re-signed semantic spec is rejected by Owner registry revalidation (lines 313-328).
- A missing localization Owner is rejected (lines 329-335).

The refreshed privacy result is **PASS, 33/33 checks**. No source-authority blocker remains.

## Catalog-Owned Fast Path

Status: **PASS**

The optimized catalog-owned constructors remain narrow and adversarially covered:

- PlayerFaceDTO, PlayerCardCodexDTO, and family-ladder outputs remain detached, fingerprinted, and closed.
- Mutation cases cover unknown keys, malformed or mismatched fingerprints, private/value-channel fields, unstable identity, wrong rank/surface, Object/Callable/nonfinite values, stale nested fingerprints, family/rank mismatch, and malformed ladder entries (tests/card_codex_catalog_owned_constructor_test.gd:192-440).
- The call-site scan permits exactly the reviewed PlayerFace owner and the two Codex source constructor calls; other production fast-path call sites fail (lines 484-521).
- Recorded focused result: **PASS, 93 checks**.

This validates the exact-record optimized path without turning the fast constructor into a general caller-controlled bypass.

## Localization And Token Authority

Status: **PASS**

- CardPlayerFacePublicLocalizationSourceService and CardCodexPublicSourceAdapter both consume CardPlayerFacePublicTokenManifestV1.icon_value() and color_value(); no second expanded token map remains (scripts/runtime/card_player_face_public_localization_source_service.gd:1018-1023; scripts/runtime/card_codex_public_source_adapter.gd:432-438).
- Effect parameter names are admitted only through PARAMETER_LABELS.
- Known stable values resolve through SEMANTIC_VALUE_LABELS or the shared industry presentation authority.
- Unknown stable semantic values are omitted. Arrays and dictionaries filter empty members, so raw internal IDs and empty collection residue are not emitted.
- Authored prose is display-only. It is not parsed to select targets, timing, operations, readiness, legality, or handlers.

Message-reference validation is fail closed at both DTO and resolution boundaries (scripts/presentation/player_face_dto_v1.gd:566-625; scripts/runtime/card_player_face_public_localization_source_service.gd:475-558). ARGS-001 is the only retained non-blocking hardening item.

## Identity, Inference, And UI Consumption

Status: **PASS**

- New Codex internals use stable card_id values.
- resolve_card_id() accepts only an exact cached stable ID; localized names, Roman ranks, numeric suffixes, and monster-name parsing are absent from the new path.
- The sole compatibility bridge maps an audited monster catalog index plus explicit rank to a stable v0.6 card ID. It does not parse text.
- Card Codex rule structure comes from catalog-owned CardSemanticSpec through PlayerFace/Codex DTOs and the one-way adapter.
- The production browser, hover, detail, filters, pagination, illustration keys, and I-IV ladder consume the DTO-backed source cache.
- No target_kind.contains(), raw effect_payload interpretation, player-prose rule branch, or text-to-Rules/AI feedback was found in the new production chain.

Legacy snapshot aliases remain contained behind the compatibility boundary and retirement allowlist; no new cost/price/play_cost alias was introduced.

## Evidence Matrix

| Gate | Result |
| --- | --- |
| Public localization Owner | PASS, 74 checks |
| Full catalog projection | PASS, 18 checks; 348/348 cards; 87/87 families; 7 categories; compile delta 0 |
| Card Codex public source/snapshot | PASS |
| Catalog-owned constructor adversarial | PASS, 93 checks |
| Card Codex architecture | PASS, 113 checks |
| Card semantic architecture | PASS, 158 checks |
| Frozen AI raw-read debt | 225 value reads / 5 presence checks / 33 functions / 71 keys |
| Privacy | PASS, 33/33 checks |
| Runtime invariants | PASS, 28 checks; Save sections 19; compile count 348 -> 348 |
| Stable-ID public contract | PASS, 21 checks |
| Performance | FINAL_PASS |
| Godot MCP visual acceptance | CODEX_FIRST_PLAYERFACE_VISUAL_QA_GREEN |

The full-catalog leakage gate rejects _id=, _ids=, until_facility_destroyed, production_or_demand_by_facility_kind, and card_family markers. Projection-only cards remain displayable without changing executable readiness.

## Performance Evidence

Status: **FINAL_PASS**

Latest clean sample recorded by reports/semantic_program/codex_first_playerface_performance_review.json:

| Measure | Current |
| --- | ---: |
| Semantic access | 19 us |
| Localization initialization | 2,609,678 us |
| Dependency bind | 22,533 us |
| Startup authorization | 2,632,211 us |
| Lazy projection cache | 5,123,413 us |
| First Codex open | 5,146,887 us |
| First browser | 23,474 us |
| Repeat browser | 22,514 us |
| Hover x100 | 2,807 us |
| Detail x20 | 13,123 us |
| Full 348 facts | 10,169 us |
| Total initialization | 7,733,091 us |

- Fixed initialization gate: 7,733,091 us < 8,000,000 us.
- Startup ratio: 9.5042x < 10x.
- First-open ratio: 7.5052x < 10x.
- All five hot paths pass the 1.25x baseline gate.
- DTO/family counts: 348/87.
- Semantic compile delta: 0.
- Catalog snapshot count: 1.

The one-shot typed bind rejects hostile rebinds, and the full 348-card cache is built once on first Codex use rather than at Coordinator startup or in hover/detail/render loops.

## Scope And Ownership

Status: **PASS**

- Production composition contains exactly one CardSemanticCatalogService, one CardPlayerFacePublicLocalizationSourceService, one CardPlayerFaceProjectionService, and one CardCodexPublicSourceService.
- Public semantic authority remains CardSemanticCatalogService; public localization/token authority remains the one scene-owned localization Owner plus shared token manifest.
- Main responsibility delta: 0.
- Production AI consumer delta: 0.
- RulesProjection, RuleExecutionPlan, and handler registration delta: 0.
- Save owner/section delta: 0; fixed Save sections remain 19.
- RNG owner/draw delta: 0.
- Market, hand, and card-track PlayerFace cutover delta: 0.
- New state owner delta: 0.

Current static status contains 17 untracked .uid files, all paired with task-owned new scripts/tests and present in the reviewed allowlist. Current out-of-scope UID count is 0. This is not a staging blocker.

## Visual Evidence

Status: **GREEN**

The existing MCP report records real production browser/hover/detail operation at 1280x720 and 1920x1080, real double-click detail navigation, all seven categories, ranks I and IV, separated costs, structured rule sections, real and fallback illustration, long-text coverage, and zero raw internal-ID hits. It also records fresh runtime/editor errors 0, stopped scene state, and final Godot process count 0.

This review did not start Godot. The projector hardening changes authorization only and do not alter the DTO or visible output shape; the new security behavior is covered by the refreshed 33-check privacy run.

## Evidence Provenance

- Baseline: 46b356f99da5b536f877d96a946ceddd1720fef4
- PlayerFace projector SHA-256: 0629c04f7bfeb418fc60a75f3dc4daccea455c0c793df4dfd2b05df70a1441a0
- Card Codex source SHA-256: 135f3676c7cba05b83e0a2b85956520819e8ffb4e2b608cb8a73332a4971a6a8
- Localization Owner SHA-256: a6f6399d0d4d740cf098c280e5f7f1bc2819a94d802a1778ed1f2be6320bf7de
- Token manifest SHA-256: fb7a900be8a60868806c92be25db60158b907ab79d7d3a8e45822937d7d55513
- Compatibility adapter SHA-256: db93a206196f11c3868a53d2ee6d121cea5c9670296d66fe7e020becefdeb90a
- Privacy test SHA-256: 865afe60846ba4739dc05f6a5be40ac5e95e00442c281208df1c0b8378567014
- Catalog-owned constructor test SHA-256: afc5c4d9118eb027989207a5e8dcc23fcee5b8ba5105a8ba34c126da6c6f4255
- Full-catalog test SHA-256: c63ac4e9077a35a08a821d7085762fa14250e0a16cb093c652e22147f89b45d3
- Performance report JSON SHA-256: 9fb57edaa6fe277ea36cc3a8e5bedbae801ae796a3dd30ff2a8fa037fb11e218
- Visual report JSON SHA-256: 7fbb13e0130e90f0e20c03e9d5af66670ce3032a2c6307bcf00788cfd6467e4d

Runtime outcomes are evidence recorded by the current focused reports and supplied final reruns; this independent review performed static inspection only. No known stale-test assumption affects the projector security fix: the two new fail-closed cases are included in privacy 33/33. Visual evidence remains scoped to unchanged visible behavior.

## Final Decision

**PASS**. Blocker count: **0**.

ARGS-001 remains a non-blocking future hardening item. The merge claim must remain Codex-only.
