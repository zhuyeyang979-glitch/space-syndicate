# Card Resolution Transition Boundary Review

## Review scope

This review is analysis-only. It covers the transition boundary between `CardResolutionFrameDriver`, the production card-resolution owners, `GameRuntimeCoordinator`, `Main`, and the public card presentation surface. It does not authorize production changes and does not treat the current legacy path as an acceptable implementation.

Baseline reviewed: `dfcd841e51a2ae72d319a4aea2cb44bbe3f18922` on `codex/scene-first-remove-main-gd`.

## Baseline verdict

`NOT_READY_FOR_CUTOVER_ACCEPTANCE`

The baseline still has the exact blocker identified by RuntimeLoop preflight:

- `CardResolutionRuntimeController` emits untyped `Dictionary` commands whose discriminator is the string field `transition`.
- `CardResolutionFrameDriver` returns the command array to `Main`.
- `Main._process` iterates the array and dispatches through `_apply_card_resolution_controller_transition`.
- Main owns the transition switch, queue start/lock/complete flow, execution-intent bridge call, card effect routing, history mutations, public log writes, and direct overlay mutations.
- The legacy execution bridge receives `self` (Main) through `apply_intent(self, transaction)`.

This is the baseline to remove, not a design to preserve behind a facade.

## Baseline command inventory

The producer currently emits these ordered transition names:

1. `show_active`
2. `begin_counter`
3. `complete_active`
4. `start_next`
5. `show_group_window`
6. `enter_public_bid`
7. `enter_lock`
8. `all_ready_public_bid`
9. `all_ready_lock`
10. `all_ready_lock_batch`
11. `lock_batch`
12. `hide_overlay`

The producer has latch protection for active completion, start-next, lock-batch, overlay hiding, public-bid entry, and lock entry. The new sink must preserve these ordering semantics and add stable command/batch identity; it must not depend on the latches alone for exact-once mutation.

## Required boundary gates

### Sink must not become a replacement monolith

The sink may validate ordering, revision and command identity, then route to narrow owners. It must not absorb:

- card-effect formulas or handler implementations;
- player, district, monster, military, economy, weather or contract state;
- queue storage already owned by `CardResolutionQueueRuntimeService`;
- inventory storage;
- complete world snapshots or save ownership;
- UI node lookup or layout;
- frame timing.

A sink that contains a large `match handler_id` for all game effects is a failed cutover even if Main becomes smaller.

### No Main callback or fallback

The final production path must contain none of the following:

- `Callable(Main, ...)` or `Callable(self, ...)` passed to the sink as an execution hook;
- `Object`, `Node`, `Main`, `current_scene`, `/root/Main`, or method-name string in a transition command;
- `call/get/set/has_method` used to discover a Main method;
- signals connected back to a Main card helper;
- sink failure falling back to `_apply_card_resolution_controller_transition`, `_complete_active_card_resolution`, `_start_next_card_resolution`, or another Main wrapper;
- `apply_intent(self, transaction)` where `self` is Main.

### UI and presentation boundary

The sink must not directly access `GameScreen`, `OverlayLayer`, card-resolution labels, timer bars, artwork Controls, planet rails, or tree-wide `find_child` calls. A narrow scene-owned presentation port may consume only a sanitized receipt.

The public receipt may include public card identity, public phase, remaining public time, public target clue, public effect aftermath, public counterability and explicitly revealed ownership. It must not include unrevealed `player_index`, hand/slot contents, cash, discard state, private target facts, `true_owner`, `hidden_owner`, `owner_truth`, AI plan/score metadata, or the complete private queue entry.

### Exact-once and deterministic order

Acceptance requires evidence for all of the following:

- batch revision and order index are monotonic;
- stable deterministic command IDs originate at the producer, never from sink RNG/time/frame/UI state;
- duplicate IDs do not reapply gameplay, queue or presentation effects;
- stale revisions fail closed;
- commands are applied synchronously in producer order;
- gameplay routing does not use deferred signals;
- one resolution starts once and completes once;
- queue removal/promotion/lock occurs once;
- commitment, mana settlement, history append and world-effect receipts occur once;
- one public presentation receipt is published once;
- replay/save restoration does not make old applied commands eligible again.

### No dual execution

After cutover:

- Main calls only the coordinator's high-level frame API;
- Main never receives the command array;
- `_apply_card_resolution_controller_transition` has zero production references and is removed;
- the coordinator/frame driver/sink path is the only command application path;
- legacy Main signals, wrappers and queue caches do not receive a second write;
- no RuntimeLoop or second `_process` is introduced.

## Baseline hidden-information observations

The current overlay text intentionally says the actor is unknown unless `public_owner_revealed` is true. That rule must remain, but copying an entire queue entry into a public receipt would still leak `player_index`, slot index and other private fields even when UI text ignores them. Public receipt sanitization must therefore be structural and recursively tested, not merely a formatting convention.

Existing receipt sanitizers in `scripts/cards/v06` demonstrate forbidden-key scanning patterns, but the transition sink must use an explicit card-presentation contract rather than forwarding arbitrary gameplay receipts.

## Final-review checklist

- [ ] Scene-owned sink is production-composed exactly once.
- [ ] Command and receipt are explicit typed contracts.
- [ ] All 12 baseline command kinds have explicit handling or documented retirement.
- [ ] Sink routes effects to existing domain owners; it does not reimplement them.
- [ ] Sink has no UI node references and no direct `GameScreen`/`OverlayLayer` access.
- [ ] Presentation port accepts only visibility-safe receipts.
- [ ] Recursive privacy scan covers owner, cash, hand, discard, target and AI metadata.
- [ ] No Main reference/callback/fallback exists in sink, ports or commands.
- [ ] Main does not receive or iterate commands.
- [ ] No old/new dual execution or duplicate signal exists.
- [ ] Exact-once counters remain zero under duplicate and stale inputs.
- [ ] Full command ordering is asserted, not only command presence.
- [ ] Save/reload preserves applied-command lineage if a pending batch can survive save.
- [ ] Main metrics decline and no replacement monolith appears.
- [ ] RuntimeLoop remains absent.

## Final boundary verdict for this attempt

`CARD_RESOLUTION_TRANSITION_SINK_CUTOVER_BLOCKED`

The sole production writer stopped before changing production code. That is the correct boundary decision. The `complete_active` path still enters `Main._complete_active_card_resolution`, which calls `CardResolutionExecutionWorldBridge.apply_intent(self, transaction)` with Main as `self`. The bridge contains 35 literal dynamic access sites: 27 `world.call`, 1 `world.get`, 5 `world.set`, and 2 `world.get_node_or_null` operations. They span counter checks, active release, presentation completion, requirement/target revalidation, effect dispatch, commitment, aftermath, selection restoration, history, queue start/finish and batch promotion.

Moving that graph behind a new sink now would either preserve a Main callback/fallback or copy a second gameplay engine into the sink. Both are expressly forbidden. The minimum prerequisite is therefore a `CARD EXECUTION TYPED PORTS CUTOVER` that replaces every dynamic world dependency with a narrow scene-owned owner API before the transition sink is retried.

The blocked graph also lacks a formal presentation consumer for `show_active`, `show_group_window` and `hide_overlay`, and the producer still lacks stable command IDs, batch revision and order indexes. These gaps prevent a truthful exact-once claim.

## No-half-line / no-double-run verification

Final source and diff scans confirm:

- no `CardResolutionTransitionSink` class, script or scene was added;
- no typed transition command or receipt was partially introduced;
- `GameRuntimeCoordinator` composition was not changed by this attempt;
- `Main._process` still has the single existing card-frame call and single existing legacy command loop;
- no second card-frame tick or transition application path exists;
- no `RuntimeLoop` was created;
- no new UI target, signal callback, Callable, method-name callback or fallback was added;
- no production, scene or test file was modified by the sole writer;
- only the two analysis-only boundary review documents were added by this reviewer;
- unrelated pre-existing untracked Godot `.uid` files remain untouched.

The current legacy path is still architecturally blocked, but the repository was not made worse by a half-cutover.

## Required prerequisite owner set

Before retrying this cutover, introduce narrow typed owners/ports for:

1. execution command and receipt contracts;
2. requirement and target revalidation;
3. counter and queue lifecycle, including batch promotion;
4. field-driven effect dispatch to existing domain owners;
5. intel effects;
6. commitment, history and aftermath;
7. selection-context restoration;
8. visibility-safe card presentation receipts and their scene-owned consumer;
9. producer-owned deterministic command lineage.

After those ports replace all 35 dynamic Main access sites, rerun this review and require every checklist item above before declaring green.
