# District Purchase Settlement Contract

## Scope

This document defines the active v0.6 district-purchase transaction for
payment, acquisition, upgrade, hand limit, private discard, quote lifetime and
regional-rack refill. It is not a second rules implementation.

Authoritative references:

- `docs/tabletop_rulebook_v06.md`: a listed non-commodity card is paid for in
  cash when it is obtained.
- `docs/card_play_and_region_supply_policy.md`: merely opening or previewing a
  rack does not reserve supply or create a quote. An explicit purchase intent
  locks the listing, public eligibility and final price for 5 seconds of
  `world_effective` time.
- `docs/region_supply_randomization_v06.md`: every rack slot is owned by the
  deterministic regional supply bag; a successful purchase refills only the
  purchased slot.
- The ordinary hand limit is five. Same-family acquisition upgrades before the
  hand limit is checked; a non-combining sixth card requires one private
  discard before settlement.
- Bankruptcy is checked after the complete atomic event, not during an
  intermediate debit or compensation step.

## Current Owners

| Responsibility | Current owner |
| --- | --- |
| Player-opened browsing session, 5-second quote binding, supply-reselection gate and pending-discard decision state | `DistrictPurchaseRuntimeController` |
| Regional rack slots, deterministic bag/RNG continuation, unique-card state, slot refill revision and exact-once refill journal | Active regional supply/CardFlow owner |
| Viewer-safe Drawer formatting | `DistrictSupplySnapshotService` |
| Market cards, selected preview, focus, close/preview/purchase intents | `DistrictSupplyDrawer` |
| Family/rank policy, hand limit, discardability, fingerprint, and card-slot mutation | `CardInventoryRuntimeService` |
| Purchase planning, exact cash/counter/private-ledger commit, and complete purchase atomicity | `DistrictPurchaseSettlementRuntimeService`, delegating slot mutation to `CardInventoryRuntimeService` on its temporary player copy |
| Card, player, region, supply, price and authorization fact adapter | Scene-owned Coordinator/WorldBridge pure-data adapter |
| Scenario, role-bonus, public feedback, and bankruptcy post-commit forwarding | Existing scene-owned domain hooks |
| Temporary private discard presentation | Existing `temporary_decision` Overlay flow |

`DistrictPurchaseRuntimeController` does not own players, hands, cash, cards,
regional rack contents, the future bag or economy ledgers.
`DistrictSupplySnapshotService` has no settlement authority.
`DistrictPurchaseSettlementRuntimeService` does not own quote timing, rack
refill, presentation Nodes, scenario progression, role-bonus effects or
bankruptcy policy.

## Observed Transaction Order

1. Open the player's single dismissible regional-rack browser. Opening,
   closing, hovering, scrolling and reopening do not advance supply RNG and do
   not create a quote.
2. Preview a current public listing without reservation.
3. On explicit purchase intent, ask the existing quote owner for a
   5-`world_effective`-second quote bound to player, region, slot, card,
   supply revision and public price facts.
4. Ask the regional supply owner to prepare the exact one-slot refill without
   exposing or committing the future bag result to UI or AI.
5. Build a pure-data request and ask
   `DistrictPurchaseSettlementRuntimeService` for a non-mutating plan;
   inventory policy is delegated to `CardInventoryRuntimeService`.
6. Revalidate live access, exact slot membership, quote expiry, locked price,
   player cash, inventory fingerprint, supply revision, refill fingerprint,
   authorization and discard slot immediately before commit.
7. If the same family is held below rank IV, plan an in-place upgrade before
   applying ordinary hand-limit pressure.
8. If a new ordinary card would exceed five cards, register one private
   forced discard decision; do not debit cash, remove the listing, add a card
   or advance the bag.
9. On private confirmation, re-enter the same plan/commit path with the chosen
   discard slot and the still-valid quote/refill binding.
10. Apply inventory mutation, exact debit, counters and private ledger to one
    temporary player copy.
11. Commit the prepared one-slot rack refill exactly once under the same
    transaction lineage. If any owner cannot commit or compensate atomically,
    fail closed before mutating the player or rack.
12. Publish anonymous public feedback and post-commit hooks. Successful
    purchase closes the rack by default; a local continuous-browsing option may
    keep it open without changing supply or quote ownership.

## Commit Invariants

- A successful new-family purchase adds one counted card and debits exactly one locked price.
- A successful duplicate-family purchase upgrades in place, leaves counted hand size unchanged, and debits exactly one price.
- A rank-IV duplicate, insufficient cash, invalid supply, expired authorization, or invalid discard cannot debit cash or increment purchase/spend counters.
- Browsing does not reserve supply. A purchase transaction consumes exactly one
  visible slot and refills exactly that slot; all other slots and their order
  remain unchanged.
- Closing the rack does not extend or cancel a valid quote. Reopening may show
  its remaining `world_effective` lifetime; an expired quote requires a new
  explicit purchase intent.
- A pending discard records a private zero-value status event but no card-spend entry.
- A confirmed discard-and-buy keeps counted hand size unchanged, records one private discard event and one card-spend event, and commits one purchase.
- Cancelling discard clears the private pending context, restores the still-live window, and performs no settlement mutation.
- Queued or cooldown-locked cards are not legal discard candidates.
- Fixed persistent skills may coexist with five ordinary cards and are excluded from ordinary discard choices.
- AI purchases use the same controller authorization and settlement entry point as human purchases.

## Failure And Drift Matrix

| Condition | Expected mutation | Observed Sprint 28 |
| --- | --- | --- |
| Insufficient cash before purchase | None | Aligned |
| Held rank IV family | None | Aligned |
| Hand limit reached | Pending private discard only | Aligned |
| Discard cancelled | None; rack may return to browsing while the quote remains valid | Aligned |
| Invalid discard slot | None; pending context resolves safely | Aligned |
| Cash changes while discard is pending | Revalidation before discard; no old card consumed | Aligned |
| Successful discard confirmation | One replacement, one debit, one purchase/spend commit | Aligned |
| Successful same-family purchase | One in-place upgrade, one debit | Aligned |

The Sprint 28 bench records `observed` separately from `contract_aligned`. A characterization harness may complete even when a future mismatch is found; the report must never present a mismatch as aligned.

## Privacy Boundary

- The buyer's exact cash, ordinary hand count, concrete hand cards, discarded card, locked private channel source, and economic ledger are private.
- Public purchase feedback does not expose buyer name, acquired card name, discarded card, hidden monster owner, or AI plan.
- Characterization output stores only deltas and anonymized family hashes plus ranks. It does not serialize real private hand names.
- QA manifests and reports remain under `user://space_syndicate_design_qa/` and contain only Dictionary, Array, String, Number, and Bool values.

## Active migration gate

The inventory and settlement services are reusable production owners. The
regional rack itself is not accepted until all of the following are true:

- the deterministic supply owner is composed as a real Godot scene;
- current rack slots and future bag state are absent from writable `main.gd`
  district dictionaries;
- human, AI and Coach purchases use the same quote, inventory, cash and
  one-slot-refill transaction path;
- clicking or hovering a listing only previews it;
- a quote is created only by an explicit purchase intent;
- private discard is represented once by the purchase/forced-decision owners,
  not by a second `main.gd` pending record;
- save/load restores rack, bag, quote and pending discard without advancing
  RNG or replaying settlement;
- old fixed-slot, category-stage and direct purchase mutation helpers have no
  production or test caller.

Previous characterization totals remain historical evidence only. They do not
prove the v0.6 random-rack, 5-second quote or one-slot-refill contract.
