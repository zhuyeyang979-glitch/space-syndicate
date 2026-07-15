# E 1280 table readability v2 — before

Status: **RED** on `origin/main@fdb62bd2896dd19d01c8660a2a39cd541de2553b`.

## Findings first

1. **Map readability is blocked.** The real production globe produced 371 intersecting sceneized label/token pairs. Of those, 262 pairs covered at least 18% of the smaller card, including 6 district-name-to-district-name collisions. Route lines and boundaries remain present; the failure is label hierarchy/noise, not a missing system.
2. **The core table is fully present.** `TopBar`, `PlayerBoard`, `HandRack`, and `PlayerMainActionDock` are visible and inside the stretched 1706×960 logical canvas rendered to the 1280×720 window. The PNG node-region pixel gate passes. Top-bar copy is still heavily ellipsized at this size and remains a readability finding.
3. **Privacy and capture integrity pass.** Recursive visible text plus tooltip scanning found 0 machine identifiers. The dedicated QA save was removed, the player's default save metadata/SHA-256 remained byte-for-byte equivalent, and the final headed run logged 0 `ERROR`, `SCRIPT ERROR`, or `WARNING` lines.

## Evidence

- [1280×720 production table](before_clear_table_1280x720.png)
- [Scene-tree, overlap, pixel, privacy, and save gate](before_clear_1280x720_scene_tree.json)
- [Final headed console result](before_console.log)

The first Godot invocation on this branch used `tools/invoke_godot_test.ps1 -RefreshImport` with Godot 4.7 and completed the import refresh. Because that runner intentionally adds `--headless`, the final screenshot was captured by the same GUI Godot 4.7 executable in blocking `--windowed --resolution 1280x720` mode on the secondary screen.

