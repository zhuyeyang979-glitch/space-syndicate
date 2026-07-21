# P1 FullRun Bounded Rack Exploration Validation

Status: `BOUNDED_RACK_EXPLORATION_GREEN_NEXT_BLOCKER_PRODUCT_BUG`

Branch: `codex/p1-fullrun-rack-driver-49445b3`
Parent commit: `986649f`

## Scope

This atomic driver change handles a visible district rack that remains at
`market_quote_unavailable`. It changes only the FullRun QA driver, its source contract test,
and this evidence report. No production scene, runtime owner, rule, quote, solar, purchase,
cash, Main, or Coordinator path changed.

## Formal player path

The bounded exploration sequence is:

```text
visible DistrictSupplyDrawer debug snapshot
  -> GameScreen.request_district_supply_close(&"qa_driver")
  -> rendered PlanetMapView.district_selected(target_district)
  -> GameScreen typed table-selection intent and receipt
  -> GameScreen.request_district_supply_open(target_district, &"qa_driver")
  -> typed district-supply open intent
  -> newly rendered visible rack
```

The driver does not call a purchase owner, quote owner, market query port, Coordinator, or
Main. It does not inspect a future supply bag or unopened district rack.

## Deterministic bounds and privacy

- A visible rack receives at most three real quote refresh requests before rotation.
- The whole run may rotate at most eight times.
- Each retry is keyed by a SHA-256 signature containing only the selected public district
  index and the visible ordered `(card_name, kind)` rows.
- The local selection revision is retained in the action phase so stale selection progress is
  observable.
- Visited district indices and exhausted visible rack signatures prevent an endless cycle.
- Target districts are selected in stable wraparound order. No unopened-rack availability or
  purchasability query is used.
- When all public districts or the explicit rotation budget are exhausted, the driver exposes
  `district_supply_rotation_exhausted` instead of looping or bypassing a rule gate.

## Fixed-seed result

Seed: `900626424` (`seed-index=0`).

Command-line diagnostic window: 45 observation seconds / 60 maximum wall seconds.

The run:

- refreshed the original visible quote three times;
- closed the original drawer through the typed close request;
- selected another public district through `PlanetMapView.district_selected`;
- reopened that district through the typed rack request;
- rendered a different rack and reached a visible enabled purchase action;
- attempted eight actions, with seven progressing;
- performed one bounded district-rack rotation;
- did not reach final settlement.

The first new blocking action was:

```text
scripted_ui_action_no_progress:district_supply_purchase_card
```

The visible card in the latest diagnostic was
`facility.market.technology.rank_1`. The drawer exposed it as buy-enabled, the driver submitted
the same production purchase signal as a human click, and the resulting player feedback state
was `blocked`. The visible purchase action and rack remained unchanged for the three-second
progress deadline.

Classification: `PRODUCT_BUG`.

This is no longer a driver navigation gap: close, selection, open, quote, wager response, and
purchase all used existing player-facing typed paths. It is not proven to be a content gap,
because the production UI advertised the action as buy-enabled. The next investigation should
capture the typed `DistrictSupplyActionReceipt.reason_code` and reconcile it with the drawer's
`buy_enabled` projection. The driver must not suppress the rejection or force the purchase.

## Acceptance evidence

- `tests/full_run_quality_driver_contract_test.gd`: PASS, `78/78`.
- `tests/main_runtime_composition_test.gd`: PASS.
- `tests/smoke_test.gd --check-only`: PASS, exit `0`.
- Godot 4.7 MCP `validate_script`: driver and contract test have zero diagnostics.
- Godot 4.7 MCP real `res://scenes/main.tscn`: starts normally; 186 scripts scanned with zero
  script errors; play mode and isolated editor stop cleanly.
- The only error-log entries are the repository's existing Unicode NUL decoding warnings.
- Production files changed: `0`.
- Main fallback added: `0`.
- Hidden purchasability or future-rack reads: `0`.
