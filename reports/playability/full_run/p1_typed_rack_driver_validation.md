# P1 FullRun Typed Rack Driver Validation

Status: `DRIVER_DEBT_FIXED_NEXT_BLOCKER_DRIVER_DEBT`

Branch: `codex/p1-fullrun-rack-driver-49445b3`
Base: `49445b3c6cb1f6ab8b9b784483756c34bb9824c8`

## Frozen production path

The real regional-rack action path is:

```text
PlayerBoard action_requested("rack")
  -> GameScreen._on_action_requested("rack")
  -> GameScreen._emit_district_supply_action(open, selected district, ...)
  -> district_supply_action_intent_requested(DistrictSupplyActionIntent)
  -> GameRuntimeCoordinator
  -> DistrictSupplyActionPort.submit_intent(...)
  -> DistrictSupplyPurchaseRuntimeController / presentation receipt
```

`GameScreen.request_district_supply_open(district_index, &"qa_driver")` is the existing
public QA-safe entrypoint for the same typed path. It binds the current viewer/session
identity, submits the district selection through `TableSelectionIntent`, then submits the
rack-open `DistrictSupplyActionIntent`. It does not expose or reproduce purchase rules.

The old FullRun driver emitted `GameScreen.action_requested` from outside the GameScreen.
That signal is the outward, post-routing signal; external emission never executes
`GameScreen._on_action_requested`, so `rack` could not reach `DistrictSupplyActionPort`.

## Driver-only correction

- Rack action IDs are allowlisted in `TYPED_RACK_ACTION_IDS`.
- Those IDs now call the typed public `request_district_supply_open` entrypoint with the
  current public selection and `qa_driver` source surface.
- All other scripted actions keep their existing path.
- Missing typed submission capability now fails immediately with
  `scripted_ui_action_submission_rejected:<action>`, instead of waiting three seconds and
  misreporting a product no-progress failure.
- Fresh-run capability preflight requires the typed rack method.

No production rule, GameScreen, DistrictSupplyActionPort, Main, shared scene, card catalog,
cash, inventory, quote, solar-rotation, or purchase logic changed.

## Fixed-seed evidence

Seed: `900626424` (`seed-index=0`).

### Before

Run: `20260721-215901-397-full_run_quality_driver-7600a2e8`

- Four-seat session started normally.
- Two actions progressed.
- Third action stalled at `rack`.
- Final failure: `scripted_ui_action_no_progress:rack`.
- Classification: `DRIVER_DEBT`.

### After

Run: `20260721-220137-973-full_run_quality_driver-50d27cca`

- Four-seat session started normally.
- `rack` received production feedback `success`.
- The real drawer exposed four public listings.
- The driver selected the visible organization facility listing and exercised the normal
  quote refresh path while it was unavailable.
- The run reached a real `monster_wager` forced-decision window.
- Final failure: `scripted_ui_action_no_progress:monster_wager:1:a:6`.

The next blocker is also classified `DRIVER_DEBT`, not
`ACTIVE_PRODUCT_REGRESSION`: production exposed a live monster-wager decision and option,
but the driver still emits that option through the generic outward GameScreen signal instead
of the typed temporary-decision response path. That separate forced-decision driver migration
is outside this rack-only ownership set. No evidence in this run shows a rack or gameplay
regression.

## Godot 4.7 MCP evidence

Role-local endpoint: `http://127.0.0.1:8782/`
Worktree identity: `space-syndicate-p1-fullrun-49445b3`

- Opened `res://scenes/main.tscn` in the isolated editor.
- MCP script validation: driver diagnostics `0`; contract-test diagnostics `0`.
- Played the real main scene for eight seconds.
- Play state reported active `res://scenes/main.tscn`, time scale `1.0`.
- MCP console error lines: `0`.
- MCP project script errors: `0` across 186 checked scripts.
- Exited play mode, confirmed `is_playing_scene=false`, then closed the isolated editor.
- Port `8782` was closed after shutdown.

## Acceptance classification

- Typed rack driver: **PASS**
- Production files changed: **0**
- Production rules changed: **0**
- Main dependency added: **0**
- Rack failure classification before fix: **DRIVER_DEBT**
- First subsequent failure classification: **DRIVER_DEBT** (monster-wager typed response driver)

## Automated gates

- `tests/full_run_quality_driver_contract_test.gd`: PASS, exit `0`, script errors `0`.
- `tests/main_runtime_composition_test.gd`: PASS, exit `0`, script errors `0`.
- `tests/smoke_test.gd --check-only`: PASS, exit `0`, script errors `0`.
- `git diff --check`: PASS.
