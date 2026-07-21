# P1 District Purchase Projection / Receipt Alignment Validation

Status: `DISTRICT_PURCHASE_RECEIPT_ALIGNMENT_GREEN_NEXT_BLOCKER_OBSERVATION_WINDOW`

Branch: `codex/p1-district-purchase-receipt-826c3bd`
Base commit: `826c3bd31db41891993fff613e9fed48effb6297`

## Root cause

The authoritative purchase owner was behaving correctly. A human purchase submitted without
a live five-second quote was rejected with the typed reason `locked_quote_required`.

The mismatch was in the presentation/action boundary:

```text
DistrictSupplySnapshotService
  -> buy_enabled = actionable OR can_request_quote
DistrictSupplyDrawer
  -> every enabled activation emitted district_supply_purchase_card
GameScreen
  -> typed purchase intent
DistrictSupplyActionPort
  -> locked_quote_required
```

The same projection mismatch was mirrored by `FullRunQualityDriver`, which treated every
buy-enabled preview as an immediate purchase. This made a valid quote-first listing look like
a blocked purchase product bug.

## Atomic correction

- `DistrictSupplySnapshotService` now projects an explicit allowlisted
  `primary_action_id`: quote when a quote may be requested, purchase only when the quote-backed
  purchase state is truly actionable.
- `DistrictSupplyDrawer` emits only the action projected for that exact visible card. Public
  snapshots and unknown action identities fail closed.
- `FullRunQualityDriver` follows the same visible action identity instead of hard-coding
  purchase.
- No price, quote duration, affordability, hand-limit, solar availability, purchase mutation,
  cash, Coordinator, P0 owner, or gameplay rule changed.
- `scripts/main.gd` was not modified. There was no active Main district purchase fallback to
  delete.

## Production-session receipt proof

`tests/district_supply_purchase_projection_receipt_test.gd` starts the real production session
with fixed seed `900626424` and card `facility.market.technology.rank_1`.

It proves the complete human path:

```text
viewer-private supply projection (quote action)
  -> real DistrictSupplyDrawer activation
  -> GameScreen typed KIND_QUOTE intent
  -> DistrictSupplyActionPort quote_locked receipt
  -> refreshed projection (purchase action)
  -> same Drawer / GameScreen human path
  -> typed KIND_PURCHASE intent
  -> accepted and applied purchase receipt
```

The test also proves one purchase commit, idempotent duplicate-submit replay, and a public
receipt that omits the card identity, quote credential, and private rejection reason.

## Fixed-seed before / after

Before this correction, seed `900626424` stopped at:

```text
scripted_ui_action_no_progress:district_supply_purchase_card
```

It attempted 8 actions, progressed 7, and exposed the target facility as buy-enabled without
first acquiring the required quote.

After this correction, the same seed:

- attempted 34 actions and progressed 33;
- recorded 0 invalid actions and no rejection reason code;
- completed 3 quote refreshes and 1 bounded rack rotation;
- repeatedly crossed visible quote -> purchase states, including the full-hand discard path;
- passed the former district purchase no-progress point;
- stopped only at `observation_window_elapsed_during_action` after the bounded observation
  window expired.

Therefore the next boundary is FullRun observation/runtime strategy, not a district purchase
receipt rejection.

## Acceptance evidence

- Production-session projection/receipt test: PASS, `23/23`.
- Drawer live-refresh/action projection test: PASS, `8/8`.
- Transient gameplay windows test: PASS, `41/41`.
- FullRun driver contract: PASS, `80/80`.
- Existing district supply surface query cutover test: PASS.
- Existing district supply action port cutover test: PASS.
- UI text smoke: PASS.
- Main architecture budget: PASS; external caller files remain `102`.
- `git diff --check`: PASS.
- Godot 4.7 MCP real `res://scenes/main.tscn`: starts and stops without a new parser or runtime
  error. The output contains only repository-baseline warnings, including existing Unicode NUL
  decoding warnings.

## Unrelated baseline debt observed

- `runtime_table_focus_order_test.gd` still has stale focus/component expectations.
- `layout_scene_smoke_test.gd` still fails in an unrelated missing `bind_port` fixture path.

Neither suite was weakened or modified for this correction.

## Scope / ownership guard

- P0 hot files changed: `0`.
- `scripts/main.gd` changes: `0`.
- Rule or price changes: `0`.
- Hidden future-rack reads: `0`.
- Public/private receipt leaks: `0`.
