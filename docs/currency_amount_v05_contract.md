# CurrencyAmount v0.5 Wire Contract

Status: frozen for SS05-01. This contract defines new v0.5 payloads; it does not convert the active v0.4 cash state.

## Unit

- `currency_scale` is always `100`.
- One game currency unit is one hundred integer cents.
- Every v0.5 monetary field ends in `_cents`; floats and implicit scales are invalid.
- Legacy unsuffixed fields such as `cash`, `bid`, `amount`, `available`, `escrow`, `price`, and `cost` are accepted only inside a future versioned v0.4 save migration boundary.
- A payload containing both an unsuffixed legacy field and its `_cents` counterpart fails closed.

## Transaction

Every monetary mutation has a non-empty `transaction_id`, `currency_scale`, source and destination ledger identifiers, pre/post available and escrow balances, and `ledger_delta_cents`. Transaction IDs are idempotency keys and may occur only once in a committed receipt set.

Conservation requires:

```text
available_after_cents + escrow_after_cents
= available_before_cents + escrow_before_cents + ledger_delta_cents
```

Available and escrow remain separate. A public presentation may expose a combined total only when a domain contract explicitly allows it.

## Rounding

Percentage and ratio calculations use integer inputs and round to the nearest cent. Exact half-cent cases round away from zero. Results are clamped to the protocol limits before entering a receipt. Stable transaction/player ordering owns any remainder allocation.

## Runtime boundary

`CurrencyAmountWireV05` validates wire shapes, conservation, exact-once IDs, and fixed-point rounding. It does not own player cash, escrow, pricing, payouts, purchases, or save migration. The active v0.4 runtime continues to use its existing unit until the owning domains hard-cut over.
