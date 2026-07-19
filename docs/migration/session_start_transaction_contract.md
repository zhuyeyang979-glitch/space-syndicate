# Session Start Transaction Contract

Status: `CONTRACT_READY_WITH_REQUIRED_API_GAPS`
Reviewed base: `2575fb4ac3192f8030c1719401531c582c9121c1`
Scope: setup/new-session transaction boundary only. This document does not claim full-run resume.

## Findings First

### [P0] The current start path destroys the active run before it knows that a replacement can start

`Main._new_game()` resets card resolution and the coordinator, clears `WorldSessionState.players` and `districts`, resets clocks, selection and victory, and only then constructs the replacement run (`scripts/main.gd:4373-4422`). A missing starter monster, failed production binding, or failed region-supply configuration returns after those mutations (`scripts/main.gd:4428-4432`, `scripts/main.gd:4472-4493`). The current path therefore cannot satisfy active-session failure isolation.

The coordinator reset is itself a broad destructive operation. It clears presentation query state, forced decisions, target choice, clock, pricing quotes, AI, monsters, military, weather, contracts, routes, commodity flow, mana, commodity inventory, organization, bankruptcy, victory, session, purchases, card inventory, card queues, execution and interaction state (`scripts/runtime/game_runtime_coordinator.gd:3804-3897`). It has no composite preflight, checkpoint or rollback API. `SessionStartTransactionCoordinator` must never call this method.

### [P0] There is no exclusive mutation barrier while checkpoints are captured and applied

`RuntimeLoop._process()` advances every frame without an operation barrier (`scripts/runtime/runtime_loop.gd:11-12`). The lifecycle phase only gates finished, forced-decision-blocked and paused sessions (`scripts/runtime/runtime_lifecycle_phase_coordinator.gd:13-35`); it has no session-start transaction lease. A live frame between two checkpoints can invalidate cross-owner consistency. A narrow runtime operation barrier is required before the first checkpoint and must block runtime ticks and gameplay commands without changing `GameSessionRuntimeController` lifecycle state.

### [P0] Several currently reset owners do not have exact runtime checkpoints

The active card queue has mutable current/next queues, active entry and sequence state but only exposes `reset_state()` (`scripts/runtime/card_resolution_queue_runtime_service.gd:7-18`, `scripts/runtime/card_resolution_queue_runtime_service.gd:41-51`). `CardMarketPricingRuntimeController` similarly owns active private quote records and counters but only exposes `reset_state()` (`scripts/runtime/card_market_pricing_runtime_controller.gd:11-20`, `scripts/runtime/card_market_pricing_runtime_controller.gd:35-40`). `ViewerPrivateFeedbackOwner` and `VisualCueRuntimeOwner` also have reset-only runtime state (`scripts/presentation/viewer_private_feedback_owner.gd:5-13`, `scripts/runtime/visual_cue_runtime_owner.gd:40`). These states cannot be cleared before commit until an exact checkpoint exists; presentation-only state should instead be cleared after commit.

### [P0] Existing GameSession save data is not an exact active-session rollback checkpoint

`begin_session()` mutates the lifecycle to `error` on invalid input and resets the world clock while transitioning to running (`scripts/runtime/game_session_runtime_controller.gd:60-76`). `to_save_data()` captures public session fields and world time (`scripts/runtime/game_session_runtime_controller.gd:129-144`) but omits `_save_state`, `_dirty_reason`, `_operation_sequence`, `_active_operation` and `_last_operation` declared at `scripts/runtime/game_session_runtime_controller.gd:31-36`. Rolling back through `apply_save_data()` also forces save state to clean (`scripts/runtime/game_session_runtime_controller.gd:147-172`). A dedicated exact checkpoint and a preflighted, deterministic session commit API are mandatory.

### [P1] Current RNG use cannot support a failed-start zero-delta guarantee

Random setup roles consume the live `RunRngService` directly (`scripts/main.gd:7280-7313`). World generation also mutates live `WorldSessionState` while drawing from the same RNG (`scripts/main.gd:3931-3998`). `RunRngService` can save and restore its state, but restoring emits `state_restored` and increments runtime restore metrics (`scripts/runtime/run_rng_service.gd:37-40`, `scripts/runtime/run_rng_service.gd:96-116`). It has no detached fork/reservation/commit contract. Plan construction therefore needs a pure detached fork and a checked terminal-state commit rather than live draws followed by compensating restore.

### [P1] Some multi-owner helpers mutate before reporting readiness

`refresh_v06_production_player_bindings()` initializes the commodity belt, configures organization, bootstraps public demand, configures the economic adapter and refreshes additional adapters before it computes `binding_ready` (`scripts/runtime/game_runtime_coordinator.gd:629-690`). This helper cannot be an apply participant. Its stateful work must be split into explicit owner subplans; dependency wiring can remain a post-apply rebind.

`RegionSupplyRuntimeController.configure()` validates its inputs first, but then replaces all live rack/bag state while constructing listings (`scripts/runtime/region_supply_runtime_controller.gd:45-108`). It needs a detached plan/probe plus an exact apply checkpoint; calling `configure()` directly is not transactional.

`ProductMarketRuntimeController.reset_state()` immediately generates a live market (`scripts/runtime/product_market_runtime_controller.gd:159-168`), and generation performs weighted random selection (`scripts/runtime/product_market_runtime_controller.gd:216-225`). Market generation belongs in the detached session plan, not in owner apply.

### [P1] Start announcements are emitted before the session commits

The current path appends seven public start messages before `begin_session()` (`scripts/main.gd:4507-4529`). Public log, visual cues, audio, page closure and presentation refresh must be delayed until every business owner and the RNG finalizer have committed.

## Architectural Decision

Create one scene-owned `SessionStartTransactionCoordinator` with explicit typed dependencies. It is an operation coordinator, not a gameplay state owner. It must not use `V06SaveOwnerRegistry`, dynamic groups, `current_scene`, `/root/Main`, or a second `GameRuntimeCoordinator`.

The existing save transaction is a useful pattern: it preflights all children, captures checkpoints, applies in a fixed order and rolls touched owners back in reverse (`scripts/runtime/session_envelope_save_owner.gd:67-162`, `scripts/runtime/session_envelope_save_owner.gd:222-252`). It is not reusable as the new-session registry because several active-run owners are intentionally unsupported in the save registry, including routes, card inventory, card queue, military and AI (`scenes/runtime/V06SaveOwnerRegistry.tscn:43-51`, `scenes/runtime/V06SaveOwnerRegistry.tscn:65-75`, `scenes/runtime/V06SaveOwnerRegistry.tscn:112-122`, `scenes/runtime/V06SaveOwnerRegistry.tscn:143-151`).

The transaction coordinator must keep only an operational exact-once journal. It must not store players, districts, cards, routes, monsters, economy, RNG state or setup draft state.

## Required Narrow Participant Contract

Every authoritative owner in the apply order must expose semantic equivalents of:

```gdscript
func preflight_new_session(owner_plan: Dictionary, context: Dictionary) -> Dictionary
func capture_new_session_checkpoint() -> Dictionary
func apply_new_session_plan(owner_plan: Dictionary, context: Dictionary) -> Dictionary
func rollback_new_session_checkpoint(checkpoint: Dictionary, context: Dictionary) -> Dictionary
```

Requirements:

- Preflight is data-only and mutation-free.
- Checkpoint is exact for every field affected by start, including private and in-flight state.
- Apply consumes only its prevalidated subplan and performs no RNG draw, UI access, public logging, audio or presentation refresh.
- Rollback can be repeated and restores the byte-equivalent behavioral state.
- Apply and rollback return typed receipts containing owner ID, request ID, fingerprint, expected version and resulting version.
- Existing `to_save_data/apply_save_data` may back the checkpoint only where tests prove complete exact runtime roundtrip. A save payload that omits runtime-only behavior is insufficient.

## Runtime Operation Barrier

Before checkpointing, acquire a typed exclusive lease such as:

```gdscript
acquire_session_start_barrier(request_id, expected_session_revision)
release_session_start_barrier(request_id)
```

While held:

- `RuntimeLoop` produces a blocked receipt and does not advance world time or domains.
- Runtime command submission fails closed with `session_start_in_progress`.
- UI read-only presentation may continue from the old committed snapshot.
- `GameSessionRuntimeController` remains in its original running/paused/finished state.
- No forced decision is resolved or discarded.

The lease is operational, not a second lifecycle or world-state owner. Failure releases it only after rollback completes; success releases it only after commit-only publication is complete.

## Transaction Phases

1. **Request validation**: validate request ID, fingerprint, draft revision, active-session revision and source context.
2. **Pure planning**: build `SessionStartPlan` from detached catalog facts and an RNG fork. No live owner changes.
3. **All preflight**: invoke every owner preflight in the machine order below. Any failure ends with zero checkpoints and zero apply.
4. **Acquire barrier**: block live ticks and commands, then recheck active-session revision and RNG baseline.
5. **All checkpoints**: capture every authoritative participant before the first apply. Any checkpoint failure releases the barrier with apply count zero.
6. **Ordered apply**: apply prevalidated subplans in the fixed order below. `GameSessionRuntimeController` is the last business owner.
7. **RNG finalization**: commit the reserved fork terminal state with an expected-baseline compare. It must be non-random and exact-once. Failure rolls back GameSession and all touched owners.
8. **Commit-only publication**: emit `session_started`, clear old presentation-only state, rebuild derived caches, publish start receipts, refresh presentation once, play audio once, close Setup once.
9. **Release barrier**: resume the single existing RuntimeLoop.

## Fixed Owner Apply Order

The JSON companion is authoritative and machine-readable. The order is dependency-driven:

1. `world_session_state`
2. `world_effective_clock`
3. card resolution state: controller, queue, execution, public history, private annotations, target choice and purchase windows
4. region topology/infrastructure and deterministic supply
5. player mana, commodity inventory and organization
6. economy: commodity flow, contracts, market, GDP derivative and weather
7. actors: monsters, military and AI
8. pricing, bankruptcy and victory
9. table selection
10. `game_session_runtime` last

`RouteNetworkRuntimeController` is a derived cache owner: its save payload explicitly says `derived_cache_only` and `apply_save_data()` clears and rebuilds from current topology (`scripts/runtime/route_network_runtime_controller.gd:187-213`). It must not be mutated during the rollback-capable business phase. Rebuild it after authoritative commit; on rollback it is rebuilt only after the old authoritative topology is restored.

Likewise `CommoditySushiTrackRuntimeService`, forced-decision candidates, public/private feedback, visual cues and presentation scheduling are derived/presentation state. They are commit-only and never checkpointed as business owners.

## Reverse Rollback

Rollback is the exact reverse of the touched business-owner order. The coordinator must continue after an individual rollback failure, collect every failure, keep the runtime barrier held, and return `rollback_complete=false`. It must never resume runtime or present either world when rollback is incomplete.

RNG finalization, if already touched, is rolled back first through its exact transaction checkpoint. `GameSessionRuntimeController` then rolls back before dependent owners. `WorldSessionState` rolls back last so every dependent owner sees the replacement world until its own old state has been restored.

Derived cache recovery happens only after authoritative rollback completes: rebuild routes from the old world, resynchronize forced decisions, then refresh presentation once. No start log, audio or success signal is emitted on failure.

## Exact-Once Contract

The coordinator keeps a bounded operational journal keyed by `request_id`:

- same ID + same fingerprint + `succeeded`: return the stored receipt; apply count stays zero;
- same ID + same fingerprint + active operation: return `in_progress`;
- same ID + different fingerprint: reject `request_id_collision`;
- failed request: return the stored terminal failure; retry requires a new request ID;
- stale draft, active-session revision or RNG baseline: reject before checkpoint;
- concurrent distinct request: reject `session_start_busy`.

The journal stores receipts and fingerprints only. It is not saved and owns no gameplay state.

## Commit-Only Side Effects

After GameSession and RNG succeed, perform exactly once:

1. publish the delayed GameSession `session_started` signal;
2. rebind non-state adapters to the existing owner nodes without bootstrapping data;
3. rebuild the route cache from committed topology;
4. resynchronize forced decisions from committed owners;
5. clear old public log/private feedback and publish typed start receipts;
6. clear visual cues and add the initial ingress cue;
7. reset the commodity sushi presentation projection;
8. request one full table presentation refresh;
9. play one start audio cue;
10. close Setup and show the table;
11. release the runtime barrier.

All dependencies for these operations must be checked during preflight. None may trigger gameplay initialization or RNG.

## Current API Reuse and Gaps

### Directly reusable with a new semantic wrapper

- `WorldSessionState.capture_runtime_checkpoint/restore_runtime_checkpoint` already capture players, districts, time and geometry (`scripts/runtime/world_session_state.gd:400-448`). Add only plan validation/apply; do not create a second world owner.
- Card resolution controller has validated exact transition save/apply (`scripts/runtime/card_resolution_runtime_controller.gd:358-473`).
- Card execution and public history expose strict preflight plus save/apply (`scripts/runtime/card_resolution_execution_runtime_service.gd:419-453`, `scripts/runtime/card_resolution_history_runtime_service.gd:173-189`).
- Card-history annotations expose exact runtime checkpoint/restore (`scripts/runtime/card_history_private_annotation_service.gd:453-470`).
- Region supply, infrastructure, commodity flow, mana, commodity inventory, organization, monsters, weather, victory and bankruptcy have full-state save/apply candidates. Each still needs a new-session preflight wrapper and an exact-runtime roundtrip test before use.

### Minimal APIs required before implementation can be green

- Runtime operation barrier on the existing runtime loop/command boundary.
- Detached RNG fork, terminal state reservation, exact commit and exact checkpoint restore.
- Exact GameSession transaction checkpoint including dirty and operation fields; deterministic session ID from the plan; no `Time.get_ticks_msec()` during apply.
- Exact checkpoints for card queue, card-market quotes, AI runtime receipts/bootstrap counters, purchase/hand/effect transient state, and any other state reset by the current coordinator.
- Detached world, product-market, region-supply and public-demand subplans. No owner may generate randomness while applying.
- Split `refresh_v06_production_player_bindings()` into mutation-free dependency rebind plus explicit owner subplans.
- Weather telemetry must not be cleared before commit because weather save data does not restore the external telemetry service (`scripts/runtime/weather_runtime_controller.gd:107-117`, `scripts/runtime/weather_runtime_controller.gd:485-524`).
- Main-only selection/purchase/timer fields must move to their existing typed owners or dedicated narrow owners before `_new_game` is deleted. They cannot be hidden inside the transaction coordinator.

## Blocking Verdict

The transaction design is implementable without changing gameplay rules, but the current source is **not transaction-ready**. Production cutover must remain blocked until all hard blockers in the JSON companion are resolved and fault tests prove active-session byte-equivalent restoration. In particular, calling the current broad `GameRuntimeCoordinator.reset_state()`, `Main._new_game()`, `ProductMarketRuntimeController.reset_state()`, `RegionSupplyRuntimeController.configure()` or `refresh_v06_production_player_bindings()` from the new transaction is forbidden.

The required blocked status, if implementation attempts to proceed without those APIs, is:

`SETUP_SESSION_START_BLOCKED_BY_NONTRANSACTIONAL_OWNER`
