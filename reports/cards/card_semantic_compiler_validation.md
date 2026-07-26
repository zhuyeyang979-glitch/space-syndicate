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
| Active specs | 256 |
| `projection_only` specs | 92 |
| Not-acquirable specs | 0 |
| Compile errors | 0 |
| Normalized operations | 606 |

Readiness by category:

| Runtime readiness | Categories | Count |
| --- | --- | ---: |
| `active` | commodity 184 + facility 64 + supply/demand 8 | 256 |
| `projection_only` | monster 32 + military 28 + interaction/counter 12 + organization 20 | 92 |

Monster, military, interaction/counter, and organization records compile into
deterministic projections but cannot advertise executable readiness until their
production routes are atomically ready. This is a frozen migration-contract
classification; the pure compiler does not query live owners. Unknown or
unsupported routes still fail closed and return no semantic spec, so they cannot
carry any readiness claim.

### Monster Readiness Evidence

- `docs/monster_military_card_runtime_v06_contract.md` classifies all 32
  `deploy_or_upgrade_monster` records as production fail-closed because the real
  owner does not satisfy the atomic transaction capability contract.
- `reports/cards/monster_military_runtime_v06/effect_support_matrix.md` marks
  that route `Blocked` with `monster_owner_atomic_contract_missing`.
- `scripts/runtime/monster_runtime_controller.gd` gates the route in
  `unit_card_runtime_capabilities_v06()` on `atomic_mutation_ready` and reports
  `monster_cross_owner_atomicity_unavailable` when required cross-owner
  dependencies are incomplete.
- `data/cards/card_runtime_catalog_v06.json` keeps all 32 monster records at
  developer status
  `catalog_ready_runtime_wiring_pending`.
- `tests/unit_card_owner_capability_v06_test.gd` and
  `tests/monster_card_runtime_v06_test.gd` preserve real/bare-owner fail-closed
  gaps; positive atomic owners there are explicitly reference fixtures.

Source catalog fingerprint:

`ae2f6e17181fd31114e18d3ee0695ba5a31db99b0f09bdd4963aa556acaa4792`

Semantic catalog fingerprint:

`1db2ac3fefdeebcdf2a28525be089cdc2fef383aeebf46f9962a23b8c49d1288`

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

Final run ID: `20260726-151401-620-card_semantic_schema_compiler_test-e84378a4`

- Result: `PASS`, exit `0`, script errors `0`
- Runner duration: `1.925 s`
- Test-reported duration: `1385.410 ms`
- First 348-record compile: `277.849 ms`
- Checks: `5290`, failures: `0`
- Monster readiness regression: all `32` records are `projection_only`
- No remaining headless child process

### Real Godot MCP Bench

- Role: `A`
- Endpoint: `http://127.0.0.1:8875/`
- Godot: `4.7-stable (official)`
- Scene: `res://scenes/tools/CardSemanticCompilerBench.tscn`
- MCP runtime query result: `PASS`
- Bench checks: `38`, failures: `0`
- Compiled records: `348`
- Readiness: `256 active / 92 projection_only / 0 not_acquirable`
- Normalized operations: `606`
- Fresh compile duration: `309.003 ms`
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
- Monster, military, interaction/counter, and organization records intentionally
  remain `projection_only` even when the catalog marks them acquirable. Their
  normalized projections must not be treated as executable until production
  routes are atomically ready and the frozen migration mapping is revised.
- Military bound-action capability markers are schema-recognized fixtures only;
  current catalog compilation emits deploy/upgrade projections and does not
  claim executable move, guard, or strike capability.
- Full regression, integration composition, AI/PlayerFace consumers, and
  coordinator-level RNG/save parity remain Wave 3 responsibilities.
