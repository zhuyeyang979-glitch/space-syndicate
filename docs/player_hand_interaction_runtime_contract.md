# Player Hand Interaction Runtime Contract

## Scope

Sprint 32 characterized the live `main.tscn` path for the four ranks of
`星链拆解` and `影仓牵引`. Sprint 33 preserves those observations while
cutting production ownership over to one scene-owned
`PlayerHandInteractionRuntimeService`; there is no parallel legacy resolver.

The v0.4 rulebook is authoritative for the privacy boundary, ordinary-card
rank I-IV progression, the five-card ordinary hand limit, duplicate-family
upgrade behavior, and the five-second response window for direct player
interaction. The card catalog supplies the exact per-rank count, lock,
penalty, and compensation values listed below.

## Live card matrix

| Card | Runtime kind | Requested effect | Follow-up | Cash rule |
| --- | --- | --- | --- | --- |
| 星链拆解1 | `player_hand_disrupt` | remove 1 | none | none |
| 星链拆解2 | `player_hand_disrupt` | remove 1 | lock 1 for 10s | none |
| 星链拆解3 | `player_hand_disrupt` | remove 1 | lock 1 for 18s | target penalty 80 |
| 星链拆解4 | `player_hand_disrupt` | remove up to 2 | lock 1 for 20s | target penalty 120 |
| 影仓牵引1 | `player_hand_steal` | transfer 1 | none | one-time failure compensation 60 |
| 影仓牵引2 | `player_hand_steal` | transfer 1 | lock 1 for 8s | one-time failure compensation 90 |
| 影仓牵引3 | `player_hand_steal` | transfer 1 | lock 1 for 15s | one-time failure compensation 140 |
| 影仓牵引4 | `player_hand_steal` | transfer up to 2 | lock 1 for 18s | one-time failure compensation 220 |

## Observed ordering

### Disrupt

1. Validate actor and target seats.
2. Repeat private removal up to `hand_discard_count`.
3. Stop the loop when no eligible ordinary card remains.
4. Attempt one private lock on the remaining eligible cards.
5. Apply the target cash penalty, capped at the target's current cash.
6. Write private ledger details and aggregate public feedback.

Queued cards and cards already locked by `lock_left > 0` are not eligible for
removal or a new lock. An empty target is a safe failure for rank I. A rank
with a cash penalty may still settle its penalty after card operations are
exhausted; Sprint 33 must preserve that ordering unless design explicitly
changes the authored effect.

### Steal

1. Validate actor and target seats.
2. Repeat private transfer up to `hand_steal_count`.
3. Each transfer delegates to `CardInventoryRuntimeService`.
4. A new family is received; a duplicate family upgrades in place.
5. If the receiver cannot accept the family, including an existing rank IV,
   the target card is removed with outcome `converted_to_remove`.
6. Stop the loop when the target has no eligible ordinary card.
7. Attempt one private lock on the remaining target cards.
8. Pay compensation once for the played card when at least one transfer
   converted to removal, or when no transfer succeeded.
9. Write private ledger details and aggregate public feedback.

When a two-card request finds only one eligible target card, it partially
succeeds. One successful transfer and no conversion pays no compensation.
Two conversions from one rank-IV `影仓牵引4` still pay 220 once, not twice.

## Mutation ownership

`CardInventoryRuntimeService` is the only owner of slot mutation:

- remove and remove eligibility,
- lock,
- receive and duplicate-family upgrade,
- rank-IV receive rejection,
- transfer and `converted_to_remove`,
- inventory fingerprints and drift rejection.

`PlayerHandInteractionRuntimeService` owns the transaction-level behavior:

- repeated remove/transfer ordering and the follow-up lock,
- target cash penalty and actor compensation,
- partial-success and `converted_to_remove` aggregation,
- private ledger, aggregate public event, and action-callout intents,
- atomic temporary actor/target copies with one final state commit.

`main.gd` is now a thin runtime adapter:

- random eligible-card selection through the existing seeded RNG,
- real player/card facts and card-catalog metadata,
- private economic-ledger intent forwarding,
- public log and action-callout intent forwarding,
- `player_hand_disrupt` / `player_hand_steal` dispatch from
  `_resolve_queued_skill()`.

The legacy `_take_private_hand_card_from_player()`,
`_lock_private_hand_card_for_player()`, and
`_transfer_private_hand_card_between_players()` implementations were deleted
in the same cutover. The two `_apply_player_hand_*` names remain thin
compatibility entry points and contain no penalty, compensation, or inventory
formula.

Both human target selection and AI candidate execution converge on
`_queue_skill_resolution()` and the same queued resolver. There is no
separate AI interaction algorithm.

## Privacy contract

Public output may contain the played card, target seat, aggregate removed /
transferred / converted count, lock occurrence, and the card's stated cash
effect. It must not contain:

- the acting player's identity,
- concrete affected private-card identities,
- the target's exact remaining hand,
- AI plans or private target-selection state.

The affected player receives exact lost/locked card details in their private
ledger. A successful receiver receives the exact transferred card detail in
their own private ledger. Characterization manifest and report records retain
only aggregate deltas; the played card id is public resolution information.

## Save, action, and signal compatibility

The existing save envelope retains `card_resolution_queue`,
`next_card_resolution_queue`, `pending_player_target_player_index`, and
`pending_player_target_slot_index`. The stable temporary-decision actions
remain `target_player_<index>` and `target_player_cancel`, routed through the
existing `temporary_decision_action_requested` path.

## Rulebook comparison

No contradiction with the v0.4 privacy, rank, duplicate-upgrade, ordinary
hand-limit, or direct-interaction response-window rules was observed. The
rulebook does not enumerate these eight cards' complete rank-by-rank numeric
payloads; those values are authored runtime content and are therefore locked
here as the current production contract rather than inferred from prose.

## Sprint 33 cutover complete

The real-main gate preserves **20/20 observed** and **20/20 contract-aligned**
characterization cases, then adds **20/20 cutover** cases for scene
composition, pure service APIs, disrupt/steal ordering, cash exact-once rules,
queued human/AI routing, privacy-safe event intents, and absence of the legacy
helpers. `CardInventoryRuntimeService` remains the sole card-slot mutation
authority; `PlayerHandInteractionRuntimeService` does not duplicate its
remove, lock, receive/upgrade, transfer, or fingerprint algorithms.
