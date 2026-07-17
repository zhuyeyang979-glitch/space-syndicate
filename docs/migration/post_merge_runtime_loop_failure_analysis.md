# Post-Merge RuntimeLoop Failure Analysis

Date: 2026-07-18

## Verdict

Production `RuntimeLoop` is present once, owns the only engine frame callback, and preserves the merged phase order. The baseline failure was fixture drift, not a production ordering defect.

## Root Cause

`RuntimeWorldPorts` exposes seven getter-only child lookups. `tests/runtime_loop_cutover_test.gd` and `scripts/tools/table_presentation_source_target_bench.gd` assigned through those getters before named child nodes existed. Each inherited getter therefore returned `null`, and the following `.name` assignment failed.

The repair creates, names, and attaches seven typed fake port children first. No production runtime order, Main callback, or fallback was changed. `scripts/tools/runtime_loop_cutover_bench.gd` was also aligned with the current `RuntimePhaseCoordinator` scene: six phase coordinators plus one typed simulation-step child.

## Evidence

- Initial hardened run with `EnsureImported`: failed with 16 script/runtime errors; first error was a `Nil` name assignment in the stale fixture.
- `runtime_loop_cutover_test.gd`: PASS, run `20260717-230558-131-runtime_loop_cutover_test-d578fb60`, script errors 0.
- `RuntimeLoopCutoverBench.tscn`: PASS, run `20260717-230605-671-RuntimeLoopCutoverBench-3f23c93b`, script errors 0.
- The gate proves production presence and uniqueness, one loop/tick owner, typed clock/transition/presentation/pipeline flow, pause/global-block/finished behavior, deterministic order, and no Main fallback.
- `TablePresentationSourceTargetBench.tscn` no longer reports the getter-assignment error, but its bounded scene run timed out after 300 seconds: run `20260717-231912-880-TablePresentationSourceTargetBench-7a3cde99`, script errors 0, remaining runtime process IDs empty. It is recorded as a timeout, not a pass.

This is focused repair evidence only. It is not a full Gate 0 claim.
