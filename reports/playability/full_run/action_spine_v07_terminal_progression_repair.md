# Action Spine V0.7 Terminal Progression Repair

```text
STATUS=ACTION_SPINE_V07_TERMINAL_PROGRESSION_REPAIR_PARTIAL

BASE_SHA=02d1719b83ce614b63627245641d3744f6f56c19
RESULT_HEAD_SHA=THIS_REPAIR_COMMIT
BRANCH=codex/action-spine-v07-terminal-progression-repair-02d1719
PULL_REQUEST=none
DRAFT_PR=false
MERGE_TO_MAIN_ALLOWED=false

CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_CONSTITUTION=V0.7
FULL_V0_7_RUNTIME_CUTOVER=false

FAILURE_CLASS=FULL_RUN_DRIVER_ORACLE_STALE

PARENT_360_STEP_RESULT=not_runnable_with_same_driver; second action rejected before authoritative stepping
CURRENT_360_STEP_RESULT=historical 02d baseline exhausted at 360 steps with 3 facilities, 14 Sale Receipts, GDP 32/108, Victory idle
PARENT_CHILD_BEHAVIOR_DELTA=strict pacing parity unavailable; current descendant accepts and progresses the same Driver while parent rejects its session identity

ACTION_SPINE_ARCHITECTURE_READY=true
ACTION_SPINE_BEHAVIOR_PARITY=false
FULL_RUN_DRIVER_ORACLE_CURRENT=true
STEP_BUDGET_POLICY_CURRENT=true

FACILITY_COUNT=3
SALE_RECEIPT_COUNT=5
INVALID_ACTION_COUNT=0
TOP_K_GDP=59
TOP_K_GDP_REQUIRED=108

VICTORY_ENTERED=false
FINAL_SETTLEMENT_COUNT=0
TERMINAL_QUIESCENT_FRAMES=0
TERMINAL_WORLD_DELTA=-1
TERMINAL_RNG_DRAW_DELTA=-1

REPAIR_COMMIT_ALLOWED=true
BRANCH_PUSH_ALLOWED=true
DRAFT_PR_ALLOWED=true
NEXT_MAJOR_TASK_ALLOWED=false

FOCUSED_TESTS=433/433
STAGED_PROGRESS_TESTS=3/7
FULL_RUN_REGRESSION=fail

AI_WORLD_PRODUCTION_MODIFIED=false
NEXT_RECOMMENDED_TASK=ACTION_SPINE_V07_TERMINAL_PROGRESSION_ECONOMY_CONTINUATION
```

`-1` for a terminal delta means “not observed”. The controlled run never
entered Victory, so neither terminal delta may be rewritten as zero.

## Diagnosis

The original failure used a fixed 360-step oracle and stopped legal production
search after a three-installation floor and an initial Sale Receipt. The
resulting economy remained at Top-K GDP `32/108`; the oracle could not
distinguish a still-maturing legal economy from a real stall.

The repaired Driver artifact has SHA-256
`6A2F26270F42E275E50A932421763D164E906DAC7AA8134312D4094164684868`.
Applied to direct parent `5cf30c6`, the second action was rejected with
`game_action_intent_authorization_session_id_invalid`; no authoritative step
ran. Applied to the current descendant, it attempted 147 actions, progressed
138, and recorded zero invalid actions. Strict 360-step pacing parity is
therefore unproved, but the evidence does not identify a current Action Spine
behavior regression.

The primary failure class is `FULL_RUN_DRIVER_ORACLE_STALE`. This classification
does not make the product gate green: the repaired oracle is current, while the
legal facility/rack and economy selection still fails to reach Victory within
the one allowed controlled run.

No V0.7 runtime rule was used to explain a V0.6 pacing result. The active
production runtime is V0.6; V0.7 remains only the highest target development
constitution.

## Repair

The repair changes only the FullRun development Driver, its viewer-safe
snapshot, focused tests, and evidence contracts.

- A progress-aware budget uses a 360-step base, 480-step absolute maximum,
  90-step stall window, 420 world-effective-second hard cap, and 180-second
  wall cap.
- Progress renewal accepts only monotonic public facts: installation, Sale
  revision, GDP and controlled-region high water; first eligibility; forward
  Victory transition; or settlement.
- Duplicate/stale receipts, GDP rollback, navigation, rack rotation, ordinary
  attempts, presentation refreshes, and heartbeats do not renew the lease.
- One accepted one-second authoritative step remains the only accelerated
  unit. There is no batching or copied Victory duration.
- Every 30 authoritative steps emits an allowlisted aggregate checkpoint.
- Each new installation count receives a 30 world-effective-second or two-new-
  Sale maturation window before another legal production action is considered.
- `eligible`, `qualification`, `audit`, and `resolved` lock further scripted
  production growth. `cooldown` may reopen the legal path.
- Terminal acceptance requires zero installations added after Victory lock and
  explicitly exposes terminal world delta.

The repair does not change gameplay values, AI policy, gameplay order,
RuntimeLoop, clock formulas, RunRngService, RNG consumption, Save owners, Save
schema, Victory timers, FinalSettlement ownership, Main, or any retired
compatibility path. It performs no state, GDP, facility, Victory, or settlement
injection.

## Final controlled FullRun

The task's single final FullRun allocation was used by:

```text
RUN_ID=20260728-093544-814-full_run_quality_driver-5752ad04
ARGS=--seed-index 0 --observation-seconds 150 --max-wall-seconds 180
GODOT=4.7.stable.official
RUNNER_TIMED_OUT=false
SCRIPT_ERROR_COUNT=0
REMAINING_RUNTIME_PROCESSES=0
DRIVER_ELAPSED_WALL_SECONDS=150.240
WORLD_EFFECTIVE_SECONDS=176.950079
AUTHORITATIVE_STEPS=150
ACTIONS_ATTEMPTED=147
ACTIONS_PROGRESSED=138
FAILURE_CODE=observation_window_elapsed_before_settlement
```

Viewer-safe checkpoints were:

| Step | World seconds | Facilities | Sale Receipts | Top-K GDP | Victory | Steps since progress |
| ---: | ---: | ---: | ---: | ---: | --- | ---: |
| 30 | 32.486470 | 1 | 0 | 0 | idle | 30 |
| 60 | 62.486470 | 1 | 1 | 24 | idle | 0 |
| 90 | 103.439923 | 3 | 1 | 0 | idle | 15 |
| 120 | 137.054947 | 3 | 4 | 32 | idle | 11 |
| 150 | 174.554947 | 3 | 5 | 59 | idle | 22 |

The run proves three real installations, continuing Sale Receipts, renewed GDP
growth, and zero invalid actions. It does not prove qualification, audit,
FinalSettlement, presentation/log exact-once in this run, or eight quiet
terminal frames. `post_victory_production_installation_delta=0` is not counted
as terminal evidence because Victory was never entered.

Evidence hashes:

```text
result.json=08E9132687BCEEC491503329320B01D1AF5EF1A576892B5C99F69BE469B169D3
stdout.log=F10BFEFB8C2A130E2164E30F97E2BA44051D2F75E3DB59FDD290192B43E18514
stderr.log=7202AC2EFE624BC7149B2AAA3CBA600143B71CA36523DBA04EB798E826DEB21F
godot.log=A8C910D9380968C71F90ED70CD0136E5E9D40B6F0E32FF524D77F94CBA272814
```

## Verification

Focused Driver and Action Spine checks pass `433/433`:

- progress budget `11/11`;
- checkpoint privacy `8/8`;
- facility policy `32/32`;
- Driver contract `186/186`;
- argument transport `13/13`;
- observation-window policy `8/8`;
- authoritative stepper `17/17`;
- GameAction protocol `110/110`;
- Action application flow `48/48`.

Counted regression checks pass `929/929`: CommodityFlow postcommit exact-once
`115/115`, Victory split delta `57/57`, terminal Victory exact-once `81/81`,
FinalSettlement composition `24/24`, Main architecture `219/219`, plus the
focused matrix above. Main runtime composition, UI text, visual snapshot, and
smoke `--check-only` pass as four binary gates.

The full smoke exceeded 180 seconds while traversing existing retired Main and
old monster-signature fixtures. `vs06_facility_commodity_flow_integration_test`
still invokes removed `bind_world` and `_open_new_game_setup_menu` surfaces.
Neither debt was repaired by restoring compatibility code, and neither is
reported as a new production regression or a green full smoke.

Godot MCP identified Godot 4.7, opened the real production `main.tscn`, exposed
zero new script/runtime errors beyond the existing warning/NUL baseline, and
stopped it cleanly.

## Admission decision

PR #68 A13/A14 remains the accepted V0.6 complete-match baseline, but it cannot
substitute for a terminal proof on the `02d1719` Action Spine descendant. This
repair is safe to commit and push to its task branch because it introduces no
authority, privacy, RNG, Save, parsing, or unexplained invalid-action failure.
It may not merge to `main` and may not admit the paused AI World typed-ports
cutover.

The next minimum task must improve legal rack facility acquisition and economic
progress selection so Victory, FinalSettlement exact-once, and eight-frame
quiescence complete inside the same 180-second wall boundary. It may not add
budget, inject GDP, force Victory, skip the 10/120-second lifecycle, call
FinalSettlement, or restore Main action routing.
