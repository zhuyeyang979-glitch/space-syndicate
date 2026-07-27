# Shared Partial-Visibility Commodity Track Three-Layer Semantic Contract

## Status and authority

```text
CONTRACT_ID=shared_partial_visibility_commodity_track.v1
RULE_STATUS=V0_7_APPROVED_SEMANTIC_CONSTITUTION_NOT_ACTIVE_RUNTIME_RULE
GAME_SEMANTIC_CONSTITUTION_VERSION=V0.7
REPOSITORY_APPLICATION_VERSION=NOT_DECLARED
ACTIVE_PRODUCTION_RULESET=v0.6
CURRENT_RUNTIME_RULE_VERSION=v0.6
TARGET_RULE_VERSION=V0.7
RUNTIME_CUTOVER_PERFORMED=false
OLD_RULE_AUTHORITY_DISABLED=false
FULL_RULE_CUTOVER=false
FULL_V0_7_CUTOVER=false
CURRENT_TASK_INTERRUPTED=false
CURRENT_WORK_DISCARDED=false
CONSTITUTION_AMENDMENT_RECORDED=true
```

This contract turns the approved V0.7 shared-sushi-track constitution in
`AGENTS.md` into executable, pure-data reference semantics. It supersedes
conflicting v0.6 commodity clauses as the **future design direction**, but does
not override their current runtime execution, update the active mechanic
registry, change the Save schema, or connect a second owner to production. The
existing v0.6 belt, inventory, merge, market, and Victory behavior remains the
sole production authority until an explicit Phase D cutover replaces it
atomically.

The mechanic IDs below are reserved but remain `RULE_AUTHORITY_NOT_ESTABLISHED`
for production until the rulebook, runtime directive, mechanic registry, Save
migration, and unresolved topology decisions are approved:

- `shared_commodity_track_local_window_v1`
- `commodity_supply_cycle_180s_v1`
- `commodity_hidden_lead_snake_order_v1`
- `commodity_gdp_generation_baseline_v1`
- `separate_commodity_inventory_v1`
- `linear_commodity_upgrade_v1`
- `commodity_macro_round_end_gate_v1`

## One semantic chain

```text
CORE_SEMANTICS
  computes facts and is the only future mutation authority
        ↓
AI_SEMANTICS
  receives an actor-scoped legal observation and submits typed intents
        ↓
PLAYER_SEMANTICS
  receives public plus actor-private projection and submits the same intents
```

AI and player semantics are projections, not competing rule engines. Neither
may calculate or overwrite supply percentages, lead weights, track visibility,
merge legality, or game-end eligibility.

## Frozen core semantics

### Stable identities and fixed point

The stable color order is:

```text
life, energy, industry, technology, commerce, shipping
```

All distributions use integer basis points and total exactly `10,000`. At
bootstrap, integer remainder is assigned in the stable color order, producing
shares that differ by at most one basis point. Localized names, icons, card art,
and display colors never serve as runtime identity.

The runtime distribution has three separate layers:

```text
GDP_BASELINE_DISTRIBUTION
TEMPORARY_PLAYER_INTERVENTION
FINAL_RUNTIME_DISTRIBUTION
```

GDP changes affect only the long-horizon baseline. A cycle settlement computes
one intervention vector and one final distribution. Tokens already present on
the track are never rewritten by a new distribution.

GDP smoothing, color floor/ceiling, per-color intervention cap, and player-count
scaling remain `OPEN_BALANCE_PARAMETER`. The reference vectors pass explicit
test values; those values are not a balance lock.

### Continuous 180-second market cycle

The candidate clock domain is the existing authoritative
`RuntimeSimulationStep.world_effective` delta. It creates no second `_process`
or clock.

- duration: exactly `180,000,000` simulation microseconds;
- ordinary pause: no advance;
- monster-wager global gameplay block: no advance;
- finished session: no advance;
- large delta: process every crossed boundary in deterministic order;
- active cycle: players select and may amend one UP and one different DOWN;
- explicit lock prevents a later same-cycle amendment;
- boundary: deterministically lock the last valid selection, reveal all seats
  simultaneously, settle supply, begin the next cycle immediately;
- no empty voting phase and no global wait for a player response.

The default for a seat that never produced a valid selection remains
`RULE_AUTHORITY_NOT_ESTABLISHED`. The reference reducer accepts an explicit
fixture policy and otherwise fails closed at the boundary.

### Hidden lead and snake macro rounds

A fixed hidden order is derived once from the session's existing
`RunRngService` boundary. The reference uses
`RunRngService.deterministic_weighted_shuffle` as a detached vector and proves
that it changes no live draw cursor.

The current cycle's hidden lead weights the stance that is revealed at that
cycle's boundary. The cursor advances only after settlement:

```text
normal stance: +300 bp / -300 bp
lead stance:   +600 bp / -600 bp
```

Only UP/DOWN colors are public. Lead identity, doubled weight, and individual
pre-normalization contributions remain authority-secret. The lead seat itself
receives a private boolean/notice but submits the same `MarketStanceIntent` as
every other human or AI seat.

Odd macro rounds use the fixed forward order. Even macro rounds use its exact
reverse. Every roster member leads exactly once per complete macro round. The
handling of eliminated, disconnected, restored, or newly invalid seats remains
unresolved and blocks production ownership.

### Shared track and local segments

There will be one global ordered token sequence. A token uses stable pure-data
fields:

```text
token_id
product_id
color_id
commodity_level
base_unit_count
spawn_sequence
authoritative_track_position
```

The authority holds the full sequence and seat-to-window binding. AI and player
projections receive only the actor's local segment, with local indices. Another
seat's token ID, product, color, level, name, art, tooltip, global position, or
reconstructable sequence is absent.

The executable reference accepts explicit fixture window offsets but marks the
track state `RULE_AUTHORITY_NOT_ESTABLISHED`. Production cannot start until
track length, window length/overlap, direction/speed model, spawn/refill,
finite-stock behavior, unclaimed-item lifecycle, and simultaneous-claim
tie-break are approved.

### Separate inventory and linear upgrade

The target partitions are independent:

```text
NORMAL_CARD_HAND_LIMIT=5
COMMODITY_CARD_HAND_LIMIT=5
HAND_POOLS_ARE_INDEPENDENT=true

normal_card_count <= normal_card_limit
commodity_slot_count <= commodity_slot_limit
```

Five normal cards do not block commodity acquisition, and five commodity
stacks do not block normal-card acquisition. Five of each is legal but is not a
shared `TOTAL_CARD_COUNT<=10` rule. Normal overflow changes no commodity field;
commodity overflow changes no normal-hand field.

A higher-level commodity occupies one commodity slot and records linear base
units:

```text
L1 + L1 → L2 (2 units)
L2 + L1 → L3 (3 units)
L3 + L1 → L4 (4 units)
```

`L2 + L2` and `L3 + L3` are rejected by the reference. A merge removes one
commodity slot and never changes normal-card count. Manual player choice is the
approved V0.7 target until a later explicit rule changes it. Production
migration remains blocked until rules decide same-product versus same-color
identity, map linear units to today's `10/20/40/80` installation rates, and
define full-inventory failure/discard/replacement behavior.

### Complete macro-round end gate

The existing `VictoryControlRuntimeController` remains the only planned owner
of original end conditions and final scoring. The future track authority may
provide only an attested macro-round-boundary input.

```text
original condition true before boundary
→ end_condition_pending=true
→ continue ordinary gameplay
→ complete current macro round
→ revalidate the original condition after boundary settlement
→ still true: game_may_end=true
→ false: clear pending and continue
```

The pure reducer proves this ordinary path. Production integration remains
blocked until irreversible planet destruction, last-survivor outcomes, and
seat-elimination interactions are explicitly ruled.

## MarketStanceIntent

Human and AI actors submit the same exact structure:

```text
schema_version
actor_id
expected_cycle_index
increase_color
decrease_color
lock
intent_revision
```

UP and DOWN must be different stable color IDs. The core validates the actor,
cycle revision, shape, and lock lifecycle. There is no lead-only action and no
AI privilege field.

## AI semantics

`CommodityMarketObservation` is constructed through an owner-bound actor port.
The trusted owner supplies the bound actor; a different requested actor is
rejected. Every nested object is rebuilt through an exact field allowlist rather
than copied from the core object. The observation contains only:

- current public final and GDP-baseline distributions and trend;
- public revealed stance history;
- public macro-round index/direction and aggregate cycles remaining;
- the actor's local track segment;
- the actor's own separate normal-hand and commodity-inventory state, plus next
  stance/lock state;
- whether the actor itself is current lead;
- actor-private needs and public-visible opponent demand;
- public pending-end state.

It excludes the complete sequence, another seat's segment/inventory/next
stance, fixed lead order, other-seat current lead answer, weights,
pre-normalization contributions, future unseen tokens, RNG, and Save payload.

The executable reference provides Easy/Normal/Hard/Expert stance decisions,
independent-capacity checks, and claim/linear-merge decisions using only this
observation. Merge policy is an explicit fixture rule term and fails closed when
unresolved; it is not hard-coded by AI. Hostile nested Save/RNG/lead/weight
aliases and cross-seat requests are rejected or stripped. This is a semantic
reference, not a production AI cutover; `AiRuntimeController` remains unchanged.

## Player semantics

The passive player projection is also owner-bound and nested-allowlisted. It
contains:

- six authoritative final percentages, GDP baselines, and trends;
- cycle countdown, macro-round label, and revealed stances;
- the viewer's local track segment;
- the viewer's private next stance and lock state;
- a private lead notice only when the viewer is lead;
- separate `普通手牌 x/5` and `商品库存 x/5` counts, limits, acquisition
  permissions, and precise overflow reasons;
- the explicit linear upgrade ladder;
- a pending-end explanation and final-scoring permission from core state.

The projection never exposes a public `+6%`, special animation/timing marker,
lead identity, full sequence, or another actor's private state. The production
`TopCommoditySushiTrack` remains unchanged in this phase.

## Visibility matrix

| Class | Fields |
| --- | --- |
| `PUBLIC` | final six-color distribution, GDP baseline aggregate, trend, cycle timer, revealed UP/DOWN stances, both capacity limits, pending-end message |
| `ACTOR_PRIVATE` | own local segment, own next stance/lock, self-is-lead notice, own normal-hand/commodity counts and commodity stacks, actor-authorized receipts |
| `AUTHORITY_SECRET` | full sequence, other segments, fixed lead order, other-seat lead answer, weights/contributions, other next stances, unseen future tokens, RNG/Save payload |
| `DERIVED_REBUILDABLE` | localized rows, trend labels, private lead text, capacity labels, end-gate message |

AI uses the same actor visibility boundary as a corresponding human seat.

## Future owner and persistence map

```text
RuntimeSimulationStep
├─ future SharedCommodityTrackRuntimeController
│  ├─ one sequence / movement / stock owner
│  ├─ cycle / stance / distribution owner
│  └─ hidden order / macro-round cursor owner
├─ existing CardFlow + CardPlayerStateProductionAdapterV06
│  └─ atomically migrated commodity inventory partition
├─ existing ProductMarketRuntimeController
│  └─ price and futures only
└─ existing VictoryControlRuntimeController
   └─ original conditions, attested macro-round gate, final scoring
```

The future Save payload must preserve sequence/position/stock/generation
lineage, cycle/deadline/distributions, revealed and private stances, hidden
order/cursor, separate normal-hand and commodity-inventory counts/limits and
contents, merge lineage, and pending-end state. Projections are
rebuildable and are never saved. Legacy/new schema dual write is prohibited.

## Executable evidence

- `tests/support/shared_commodity_track_core_semantics_reference.gd`
- `tests/support/shared_commodity_track_semantic_query_source_reference.gd`
- `tests/support/shared_commodity_track_ai_semantics_reference.gd`
- `tests/support/shared_commodity_track_player_semantics_reference.gd`
- `tests/shared_partial_visibility_commodity_track_three_layer_semantics_test.gd`
- `docs/rules/shared_partial_visibility_commodity_track_test_vectors.json`
- `scenes/tools/SharedCommodityTrackThreeLayerSemanticsBench.tscn`

These artifacts prove the nonproduction contract and fail closed around the
unresolved rules. They are not wired into `GameRuntimeCoordinator`,
`RuntimeSimulationStep`, production UI, AI, Save, or Victory.
