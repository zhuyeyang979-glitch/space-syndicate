# Card Semantic Compiler v1 Validation

Status: `READY_FOR_COORDINATOR_MERGE`

Mechanic ID: `card_semantic_projection_v1_migration`

Source authority: `CardRuntimeCatalogV06Resource` machine records from
`res://data/cards/card_runtime_catalog_v06.json`

## Delivered Boundary

- `CardSemanticSchemaV1` is a closed schema for `CardSemanticSpec` v1,
  authorized definition envelopes, targets, costs, responses, information
  policy, and all Phase 1 operation branches.
- `CardSemanticCompilerV1` validates the complete v0.6 machine envelope and the
  effect-specific payload before normalization. Unknown effect/target IDs and
  missing or extra machine, payload, semantic, or operation fields fail closed.
- Recursive canonical JSON sorts dictionary keys lexicographically, preserves
  array order, serializes UTF-8 JSON, and hashes lowercase SHA-256.
- The cache key is `schema_version + source_definition_fingerprint`. A cached
  definition is compiled once and every read returns a deep detached copy.
- `CardSemanticCatalogService` eagerly compiles the public catalog but reports
  only counts, fingerprints, errors, and cache counters. Its only semantic read
  accepts the frozen authorized envelope; it exposes no card-ID lookup or
  catalog/cache enumeration API.
- The layer has no gameplay mutation, legality, execution, router, AI score,
  live state, RNG, save, Main, current-scene, or process-loop dependency.

## Catalog Result

| Measure | Result |
| --- | ---: |
| Source records | 348 |
| Compiled specs | 348 |
| Active projections | 328 |
| Organization `projection_only` specs | 20 |
| Not-acquirable specs | 0 |
| Compile errors | 0 |
| Normalized operations | 606 |

Source catalog fingerprint:

`ae2f6e17181fd31114e18d3ee0695ba5a31db99b0f09bdd4963aa556acaa4792`

Semantic catalog fingerprint:

`f45d0b017ed14294113c6125ba1eac358d50518e861b80c3b9e75ffde3e7178b`

Operation counts:

| Operation | Count |
| --- | ---: |
| `install_rate` | 184 |
| `build_facility` / `upgrade_facility` / `repair_facility` | 64 each |
| `deploy_unit` / `upgrade_same_family_unit` | 60 each |
| `extend_presence` / `heal_unit` | 32 each |
| `modify_supply` / `modify_demand` | 4 each |
| `discard_random` / `steal_random` / `counter_action` | 4 each |
| `lock_random` | 6 |
| `install_organization_upgrade` | 20 |

The localized v0.6 `effect_payload.product_id` is required and type-checked as
part of the authored source envelope, but it is never parsed, branched on, or
emitted. `install_rate` binds its subject generically to the stable card family.

## Acceptance Evidence

### Focused Headless Test

Command:

```powershell
tools/invoke_godot_test.ps1 `
  -TestScript res://tests/card_semantic_schema_compiler_test.gd `
  -TimeoutSeconds 60 `
  -ExpectedCompletionMarker CARD_SEMANTIC_SCHEMA_COMPILER_TEST
```

Final run ID: `20260726-144813-781-card_semantic_schema_compiler_test-48d9bd63`

- Result: `PASS`, exit `0`, script errors `0`
- Runner duration: `1.926 s`
- Test-reported duration: `1326.804 ms`
- First 348-record compile: `268.155 ms`
- Checks: `5287`, failures: `0`
- No remaining headless child process

An earlier 1.713-second run reached all 5,287 checks and failed only an overly
broad source-text assertion that treated the required `player` envelope key as
localized-field access. The assertion was narrowed to actual player-block reads;
production code did not change for that test-only correction.

### Real Godot MCP Bench

- Role: `A`
- Endpoint: `http://127.0.0.1:8875/`
- Godot: `4.7-stable (official)`
- Scene: `res://scenes/tools/CardSemanticCompilerBench.tscn`
- MCP runtime query result: `PASS`
- Bench checks: `38`, failures: `0`
- Compiled records: `348`
- Fresh compile duration: `286.020 ms`
- Cache entries / actual compiles / authorized hits: `348 / 348 / 3`
- Compiler failure count: `0`
- Service error count: `0`
- MCP error-console query: `0` lines
- `exit_play_mode`: `Stopped the running scene.`
- Post-stop `get_play_state.is_playing_scene`: `false`

## Remaining Risk

- This owned change creates the production service scene but does not edit
  `GameRuntimeCoordinator.tscn`; the coordinator owner must instance the scene
  during integration.
- Organization records intentionally remain `projection_only` even though the
  catalog marks them acquirable. The semantic layer does not make them active.
- Military bound-action capability markers are schema-recognized fixtures only;
  current catalog compilation emits deploy/upgrade semantics and does not claim
  an executable card route for move, guard, or strike capabilities.
- Full regression, integration composition, AI/PlayerFace consumers, and
  coordinator-level RNG/save parity remain Wave 3 responsibilities.
