# Game Quality Baseline

Status: failure-preserving quality baseline; not a playable-match acceptance

Date: 2026-07-15

Capture commit: `d713b9707d53fd407eb438e83ed90e53a95f4b0f`

Capture branch: `codex/e-1280-first-run-core-path`

Cloud comparison: local `origin/main` was
`fdb62bd2896dd19d01c8660a2a39cd541de2553b` when this baseline was captured. This
document describes the local E worktree HEAD above, not the older cloud pointer.

Godot: `4.7.stable.official`, using
`C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe`

## Source Identity

- `scripts/main.gd`: 18,631 physical lines, 16,339 nonblank lines, and 1,075
  `func` declarations. The earlier baseline draft mislabeled the nonblank count as
  the physical count; the source commit itself is unchanged.
- The worktree already contained unrelated untracked Godot UID files and the prior
  `tests/e_1280_first_run_core_path_capture.gd` before capture. They were preserved
  and are not part of this baseline commit.
- Read before testing: `AGENTS.md`, `README.md`, `docs/decision_log.md`,
  `docs/next_stage_regression_prompts.md`, `docs/weather_system_v1_spec.md`,
  `docs/weather_v1_test_report.md`, and `docs/weather_v1_balance_report.md`.
- Rule authority remains `docs/tabletop_rulebook_v06.md`, followed by
  `docs/rules_v06_runtime_directive.md` and `docs/decision_log.md`. Historical v0.4
  inventory in README and retired smoke/layout assertions do not override v0.6.

All automated runs used `tools/invoke_godot_test.ps1` serially. The runner used the
GUI Godot executable, blocked until the real child exited, wrote logs outside the
repository, returned the real process status, and scoped cleanup to this worktree.
The first run forced a fresh import. Every result reported
`remaining_project_runtime_process_ids=[]`.

Evidence root:

`C:\Users\zhuye\AppData\Local\SpaceSyndicate\godot_test_runs`

## Command Results

| Scope | Command target | ExitCode | Timeout | Duration | First failure / script error | Evidence run |
| --- | --- | ---: | --- | ---: | --- | --- |
| Engine/script check | `smoke_test.gd --check-only` with `-RefreshImport` | 0 | no | 2.600 s test; 17.5 s runner including import | none | `20260715-101431-250-smoke_test-e644aa53` |
| Main composition | `main_runtime_composition_test.gd` | 0 | no | 8.932 s | none | `20260715-101454-942-main_runtime_composition_test-89b05f26` |
| Human first table | `human_first_table_playability_v06_test.gd` | 0 | no | 11.600 s | none | `20260715-101504-461-human_first_table_playability_v06_test-6832618a` |
| Save envelope | `v06_save_envelope_runtime_test.gd` | 0 | no | 0.900 s | none | `20260715-101516-575-v06_save_envelope_runtime_test-658058ee` |
| Final settlement composition | `final_settlement_runtime_composition_v06_test.gd` | 0 | no | 6.617 s | none | `20260715-101517-983-final_settlement_runtime_composition_v06_test-02720eee` |
| Victory public privacy | `victory_control_public_projection_privacy_v06_test.gd` | 0 | no | 0.461 s | none | `20260715-101525-086-victory_control_public_projection_privacy_v06_test-98a9ef58` |
| Bankruptcy | `bankruptcy_neutral_estate_runtime_test.gd` | 0 | no | 5.017 s | none | `20260715-101526-001-bankruptcy_neutral_estate_runtime_test-ae813d30` |
| Public card market | `card_market_policy_runtime_test.gd` | 0 | no | 14.032 s | none | `20260715-101531-519-card_market_policy_runtime_test-2ba90524` |
| Weather core | `weather_v1_core_test.gd` | 0 | no | 2.046 s | none | `20260715-101546-037-weather_v1_core_test-9230d2fe` |
| Monster privacy | `monster_runtime_v06_privacy_test.gd` | 0 | no | 1.108 s | none | `20260715-101548-583-monster_runtime_v06_privacy_test-2080d3cd` |
| AI facility bootstrap | `ai_v06_facility_bootstrap_policy_test.gd` | 0 | no | 1.777 s | none | `20260715-101550-155-ai_v06_facility_bootstrap_policy_test-fbec68b9` |
| Full layout | `layout_scene_smoke_test.gd` | 1 | no | 69.208 s | first failure: `split RightInspector binds why/availability text`; no `SCRIPT ERROR` | `20260715-101601-140-layout_scene_smoke_test-081da46e` |
| Full smoke | `smoke_test.gd` | 124 | yes, 600 s | 600.289 s | first production error: AI bridge cannot route `_set_card_bid_for_player`; first script error returns `Nil` from a `bool` function | `20260715-101733-053-smoke_test-ce1e0eca` |

Focused production result: **10 of 10 targets passed**. This proves the selected owner
contracts in isolation. It does not prove a complete match, save/resume to settlement,
1280 playability, AI quality, or pacing.

## Local Integration Progress After Capture

These results are later local-only progress through integration commit
`6bd1a7c` (`test: migrate card codex smoke formatters`); they do not rewrite the historical
capture table above and have not been pushed to cloud `main`.

- `scripts/main.gd` is now 18,609 physical lines, 16,319 nonblank lines, and
  1,074 functions: net -22 physical lines, -20 nonblank lines, and -1 function
  relative to the captured baseline.
- Weather restore is now the eighth transactional save owner. Run
  `20260715-102325-540-full_run_quality_driver-23cd016e` reports an honest 8
  transactional / 10 unsupported boundary, then exits 3 at capability preflight;
  it still does not claim a playable complete run.
- Full layout run `20260715-102847-268-layout_scene_smoke_test-abba41db`
  completes in 62.849 seconds with ExitCode 1, no timeout, no residual process,
  no parser error, and 13 remaining failures. The corrected production-canvas
  harness removed all nine false 1280 bounds reports, while the Funplay MCP
  contract migration removed three obsolete tooling failures.
- Direct-player-interaction, Monster-wager, and Monster-lure smoke setup no longer
  call retired Main-wide capture/apply wrappers. Other smoke blocks still contain
  54 such references (24 capture / 30 apply) and
  remain migration work; no compatibility wrapper was restored.
- The obsolete AI fixed-priority-bid loop, its dead Main bridge calls, bid-budget
  metadata, and high-bid owner-guess signal were physically removed. The active
  v0.6 queue already orders submissions by rotating seat priority and explicitly
  owns no priority-bid authority. `action_result_v1_test` run
  `20260715-115606-540-action_result_v1_test-4b3e2f3d`, Main composition run
  `20260715-115709-291-main_runtime_composition_test-10d8e6c0`, and smoke
  check-only run `20260715-115723-660-smoke_test-74c2fbe0` all exited 0.
- A new full-smoke run,
  `20260715-115802-450-smoke_test-75dcf446`, timed out after 300.273 seconds
  with runner ExitCode 124 and zero residual process. It contains no missing
  `_set_card_bid_for_player` or typed-`Nil` error. Its last durable marker remains
  the card-resolution smoke; the next lock is an isolated fixture reusing
  `resolution_id=1` after the authoritative execution owner already completed that
  ID. The owner correctly rejects the second execution as `already_completed`.
  Retired Main snapshot and formatter calls occur earlier in the same run and must
  still migrate to current owners.
- After replacing that synthetic auction fixture with an isolated real v0.6 queue,
  full-smoke run `20260715-120738-351-smoke_test-dfa7616c` again timed out at
  300.297 seconds with ExitCode 124 and zero residual process. It passed the new
  `v0.6 card resolution owner smoke` marker and reached later route/Card Codex
  assertions. Its earliest remaining failures are stale AI military command/deploy
  metadata and retired Main snapshot calls. The Card Codex calls to retired
  `_card_detail_tooltip` and `_card_price_tier_text` have since been migrated to
  `CardCodexPublicSourceService` and `RuntimeBalanceModel`; smoke check-only,
  card-presentation public privacy, and runtime-balance focused gates all exit 0.

## Full Layout Findings

The full layout run finished normally with ExitCode 1, 31 listed failures, no script
parse errors, no timeout, and no residual process.

### Current UI or integration failures

- RightInspector does not satisfy the current why/availability binding and hover
  restoration assertions.
- Map selection does not refresh the split top-bar region label under the tested
  runtime path.
- Quick play, hand double-click/drag, PublicTrack selection, dossier linking, and
  market-card double-click do not reach the expected live actions in this fixture.
- TopBar, PlayerBoard, HandRack, MainActionDock, and five visible buttons are reported
  outside 1280x720. Earlier real captures show complete frames, so these must be
  rechecked with a coordinate-correct harness and PNG evidence; they are not dismissed.
- `top_bar.gd`, RightInspectorSnapshot, and CardCodexDetailSnapshot fail active layer
  and presentation contracts.

### Old contract or environment failures

- SharedCardGroupWindow still has a v0.5 six-second/two-second oracle.
- Full-hand private discard rescue is retired by v0.6 and must not be restored.
- Sprint 40 economy/product/route formula-dispatch assertions and the retained AI
  policy registry gate refer to migration-era shapes.
- `.mcp.json` package selection and `project.godot` editor-plugin registration are
  environment/tooling assertions, not player layout behavior.

No assertion should be deleted merely because it is old. Replacement requires a
point-for-point current-owner or real-viewport gate.

## Full Smoke Findings

The full smoke timed out after 600.289 seconds with ExitCode 124. The runner terminated
the scoped Godot child and left zero residual processes. The log contains 87 explicit
`FAIL` lines, 37 `SCRIPT ERROR` lines, 99 total `ERROR` lines, and no warnings.

### First production blocker

`AiRuntimeWorldBridge` cannot route `_set_card_bid_for_player`. The first three calls
occur during AI military-command and military-force checks. The receiving typed method
then returns `Nil` from a `bool` function. During live processing this pair repeats from
`AiRuntimeController._auto_ai_card_decisions` through `GameRuntimeCoordinator.tick_ai`
and `main.gd::_process` until timeout. This is a production AI/runtime integration bug,
not a stale assertion.

### Old-contract noise still present

The smoke continues to call retired Main APIs including `_capture_run_state`,
`_apply_role_market_income_bonus`, `_set_selected_card_priority_bid`,
`_economy_player_cash_line`, `_card_detail_tooltip`, and `_card_price_tier_text`.
These calls must migrate to current owners or focused fixtures. Restoring the deleted
Main wrappers is forbidden.

### Last durable progress

The final progress marker was `SMOKE: 21.43s | card resolution auction smoke`.
Subsequent card-resolution, bid, track, clue, economy, and owner-guess assertions
cascaded after the missing bid route. No durable marker proves that save/reload, final
countdown, final audit, winner selection, or settlement was reached. The monolithic
smoke still lacks enough phase/decision-window heartbeat data to identify a soft lock
without reading a large error stream.

## Existing Real-Scene Evidence

No new headed capture was created for this documentation-only task. Existing committed
production evidence may be inspected, but it is not an exact-HEAD recapture:

- [Three-resolution minimal production acceptance](../reports/ui/production_acceptance/e_minimal_production_acceptance.md)
  covers real `main.tscn` globe, local map, and economy frames at 1280x720, 1600x960,
  and 1920x1080. It reports complete frames and no machine identifiers or console
  errors, while preserving findings for map crowding, top-bar truncation, 1280 density,
  and the economy text wall.
- [Weather lifecycle production acceptance](../reports/ui/production_acceptance/e_weather_lifecycle/e_weather_lifecycle_acceptance.md)
  covers forecast, active, fading, and dual-active at 1600x960 with scene-tree and PNG
  integrity gates. It remains red for actual city-marker occlusion evidence because the
  fixture could not create a real city through the current Coordinator API.

The required dense-state matrix with at least three real cities, two monsters, two
routes, temporary decision UI, final countdown, and settlement has not been completed.

## Player Journey Verification

| Journey | Baseline verdict |
| --- | --- |
| Start a recommended four-seat game | **Partially verified.** Full smoke reaches new-game setup and creates the configured human plus three AI seats. |
| Complete the first-table core actions | **Focused only.** The current human first-table test passes, but no manual 1280 run was completed in this task. |
| Complete an entire match | **Not verified.** Full smoke times out in card-resolution/AI bidding work. |
| Save, exit, reload, and continue | **Not verified end to end.** Save-envelope focused tests pass; real Main continuation was not reached. |
| Trigger final countdown/audit | **Not verified.** Composition tests pass; full smoke provides no countdown marker. |
| Complete settlement | **Not verified.** Focused composition passes; no real match settlement occurred. |
| Play at 1280x720 | **Not accepted.** Existing screenshots are readable but dense, while full layout reports unresolved bounds failures. |
| Explain AI strategy and invalid actions | **Not verified.** AI bootstrap passes, but production bid routing fails and no complete-match telemetry exists. |

## Failure Classification

### Production code bug

- Missing AI world route for `_set_card_bid_for_player` and typed `Nil` return.
- Repeated AI bid errors prevent trustworthy card-resolution progression and may be the
  immediate soft-lock mechanism.
- `CardResolutionExecutionRuntimeService` also reports an `already_completed` active
  resolution during the cascade; it requires focused reproduction after the bid route
  is fixed.

### Old test or old contract

- Remaining `_capture_run_state` and other retired Main helper calls in smoke.
- v0.5 SharedCardGroup timing, private discard rescue, old formula-dispatch, and old
  presentation/source-shape assertions in layout.

### UI layout issue

- Unresolved 1280 bounds reports for the top and bottom table bands.
- Confirmed map label/route/weather/monster crowding and economy text density in the
  existing real screenshots.
- Intermittent economy scroll-position reuse remains reported, not reproduced here.

### Rule clarity

- The active v0.6 section is clear, but README still contains a very large historical
  v0.4 inventory. Readers must follow the authority banner and decision log rather than
  treating that inventory as current play.

### Operation feedback

- RightInspector why/availability restoration fails the full layout contract.
- No baseline evidence proves a single structured ActionResult contract across build,
  buy, play, bid, route, military, contract, and weather actions.

### AI behavior

- Production bid routing is broken under full smoke despite focused facility bootstrap
  passing.
- There is no 20-seed completion, personality-distinction, repeated-invalid-action, or
  hidden-information fairness report.

### Pacing or balance

- The smoke spends ten real minutes without reaching a later durable phase marker.
- No complete-match decision-rate, forced-wait, modal-time, lead-gap, turning-point, or
  winner-distribution data exists.
- Weather balance evidence is deterministic resolver output, not realized match income
  or human fun evidence.

### Test infrastructure

- Monolithic smoke lacks a durable phase and active-decision heartbeat after the card
  auction marker.
- Full layout mixes product assertions, historical contracts, and MCP installation
  checks in one exit result.
- Exact-HEAD real-scene recapture and the required dense-state screenshot matrix remain
  outstanding.

## Baseline Decision

This baseline is **not a quality pass**. The missing AI priority-bid route has been
removed with the retired mechanic rather than restored, and synthetic resolution
fixtures no longer reuse production execution state. The next owner should migrate
the remaining AI military and Main-wide snapshot smoke blocks to focused owners,
without weakening exact-once protection or restoring Main wrappers. A milestone cannot claim
complete-run quality until deterministic matches finish, save/resume reaches settlement,
1280 interaction is demonstrated, and the final report includes AI, pacing, feedback,
privacy, and turning-point evidence.

## Recheck after local owner migrations

On `codex/a-v06-local-integration@15b2148`, Main measures 18,540 lines / 1,071
functions. `smoke_test.gd --check-only` returned ExitCode 0. Focused gates returned
ExitCode 0 for AI facility production, AI facility bootstrap policy, ActionResult v1,
PublicTrack interaction, and FullRunQualityDriver contract. The full smoke runner
returned timeout 124 at 90 seconds; its first new retired production call was
`_refresh_city_networks`. The real quality driver returned ExitCode 4 with the bounded
first-run buy-card action disabled and did not invent a settlement.

These observations supersede the earlier statement that the immediate full-smoke
blocker was the removed `_auto_expand_rival_syndicates`; that call has now been
migrated to the current AI facility owner contract. The remaining red smoke assertions
are still classified individually in the report and are not treated as harmless stale
tests without an owner-equivalent gate.
