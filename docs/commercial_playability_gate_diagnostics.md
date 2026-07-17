# Commercial Playability Gate Diagnostics

Date: 2026-07-16

Scope: test and tooling diagnostics only. No production gameplay, UI, economy, runtime
owner, Coordinator, or `main.gd` behavior is changed by this work.

## Why the old gate could appear stuck

The old `tests/commercial_playability_gate_test.gd` ran every assertion in one Godot
process and created seven complete `main.tscn` instances. It did not print a stage
start, stage end, wait heartbeat, or elapsed time. A slow scene startup and a stalled
action wait therefore looked identical from the terminal.

The existing focused flag read only `OS.get_cmdline_user_args()`, while the project
runner passed the flag as a regular command-line argument. As a result,
`--first-table-optional-summon-only` could silently run the entire suite instead of the
requested focused case.

The gate also added Main to the tree before configuring a QA save path. That allowed
the test to consult the player's default `user://` run state during initialization.
The diagnostic gate now installs `user://test_runs/commercial_playability_gate.save`
before Main enters the tree, while the orchestrator gives every stage a separate
`APPDATA/LOCALAPPDATA` root.

Static inspection found no unbounded `while` loop, real-time timer wait, or deliberate
minute-scale sleep in the gate. Its waits are frame-bounded:

- local purchase: at most 180 frames;
- scenario signal: at most 180 frames;
- map focus animation: at most 180 frames;
- optional summon drain: at most 240 frames;
- first project resolution: at most 480 frames.

These loops now emit a heartbeat every 60 frames.

## False-green protection

A Godot scene whose root script fails to compile may still instantiate as an unscripted
base `Control`. The previous gate could then abort a coroutine on a missing method,
reach `_finish()`, and report success because no `_expect()` had recorded the engine
error.

The revised gate requires:

1. `res://scripts/main.gd` loads and `can_instantiate()` is true;
2. `main.tscn` has its real script and `_new_game` method;
3. the external orchestrator sees a stage-end marker;
4. the Godot logs contain no `SCRIPT ERROR`, script-load failure, or parse error.

An engine error can no longer be counted as a passing stage merely because Godot exits
with code zero.

## Observable stages

The same assertions are exposed as eight focused stages:

1. `documentation`
2. `layout_1280`
3. `layout_1600`
4. `layout_1920`
5. `cta_open_rack`
6. `cta_buy_recovery`
7. `optional_summon`
8. `action_chain`

Use:

```powershell
pwsh -File tools/invoke_commercial_playability_gate.ps1
```

The default contract is 20 seconds per stage and 90 seconds total. A timeout is a hard
failure; remaining stages are reported as not run after the total budget expires.
Evidence is written below `.codex-godot/commercial-gate-runs/`, which is local QA data
and not player save data.

## Focused-gate split

For day-to-day diagnosis, run the narrowest relevant stage:

- layout regression: the three `layout_*` stages;
- Coach recovery: `cta_open_rack` and `cta_buy_recovery`;
- post-economy starter summon: `optional_summon`;
- first-table progression: `action_chain`.

The unified orchestrator remains the merge gate. Focused stages identify ownership and
speed up iteration; they do not replace the complete assertion set.

## Current evidence boundary

An initial run during concurrent production edits contained parse errors in Main and
UI/runtime dependencies. It is not functional acceptance evidence. It proved that the
old gate could return a false green after a script-load failure.

After the first production freeze, Godot MCP scanned 186 scripts with zero errors. The
new orchestrator then completed in 70.433 seconds, left no Godot process, and reported:

| Stage | Result | Wall time | Finding |
| --- | --- | ---: | --- |
| documentation | PASS | 0.165 s | Rule contract markers present |
| layout_1280 | FAIL | 10.628 s | Stale base-focus oracle still expected persistent bid UI |
| layout_1600 | FAIL | 10.528 s | Same stale bid-focus oracle |
| layout_1920 | FAIL | 10.447 s | Same stale bid-focus oracle |
| cta_open_rack | FAIL | 6.090 s | Real FocusGuideLayer and map rotation passed; duplicate old Main focus fields failed |
| cta_buy_recovery | FAIL | 5.532 s | Test called retired `_can_buy_card_from_district` |
| optional_summon | FAIL | 6.924 s | Test still used the retired fixed first-table facility shelf |
| action_chain | TIMEOUT | 20.044 s | Coach opened the rack; stale bid focus failed, then `coach_buy_card` returned false and the old gate waited blindly |

Evidence:

```text
.codex-godot/commercial-gate-runs/20260716-170447-058-5549b268/summary.json
```

The stale oracles have since been migrated:

- base focus no longer expects a persistent bid surface; the dedicated transient-window
  gate owns `public_bid`;
- CTA focus uses the real FocusGuideLayer plus map projection evidence;
- buy recovery reads current public RegionSupply listings and quote availability;
- optional summon purchases a stable card from the actual RegionSupply rack;
- a rejected Coach purchase ends the stage immediately instead of entering a long
  frame wait.

The `coach_buy_card=false` result remains a production integration finding, not a test
exception. A final post-fix timing table must replace the first-freeze table only after
the production owner freezes again.

## Post-migration focused rerun

After migrating the stale oracles, the seven non-action-chain stages ran in 65.178
seconds:

| Stage | Result | Wall time |
| --- | --- | ---: |
| documentation | PASS | 0.258 s |
| layout_1280 | PASS | 10.525 s |
| layout_1600 | PASS | 10.532 s |
| layout_1920 | PASS | 10.346 s |
| cta_open_rack | PASS | 6.007 s |
| cta_buy_recovery | TIMEOUT / production red | 20.062 s |
| optional_summon | PASS | 7.386 s |

Evidence:

```text
.codex-godot/commercial-gate-runs/20260716-172057-096-e94305e3/summary.json
```

The CTA-buy stage proved that a current public purchasable listing and a browse-only
source region both existed. The production Coach action then returned `false`, so no
purchase, slot refill, or map-focus request occurred. This is the same production
quote-sequencing blocker observed by the Coach owner. The test now exits immediately
at `cta_buy_recovery_rejected` instead of waiting through map-animation frames.

`action_chain` was intentionally not rerun in this focused pass because its first
purchase uses the same production Coach action. It remains assigned to the production
owner and must be rerun after that owner freezes.
