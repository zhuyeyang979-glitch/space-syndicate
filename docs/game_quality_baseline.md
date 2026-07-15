# Game Quality Baseline

Status: frozen before quality-milestone implementation

Date: 2026-07-15

Authority commit: `fdb62bd2896dd19d01c8660a2a39cd541de2553b` (`origin/main`)

Branch used for capture: `codex/a-v06-local-integration`

Godot: `Godot_v4.7-stable_win64.exe`

## Source identity

- `scripts/main.gd`: 18,972 physical lines and 1,097 `func` declarations.
- The worktree matched `origin/main` before the baseline commands.
- `AGENTS.md`, `README.md`, `docs/next_stage_regression_prompts.md`,
  `docs/weather_system_v1_spec.md`, `docs/weather_v1_test_report.md`, and
  `docs/weather_v1_balance_report.md` were read before testing.
- `docs/decision_log.md` does not exist at this commit. The active rule authority is
  `docs/tabletop_rulebook_v06.md`; the missing decision-log entry is a documentation
  and authority-discovery defect, not an excuse to infer rules from historical tests.
- The lower README migration inventory contains explicitly historical v0.4 behavior.
  It is not an active v0.6 rules source.

All automated runs used `tools/invoke_godot_test.ps1`, the GUI Godot executable,
blocking process waits, repository-external logs, and per-run process cleanup. The
first run used `-RefreshImport` to avoid evaluating stale import/cache state.

## Command results

| Scope | Command target | ExitCode | Timeout | First failure / error | Remaining run processes | Evidence |
|---|---|---:|---|---|---:|---|
| Engine/script check | `res://tests/smoke_test.gd --check-only` | 0 | no | none | 0 | `20260715-070443-476-smoke_test-48722286` |
| Main composition | `res://tests/main_runtime_composition_test.gd` | 0 | no | none | 0 | `20260715-070456-724-main_runtime_composition_test-9d7462b1` |
| Human first table | `res://tests/human_first_table_playability_v06_test.gd` | 4 | no | pending-discard rescue contract; later optional summon uses a retired coach action | 0 | `20260715-070530-285-human_first_table_playability_v06_test-e4efc58a` |
| Save envelope | `res://tests/v06_save_envelope_runtime_test.gd` | 0 | no | none | 0 | `20260715-070541-725-v06_save_envelope_runtime_test-fa1c0c1a` |
| Final settlement composition | `res://tests/final_settlement_runtime_composition_v06_test.gd` | 0 | no | none | 0 | `20260715-070543-832-final_settlement_runtime_composition_v06_test-fa94c1f9` |
| Victory public privacy | `res://tests/victory_control_public_projection_privacy_v06_test.gd` | 0 | no | none | 0 | `20260715-070549-886-victory_control_public_projection_privacy_v06_test-a41aa7ab` |
| Bankruptcy | `res://tests/bankruptcy_neutral_estate_runtime_test.gd` | 0 | no | none | 0 | `20260715-070551-495-bankruptcy_neutral_estate_runtime_test-6dfc2a3a` |
| Card market | `res://tests/card_market_policy_runtime_test.gd` | 0 | no | none | 0 | `20260715-070556-156-card_market_policy_runtime_test-be9d5e42` |
| Weather core | `res://tests/weather_v1_core_test.gd` | 0 | no | none | 0 | `20260715-070606-488-weather_v1_core_test-94b4741a` |
| Monster privacy | `res://tests/monster_runtime_v06_privacy_test.gd` | 0 | no | none | 0 | `20260715-070609-203-monster_runtime_v06_privacy_test-74d020ec` |
| AI facility bootstrap | `res://tests/ai_v06_facility_bootstrap_policy_test.gd` | 0 | no | none | 0 | `20260715-070611-388-ai_v06_facility_bootstrap_policy_test-d1d8d63e` |
| Full layout | `res://tests/layout_scene_smoke_test.gd` | 1 | no (56.604 s) | `split RightInspector binds why/availability`; Military bench parse/type errors follow | 0 | `20260715-070627-064-layout_scene_smoke_test-e9f35c06` |
| Full smoke | `res://tests/smoke_test.gd` | 124 | yes (600.245 s) | role Codex mechanical-benefit assertion; first script error calls retired `_capture_run_state` | 0 | `20260715-070750-921-smoke_test-ad385bfd` |

The evidence folders are under:

`C:\Users\zhuye\AppData\Local\SpaceSyndicate\godot_test_runs`

Focused production result: **10 passing targets, 1 failing target**. The failing target
reported 26 checks and four failures with zero privacy leaks:

1. Two checks preserve a private pending-discard rescue that v0.6 explicitly retired.
2. Two checks invoke missing action `coach_first_summon` instead of the live starter
   card -> card-resolution -> Monster owner route. This is a stale test entry point;
   it does not prove that the Monster owner transaction is broken.

## Full layout classification

The baseline layout run reports 52 assertion failures plus parser/runtime diagnostics.
The first remediation target is test validity, not hiding failures:

- **Old test or contract:** retired Military characterization APIs, old GDP calculation
  API, byte-for-byte Main hashes, retired EconomyCashflow/CityTrade owners, and several
  v0.4/v0.5 component contracts.
- **Current UI/integration contract:** RightInspector state restoration, BidBoard/card
  group behavior, map/game-screen/public-track integration, and active purchase flows.
- **Reported 1280 layout failures:** TopBar, PlayerBoard, HandRack, action dock, and
  several buttons are reported out of bounds. A production capture audit found that
  the old assertion compares a 1706x960 logical canvas directly with a 1280x720
  physical window. These failures remain open until corrected coordinate-space tests
  and real PNG evidence distinguish false positives from product defects.
- **Confirmed visual issue independent of that coordinate bug:** globe overview has
  excessive overlapping route, district, monster, and weather labels.
- **Test infrastructure:** local MCP configuration checks are environment failures and
  must be reported separately from product layout.

No 1280 assertion may be deleted merely because its current coordinate calculation is
wrong. The replacement must retain real visible-rect and PNG integrity checks.

## Full smoke classification

The full smoke did not complete within ten minutes. It produced 94 failure lines and
30 script-error lines before the runner terminated the test and confirmed zero
remaining project processes.

- **First stale contract:** role Codex expects the old presentation/mechanical-benefit
  shape.
- **First retired API call:** `_capture_run_state` on `main.gd`. This wrapper must not
  be restored; each block must move to its authoritative owner or a focused fixture.
- **Observability gap:** the smoke emits no durable phase heartbeat. At timeout the
  exact active decision window or game phase cannot be recovered from the log.
- **Completion gap:** there is no marker for save/reload, final countdown, final audit,
  winner selection, or a completed match. Passing `--check-only` is not a substitute.

## Real-scene visual evidence

Committed GUI Godot 4.7 production-scene evidence already exists at this exact baseline:

- [Minimal production acceptance](../reports/ui/production_acceptance/e_minimal_production_acceptance.md):
  real `main.tscn` at 1280x720, 1600x960, and 1920x1080 for globe, local map, and
  economy views.
- [Weather lifecycle acceptance](../reports/ui/production_acceptance/e_weather_lifecycle/e_weather_lifecycle_acceptance.md):
  forecast, active, fading, and dual-active table/economy frames at 1600x960, with
  scene-tree and PNG integrity gates.

These runs used an isolated QA save path, preserved the default save hash, reported
zero console errors/warnings, and exposed no machine identifiers. They also record
open findings: map crowding, 1280 density/top-bar truncation risk, economy text density,
an intermittent reused economy scroll position, and missing real-city pixel evidence.
The required 3-city/2-monster/2-route/full-countdown/settlement screenshot matrix is not
yet complete.

## Player-quality baseline

| Question | Baseline answer |
|---|---|
| Can a complete match be proven to finish? | **No.** The only full run timed out before any completion marker. |
| Can save, exit, reload, and continue to settlement be proven? | **No.** Owner-level save tests pass; the real Main end-to-end path was not reached. |
| Can final countdown and settlement be proven in the real match? | **No.** Focused composition passes, but full smoke never reached them. |
| Is 1280x720 playable? | **Not yet demonstrated.** Real screenshots exist, but corrected bounds and dense-state interaction evidence are pending. |
| Is first-table progression healthy? | **Partially.** 22/26 checks pass; two rule contracts and the optional summon test entry are stale. |
| Is hidden information protected? | Focused market, victory, monster, and first-table scans pass; full-run privacy remains unverified. |
| Is AI strategically readable? | **Unverified.** Bootstrap policy passes, but no full-run personality/invalid-action statistics exist. |
| Are pacing and balance acceptable? | **Unverified.** Weather simulations are deterministic balance samples, not completed-match telemetry or human fun evidence. |

## Failure inventory by quality category

- **Production code risk:** complete-run progression is unproven; optional summon must
  be exercised through the real route; dense map presentation is confirmed; real
  save-resume-to-settlement has no evidence.
- **Old test or old contract:** pending-discard rescue, role Codex format, retired Main
  snapshots, Military/GDP APIs, and multiple v0.4/v0.5 owner oracles.
- **UI layout:** map overlap is real; reported 1280 bounds require coordinate-corrected
  revalidation; economy scroll restoration remains an intermittent finding.
- **Rules clarity:** the active rulebook is clear, but the README mixes active v0.6
  guidance with a large historical inventory and the requested decision log is absent.
- **Operation feedback:** no common `ActionResult` contract is proven across build,
  buy, play, bid, military, route, contract, and weather actions.
- **AI behavior:** no 20-seed completion/personality evidence and no consolidated
  repeated-invalid-action telemetry.
- **Pacing or balance:** no completed-match timeline, effective-decisions-per-minute,
  forced-wait, lead-gap, or turning-point distribution.
- **Test infrastructure:** monolithic smoke lacks a heartbeat and exceeds ten minutes;
  stale import state required an explicit refresh; full-run screenshot fixtures do not
  yet create every required real entity state.

## Baseline decision

This commit is a failure-preserving baseline, not a quality pass. The next atomic work
must reduce old-contract noise without restoring retired APIs, then expose the next real
production blocker. No milestone may claim completion until 20 deterministic four-seat
runs finish, save-resume reaches settlement, real 1280 interaction is demonstrated,
and the remaining player-facing failures have structured explanations.
