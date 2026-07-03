# Codex Work Orders

Copy these prompts when assigning parallel Codex tasks. Keep owner, allowed files, forbidden files, and verification commands explicit.

## Codex A: PublicTrack / BidBoard / IntelDossier

Owner: Codex A

Allowed primary files:

- `scenes/ui/PublicTrack.tscn`
- `scenes/ui/CardTrack.tscn`
- `scenes/ui/BidBoard.tscn`
- `scripts/ui/card_track.gd`
- `scripts/ui/bid_board.gd`
- `scripts/viewmodels/public_track_snapshot.gd`
- `scripts/viewmodels/bid_board_snapshot.gd`
- IntelDossier evidence-chain files

Forbidden unless explicitly required:

- ScenarioBrowser / ScenarioCoach / ScenarioActionLog / ScenarioReplayPanel
- `scripts/scenarios/*`
- `data/scenarios/*`

Goal pattern:

> Improve anonymous-card track, bid-board feedback, hover/select/open linkage, and evidence-chain readability without exposing hidden owners or private AI/player state.

Required checks:

```powershell
godot --headless --path . --script res://tests/ui_text_smoke_test.gd
godot --headless --path . --script res://tests/visual_snapshot.gd
godot --headless --path . --script res://tests/layout_scene_smoke_test.gd
godot --headless --path . --script res://tests/smoke_test.gd --check-only
```

## Codex B: Playable Scenario Lab

Owner: Codex B

Allowed primary files:

- `scripts/scenarios/*`
- `data/scenarios/*`
- `scenes/ui/Scenario*.tscn`
- `scripts/ui/scenario_*.gd`
- `scripts/viewmodels/scenario_*.gd`
- `tests/scenario_*.gd`

Allowed shared wiring:

- `scripts/main.gd`
- `scripts/ui/game_screen.gd`
- `scripts/viewmodels/table_snapshot.gd`
- `tests/layout_scene_smoke_test.gd`
- `tests/visual_snapshot.gd`
- `tests/ui_snapshot_capture.gd`

Forbidden unless explicitly required:

- `scripts/ui/bid_board.gd`
- `scripts/ui/card_track.gd`
- `scripts/viewmodels/bid_board_snapshot.gd`
- `scripts/viewmodels/public_track_snapshot.gd`
- bid recommendation logic
- AI scoring logic
- economy formula logic
- monster movement/damage formula logic

Goal pattern:

> Build fixed playable scenarios, scenario coach, scenario action log, and lightweight replay fixtures so humans can enter, practice, screenshot, and verify core systems.

Required checks:

```powershell
godot --headless --path . --script res://tests/scenario_smoke_test.gd
godot --headless --path . --script res://tests/scenario_progress_test.gd
godot --headless --path . --script res://tests/scenario_privacy_test.gd
godot --headless --path . --script res://tests/layout_scene_smoke_test.gd
godot --headless --path . --script res://tests/smoke_test.gd --check-only
```

## Human review packet

Every sizeable PR should include:

- owner;
- changed modules;
- touched shared functions;
- screenshots path;
- tests run;
- known blockers;
- three remaining playability risks.

