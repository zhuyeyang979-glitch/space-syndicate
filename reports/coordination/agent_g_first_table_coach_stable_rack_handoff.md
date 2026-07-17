# Agent G — First-table Coach stable rack purchase handoff

## Scope

This slice repairs the `first_table` Coach purchase CTA without restoring the
retired fixed facility market or introducing another inventory/purchase owner.
The Coach now consumes only the current public `RegionSupply` rack, while the
existing production purchase entry remains responsible for the transaction.

## Production behavior

- `_first_run_recommended_start_district` prefers an authored district whose
  current market availability is purchasable.
- `_first_run_coach_rack_purchase_target` asks
  `FirstTableAuthoredRuntimeService` to recommend from the current public rack.
- Before use, the recommendation is rebound to the live listing by
  `region_id`, `card_id`, `item_id`, `slot_index`, and `supply_revision`.
- `_first_run_coach_quote_for_target` validates the same live listing, reuses
  an active five-world-second quote when present, or acknowledges the listing
  and requests a new quote.
- `coach_buy_card` calls the existing
  `_buy_card_for_player_from_district` production path. It does not mutate the
  rack directly, inspect the future bag, select a fixed card name, or call the
  retired first-table facility market.
- The rack overlay closes only after a committed purchase. The authoritative
  transaction then emits `card_bought` and refills only the purchased slot.

## Focused evidence

Godot 4.7 isolated focused gate:

```text
res://tests/first_run_coach_purchase_recovery_test.gd
FIRST_RUN_COACH_PURCHASE_RECOVERY_TEST|status=PASS|checks=14|failures=0
duration_seconds=6.084
script_error_count=0
```

The gate verifies:

- authored `first_table` runtime is active;
- Coach selects and opens the current public rack;
- recommendation binds card/item/slot/revision;
- the five-second quote is reused while active;
- one Coach CTA commits exactly one production inventory receipt;
- `card_bought` is emitted;
- the purchased item is replaced only after the transaction commits;
- no deleted eligibility helper or fixed facility-market dependency is used.

Godot 4.7 MCP evidence:

- production project starts successfully;
- `scripts/main.gd` and dependencies compile;
- debug output contains pre-existing warnings only, with no script/runtime
  errors;
- `stop_project` completed and the shared root MCP lease was released.

## Integration note

The current district-purchase session records a rack-level revision while card
quotes bind the listing-level `supply_revision`. Passing an attached
`locked_quote_id` through the current generic purchase entry therefore causes
the session to clear that quote when the revision is re-marked. This slice does
not change that owner contract or B2's full-hand discard work. The Coach first
validates/reuses its five-second quote, then lets the existing purchase entry
reacquire the production quote using the same bound live listing. A later
DistrictPurchase owner task should align rack/listing revision semantics for
all callers.

## Files owned by this slice

- `scripts/main.gd` — narrow first-table Coach recommendation/quote/action
  sections only.
- `tests/first_run_coach_purchase_recovery_test.gd`.
- `reports/coordination/agent_g_first_table_coach_stable_rack_handoff.md`.

No Coordinator, AI, UI layout, inventory, CardFlow, or RegionSupply owner was
modified by Agent G.
