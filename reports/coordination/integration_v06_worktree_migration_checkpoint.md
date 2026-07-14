# v0.6 cloud/worktree migration checkpoint

Date: 2026-07-15

Source branch before checkpoint: `rules/v06-runtime-integration`

Source commit: `c9c1b33841df3f96efe6a5b2a2132ed19e0effce`

Target integration branch: `integration/v06-playable`

## Purpose

This commit preserves the complete shared-worktree v0.6 development state before development moves to isolated Agent A/B/C worktrees. It is a resumable integration checkpoint, not a claim that the full human-playable vertical slice is green.

The current ruleset remains the real-time PVE roguelike hidden-information tabletop design. Do not restore the obsolete 3x3/D6 guardian/direct-monster-control/passive-world-event/manual-settlement/charged-skill model from the old GitHub `main` branch.

## Frozen production evidence included in this checkpoint

- Facility/commodity transaction lifecycle, permanent installations, local baseline demand, exact-once receipts, and fail-closed rollback paths have focused Godot 4.7 coverage.
- Monster first summon, deploy/upgrade ownership boundaries, organization binding, wager settlement, and privacy paths have focused Godot 4.7 coverage.
- Contract and anonymous interaction ownership boundaries have focused coverage.
- Shared card window cadence is `30/20/5/5`, with the opening `45/35/5/5` sequence and Queue-owned sequence `0 -> 1 -> 2` semantics.
- Player organization cards and production composition are sceneized and use authoritative capability bindings.
- Victory audit visibility and final-settlement privacy fail closed unless an authoritative public-audit roster explicitly reveals a seat.
- `FinalSettlementRuntimeComposition` is sceneized exactly once in `main.tscn`. A14 removed 232 nonblank lines and 15 functions from `main.gd`; its focused gate passed 7/7 and Godot MCP bench passed 11/11 with empty debugger/final error lists.
- v3/v0.6 save-envelope primitives exist with isolated `user://test_runs/` coverage; production full-current-run capture/apply composition remains incomplete.
- The human-first-table acceptance skeleton has previously passed its focused 25/25 privacy gate, but integration tests now contain stale calls after final-settlement sceneization.

Detailed evidence and API ownership contracts are under `reports/coordination/` and `docs/`.

## Integration checkpoint test result

An isolated Godot 4.7 checkpoint run attempted:

- `tests/main_runtime_composition_test.gd`
- `tests/layout_scene_smoke_test.gd`
- `tests/human_first_table_playability_v06_test.gd`

All three currently exit non-zero. The observed blockers are integration-oracle debt, not permission to restore retired production code:

1. `main_runtime_composition_test.gd` still expects the previous current-run save version/default-path behavior.
2. `layout_scene_smoke_test.gd` contains stale runtime expectations and exits with leaked test objects/resources.
3. `human_first_table_playability_v06_test.gd` still reflects an obsolete isolated-save-path assertion and calls the retired `_open_final_settlement_menu`; the real owner is now `FinalSettlementRuntimeComposition` / `FinalSettlementBoardPanel`.

The test launcher also failed to create its intended temporary APPDATA root before resolving it. No default player save was intentionally read or written, and no complete default-user smoke test was run.

## Non-negotiable integration invariants

- One owner for each business state and one transaction/journal path.
- AI plans, opponent exact cash/hand/discard, hidden ownership truth, and private route plans never enter player-facing UI.
- Production work must have editable Godot scenes and Godot MCP open/run/debug/stop evidence.
- `main.gd` continues to shrink through scene/API cutovers; do not create compatibility fallbacks for retired paths.
- Tests use isolated APPDATA/LOCALAPPDATA and explicit test save paths.
- Do not merge this checkpoint to `main` until the integration gates and human headed acceptance are green.

## Cloud continuation topology

- Integration: `integration/v06-playable`
- Agent A: `codex/a-main-sceneization`
- Agent B: `codex/b-runtime-owners`
- Agent C: `codex/c-save-runtime`

All three Agent branches start from this exact checkpoint. On another device, clone/fetch from GitHub and create one worktree per branch. Development is intentionally paused immediately after cloud publication.
