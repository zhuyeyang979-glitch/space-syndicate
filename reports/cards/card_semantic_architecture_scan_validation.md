# Card Semantic Phase 1 Wave 3 QA

Status: `MERGE_READY`

## Scope

- Integration base: `4f50cc439d2879849ca1c125a320af8a18c7465e`
- Branch: `codex/card-semantic-spec-phase1-59756a2`
- Production code changes: none
- Production scene changes: none
- Catalog, compiler, schema, fixture, rule, balance, save, and RNG changes: none
- Test timeout: 60 seconds for every focused run

Owned files are limited to the architecture scanner and UID, the performance
oracle constant, the golden fixture gate and UID, and this report.

## Architecture Scanner

Command:

```powershell
pwsh -NoProfile -File tools/invoke_godot_test.ps1 `
  -TestScript res://tests/card_semantic_architecture_scan_test.gd `
  -TimeoutSeconds 60 `
  -ExpectedCompletionMarker CARD_SEMANTIC_ARCHITECTURE_SCAN_COMPLETE
```

Final run: `20260726-160722-962-card_semantic_architecture_scan_test-5f992878`

- Result: `PASS`, 106 checks, 0 failures
- Wrapper duration: `4.873 s`
- Scanner duration: `87.798 ms`
- AI raw value reads: `225`
- AI raw presence checks: `5`
- Affected AI functions: `33`
- Distinct raw keys: `71`
- New violations outside the report signatures: `0`
- Name/kind report: 57 groups, `REMOVE=16`, `MOVE=33`, `KEEP=8`
- Save Registry: 19 unique sections, 0 semantic sections

The scanner rejects Main/current-scene/save/RNG dependencies, runtime objects in
semantic payloads, localized rule parsing, raw AI skill/effect-payload reads,
candidate-loop compilation/catalog loads, semantic catalog enumeration, PlayerFace
legacy alias emission, and duplicate Card schema tables in AI or PlayerFace.
Existing AI debt may decrease, but no function/field signature may be added or
exceed the machine-readable audit allowance.

## Golden Fixture Gate

Command:

```powershell
pwsh -NoProfile -File tools/invoke_godot_test.ps1 `
  -TestScript res://tests/card_semantic_golden_fixture_test.gd `
  -TimeoutSeconds 60 `
  -ExpectedCompletionMarker CARD_SEMANTIC_GOLDEN_FIXTURE_TEST_COMPLETE
```

Final run: `20260726-160641-298-card_semantic_golden_fixture_test-ab647018`

- Result: `PASS`, 417 checks, 0 failures
- Wrapper duration: `1.335 s`
- Gate duration: `300.284 ms`
- Cards compiled: `40`
- Semantic mismatches: `0`
- Facility/commodity: 12 exact specs and fingerprints
- Monster/military/supply-demand: 16 exact specs and fingerprints
- Interaction/counter: 12 exact declared semantic projections
- Effect operation order: exact
- Runtime readiness: exact
- Pure-data validation: 40/40
- Source catalog SHA before/after: unchanged
- Unknown root, row, and semantic fields: fail closed

`catalog_values` are treated as declared recursive subsets. Interaction fixtures
use their declared `exact_except_computed_fingerprints` contract; source and
semantic fingerprints are computed independently from the complete compiler
input and complete compiler output, never from the incomplete expected record.

Integral JSON values are normalized only in the fixture test boundary. The older
facility fixture pins the production JSON source fingerprint, while the unit
fixture pins its integral-normalized test-boundary fingerprint. The gate compiles
each declared contract through the same compiler/schema and additionally proves
that normalization changes only the two fingerprint fields, not any rule-facing
semantic field, operation order, target, cost, or readiness value.

## Performance Oracle

Only `GOLDEN_AI_STATE_QUERY_COUNT_DELTA` changed, from `219` to `23`. No hash,
time budget, production code, or other assertion changed.

Before the edit:

- Run: `20260726-155237-910-ai_card_play_candidate_performance_parity_test-cc6a7885`
- Result: `FAIL`, 32 checks, 1 failure
- Wrapper duration: `10.167 s`
- Candidate call: `1568 ms`
- Actual query delta: `23`
- Commit delta: `4`
- Sole failure: stale expected query count `219`

After the edit:

- Run: `20260726-160656-181-ai_card_play_candidate_performance_parity_test-bd9d9a21`
- Result: `PASS`, 32 checks, 0 failures
- Wrapper duration: `10.883 s`
- Candidate call: `1622 ms`, below the unchanged `30000 ms` budget
- Actual query delta: `23`
- Commit delta: `4`

Frozen values remained identical before and after:

| Projection | SHA-256 |
| --- | --- |
| Candidate projection | `f329df1f8a8b04508e53f29e56244fee81bbd186f75606b7b1025340a52d64f3` |
| Original order | `237bceb0caf77bd132384a6fb5f626fed9becb2070c346d808da36defd0cce61` |
| Ranked order | `237bceb0caf77bd132384a6fb5f626fed9becb2070c346d808da36defd0cce61` |
| Forced selection | `505a6887dc16826b0171669289404bec75bbed35412fb87310c7d323898b4b86` |
| Normal selection | `505a6887dc16826b0171669289404bec75bbed35412fb87310c7d323898b4b86` |
| Normal terminal RNG | `de8e5bac67516eca681844c67c09c05ebb6a39acc38d1916fd19109de93bcd58` |
| Final memory | `9a1951ceac14f8fdfd28488f9105b2e0c405a5b5b4160666caaa05ec1637c957` |

Candidate count remained 1 and candidate generation consumed zero
`RunRngService` draws.

## Funplay Godot MCP

- Role: C
- Endpoint: `127.0.0.1:8945`
- Editor PID: `15008`
- Godot: `4.7-stable (official)`
- Worktree identity: exact integration worktree
- `edit_script`: all three test scripts written through MCP
- `validate_script`: all three returned `ok=true`, `diagnostic_count=0`
- Runtime scene: `res://scenes/tools/AiCardSemanticProjectionBench.tscn`
- Runtime result: `PASS`, 183 checks, 0 failures, 12 representative candidates
- Runtime error log query: 0 lines
- Final play state: `is_playing_scene=false`
- Editor shutdown: normal; PID exited and port closed

Godot generated 21 untracked UIDs while the editor indexed this worktree. The 19
known UIDs paired with pre-existing scripts were removed after exact-path
verification. The two UIDs belonging to the new tests were retained.

## Residual Risks

- The scanner intentionally ratchets the audited AI debt; it does not claim that
  the existing 225 raw reads have already been migrated.
- The fixture families retain two historical numeric fingerprint conventions.
  This gate makes the distinction explicit and proves rule projections are equal;
  a later fixture-format migration should select one convention atomically.
- Existing `Unexpected NUL character` notices remain in the performance fixture.
  They occur before and after this test-only change and do not alter the 32 checks.
- Repeated MCP `validate_script` calls can emit an editor-tooling resource-path
  collision notice after the structured result has returned zero diagnostics.
  Headless parsing, all focused gates, and the MCP runtime Bench are clean.

No production behavior, balance value, execution route, hidden-information
boundary, save section, or RNG order changed. The six-file change is mergeable.
