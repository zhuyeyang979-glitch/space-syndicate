# Presentation Capture Agent 6

## Status

`BLOCKED_BY_CAPTURE_PREFLIGHT_CREDITS_DATA_MISSING`

The real-scene capture driver and its preflight are implemented. The capture plan is exact at 15 files and supports fixed `1920x1080` and `1366x768` SubViewports. No screenshot was written because the canonical `res://docs/third_party/credits_data.json` owner artifact is not present. Placeholder Credits are explicitly forbidden from authorizing capture.

## Capture Plan

| File | Size |
|---|---:|
| `commercial_art_full_table_1920.png` | 1920x1080 |
| `commercial_art_full_table_1366.png` | 1366x768 |
| `commercial_art_six_color_assets.png` | 1920x1080 |
| `commercial_art_normal_cards.png` | 1920x1080 |
| `commercial_art_commodity_cards.png` | 1920x1080 |
| `commercial_art_bound_actions.png` | 1920x1080 |
| `commercial_art_hand_hover.png` | 1920x1080 |
| `commercial_art_hand_drag.png` | 1920x1080 |
| `commercial_art_planet_day.png` | 1920x1080 |
| `commercial_art_planet_night.png` | 1920x1080 |
| `commercial_art_planet_zoom.png` | 1920x1080 |
| `commercial_art_facilities.png` | 1920x1080 |
| `commercial_art_monsters.png` | 1920x1080 |
| `commercial_art_military.png` | 1920x1080 |
| `commercial_art_credits.png` | 1920x1080 |

Each capture prepares a real state on `CommercialArtIntegrationReview`, waits process/render frames, reads a real SubViewport texture, validates exact dimensions and nonempty pixels, samples luminance variance and color diversity, saves PNG, reloads it, repeats image checks, and records byte size plus SHA-256.

## Preflight Result

- Screenshot plan: `15/15`
- Catalog textual contract: `42/42` stable keys, no missing keys
- Catalog runtime contract: `11/11`
- Canonical Credits sections: `0/4`, source file absent
- Heavy Catalog/model load authorized: `false`
- PNG write authorized: `false`
- Repository screenshots written: `0`
- Placeholder screenshots written: `0`

The early gate runs before loading the 17 model scenes. This replaces the earlier slow path where a known Credits failure was discovered only after loading the populated Catalog.

## Verification

- Godot: `4.7.stable.official.5b4e0cb0f`
- Review script `--check-only`: PASS
- Capture driver `--check-only`: PASS
- Review scene: `54/54`, zero runtime errors after replacing off-tree `look_at()` with `look_at_from_position()`
- Presentation Catalog contract: `11/11`
- `git diff --check`: PASS
- Task-owned Godot processes after testing: `0`

The broader architecture preflight is `286/287`. Its sole failure is a stale Phase-1 characterization that still requires `_draw_table_ring` and translucent ocean alpha; the parallel Planet lane has already retired that old state. Agent6 did not modify that test or any production Planet file.

## Boundary

This lane creates no Session, loads no `main.tscn`, writes no Save, consumes no RNG, changes no gameplay, and connects no production scene. Review and capture code use stable Catalog keys and contain no third-party vendor paths. No Formal run or full Smoke was performed.

Once the canonical Credits owner lands the four nonempty sections and mandatory Game-icons attribution, rerun:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script tests/commercial_art/commercial_art_screenshot_capture.gd -- --commercial-art-output-root=res://docs/art_qa/commercial_art
```
