# Card Inventory Runtime Contract

## Scope

This document records the completed Sprint 31 cutover to the single scene-owned
`CardInventoryRuntimeService`. It is the compatibility contract for card-slot
mutation. It is not a second card-effect, purchase, AI, save, or presentation
system.

Authoritative v0.4 rules retained by the service:

- Ordinary hand limit is five counted cards.
- A duplicate family upgrades in place before ordinary hand-limit pressure.
- Card ranks stop at IV; another copy of a held rank-IV family is rejected.
- Fixed persistent skills do not count toward the ordinary hand limit.
- Queued and cooldown-locked cards are not discardable.
- Exact private hands, discards, locks, and transferred cards remain private.
- The card-defined failed steal converts to target removal plus compensation; it
  is not a generic transaction rollback.

The values `ordinary_hand_limit=5` and `maximum_card_rank=4` come from the
Inspector-editable v0.4 Ruleset Profile through `RulesetRuntimeBridge`. The
inventory service does not keep a second hard-coded ruleset.

## Runtime Owners

| Responsibility | Owner after Sprint 31 |
| --- | --- |
| Family/rank receive plan, add, upgrade, rank-IV reject, ordinary count, fixed-skill exemption, discardability, fingerprint, remove, lock, and transfer slot mutation | `CardInventoryRuntimeService` |
| Price, cash, purchase count, total spend, private purchase ledger, cash history, and complete purchase transaction atomicity | `DistrictPurchaseSettlementRuntimeService` |
| Purchase window, authorization, locked context, expiry, pending-discard window state, and v1 save adapter | `DistrictPurchaseRuntimeController` |
| Target-player effect dispatch, real world fact construction, successful World player writeback, and public interaction events | `CardEffectRuntimeRouter` |
| Remove/transfer/lock orchestration, cash penalty, converted-remove compensation, and private/public event intents | `PlayerHandInteractionRuntimeService` |
| Role-bonus and extra-supply qualification/candidate choice | Existing card-effect adapters, delegating mutation to `CardInventoryRuntimeService` |
| Save envelope composition | Existing `GameRuntimeCoordinator` and domain-state compatibility adapter |

`GameRuntimeCoordinator.tscn` statically owns both runtime services. It injects
the inventory service into the purchase service. That `Node` reference is
internal wiring only and must never enter a UI snapshot, QA manifest, report,
or save file.

## Service API

`CardInventoryRuntimeService` exposes:

- `configure(ruleset_snapshot)`
- `plan_receive(request)` / `commit_receive(player_state, current_facts, plan)`
- `discardable_slots(current_facts)`
- `plan_remove(request)` / `commit_remove(player_state, current_facts, plan)`
- `plan_lock(request)` / `commit_lock(player_state, current_facts, plan)`
- `plan_transfer(request)` / `commit_transfer(source_state, target_state, current_facts, plan)`
- `inventory_fingerprint(current_facts)`
- `debug_snapshot()`

Plans and debug snapshots contain only Dictionary, Array, String, Number, Bool,
and null values. Debug output contains counters and anonymous policy state, not
concrete private card or player identities.

## Mutation Invariants

### Receive and upgrade

1. `main.gd` builds a pure snapshot from a real player and real card definition.
2. The service plans against family, rank, ordinary count, fixed-skill status,
   discardability, and an inventory fingerprint.
3. Commit rebuilds the current plan and rejects drift.
4. Mutation is applied to a temporary player copy.
5. The caller's Dictionary is replaced only after the full mutation succeeds.

A plan may be queried more than once by UI, AI, or qualification code. A
successful gameplay path must still perform exactly one slot-mutation commit.

### Purchase delegation

`DistrictPurchaseSettlementRuntimeService` delegates inventory planning and
application to the inventory service on its temporary player copy. It then
applies the exact cash debit, purchase counters, spend ledger, and cash history
as one purchase transaction. It no longer contains family/rank, hand-limit,
discardability, fingerprint, or slot-mutation formulas.

Player, AI, Coach, and resumed-discard purchases continue to use the same
purchase entry point and the same inventory owner.

### Fixed persistent skills

`_grant_bound_military_commands()` still constructs the real command and emits
existing events, but insertion uses the inventory service with family upgrade
disabled. The occupied slot count may grow while ordinary counted-hand size
remains five.

### Private remove and lock

`PlayerHandInteractionRuntimeService` obtains the authoritative discardable
slot set from the inventory service, preserves stable slot order, and commits
the remove or `lock_left` mutation. A request with no discardable target card
is rejected during planning and cannot reach commit, cash, event, or World
writeback. Concrete card details remain private event intents.

### Transfer and failed-steal conversion

Successful steal is one inventory-service transfer commit: remove the target
slot and add or upgrade the receiver on temporary copies before replacing both
players.

If the receiver cannot accept a card that was actually selected and removed,
and the card effect requests `convert_to_remove`, the service returns
`converted_to_remove`: the target card stays removed, the receiver hand is
unchanged, and the interaction service applies the existing card-defined
compensation once. A target that had no discardable card is not a failed
receive and receives neither compensation nor cash penalty. This deliberate
conversion outcome is not partial failure and must not be changed to automatic
rollback.

## Main Compatibility Surface

The following functions are thin adapters or higher-level orchestrators, not
inventory formula owners:

- `_card_inventory_snapshot()` and `_district_purchase_inventory_snapshot()`
- `_district_purchase_inventory_plan()`
- `_discardable_hand_slots_for_purchase()`
- `_acquire_inventory_skill_for_player()` / `_acquire_card_for_player()`
- `_take_private_hand_card_from_player()`
- `_lock_private_hand_card_for_player()`
- `_transfer_private_hand_card_between_players()`
- `_grant_role_bonus_card_on_purchase()`
- `_draw_extra_district_cards()`
- `_ai_discard_slot_for_purchase()`

No adapter may directly add, upgrade, replace, remove, lock, or transfer a card
slot. Target selection, candidate selection, compensation, event order, and
privacy forwarding remain outside the inventory service.

## Privacy And Save Boundary

- QA fingerprints contain anonymous family hashes, rank, queued, locked, and
  counted flags only.
- Public feedback may expose an affected seat and aggregate result, never the
  concrete private card, hidden actor, AI keep score, private target, or plan.
- Exact card detail may exist in the affected player's private ledger.
- Save version and existing domain envelope are unchanged.
- Runtime services, Resources, Nodes, Objects, and Callables never enter save or
  QA payloads.

## Sprint 31 Evidence

The existing `CardInventoryRuntimeCharacterizationBench` was expanded rather
than duplicated. It instantiates real `main.tscn`, real cards, roles, districts,
players, and the production Coordinator.

- Original characterization: 20/20 observed.
- Original contract alignment: 20/20.
- Runtime ownership cutover: 20/20.
- Total gate: 40/40.
- Output: `user://space_syndicate_design_qa/card_inventory_runtime_cutover/`.

The cutover cases cover scene composition, ruleset source, pure payloads,
receive, upgrade, rank-IV rejection, ordinary limit, fixed-skill exemption,
discardability, remove, lock, transfer success, failed-transfer conversion,
purchase delegation, role bonus, extra supply, human/AI parity, fingerprint
drift, save/privacy compatibility, and permanent legacy-formula deletion.

Player-hand interaction production dispatch now runs through
`CardEffectRuntimeRouter` and `PlayerHandInteractionRuntimeService`. Future work
must not return interaction orchestration or slot mutation to `main.gd`, and
must not create a parallel inventory implementation.
