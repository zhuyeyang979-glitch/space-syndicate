# E 1280 table readability v2 — after

Status: **GREEN for the scoped production acceptance** on `codex/e-1280-table-readability-v2`, based on `origin/main@fdb62bd2896dd19d01c8660a2a39cd541de2553b`.

## Findings first

1. **The 1280 map-readability blocker is cleared.** The original production capture had 262 hard label/token overlaps and 6 district-to-district collisions. The final 1280 clear/forecast/active/dual-active captures each have 0 hard overlaps and 0 district collisions. Non-selected districts use one-line public names; the selected district keeps full public detail. Route geometry and boundaries remain visible, while the overview replaces dozens of duplicate route cards with one public `商路 ×N` summary. Nearby monster tokens are grouped without losing their public names/counts from the tooltip.
2. **The complete table stays on screen.** `TopBar`, `PlayerBoard`, `HandRack`, and `PlayerMainActionDock` pass the scene-tree rect and PNG node-region gates in all 12 final captures. `RightInspector` remains visible, and the existing compact forecast strip remains non-modal. Top-bar strings are still ellipsized at 1280 and remain a P2 copy-density finding; this block did not expand into Main or top-bar ownership.
3. **Weather is quieter without disappearing.** Forecast/active overlays retain their public phase near the affected region, with the full weather name, phase, and remaining time in the tooltip and the full effects/exploitation/counterplay explanation in the existing detail surfaces. Dual-active shows two distinct map overlays and the public count is 2 at all three resolutions.
4. **The intermittent economy-scroll finding was not reproduced and is not claimed fixed.** The separate 1280 gate recorded `0 → 852 → close/reopen → 0`; `finding_reproduced=false` and `no_fix_claimed=true` are stored in the clear scene-tree JSON. The economic overview remains a dense, long page and is outside this fix.
5. **The repository-wide layout suite remains red for known out-of-scope baseline drift.** It reports stale owner/Main/MCP expectations plus an unrelated Military bench parse failure. Focused UI text, visual snapshot, smoke `--check-only`, MCP compile/runtime, and all production captures pass. No owner/rule/Main compatibility layer was restored.

## Before / after

| Gate | Before 1280 | Final 1280 clear | Final 1280 dual-active |
| --- | ---: | ---: | ---: |
| Core table | PASS | PASS | PASS |
| Hard map overlaps | 262 | 0 | 0 |
| District collisions | 6 | 0 | 0 |
| Route label cards | 44 | 1 | 1 |
| Route segments retained in captured run | 28 | 20 | 20 |
| Machine identifiers, including tooltips | 0 | 0 | 0 |
| Default save metadata/SHA unchanged | yes | yes | yes |
| QA save artifacts after cleanup | 0 | 0 | 0 |
| Headed console ERROR / SCRIPT ERROR / WARNING | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |

- [Before 1280 production table](before_clear_table_1280x720.png) / [before scene-tree gate](before_clear_1280x720_scene_tree.json)
- [Final 1280 clear table](after_clear_table_1280x720.png) / [final clear gate](after_clear_1280x720_scene_tree.json)
- [Final 1280 dual-active table](after_dual_active_table_1280x720.png) / [final dual-active gate](after_dual_active_1280x720_scene_tree.json)

The final dual-active 1280 PNG SHA-256 is `1af09b87629cb9fe4e156a870bcd0142c8645a7607f7f6b407bc6b3746cd5d02`, identical to the SHA stored in its JSON. Codex A independently reopened that exact PNG at original detail and confirmed the frame is complete.

## Final production matrix

Every cell is a real `res://scenes/main.tscn` GUI Godot 4.7 blocking capture. Each JSON contains the scene tree, stable-frame snapshot, pixel metrics, public weather phase/count, tooltip-inclusive machine scan, QA cleanup, and default-save comparison.

| Resolution | clear | forecast | active | dual-active |
| --- | --- | --- | --- | --- |
| 1280×720 | [PNG](after_clear_table_1280x720.png) / [JSON](after_clear_1280x720_scene_tree.json) | [PNG](after_forecast_table_1280x720.png) / [JSON](after_forecast_1280x720_scene_tree.json) | [PNG](after_active_table_1280x720.png) / [JSON](after_active_1280x720_scene_tree.json) | [PNG](after_dual_active_table_1280x720.png) / [JSON](after_dual_active_1280x720_scene_tree.json) |
| 1600×960 | [PNG](after_clear_table_1600x960.png) / [JSON](after_clear_1600x960_scene_tree.json) | [PNG](after_forecast_table_1600x960.png) / [JSON](after_forecast_1600x960_scene_tree.json) | [PNG](after_active_table_1600x960.png) / [JSON](after_active_1600x960_scene_tree.json) | [PNG](after_dual_active_table_1600x960.png) / [JSON](after_dual_active_1600x960_scene_tree.json) |
| 1920×1080 | [PNG](after_clear_table_1920x1080.png) / [JSON](after_clear_1920x1080_scene_tree.json) | [PNG](after_forecast_table_1920x1080.png) / [JSON](after_forecast_1920x1080_scene_tree.json) | [PNG](after_active_table_1920x1080.png) / [JSON](after_active_1920x1080_scene_tree.json) | [PNG](after_dual_active_table_1920x1080.png) / [JSON](after_dual_active_1920x1080_scene_tree.json) |

All 12 cells pass core table, map readability, pixel integrity, stable frame, expected weather state, machine-ID count 0, default-save equality, and QA cleanup count 0. The final headed matrix has 0 `ERROR`, 0 `SCRIPT ERROR`, and 0 `WARNING`; see [after_console.log](after_console.log).

## Scope and validation

- Production changes are limited to `scripts/ui/planet_map_view.gd`, `scripts/ui/map/*` presentation components, and `scripts/ui/weather/weather_map_overlay.gd`.
- `scripts/main.gd`, Coordinators, economy/AI/monster/weather rules, save ownership, and private data are unchanged.
- MCP opened and ran `res://scenes/ui/PlanetMapView.tscn`; MCP error log count was 0, play mode stopped cleanly, and the isolated E editor/port then closed normally.
- `ui_text_smoke_test.gd`, `visual_snapshot.gd`, and `smoke_test.gd --check-only` pass. The capture script and all 117 `scripts/ui` files passed MCP GDScript validation.
