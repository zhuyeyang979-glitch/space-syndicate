# Card Resolution Execution Runtime Contract

## Scope

This contract records the Sprint 36 observed behavior and the Sprint 37 ownership cutover for one active card from public reveal through effect completion.

- Ruleset reference: `v0.4`, especially sections 4, 9, 12, 13, 15, 17, and 21.
- Runtime entry point: `CardResolutionTransitionSink.apply_transition_batch()`.
- Orchestration owner: `CardResolutionExecutionRuntimeService.tscn`.
- Concrete effect routing: `CardEffectRuntimeRouter` through typed family ports.
- Characterization/cutover gate: `CardResolutionExecutionRuntimeCharacterizationBench.tscn`.
- Sprint 37 gate: 28/28 observed, 28/28 aligned, and 28/28 cutover.

## Observed lifecycle

The current runtime order is:

1. Read the active entry from `CardResolutionQueueRuntimeService`.
2. Preserve the active entry during the fixed five-second counter window.
3. At completion, Execution Service issues `counter_check` while active remains retained.
4. If a counter exists, remove and settle that counter through the existing queue/cost/history path.
5. Execution Service requires a successful `release_active` receipt from Queue Service.
6. Close reveal/counter presentation state.
7. Rebuild the card from its committed snapshot or persistent slot.
8. Recheck card requirements and current target validity through ordered intents.
9. Dispatch one pure effect request to the existing effect-family rule owner.
10. Finalize the submitted card commitment and persistent cooldown.
11. Emit success/failure aftermath and public/private evidence.
12. Restore the previously selected player, district, product, and contract endpoints.
13. Append one resolved-history entry.
14. Execution Service chooses `start_next` or `finish_batch`/`promote_next_batch`; Queue Service performs the mutation.

The active entry is deliberately cleared before concrete effect dispatch. Exactly-once behavior is enforced by Queue Service release, the Execution Service in-flight/completed resolution gates, and the persisted pending-settlement boundary. A retry after history or mana-settlement failure resumes the same unfinished intent and cannot release the card or dispatch its effect again.

## Submission versus resolution

Ruleset v0.4 treats submission as commitment.

- Card conditions, target choice, one-time card removal, and action cost are checked/committed at submission.
- GDP/share/product conditions are rechecked by the current runtime before dispatch.
- A target that no longer exists or is down is rejected at resolution.
- A consumed one-time card is not returned after counter, condition drift, or invalid target.
- A paid action cost is not refunded by the generic execution path.
- A persistent bound skill remains in its slot and enters cooldown.

`CardInventoryRuntimeService` owns one-time queue slot removal. Execution Service never reacquires a consumed card. Persistent cooldown metadata is finalized by the existing world adapter without changing inventory shape.

## Failure matrix

| Failure | World effect | Card/cost | Active state | Public feedback |
| --- | --- | --- | --- | --- |
| Invalid player or missing card snapshot | No effect | Existing submission commitment remains | Completion caller continues | Missing/invalid snapshot log |
| Requirement drift | No card effect | Consumed card and paid cost are not returned; persistent skill remains | Active already cleared | Explicit condition-failure log |
| Monster target missing/down | No monster effect | Submission commitment remains | Active already cleared | Target-invalid log and failed aftermath |
| Effect owner returns false | No successful effect result | Submission commitment remains | Active already cleared | `未生效` aftermath clue |
| Counter succeeds | Target effect skipped | Target card/cost remain committed; counter also settles | Active target cleared once | Anonymous counter event and history |
| Contract endpoint invalid at reveal end | Contract offer is not opened | Submitted contract remains committed | Active card does not resume | Stable contract failure log |

No generic execution refund mechanism was observed. Bankruptcy checks remain with the existing cash/ledger owners and run after complete atomic effects.

## Temporary decisions and response windows

There is no generic `temporary_decision` continuation token inside active-card execution.

### Target choice

Monster and player targets are chosen before queue submission. Pending target choice prevents submission, so it does not pause an already active card.

### Counter response

Direct-player interaction cards open a fixed five-second response window. This is the card-level pause that retains the active entry. One counter layer is allowed; counter cards are not countered again.

### Contract response

Area trade contracts follow the explicit v0.4 exception:

- The active contract card completes its normal reveal position.
- A copy keyed by the same `resolution_id` enters `pending_contract_offers`.
- The target owner receives an independent five-second accept/reject window.
- Other cards continue resolving.
- Accept, reject, or timeout patches the same resolved-history record.
- Timeout is rejection, not cancellation/rewind.

### Monster wager

Monster wager belongs to `ForcedDecisionRuntimeScheduler` and freezes planet simulation. It is not an alternate owner of card active/current/next queue state and does not create a generic card execution resume token.

## Event order

The observed generic sequence distinguishes opening evidence from outcome evidence:

1. Public reveal/opening log and callout.
2. Concrete world/economy/monster/interaction mutation.
3. Private ledger or private interaction intents from the concrete owner.
4. Public effect intents/callouts from the concrete owner.
5. Generic success or `未生效` aftermath clue.
6. Scenario hooks owned by the concrete rule handler, when applicable.
7. Resolved-history append.
8. Next queue entry start or batch promotion.

`card_played` is a submission hook, not a second resolution hook. City-development rules own their distinct `city_development_resolved` and `city_built` hooks. The generic resolver does not duplicate them.

## Representative real content

Sprint 36 loads real runtime definitions rather than fabricated IDs:

| Card | Effect family | Coverage |
| --- | --- | --- |
| `轨道融资1` | `cash_gain` | Immediate economy, ledger, exactly-once completion |
| `价格套利1` | `product_speculation` | Product/economy mutation |
| `生产扩张1` | `region_economy_shift` | District mutation |
| `诱导电波1` | `monster_lure` | Monster target recheck and monster-rule dispatch |
| `星链拆解1` | `player_hand_disrupt` | Existing hand-interaction service route |
| `区域供需合约1` | `area_trade_contract` | Independent contract response window |
| `出牌追帧1` | `intel_card_trace` | Private/public information boundary |
| `相位否决1` | `card_counter` | Five-second counter response |
| Runtime-generated city development card | `city_development` | Scenario hook ownership |
| Runtime-generated bound monster technique | `monster_bound_action` | Persistent-card boundary |

## Ownership boundary

### CardResolutionQueueRuntimeService

- Owns current, active, and next queue state.
- Owns resolution sequence, group order, lock metadata, pop/skip, counter queue route, and batch promotion.
- Does not execute card effects or mutate world state.

### CardResolutionRuntimeController

- Sole owner of the active shared 8-second, organize 6-second, lock 2-second, reveal, and counter timing transitions.
- Does not own active card payloads or effects.

### CardInventoryRuntimeService

- Owns queue-time slot removal and other inventory-shape transactions.
- Does not execute card effects.

### PlayerHandInteractionRuntimeService

- Owns disrupt/steal planning, penalties, compensation, inventory transaction, and event intents.
- `main.gd` forwards the resulting player states and intents.

### CardResolutionExecutionRuntimeService

- Owns the active execution transaction and ordered intents.
- Owns requirement/target result envelopes, continuation classification, and exactly-once finalization.
- Does not own queue state, clocks, inventory shape, player-hand mutation, or concrete card rules.
- Stores no second active-card authority; the full entry is an isolated transaction snapshot only.

### Existing world rule owners

Economy, city development, product, route, monster, military, contract, intelligence, weather, scenario, and privacy logic remain in their current owners. Sprint 37 does not move or rewrite these algorithms.

### Current scene-first boundary

`CardResolutionTransitionSink` now consumes all twelve authored frame commands
and invokes only typed execution and presentation ports. `main.gd` no longer
owns the transition switch, active-card completion wrapper, queue lifecycle
helpers or `_use_skill` submission fallback. The production table remains the
temporary presentation target until the separate Table Presentation
Source/Target Cutover; that remaining UI debt is not an execution fallback.

Execution persistence uses schema v3. Full in-flight transactions and pending
settlements are validated for ordered intent progress, flag consistency,
resolution/execution binding and outcome fingerprint before restore. Public
debug projections expose counts and summaries only, never private transaction
payloads.

## Sprint 38 effect-family boundary

Economy, product, and route handler registration and result envelopes now belong to `CardEconomyProductRouteEffectRuntimeService`. Its stateless `CardEconomyProductRouteEffectWorldBridge` invokes the existing concrete rule functions. `CardResolutionExecutionRuntimeService` remains unchanged and family-agnostic: it issues one generic `dispatch_effect` intent and never imports the family service, handler table, market formulas, route formulas, or contract formulas.

See `res://docs/card_economy_product_route_effect_runtime_contract.md` for the seventeen-handler boundary and the next formula-migration gate.

## Sprint 39 pure-formula boundary

Deterministic market-boon, speculation, futures, GDP-derivative, and route arithmetic now belongs to `CardEconomyProductRouteFormulaRuntimeService`. Product price remains in `RuntimeBalanceModel`, and the city GDP model remains in `GdpFormulaRuntimeController`; Sprint 39 does not create duplicate formula owners.

`CardResolutionExecutionRuntimeService` remains unchanged. It imports no Formula Service, formula id, product, futures, GDP, or route method. It continues to issue one generic `dispatch_effect` intent and own exactly-once lifecycle ordering only.

See `res://docs/card_economy_product_route_formula_runtime_contract.md` for the pure inputs, outputs, rounding/cap semantics, main compatibility adapters, and deletion gate. The long-lived execution/effect/formula gate is now 68/68.

## Privacy boundary

Public card-track output may contain:

- Card face and effect family.
- Public target and result.
- Group relationship and bid clues.
- Success/failure aftermath.
- Explicitly revealed owner labels.

It must not contain:

- Hidden `player_index` ownership.
- Private target/discard payloads.
- Complete opponent hands or cash.
- AI private plans or scores.
- Private intelligence answers.

Manifest and report records use only dictionaries, arrays, strings, numbers, and booleans. Runtime `Node`, `Callable`, `Object`, and `Resource` values are excluded.

## Save and resume

Current, active, and next queues round-trip through the existing v1 compatibility keys owned by Queue Service. `pending_contract_offers` remains a separate saved list because contract responses are non-blocking history continuations rather than active-card state.

Missing or empty active state resumes safely with no effect replay. Existing v1 queue keys and save version are unchanged. The Service recovery API rejects empty active state and never recreates an effect from history alone.

## Sprint 37 cutover result

Moved as one orchestration unit:

- Active execution plan construction.
- Requirement/target recheck result model.
- Effect-dispatch request and result envelope.
- Selection-context capture/restore.
- Completion, aftermath, history, and continuation intents.
- Counter/contract continuation classification.

Deleted or reduced after the execution and transition gates proved parity:

- `_complete_active_card_resolution()` is physically deleted from Main.
- `CardResolutionTransitionSink` is the sole ordered plan/intent/finalize runner.
- `_resolve_queued_skill()` is absent.
- Completion, aftermath, history, and active-path continuation order are Service-owned.

Keep as world adapters or existing service calls:

- All `_apply_*` concrete effect functions.
- `_resolve_targeted_skill()` and monster/military rules.
- City development, product, route, contract, and economy algorithms.
- Player hand interaction and inventory service adapters.
- Scenario, privacy, log, visual, and public snapshot owners.

## Next boundary

Future card-effect-family and formula modularization should use the stable effect request/result envelope and pure Formula Service boundary. It must not expand Execution Service into a queue, timer, inventory, AI, economy, monster, city, formula, or concrete card-rule owner.
