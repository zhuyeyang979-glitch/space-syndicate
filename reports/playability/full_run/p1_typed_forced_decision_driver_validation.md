# P1 FullRun Typed Forced-Decision Driver Validation

Status: `MONSTER_WAGER_DRIVER_DEBT_FIXED_NEXT_BLOCKER_DRIVER_DEBT`

Branch: `codex/p1-fullrun-rack-driver-49445b3`
Parent commit: `0e112ae9a8389a3066b6f04a5f8721c86d5ec01a`

## Frozen production path

The real monster-wager response path is:

```text
MonsterWagerDecisionPanel action_requested(option_id)
  -> OverlayLayer.temporary_decision_action_requested(option_id)
  -> GameScreen._on_temporary_decision_action_requested(option_id)
  -> GameScreen._emit_forced_decision_response(...)
  -> forced_decision_response_requested(ForcedDecisionResponseRequest)
  -> ForcedDecisionResponsePort.submit_response(...)
  -> MonsterWagerResponseSink
  -> MonsterRuntimeController wager owner
```

The FullRun driver previously emitted the outward `GameScreen.action_requested` signal.
That skips the typed request construction in GameScreen, so the authoritative wager window
never received the response.

## Driver-only correction

- Every action read from the viewer-safe `temporary_decision` snapshot is tagged with the
  `temporary_decision` UI origin.
- Submission resolves the existing `SpaceSyndicateOverlayLayer` through
  `GameScreen.get_overlay_host()`.
- The driver emits the real Overlay `temporary_decision_action_requested` signal. GameScreen
  therefore performs the same rendered-decision binding and authorization checks as a human
  click before creating `ForcedDecisionResponseRequest`.
- Capability preflight now fails closed if that production Overlay surface is absent.

No wager formula, 15-second window, cash, commitment, settlement, monster owner, GameScreen,
Main, Coordinator, scene, or gameplay data changed. No QA-only production API was added.

## Fixed-seed evidence

Seed: `900626424` (`seed-index=0`).

### Before

Run: `20260721-220137-973-full_run_quality_driver-50d27cca`

- The driver reached a visible `monster_wager` forced decision.
- Submission stalled at `monster_wager:1:a:6`.
- Failure: `scripted_ui_action_no_progress:monster_wager:1:a:6`.
- Classification: `DRIVER_DEBT`.

### After

Short run: `20260721-220725-610-full_run_quality_driver-a4dc0778`

- Four scripted actions were attempted and all four progressed.
- Invalid actions: `0`.
- The wager window closed through the typed response path.
- The run continued on the live district-supply surface.

Extended diagnostic run: `20260721-220814-563-full_run_quality_driver-5e7db0e6`

- Temporary diagnostic defaults were raised to 45/60 seconds only for this run and restored
  before commit.
- The wager option progressed and the forced-decision window closed.
- Actions attempted/progressed: `4/4`; invalid actions: `0`.
- The next stopping condition was the observation window while the only selected facility
  remained at `market_quote_unavailable`; eight real quote refresh attempts were made.

## Next blocker classification

Classification: `DRIVER_DEBT`.

The current scripted policy keeps one drawer open and waits on one facility listing. It does
not yet close that drawer, rotate to another public district/rack, or distinguish a legitimately
unavailable solar quote from a missing quote response before its observation deadline. The
production surface remains responsive, no typed action was rejected, and no gameplay/runtime
error occurred. This evidence therefore does not establish a `PRODUCT_BUG` or `CONTENT_GAP`.

A separate driver-policy task may use the existing typed drawer close and map district-selection
surfaces to explore another public rack. It must not bypass the solar gate or force a listing.

## Acceptance

- Wager typed response path: PASS.
- New production API: none.
- Production files changed: none.
- Main fallback: none.
- Runtime errors during fixed-seed runs: none.
- `tests/full_run_quality_driver_contract_test.gd`: PASS, `72/72`, exit `0`.
- `tests/main_runtime_composition_test.gd`: PASS, exit `0`.
- `tests/smoke_test.gd --check-only`: PASS, exit `0`.
- Godot 4.7 MCP `validate_script`: driver and contract test both report zero diagnostics.
- Godot 4.7 MCP real `res://scenes/main.tscn`: started and remained live; 186 scripts
  scanned with zero script errors; play mode stopped cleanly and the isolated MCP process was
  released.
- MCP error-log inspection reported only the repository's pre-existing Unicode NUL decoding
  warnings; no gameplay, typed-access, parse, or missing-node error was present.
