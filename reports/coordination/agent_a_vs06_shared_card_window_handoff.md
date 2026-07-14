# Agent A VS06-A11 Shared Card Window Handoff

## Scope completed

The v0.6 shared card cadence is now authored as standard `30/20/5/5` and opening sequences `0/1/2` as `45/35/5/5`. The ordinary submission limit is one; a named explicit capability may raise it to at most three.

Changed paths:

- `scripts/cards/shared_card_group_window.gd`
- `scripts/runtime/card_resolution_runtime_controller.gd`
- `scenes/runtime/CardResolutionRuntimeController.tscn`
- `scripts/runtime/card_resolution_queue_runtime_service.gd` (A11 cadence, card-limit, and sequence additions only; pre-existing shared-file changes were preserved)
- `scripts/rules/space_syndicate_ruleset_profile_v06.gd`
- `resources/rules/space_syndicate_ruleset_v06.tres`
- `scripts/rules/ruleset_v06_validator.gd`
- `tests/shared_card_group_window_test.gd`
- `tests/card_resolution_runtime_controller_test.gd`
- `tests/card_resolution_queue_cadence_v06_test.gd`
- `docs/shared_card_window_cadence_v06.md`

## Stable APIs

- `SharedCardGroupWindow.cadence_for_sequence(window_sequence)` returns the pure-data authored cadence.
- `SharedCardGroupWindow.phase_for_remaining(remaining, lock, public_bid)` returns `planning`, `public_bid`, `lock`, or `closed`.
- `SharedCardGroupWindow.can_submit(..., public_bid_seconds, extra_submission_capability)` consumes only the Queue-normalized capability. Raw request limits are not authority.
- `CardResolutionQueueRuntimeService.plan_submission(request, facts)` accepts extra ordinary cards only from `facts.extra_submission_capability` with authoritative flag, matching owner revision, actor/player/window bindings, active range, and valid base/bonus/effective/hard-cap values.
- `CardResolutionRuntimeController.cadence_snapshot(sequence)` exposes the active cadence without acquiring gameplay ownership.
- `CardResolutionQueueRuntimeService` persists `card_group_last_window_sequence` through its existing legacy save envelope.

## Ownership evidence

- Controller debug snapshot reports `owns_cards=false`, `owns_cash=false`, `owns_bids=false`, and `owns_queue=false`.
- Queue debug snapshot keeps `priority_bid_authority=false`, `cash_authority=false`, and `inventory_authority=false`.
- First queue batch is sequence `0`; same-batch entries remain `0`; promotion produces `1`; a later idle batch produces `2`; save/load then produces `3`.
- `organize_seconds` remains only a compatibility alias for `planning_seconds`.

## Focused validation

Godot 4.7 was run with isolated `APPDATA` and `LOCALAPPDATA`:

- `tests/shared_card_group_window_test.gd`: PASS, 24 checks, 0 failures.
- `tests/card_resolution_runtime_controller_test.gd`: PASS, 26 checks, 0 failures.
- `tests/card_resolution_queue_cadence_v06_test.gd`: PASS, 23 checks, 0 failures; covers forged request limit, stale revision, early activation, wrong actor, wrong window, legal +1, hard cap 3, reactive counter isolation, sequence, and save/load.
- `git diff --check` on A11 paths: PASS.

Per coordinator policy, no full regression, MCP, headed run, default `user://`, commit, push, or merge was performed.

## Known integration follow-ups

- Historical tests and reports that assert `8/6/2`, a default three-card group, or one-step all-ready locking are stale. In particular, `tests/shared_card_group_runtime_test.gd` and old composition/layout assertions must be updated by the integration owner rather than restoring retired behavior.
- `main.gd` still contains old `8秒/6秒/2秒` player-facing log text and is outside A11's write boundary. Runtime behavior is cut over; presentation cleanup remains a separate integration task.
- Bid authorization and cash flow were deliberately not changed. The new controller only exposes the `public_bid` phase gate.
- Current production binding passes total and lock durations to the controller; the scene defaults carry the matching planning/public-bid/opening values. A later composition pass should forward the complete cadence snapshot without creating a second timing owner.

## Lessons for other agents

- **invariant:** phase ownership and queue ownership stay separate; only the queue allocates monotonic window sequence, while only the controller decrements time and advances ready state.
- **failed approach:** deriving every new sequence as `facts.window_sequence + 1` skips the required first sequence `0` and can reuse or drift after idle/save transitions.
- **stable API:** elevated submissions require an authoritative facts snapshot bound to actor/player/window/revision/range; request `max_cards` is intent only.
- **test oracle:** `card_resolution_queue_cadence_v06_test.gd` proves `0 -> 1 -> 2 -> save/load -> 3` and the ordinary-one/explicit-three gate.
- **integration trap:** old all-ready code may jump directly from planning to batch lock, silently skipping the public bid phase.
- **reusable pattern:** store the last allocated sequence in the state owner, infer only from started current/active entries for old saves, and never make UI/main a second sequence source.
- **stale evidence:** any `8/6/2`, `standard_group_card_limit=3`, or `all_ready_lock` assertion describes the retired cadence.
- **next dependency:** the production composition owner should forward all authored cadence fields and update old UI/log text; the bid/cash owner may consume `bidding_open` without moving settlement into the timing controller.
