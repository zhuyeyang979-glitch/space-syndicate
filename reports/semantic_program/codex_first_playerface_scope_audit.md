# Codex First PlayerFace Final Scope And Ownership Audit

## Final Decision

**OVERALL PASS**

- Overall blockers: 0
- Code scope blockers: 0
- Ownership blockers: 0
- Staging blockers: 0
- Privacy blockers: 0
- Performance blockers: 0
- Visual blockers: 0

The final candidate remains confined to the Card Codex PlayerFace cutover and its focused compatibility, tests, Bench, and reports. No Main, production AI, RulesProjection, handler, Save, RNG, gameplay-state-owner, market, hand, card-track, v0.4 execution, rule-data, or balance-data cutover was found.

## Final Test Evidence

| Gate | Result |
|---|---|
| Public localization source | PASS, 74 checks |
| Full catalog projection | PASS, 18 checks; 348 cards; 87 families; compile delta 0 |
| Card Codex public source/snapshot | PASS |
| Card Codex architecture | PASS, 113 checks |
| Card semantic architecture | PASS, 158 checks; AI debt `225/5/33/71` |
| Privacy | PASS, 33 checks |
| Runtime invariants | PASS, 28 checks; Save sections 19 |
| Performance | `FINAL_PASS`, blockers 0 |
| Visual MCP | `CODEX_FIRST_PLAYERFACE_VISUAL_QA_GREEN`, blockers 0 |

All current machine reports agree on PASS. This scope audit did not start Godot or rerun tests.

## Typed Localization Owner Revalidation

The final projector boundary is owner-attested and fail closed:

```text
CardCodexPublicSourceService
    -> semantic_spec
    -> exact full card_record
    -> typed CardPlayerFacePublicLocalizationSourceService
    -> CardPlayerFaceProjectionService.project_authorized_public_detail(...)
```

`project_authorized_public_detail` now accepts exactly:

- catalog-owned `semantic_spec`;
- exact full `card_record`;
- a concrete typed localization Owner.

The projector calls `localization_owner.issue_verified_for_exact_record()` itself. It does not accept a caller-built verified localization report. It then validates the Owner-issued verified-report schema, semantic spec, localization structure, and detached output before returning the detail projection.

Privacy evidence confirms:

- forged or caller-built verified reports are not an accepted projector input;
- wrong Owner type fails closed;
- exact-record mutation fails Owner revalidation;
- private/value-channel arguments remain rejected;
- privacy suite passes 33 checks.

## Lazy Validation And Performance

The final optimization removes redundant work without weakening the authorization gate:

- Localization Owner configuration no longer performs a second semantic canonicalization after the catalog-owned cache-hit compile.
- Card Codex source binding performs typed one-shot dependency binding only; it no longer repeats full catalog validation at bind time.
- The first public Codex read remains the lazy full-catalog gate.
- That gate still validates exact catalog membership, ordinal, full record content/fingerprint, catalog-owned semantic identity/fingerprint, Owner exact-record binding, 348 cards, 87 families, and compile delta 0.
- Coordinator startup remains bind-only.
- Performance remains `FINAL_PASS`.

No validation moved into render, hover, detail, tick, AI candidate, or frame loops.

## Reviewed Candidate And Staging

- Baseline, HEAD, and merge-base: `46b356f99da5b536f877d96a946ceddd1720fef4`
- Branch: `codex/codex-first-playerface-cutover-46b356f`
- Current status paths: 62
- Tracked modifications: 16
- Untracked paths: 46
- Current untracked UIDs: 17
- Intended staging paths: 62
- Task-owned UID staging allowlist: 17
- Test-regenerated UID exclusions currently present: 0
- Out-of-scope paths in intended staging: 0
- Deleted paths: 0

The staging UID scope is unchanged. The current worktree contains only the 17 task-owned UIDs paired with new GDScripts. All 19 test-regenerated sidecars have been removed.

### Task-owned UID allowlist

- `scripts/presentation/authorized_card_player_face_localization_source_v1.gd.uid`
- `scripts/presentation/card_player_face_public_token_manifest_v1.gd.uid`
- `scripts/presentation/player_card_codex_dto_v1.gd.uid`
- `scripts/presentation/player_card_codex_family_ladder_dto_v1.gd.uid`
- `scripts/runtime/card_player_face_public_localization_source_service.gd.uid`
- `scripts/tools/card_codex_playerface_production_bench.gd.uid`
- `tests/card_codex_catalog_owned_constructor_test.gd.uid`
- `tests/card_codex_dto_compatibility_adapter_test.gd.uid`
- `tests/card_codex_playerface_architecture_scan_test.gd.uid`
- `tests/card_codex_playerface_full_catalog_integration_test.gd.uid`
- `tests/card_codex_playerface_performance_test.gd.uid`
- `tests/card_codex_playerface_privacy_test.gd.uid`
- `tests/card_codex_playerface_runtime_invariants_test.gd.uid`
- `tests/card_player_face_public_localization_source_test.gd.uid`
- `tests/card_semantic_catalog_public_authorization_test.gd.uid`
- `tests/player_card_codex_dto_v1_test.gd.uid`
- `tests/player_card_codex_family_ladder_dto_v1_test.gd.uid`

## Unique Ownership

Production composition contains exactly one of each:

| Boundary | Production instances |
|---|---:|
| `CardSemanticCatalogService` | 1 |
| `CardPlayerFacePublicLocalizationSourceService` | 1 |
| `CardPlayerFaceProjectionService` | 1 |
| `CardCodexPublicSourceService` | 1 |

The tools Bench is isolated and is not an autoload or second production owner. Source and localization dependencies remain one-shot bound and reject replacement.

Final critical hashes:

- token manifest: `fb7a900be8a60868806c92be25db60158b907ab79d7d3a8e45822937d7d55513`
- localization Owner: `a6f6399d0d4d740cf098c280e5f7f1bc2819a94d802a1778ed1f2be6320bf7de`
- PlayerFace projector: `0629c04f7bfeb418fc60a75f3dc4daccea455c0c793df4dfd2b05df70a1441a0`
- compatibility adapter: `db93a206196f11c3868a53d2ee6d121cea5c9670296d66fe7e020becefdeb90a`
- Card Codex source: `135f3676c7cba05b83e0a2b85956520819e8ffb4e2b608cb8a73332a4971a6a8`

## Frozen Boundaries

### Main

`scripts/main.gd` remains byte-identical to `origin/main`:

`cc3cfc8e57d3ec78a51df139b2d24ca5cda427f9`

Main responsibility delta: 0.

### Save

`V06SaveOwnerRegistry.FIXED_SECTION_ORDER` remains exactly 19 unique sections. Semantic, localization, PlayerFace, and Codex Save sections remain 0.

### AI debt

The frozen AI raw-read debt remains exactly:

- value reads: 225
- presence checks: 5
- functions: 33
- keys: 71

Production AI semantic consumer delta: 0. `AiRuntimeController` is unchanged.

### Forbidden subsystem deltas

| Boundary | Delta |
|---|---:|
| RulesProjection / RuleExecutionPlan | 0 |
| Executable handler registration | 0 |
| Rule or balance data | 0 |
| RNG owner or draw | 0 |
| Save owner or section | 0 |
| Market PlayerFace cutover | 0 |
| Hand PlayerFace cutover | 0 |
| Card-track PlayerFace cutover | 0 |
| v0.4 execution deletion | 0 |
| Legacy execution deletion | 0 |

## Compatibility Boundary

The sole production identity bridge remains:

`legacy_monster_codex_card_id(catalog_index, rank) -> stable v0.6 card_id`

It has one production caller, `MonsterCodexPublicSourceService`, and never parses localized names, Roman ranks, or name suffixes.

The exact alias retirement list remains:

`card_name, kind, route, effect, cost, type, rank, roman, price`

Alias count: 9. `play_cost` is denied and is not an allowed alias.

## Final Status

```text
STATUS=CODEX_FIRST_PLAYERFACE_SCOPE_OWNERSHIP_GREEN
OVERALL_PASS=true
BLOCKERS=0
CODE_SCOPE_BLOCKERS=0
OWNERSHIP_BLOCKERS=0
STAGED_OUT_OF_SCOPE_UIDS=0
MAIN_CHANGED=false
SAVE_SECTIONS=19
AI_DEBT=225/5/33/71
PRIVACY_CHECKS=33
PERFORMANCE_GREEN=true
VISUAL_MCP_GREEN=true
```
