# `main.gd` scene-first migration plan

Status: active architecture authority for the
`codex/scene-first-remove-main-gd` worktree.

Baseline commit: `689c77af4867e2f85fc1edf356e1f7abb295bc7a`.

The existing responsibility inventory remains authoritative. The generated
`main_gd_production_call_graph.json` adds concrete callers, dynamic method
strings, scene connections and `_process` edges; it does not create a second
classification.

## Hard gates

- `tools/architecture/check_main_gd_budget.py` rejects any increase in Main
  lines, methods, fields, constants, preloads or external callers.
- `docs/migration/main_gd_cutover_ledger.json` is updated in every atomic
  domain cutover.
- `RuntimeAuthorityAuditBench.tscn` proves the duplicate owner/tick/signal/
  snapshot/save-writer/mutation detector fails closed.
- No production commit may add a Main wrapper, service locator, dynamic
  fallback or second production path.

## Dependency order

1. Run RNG, table selection state, run world state, topology and authoritative
   clocks.
2. Runtime loop and deterministic controller tick ordering.
3. Typed query/command ports replacing root-bound WorldBridges.
4. Card commitment, execution and world-mutation routing.
5. New-game setup, public role catalog and session-start transaction.
6. v0.6 save-owner restore transaction.
7. Table presentation, stable action routing and menus.
8. Audio, diagnostics and final compatibility-surface deletion.
9. Root composition cutover and physical deletion of `scripts/main.gd`.

## First atomic cutover: complete

The first production cutover is `RunRngService`:

- `RunRngService.tscn` is a real child of `GameRuntimeCoordinator.tscn`;
- the service exclusively owns the gameplay RNG state and deterministic draw
  API;
- AI, monster, weather and product-market bridges receive the typed service
  directly from the composition root;
- Main's `rng` field and `_ai_runtime_rng_gateway` are physically deleted;
- deterministic QA drivers seed the service instead of reading a Main
  property;
- the negative gate proves the old field and gateway are absent and that one
  scene-owned service is composed.

Current Main reduction from the frozen baseline: one top-level field and one
method removed, with no replacement compatibility property.

## Next atomic cutover

The next production cutover is `TableSelectionState`. It is deliberately
smaller than the world arrays:

- remove Main ownership of selected/inspected player, selected district,
  selected product and closely related table-selection values;
- add one scene-owned state node under the existing runtime composition;
- migrate every production reader/writer and active test in the same commit;
- prove the state node is the only writer and no compatibility property remains
  on Main.

This continues the typed owner pattern before moving the much larger `players`
and `districts` graphs.

## Completion rule

A ledger domain becomes `cut_over` only when its Main fields, methods,
constants, preloads, wrappers and dynamic callbacks are physically deleted and
the negative scan reports zero references for that domain. A reference Bench
or a new owner without old-path deletion is not completion.
