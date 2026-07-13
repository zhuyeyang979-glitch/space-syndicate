# Card Resolution Queue Ownership Boundary

## Sprint 35 Result

`CardResolutionQueueRuntimeService.tscn` is now the single owner of the current
queue, active entry, next queue, resolution sequence, group construction and
ordering, bid normalization, lock metadata, active pop/invalid skip,
counter-entry removal, next-batch promotion, queue save compatibility, and
public-safe queue debug state. It is statically composed under
`GameRuntimeCoordinator` and is editable in the Godot Inspector.

The long-lived `CardResolutionQueueRuntimeCharacterizationBench` now passes
**28/28 preserved characterization** and **28/28 ownership cutover**, total
**56/56**. The flat v1 save keys remain unchanged. `main.gd` has no
`card_resolution_queue`, `next_card_resolution_queue`,
`active_card_resolution`, `card_resolution_sequence`, or priority-reference
storage; its compatibility property accessors forward directly to the service
without caching or mirroring state.

`CardResolutionRuntimeController` remains the sole 30/25/5 timing authority.
`CardInventoryRuntimeService` remains the sole card-slot mutation authority.
`main.gd` retains world/card eligibility facts, existing play-cost and
bid-chain cash/ledger side effects, UI/scenario/public-event forwarding,
resolved history, and `_resolve_queued_skill()` card effects. No second queue
algorithm remains in `main.gd`.

## Sprint 34 Characterization Baseline (Historical)

`CardResolutionQueueRuntimeCharacterizationBench` instantiates the real
`main.tscn` and passes **28/28 observed** and **28/28 contract aligned** cases.
This sprint does not create a queue service and does not change production
`main.gd`.

`CardResolutionRuntimeController` remains the sole owner of the 30-second
window, 25-second organize phase, 5-second lock phase, active display/counter
clocks, phase transition requests, and their existing save fields. `main.gd`
still owns the current queue, active entry, next queue, entry sequence, group
construction, bid normalization, lock annotations, pop/skip, promotion, and
queue save adapters.

## Observed Submission Transaction

The live `_queue_skill_resolution()` order is:

1. Validate player, slot, duplicate queued flag, active/lock phase, 0-3 group
   limit, one-counter-per-response-window, play requirements, targets, and
   contract context.
2. Reuse the first card's group bid for later cards in that player's group.
   A duplicate positive tier from another group is reduced to zero rather than
   silently raised.
3. Validate that live cash can cover the immediate play cost and retained group
   bid. Rejection leaves cash, hand, queued flags, and both queues unchanged.
4. For the first current-batch card, set the reference player, increment the
   window sequence, and start the controller-owned shared window.
5. Pay the play cost exactly once, clear the private preset bid, increment the
   resolution sequence, and mark the queued skill snapshot.
6. A persistent card stays in its slot with `queued_for_resolution=true`. A
   one-use card is removed from its slot immediately and survives only as the
   queued snapshot with `consumed_on_queue=true`.
7. Append a normal card to `card_resolution_queue`, or append one legal
   reactive counter to `next_card_resolution_queue`. Normal groups are sorted;
   counters retain their waiting order.

The entry records `resolution_id`, `queued_order`, `window_sequence`,
`group_id`, `group_order`, `group_size`, `group_bid`, the locked public target
context, and `play_cost_paid_on_queue=true`. Resolution forwards the private
`_play_cost_paid_on_queue` marker so cleanup does not charge again.

## Group, Bid, Lock, And Order

- Default group size is 0-3 cards; an attempted fourth card is rejected without
  mutation. Cards from one player are flattened contiguously in authored
  `group_order`.
- Distinct positive group bids sort descending. Equal/zero bids use clockwise
  seat distance from `card_resolution_batch_reference_player`, then original
  queued order.
- Lock normalizes each bid to affordable live cash, resolves any duplicate
  positive tier to zero, sorts once more, writes one-based `batch_position` and
  `locked_bid`, then applies the existing group bid chain.
- The highest positive bid enters the public monster-wager pool. Each later
  positive group pays the preceding group. Zero-bid groups pay nothing. These
  cash, ledger, and public-pool mutations are gameplay side effects and do not
  belong inside the future data-only queue container.

## Current, Active, And Next Lifecycle

1. `card_resolution_queue` is the organize/lock batch.
2. Lock marks the batch locked and immediately calls start-next.
3. Start-next pops exactly one front entry. An entry with no usable private
   slot or queued snapshot is skipped recursively without stalling.
4. The valid entry becomes `active_card_resolution`; display and response
   timing continue through `CardResolutionRuntimeController`.
5. A legal response card is committed to `next_card_resolution_queue`; the
   same player cannot add a second response in that five-second window.
6. Active completion clears active state, resolves or counters the card, adds
   history, and starts the next current entry.
7. When current and active are empty, finish-batch promotes the complete next
   queue. Promotion increments the window sequence, clears
   `queued_behind_resolution`, rewrites `promoted_time`, `window_sequence`,
   `group_id`, and per-player `group_order`, selects a reference seat, sorts,
   and starts a fresh organize window.

`_resolve_queued_skill()`, card effects, target validation at resolution,
reactive-counter effects, resolved-history mutation, UI overlays, logs, and
scenario hooks remain outside the future queue service.

## Save Compatibility

Save version 1 currently persists these flat fields without a schema change:

- `card_resolution_queue`
- `next_card_resolution_queue`
- `active_card_resolution`
- `card_resolution_sequence`
- `resolved_card_history`
- controller-owned timer, lock, reference-player, window-sequence, and
  last-resolution-player fields

Missing queue keys restore as empty arrays/dictionaries. Empty current/active
state with a populated next queue remains promotable. The Sprint 35 service
accepts and emits the same flat envelope through compatibility adapters and
does not retain a second queue copy in `main.gd`.

## Public Privacy Boundary

The public track may expose card face, target clues, group position/order/size,
bid clues, phase, and public aftermath. It must not expose `player_index`, real
owner identity, `contract_target_owner`, private target payloads, private
discard payloads, exact private hand names, or AI private plans. Service debug
snapshots, manifests, and reports must contain only Dictionary, Array, String,
Number, Bool, and null-compatible values.

## Sprint 35 Single-Owner Cutover (Completed)

The scene-owned `CardResolutionQueueRuntimeService` was introduced in the same
change that removed the corresponding implementation from `main.gd`.

The cutover removed these main-owned variables and direct container writes:

- `card_resolution_queue`
- `next_card_resolution_queue`
- `active_card_resolution`
- `card_resolution_sequence`
- `card_resolution_priority_reference_player`
- queue portions of capture/apply save adapters

The following lifecycle helpers were deleted or reduced to stateless service
adapters. Presentation and world-fact helpers remain only where their inputs
belong to `main.gd`:

- `_is_card_resolution_busy`
- `_queued_skill_from_entry`
- `_clockwise_queue_distance`
- `_sort_card_resolution_queue`
- `_entry_effective_card_bid`
- `_highest_card_resolution_bid`
- `_card_resolution_leading_queue_index`
- `_normalize_card_resolution_queue_bids`
- `_sort_card_resolution_entry_priority`
- `_card_resolution_groups`
- `_queue_skill_resolution` queue-construction branch
- `_lock_card_resolution_batch`
- `_start_next_card_resolution`
- `_pop_counter_entry_from_queue` container search/removal
- `_finish_card_resolution_batch`
- `_promote_next_card_resolution_batch`
- `_clear_queued_card_flag` ownership coordination
- `_queued_card_entry_index_for_player`
- `_next_batch_card_entry_index_for_player`

Keep `CardResolutionRuntimeController` as timing authority. Keep cash/hand
mutation in their established owners, and have the queue service return pure
commit intents or transition results rather than mutating those domains.
`_resolve_queued_skill`, card effects, group-bid cash settlement, history,
presentation, and scenario forwarding must not be copied into the queue
service. A legacy queue implementation and a service implementation may not
coexist after cutover.

## Cutover Gates (Passed)

1. Preserve all 28 Sprint 34 observations and alignment results.
2. Preserve Runtime Card Resolution Track 14/14 and shared-window/controller
   script tests.
3. Preserve Hand Interaction 40/40, Inventory 40/40, District Purchase 80/80,
   and First Mission 17/17.
4. Round-trip current, active, and next queue through the existing v1 keys.
5. Keep public snapshots anonymous and pure data.
6. Godot editor diagnostics remain at zero.
