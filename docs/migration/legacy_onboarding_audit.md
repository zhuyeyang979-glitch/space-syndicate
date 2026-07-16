# Legacy onboarding audit

Status: audit completed against baseline `fa7ca46`; the classified A/B/F
production chain has now been removed.

Authority: `docs/tabletop_rulebook_v06.md` and
`docs/rules_v06_runtime_directive.md`. The campaign, first-run mission and
scenario-coach content below is historical v0.4/v0.5 onboarding and is not
runtime authority for v0.6.

## Classification

| Class | Meaning | Decision |
| --- | --- | --- |
| A | Old onboarding/campaign content | Delete |
| B | Infrastructure whose only production consumer is old onboarding | Delete |
| C | General infrastructure with a current non-tutorial consumer | Keep, disconnect from onboarding |
| D | Current v0.6 normal-game function | Keep |
| E | Historical documentation | Keep only when clearly marked historical/removed |
| F | Legacy-only test, fixture, bench or screenshot oracle | Delete or remove from active gates |

## A — old onboarding/campaign content

- `data/campaigns/tutorial_campaign.json` and
  `data/campaigns/skirmish_campaign.json`: the latter still uses the same
  chapter/progress/reward campaign schema and has no non-tutorial production
  consumer.
- `data/scenarios/*.json`: all eight entries are teaching chapters or tutorial
  exercises (`first_table`, market hand, public track, bid, monster pressure,
  intel, contract goods and final countdown).
- `data/recommendations/tutorial_recommended_set.json`.
- `scenes/ui/FirstRunCoach.tscn`, `ScenarioCoach.tscn`,
  `TutorialQuickStartBoard.tscn`.
- `scenes/ui/CampaignMenu.tscn`, `CampaignBriefing.tscn`,
  `CampaignProgressMap.tscn`, `CampaignRewardPanel.tscn`.
- Campaign-only use of `MatchRecapPanel.tscn`; there is no normal-match
  consumer in the baseline.
- Production routes `campaign`, `quick_start`, `first_mission`,
  `scenario_lab`, `campaign_settings`, campaign deep links and all
  `coach_*` action ids in `scripts/main.gd`.

## B — onboarding-only infrastructure

- `scripts/campaign/*.gd`.
- `scripts/recommendations/recommended_start_service.gd`.
- Campaign UI scripts and campaign viewmodels.
- First-run/scenario coach UI scripts and viewmodels.
- Scenario definition/progress/action-log/fixture runtime, because every
  authored scenario is onboarding content and no current normal match consumes
  its progression state.
- Campaign progress save `user://campaign_progress.save`.
- Campaign settings/progress fields in `scripts/main.gd`.
- First-run seen/route/focus fields in the normal game save dictionary.
- Tutorial one-card group-window branch and monster-wager deferral branch.

## C — retained general components

- `GameScreen`, `PlanetBoard`, `PlayerBoard`, `MapView`: normal-game
  production consumers remain.
- `MenuRootLobby`, `NewGameSetupPage`, menu overlay and save/load controls:
  used by normal new-game, continue and current-match save/load flows.
- `RulesQuickReferenceBoard`, compendium/codex scenes, economy, standings and
  intel pages: used by current v0.6 normal play.
- `FinalSettlementRuntimeComposition`: current normal-match settlement owner.
  It is distinct from the campaign-only reward/recap chain.
- `GameRuntimeCoordinator` and domain controllers: retained, but onboarding
  scenario nodes/services are removed from composition/readiness.

## D — current v0.6 normal-game functions

- New-game setup for 3–8 seats and 2–7 AI.
- Current-run save/load (`space_syndicate_current_run.save`) and v0.6
  transactional save owners.
- Card, commodity, facility, route, monster, military, weather, bankruptcy,
  victory/audit and final-settlement runtime.
- Rules and compendium navigation.

## E — historical documentation

The following documents describe removed behavior and may remain only as
historical migration evidence: `docs/tutorial_campaign_spec.md`,
`docs/campaign_chapter_settings.md`,
`docs/campaign_runtime_path_v2_acceptance.md` and related development-log
entries. They are not production authority and must not be used to retain
runtime code.

## F — legacy-only tests and tools

- All `tests/campaign_*`.
- `tests/first_run_coach_purchase_recovery_test.gd`,
  `tests/first_table_authored_runtime_service_test.gd` and
  `tests/human_first_table_playability_v06_test.gd`.
- Scenario tests whose fixtures are the deleted teaching scenarios.
- Campaign/first-mission screenshot capture and benches.
- Source-level smoke assertions that require campaign buttons, coach nodes,
  tutorial quick-start surfaces or campaign save fields.

## Save-field removal

Delete these normal-run fields and all reads/writes:

- `first_run_coach_district_seen_players`
- `first_run_coach_supply_seen_players`
- `first_run_coach_public_track_seen_players`
- `first_run_coach_ai_public_action_seen_players`
- `first_run_coach_monster_pressure_seen_players`
- `first_run_coach_route_choice_players`
- `first_run_coach_clues_seen_players`
- campaign id/chapter/completion/reward/recap/checkpoint state
- tutorial completion and recommended-start progress

The v0.6 save schema receives no replacement tutorial fields and performs no
campaign-progress migration.

## Post-removal result

- Production menu actions for campaign, quick-start, first mission, scenario
  lab/settings and every coach action are absent.
- Campaign/scenario data, campaign progress/reward/save code, coach scenes,
  tutorial quick-start, recommendation services, authored first-table runtime
  services and their dedicated benches/tests/screenshots are physically
  deleted.
- `GameRuntimeCoordinator` no longer composes or reports scenario/first-table
  onboarding services.
- Normal setup, current-run session services, GameScreen, PlanetBoard,
  PlayerBoard, rules, compendium and final settlement remain.
- The only retained `first_run_art_focus` key is card-illustration metadata. It
  has no menu route, save field, runtime coach or tutorial consumer and is
  outside this migration by the art-preservation constraint.
- Active production scan result: **0 removed onboarding references** in
  `scripts/`, `scenes/`, `addons/`, `project.godot` and non-art `data/`.

Final onboarding verdict:
`LEGACY_ONBOARDING_PURGED_MAIN_GD_REMOVAL_BLOCKED`.
