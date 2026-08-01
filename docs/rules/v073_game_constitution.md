# Space Syndicate V0.7.3 Complete Constitution

```text
CONSTITUTION_ID=space_syndicate.v073.complete
RULESET_ID=v0.7.3
STATUS=frozen_highest_target_constitution
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
FULL_V0_7_3_RUNTIME_CUTOVER=false
```

## Authority

The closed machine-readable authority is
`docs/rules/v073_game_constitution.json`. V0.7.3 inherits the complete,
hash-locked V0.7.2 constitution and changes only the five decisions frozen in
`docs/rules/v073_amendment_from_v072.json`.

Rule conflicts use this order:

1. The user's latest explicit rule decision.
2. `docs/rules/v073_game_constitution.json`.
3. This Markdown companion.
4. The immutable V0.7.2 JSON and Markdown constitution.
5. The immutable V0.7.1 JSON and Markdown constitution.
6. The immutable V0.7 JSON and Markdown constitution.
7. The V0.6 rulebook for current-production behavior only.
8. Older documents, test oracles, and code behavior.

V0.7.3 is a detached target. This docs-only freeze does not connect it to the
production runtime, alter V0.6, or authorize dual writing.

```text
USER_REJECTS_RESOLUTION_ORDER_AUCTION=true
USER_REJECTS_INITIATIVE_CASH_BIDDING=true
USER_APPROVES_FIXED_ROUND_ROBIN_RESOLUTION=true
USER_APPROVES_PREBOUND_FACILITY_CONTENTION=true
USER_APPROVES_FACILITY_BUILD_FIZZLE_ON_SLOT_CONTENTION=true
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
```

## No Resolution Auction

Rule: `v073.resolution.auction_rejected`

Initiative and resolution order are not an economy. Cash, assets, cards,
roles, organizations, and facilities cannot buy, exchange, or modify a place
in the batch order. V0.7.3 has no initiative-auction Core or Owner, bid intent,
reservation, Receipt, Save field, UI surface, or AI bid policy.

Historical discussion may remain only when marked
`REJECTED_RULE_PROPOSAL` and `NOT_RUNTIME_AUTHORITY`. No half-implemented bid
Owner is retained for possible future use.

```text
INITIATIVE_AUCTION_ENABLED=false
RESOLUTION_ORDER_BIDDING_ENABLED=false
CASH_CAN_CHANGE_RESOLUTION_ORDER=false
INITIATIVE_AUCTION_CORE_COUNT=0
INITIATIVE_BID_INTENT_COUNT=0
INITIATIVE_BID_SAVE_FIELD_COUNT=0
INITIATIVE_BID_UI_SURFACE_COUNT=0
AI_INITIATIVE_BID_POLICY_COUNT=0
```

## Fixed Hidden Round Robin

Rule: `v073.resolution.fixed_hidden_round_robin`

The only source of batch resolution order is the current authoritative hidden
lead order frozen when that batch locks:

```text
RESOLUTION_ORDER_MODE=fixed_hidden_round_robin
BATCH_RESOLUTION_ORDER_SOURCE=frozen_hidden_lead_order_at_batch_lock
RESOLUTION_ORDER_WRITER_COUNT=1
RESOLUTION_ORDER_MODIFIER_COUNT=0
RESOLUTION_ORDER_MUTATION_AFTER_BATCH_LOCK=false
```

The global queue is built by ascending local action index. At each index, the
system visits every player in the frozen batch turn order and appends that
player's card when one exists. Empty positions are skipped. When only one
player has cards remaining, that player's tail naturally continues.

For frozen order `A, B, C, D` and local queues `A1 A2 A3`, `B1 B2`, `C1`, and
`D1 D2 D3 D4`, the global order is:

```text
A1 B1 C1 D1 A2 B2 D2 A3 D3 D4
```

A player controls only the order of their own cards. Putting a critical BUILD
in local position 1 reduces its number of waiting layers but cannot move that
player ahead of another player in the frozen turn order.

`MARKET_LEAD_WEIGHT`, `TRACK_POSITION_ORDER`, and
`BATCH_RESOLUTION_TURN_ORDER` remain separate typed semantics. A common hidden
order may derive them, but none owns or reverse-infers another. No bid affects
market lead, track order, batch order, or victory macro-round order.

The public queue remains owner-anonymous. It does not reveal the complete
player order, actor ID, player name, color, avatar, seat, or owner-specific
animation or audio.

## Unique Facility Slots

Rule: `v073.facility.prebound_unique_slot_modes`

A facility slot is uniquely identified by:

```text
region_id + facility_type + industry_id
```

For example, `region.alpha + factory + life` denotes the one life-factory
slot in that region. The same uniqueness rule applies to markets.

Every facility action must bind these fields before queue lock:

- `region_id` and `region_revision`
- `facility_type` and `industry_id`
- `target_slot_id` and `target_slot_generation`
- `facility_action_mode` and `expected_occupancy`
- expected facility identity, generation, owner, rank, and damage revision

Fields that do not apply use the contract's explicit closed `none` value.
They cannot be omitted and guessed during resolution.

## Prebound Facility Modes

Every facility card selects exactly one immutable mode at submission.

### BUILD_NEW

The target slot must be empty at submission. The action locks
`expected_occupancy=empty` and the current slot generation. Resolution requires
the same slot generation and an empty slot.

### UPGRADE_OWN

The target facility must exist, belong to the acting player, match facility
type and industry, and permit the requested rank transition. Its exact
facility ID, generation, owner, and rank are locked.

### REPAIR_OWN

The target facility must exist, belong to the acting player, have legal
damage, and accept the card's repair. Its exact facility ID, generation,
owner, and damage revision are locked.

```text
FACILITY_ACTION_MODE_MUTABLE_AFTER_LOCK=false
TARGET_RESELECTION_DURING_RESOLUTION=false
```

## Authoritative Revalidation

Rule: `v073.facility.authoritative_revalidation_no_conversion`

The authoritative Region Infrastructure Owner, not UI and not a stale viewer
snapshot, revalidates slot identity and generation, occupancy, facility
identity and generation, owner, mode, rank, and damage revision at resolution.
It emits one typed result:

- `facility_action_resolved`
- `facility_target_invalid_slot_occupied`
- `facility_target_invalid_generation_changed`
- `facility_target_invalid_owner_changed`
- `facility_target_invalid_rank_changed`
- `facility_target_invalid_damage_changed`

`BUILD_NEW` remains BUILD. It cannot become an upgrade, repair, different
region, different industry, different facility type, or action against another
player's facility. The same no-conversion rule applies between UPGRADE and
REPAIR.

```text
BUILD_TO_UPGRADE_AUTO_CONVERSION=false
BUILD_TO_REPAIR_AUTO_CONVERSION=false
UPGRADE_TO_REPAIR_AUTO_CONVERSION=false
REPAIR_TO_UPGRADE_AUTO_CONVERSION=false
```

## Contention Fizzle

Rule: `v073.facility.contention_fizzle_privacy_and_persistence`

Two players may legally lock BUILD actions against the same empty slot. The
earlier action in the frozen round-robin order builds and advances the slot
generation. The later action fails authoritative revalidation and uses
`FIZZLE_FULL_ASSET_REFUND`.

```text
TARGET_RESELECTED=false
ASSET_RESERVATION_RELEASED=true
NORMAL_CARD_DESTINATION=discard
ACTION_SLOT_REFUNDED=false
FACILITY_CREATED=false
FACILITY_UPGRADED=false
FACILITY_REPAIRED=false
```

The public history may say that an earlier action occupied the target slot.
It cannot identify either player. The failed player gets no replacement
action, and the card does not return to hand.

Starter facility cards use exactly the same policy. Their released asset value
is zero because their inherited V0.7.2 cost is zero, but the Starter still
enters discard and the action slot remains consumed.

## Save And Restore

V0.7.3 Save persists the frozen hidden lead order, frozen batch turn order,
player-local queues, local action index, anonymous global queue, and resolution
cursor. Every facility action persists its mode, exact slot identity and
generation, expected occupancy, exact facility identity and generation,
expected owner, rank, damage revision, and invalid-target policy.

Save contains no bid, cash bid, reservation, rank, histogram, auction status,
auction Receipt, or public tiebreak cursor. Restore cannot reorder players,
reselect a target, convert a mode, or repeat a build, Fizzle, asset refund, or
discard.

```text
V072_SAVE_TO_V073_DIRECT_RESUME=false
V06_SAVE_TO_V073_DIRECT_RESUME=false
V06_SAVE_BACKUP_REQUIRED=true
RESTORE_RNG_DRAW_DELTA=0
```

An old detached Save may only fail closed or use an explicit test-only offline
migration. New fields never receive silent defaults.

## AI And Player Boundary

AI and humans receive the same lawful contention information. AI may consider
its self-lead fact, public contention history, public demand, its own local
order, the current public slot state, estimated competition, and legal modes.
It cannot inspect rival targets, rival local queues, rival hands, the complete
hidden order, future action owners, or anonymous queue owners.

Player UI offers BUILD, UPGRADE, and REPAIR modes and explains that local card
ordering changes only the player's layer position. It has no cash bid button,
auction panel, auction countdown, histogram, bid rank, or auction result popup.
Fizzle feedback reports refund, discard, and the consumed action without
revealing an owner.

## Balance Profile

The first-sample profile is
`V073_STARTER_FREE_FIXED_ORDER_CONTENTION`. It inherits V0.7.2's zero initial
assets, free Starter cards, standard L1 cost of one, 60/40 track ratio, 1200
basis-point intervention cap, refresh cap of three, eight-second maintenance,
one-batch lead tenure, six-batch color cycle, five-second scroll, and five local
slots.

It adds only these structural settings:

```text
RESOLUTION_ORDER_MODE=fixed_hidden_round_robin
FACILITY_ACTION_MODE_REQUIRED=true
BUILD_SLOT_CONTENTION_FIZZLE=true
INITIATIVE_BID_MAX_CASH=not_applicable
INITIATIVE_BID_MODE=retired
```

The recommended sample range for facility BUILD Fizzle rate is 3% to 15%.
Below that range contention may lack strategic presence; above it, card loss
may feel excessive. Future tuning may change regions, slot distribution, card
supply, target information, AI preferences, or effects. It cannot add an
initiative auction to hit the range.

## Runtime Boundary

V0.7.3 remains detached. The atomic cutover group must switch `card_batch`,
`anonymous_resolution`, `region_infrastructure`, and
`facility_target_contention` together. V0.6 automatic facility interpretation
cannot coexist with V0.7.3 explicit modes.

```text
V072_HISTORICAL_CONSTITUTION_CHANGE_COUNT=0
V073_PRODUCTION_CONNECTION_COUNT=0
V073_V06_MUTATION_COUNT=0
V073_DUAL_WRITE_COUNT=0
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
HIGHEST_TARGET_RULESET=V0.7.3
FULL_V0_7_3_RUNTIME_CUTOVER=false
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
```
