# Shared Partial-Visibility Commodity Track Direction

## Document Status

This document records a candidate direction for a future commodity-track and
market-supply cutover. It is not an active v0.6 runtime rule, implementation
contract, balance declaration, or save migration.

The current production runtime remains authoritative until a later, explicitly
scoped cutover completes logic, privacy, replay, save, UI, and balance gates.
The in-progress `SAMPLE_FULL_RUN_VERTICAL_SLICE_TO_SETTLEMENT` task is not
interrupted or expanded by this direction record.

```text
RULE_DIRECTION=SHARED_PARTIAL_VISIBILITY_COMMODITY_TRACK
MARKET_CYCLE=180_SECONDS
PLAYER_STANCES_PUBLIC_AFTER_REVEAL=true
NEXT_CYCLE_STANCES_HIDDEN_UNTIL_REVEAL=true
LEAD_PLAYER_IDENTITY_HIDDEN=true
LEAD_PLAYER_WEIGHT_HIDDEN=true
COMMODITY_HAND_SEPARATE=true
END_GAME_REQUIRES_COMPLETE_MACRO_ROUND=true
IMPLEMENTATION_CUTOVER_NOW=false
CURRENT_TASK_MUST_NOT_BE_INTERRUPTED=true

GLOBAL_TRACK_STATE=SHARED
GLOBAL_COLOR_DISTRIBUTION=PUBLIC
LOCAL_ITEM_SEQUENCE=PARTIALLY_VISIBLE
OTHER_PLAYERS_LOCAL_SEGMENTS=HIDDEN

NO_EMPTY_VOTING_DOWNTIME=true
PRECOMMIT_DURING_ACTIVE_CYCLE=true
SIMULTANEOUS_REVEAL_AT_BOUNDARY=true

PUBLIC_STANCE=true
PUBLIC_WEIGHT=false
PUBLIC_LEAD_IDENTITY=false

LEAD_ORDER_GENERATION=FIXED_HIDDEN_ORDER
MACRO_ROUND_1=FORWARD
MACRO_ROUND_2=REVERSE
FOLLOWING_ROUNDS=ALTERNATING_FORWARD_REVERSE
EACH_PLAYER_ONCE_PER_MACRO_ROUND=true

OTHER_CARD_HAND_LIMIT=5
COMMODITY_HAND_LIMIT=5
MAX_COMMODITY_LEVEL=4

CURRENT_TASK_INTERRUPTED=false
NEW_RULE_DIRECTION_RECORDED=true
RUNTIME_CUTOVER_PERFORMED=false
SHARED_COMMODITY_TRACK_PLANNED=true
PUBLIC_STANCES_HIDDEN_WEIGHTS_PLANNED=true
FIXED_HIDDEN_LEAD_ORDER_PLANNED=true
ALTERNATING_REVERSE_MACRO_ROUNDS_PLANNED=true
SEPARATE_COMMODITY_HAND_PLANNED=true
COMPLETE_MACRO_ROUND_END_GATE_PLANNED=true
NEXT_IMPLEMENTATION_PHASE=PHASE_A_RULE_AND_SEMANTIC_FREEZE
```

## Candidate Rule Summary

All players share one continuously moving commodity sequence. The sequence is
real global state, but each viewer sees only the local segment currently in
front of that viewer. A player may reason from public color distributions,
GDP, revealed market stances, seat order, and items previously seen locally;
the player may not inspect another seat's current segment or future unseen
items.

The intended decision loop combines:

- public long-horizon color supply driven by planetary GDP;
- short-horizon market intervention chosen by every player;
- one hidden double-weight lead player per 180-second cycle;
- a fixed hidden lead order that alternates forward and reverse by macro round;
- a shared finite item sequence whose local exposure depends on track position;
- a separate five-slot commodity inventory with linear rank accumulation; and
- final settlement delayed until every player has completed one lead cycle in
  the current macro round.

No localized product name, display text, color hex value, or UI label may act
as a runtime identity. Future schemas must use stable commodity, player, cycle,
track-item, stance, and macro-round IDs.

## Authority And State Boundaries

The future cutover must preserve one authoritative owner for each mutable
domain. This document does not create those owners.

| Concern | Future authority boundary | Must not own or infer |
| --- | --- | --- |
| Immutable rule terms | A versioned commodity-track rule specification | Runtime sequence, player choices, UI state, or AI weights |
| Shared track sequence and local-window positions | Exactly one scene-owned commodity-track runtime owner | Product prices, player inventory, presentation text, or a second RNG |
| GDP color facts | Existing GDP/economy owner through a typed read port | Track mutation or market stance state |
| Market price and futures | Existing `ProductMarketRuntimeController` unless a later approved contract changes it | Shared track sequence or commodity inventory |
| Player stances, cycle boundary, and hidden lead order | One versioned market-cycle authority, composed with the track owner through typed receipts | Price formulas, UI voting state, or duplicated player records |
| Commodity inventory | The existing player/inventory ownership chain extended or migrated atomically | A second hand owner, mirror cache, or parallel save section |
| Original victory conditions and final scoring | Existing `VictoryControlRuntimeController` | A second victory engine or presentation-owned eligibility |
| Macro-round end gate | An explicit input to the existing victory authority | Final scoring, ranking, or independent terminal mutation |
| Random generation | Existing shared run RNG authority | A market-specific RNG or projection-time draw |
| Public and viewer-private UI | Read-only projections from authoritative state | Rule calculation, hidden lead inference, or state mutation |

Static terms and dynamic state must remain separate. A candidate future model
may use the following closed, versioned concepts without treating these names
as implemented APIs:

```text
SharedCommodityTrackRuleSpecV1
  cycle_duration_seconds
  color_ids
  normal_influence_basis_points
  lead_influence_basis_points
  commodity_hand_limit
  other_card_hand_limit
  maximum_commodity_level
  lead_order_policy_id
  macro_round_direction_policy_id
  distribution_policy_id

SharedCommodityTrackStateV1
  session_id / session_revision
  track_revision / sequence_fingerprint
  ordered_item_instance_ids
  item_positions
  seat_window_bindings
  current_distribution_revision

MarketCycleStateV1
  cycle_id / cycle_revision
  elapsed_seconds / remaining_seconds
  current_revealed_stances
  next_cycle_private_stances
  lock_receipts
  current_macro_round_id / direction / position

HiddenLeadOrderStateV1
  fixed_player_order
  order_fingerprint
  current_lead_player_id
  current_weight_table

CommodityInventoryStateV1
  owner_player_id / inventory_revision
  five commodity slots or groups
  stable commodity_id / level / base_unit_count

MacroRoundEndGateStateV1
  original_end_condition_pending
  pending_reason_id
  trigger_cycle_id
  current_macro_round_complete
  final_validation_revision
```

Hidden state remains authoritative data, not security by omission in the UI.
It must be clipped before construction of any public or viewer-scoped
projection.

## Visibility Contract

### Public to every player

- the six current runtime color percentages, summing to 100%;
- the GDP baseline color percentages;
- trend versus the previous cycle;
- current cycle ID and remaining time;
- every player's revealed increase and decrease color for the current cycle;
- public track events that do not reveal another seat's local segment;
- the viewer's own ordinary-hand and commodity-inventory counts and limits.

### Viewer-private

- concrete items currently in that viewer's local track window;
- the viewer's own next-cycle increase/decrease choice and lock status;
- the viewer's own commodity inventory contents;
- a private notice when that viewer is the current lead player;
- only actor-authorized receipts needed to submit, amend, or lock a stance.

### Authority-only and never public

- the complete shared item sequence and every other player's local segment;
- future items that have not entered a viewer's authorized window;
- the fixed hidden lead order;
- current lead-player identity, except to that player;
- per-player effective weight and pre-normalization contribution;
- hidden next-cycle stances belonging to other players;
- RNG state, save payload, AI score, private plan, and internal owner identity.

Public percentage changes may make the lead order inferable over time. That is
intended strategic evidence. Directly exposing the lead identity, weight, or
full order is not.

## Shared Track Semantics

There is one ordered commodity track for the match, not one generated track per
player. Every item has one stable runtime instance ID and one position in that
sequence. Seat-window position determines which viewer may see and claim the
item at a given authoritative revision.

The same hidden lead order may drive both market weight and track approach
order, but the two effects must remain separately represented and tested:

```text
MARKET_LEAD_WEIGHT
  current lead stance contributes twice the ordinary test weight

TRACK_POSITION_ORDER
  seat order determines the relative sequence in which local windows encounter
  newly produced items
```

A test or balance change to one concept must not silently alter the other.
Track motion, item generation, claim, removal, refill, and viewer visibility
must use authoritative revisions and fail closed on stale requests.

## GDP Baseline And Runtime Distribution

At match start, all six colors begin at an approximately equal share:

```text
INITIAL_SHARE_PER_COLOR = 100% / 6 ~= 16.67%
```

The runtime distribution has three distinct layers:

```text
GDP_BASELINE_DISTRIBUTION
TEMPORARY_PLAYER_INTERVENTION
FINAL_RUNTIME_DISTRIBUTION
```

The GDP baseline is a smoothed long-horizon projection of attributable
planetary industry GDP. GDP changes must not rewrite the already-generated
track or instantly replace the complete distribution. Player intervention is
a short-horizon offset that applies for exactly one active 180-second cycle.
The final distribution is normalized after policy-defined floors, ceilings,
and offsets.

Future logic must guarantee:

- six final probabilities sum to exactly 100% under the chosen fixed-point
  representation;
- no color can permanently reach zero because of low GDP or player pressure;
- no single color can remain arbitrarily close to 100%;
- already-created item identities and order are not rewritten by a percentage
  change;
- 3, 4, 6, and 8 player sessions use deterministic normalization;
- generation consumes only the established shared run RNG in a frozen order;
- save and replay restore the same baseline, intervention, distribution, track
  sequence, and RNG cursor.

The GDP smoothing coefficient, minimum and maximum shares, rounding policy,
normalization order, and player-count scaling remain test parameters. They are
not balanced or frozen by this document.

## Continuous 180-Second Market Cycle

Each cycle lasts 180 world-effective seconds. There is no empty voting phase
between cycles.

### Cycle start

1. Reveal every valid next-cycle stance that was locked during the previous
   active cycle.
2. Select the next lead from the already-fixed hidden order.
3. Apply ordinary or lead weight internally without revealing the weight.
4. Calculate and publish the new final runtime color distribution.
5. Continue moving and generating the shared track immediately.
6. Open private preparation for the following cycle.

### During the active cycle

Every player privately selects exactly one increase color and one different
decrease color for the next cycle. The player may amend the choice during the
allowed phase, then lock it explicitly. At the boundary, the authority locks
the last valid choice if it was not already locked.

The Phase A contract must define a deterministic bootstrap/default policy for a
player who never produced a valid first choice. It must not derive a choice
from UI text, wall-clock timing, or an untracked random draw.

### Cycle boundary

The current intervention expires, all locked next-cycle stances reveal
simultaneously, the hidden lead weight advances, and the new distribution takes
effect immediately. The next private preparation window opens in the same
transition. No player waits in a separate blocking vote screen.

## Public Stances And Hidden Weights

Each revealed stance publicly identifies the player, one increase color, and
one different decrease color. The initial test baseline is:

```text
NORMAL_PLAYER_INFLUENCE=3_PERCENTAGE_POINTS
LEAD_PLAYER_INFLUENCE=6_PERCENTAGE_POINTS
```

Only the stance is public. The interface and public receipts must not reveal:

- which player received the doubled weight;
- per-player effective percentage-point contribution;
- the exact pre-normalization contribution table;
- a message such as `vote doubled` or `lead player was ...`.

The lead player receives a private, presentation-neutral notice that their
stance has twice the ordinary influence. Every player follows the same input,
lock, animation, audio, and timing flow so the notice does not create an
observable side channel.

## Fixed Hidden Order And Snake Macro Rounds

One stable player order is established for the session and kept hidden. The
generation and RNG-consumption policy must be frozen in Phase A and replayed
from the existing run RNG; it may not use an independent RNG owner.

For a fixed hidden order `A, C, D, B`:

```text
Macro Round 1: A -> C -> D -> B
Macro Round 2: B -> D -> C -> A
Macro Round 3: A -> C -> D -> B
Macro Round 4: B -> D -> C -> A
```

Each active player is lead exactly once per complete macro round. Later rounds
alternate forward and reverse without reshuffling. Elimination, disconnection,
restoration, and seat-count edge cases require explicit Phase A state vectors;
no controller may invent an ad hoc skip or reorder rule.

Players may infer some or all of the order from repeated revealed stances and
distribution outcomes. No public snapshot may provide the order directly.

## Separate Commodity Inventory

The candidate direction separates inventory capacity:

```text
ordinary non-commodity cards: 5 slots
commodity cards or groups:     5 slots
```

Commodity occupancy does not reduce ordinary-card capacity, and ordinary cards
do not consume commodity slots. UI projections must show both counts and both
limits without creating a second mutable inventory owner.

Whether a slot represents one card or one manually retained group must be
frozen before implementation. The invariant is that a merged higher-level
commodity occupies one commodity slot and that players may retain multiple
same-color groups when legal.

## Linear Commodity Upgrade

Commodity advancement is linear accumulation, not equal-rank doubling:

```text
Level 1 + Level 1 -> Level 2
Level 2 + Level 1 -> Level 3
Level 3 + Level 1 -> Level 4

Level 1 = 1 base commodity
Level 2 = 2 base commodities
Level 3 = 3 base commodities
Level 4 = 4 base commodities
```

An upgrade must preserve stable commodity identity and record exact base-unit
count. It must not infer level from a localized name or suffix. Level IV is
terminal.

Manual merge is the preferred first interaction prototype because a player may
need one high-level commodity and one same-color low-level commodity for
different facilities. Automatic merge remains an unresolved usability option;
it may not be introduced before tests prove that it preserves player intent,
slot legality, rollback, and save/replay parity.

## Complete Macro-Round End Gate

All existing victory qualifications and comparisons remain conceptually
unchanged, but a satisfied condition becomes pending until the current macro
round completes:

```text
ORIGINAL_END_CONDITION_MET
AND
CURRENT_MACRO_ROUND_COMPLETE
=
GAME_MAY_END
```

The future lifecycle is:

1. `END_CONDITION_TRIGGERED`: record a pending end reason and its authoritative
   revision without finalizing the session.
2. `END_PENDING_UNTIL_MACRO_ROUND_BOUNDARY`: continue normal cycles until every
   eligible player has completed exactly one lead cycle in that macro round.
3. `FINAL_END_VALIDATION`: after the last cycle's world settlement, re-evaluate
   every original end condition against current authoritative facts.
4. If no condition remains valid, clear the pending state and begin the next
   reverse-direction macro round.
5. If a condition remains valid, create the existing authoritative outcome and
   proceed to `FINAL_SCORING` exactly once.

The boundary check must occur after the last cycle's ordinary world settlement,
not midway through a tick. Phase A must explicitly decide how currently
irreversible special outcomes interact with this gate; no implicit bypass is
authorized by this direction document.

## Conflicts With Current v0.6

These are migration conflicts, not defects to patch inside the current task.

| Current v0.6 behavior or ownership | Candidate direction | Required cutover work |
| --- | --- | --- |
| Commodity cards occupy the ordinary five-card hand. | Commodity inventory has its own five-slot limit. | Migrate the existing inventory ownership chain atomically; do not create a second hand owner or long-lived dual write. |
| Manual commodity merge consumes two same-family, same-rank cards to produce the next rank. | Levels represent 1, 2, 3, and 4 base units and consume one additional level-I unit per upgrade. | Replace merge policy, transaction vectors, rollback evidence, save representation, and UI wording in one scoped cutover. |
| `CommoditySushiTrackRuntimeService` projects a belt dictionary by viewer visibility and sorted item IDs. | One continuously ordered global sequence moves through seat-bound local windows. | Freeze sequence, position, motion, claim, refill, and local-window authority before changing the service. |
| Existing belt visibility may treat an empty visibility list as broadly visible. | Every other player's local segment and every unseen future item are hidden by default. | Introduce fail-closed viewer-scoped projections and hostile privacy tests before UI cutover. |
| `CommodityCardInventoryRuntimeController` owns current belt metadata and save data, while the sushi service is non-owning. | Exactly one owner must hold shared sequence and position state. | Decide whether to evolve the existing owner or migrate once to a narrow track owner; never compose both as writers. |
| `ProductMarketRuntimeController` refreshes product prices from observed supply, demand, disruptions, temporary pressure, contracts, weather, and shared-RNG noise. | GDP color distribution governs long-term item generation, while player stances govern one-cycle supply intervention. | Keep item-generation distribution distinct from price-market supply/demand and retain the existing price/futures owner unless separately approved. |
| Current market cadence and `business_cycle_count` do not implement hidden precommit, simultaneous reveal, hidden lead weight, or 180-second snake macro rounds. | One continuous 180-second stance cycle has no empty voting downtime. | Add a single cycle authority and typed receipts only after Phase A/B parity vectors exist. |
| Product and commodity identities still cross legacy content and save surfaces. | Stable IDs, never localized names, drive rules and replay. | Plan explicit ID/save migration; do not rename in place or parse display text. |
| Victory uses 10-second qualification and a 120-second public audit, and may produce an outcome independently of a commodity macro-round boundary. | A still-valid original condition may settle only after the complete macro round. | Extend the existing Victory owner with an attested boundary gate; do not create a parallel terminal path. |
| Current UI does not present two independent hand capacities, public stance history, or a local moving window under this contract. | UI is a read-only public/private projection of the new authority. | Build projections after pure simulation; UI must not calculate distribution, lead identity, merge legality, or victory eligibility. |
| Current save envelopes know the existing belt, inventory, market, and Victory shapes. | New sequence, cycle, hidden order, private stances, separate inventory, and pending-end state require replayable identity. | Define one migration and exact restore order before cutover; do not add an unversioned payload or run both states as authority. |

## Phased Implementation Plan

### Phase A: Rule and semantic freeze

- freeze stable color IDs, cycle identity, stance lifecycle, lead-order lifecycle,
  macro-round completion, and end-gate transitions;
- define immutable rule terms separately from dynamic instance state;
- freeze visibility matrices and public/private receipts;
- define GDP smoothing, floor, ceiling, normalization, rounding, and bootstrap
  stance policies as explicit candidates;
- define Save/replay identity and migration from current v0.6 without dual write;
- produce deterministic test vectors for 3, 4, 6, and 8 players;
- decide exceptional terminal and eliminated-seat behavior.

No production runtime changes belong to Phase A.

### Phase B: Pure deterministic simulation

- simulate six-color GDP baselines and one-cycle interventions;
- prove 3-point and 6-point weighting and exact normalization;
- prove each player leads once per macro round and forward/reverse alternation;
- simulate fixed-seed track generation and viewer-window movement;
- model separate five-slot commodity inventory and linear upgrades;
- prove pending-end cancellation or finalization only at the boundary;
- compare save/restore and replay fingerprints without UI or production cutover.

### Phase C: Passive projections and UI

- project six public distributions, trend, and cycle timer;
- project current revealed stances and private next-cycle choice/lock state;
- show the private lead notice without public timing, animation, or audio clues;
- show separate ordinary and commodity inventory capacities;
- show only the viewer's authorized local track window;
- keep all calculations in authoritative owners and all UI inputs revision-bound.

### Phase D: Explicit production cutover

- complete a single-owner state migration with save compatibility;
- switch generation, track, stance, inventory, UI, AI observation, and Victory
  boundary consumers together behind reviewed receipts;
- prove rules, privacy, RNG order, exact-once behavior, replay, and performance;
- delete superseded authority in the same program stage;
- prohibit permanent dual write, half-switched rules, and compatibility layers
  that can mutate both models.

## Parameters Requiring Simulation

The following values are test baselines, not balance-complete declarations:

```text
MARKET_CYCLE_SECONDS=180
NORMAL_PLAYER_INFLUENCE=3_PERCENTAGE_POINTS
LEAD_PLAYER_INFLUENCE=6_PERCENTAGE_POINTS
COMMODITY_HAND_LIMIT=5
OTHER_CARD_HAND_LIMIT=5
MAX_COMMODITY_LEVEL=4
```

Phase A/B must evaluate:

- whether 180 seconds is too long or too short;
- 3-point and 6-point strength at 3, 4, 6, and 8 players;
- whether per-color net intervention needs a cycle cap or player-count scaling;
- GDP baseline smoothing speed;
- minimum and maximum color generation shares;
- deterministic fixed-point rounding and normalization order;
- whether five commodity slots support intended factory and market decisions;
- manual versus automatic merge experience;
- whether local visibility provides enough evidence without revealing neighbors;
- whether players can infer the hidden order late in a match through fair play;
- whether snake-order inference is interesting rather than mechanical;
- whether macro-round completion creates an excessive endgame tail;
- whether the final complete macro round gives trailing players a meaningful
  response opportunity;
- bootstrap choices, eliminated seats, session restore, and irreversible special
  outcomes.

## Future Acceptance Principles

A future implementation may declare this direction active only when it proves:

- exactly one authoritative shared track and exactly one commodity inventory
  ownership chain;
- no localized-name or display-text rule branch;
- no other-seat local segment, hidden lead identity, hidden weight, or private
  stance leakage;
- deterministic 3/4/6/8-player cycles, normalization, replay, and snake order;
- no independent RNG, changed draw order, unversioned Save state, or dual write;
- UI and AI consume authorized projections rather than raw state;
- original Victory semantics remain intact except for the explicit attested
  macro-round boundary gate;
- runtime performance supports continuous track motion and 180-second cycles;
- current v0.6 authority is removed only at the explicit cutover checkpoint.

Until those gates pass, the status remains:

```text
IMPLEMENTATION_CUTOVER_NOW=false
RUNTIME_CUTOVER_PERFORMED=false
NEXT_IMPLEMENTATION_PHASE=PHASE_A_RULE_AND_SEMANTIC_FREEZE
```
