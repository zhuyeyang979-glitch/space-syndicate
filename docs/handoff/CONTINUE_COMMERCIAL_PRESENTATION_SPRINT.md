# Continue Commercial Presentation Sprint

`MASTER_TASK_ID=SPACE_SYNDICATE_ALPHA07_COMMERCIAL_PRESENTATION_AND_ASSET_REGISTRY_SPRINT_V1`

`STATUS=TRUE_HARD_STOP_REQUIRING_USER_DECISION`

`COMMERCIAL_M1_GREEN=false`

`READY_FOR_NEXT_CONSOLIDATED_HUMAN_PLAYTEST=false`

`HUMAN_RETEST_DEFERRED=true`

`HUMAN_GREEN=false`

`FULL_PRODUCT_PRODUCTION_GREEN=false`

`STEP13_STATUS=PENDING`

`STEP14_STATUS=PENDING`

`STEP15_STATUS=PENDING`

`PR93_IS_DRAFT=true`

## Resume location

- Worktree:
  `D:\SpaceSyndicateWorktrees\v076\770d741f\continuous-playable-vertical-slice`
- Branch: `codex/v076-continuous-playable-vertical-slice-770d741f`
- Validated predecessor HEAD: `362d65a1e03550800d68cb95b13f4425ee54e868`
- Validated predecessor tree: `8e828f02305f3745030e37213e78622b4c06b3a2`
- The final report/handoff commit follows that evaluated predecessor; the final
  remote-head Reuse totals must come from the post-handoff rerun.
- The dirty task-owned worktree and all existing local commits must be
  preserved. Do not reset, restore, checkout paths, stash, clean, delete unknown
  files, or rewrite history.

## What is green in scope

- Asset registry: 61 entries (11 internal, 41 production, 20 reference-only),
  35 direct-commercial verified, 9 attribution-required;
  `ASSET_LICENSE_GATE=PASS` and query selftest `PASS`.
- Showcase focused test: `984/984 PASS`, latest run
  `20260826-034634-965-vertical_slice_showcase_test-2b8a02e7`.
- Headed fixture capture: run
  `20260826-030019-680-showcase_frame_capture-db746429`, 13 episodes / 39 PNG,
  1600x960, zero errors, diagnostics, and residual processes.
- Independent visual review: `13/13 PASS`, `39/39` hashes match, fixture banner
  `39/39`, and `VISUAL_REVIEW=PASS_FIXTURE_ONLY`.
- Final Godot MCP showcase run: Godot 4.7, zero hard runtime errors, 155 existing
  warning headers retained, and a clean stop. This direct run has no runner run
  ID.
- Formal Phase 7 performance: `949/949 PASS`, run
  `20260826-014734-735-v076_phase7_sound_motion_performance_gate-4f9136fb`;
  p95 idle 9.442 ms, animation 6.901 ms, card 0.576 ms, menu 25.204 ms,
  stalls 0.
- Version continuity: `105/105 PASS`, `PASS_STATIC`, zero failures.

## Production-main automated Card-table sentinel

- `892/892 PASS`, run
  `20260826-033556-831-v076_alpha07_card_table_flow_readiness_test-5889d5cb`.
- Startup: 2.446 seconds; first AI Action Feed: 3.724 seconds.
- Three authoritative track handoffs, four action windows, second commodity
  exact-once acquisition, and 43 public resolutions are covered.
- Presentation source/queue/start/finish is `102/102/102/102`; the unique
  director drains to zero queued cues with zero collision or rejection.
- Script errors, diagnostics, task-introduced errors, and residual processes are
  all zero.
- Human-playability readiness automation also passes `266/266`, run
  `20260826-034651-563-v076_alpha07_human_playability_readiness_test-ad67a5ed`.
- Canonical receipt:
  `reports/presentation/commercial_m1/automated_card_table_flow_receipt.json`.

These results are automated production-main evidence only. They do not permit
Human Green or resume the consolidated human retest.

The showcase capture p95 includes screenshot I/O and is informational only. Do
not substitute it for the formal Phase 7 performance gate.

## Fixture-only visual acceptance

The headed runner, focused automation, and independent review of every frame
pass in fixture scope. All 13 episodes are accepted and the fixture banner is
present in all 39 frames.

The visible chains include acquire 12→13, shuffle 7+12→19, draw 19→18 and hand
4/5→5/5, a three-card public row, ordered resolution, facility growth, monster
impact, sushi-track movement, and scoring→category reveal→locked Final
Settlement. Military now has the unique `R07` origin and unique `R12` target;
Fleet Alpha follows the physical geodesic, resolves armor 4→2, and withdraws.

Visual blocker counts are all zero: numeric contradiction 0, duplicate identity
0, blocking occlusion 0, and missing required entity change 0. The result is
strictly `PASS_FIXTURE_ONLY`; it must not be rewritten as natural gameplay,
Commercial M1 Green, production green, or Human Green.

## Hard stop

The Reuse/Point-Inertia selftest is `120/120 PASS` with false-green count 0,
but the full validation through committed predecessor
`362d65a1e03550800d68cb95b13f4425ee54e868` is `FAIL` with 565 failures, 509
historical failures, and 62 transitions.

The prior 445/407 classification established a lower bound of at least 22
failures outside the existing append-only correction mechanisms. The current
authority still does not allow a blanket waiver, weakened scan, fabricated
correction, history rewrite, or new governance task. Therefore this task cannot
honestly set Commercial M1 or consolidated human-playtest readiness to green.
The fixture visual and production-main automated lanes are accepted, but the
Reuse hard stop still blocks the milestone.

## Decision required before implementation continues

The user must determine an authorized narrow path for the failures outside the
existing Reuse correction mechanism. No additional presentation repair is
required by this checkpoint.

After an authorized path exists:

1. Resolve only the authorized Reuse/Point-Inertia classifications or mechanism.
2. Rerun the `120/120` selftest and the full committed-HEAD validation.
3. Refresh Asset, Continuity, Showcase, headed capture, MCP, and performance
   evidence only where the
   authorized changes can affect it.
4. Re-audit the milestone and update Draft PR #93 without claiming Human Green.
5. Set `READY_FOR_NEXT_CONSOLIDATED_HUMAN_PLAYTEST=true` only if every required
   milestone gate is green. Steps 13-15 still require a real human run.

## Canonical checkpoint evidence

- `reports/presentation/commercial_m1/report.md`
- `reports/presentation/commercial_m1/visual_review.json`
- `reports/handoffs/commercial_presentation_checkpoint.json`
- `reports/presentation/commercial_m1/showcase_capture_manifest.json`
- `reports/presentation/commercial_m1/capture_runner_report.json`
- `reports/presentation/commercial_m1/asset_registry_report.json`
- `reports/presentation/commercial_m1/performance_report.json`
- `reports/presentation/commercial_m1/automated_card_table_flow_receipt.json`

## Preserved but not committed in this commercial sprint

- Append-only `reports/playtest/**` evidence from the interrupted Candidate 4/5
  human sessions remains in the task-owned worktree and is explicitly excluded
  from these commercial commits.
- Generated `.uid` files and
  `reports/presentation/commercial_m1/runner/**` caches remain untracked and are
  not evidence promoted into the PR.
- None of these files was cleaned, restored, deleted, or rewritten.
