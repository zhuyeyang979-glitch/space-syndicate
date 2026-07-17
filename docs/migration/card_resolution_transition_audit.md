# Card Resolution Transition Audit

Audit status: **analysis complete; production cutover not performed by this audit**.

- Branch: `codex/scene-first-remove-main-gd`
- Audited HEAD: `dfcd841e51a2ae72d319a4aea2cb44bbe3f18922`
- Production frame source: `res://scripts/runtime/card_resolution_frame_driver.gd`
- Timing/state producer: `res://scripts/runtime/card_resolution_runtime_controller.gd`
- Current transition consumer: `res://scripts/main.gd::_apply_card_resolution_controller_transition`
- Current execution orchestrator: `res://scripts/runtime/card_resolution_execution_runtime_service.gd`
- Current execution adapter: `res://scripts/runtime/card_resolution_execution_world_bridge.gd`
- Machine-readable companion: `card_resolution_transition_audit.json`

The worktree had no tracked production diff when this audit began. Pre-existing untracked Godot `.uid` files and the boundary review being written by another analysis agent were not touched.

## Executive verdict

The transition cutover is not a one-method move. The current path has two nested command protocols:

1. `CardResolutionRuntimeController.tick()` emits **12 untyped frame-transition kinds**.
2. `complete_active` enters `CardResolutionExecutionRuntimeService`, which declares **13 ordered execution-intent kinds** and emits one branch-specific ordered subset per resolution.

The frame commands are plain dictionaries containing only `transition`, a derived `phase`, and optional details. They have no deterministic command ID, frame/batch revision, order index, visibility scope, or explicit mutation/presentation flags. `CardResolutionFrameDriver._tick_count` is diagnostic only and is not placed in a command. Producer latches reduce repeated generation but do not give a future sink an exact-once identity.

The existing `CardResolutionExecutionWorldBridge.apply_intent(world, transaction)` cannot be reused as the transition sink. It accepts an arbitrary `world: Node` and performs:

- 27 dynamic `world.call("...")` operations;
- 1 dynamic `world.get("...")` operation;
- 5 dynamic `world.set("...")` operations;
- 2 hard-coded `world.get_node_or_null(...)` lookups.

Those calls reach Main-private queue, execution, inventory/cash, history, logging, presentation, target validation and effect-dispatch helpers. Reusing this bridge would preserve the exact Main callback forbidden by the extinction policy.

## Current production chain

```text
Main._process(world_delta)
  -> GameRuntimeCoordinator.advance_card_resolution_frame(world_delta)
  -> CardResolutionFrameDriver.advance_world(world_delta)
  -> CardResolutionRuntimeController.tick(world_delta, facts)
  -> Array[Dictionary transition command]
  -> Main iterates the array in order
  -> Main._apply_card_resolution_controller_transition(command)
       -> presentation-only Main helpers, or
       -> Main queue/batch helpers, or
       -> Main._complete_active_card_resolution()
            -> CardResolutionExecutionRuntimeService plan/advance/finalize
            -> Main._apply_card_resolution_execution_intent()
            -> CardResolutionExecutionWorldBridge.apply_intent(Main, transaction)
            -> dynamic Main callback for each intent
```

`Main._process` is still the single gameplay tick path. No production `RuntimeLoop` exists at this audit HEAD.

## Frame-transition declaration and ordering

All commands are declared indirectly by `CardResolutionRuntimeController._command(transition, details)`. `_command` returns a dictionary and copies arbitrary detail keys into it. The authoritative producer order is append order inside `tick()` and `_advance_all_ready_one_phase()`.

| Transition kind | Producer condition and exact order | Current Main consumer | Classification | Current side effects |
| --- | --- | --- | --- | --- |
| `show_active` | First command on every active reveal/counter frame | `_show_card_resolution_overlay(active, remaining)` | presentation receipt | Overlay visibility/content, right-rail suppression, timer bar, visual-stage state. No queue/world mutation. |
| `begin_counter` | After `show_active` when reveal expires and the active entry is counterable | `_announce_card_counter_response_window()` | public presentation/log | Public log and overlay refresh. Counter timing was already mutated by the controller before emission. |
| `complete_active` | After `show_active`; after `begin_counter` only when the counter duration is already zero | `_complete_active_card_resolution()` | gameplay/queue/inventory/presentation orchestration | Enters the branch-specific execution transaction selected from the 13 declared intent kinds described below. |
| `start_next` | Sole command when `batch_locked` and no active entry exists | `_start_next_card_resolution()` | queue mutation + presentation | Pops next queue entry into active, skips invalid entries, releases their mana reservations, starts display, shows overlay. |
| `hide_overlay` | Sole command when queue is empty and hide latch is clear | `_hide_card_resolution_overlay()` | presentation receipt | Hides overlay and clears Main visual-stage fields. |
| `show_group_window` | Last phase-display command for normal/ready planning and bidding frames | `_show_card_batch_lobby_overlay()` | presentation receipt | Opens/updates group/bid surface. |
| `enter_public_bid` | Before `show_group_window` when boundary is crossed or all players are ready in planning | Main `_log(...)` | public log receipt | Public phase-transition message only. Controller already changes phase/timer. |
| `enter_lock` | Before `show_group_window` when lock boundary is crossed or all players are ready in public bid | Main `_log(...)` | public log receipt | Public phase-transition message only. Controller already changes phase/timer. |
| `all_ready_public_bid` | First of `[all_ready_public_bid, enter_public_bid, show_group_window]` | Main `_log(...)` | public log receipt | Public readiness message only. |
| `all_ready_lock` | First of `[all_ready_lock, enter_lock, show_group_window]` | Main `_log(...)` | public log receipt | Public readiness message only. |
| `all_ready_lock_batch` | First of `[all_ready_lock_batch, lock_batch]` | Main `_log(...)` | public log receipt | Public early-lock message only. |
| `lock_batch` | After `show_group_window` on normal timeout; after `all_ready_lock_batch` on unanimous readiness | `_lock_card_resolution_batch()` | queue mutation + public log + start | Sorts and annotates the queue, writes timing mirrors, logs, then starts the first resolution. |

Large deltas may cross both phase boundaries in one tick. The exact order is:

```text
enter_public_bid -> enter_lock -> show_group_window -> lock_batch
```

The command contract currently has no sink-level way to distinguish a legitimate repeated `show_active` from a duplicated mutation command. The new contract needs stable identity at least for mutating/log transitions; presentation progress may either receive stable per-frame identity or be explicitly modeled as replaceable state.

## `complete_active` execution-intent matrix

`CardResolutionExecutionRuntimeService` owns the intent order, inflight/completed in-memory guards, and branching. Main owns the actual application through the dynamic world bridge.

| Intent | Mandatory predecessor / branch | Current mutation and side effects | Current true owner or missing owner |
| --- | --- | --- | --- |
| `counter_check` | First | Main records last resolution player, searches current/next queues, removes a matching counter, settles counter cash/refund/cooldown/mana, appends the counter to history, logs and emits visual callout | Queue owner exists; cooldown/mana owners exist; cash/ledger/history/public receipt routing still Main-coupled |
| `release_active` | After counter check | Calls queue `complete_active(resolution_id)` | `CardResolutionQueueRuntimeService` |
| `finish_presentation` | After active release | Clears controller timing flags and hides overlay | Timing owner exists; narrow card presentation receipt port is missing |
| `revalidate_requirement` | Non-countered only | Restores persistent skill into player slot, restores contract selection, re-runs eligibility, logs rejection | Inventory/session/eligibility/contract owners partly exist; orchestration and log receipt are Main-coupled |
| `revalidate_target` | Requirement valid | Restores selected player/district/product, publishes resolution log and visual cue, validates monster/player target | Selection, monster and visual owners exist; typed target-validation/public-presentation port is missing |
| `dispatch_effect` | Target valid | Routes the concrete card effect | Several typed owners exist; Main still owns the central handler switch and multiple handlers |
| `finish_card_commitment` | Countered, invalid or dispatched | Finalizes card use, persistent cooldown/nonpersistent removal, player cooldown and weather response | Cooldown/weather owners exist; inventory/cash/commitment orchestrator remains Main-coupled |
| `create_aftermath` | Countered or target-revalidation path | Patches history entry clue/style and emits visual aftermath | Visual owner exists; public history/presentation receipt owner is missing |
| `restore_context` | After commitment/aftermath | Restores TableSelectionState and contract selection | `TableSelectionState` and `ContractRuntimeController`; current adapter still discovers them through Main |
| `append_history` | After context restore | Appends resolved entry, trims to 24, reports current queue count | No scene-owned resolved-card-history owner; history is still a Main array |
| `start_next` | History appended and current queue non-empty | Starts next queue entry and its display | Queue/timing owners exist; orchestration and presentation still Main-coupled |
| `finish_batch` | History appended and current queue empty | Resets controller batch state, hides overlay, reports waiting count | Queue/timing/presentation orchestration remains Main-coupled |
| `promote_next_batch` | Finish-batch receipt reports waiting entries | Promotes next queue, opens next group window, logs and shows group surface | Queue/timing owners exist; public log/presentation port is missing |

The service can emit 13 names including the initial `counter_check` and the 12 subsequent constants shown above; the production transaction executes one ordered path, not all branches. The implementation must cover every declared intent constant.

### Exact branch sequences

Normal resolved card:

```text
counter_check -> release_active -> finish_presentation
-> revalidate_requirement -> revalidate_target -> dispatch_effect
-> finish_card_commitment -> create_aftermath -> restore_context
-> append_history -> (start_next | finish_batch [-> promote_next_batch])
```

Countered card:

```text
counter_check -> release_active -> finish_presentation
-> finish_card_commitment -> create_aftermath -> restore_context
-> append_history -> continuation
```

Requirement invalid:

```text
counter_check -> release_active -> finish_presentation
-> revalidate_requirement -> finish_card_commitment -> restore_context
-> append_history -> continuation
```

Target invalid:

```text
counter_check -> release_active -> finish_presentation
-> revalidate_requirement -> revalidate_target
-> finish_card_commitment -> create_aftermath -> restore_context
-> append_history -> continuation
```

## Effect-dispatch ownership matrix

`Main._apply_card_resolution_effect_request()` is still the central fallback switch.

| Handler family | Current route | Cutover implication |
| --- | --- | --- |
| `target_monster` | Main `_resolve_targeted_skill` -> monster or military controller | Create typed targeted-effect port; do not call Main. |
| `target_player` / `player_hand_disrupt` / `player_hand_steal` | Main player-hand interaction plan/commit plus private/public event forwarding | Route through existing player-hand interaction owner and visibility-safe receipt publisher. |
| `product_speculation`, `product_futures`, `city_gdp_derivative`, `product_contract_boon`, `area_trade_contract`, `market_stabilize`, `news_event`, `product_growth_boon` | `CardEconomyProductRouteEffectRuntimeService` then WorldBridge | Service is reusable. Its bridge still accepts a world solely to discover ContractRuntimeController; inject the contract controller instead. |
| `monster_card` | Direct Main call to `MonsterRuntimeController._summon_monster_from_card` | Expose a public typed card-effect API; do not rely on underscored controller method. |
| `public_facility` | Coordinator `submit_public_facility_card` | Existing typed coordinator API is suitable. |
| `monster_bound_action` | Direct Main call to private monster method | Expose a typed monster card-effect API. |
| `military_force`, `military_command` | Direct controller APIs | Bind controllers to the effect router; retain their authority. |
| `card_counter` | Main logs inactive counter failure | Return a typed failure receipt; presentation/log port renders it. |
| `weather_control` | Direct weather controller API | Bind weather controller to the effect router. |
| `intel_city_reveal`, `intel_card_trace` | Main-private intel helpers and Main-owned selected resolution/history | Requires a typed intel card-effect port and scene-owned public/private card-history access. |
| `intel_contract_trace` | Contract controller plus Main-selected player/resolution | Pass explicit actor/resolution IDs in the command; never infer them from Main selection. |
| `supply_draw` | Main stub only; always logs unavailable and does not report a boolean assignment | Keep explicit fail-closed typed receipt until a real inventory transaction exists. Do not invent a draw mutation. |
| unknown handler | Main logs unsupported and returns unresolved | Preserve fail-closed behavior via typed unsupported-handler receipt. |

## Entry-point audit

### `_apply_card_resolution_controller_transition`

- Sole production consumer: `Main._process` iterates the array returned by `GameRuntimeCoordinator.advance_card_resolution_frame`.
- It mixes presentation, public log and gameplay/queue commands in one string switch.
- It has no command identity, revision validation, stale-command rejection or duplicate-command guard.
- It must be deleted once the Coordinator advances the frame and applies the ordered batch internally.

### `_complete_active_card_resolution`

- Correctly delegates intent ordering to `CardResolutionExecutionRuntimeService`.
- Incorrectly remains the loop and transaction driver in Main.
- Uses a hard guard of 20 iterations; the longest current branch is below that limit.
- Applies every intent through `CardResolutionExecutionWorldBridge.apply_intent(self, transaction)`.
- Finalizes mana reservation after execution and always requests Main `_refresh_ui`.
- The future sink should absorb this orchestration without absorbing concrete domain rules.

### `_queue_skill_resolution`

This is submission, not a frame transition, but it is part of the same Main card-execution surface and is a deletion candidate required by the task.

It currently combines:

- player/slot/elimination checks;
- v0.6 special-card forwarding;
- eligibility and target/counter classification;
- contract/futures/GDP-derivative pre-authoring;
- public-facility target capture;
- queue plan and PlayerMana reservation;
- inventory plan/commit;
- queue commit;
- direct player-state replacement;
- play-cost cash mutation and spend ledger;
- controller ready/timing changes;
- public logging and UI refresh/show;
- immediate lock/start in zero-duration/headless cases.

Production callers include Main human play/target flows and `AiRuntimeController`, whose `_queue_skill_resolution` currently performs `_call_world(&"_queue_skill_resolution", ...)`. A successful cutover therefore needs one typed `CardPlaySubmissionPort` shared by human and AI; migrating only the frame sink leaves a live AI/Main dynamic callback.

### `_apply_card_resolution_effect_request`

- Central concrete-effect switch in Main.
- Routes eight economy/product/route handlers through an existing service, but every other handler remains Main-dispatched.
- Computes `forced_decision_handoff` by comparing Main-visible monster wager counts before/after.
- Must become a typed effect router bound to existing owners. It must not be copied verbatim into the sink.

### `_use_skill`

- Main presentation/action entry point used by action strings, drag/drop, quick actions and two stored `Callable(self, "_use_skill")` values.
- Performs pending-target gates, player/slot lookup, eligibility, counter conversion and target-choice opening before submission.
- It is also outside the frame-transition protocol. Replace it with an explicit action request routed through the existing target-choice owner and typed submission port; do not leave a `Callable` back into Main.

## Dynamic Main dependency inventory

`CardResolutionExecutionWorldBridge` dynamically references these Main symbols:

```text
_add_action_callout
_add_card_resolution_aftermath_clue
_apply_card_resolution_effect_request
_authorize_card_play
_card_display_name
_card_play_requirement_snapshot
_card_resolution_active_entry
_card_resolution_commitment_receipt
_card_resolution_current_queue
_card_resolution_history_receipt
_card_resolution_next_queue
_card_resolution_presentation_snapshot
_card_resolution_queue_service_node
_district_center
_entity_world_position
_hide_card_resolution_overlay
_log
_promote_next_card_resolution_batch
_reset_card_resolution_batch_state
_resolve_reactive_counter_for_entry
_start_next_card_resolution
last_card_resolution_player_index (get/set)
card_resolution_auction_open (set)
card_resolution_timer (set)
card_resolution_counter_window_active (set)
card_resolution_counter_timer (set)
```

It also performs hard-coded scene lookup of `MonsterRuntimeController` and `ContractRuntimeController` below `GameRuntimeCoordinator`.

Additional live dynamic dependencies relevant to this atomic cutover:

- `AiRuntimeController._queue_skill_resolution` -> `_call_world(&"_queue_skill_resolution", ...)`.
- Main primary action snapshots contain `Callable(self, "_use_skill")`.
- Main owns compatibility `_get/_set` adapters for queue/active/timing properties; tests and legacy bridges still use them.
- `ContractRuntimeWorldBridge` reads/writes `resolved_card_history` through Main and triggers `_refresh_ui`; a new history owner must be shared rather than duplicated.

## Ownership and save/replay findings

| State | Current authority | Save/replay status | Cutover requirement |
| --- | --- | --- | --- |
| Card timing/window state | `CardResolutionRuntimeController` | `to_save_data/apply_save_data` | Preserve; add producer command sequence/revision persistence if pending commands can cross save. |
| Current/active/next queue and resolution sequence | `CardResolutionQueueRuntimeService` | Legacy save snapshot restores queue and revision is recomputed | Preserve sole queue owner; all start/complete/promote/remove operations go through typed API. |
| Card inventory at submission | `CardInventoryRuntimeService` plus `WorldSessionState.players` | Player state is saved | Preserve two-phase plan/commit and exact slot fingerprint. |
| Mana reservation | `PlayerManaRuntimeController` | Dedicated save owner | Settle/release exactly once from typed execution receipt. |
| Execution inflight/completed IDs | `CardResolutionExecutionRuntimeService` | **Not saved**; reset clears both dictionaries | This is an exact-once replay gap. Persist a compact execution journal or derive a deterministic replay decision from queue/history/transaction lineage. |
| Resolved card history | Main `resolved_card_history` | Saved/restored by Main compatibility adapter | Create one scene-owned history owner; contract and intel consumers must use the same owner. |
| Public logs | Main `log_lines` | Saved/restored by Main | Create visibility-safe card log/presentation receipt port; never publish true actor/owner fields. |
| Overlay/card-resolution presentation | Main node references and visual-stage fields | Transient; rebuilt | Create narrow scene-owned card presentation port. Do not fold general table refresh into it. |

An active entry is restored from the queue snapshot, but the execution service's completed/inflight journal is not restored. Because `recover_from_active` has no production caller, a save taken between intent effects could replay a mutation after load. A deterministic command ID alone does not close this gap unless the applied-command journal or owner-level transaction lineage survives save/load.

## Required typed command fields

The current dictionary should be replaced with a small typed command (`RefCounted`, `Resource`, or the repository's established typed command style) containing only fields proven by current consumers:

- `kind`;
- deterministic `command_id` derived from window sequence, controller/frame revision, active resolution ID and order index;
- `frame_revision` or `batch_revision`;
- `order_index`;
- `resolution_id` when an active card is involved;
- `window_sequence` when a group window is involved;
- `stage`, `remaining`, `window_phase` where currently produced;
- visibility scope;
- `requires_gameplay_mutation`;
- `requires_presentation_receipt`.

Do not include a `Callable`, method-name string, arbitrary Object, Main node, GameScreen node, or nested callback in the command.

## Minimum scene-owned ports

The cutover can remain one atomic program without creating a new monolith if the sink is bound to narrow existing/new ports:

1. `CardResolutionQueueRuntimeService`: lock/start/complete/remove/promote and snapshots.
2. `CardResolutionExecutionRuntimeService`: intent order and transaction validation.
3. `CardPlayEligibilityRuntimeService`: pure revalidation facts.
4. `CardInventoryRuntimeService` + `PlayerManaRuntimeController` + cooldown owner: commitment finalization.
5. Typed card-effect router bound to monster, military, weather, facility, economy/product/route, contract, player-hand and intel ports.
6. Scene-owned `CardResolutionHistoryOwner`: append/update/lookup/public projection/save journal.
7. Narrow `CardResolutionPresentationPort`: overlay/group-window/log/aftermath receipts only.
8. Typed `CardPlaySubmissionPort`: shared human/AI queue submission; required if `_queue_skill_resolution` is deleted in the same cutover.

The sink must not own world state, card effects, UI nodes, logs, history storage, timing, queue storage, inventory or save schema. It should validate and route an ordered batch, then return a batch receipt.

## Exact blockers and negative gates

The production implementer must not declare green while any of these remain:

1. `CardResolutionExecutionWorldBridge.apply_intent(world, ...)` accepts Main or calls/gets/sets Main.
2. `Main._apply_card_resolution_controller_transition` still exists or Main sees a command array.
3. `Main._complete_active_card_resolution` still drives the intent loop.
4. `Main._apply_card_resolution_effect_request` remains a concrete handler switch.
5. AI still submits through `_call_world(&"_queue_skill_resolution", ...)`.
6. Human action snapshots still store `Callable(self, "_use_skill")`.
7. A new sink calls Main on failure or publishes both new and legacy receipts.
8. Queue, inventory, cash, mana, history or presentation is written by both old and new paths.
9. Applied command/intent IDs are not persisted or otherwise protected across active-entry save/load.
10. Public receipts contain `player_index` as the true anonymous actor, hidden owner, exact rival cash/hand, AI plan, or private target-choice data.

Recommended cutover order:

```text
typed command identity/order
-> scene-owned public history and card presentation receipt ports
-> typed execution-intent ports (no world Node)
-> typed concrete-effect router
-> typed human/AI submission port
-> Coordinator advances frame and applies ordered batch internally
-> remove Main transition/complete/effect/submission/use helpers and dynamic bridge
-> negative dependency + exact-once + save/replay + privacy gates
```

This audit does not authorize a partial production sink. If the typed history, presentation, effect and submission ports cannot all be completed in the atomic cutover, the correct result is a preflight blocker with Main remaining the single path, not a new sink that falls back to Main.
