# Post-Setup Active Fixture Inventory

Baseline: `0e7ee717ac6323ee2af24a8d6617a0319f038081`

The frozen scan contains 55 files and 119 exact retired-setup tokens. Classification is complete: unknown count `0`, source-splitting evasion count `0`.

## Batch A: Formal Compendium Tests

- `tests/compendium_readonly_navigation_cutover_test.gd`
- `tests/bestiary_double_click_detail_navigation_test.gd`
- `tests/compendium_v06_public_semantics_test.gd`
- `tests/product_codex_public_source_service_test.gd`
- `tests/role_codex_public_contract_test.gd`

These five `COMPENDIUM_ACTIVE_FORMAL_TEST` fixtures are the only tests changed in batch A.

## Batch B: Codex Benches

- `scripts/tools/card_codex_public_snapshot_cutover_bench.gd`
- `scripts/tools/codex_atlas_scene_cutover_bench.gd`
- `scripts/tools/codex_navigation_runtime_cutover_bench.gd`
- `scripts/tools/codex_public_snapshot_cutover_bench.gd`
- `scripts/tools/codex_scene_hard_cutover_bench.gd`
- `scripts/tools/product_codex_public_snapshot_cutover_bench.gd`

These six `CODEX_ACTIVE_BENCH` fixtures remain unchanged and reserved for batch B.

## Remaining Domains

The remaining 44 files are inventory only. Fourteen are `CURRENT_GAMEPLAY_ROUTING_MIGRATION_INPUT`: nine card-gameplay fixtures and five action-adopter or cross-domain routing oracles. Twenty-eight are `OTHER_FUTURE_DOMAIN_MIGRATION_INPUT`: AI (3), monster (4), military (1), save/settlement (3), and runtime-characterization or UI-capture fixtures (17). Two files are `HISTORICAL_NEGATIVE_ASSERTION`. No file is currently classified as `RETIRED_FIXTURE_EXPECTED_ABSENT`.

This inventory does not authorize production changes or migration of the remaining 44 files.
