# V0.7 Uninterrupted Card Batch and Contextual Table UI Handoff

## Verdict

```text
STATUS=V07_UNINTERRUPTED_CARD_BATCH_CONTEXTUAL_TABLE_UI_PARTIAL
EFFECTIVE_BASE_SHA=f377746584ac70d706418d399b813f3ad456763e
BRANCH=codex/v07-uninterrupted-card-batch-contextual-ui-f377746

CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_CONSTITUTION=V0.7
FULL_V0_7_RUNTIME_CUTOVER=false
V06_COUNTER_RUNTIME_PRESERVED=true
```

Phases A-D are complete as detached V0.7 reference semantics: frozen rules and
migration inventory, deterministic Core, owner-authorized AI, typed player
projection, reference Save/Replay/privacy, performance evidence, and real
Godot Benches. Phase E did not run. No reference scene or script is connected
to `main.tscn`, production GameScreen, RuntimeLoop, Main, the V0.6 card path,
or the production Save schema.

The task is therefore honestly `PARTIAL`, not blocked and not production
green. Its artifacts may be reviewed in a Draft PR, but may not merge to
`main` until the Action Spine terminal-progression predecessor is green and a
later atomic cutover can replace all V0.6 consumers at once.

## Why V0.7 removes interactive Counter

The old response window made every resolving card a possible multiplayer
pause. V0.7 moves strategy to one 30-second simultaneous preparation window.
Players and AI choose cards, targets, modes, quantities, placement and defense
before lock. After reveal, the batch has one immutable order and accepts zero
gameplay input until `CARD_BATCH_COMPLETE_RECEIPT` opens the next window.

This preserves interaction through prediction and proactive protection while
removing response latency, Counter-on-Counter stacks, target reselection, and
AI replanning during resolution:

```text
CARD_WINDOW_OPEN (30 seconds; all choices)
        ↓ lock
RESOLUTION_ORDER_BUILD / REVEAL
        ↓
strict sequential card commits
        ↓
BATCH_COMPLETE_RECEIPT (exact once)
        ↓
next CARD_WINDOW_OPEN
```

Measured reference results are:

```text
MID_RESOLUTION_GAMEPLAY_WAIT_COUNT=0
COUNTER_WINDOW_WAIT_SECONDS=0
COUNTER_STACK_DEPTH=0
```

## Rule and legacy-card migration

The authoritative V0.7 contract is
`docs/rules/v07_uninterrupted_card_batch_contextual_table_ui_contract.json`.
Its human companion and the V0.7 constitution in `AGENTS.md` make Counter
Window, Counter Stack, mid-resolution submission, and target reselection
illegal.

The dynamic V0.6 catalog contains four formal Counter cards: Phase Veto ranks
I-IV. Every one has exactly one primary V0.7 classification:

| V0.6 card | V0.7 primary type | Preserved authored benefit |
| --- | --- | --- |
| Phase Veto I | proactive defense | one creating-batch prevention |
| Phase Veto II | proactive defense | prevention plus refund 40 on trigger |
| Phase Veto III | proactive defense | refund 90 plus one defender-private trace |
| Phase Veto IV | proactive defense | refund 160 plus two defender-private traces |

No formal card is silently deleted, double-classified, or left undecided.
`火花反制` is a name-only match whose effect is monster delay, not Counter.
The role ability that temporarily converts a monster card into a Counter is a
separate non-card rule decision and must later become proactive defense,
passive source ability, or retire; it is not counted among the four cards.

## Core reference authority

`CardBatchReferenceRuntime` owns the one-shot window, trusted authored-rule
catalog, immutable submissions, authoritative order, sequential commit,
Defense Status, receipt lineage, batch completion and next-window gate. The
state is pure JSON-compatible data and explicitly identifies itself as
`V0.7_REFERENCE_ONLY` with `production_cutover=false`.

Target behavior is authored before lock. The default invalid target result is
`FIZZLE_NO_EFFECT`; legal remainder, authored refund, and deterministic stable
ID fallback are supported without asking a human or AI to choose again.
Actors cannot forge priority, effect amount, source pool, charges, cooldown,
or target policy outside the trusted authored catalog.

Proactive defense is existing state, not a response card. A defense card
resolves in the ordinary order and creates `DefenseStatusV1`. Later eligible
effects automatically apply statuses by stable revision/source/status order,
emit authoritative receipts, consume remaining uses, and continue. They add
no queue entry, insert no card, recurse zero times, consume no RNG, and request
no input. Refund and trace benefits are separate owner-private typed receipts;
the public result does not expose their owner, source card, status ID, refund,
trace or stable internal lineage.

Normal cards and commodities each have an independent five-slot limit. Monster
and military bound actions have zero capacity cost, carry typed source
lifecycle/charges/cooldown, and are either window-time `batch_action` or
automatic `passive_source_ability`. Their Counter action count is zero.

## AI semantic boundary

`AiCardBatchObservationSourceOwner` must be configured for one actor, seat and
source revision. It issues an actor-private, allowlisted, pure-data observation
whose capability cannot be forged by enumerating an actor ID. AI sees only its
own three pools, legal candidate/target facts and allowed public receipts.
Rival cards, targets and inventories, hidden owners, future order, RNG state,
full Core state, authority objects and production world access fail closed.

The planner operates only in `CARD_WINDOW_OPEN`. It chooses a visible legal
card, prebound target, mode and quantity, including proactive defense, then
produces the same unlocked `CardBatchSubmissionV1` draft a human uses. The
shared Core port accepts and locks it. During reveal, resolution and aftermath
the planner returns `GAMEPLAY_INPUT_DISABLED`, zero submission, zero gameplay
Intent and zero RNG consumption. There is no AI-only privileged action.

## Player semantic boundary

The reference surface instantiates its own `V07ReferencePlanetStage` and
`V07ReferencePlanetMapView`. The reference map reuses the real map interaction,
projection, district, route, weather and camera implementation, but it does not
instantiate production `PlanetBoard`, the production player-position host, or
the production backdrop/guide that carry eight-position decoration. The planet
remains the permanent stage and consumes only exact-key typed projections:

- all players appear on the left; 3-4 players use one column and 5-8 use two;
- `public_order_index` is the only roster ordering input; delivery order and
  local-player identity never reorder the list;
- the permanent right rack is replaced by a closable translucent region popup;
- opening, closing or switching the popup does not redraw the authoritative
  rack;
- clicking blank map space or the currently open region closes the popup
  without requesting or mutating a rack;
- target-selection map clicks emit only a prebound target request;
- resolution closes contextual supply and displays a temporary order/result
  overlay with automatic-defense feedback and no Counter element;
- Batch Complete hides the overlay and restores map input;
- the bottom dock separates bound actions, normal `x/5`, and commodity `x/5`.

The UI does not calculate legality, price, order, target outcome, defense or
next-window timing. It has no production GameScreen connection in this task.

## Save, Replay, RNG and privacy

The reference Save codec preserves the exact open-window or mid-resolution
state, authored rules, target bindings, order, cursor, receipts, Defense
Status, owner-private defense benefits, three pools, bound-action lifecycle,
phase trace and mutation trace. It stores no Node, Object, Resource, Callable,
UI state, engine-frame time, Counter Window, Counter Stack or pending Counter
input.

Security hardening added during final review proves:

- successful restore revokes every pre-restore viewer capability;
- card, batch-complete and private-defense receipts have exact-key typed
  schemas, canonical IDs and stable lineage;
- receipt batch/window/index/submission/card links match the locked order;
- pending, aftermath, completion and consumed IDs are unique and consistent;
- hostile Save cannot add fields, rebind or duplicate receipts, detach defense
  ownership, replace completion order, or tamper with a private refund;
- NaN and positive/negative Infinity cannot enter pure data, Save or identity;
- normalized Counter prefixes and spelling/separator variants fail closed in
  both field names and values;
- active batch/window IDs must match their deterministic sequence numbers;
- Replay identity directly fingerprints card and private-defense receipts,
  recomputes its own fingerprint and rejects reordered/tampered identities;
- restore, observation, order, target validation, defense and UI consume zero
  RNG.

This is not a replay product, rollback system, second Save system, or production
Save migration. Future authored random card effects must consume the injected
`RunRngService` in revealed order when Phase E is eventually authorized.

## Three-layer consistency

The integration gate drives one Core state through both downstream layers:

```text
CardBatchReferenceRuntime
        ├─ viewer capability → AI observation → AI plan
        └─ typed allowlists → player window/draft/dock/result projections
```

AI and player submissions use the same `CardBatchSubmissionV1`; AI and player
public aftermath derive from the same Core receipt. Both projections are
read-only. The test reports `double_write_count=0`, `counter_path_count=0`, and
`production_connection_count=0`.

The global registry now has two three-layer-ready domains:

1. `player_action_routing` — completed production slice;
2. `card_group_resolution` — detached V0.7 reference slice.

The registry explicitly keeps the latter on current runtime V0.6, records the
V0.6 Counter blocker, and leaves global completion false.

## Subagent execution

Six roles were requested, but the platform exposed four total team slots,
including the root coordinator. The actual concurrent subagent maximum was
therefore three. Work was consolidated without shell-process simulation:

- `card_batch_core_save`: Core, Save, Replay, receipt lineage and hostile tests;
- `card_batch_ai`: authorized observation, planner, privacy and AI Bench;
- `card_batch_integration_reviewer`: Core performance, cross-layer integration,
  architecture and Godot review;
- root coordinator: rule/counter audit, player surface integration, registry,
  visual QA, full regression, reports, commit, push and Draft PR.

## Verification

| Gate | Result |
| --- | --- |
| Rule contract | 122/122 PASS |
| Counter migration inventory | 122/122 PASS |
| Core semantics | 103/103 PASS |
| Save / Replay / hostile privacy | 72/72 PASS |
| Core Bench test | 7/7 PASS |
| AI semantics | 134/134 PASS |
| AI hostile privacy | 39/39 PASS |
| Three-layer same-source integration | 24/24 PASS |
| Player semantics | 53/53 PASS |
| Player Bench | 35/35 PASS |
| Performance | 11/11 PASS |
| Task architecture gate | 8/8 PASS |
| Global action/registry protocol | 119/119 PASS |
| Main architecture | 219 checks PASS |
| Main runtime composition | PASS |
| UI text / visual / smoke check-only | PASS |

The bounded full `smoke_test.gd` run did not finish within 300 seconds and is
not reported green. This matches the documented broad-suite class of retired
Main/legacy fixture debt; the run emitted no task-specific failure evidence.
No compatibility method or V0.6/V0.7 dual route was added. `--check-only`
passes, and every focused Core/AI/player/Save/architecture gate passes.

The final 64-batch, eight-card performance run recorded 64 order builds and
512 Core card commits:

| Measurement | p95 |
| --- | ---: |
| Resolution order build | 7,046 us |
| Core card commit | 168 us |
| Eight-seat roster | 3,379 us |
| Region popup | 1,426 us |
| Three-pool dock | 6,922 us |
| Resolution UI advance | 70 us |

## Godot and visual evidence

Godot MCP 4.7 loaded the production `main.tscn`, then ran and stopped the Core,
AI and contextual-table Benches. The Core Bench resolved four cards with zero
wait and opened `card-window:000002`; AI emitted zero resolution actions and
zero RNG; the table Bench passed 35/35. There were no task-owned script or
runtime errors. Existing production/map/weather warnings and the repository's
known NUL warnings remain baseline debt. Final task-owned Godot process count
was zero.

Visual evidence:

- `docs/ui_qa/v07_card_batch/contextual_table_popup_1920x1080.png`
- `docs/ui_qa/v07_card_batch/contextual_table_resolution_1366x768.png`
- `docs/ui_qa/v07_card_batch/contextual_table_target_1366x768.png`
- `docs/ui_qa/v07_card_batch/contextual_table_complete_1920x1080.png`

The corrected 1366x768 resolution capture hides the card-window banner while
the batch overlay is active, so the screen does not imply that gameplay input
is still available. The additional target and complete captures show that map
clicks bind a precommitted target during the window and that Batch Complete
returns to the planet before the authoritative next window appears.

## Remaining boundary

V0.6 Counter settlement, AI response behavior, presentation, Save fields and
production card resolution remain composed. The role-based temporary monster
Counter conversion still needs an explicit V0.7 rule decision. Production
Save consumers have not migrated. Main and GameScreen were intentionally not
modified. No V0.7 production cutover occurred.

The next exact task remains:

```text
ACTION_SPINE_V07_TERMINAL_PROGRESSION_ECONOMY_CONTINUATION
```

Only after that predecessor is green should a narrow production-cutover
preflight verify that Core, AI, player UI, Save, privacy and every V0.6 Counter
consumer can switch atomically with zero dual authority.
