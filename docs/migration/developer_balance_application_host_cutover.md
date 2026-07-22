# Developer Balance Application Host Cutover

Status: `PRODUCTION_CUTOVER_GREEN`

Rule authority gate:

- `RULE_AUTHORITY_GATE=GREEN`
- `MECHANIC_ID=developer_diagnostics_host`
- This is developer-only application tooling, not a gameplay mechanic.
- `NEW_OWNER_JUSTIFIED=true`: the owner mounts one optional presentation surface and owns no gameplay, diagnostic report, cadence, or save state.

## Problem

`scripts/main.gd` still decides whether the developer balance panel exists, loads
and mounts the panel, binds it to the presentation target, and requests its first
refresh. Those are application-composition responsibilities and keep the frozen
legacy Main on the developer presentation path.

The diagnostic data path is already scene-owned:

```text
GameplayBalanceDiagnosticsRuntimeService
  -> TablePresentationSourceOwner
  -> TablePresentationRefreshPort
  -> DeveloperBalancePresentationTarget
  -> DeveloperBalancePanel
```

This change adds only the missing application mount owner. It does not create a
second diagnostic source or a second refresh cadence.

## New owner

- Scene: `res://scenes/runtime/presentation/DeveloperBalanceApplicationHost.tscn`
- Script: `res://scripts/presentation/developer_balance_application_host.gd`
- Bench: `res://scenes/tools/DeveloperBalanceApplicationHostBench.tscn`

The Host has two explicit scene paths:

- `panel_parent_path`: the existing `Control` that receives the optional panel;
- `presentation_target_path`: the existing typed
  `DeveloperBalancePresentationTarget` inside `GameRuntimeCoordinator`.

When `SPACE_SYNDICATE_DEV_BALANCE` is not one of `1`, `true`, `yes`, `on`, or
`dev`, the Host creates no UI. When requested, it validates both dependencies
before instantiating anything, mounts exactly one real
`DeveloperBalancePanel`, and binds that panel to the existing typed target.

The independent release-safety gate remains unchanged:

- `DeveloperBalancePresentationTarget` must be in a debug build;
- `SPACE_SYNDICATE_DEVELOPER_PRESENTATION=1` must be set before the typed target
  can consume developer snapshots.

The two environment gates are intentionally not collapsed in this functional
core change.

## Ownership boundary

The Host owns only:

- the optional panel instance;
- one idempotent mount operation;
- one typed target binding;
- bounded, pure-data mount diagnostics.

It does not own:

- gameplay or simulation state;
- balance formulas or diagnostic report construction;
- table refresh cadence or presentation receipts;
- persistence or save schema;
- a Main fallback, callback, or service locator.

## Exact integration request

The functional core intentionally does not edit shared hot files. The
integration writer must apply the request in
`docs/integration_requests/P3-DEVELOPER-DIAGNOSTICS-HOST-CUTOVER.json` as one
cutover:

1. Compose exactly one Host under `Main/RuntimeServices`.
2. Bind its parent path to
   `../../RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer`.
3. Bind its target path to
   `../RuntimeControllerHost/GameRuntimeCoordinator/DeveloperBalancePresentationTarget`.
4. Physically delete Main's panel field, mount-gate method, mount method, and
   `_ready()` call.
5. Do not retain a Main fallback or a second refresh request.

The production integration has now applied that request on the current Main
line. `Main/RuntimeServices/DeveloperBalanceApplicationHost` is the only Host,
it binds the existing `DeveloperBalancePresentationTarget`, and the four old
Main symbols are physically absent. No Coordinator change was required.

The Host must appear in scene order such that its synchronous `_ready()` runs
before `GameRuntimeCoordinator` performs its existing deferred presentation
wiring. The target's `enabled` state then causes the existing scheduler's first
developer cadence receipt to populate the panel; no new cadence is required.

## Focused acceptance

The focused Bench and test cover:

- developer mount disabled;
- real panel mounted exactly once;
- typed target bound exactly once;
- independent target safety gate;
- one typed snapshot applied to the real panel;
- missing parent and missing target fail closed without partial UI;
- Host source contains no Main or service-locator fallback;
- Host diagnostics remain detached pure data.

Production Main composition, architecture, budget, and broad smoke gates remain
the integration writer's responsibility because their hot files are outside
this worktree's lease.

## Production-cutover evidence

- Godot 4.7 isolated tests: Host cutover `32/32` (including Bench `24/24`),
  table-presentation cutover `20/20`, Main architecture `209` checks, Main
  composition PASS, UI text PASS, visual snapshot PASS, and smoke
  `--check-only` PASS.
- Godot MCP: the real Host Bench passed `24/24`; formal `main.tscn` started and
  stopped without a script error or runtime crash. Existing project warnings
  and six pathless Unicode/NUL diagnostics remain and are not reported as a
  clean error console.
- Main budget is monotonic: `6641 -> 6617` physical lines, `5596 -> 5576`
  nonblank lines, `483 -> 481` methods, and `47 -> 46` top-level variables.
  External caller files remain `102`; external occurrences fall to `1231`.
- `layout_scene_smoke_test` remains a known P4 fixture debt: the integration
  branch and clean `1fb5e733` baseline produce the same 62 failures in the same
  order, so P3-only regressions are zero.
- `git diff --check`, ledger JSON parsing, exact-one Host/target composition,
  and negative Main symbol gates pass.

## Functional-core evidence

- Godot version: `4.7.stable.official.5b4e0cb0f`.
- Focused script gate: `DeveloperBalanceApplicationHostBench: PASS 24/24` and
  `Developer balance application-host cutover test passed (32 checks)`.
- Godot MCP scene run:
  `res://scenes/tools/DeveloperBalanceApplicationHostBench.tscn`, `PASS 24/24`.
- MCP debug output contained no new parse/runtime error from this change. The
  project-wide loader continued to report pre-existing warning/NUL diagnostics;
  the project was stopped and the MCP lease released.
- Existing `BalanceRuntimeBridgeBench` completed 49/50 checks. The migrated
  `developer_panel_service_source` case passed; its only failure was the
  unrelated pre-existing `codex_consumers_use_diagnostics_service` oracle that
  still expects retired Main-backed codex diagnostics.
