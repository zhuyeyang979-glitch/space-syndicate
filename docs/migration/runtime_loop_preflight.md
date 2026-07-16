# Authoritative Runtime Loop Cutover Preflight

Status: **RUNTIME_LOOP_PREFLIGHT_BLOCKED**

- Branch: `codex/scene-first-remove-main-gd`
- Start SHA: `297ed167bd0e656aef00a08c68b1edfcadd59474`
- Audited path: `res://scripts/main.gd::_process`
- Production `RuntimeLoop` created: **no**
- Main/New-loop double run created: **no**

The frame order is understood, and most domain ticks already have a scene-owned controller or an explicit `GameRuntimeCoordinator` API. The cutover is nevertheless a No-Go because four required frame responsibilities still exist only as Main-private state or Main-private mutation paths. Creating `RuntimeLoop` now would require a Main callback, duplicate ticking, missing behavior, or moving card/UI domain logic into the loop.

The machine-readable step inventory is in `runtime_loop_preflight.json`.

## Go/No-Go result

Time semantics pass their own gate:

- Current player-facing production pacing is only running or paused (`1/0`).
- `GameSessionRuntimeController` can be the ordinary-pause authority.
- `WorldEffectiveClockRuntimeController` is the only world-clock owner.
- `WorldSessionState.game_time` is a projection of that clock, not a second clock.
- Test-driver multipliers `16/128` are QA-only acceleration.
- The legacy `time_scale` restore and target-choice pause mirrors should eventually be deleted; they do not justify a production `RuntimePacingState`.

The complete runtime-loop gate still fails because unresolved `ROOT_ONLY_BLOCKER` entries exist.

## Current ordered frame path

### Frame front and blocked branch

| Order | Step | Delta | Classification |
|---:|---|---|---|
| 1 | Session-finished gate | none | `EXISTING_COORDINATOR_API` |
| 2 | Synchronize forced-decision candidates | none | `ROOT_ONLY_BLOCKER` |
| 3 | Global-time block check | none | `EXISTING_COORDINATOR_API` |
| 4 | Blocked wager tick | real | `EXISTING_COORDINATOR_API` |
| 5 | Blocked visual-cue ageing | real | `ROOT_ONLY_BLOCKER` |
| 6 | Blocked presentation refresh | real | `ROOT_ONLY_BLOCKER` |
| 7 | Ordinary pause gate | none | `READY_SCENE_OWNER` |
| 8 | Calculate world delta | world | `READY_SCENE_OWNER` |

The current early-return behavior is intentional: a global monster-wager block continues wager, visual, and presentation real-time work without advancing the world clock. An ordinary pause returns without those updates.

### Active world

| Order | Step | Delta | Classification |
|---:|---|---|---|
| 9 | Advance world-effective clock | world | `EXISTING_COORDINATOR_API` |
| 10 | Synchronize `WorldSessionState.game_time` | world | `READY_SCENE_OWNER` |
| 11 | Card-resolution progress gate | none | `EXISTING_COORDINATOR_API` |
| 12 | Card-resolution tick and transitions | world | `ROOT_ONLY_BLOCKER` |
| 13 | Contract tick | world | `EXISTING_COORDINATOR_API` |
| 14 | Player/card cooldown ageing | world | `ROOT_ONLY_BLOCKER` |
| 15 | GDP derivative timers | world | `READY_SCENE_OWNER` |
| 16 | Futures timers | world | `READY_SCENE_OWNER` |
| 17 | Weather tick | world | `EXISTING_COORDINATOR_API` |
| 18 | Economic-boon ageing | world | `READY_SCENE_OWNER` |
| 19 | Monster-wager tick | world | `EXISTING_COORDINATOR_API` |
| 20 | AI tick | world | `EXISTING_COORDINATOR_API` |
| 21 | Monster motion | world | `EXISTING_COORDINATOR_API` |
| 22 | Military tick | world | `EXISTING_COORDINATOR_API` |
| 23 | Monster action timers | world | `EXISTING_COORDINATOR_API` |
| 24 | Monster duration ageing | world | `EXISTING_COORDINATOR_API` |
| 25 | Visual-cue ageing | world | `ROOT_ONLY_BLOCKER` |
| 26 | Monster revival tick | world | `EXISTING_COORDINATOR_API` |
| 27 | Continuous commodity flow | world | `EXISTING_COORDINATOR_API` |
| 28 | Flow-result early-return gate | none | `EXISTING_COORDINATOR_API` |
| 29 | Post-flow session-finished gate | none | `EXISTING_COORDINATOR_API` |
| 30 | Product-market cycle | world | `EXISTING_COORDINATOR_API` |
| 31 | Victory control | world | `EXISTING_COORDINATOR_API` |
| 32 | Post-victory session-finished gate | none | `EXISTING_COORDINATOR_API` |
| 33 | Frame-end presentation refresh | real | `ROOT_ONLY_BLOCKER` |

This order matches the current source and the expected order in the task specification.

## ROOT_ONLY_BLOCKER inventory

### 1. Forced-decision candidate sources

`Main._forced_decision_candidates()` composes candidates from:

- the active monster wager;
- the card counter window;
- pending replacement discard;
- pending monster target choice;
- pending player target choice;
- contract candidates.

`GameRuntimeCoordinator.sync_forced_decision_candidates()` and `ForcedDecisionRuntimeScheduler` only accept and arbitrate an already-built candidate array. They do not own the source facts. A RuntimeLoop cannot query those Main-private fields or call Main to build them.

Minimum missing owner: a typed `ForcedDecisionCandidateSources` composition whose domain owners publish candidate snapshots. The scheduler should remain arbitration-only.

### 2. Card-resolution frame driver

`CardResolutionRuntimeController.tick()` already returns transition commands, but Main still:

- builds the authoritative frame facts;
- interprets every transition;
- opens and closes overlays;
- performs card completion and starts the next resolution;
- locks batches and emits public logs.

This is part of the separately scheduled `card_execution` domain. Moving it into RuntimeLoop would violate this round's boundary.

Minimum missing owner: a scene-owned `CardResolutionFrameDriver` that owns the tick/transition boundary and exposes one explicit scheduling API.

### 3. Realtime cooldown mutation

`Main._update_realtime_cooldowns()` directly mutates every player's `action_cooldown` and each slot's `cooldown_left`/`lock_left`. There is no scene-owned cooldown owner or Coordinator tick API.

Minimum missing owner: `CardCooldownRuntimeController.tick_world(delta_seconds)` or an equivalent API on the current authoritative card-state owner. RuntimeLoop must never iterate player slots.

### 4. Visual cues and presentation cadence

Main owns and ages `movement_trails`, `action_callouts`, and `map_event_effects`. The same visual helper also mutates district `pulse`, so it is not a clean presentation-only call. The arrays still participate in legacy save/restore paths, which are explicitly outside this round.

Main also owns all live/map/full/developer refresh accumulators and calls Main-private refresh methods. There is no scene-owned presentation request API that can preserve behavior without calling Main.

Minimum missing owners:

- a visual-cue state owner that separates presentation lifetimes from district pulse mutation;
- a `TablePresentationRefreshScheduler` that requests refresh from typed presentation consumers rather than Main.

## Existing APIs that are ready

The following existing APIs can be consumed by a future RuntimeLoop without expanding Main:

- `session_is_finished`
- `blocks_global_time`
- `allows_card_resolution_progress`
- `advance_world_effective_clock`
- `tick_contract_runtime`
- `tick_weather`
- `tick_monster_wagers`
- `tick_ai`
- `tick_monster_motion`
- `tick_military`
- `tick_monster_actions`
- `tick_monster_durations`
- `tick_monster_revivals`
- `advance_commodity_flow`
- `tick_product_market_cycle`
- `advance_victory_control`
- scene-owned timer methods on `CityGdpDerivativeRuntimeController` and `ProductMarketRuntimeController`.

Their already-existing world bridges remain `typed_world_ports` debt. This preflight does not add bridge methods, add Main methods, or claim those domains are detached from Main.

## Time and pause semantics

| Situation | Wager | Visual/presentation | World clock | World gameplay |
|---|---|---|---|---|
| Session finished | stopped | stopped | stopped | stopped |
| Monster-wager global block | real delta | real delta | stopped | stopped |
| Ordinary pause/menu | stopped | stopped | stopped | stopped |
| Running | world delta | visual world delta; cadence real delta | once | once, ordered |

Contract, counter, discard and target-choice decisions do not globally freeze world time. They can block the relevant player's actions or card progress through the scheduler.

## Forbidden shortcuts

The following do not satisfy the cutover:

- Callable or signal callback into Main;
- a `MainRuntimeLoopPort`;
- dictionary or string method tables targeting Main;
- `get_tree().current_scene` or `/root/Main` lookup;
- copying the Main mutation loops into RuntimeLoop;
- starting a new RuntimeLoop while leaving Main `_process` active;
- having the Coordinator or a presentation scheduler become a second gameplay process owner.

## Recommended prerequisite

Run one atomic `ForcedDecisionCandidateSources Cutover` first because candidate synchronization is the first unresolved step of every frame.

Required result:

1. Monster owner publishes wager candidates.
2. Card-resolution owner publishes counter candidates.
3. Contract owner continues publishing contract candidates.
4. District-purchase/hand owner publishes discard candidates.
5. A target-choice scene owner publishes target candidates.
6. The scheduler receives typed snapshots and Main's two candidate methods are deleted.

After that cutover, rerun this preflight. Card-resolution frame driving, cooldown ownership, and presentation/visual ownership will still require independent prerequisites; they must not be hidden inside RuntimeLoop.

## Future acceptance contract

When all prerequisites exist, the cutover test must compare complete trace arrays for:

1. already finished;
2. forced global block;
3. ordinary pause;
4. complete active frame;
5. card-resolution blocked;
6. commodity-flow failure;
7. session finished after flow;
8. session finished after victory.

Every trace entry must carry `delta_domain = real | world | none`. Each active frame must advance the world clock exactly once and synchronize `WorldSessionState.game_time` exactly once. No step may run twice.

`RuntimeAuthorityAudit` is a manual registry and is not sufficient alone. A future cutover must combine it with production-scene and source gates proving:

- exactly one RuntimeLoop instance;
- Main and Coordinator have no gameplay `_process`;
- no Main lookup or callback exists in RuntimeLoop/presentation scheduler;
- the clock scene has one production instance;
- registering a fake second tick owner makes the authority audit fail.

## Budget snapshot

`python tools/architecture/check_main_gd_budget.py --json` at the preflight SHA reports:

- physical lines: 15,469
- nonblank lines: 13,511
- methods: 915
- top-level variables: 94
- constants: 121
- top-level preloads: 15
- external Main caller occurrences: 1,652
- production Main reference files: 3

No production code was changed, so the runtime-loop ledger remains `pending`. No RuntimeLoop scene, script, test fixture, or double execution path was created.
