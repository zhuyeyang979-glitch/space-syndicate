# V0.7 Legacy Counter Card Migration Inventory

## Verdict

```text
FORMER_COUNTER_CARD_COUNT=4
MIGRATE_TO_PROACTIVE_DEFENSE=4
MIGRATE_TO_INSURANCE=0
MIGRATE_TO_BATCH_INTERFERENCE=0
MIGRATE_TO_PASSIVE_SOURCE_ABILITY=0
RETIRE_FROM_V07=0
BLOCKED_NEEDS_USER_RULE_DECISION=0

V06_COUNTER_RUNTIME_PRESERVED=true
OLD_V06_COUNTER_AUTHORITY_DISABLED=false
FULL_V0_7_RUNTIME_CUTOVER=false
```

The active V0.6 catalog contains exactly four unique Counter cards: Phase Veto
I–IV. All four belong to one family and receive exactly one primary V0.7
classification: `MIGRATE_TO_PROACTIVE_DEFENSE`. Historical V0.4 resources,
schema fixtures, and pack entries describe these same four ranks and are not
additional cards.

The machine-readable source of truth is
`docs/migration/v07_legacy_counter_card_migration_inventory.json`.

## Card-by-card disposition

| Stable ID | Rank | V0.6 authored extras | V0.7 primary class | Frozen V0.7 meaning |
| --- | ---: | --- | --- | --- |
| `interaction.phase_veto.rank_1` | I | strength 1 | `MIGRATE_TO_PROACTIVE_DEFENSE` | Prebind protection in the 30-second window; create a one-use DefenseStatus for the creating batch. |
| `interaction.phase_veto.rank_2` | II | strength 2, refund 40 | `MIGRATE_TO_PROACTIVE_DEFENSE` | Same protection; refund 40 only when the status actually intercepts an eligible effect. |
| `interaction.phase_veto.rank_3` | III | strength 3, refund 90, trace 1 | `MIGRATE_TO_PROACTIVE_DEFENSE` | Same protection; triggered refund plus one defender-only allowlisted private trace receipt. |
| `interaction.phase_veto.rank_4` | IV | strength 4, refund 160, trace 2 | `MIGRATE_TO_PROACTIVE_DEFENSE` | Same protection; triggered refund plus two defender-only allowlisted private trace receipts. |

The V0.7 target does not preserve `counter_strength` as an interrupt contest.
All four ranks create one automatic interception because V0.7 has no response
stack to compare strengths. Rank differentiation stays in the authored refund
and private trace result until a later balance revision explicitly changes it.

The protected target is bound before lock and revalidated at the card's normal
resolution position. The default invalidation policy is
`FIZZLE_NO_EFFECT`. The status is not retroactive: an attack earlier in the
same resolution order remains committed. A status expires at the end of the
batch that created it and has one use.

## Privacy result

Rank III and IV trace is never a public identity reveal. It becomes a
defender-only, field-allowlisted receipt. It may contain only clues authorized
by the future card rule. It may not contain or enable reconstruction of a
hidden owner, anonymous true source, opponent private hand, AI plan, RNG state,
or stable authority-only ID. The public receipt may say only that protection
triggered and what public effect was prevented or reduced.

## Exclusions and naming collisions

- Starlink Dismantle I–IV and Shadow Warehouse Traction I–IV are attacks that
  were Counter-eligible in V0.6. They are not Counter cards.
- Guard I–III already represents stateful protection and is not a response
  card.
- `火花反制` is a name collision. Its effect kind is
  `special_monster_delay`; it can remain an ordinary, prebound batch
  interference card and must not be deleted by a textual Counter cleanup.
- `response_cards_ignore_ordinary_submission_limit` is an old organization
  capability field, not an independent card.
- V0.4 `.tres`, migration fixtures, and the V0.6 catalog are duplicate
  representations, not duplicate card identities.

## Related role capability requiring a separate rule decision

The role capability
`role.paradox_beast_contract.temporary_monster_counter_conversion` converts a
monster card into a response-window Counter in V0.6. It is not counted among
the four formal Counter cards. It cannot survive unchanged in V0.7 and is
recorded separately as `BLOCKED_NEEDS_USER_RULE_DECISION`. Its future rule must
choose exactly one of proactive defense, passive source ability, or retirement
before the production cutover.

This does not block the four-card migration classification, but it does block
atomic retirement of every Counter surface.

## Runtime surface audit

A stable semantic scan over the pre-contract repository used these terms:

```text
card_counter
counter_window
counter_stack
pending_counter
response_window
counter_strength
counter_refund
counter_trace
response_cards_ignore
counterability
合法响应窗口
反制窗口
反制牌
反制栈
```

It scans the frozen base commit
`f377746584ac70d706418d399b813f3ad456763e` and excludes `.uid`, `addons/**`,
`third_party/**`, and top-level `tools/**`. Pinning the revision prevents
concurrent V0.7 Core/UI files from changing historical audit evidence. The
baseline contains 148 files:

| Root | Files |
| --- | ---: |
| `data` | 4 |
| `docs` | 21 |
| `reports` | 26 |
| `resources` | 5 |
| `scenes` | 2 |
| `scripts` | 55 |
| `tests` | 35 |

The 55 script files classify as 26 production Core, 2 AI, 7 presentation/UI,
1 Main, and 19 tooling files. The broad count intentionally includes frozen
V0.6 documentation, reports, fixtures, and tests so a future atomic cutover can
distinguish production deletion from immutable historical evidence.

## Current production call chain

```text
CardResolutionRuntimeController
  opens a five-second V0.6 response phase
        ↓
CardPlaySubmissionRuntimeController
  marks the submission reactive
        ↓
CardResolutionQueueRuntimeService
  bypasses the batch lock and inserts it in the next queue
        ↓
CardResolutionExecutionRuntimeService / WorldBridge
  runs counter_check
        ↓
CardCounterSettlementRuntimeService
  removes the Counter, skips the target card, refunds cash, and emits history
```

This live chain is distinct from the reference-only
`CounterResponseWindowV06` test model. The typed forced-decision surface also
accepts `counter_pass` / `counter_play_*`, but the production response port has
no Counter sink. Those dead compatibility options should be deleted at cutover,
not promoted into the new architecture.

## Highest-risk production surfaces

1. `CardResolutionQueueRuntimeService` has the only reactive submission bypass.
2. `CardResolutionExecutionRuntimeService` inserts `counter_check` before every
   card; V0.7 must begin with target revalidation and DefenseStatus application.
3. `CardCounterSettlementRuntimeService` directly mutates cash for refunds,
   ignores `counter_strength`, and does not implement the authored trace value.
4. `AiRuntimeController` makes a mid-resolution Counter decision and consumes
   RNG, violating both V0.7 no-input and deterministic planning boundaries.
5. `CardResolutionRuntimeController`, queue and execution save data can persist
   a response window or pending reactive entry.
6. PlayerFace/Codex DTOs and card presentation expose `counterability`, response
   labels, timers, and Counter categories.
7. `scripts/main.gd` still owns V0.6 conversion, clock, copy, and overlay glue.

## Atomic retirement plan

Phase A–D must leave the V0.6 production chain intact and must never call it
from new V0.7 code. The Phase E cutover must then, in one change:

1. disable and delete reactive submission bypass;
2. replace `counter_check` with prebound validation and automatic defense;
3. remove the settlement service from `GameRuntimeCoordinator`;
4. delete Counter transition, timer, presentation, and forced-decision kinds;
5. delete the AI mid-resolution planner and its RNG draw;
6. resolve and migrate/retire the role conversion capability;
7. consume legacy pending Counter save data through a one-way migration without
   reopening gameplay input;
8. remove live Counter DTO/UI/history output;
9. physically remove corresponding Main methods and fields without a wrapper;
10. prove exact-once batch completion, zero resolution gameplay Intents, zero
    dual authority, and unchanged non-Counter exact-once lineages.

Until this plan is executed, the honest state remains:

```text
V07_RULE_AND_CARD_MIGRATION_CONTRACT_READY=true
V07_PRODUCTION_COUNTER_MIGRATION_READY=false
OLD_V06_COUNTER_AUTHORITY_DISABLED=false
FULL_V0_7_RUNTIME_CUTOVER=false
```
