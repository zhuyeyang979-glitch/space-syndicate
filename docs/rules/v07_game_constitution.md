# Space Syndicate V0.7 Complete Game Constitution

```text
CONSTITUTION_ID=space_syndicate.v07.complete
SCHEMA_VERSION=1
STATUS=frozen_target_constitution
AUTHORITY_LEVEL=highest_target_rule_authority
CURRENT_PRODUCTION_RULESET=v0.6
TARGET_DEVELOPMENT_RULESET=v0.7
FULL_V0_7_RUNTIME_CUTOVER=false
OPEN_CONSTITUTIONAL_QUESTION_COUNT=0
```

This document is the human-readable companion to
[`v07_game_constitution.json`](v07_game_constitution.json). The JSON file is the
closed machine-readable authority. Stable `rule_id` values in this document
refer to records in that file.

The constitution governs future design. It does not claim that V0.7 is live.
The current player runtime remains V0.6 until an explicit atomic cutover passes
Core, AI, player projection, privacy, Save/replay, RNG, test, and legacy-deletion
gates. See [`v07_rule_precedence.md`](v07_rule_precedence.md).

## Constitution And Balance

Constitutional rules define system shape and may not be changed by an
implementation task. Initial tunable values live in
[`v07_balance_defaults.json`](v07_balance_defaults.json). Every balance record
is marked `balance_tunable=true` and `constitutional=false`; tuning one may not
violate a constitutional invariant.

Examples of frozen structure include one unified track, uniform color reset,
personal DBG zones, optional merge, six independent asset caps, prebound
targets, full reservation, no interactive counters, anonymous round-robin
resolution, solar facility efficiency, and the complete-macro-round end gate.

Examples of initial test values include the 180-second color cycle, 60-second
lead tenure, track movement interval, normal/commodity kind ratio, color floor
and ceiling, GDP-to-asset conversion, authored cost defaults, fallback purchase
price, opening assets, and presentation timing.

## Unified Card Sushi Track

Rules: `v07.track.*`

- There is one real, globally ordered cyclic track.
- Normal cards and commodity cards share that track, movement cadence, player
  order, and six-color distribution.
- Separate normal and commodity tracks and region-bound normal-card pools are
  retired as V0.7 targets.
- Every track card has one primary identity: `life`, `energy`, `industry`,
  `technology`, `commerce`, or `shipping`.
- Each player sees concrete cards only in that player's local segment. Other
  segments, future cards, and future supply order remain hidden.
- Cards enter nearest the current hidden lead and traverse seat-local segments
  in the frozen hidden lead order.
- Segment claim authority is exclusive. A physical card belongs to at most one
  claimable local segment at a time, so no viewer-side tie breaker exists.
- An unclaimed card continues through every local segment, exits after the final
  segment, and is replaced by the authoritative supply owner.
- The normal/commodity kind ratio is independent from player color stances.
  Color choices cannot change card-kind supply.
- Normal purchase and commodity claim remain different typed transactions with
  different inventory destinations.

## Color Cycles And Stances

Rules: `v07.color_cycle.*`

Every color cycle starts again from a uniform baseline:

```text
life=1/6
energy=1/6
industry=1/6
technology=1/6
commerce=1/6
shipping=1/6
```

The previous distribution is not inherited and temporary modifiers do not
compound. GDP affects neither color distribution nor normal/commodity kind
distribution.

During the active cycle, each player selects one UP color and one different DOWN
color for the next cycle. Players may revise before lock. At the boundary, all
legal locked directions reveal simultaneously. If a player has a legal but
unlocked selection, the authority auto-locks that last legal selection at the
boundary. A player with no legal selection is neutral. The next distribution
starts without an empty voting phase.

Normal influence is `+300/-300` basis points. The boundary's hidden lead has
`+600/-600`. The lead used for weighting is the lead at boundary entry: freeze
that identity, reveal and weight stances, commit the new distribution, and only
then advance the lead cursor. Public information links every revealed direction
to its actor identity and shows the final normalized distribution. It excludes
the lead identity, effective player weights, and pre-normalization contribution
breakdown.

The first test cycle duration is 180 seconds. Duration is tunable; the fixed
`300/600` influence values are not subject to a player-count multiplier without
a constitutional amendment. Active-cycle
precommit, simultaneous reveal, no downtime, uniform reset, and hidden weights
are constitutional.

## Hidden Lead And Macro Rounds

Rules: `v07.lead.*`

One authoritative RNG stream creates a fixed hidden player order at match start.
Macro round 1 follows that order, macro round 2 follows its exact reverse, and
later rounds alternate forward and reverse. Every roster player leads exactly
once per complete macro round.

The macro-round roster freezes at its boundary. A disconnected or eliminated
seat keeps its scheduled position for that round and contributes neutral/no-op
decisions; roster changes take effect only at the next boundary. This preserves
the once-per-player proof and deterministic replay.

Only the current lead receives a private notice that explicitly says the
player's influence is double for this cycle. There is no distinctive public
animation, sound, pause, or input flow. Players may infer the order from public
results over time, but no projection directly reveals it.

`MARKET_LEAD_WEIGHT` and `TRACK_POSITION_ORDER` are distinct typed semantics.
The same hidden order may drive both, but neither is inferred from the other.

## Normal Card Acquisition And Personal DBG

Rules: `v07.normal.*`

Clicking a normal card body in the player's local segment directly attempts a
cash purchase while world and track acquisition are active; there is no second
purchase button. A failed purchase leaves the card moving on the track. A
successful purchase enters the player's personal discard pile, not the current
hand, and cannot be used immediately.

Normal-card price has no automatic source-region, monster-position,
monster-range, sunlight, GDP, or rank modifier. The initial base price is one
scalar balance default. An explicit authored card effect or global rule may
still modify price through a typed rule.

Each player owns these normal-card zones:

```text
draw_pile -> hand -> committed_escrow -> resolution -> discard
discard --authoritative reshuffle--> draw_pile
```

Played normal cards do not disappear. When the draw pile cannot satisfy a draw,
the personal discard pile is shuffled by a saveable, replayable authoritative
per-player RNG stream.

## Starter Deck

Rules: `v07.starter.*`

Each player starts with exactly these twelve stable card IDs:

| Color | Factory | Market |
| --- | --- | --- |
| life | `facility.factory.life.rank_1` | `facility.market.life.rank_1` |
| energy | `facility.factory.energy.rank_1` | `facility.market.energy.rank_1` |
| industry | `facility.factory.industry.rank_1` | `facility.market.industry.rank_1` |
| technology | `facility.factory.technology.rank_1` | `facility.market.technology.rank_1` |
| commerce | `facility.factory.commerce.rank_1` | `facility.market.commerce.rank_1` |
| shipping | `facility.factory.shipping.rank_1` | `facility.market.shipping.rank_1` |

The deck is authoritatively shuffled, five cards are dealt, and seven remain in
the draw pile. There is no forced factory/market pair, priority card, or
pattern-based mulligan. A zero-deadlock setup is mandatory, but it is achieved
through the initial asset/default setup rather than by rewriting the random
hand.

## Hand Maintenance And Normal Merge

Rules: `v07.hand.*`, `v07.normal_merge.*`

The normal hand limit is always five. No role, organization, card, or effect can
raise it. Submission and resolution never refill the hand, draw replacement
cards, or reshuffle discard.

After the whole batch resolves:

1. Used normal cards enter discard.
2. Draw to five, reshuffling discard if needed.
3. Present eligible optional merges.
4. After each accepted merge, draw back to five.
5. Repeat merge choice or finish maintenance.
6. Open the next submission window only after maintenance completes.

World time is paused throughout hand maintenance. The initial timeout is 20
seconds and is balance-tunable. At timeout, already committed merges remain and
the authority ends maintenance without performing another merge; this prevents
an unbounded pause without inventing an automatic merge.

Normal cards never auto-merge. Two cards may merge only when they have the same
primary color, card type, `merge_family_id`, level, and owner; both must be in
the normal hand and unlocked.

```text
L1 + L1 -> L2
L2 + L2 -> L3
L3 + L3 -> L4
```

The player may keep duplicates. Merge costs no cash or assets, but produces an
authoritative receipt and a new card instance identity.

## Commodity Inventory And Merge

Rules: `v07.commodity.*`, `v07.commodity_merge.*`

Commodity cards use an independent five-slot inventory. They never occupy the
normal hand, draw pile, or discard pile. Clicking a commodity card body in the
player's local segment directly attempts a free claim; there is no extra claim
button and no cash or asset payment.

A claim is legal only while world simulation and track acquisition are active,
the item is currently in the viewer's exclusive segment, and an inventory slot
is available. A full inventory rejects the claim without discarding or
auto-merging anything; the item continues on the track.

Commodity merge is manual and uses linear base units:

```text
L1 + L1 -> L2
L2 + L1 -> L3
MAX_COMMODITY_LEVEL=L3
```

Inputs must share stable `commodity_id`, color, owner, and unlocked state.
Level-IV commodities and automatic commodity merge are retired V0.7 rules.

## Bound Actions

Rules: `v07.bound_action.*`

Monster and military sources may grant bound actions in the Player Card Dock.
They occupy neither normal-hand nor commodity slots, do not join the normal DBG,
do not merge, and live only while their source authorizes them.

An active bound action uses one of the player's five batch action slots. A
passive bound ability uses none.

## Submission, Targets, And Reservations

Rules: `v07.batch.*`, `v07.reservation.*`, `v07.action_cost.*`

Each one-shot submission window lasts 30 seconds. Every player selects zero to
five active actions across normal cards, commodity cards, monster actions, and
military actions. For each action the player prebinds complete targets, chooses
local order, reviews the full six-color cost, and locks the local queue.

Five is an absolute batch maximum. No role, organization, card, or effect can
add a sixth active action slot.

Lock is all-or-nothing. Every action receives its own complete asset reservation
and the whole queue must be affordable. A successful action consumes its
reservation; a rule-authorized refundable failure releases it. Future refresh
cannot pay the current batch.

After lock, cards, targets, and local order are immutable. The next window opens
only after resolution, reservation settlement, asset refresh, and hand
maintenance.

All active action costs are authored data. They may use primary color, secondary
color, and a limited any-color component. `any` is a payment constraint over
the six pools, not a seventh resource.

## Six-Color Assets

Rules: `v07.assets.*`

The player term is **six-color assets / 六色资产**. `Mana`, `mana points`,
`法力`, and `玛娜` are retired player terms. Life, energy, industry,
technology, commerce, and shipping are independent pools, each capped at six.
Balances, exact reservations, and fixed-point remainder are player-private.

The six player-facing names are `生命资产`, `能源资产`, `工业资产`,
`科技资产`, `商贸资产`, and `航运资产`. `法力值` is retired as well.

Assets do not recover continuously. At submission lock, the authority freezes
that player's completed per-color commodity GDP snapshot. After the whole batch
resolves and reservation consumption/refunds finish, that frozen snapshot tops
up the corresponding pools once. Resolution-time GDP changes are not reread for
the same refresh.

Unused assets carry over. Amount above six is discarded. Fixed-point remainder
must preserve fractional accrual. Only a player's own same-color GDP contributes
to that player's refresh; opponent GDP does not, and no GDP value affects the
unified track.

Initial conversion and card-cost values are balance defaults. The frozen shape
is six independent capped pools, lock-time snapshot, post-batch top-up, carry,
overflow discard, and exact reservation.

## No Interactive Counters

Rules: `v07.counter.*`, `v07.resolution.no_new_input`

V0.7 retires the Counter Window, counter stack, counter-the-counter, temporary
play during resolution, and target reselection. Resolution accepts no new
gameplay input.

Shields, insurance, protection, damage reduction, passive source abilities, and
precommitted interference apply automatically from already-authoritative state.

## Anonymous Round-Robin Resolution

Rules: `v07.resolution.*`

At lock, freeze the hidden lead order. Build the global queue as follows:

```text
for local_action_index in 0..4:
    for player in frozen_hidden_lead_order:
        if player has action[local_action_index]:
            append action
```

Empty queues are skipped. If one player alone has remaining actions, that tail
naturally resolves consecutively without changing the algorithm.

The public queue may show the card, rule-allowed target, current effect, and
result. It must not show actor ID, name, color, avatar, seat, skips, origin-hand
animation, or owner-specific audio. Resolution order must not directly reveal
the hidden lead.

## World Time

Rules: `v07.world.*`

During the 30-second submission window, effective world time, GDP, facilities,
the unified track, sunlight, lead timer, market color cycle, and Victory timer
continue unless an existing authoritative pause applies.

During card-by-card resolution, those systems and Victory qualification/audit
pause. Card state commits in queue order, but no ordinary world tick occurs
between cards.

## Sunlight And Facility Efficiency

Rules: `v07.solar.*`

Sunlight affects only facility work-rate channels declared by authoritative
facility rules:

```text
sunlit=2.0
dark=1.0
```

The minimum covered channels are factory production rate, market demand or
consumption rate, warehouse ingress throughput, and warehouse egress
throughput.

Sunlight does not affect card supply, track distribution, card price, purchase
legality, facility HP/level/slots/construction price, warehouse capacity or
stock, monster attack, military power, or asset caps. Core solar/world state is
the source; render brightness is never a rule input.

## Complete Macro-Round End Gate

Rules: `v07.victory.*`

V0.7 inherits every unmodified V0.6 end condition and Victory comparison,
including the ordinary Victory audit and a last-solvent-player trigger, but no
trigger immediately enters final settlement. Every trigger becomes pending and
settlement waits until all of these are true:

1. The current submission window is locked.
2. The current card batch is completely resolved.
3. Asset refresh is complete.
4. Hand maintenance is complete.
5. The current lead macro round is complete.
6. Every macro-round roster player has occupied one lead period.
7. Victory still passes revalidation at that boundary.

A mid-round trigger becomes pending. Failed boundary revalidation of the same
original end condition clears the pending state and play continues into the
reversed macro round. Successful revalidation enters `FinalSettlement` exactly
once.

## Player Presentation Constitution

The top surface shows exactly one mixed track, the viewer's local segment,
current six-color proportions, all revealed UP/DOWN directions, unique
color-plus-symbol identities, the actor identity attached to every revealed
stance, and track/cycle timing. It never shows another
segment, future sequence, lead identity, or weight owner.

The Player Card Dock contains six-color assets, normal hand, commodity
inventory, bound actions, and local submitted order. Each asset shows
`current / 6`, reserved amount, and projected cycle refresh.

Normal-hand interaction supports card-shaped presentation, hover raise,
keyboard focus, click selection, drag submit, drag reorder, target highlighting,
illegal-target return, and insufficient-cost feedback.

Region popups no longer purchase normal cards. They may continue to show region,
facility, route, monster, military, economy, and objective facts.

The planet is opaque, front occludes back, backside facilities are hidden, zoom
and pan are safe, and semantically empty outer decoration is removed. Market,
warehouse, factory, monster, and military need replaceable baseline visuals;
visual assets never own rules.

## Core, AI, Player, Save, Privacy, And RNG

Every affected domain must define one Core authority, allowlisted AI
observation, allowlisted player projection, shared typed intent, authoritative
receipt, versioned Save/replay state, privacy policy, and RNG ownership.

Core, AI, and player semantics are three projections of the same authoritative
facts. AI may not copy rules, UI may not recompute legality, Save may not become
a second state owner, localized names may not imply rules, and `Main` may not
own V0.7 business state. `GLOBAL_THREE_LAYER_COMPLETE` remains false.

Public, viewer-private, and authority-secret fields are enumerated in the JSON
constitution. Timing, animation, or audio may not leak a secret identity.

V0.7 requires a new versioned Save schema. V0.6 saves cannot directly resume as
V0.7 and must be backed up before migration. Required state covers personal DBG
zones/order, merge lineage, commodities, bound sources, assets/remainders,
reservations/snapshots, submission and queues, unified track and supply state,
market cycle and stances, hidden lead and macro round, solar state, and Victory
gate.

Dedicated RNG streams are required for starter shuffle, each player's normal
deck reshuffle, unified-track type draw, color draw, normal-card draw,
commodity-card draw, and initial hidden lead order. UI, AI observation, hover,
drag, and animation consume no rule RNG.

## Inheritance And Retirement

V0.7 initially inherits unmodified V0.6 semantics for 3-8 player PVE, public
role selection, voluntary starter monster timing, automatic monster behavior,
facility legal regions, routes/transport, cash and GDP meaning, Victory
qualification/audit comparison, untouched monster/military/weather domains, and
the anonymous-play information boundary.

Inheritance carries rule meaning, not old architecture, `Main` calls, stale
tests, or old Save ownership. The complete retired-rule registry is in the JSON
constitution and the transition is mapped in
[`v06_to_v07_rule_delta.md`](../migration/v06_to_v07_rule_delta.md).

Earlier shared-commodity-track documents remain historical migration evidence.
Their GDP-driven supply, separate commodity-only track, level-IV commodity
merge, and unresolved authority questions are superseded by this complete
constitution.

## Cutover Boundary

This freeze adds no runtime, scene, resource, Save schema, RNG draw point, AI
policy, queue owner, or reference implementation. V0.6 remains production.

A future implementation task must cite rule IDs, implement deterministic logic
before presentation, preserve exactly one writer per state domain, version
persistence, validate privacy and replay, and delete the conflicting V0.6 owner
in the same atomic cutover. Long-term dual write is forbidden.
