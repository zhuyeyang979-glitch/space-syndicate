# Legacy onboarding purge report

Final status: `LEGACY_ONBOARDING_PURGED_MAIN_GD_REMOVAL_BLOCKED`

Baseline: `fa7ca46`
Branch: `codex/remove-legacy-onboarding-and-main`

## Removed legacy content

- Campaigns: tutorial campaign and skirmish campaign using the retired
  progress/reward schema.
- Authored teaching scenarios: first table, market hand, public track, bid
  practice, monster pressure, intel guess, contract goods and final countdown.
- Production UI: Campaign Menu/Briefing/Progress Map/Reward Panel,
  FirstRunCoach, ScenarioCoach, Scenario Browser/Log/Replay/Pause,
  TutorialQuickStartBoard, onboarding-only MatchRecap, FocusGuide and
  PresentationSettings surfaces.
- Runtime/data: all `scripts/campaign/`, `scripts/scenarios/`, the scenario
  controller, authored first-table service, recommended-start services,
  campaign/scenario JSON and tutorial recommendation/showcase fixtures.
- QA evidence: campaign/scenario/first-mission tests and benches, onboarding
  commercial/readability/skeleton gates, campaign screenshots and the
  first-run production screenshot oracle.

## Removed production state and routes

- Save fields: all first-run seen/focus/route flags; campaign ids, selected and
  active chapters, completed chapters, reward/recap/checkpoint state and
  tutorial/recommended-start progress.
- Menu/deep links: campaign, quick start, first mission, scenario lab/settings,
  campaign settings and all `coach_*` actions.
- No migration, inferred completion, reward conversion or dual-path
  compatibility layer was added.

## Retained current v0.6 components

- `GameScreen`, `PlanetBoard`, `PlayerBoard`, HandRack and PublicTrack: consumed
  by normal tables.
- `MenuRootLobby`, `NewGameSetupPage`, current-run continue/load, rules and
  compendium/codex: consumed by current production navigation.
- `GameRuntimeCoordinator` and domain controllers: consumed by normal card,
  facility, commodity, route, monster, military, weather, bankruptcy and
  victory flows.
- `FinalSettlementRuntimeComposition`: consumed by normal match settlement.
- Card `first_run_art_focus` metadata: retained only because it is illustration
  metadata in the protected art system, with no onboarding runtime consumer.

## `main.gd`

- Before: 17,761 physical / 15,570 nonblank lines, 1,028 methods.
- After purge: 15,488 physical / 13,528 nonblank lines, 916 methods.
- `scripts/main.gd` still exists and `scenes/main.tscn` still references it.
- No replacement root script or copied monolith was created.
- Exact blockers are recorded in
  `docs/migration/main_gd_responsibility_inventory.md`: root-owned world state,
  runtime tick ordering, card execution mutation, dynamic world bridges,
  setup/catalog construction, normal-world save restore, and presentation/
  action routing.

## Verification

- Godot 4.7 headless editor import: PASS.
- `tests/human_normal_table_playability_v06_test.gd`: PASS, 28 checks covering
  normal setup, visible table/hand/map/track, facility purchase and play,
  final settlement, privacy sentinels, and authorized v0.6 save write/read.
- `tests/legacy_onboarding_purge_test.gd`: PASS, 9,691 checks.
- `tests/main_runtime_composition_test.gd`: PASS.
- `tests/player_board_strategy_action_port_test.gd`: PASS, 15 checks.
- `tests/runtime_pointer_input_layer_test.gd`: PASS.
- `tests/rules_quick_reference_snapshot_v06_test.gd`: PASS.
- `tests/ui_text_smoke_test.gd`: PASS.
- `tests/visual_snapshot.gd`: PASS.
- `tests/full_run_quality_driver_contract_test.gd`: PASS, 64 checks.
- `tests/smoke_test.gd --check-only`: PASS.
- Isolated Godot MCP after restart: correct worktree/port, current main scene
  contains RuntimeGameScreen, PlayerBoard and GameRuntimeCoordinator, and
  contains no removed coach/scenario/first-table nodes.
- Full smoke execution: stopped after more than seven minutes with no output;
  no first assertion failure was produced. It was started before the final
  cleanup and is not used as passing evidence.

## Reference counts

- Removed onboarding references in production code/scenes/non-art data: 0.
- Old onboarding menu actions/deep links: 0.
- Old onboarding save fields written by normal sessions: 0.
- `scripts/main.gd` references: 1 live scene/project reference
  (`scenes/main.tscn`); 257 textual references across the full repository,
  including migration documents, tests and characterization tools.

Commit SHA: recorded in the final handoff; omitted here to avoid a
self-referential commit hash.
Push: not performed.
