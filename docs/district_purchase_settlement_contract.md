# District Purchase Settlement Contract

## Scope

This document records the characterized `v0.4` district-purchase transaction and the completed Sprint 29 cutover from `main.gd` into one scene-owned runtime service. It is the compatibility contract for payment, acquisition, upgrade, hand-limit, discard, and private-ledger behavior; it is not a second rules implementation.

Authoritative references:

- Rulebook v0.4 section 9: a district purchase price is paid in cash when a card is obtained.
- Rulebook v0.4 section 11: qualification and private channel pricing lock for 12 seconds; opening a window does not reserve supply.
- Rulebook v0.4 section 11: ordinary hand limit is five cards; duplicate families upgrade before the limit is checked; rank IV rejects another copy unless explicitly allowed.
- Rulebook v0.4 section 11: a non-combining sixth card requires one private discard before payment; cancelling the discard cancels the purchase; fixed persistent skills do not count toward the ordinary limit.
- Rulebook v0.4 section 21: bankruptcy is checked after the complete atomic event, not during an intermediate debit or refund step.

## Current Owners

| Responsibility | Current owner |
| --- | --- |
| 12-second qualification, locked access, locked price context, supply-reselection gate, pending-discard window state | `DistrictPurchaseRuntimeController` |
| Viewer-safe Drawer formatting | `DistrictSupplySnapshotService` |
| Market cards, selected preview, focus, close/preview/purchase intents | `DistrictSupplyDrawer` |
| Family/rank policy, hand limit, discardability, fingerprint, and card-slot mutation | `CardInventoryRuntimeService` |
| Purchase planning, exact cash/counter/private-ledger commit, and complete purchase atomicity | `DistrictPurchaseSettlementRuntimeService`, delegating slot mutation to `CardInventoryRuntimeService` on its temporary player copy |
| Card, player, district, supply, price, and authorization fact adapter | Thin `main.gd` `_buy_card_for_player_from_district()` compatibility entry |
| Scenario, role-bonus, public feedback, and bankruptcy post-commit forwarding | Existing domain hooks reached through `main.gd` |
| Temporary private discard presentation | Existing `temporary_decision` Overlay flow |

`DistrictPurchaseRuntimeController` does not own players, hands, cash, cards, districts, or economy ledgers. `DistrictSupplySnapshotService` has no settlement authority. `DistrictPurchaseSettlementRuntimeService` does not own the 12-second window, locked price context, presentation Nodes, scenario progression, role-bonus effects, or bankruptcy policy.

## Observed Transaction Order

1. Resolve a canonical real card id and a valid, non-destroyed district.
2. Open or resume the player's single district purchase window.
3. Ask `DistrictPurchaseRuntimeController` to authorize the card against the locked window and current supply revision.
4. Build a pure-data world-fact request and ask `DistrictPurchaseSettlementRuntimeService` for a non-mutating plan; inventory policy is delegated to `CardInventoryRuntimeService`.
5. Revalidate live access, current supply membership, exact locked price, player cash, inventory fingerprint, supply revision, authorization, and discard slot immediately before commit.
6. If the same family is already held below rank IV, plan an in-place upgrade before applying ordinary hand-limit pressure.
7. If a new ordinary card would exceed five cards, reserve `pending_discard`; do not debit cash, add a card, or increment purchase counters.
8. On private confirmation, re-enter the same adapter and service plan/commit path with the chosen discard slot.
9. Ask `CardInventoryRuntimeService` to apply the planned card add/upgrade/replacement to a temporary player copy, then apply exact debit, purchase counter, total spend, private ledger, and cash history to that same copy.
10. Replace the live player state only after the complete transaction succeeds.
11. Forward anonymous public feedback and scenario, role-bonus, and bankruptcy post-commit hooks from the adapter.

## Commit Invariants

- A successful new-family purchase adds one counted card and debits exactly one locked price.
- A successful duplicate-family purchase upgrades in place, leaves counted hand size unchanged, and debits exactly one price.
- A rank-IV duplicate, insufficient cash, invalid supply, expired authorization, or invalid discard cannot debit cash or increment purchase/spend counters.
- Supply is not reserved by the window and is not silently consumed by the settlement path; supply revision changes require reselection.
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
| Discard cancelled | None; window returns active while time remains | Aligned |
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

## Legacy Route Classification

Sprint 28 confirmed that `_upgrade_skill_slot()`, `_replace_skill_slot()`, `_can_upgrade_skill_slot()`, and `_can_replace_skill_slot()` had no production caller, reflected `call()`, signal route, scene reference, test dependency, or save dependency. Sprint 29 additionally removes the purchase-only `_record_player_card_purchase()`, `_discard_card_from_player()`, `_find_previous_rank_card_slot()`, and `_find_owned_card_slot()` helpers. Shared receive helpers remain as thin delegates because role bonuses, steals, and extra draws still use the same inventory service.

## Sprint 29 Cutover Result

`GameRuntimeCoordinator/DistrictPurchaseSettlementRuntimeService` now owns one pure plan and one explicit atomic commit result. Player, AI, Coach, and resumed-discard purchases enter through the same service. `main.gd` retains world-fact collection, Controller authorization, Overlay orchestration, and post-commit forwarding; it no longer directly debits purchase cash, mutates purchased card slots, increments purchase counters, or writes the purchase ledger.

Sprint 31 moves the generic inventory formula into the adjacent `CardInventoryRuntimeService`. The purchase service retains the complete transaction boundary and injects the inventory mutation into its temporary-copy commit. No family/rank, hand-limit, discardability, fingerprint, or card-slot formula remains in the purchase service.

The expanded gate passes 45/45 ownership, 17/17 observed characterization, 17/17 contract alignment, and 18/18 service-cutover cases, for 80/80 total. The new cases cover scene composition, pure requests, add/upgrade/rank-IV plans, pending and confirmed discard, cancel, cash drift, invalid discard, exact-once intents, shared player/AI/resume routing, unchanged Controller/save ownership, permanent legacy-formula deletion, and privacy-safe diagnostics.
