# P1 FullRun Observation-Window Admission Validation

Status: `P1_FULLRUN_OBSERVATION_WINDOW_ADMISSION_GREEN`

Branch: `codex/p1-fullrun-observation-window-d62cc20`

Base commit: `d62cc2032924ceb30b217eabe7e27e86e9b70275`

Fixed seed: `900626424`

## First observed stop

The prior 45-second fixed-seed run (`20260721-224123-428-full_run_quality_driver-4ccb06c9`)
reported:

```text
attempted=34
progressed=33
rejected_invalid=0
failure=observation_window_elapsed_during_action
```

The final accepted action was the visible typed action
`district_supply_preview_card` for `unit.monster.oasis_repairer.rank_1`, after the production
discard response had already progressed successfully. The driver was waiting for the next
scene-owned Drawer projection and player-feedback receipt. It allowed only about 21 ms between
that final submission heartbeat and the observation stop.

A separate pre-fix 60-second run
(`20260721-225346-009-full_run_quality_driver-c4fc4fe4`) reproduced the pattern at a later point:

```text
attempted=43
progressed=42
rejected_invalid=0
failure=observation_window_elapsed_during_action
```

Every earlier action had progressed. This showed that increasing the window merely moved the
one-action deficit to a new final action; it did not expose a production action-lifecycle
failure.

## Root cause

The driver checked the observation deadline only after it had:

1. selected the next visible action;
2. submitted that action through the real production UI surface;
3. recorded it as pending.

Under accelerated simulation a coarse frame could already be beyond the observation deadline,
yet still admit one more action. The next frame then cancelled observation before the ordinary
three-second action-progress check could classify the action. This was a harness ordering bug,
not a District Supply or forced-decision owner defect.

## Atomic correction

The observation duration is now an action-admission boundary:

- before the deadline, a visible action may be submitted normally;
- at or after the deadline, no new action may be submitted;
- an action accepted before the deadline may drain only through the existing bounded
  three-second progress check;
- once that action progresses, the driver stops before admitting another action;
- a genuinely stalled action still reports `scripted_ui_action_no_progress:<action>`;
- no timeout, gameplay rule, production controller, or action receipt was changed.

`tests/full_run_observation_window_policy_test.gd` freezes open/drain/closed semantics,
including an exact-deadline case and a coarse-frame overshoot matching the observed run.

## Fixed-seed result after correction

Run: `20260721-225655-790-full_run_quality_driver-1464cede`

```text
observation_seconds=45
attempted=36
progressed=36
rejected_invalid=0
supply_quote_refreshes=3
supply_rack_rotations=1
failure=observation_window_elapsed_before_settlement
```

The run ended with no in-flight scripted action. A normal public `discard_purchase` decision was
visible at the boundary, but the closed observation gate correctly did not submit another input.
No next production blocker was observed inside this bounded run, and settlement was not claimed.

## Acceptance evidence

- Observation policy: PASS, `8/8`.
- FullRun driver contract: PASS, `83/83`.
- Production District Supply quote/purchase receipt: PASS, `23/23`.
- Fixed-seed 45-second run: honest incomplete exit `4`, `36/36` actions progressed, zero invalid.
- Godot 4.7 MCP production `res://scenes/main.tscn`: loaded and stopped without a new parser or
  runtime error. Existing repository warnings and Unicode NUL warnings remain baseline debt.
- Isolated `user://`: all console runs used the repository's isolated test runner; the MCP run
  used a temporary per-worktree custom user directory that was removed after validation.
- `scripts/main.gd`: unchanged.
- P0 cash / `WorldSessionState` / `PlayerCashMutationPort`: unchanged.
- Rule formulas and production gameplay owners: unchanged.

## Scope conclusion

The removed failure was an observation-driver false positive. The production UI and typed
receipt chain remained authoritative and was not bypassed. Longer FullRun work may continue from
the first future exact product blocker; this change does not pretend the match reached final
settlement.
