# Space Syndicate 1280x720 Production Acceptance

- **Result:** PASS
- **Revision:** `0c25b3a421f06fc66dc8cbad172b70334c916f77`
- **Engine:** `4.7.stable.official.5b4e0cb0f` (headed, blocking, 1280x720)
- **Scene:** `res://scenes/main.tscn`
- **Process:** exit `0`; timeout `False`; clean-stop marker `True`
- **Default save:** metadata + SHA256 unchanged `True`
- **QA profile:** independent override installed before Main entered tree; temporary profile removed `True`

## Runtime Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| First-run core table | PASS | `01_first_run_core_table_1280x720.png` |
| Weather forecast | PASS | `02_weather_forecast_1280x720.png` |
| Weather active-only review frame | PASS | `03_weather_active_1280x720.png` |
| Weather active + forecast dual | PASS | `04_weather_dual_1280x720.png` |
| Economy reopen scroll-to-top | PASS | before `460`; reopened `0` |
| PublicTrack / RightInspector / PlayerBoard complete frames | PASS | `07_card_track_inspector_player_board_1280x720.png` |
| Pixel gate | PASS | `pixel_gate.json` |
| Scene tree | CAPTURED | `scene_tree.json` |

Weather activation used the production transition. For the active-only frame, the already generated next forecast was held for one QA frame and restored unchanged for the dual frame. No city, monster, or route arrays were fabricated; the final card-track frame comes from production `_use_skill(0)`.

## Console Classification

- Errors: `0`
- Warnings: `0`
- Categories: `{}`
- Full evidence: `godot_console.log` and `console_classification.json`

## Failures

- None.

## Evidence Index

Structured runtime facts are in `acceptance_results.json`; renderer/runtime facts in `runtime_environment.json`; independent save fingerprints in `save_integrity.json` and `run_summary.json`. Every PNG records its SHA256 and sampled pixel metrics in `pixel_gate.json`.
