# Agent D — Commercial Playability Gate Diagnostics Handoff

Date: 2026-07-16

Scope: acceptance/test infrastructure only. No gameplay, UI, economy, Main,
Coordinator, RegionSupply, CardFlow, or other runtime-owner production behavior was
changed by Agent D.

## Files owned

- `tests/commercial_playability_gate_test.gd`
- `tools/invoke_commercial_playability_gate.ps1`
- `docs/commercial_playability_gate.md`
- `docs/commercial_playability_gate_diagnostics.md`
- this handoff

## Root cause of the reported long no-output run

The old gate combined seven complete `main.tscn` instances in one process without
stage markers or timing. Its focused flag inspected only `OS.get_cmdline_user_args()`,
but the project runner supplied a normal command-line argument, so focused invocations
silently ran the whole suite.

The test also configured no QA run-save path before Main entered the tree. It could
therefore inspect the player's default `user://` state. The revised gate installs a
QA path before `_ready`, while the orchestrator gives every stage a fresh isolated
`APPDATA/LOCALAPPDATA`.

Static inspection found no unbounded gameplay wait in the test: its loops were bounded
to 180, 240, or 480 frames. They were hard to diagnose because they emitted no
heartbeat. The revised waits report every 60 frames.

## False-green and hard-timeout protection

Godot can instantiate an unscripted base `Control` after a root script compile failure.
The previous gate could then abort an awaiting coroutine on a missing method and still
reach a zero-failure finish.

The revised gate and orchestrator require:

- `main.gd` loads and can instantiate;
- `main.tscn` has the real scripted Main API;
- every stage emits a completion marker;
- logs contain no parse/load/`SCRIPT ERROR`;
- every stage and the whole suite have external wall-clock limits.

The dedicated launcher also has no unbounded post-timeout `WaitForExit`: process-tree
kill is followed by at most ten seconds of verified waiting. If termination fails,
the launcher records `terminated_after_timeout=false` and does not block on unfinished
stdout/stderr tasks.

## Stale oracle migrations

- Base table focus now has six regions and does not require a persistent bid panel.
  `transient_gameplay_windows_v06_test.gd` remains the dedicated `public_bid` owner.
- Open-rack focus uses the real FocusGuideLayer plus MapView projection evidence, not
  retired Main `focus_target/stuck_state` snapshot fields.
- CTA-buy recovery reads current public RegionSupply racks, listing availability,
  quotes, slot identity, and production purchase count. It no longer calls
  `_can_buy_card_from_district`.
- Optional summon purchases a current stable v0.6 RegionSupply card before summoning;
  it no longer legitimizes the retired fixed first-table facility shelf.
- Rejected Coach purchases fail immediately instead of entering long downstream waits.

## Evidence

Godot 4.7 MCP scan before the focused rerun:

- checked: 186
- errors: 0

First observable full run:

- 70.433 seconds
- no residual Godot process
- evidence:
  `.codex-godot/commercial-gate-runs/20260716-170447-058-5549b268/summary.json`

Post-migration focused rerun:

- `documentation`: PASS, 0.258 s
- `layout_1280`: PASS, 10.525 s
- `layout_1600`: PASS, 10.532 s
- `layout_1920`: PASS, 10.346 s
- `cta_open_rack`: PASS, 6.007 s
- `optional_summon`: PASS, 7.386 s
- `cta_buy_recovery`: production red/timeboxed at 20.062 s
- evidence:
  `.codex-godot/commercial-gate-runs/20260716-172057-096-e94305e3/summary.json`
- timeout cleanup:
  `terminated_after_timeout=true`
- residual scoped Godot processes: 0

The CTA-buy log proves a current public purchasable listing and a browse-only region
were found. `_activate_first_run_coach_action("coach_buy_card")` returned false before
purchase, refill, or map focus. This is a production quote-sequencing blocker, not a
test exception.

## Deferred final stage

`action_chain` was not rerun after the last oracle migration because it depends on the
same Coach purchase production path. The Coach owner is fixing that path. After its
freeze, the integration coordinator should rerun:

```powershell
pwsh -File tools/invoke_commercial_playability_gate.ps1 `
  -Stage cta_buy_recovery,action_chain `
  -StageTimeoutSeconds 20 `
  -OverallTimeoutSeconds 45
```

Then run the default eight-stage command once. Do not restore the fixed facility shelf,
the retired buyability helper, persistent bid focus, or Main-owned focus fields to make
the gate green.
