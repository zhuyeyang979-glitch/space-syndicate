# Shared Card Window Cadence v0.6

## Runtime contract

The v0.6 shared card window is a three-phase timing protocol:

| Window sequence | Total | `planning` | `public_bid` | `lock` |
|---|---:|---:|---:|---:|
| 0, 1, 2 | 45s | 35s | 5s | 5s |
| 3 and later | 30s | 20s | 5s | 5s |

`organize_seconds` is a read-only migration alias for `planning_seconds`. New runtime and player-facing APIs use `planning`, `public_bid`, and `lock`.

## Ownership

- `CardResolutionRuntimeController` owns elapsed time, phase transitions, phase-local ready state, and cadence save/load.
- `CardResolutionQueueRuntimeService` owns queue entries and the monotonic group-window sequence. It does not own time, cards, cash, bids, effects, inventory, or history.
- `SharedCardGroupWindow` is a stateless rule helper for cadence lookup, phase gates, card limits, and public group ordering.
- Existing bid authorization and cash movement remain outside this cutover.

## Submission limits

An ordinary player may submit one ordinary card per window. `group_card_limit` and `max_cards` in a request are intent only and cannot authorize a higher limit. A higher limit requires a pure-data, authoritative `facts.extra_submission_capability` snapshot bound to the actor, player, current window, owner revision, activation range, and hard cap.

The Queue validates:

- `actor_id`, `player_index`, and exact `window_sequence`;
- current `owner_revision`;
- inclusive activation and expiry window sequences;
- `base_limit=1`, positive `bonus_limit`, `effective_limit=clamp(base+bonus, 1, 3)`, and `hard_cap=3`.

Only after those checks does it normalize the capability for the stateless helper. The request still supplies the desired `max_cards`, so an authorized player can voluntarily use less than the effective limit. Without a valid fact snapshot, the limit remains one. Reactive counter submissions use the existing counter path and do not consume the ordinary submission count.

At the helper boundary, an elevated limit requires both:

1. a non-empty, Queue-validated `extra_submission_capability` identifier; and
2. an explicit `max_cards` value.

The hard maximum is three. Supplying only `group_card_limit` or `max_cards` does not raise the ordinary limit.

## Ready and transition behavior

Ready is phase-local. All active players ready in `planning` advances only to `public_bid`; all ready in `public_bid` advances only to `lock`; all ready in `lock` requests `lock_batch`. Every phase advance clears the ready set. A large clock delta emits each crossed phase boundary once before the final batch lock.

## Sequence and persistence

The first new batch is sequence `0`. Entries in one batch keep the same sequence. Promotion of a waiting response batch advances by one, and a later idle batch cannot reuse `0`. The queue saves `card_group_last_window_sequence`; older saves infer a started sequence from current or active entries and otherwise use the caller's restored window fact.

Legacy auction-only controller saves are normalized into the `public_bid` phase with an explicit `legacy_auction_only_to_public_bid` migration reason. Snapshots remain pure data.

## Production consumption

`main.gd` does not own cadence values or a second sequence counter. During runtime binding it forwards the complete `card_group_runtime_rules()` snapshot to `CardResolutionRuntimeController`, including the standard cadence, the opening cadence, and the ordinary/explicit submission limits. New batches are opened through `begin_group_window(reference_player, sequence)`; the sequence is allocated by `CardResolutionQueueRuntimeService`.

Production interaction and copy consume the controller phase names `planning`, `public_bid`, and `lock`. Ready only advances the current phase. Player-facing timing text is formatted from `cadence_snapshot()` rather than embedding 8/6/2 or a default three-card limit. The public bid phase keeps the existing wager-pool receipt and cash owner; this cutover changes only timing, phase gates, and trusted limit consumption.

Historical v0.4/v0.5 fixtures may retain their authored cadence as migration evidence. They are not production v0.6 configuration or player-facing copy.

## Out of scope

This cutover does not change bid options, escrow, cash settlement, card inventory mutation, card effect execution, counter rules, monster wager timing, or UI layout.
