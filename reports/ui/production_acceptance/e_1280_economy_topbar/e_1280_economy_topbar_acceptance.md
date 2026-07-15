# E 1280 economy + TopBar acceptance

Status: **GREEN** for the scoped 1280×720 production acceptance on `codex/e-1280-economy-topbar`, based on local integration commit `14836e0f4044b06a1db0821f2f4089cb2556ce3e`.

## Findings first

1. **The economy scroll drift was not reproduced, so production reset behavior was not changed.** The before run recorded `0 → 852/852 → close/reopen → 0`. The final disclosure-aware run opened at `0`, expanded the retained full public detail, forced a real deep scroll to `898/898`, then closed and reopened at `0`. Active and dual-active weather openings also started at `0`.
2. **The 1280 text wall was real and is now demoted to an explicit secondary disclosure.** Before the change, the full public summary pushed `EconomyDashboardPanel` to logical `y=1089.4` and its KPI grid to `y=1134.4`, below the first screen. The final page keeps the complete public text in `MenuBodyLabel`, defaults it to collapsed, and presents the disclosure at `y=324.4`, Dashboard at `y=370.4`, KPI at `y=415.4`, and the end of the decision rail at `y=673.4`, safely inside the scroll viewport ending at `y=873.4`.
3. **TopBar now has a physical-resolution hierarchy without shrinking the whole UI.** At 1280 it retains table state, elapsed time, current seat, cash, GDP, and the complete `目标 Top-N 0/144`. District, next action, and weather move into a visible `更多 3项` chip whose tooltip preserves all three public strings. A 1600×960 probe proves those three chips return and `更多` hides.
4. **No public-data boundary moved.** MenuOverlay only changes presentation of the existing public summary; TopBar only rearranges its existing public payload. `scripts/main.gd`, Coordinator, ViewModel/snapshot services, formulas, owners, save, rules, BidBoard, and ActionResult are unchanged.

## Real production capture matrix

Every row is a GUI Godot 4.7 blocking run of `res://scenes/main.tscn`. Each JSON records physical/logical size, scene-owned node rects, PNG pixel metrics, tooltip-inclusive machine scan, scroll state, save isolation, and the PNG SHA-256.

| Case | Before | Final | Final SHA-256 |
| --- | --- | --- | --- |
| 1280 table idle | [PNG](before_table_idle_1280x720.png) / [JSON](before_table_idle_1280x720_scene_tree.json) | [PNG](after_table_idle_1280x720.png) / [JSON](after_table_idle_1280x720_scene_tree.json) | `cca9e58f37225b825a208c81ea0b6c63b276ed444de77f2fa048c1e1e0013ba6` |
| Economy first open | [PNG](before_economy_first_1280x720.png) / [JSON](before_economy_first_1280x720_scene_tree.json) | [PNG](after_economy_first_1280x720.png) / [JSON](after_economy_first_1280x720_scene_tree.json) | `59c648245e05b66730378d9484d35763a58fa5af3d2da2b14bffc3b856164d2c` |
| Reopen after deep scroll | [PNG](before_economy_reopened_1280x720.png) / [JSON](before_economy_reopened_1280x720_scene_tree.json) | [PNG](after_economy_reopened_1280x720.png) / [JSON](after_economy_reopened_1280x720_scene_tree.json) | `59c648245e05b66730378d9484d35763a58fa5af3d2da2b14bffc3b856164d2c` |
| Economy with one active weather | [PNG](before_economy_active_1280x720.png) / [JSON](before_economy_active_1280x720_scene_tree.json) | [PNG](after_economy_active_1280x720.png) / [JSON](after_economy_active_1280x720_scene_tree.json) | `ad58b3d80fe66110997cedee0c40ae7ed0571dfa43f0220eff905a374c53117c` |
| Economy with dual active weather | [PNG](before_economy_dual_1280x720.png) / [JSON](before_economy_dual_1280x720_scene_tree.json) | [PNG](after_economy_dual_1280x720.png) / [JSON](after_economy_dual_1280x720_scene_tree.json) | `7c6f869623d5c76d40b170d0610adabd92fab420d8bafcad01aa622cf0e5bce8` |

All five final PNGs are exactly 1280×720 with a 1706×960 logical canvas. They were individually inspected at original detail. All final scene/layout and pixel-integrity gates pass, including opaque/non-black frame checks and first-glance rect checks. Active reports one forecast/overlay event; dual-active reports two.

## Privacy, save, console, and clean stop

- Visible Label/Button text and every visible Control tooltip report zero machine identifiers in all five final states.
- QA save override `user://test_runs/e_1280_economy_topbar.save` is installed before Main enters the tree, cleaned before and after, and leaves zero artifacts.
- Player default `user://space_syndicate_current_run.save` metadata/SHA snapshot is identical before and after. It was absent in this role-local run both times, so equality is explicit rather than inferred.
- Final GUI capture: process exit 0, timeout false, `ERROR / SCRIPT ERROR / WARNING = 0`, remaining scoped game/headless processes 0.
- Fresh Godot MCP load sees `MoreChip` and `MenuBodyDisclosureButton` in the real `main.tscn` composition. MCP play-mode runtime root is `/root/Main`; console error/warning lines are 0; play mode and editor both stop cleanly.
- See [console summary](e_1280_economy_topbar_console.log).

## Scoped files and automated gates

Production changes are limited to:

- `scenes/ui/MenuOverlay.tscn`
- `scripts/ui/menu_overlay.gd`
- `scenes/ui/TopBar.tscn`
- `scripts/ui/top_bar.gd`

Focused gates:

- `ui_text_smoke_test.gd`: PASS (`20260715-085539-967-ui_text_smoke_test-952ce60e`)
- `visual_snapshot.gd`: PASS (`20260715-085542-900-visual_snapshot-794f1774`)
- `smoke_test.gd --check-only`: PASS (`20260715-085545-799-smoke_test-3352f5b7`)
- New production capture script and both changed UI scripts: MCP diagnostics 0
- `git diff --check`: PASS
