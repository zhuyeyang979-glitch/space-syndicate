# Alpha 0.4-A authorized Formal FullRun rerun

Updated: 2026-07-29 18:19 (Asia/Tokyo)

## Result

`STATUS=PARTIAL`

The user separately authorized one second Formal FullRun. It was executed once
at head `30a6d87c545df2d8de3c369dec5fb2b3d57a1e92` with the unchanged fixed-seed,
observation, wall-time, gameplay, and driver parameters. No third Formal run was
performed or authorized.

The rerun proved the real matched economy and reached the Victory audit, but it
ended at the bounded observation/wall boundary before `resolved`, final
settlement, presentation, public log, or terminal quiescence. It is therefore
PARTIAL, not GREEN and not BLOCKED.

## Command and execution

```text
godot --headless --path . --script res://scripts/tools/full_run_quality_driver.gd -- --seed-index 0 --observation-seconds 150 --max-wall-seconds 180
```

- seed: `900626424`
- process exit code: `1`
- driver summary valid: true
- status / completed: `incomplete / false`
- failure: `observation_window_elapsed_before_settlement`
- driver wall: `181.437` seconds
- session wall / world: `174.654 / 185.634705` seconds
- script/runtime error count: 0
- system Godot process count before / after: `0 / 0`
- Formal command count after this run: 2
- Formal rerun count after this run: 1

The driver wall includes startup and final summary/cleanup overhead. The public
session snapshot closed at about 174.654 wall seconds with the explicit bounded
observation code, not `driver_wall_timeout`.

## Economy and Victory evidence

- facilities / production installations / peak: `2 / 2 / 2`
- matched commodity rows: 1
- settled matched commodity rows: 1
- matched commodity: `磁核榴莲` / energy
- matched production / demand: `10 / 10` units per minute
- matched settled / transported units: `5 / 5`
- Sale Receipts: 22
- first Sale Receipt world time: `62.391742`
- controlled / required regions: `4 / 3`
- top-k / required GDP per minute: `1612 / 108`
- eligible: true
- post-eligibility production-installation delta: 0
- actions attempted / progressed / invalid: `141 / 140 / 0`
- non-finite public values: 0

The Victory state sequence reached:

```text
idle -> qualification -> audit
```

It did not reach `resolved`. Consequently:

- final settlement count: 0
- final settlement presentation count: 0
- final settlement public-log count: 0
- terminal quiescent frames: 0
- terminal world delta: `-1` (not observed sentinel)
- terminal RNG delta: `-1` (not observed sentinel)

The sentinels do not show drift; the terminal probe never opened.

## Player Card Dock and direct-claim gates

Every new Alpha 0.4-A player-surface gate was green:

- normal card visible: true
- commodity card visible: true
- commodity source art visible: true
- commodity inventory art visible: true
- direct commodity claim succeeded: true
- claim requests / duplicates: `1 / 0`
- visible or hidden claim Buttons: 0
- duplicate card submissions: 0
- Player Card Dock refresh count: 675
- performance samples recorded: true

Recorded p95 values:

- source render: 27.968 ms
- inventory render: 13.836 ms
- hover: 2.913 ms
- single click to intent: 0.250 ms
- receipt to inventory refresh: 70.793 ms

The only action reason was one
`district_supply_retryable_receipt`; it was not invalid. This Formal did not
enter a pending-discard path. SHARED_V06 full-capacity claim/discard behavior
remains independently proven by the focused 20/20 integration test.

## Runtime progression evidence

- authoritative active / attempted steps: `159 / 159`
- authoritative world seconds: 159
- authoritative step average / max wall: `564.377 / 3081` ms
- last progress reason: `victory_timer_audit`
- steps since progress: 0
- progress-budget extension used: false
- progress stall: false
- blocked-realtime invariant failures: 0
- progress checkpoints: 5
- final checkpoint: step 150, world `176.634705`, Sale Receipts 20,
  Victory `audit`

This is not a capability failure, invalid-action failure, non-finite failure,
runtime-step rejection, or progress stall. The run remained actively advancing
the authorized audit timer when the bounded wall window ended.

## Release classification

- `FULL_RUN_REGRESSION=fail`
- `FULL_RUN_TO_SETTLEMENT_GREEN=false`
- `ALPHA_0_4_A_PLAYER_CARD_DOCK=PARTIAL`
- `MERGE_TO_MAIN_ALLOWED=false`
- `DRAFT_PR=true`
- `THIRD_FORMAL_RUN_ALLOWED=false`

Draft PR #72 must remain Draft and must not merge. Further action requires a
new user decision; this task will not silently change the Formal budgets or
execute another run.
