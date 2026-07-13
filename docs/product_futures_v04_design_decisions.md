# Product Futures v0.4 Design Decisions

## Status: ADOPTED in Sprint 55

All ten recommendations below are now implemented by the Inspector-editable v0.4 terms catalog. They are retained as decision history, not open questions. The live gate is **76/76 aligned**, and `needs_design_decision=0`.

These decisions are intentionally not active production rules in Sprint 54.

## 1. Purchase cost, action fee, or margin

Options:

- Treat the existing purchase price as the only cost. Simple, but it does not create financial exposure at play time.
- Add a separate refundable margin. Clear financial risk without charging twice for card acquisition.
- Add both a non-refundable action fee and refundable margin. Strong balancing control, but higher cognitive load.

Recommendation: keep purchase price separate and add an explicit refundable `margin_cash` term.

## 2. Margin timing

Options:

- Deduct everything at queue commit.
- Authorize funds at queue commit, then lock margin when the card effect opens.
- Deduct only at expiry.

Recommendation: authorize atomically at queue commit, lock margin when the position opens, and settle or refund it at expiry/destruction. This preserves Queue atomicity while avoiding payment for a card that never opens.

## 3. Maximum gain

Options:

- Fixed value on every card.
- Shared value from a rank table.
- A multiple of margin.

Recommendation: use an explicit per-card `maximum_gain` value. A balance tool may suggest it, but runtime and card copy should read one authored value.

## 4. Maximum loss

Options:

- Loss cannot exceed locked margin.
- Loss may consume additional cash.
- Each card chooses its own liability model.

Recommendation: cap loss at locked margin. It avoids surprise debt, mid-settlement bankruptcy, and hidden liabilities.

## 5. Adverse price movement

Options:

- Continue returning zero.
- Realize a negative settlement capped by maximum loss.
- Lose margin only after a card-authored threshold.

Recommendation: realize a negative settlement capped by `maximum_loss`, otherwise the required loss term has no gameplay effect.

## 6. Warehouse HP snapshot

Options:

- HP immediately before the damaging hit.
- HP immediately after the hit.
- HP captured when the position opens.

Recommendation: the destruction receipt should carry maximum HP, pre-hit HP, and post-hit HP. Settlement should use post-hit remaining HP, while retaining the other two values for audit and presentation.

## 7. Warehouse loss formula

Options:

- Fixed loss from the card.
- Loss proportional only to HP lost in the final hit.
- `maximum_loss * (1 - remaining_hp / maximum_hp)`.

Recommendation: use the third option. It directly uses the card term and remaining HP, and complete destruction produces maximum loss.

## 8. Partial warehouse damage

Options:

- Do not settle until expiry or destruction.
- Settle a fraction after every hit.
- Let each card choose.

Recommendation: do not settle early. Partial damage should update visible risk, while the financial transaction remains atomic at expiry or destruction.

## 9. Insufficient cash for exposure

Options:

- Permit debt.
- Clamp the later loss to available cash.
- Require margin up front.

Recommendation: require margin up front and reject atomically when it cannot be reserved. This also makes maximum liability understandable before play.

## 10. AI financial scoring

Options:

- Score maximum gain only.
- Score gain per margin unit.
- Score risk-adjusted expected value.

Recommendation: use risk-adjusted expected value including capped gain, capped loss, lock duration, current market signal, warehouse risk, and public-clue exposure. AI remains a decision owner, not a settlement owner.

## Required authored fields for Sprint 55

- `margin_cash`
- `maximum_gain`
- `maximum_loss`
- `loss_mode`
- `margin_refund_mode`
- `warehouse_loss_mode` for warehouse cards
- Player-facing terms copy derived from these fields

No sentinel zero or silent infinity should stand in for a missing term.
