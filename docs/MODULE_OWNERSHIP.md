# Module Ownership

This file is the coordination contract for parallel Codex work.

## Codex A owns

Codex A is responsible for the anonymous public-card and evidence-chain table objects:

- `scenes/ui/PublicTrack.tscn`
- `scenes/ui/CardTrack.tscn`
- `scenes/ui/BidBoard.tscn`
- `scripts/ui/card_track.gd`
- `scripts/ui/bid_board.gd`
- `scripts/viewmodels/public_track_snapshot.gd`
- `scripts/viewmodels/bid_board_snapshot.gd`
- IntelDossier evidence-chain behavior
- `track_select_*`
- `track_intel_*`
- `bid_*` recommendation and bid interaction logic

Codex B may create fixtures that place these components in useful states, but must not change their core interaction or snapshot semantics.

## Codex B owns

Codex B is responsible for playability entry, tutorialized scenario flow, replay scaffolding, and human-test verification:

- `scripts/scenarios/*`
- `data/scenarios/*`
- `scenes/ui/ScenarioBrowser.tscn`
- `scenes/ui/ScenarioCoach.tscn`
- `scenes/ui/ScenarioActionLog.tscn`
- `scenes/ui/ScenarioReplayPanel.tscn`
- `scripts/ui/scenario_*.gd`
- `scripts/viewmodels/scenario_*.gd`
- `tests/scenario_*.gd`
- scenario screenshots in `tests/ui_snapshot_capture.gd`

## Shared but dangerous files

These files are allowed to be touched only for thin wiring or test registration. PRs must list touched functions and why the edit could not stay inside an owned module.

- `scripts/main.gd`
- `scripts/ui/game_screen.gd`
- `scripts/viewmodels/table_snapshot.gd`
- `tests/layout_scene_smoke_test.gd`
- `tests/visual_snapshot.gd`
- `tests/ui_snapshot_capture.gd`
- `tests/smoke_test.gd`

## Forbidden cross-owner changes

Unless the task explicitly changes ownership:

- Codex B must not modify BidBoard/PublicTrack/CardTrack core behavior.
- Codex B must not alter `track_select`, `track_intel`, or bid recommendation behavior.
- Codex A must not rework ScenarioBrowser/ScenarioCoach/ScenarioActionLog/ScenarioReplayPanel flow.

Both agents must preserve hidden information boundaries: no opponent exact cash, opponent hand, discard choices, AI route plans, pressure buckets, or true anonymous owners in player-facing UI unless explicitly revealed by game rules.

