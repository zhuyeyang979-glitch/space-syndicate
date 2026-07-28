# V0.7 Uninterrupted Card Batch and Contextual Table Contract

## Status and authority

```text
CONTRACT_ID=v07_uninterrupted_card_batch_contextual_table_ui.v1
PHASE=PHASE_A_TO_D_REFERENCE_SEMANTICS_READY
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_CONSTITUTION=V0.7
V07_HIGHEST_DEVELOPMENT_AUTHORITY=true
FULL_V0_7_RUNTIME_CUTOVER=false
V06_COUNTER_RUNTIME_PRESERVED_UNTIL_V07_CUTOVER=true
```

This contract and its executable reference scenes complete Phases A-D without
changing the active V0.6 runtime. V0.7 retires interactive Counter cards,
Counter Windows, and Counter Stacks. V0.6 remains the only production
authority until Core, AI, player UI, persistence, privacy, and old-path
deletion can switch together in one atomic cutover. A new V0.7 path must never
call the preserved V0.6 Counter runtime, and no dual write is permitted.

The executable counterpart is
`docs/rules/v07_uninterrupted_card_batch_contextual_table_ui_contract.json`.

## Player rule

Every strategic choice happens inside one 30-second card window. A player or
AI selects cards, targets, placement slots, modes, quantities, commodity
bindings, and proactive protection before the window locks. Once the order is
revealed, the batch resolves automatically and continuously. Resolution never
waits for a player, accepts a new gameplay action, or reopens ordinary target
selection.

Players may still inspect non-mutating information and adjust local
presentation speed during resolution. Those actions are presentation-only and
cannot alter authority state.

## Authoritative state machine

```text
CARD_WINDOW_CLOSED
→ CARD_WINDOW_OPEN
→ CARD_WINDOW_LOCKING
→ RESOLUTION_ORDER_BUILD
→ RESOLUTION_ORDER_REVEAL
→ CARD_RESOLUTION_ACTIVE
→ CARD_EFFECT_COMMIT
→ CARD_AFTERMATH
→ CARD_RESOLUTION_ACTIVE (when another card remains)
→ BATCH_AFTERMATH
→ BATCH_COMPLETE
→ CARD_WINDOW_OPEN
```

There is no `COUNTER_WINDOW`, `COUNTER_STACK`,
`FORCED_CARD_RESPONSE`, or `MID_RESOLUTION_CARD_SUBMISSION` state. The next
window may open only from one authoritative, exact-once
`CARD_BATCH_COMPLETE_RECEIPT`, after the resolution queue, active resolution,
pending receipts, and aftermath work are empty. UI animation and local timers
cannot open a window.

## Typed pure-data contracts

The detached V0.7 reference authority uses the following stable structures:

- `CardBatchStateV1` owns the window, locked submissions, order, current index,
  receipt lineage, aftermath, and completion fact.
- `CardBatchSubmissionV1` binds one actor and card instance to a source
  revision, window, action class, and `PreboundTargetSpecV1`.
- `PreboundTargetSpecV1` carries stable target IDs, target revision, placement
  slot, mode, quantity, authored parameters, and invalidation policy.
- `CardResolutionStateV1` records one ordered resolution, target validation,
  applied defense statuses, authoritative receipt, and aftermath completion.
- `DefenseStatusV1` records source lineage, protected stable IDs, filter,
  amount/count, activation and expiry, remaining uses, and visibility policy.

These structures are stable-serializable pure data. They contain no `Node`,
`Object`, `Resource`, `Callable`, `NodePath`, localized-name identity, or UI
reference.

## Submission and target locking

At `CARD_WINDOW_LOCKING`, submissions, targets, modes, and quantities become
immutable. When a card reaches the head of the order, Core loads the locked
submission, revalidates the prebound target, applies existing defense/status
state, commits the effect, emits the authoritative receipt, and completes
aftermath. Neither a human nor AI may choose a replacement target.

Every card declares one target-invalidation policy:

1. `FIZZLE_NO_EFFECT` — the default;
2. `COMMIT_LEGAL_REMAINDER`;
3. `REFUND_BY_AUTHORED_RULE`;
4. `DETERMINISTIC_FALLBACK`.

A deterministic fallback must be authored by the card rule and use stable IDs.
It cannot use RNG, UI state, translated names, or a fresh planning decision.

## Proactive defense replaces Counter

The four V0.6 Phase Veto cards migrate to proactive defense semantics. During
the 30-second window, the actor binds the player or object to protect. The card
resolves in the ordinary order and creates a `DefenseStatusV1`. A later direct
player interaction automatically consults and consumes eligible status without
opening a window, adding a queue item, changing the order, or recursing.

Multiple defenses apply in the stable order:

```text
active_from_revision
→ source_card_instance_id
→ defense_status_id
```

The Phase A default is one use, valid only in the batch that created it, and
never retroactive. A defense resolved after an attack cannot protect against
that earlier attack. Rank II-IV refund occurs only if the defense actually
triggers. Rank III-IV trace becomes a defender-only allowlisted private
receipt; it cannot expose a hidden owner or anonymous true source through a
public projection.

## Time ownership

The three domains remain distinct:

| Phase | World effective time | Card-window time | Presentation time |
| --- | --- | --- | --- |
| `CARD_WINDOW_OPEN` | running | running | running |
| order build through batch aftermath | paused | paused | running |

GDP, production, demand, transport, autonomous behavior, weather, commodity
cycle timing, Victory timing, and world-duration effects therefore do not tick
between resolving cards. Each card commit is nevertheless immediately visible
to the next card in the same batch.

## Three independent card pools

```text
NORMAL_CARD_HAND_LIMIT=5
COMMODITY_CARD_HAND_LIMIT=5
BOUND_ACTION_CAPACITY_COST=0
THREE_CARD_POOLS_INDEPENDENT=true
```

Monster and military sources may grant `BATCH_ACTION` or `PASSIVE_ABILITY`
entries. They never grant a bound Counter action in V0.7. Source lifecycle,
cooldown, and charges remain typed state; bound actions consume neither normal
nor commodity capacity.

## AI semantics

AI receives an owner-bound allowlisted observation and uses the same
`CardBatchSubmissionV1` contract as a human. It plans cards, targets, modes,
quantities, and proactive defenses only while the card window is open. During
order reveal, resolution, and aftermath, its gameplay Intent count is exactly
zero. It cannot read hidden owners, rival private inventories, unrevealed
submissions, or authority-only defense details.

## Player table semantics

The target table keeps the map as the permanent stage:

- all player portraits appear on one side;
- 3–4 seats use one column, 5–8 seats use two columns;
- the permanent right-side region rack is retired;
- selecting a region opens a closable translucent, read-only projection of its
  authoritative rack;
- close, Esc, blank-map click, repeated current-region click, target selection,
  resolution, and menu navigation all close the popup without refreshing it;
- target-selection clicks bind targets and do not open the rack popup;
- resolution closes the popup and shows one temporary overlay;
- the overlay displays order, current result, aftermath, and automatic defense
  feedback, but no Counter controls or timer;
- the bottom dock separates bound actions, normal hand `x/5`, and commodity
  inventory `x/5`.

The popup and overlay do not own racks, prices, legality, card order, or rules.
Opening, closing, switching region, hovering, and camera motion consume no RNG
and mutate no rack.

## Save, Replay, RNG, and privacy

The reference Save codec preserves batch phase, remaining window time, locked
and unlocked submissions, prebound targets, order and current index, authored
rules, defense statuses, defender-only refund/trace receipts, aftermath, and
all three card pools. It explicitly does not preserve a Counter Window,
Counter Stack, or pending Counter input. Restore cannot reroll order, reselect
targets, reopen retired windows, reuse a pre-restore viewer authorization, or
reapply committed cards. This is executable reference evidence, not a
production Save-format migration.

Replay identity is based on batch, submission, card instance, target-binding,
order, and defense fingerprints. Defense ordering, target validation,
observation, UI layout, and restore consume zero RNG.

Unrevealed submissions and targets, hidden owners, rival inventories, AI plans,
and private trace data remain private. Public defense presentation communicates
only the allowlisted fact and result.

## Production cutover gate

Phases A-D are reference-ready: the rule/migration freeze, deterministic Core,
owner-authorized AI planning, contextual player surface, Save roundtrip,
privacy gates, and Benches execute without entering production composition.
That does not make the V0.7 production runtime ready. The V0.6 Counter runtime
remains composed until one later atomic cutover simultaneously:

1. connects the V0.7 batch Core and exact-once complete receipt;
2. migrates every Counter card to its approved V0.7 semantic;
3. connects AI window planning and proves zero resolution Intents;
4. connects the contextual player UI and removes Counter surfaces;
5. migrates Save/restore and replay identity;
6. deletes V0.6 Counter submission, settlement, AI, UI, and Save paths;
7. proves no dual authority, dual write, Main fallback, privacy leak, or RNG
   drift.

Until all seven gates pass:

```text
PHASE_A_CONTRACT_READY=true
PHASE_B_REFERENCE_CORE_READY=true
PHASE_C_REFERENCE_AI_READY=true
PHASE_D_REFERENCE_PLAYER_UI_READY=true
PHASE_B_PRODUCTION_CORE_RUNTIME_READY=false
PHASE_C_PRODUCTION_AI_RUNTIME_READY=false
PHASE_D_PRODUCTION_PLAYER_UI_READY=false
SAVE_MIGRATION_READY=false
PRODUCTION_CONSUMERS_MIGRATED=false
OLD_V06_COUNTER_AUTHORITY_DISABLED=false
FULL_V0_7_RUNTIME_CUTOVER=false
```
