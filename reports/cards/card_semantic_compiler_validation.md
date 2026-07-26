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
- Runtime readiness is an explicit property of each closed effect contract.
  Acquisition does not imply execution support: only production-wired routes
  are `active`; known but unwired routes remain `projection_only`.
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
| Active specs | 288 |
| `projection_only` specs | 60 |
| Not-acquirable specs | 0 |
| Compile errors | 0 |
| Normalized operations | 606 |

Readiness by category:

| Runtime readiness | Categories | Count |
| --- | --- | ---: |
| `active` | commodity 184 + facility 64 + supply/demand 8 + monster 32 | 288 |
| `projection_only` | military 28 + interaction/counter 12 + organization 20 | 60 |

Military and interaction/counter records compile into deterministic projections
but cannot advertise executable readiness until their production executor
routes are wired. Unknown or unsupported routes still fail closed and return no
semantic spec, so they cannot carry any readiness claim.

Source catalog fingerprint:

`ae2f6e17181fd31114e18d3ee0695ba5a31db99b0f09bdd4963aa556acaa4792`

Semantic catalog fingerprint:

`5d0f57e3079dab72ec3d5c95ac4825dc23ce5762194d6d2ac93e70153e07b189`

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

## Responsibility Review

The compiler reviewed at 704 lines (715 after this explicit readiness revision)
remains one compilation boundary: it validates one closed source definition,
maps its authored effect into normalized operations, validates the resulting
spec, and owns the source-fingerprint cache transaction. Splitting those stages
would expose or duplicate intermediate machine semantics without creating an
independently reusable responsibility.

The 539-line schema remains the single closed-schema oracle for allowed field
tables, recursive canonicalization, and structural validation. Moving its tables
or validators into separate files would create a drift-prone second schema
authority. Neither file was expanded into a replacement monolith for this
revision; the readiness change stays in the compiler's existing contract table.

## Acceptance Evidence

### Focused Headless Test

Command:

```powershell
tools/invoke_godot_test.ps1 `
  -TestScript res://tests/card_semantic_schema_compiler_test.gd `
  -TimeoutSeconds 60 `
  -ExpectedCompletionMarker CARD_SEMANTIC_SCHEMA_COMPILER_TEST
```

Final run ID: `20260726-150141-591-card_semantic_schema_compiler_test-b6e04078`

- Result: `PASS`, exit `0`, script errors `0`
- Runner duration: `1.941 s`
- Test-reported duration: `1376.819 ms`
- First 348-record compile: `272.795 ms`
- Checks: `5289`, failures: `0`
- No remaining headless child process

### Real Godot MCP Bench

- Role: `A`
- Endpoint: `http://127.0.0.1:8875/`
- Godot: `4.7-stable (official)`
- Scene: `res://scenes/tools/CardSemanticCompilerBench.tscn`
- MCP runtime query result: `PASS`
- Bench checks: `38`, failures: `0`
- Compiled records: `348`
- Readiness: `288 active / 60 projection_only / 0 not_acquirable`
- Normalized operations: `606`
- Fresh compile duration: `390.662 ms`
- Cache entries / actual compiles / authorized hits: `348 / 348 / 3`
- Compiler failure count: `0`
- Service error count: `0`
- MCP compiler/bench script diagnostics: `0 / 0`
- MCP error-console query: `0` lines
- `exit_play_mode`: `Stopped the running scene.`
- Post-stop `get_play_state.is_playing_scene`: `false`

## Remaining Risk

- This owned change creates the production service scene but does not edit
  `GameRuntimeCoordinator.tscn`; the coordinator owner must instance the scene
  during integration.
- Military, interaction/counter, and organization records intentionally remain
  `projection_only` even when the catalog marks them acquirable. Their normalized
  projections must not be treated as executable until production routes exist.
- Military bound-action capability markers are schema-recognized fixtures only;
  current catalog compilation emits deploy/upgrade projections and does not
  claim executable move, guard, or strike capability.
- Full regression, integration composition, AI/PlayerFace consumers, and
  coordinator-level RNG/save parity remain Wave 3 responsibilities.
