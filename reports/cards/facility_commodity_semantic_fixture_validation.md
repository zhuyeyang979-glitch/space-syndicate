# Facility and Commodity Semantic Fixture Validation

Status: `MERGE_READY_FOR_INTEGRATION`

## Scope

- Integration base: `1552c39dc405dd336fa5a00848b3d3425a0ee9a4`
- Branch: `codex/card-semantic-facility-fixture-repair-8c730e0`
- Schema authority: `CardSemanticSchemaV1`
- Compiler authority: `CardSemanticCompilerV1`
- Reviewed monster-readiness correction: `3d5366263619006c3071fc963b4077a4ca1c8214`
- Integrated equivalent: `5a4fadb5e76ee6c1e5be50a2529ea64dfea63537`
- Catalog authority: v0.6 `machine` blocks only
- Production code changed: none
- Catalog records changed: none
- Test scripts changed: none

The repair is limited to the family template, the twelve-card golden fixture,
and this report. It reconciles the pre-freeze fixture shape with the integrated
schema/compiler v1 without changing a rule, balance value, target, readiness
decision, or runtime route.

## Reconciliation Result

The mismatch count is a recursive shape-and-value comparison. It records
container type and keys, array length and order, scalar type, and scalar value.

| Measure | Before | After |
| --- | ---: | ---: |
| Golden cases that differ from compiler output | 12 | 0 |
| Recursive mismatch paths | 852 | 0 |
| Template rank cases that differ after deterministic assembly | 12 | 0 |
| Schema validation failures | 12 | 0 |
| Fingerprint mismatches | 12 | 0 |
| Localized product facts inside semantic output | 4 | 0 |

The old nested contract was removed. The repaired data now uses exactly:

- `timing: { timing_id }`
- `target.selection_id=actor_choice`
- compiler-owned target and filter IDs
- `response: { response_id }`
- `information_policy: { visibility_policy_id }`
- `runtime_readiness_id=active`
- acquisition and activation cost as separate dictionaries
- closed compiler operation fields and nesting

No `owner_established`, `selection_id=single`, flat timing/response/information
strings, or pre-freeze operation aliases remain.

## Exact Fingerprints

All twelve rows were compiled from the current catalog through the integrated
compiler. Source fingerprints cover the catalog ID and complete source
`machine` block. Semantic fingerprints cover the closed semantic projection
while omitting only its own `semantic_fingerprint` field.

| Card ID | Source definition SHA-256 | Semantic SHA-256 |
| --- | --- | --- |
| `commodity.star_dew_berry.rank_1` | `3e0b3740222e5ba06f24b71f053b7e5eebac22f0d2c2dd2aa95bac13a14d7a34` | `264c79ac3a6434d5e83b283fe0f8e1010af933eb58df730d6af35fdd2bebd8c4` |
| `commodity.star_dew_berry.rank_2` | `c630689aaf68fe892850512698c8a0ccbd22b2a8e1612c364bf98d7ff9efb0dc` | `7ff22c5707ceb81c4dd627e20dd6448062b95ab9e6c64953ca568699b771a70d` |
| `commodity.star_dew_berry.rank_3` | `f5319473ca204aca7090672642f84423b342a4492258f4cb2d6b2b28035d0d26` | `4ebf779a52c2b932d16dea438351396cbd8090a182de2af5abe5ab87cc23c6e0` |
| `commodity.star_dew_berry.rank_4` | `9519bfd2c7b22087433883066e1d06c5e7771a647a43308679ff71ed94886cbf` | `83b9eae3ec028b95fc1846908855c06ad64cd062873aff9134fc4c24c6ba40c4` |
| `facility.factory.life.rank_1` | `e5fc8871914a41b53e94ff9cf288da8c339153e0671f1661f20c81621f86a9e3` | `85483c5e62153fd0e1028ac5028abc0e75168ac2e897a00ac9cea7d12b20f67f` |
| `facility.factory.life.rank_2` | `f2d2da9cc8ee73ec965b6e14e16f3526781220fbf7e89709b782780b9f61f8d1` | `2c876fc2c191b0a2d797802fd58966305f00b15aef3217ef2edd6e49e4543816` |
| `facility.factory.life.rank_3` | `9b492641bd5a88ae07ffb4fc9a5e909efd415d01808a3fa7877d96f18206ff73` | `b54106d40a7fe891be40b092e44780e1416a930f229ade6db9b1d5dd3a2732c9` |
| `facility.factory.life.rank_4` | `c04eb9c9c834b7f9ebcc4d8a45129ef60be2cb1215fe337edadb6862b64854d7` | `af9cc3abf513d696cb773ecba7965eefb7142177e8b10daf4c1552610d34a111` |
| `facility.market.life.rank_1` | `91ff4178d0fe720730e2f3ccc501e5fd162dda7f21ca705d12fe1e49cb27dd6f` | `401a5697859afef6b259a8fe18533e0249f2610816566a6de86a1cc098e0a6e4` |
| `facility.market.life.rank_2` | `c112520926fd172ea953a862d69eb5467e369ab619b3716a90171c5beda0498b` | `23df44aa3bca1a05d1510916f6146512c5f89e8a87022471dd733b5bd33c41ae` |
| `facility.market.life.rank_3` | `094e82ae2e37b17e336408f02efc355b2cd55f528fb06ea04faadfb690364bd2` | `7a6db07201e04758e0b8f4886b5dd1a651a3468b9f8c4dc6d0665054432f00a0` |
| `facility.market.life.rank_4` | `d199211efdca7d59bad599f33ece548f1ef5f46cdc0cf3f00cba82ee068bb3ef` | `e8da8860b53286c4cbda5cda750eda32752c08d2587e9e04aa8d6700e9827a96` |

All twelve records are `active`. This claim is limited to the existing v0.6
core-economic facility/commodity route and does not generalize to unwired
military, interaction, or organization routes.

The monster-readiness correction changes neither these twelve semantic specs
nor any individual source/semantic fingerprint. The reviewed and integrated
correction commits have the same stable patch ID
`d7757a0a1cd4683cbf4670ccffd48a30e358b841`.

## Rule and Balance Parity

The repaired projections preserve the current catalog values:

- commodity rates: `10 / 20 / 40 / 80`
- facility purchase cash: `4 / 7 / 11 / 16`
- facility life activation assets: `0 / 2 / 4 / 7`
- facility shared HP: `100 / 200 / 300 / 400`
- factory production capacity: `40 / 80 / 140 / 220`
- market demand capacity: `40 / 80 / 140 / 220`
- build condition: `facility_slot.empty_or_district_ruined`
- upgrade condition: `facility.same_kind_lower_rank`
- repair condition: `facility.same_kind_equal_or_higher_rank`
- repair policy: `established_facility_repair`

The commodity operation now exactly matches compiler v1:
`rate_subject_id=card_family`,
`rate_axis_id=production_or_demand_by_facility_kind`, and
`rate_units_per_minute`. Facility capacity and HP fields live inside the
compiler-owned nested `facility_profile`.

## Product Identity Boundary

The localized source value `星露莓` is retained only as an opaque compatibility
fact under source/catalog evidence. It is not parsed, branched on, emitted by a
semantic operation, or replaced with an invented ASCII product alias.

Compiler output continues to use `rate_subject_id=card_family`. This repair
does not claim that `card_family` resolves the future
`ProductSemanticSpec` identity bridge. A consumer that requires that future
identity must still fail closed.

The catalog rent profile `pending_first_playtest_table` is likewise preserved
as an opaque profile ID. No numeric rent rate is invented.

## Behavioral Proof Boundary

The eight behavioral rows are explicitly marked
`projection_and_legality_only` and `runtime_execution_claimed=false`.
Each row embeds one exact compiler operation and a separate authorized target
context. The rows demonstrate branch selection expectations; they do not
execute an owner, consume a card, mutate the world, or create a second rules
path.

## Deterministic Validation

### Fixture and Template Query

A role-local Funplay MCP `execute_code` query loaded the real catalog,
schema, compiler, template, and golden fixture. JSON integral numbers were
normalized to GDScript `int` before schema validation, matching compiler
normalization.

Result:

- selected compile: `12/12`
- active readiness: `12/12`
- compile failures: `0`
- golden mismatches: `0`
- template assembly mismatches: `0`
- schema errors: `0`
- source/semantic fingerprint mismatches: `0`
- localized product leaks into semantic specs: `0`
- behavioral proof errors: `0`
- compiler cache entries/compiles: `12/12`

### Focused Headless Test

Command:

```powershell
pwsh -File tools/invoke_godot_test.ps1 `
  -TestScript res://tests/card_semantic_schema_compiler_test.gd `
  -TimeoutSeconds 60 `
  -ExpectedCompletionMarker CARD_SEMANTIC_SCHEMA_COMPILER_TEST
```

Run `20260726-153540-783-card_semantic_schema_compiler_test-b65c26e2`:

- status: `PASS`
- checks: `5290/5290`
- failures: `0`
- script errors: `0`
- wrapper duration: `2.023 s`
- test duration: `1419.280 ms`
- first catalog compile: `313.646 ms`

### Funplay Godot MCP Bench

- Role/endpoint: Role A, `127.0.0.1:8915`
- Godot: `4.7-stable (official)`
- Worktree identity: exact isolated branch worktree
- Edited scene: `res://scenes/tools/CardSemanticCompilerBench.tscn`
- Child service scene: `res://scenes/runtime/CardSemanticCatalogService.tscn`
- Bench: `PASS`, `38/38`, failures `0`
- Catalog: `348/348` compiled
- Readiness: `256 active / 92 projection_only / 0 not_acquirable`
- Operations: `606`
- Compile duration: `293.822 ms`
- Cache entries/compiles/authorized hits: `348/348/3`
- Compiler/service errors: `0/0`
- MCP script diagnostics: `0`
- Runtime error log lines: `0`
- Stop result: `Stopped the running scene.`
- Final play state: `is_playing_scene=false`

## File Hashes

- Catalog JSON SHA-256:
  `b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40`
- Template JSON SHA-256:
  `ced58639da4eca729df5ef00a7dcebb4e900fa88a8564f0d382b77c5345b321e`
- Golden JSON SHA-256:
  `fc17efc134705115b0d945d8f0522c2d3965d3988ecb90c5e20156ba64647426`
- Compiler source catalog fingerprint:
  `ae2f6e17181fd31114e18d3ee0695ba5a31db99b0f09bdd4963aa556acaa4792`
- Compiler semantic catalog fingerprint:
  `1db2ac3fefdeebcdf2a28525be089cdc2fef383aeebf46f9962a23b8c49d1288`

## Residual Risks and Mergeability

- The future `ProductSemanticSpec` identity bridge remains unresolved by
  design.
- JSON fixture readers must normalize integral JSON numbers before invoking
  the strict GDScript schema validator.
- Behavioral proofs remain projection/legality fixtures, not executable tests.
- No production code, catalog value, RNG path, save owner, or runtime route was
  changed.

The three owned files are mergeable as one fixture-only reconciliation commit.
