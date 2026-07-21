# P1 extended bounded FullRun validation

## Scope

- Branch: `codex/p1-fullrun-extended-evidence-4f7b79d`
- Base: `4f7b79d8e9b4387d672f9dc60f7bdb6130ea0662`
- Fixed seed: `900626424` (`seed-index=0`)
- Runtime: Godot `4.7.stable.official.5b4e0cb0f`
- Production scene: `res://scenes/main.tscn`
- Save isolation: every scripted run used `tools/invoke_godot_test.ps1`, which redirected both `APPDATA` and `LOCALAPPDATA`; MCP used a temporary custom `user://` directory.

The task was bounded to 30, 60 and 120 wall-second observation windows. Observation expiry is an incomplete evidence window, not a product failure.

## Driver corrections

No production rule, cash owner, `Main`, world state, card formula or presentation component changed.

The QA driver now:

1. Treats the public region-supply category `facility` as a facility. `facility_v06` is a private hand-presentation alias, not the canonical rack kind.
2. Selects only a publicly actionable facility listing. A dark-side facility remains viewable but does not cause an invalid quote request.
3. Keeps ordinary typed UI actions at engine time scale `1.0`; only explicit supply/GDP waits accelerate. This preserves the public five-world-second quote window.
4. Observes `DistrictSupplyActionPort.receipt_ready` so a rejection is attributed to its typed reason instead of a generic three-second UI timeout.
5. Treats `source_region_dark`, `locked_quote_changed` and `quote_unavailable` as normal retryable public quote outcomes. They make no gameplay mutation and are recoverable by the same UI flow available to a human.
6. Stops bounded rack exploration as a neutral wait rather than reporting the QA driver's scan limit as a product blocker.

The driver never reads the future supply bag, private cash, opponent hand, hidden owner truth or AI plan.

## Fixed-seed evidence

| Observation | Result | Wall / world elapsed | Attempted / confirmed | Invalid | Non-finite | Rack quote refreshes / rotations | Facilities installed | Settlement |
|---|---|---:|---:|---:|---:|---:|---:|---|
| 30 s | bounded incomplete | 30.389 / 13.880 s | 13 / 13 | 0 | 0 | 3 / 3 | 0 | idle |
| 60 s | bounded incomplete | 66.252 / 23.987 s | 24 / 23 | 0 | 0 | 6 / 4 | 0 | idle |
| 120 s | bounded incomplete | 122.973 / 40.338 s | 32 / 31 | 0 | 0 | 9 / 6 | 0 | idle |

Run directories:

- 30 s: `20260721-232510-311-full_run_quality_driver-48d1a4bb`
- 60 s: `20260721-232558-027-full_run_quality_driver-471d3972`
- 120 s: `20260721-233116-897-full_run_quality_driver-0a0b1f38`

All three summaries ended with `observation_window_elapsed_before_settlement`. Exit code `4` is the driver's documented bounded-incomplete result. The 60 s and 120 s rows each had one accepted retry classification for a volatile quote receipt; neither recorded an invalid action.

## Interpretation

No trustworthy production blocker was reached inside these bounded windows.

The scripted player traversed the real menu/session path, real map selection, the production district drawer, typed quote/purchase receipts, forced monster-wager UI, hand actions and public telemetry. Facility purchase success appeared in the action trace, but the run did not reach an installed-facility GDP chain or final settlement.

This is consistent with the current opening shared-card cadence: the first resolution boundary is approximately 45 world seconds. The longest observation advanced only `40.338` world seconds. Therefore `owned_facility_count=0`, GDP `0`, and settlement `idle` are insufficient-time evidence, not proof of a broken facility or settlement owner.

The next evidence boundary should be a separately authorized run that reaches at least the first complete shared-card resolution boundary and then observes its typed facility-resolution receipt. This report deliberately does not extend the run, change the 30-second cadence, bypass the anonymous queue or directly install a facility.

## Focused validation

- `full_run_facility_acquisition_policy_test.gd`: PASS `12/12`
- `full_run_quality_driver_contract_test.gd`: PASS `89/89`
- `full_run_observation_window_policy_test.gd`: PASS `8/8`
- `district_supply_purchase_projection_receipt_test.gd`: PASS `23/23`
- Godot MCP production `main.tscn`: started and stopped successfully; no script or runtime error. Existing repository warnings and Unicode NUL warnings remain baseline-only.
- `user://`: isolated for every run.
- Production files changed: none.
