# Compendium Navigation Fixture Migration

Batch A migrates five active formal Compendium tests from retired Main setup and pause helpers to existing scene-owned production boundaries.

## Boundaries

- Sessions start through `ProductionSessionStartDriver` and `SessionStartTransactionCoordinator`.
- Every formal session asserts an applied receipt, the expected player count, a running `GameSessionRuntimeController`, zero Main start calls, zero setup fallback calls, and one terminal transaction.
- Pausing uses `GameSessionRuntimeController.pause_session()`.
- Top-level Compendium opening uses `ApplicationFlowPort.submit_action("compendium")` exactly once per intentional open.
- Role definitions come from `RoleCatalogRuntimeService`; Product Codex retains a standalone unconfigured fail-closed subcase.
- Returned scene roots are freed and QA save plus `.tmp` artifacts are removed on success and failure paths.

## Preserved Coverage

The navigation fixture retains all domain navigation, monster-to-card deep links, back-stack, return targets, pure-data, zero-mutation, invalid-request, exact-once, and Main-negative checks. Bestiary keeps real GUI input and node-identity checks. Semantics keeps nine public pages, recursive privacy, retired-term, and runtime-object rejection checks. Product and Role fixtures retain their owner, parity, privacy, and read-only contracts.

## Scope

```text
production_files_modified=0
production_scenes_modified=0
driver_contract_changed=false
main_wrapper_restore_count=0
fixture_count=5
```

The six Codex benches and the remaining 44 classified fixtures are not modified in this batch.
