# Agent A VS06-A12 Handoff

## Scope and freeze

VS06-A12 wires production consumers to the A11 shared-card-window authority. No bid/cash formula, Queue ownership, reactive-counter counting, UI layout, Coordinator composition, or gameplay effect was changed. This task did not commit, push, merge, reset, or access the default `user://` profile.

The coordinator approved one narrow scope extension for `scripts/runtime/game_table_viewmodel_runtime_service.gd`: phase mapping and player copy only.

## Production callsites changed

- `scripts/main.gd`
  - `_bind_card_resolution_runtime_controller()` forwards the complete v0.6 cadence snapshot instead of 8/2 fallbacks.
  - `_card_resolution_controller_facts()` and Queue facts include `public_bid_duration`.
  - New-window creation and next-queue promotion call `CardResolutionRuntimeController.begin_group_window(reference_player, sequence)`.
  - Player status, ready actions, transition logs, rejection copy, and lobby copy consume `planning`, `public_bid`, and `lock` plus `cadence_snapshot()`.
  - `_runtime_card_track_model_source()` now exposes pure-data `group_phase_remaining_seconds` and `group_cadence` for presentation.
  - Main does not own a second cadence or sequence counter. Sequence remains allocated by `CardResolutionQueueRuntimeService`.
- `scripts/runtime/game_table_viewmodel_runtime_service.gd`
  - Maps `planning/public_bid/lock` to player-facing phase labels.
  - Formats remaining time from the supplied authoritative snapshot and removes old 6/2 copy.
  - Accepts legacy `organize` only as an internal migration input and presents it as `planning`.
  - Leaves public-bid receipt and cash semantics untouched.
- `tests/helpers/card_resolution_main_test_harness.gd`
  - Removed the stale dependency on the retired `CityDevelopmentRuntimeController`; the fixture now mounts only the owners used by this gate.

## Stale assertions and fixtures replaced

- `tests/shared_card_group_runtime_test.gd`: default three cards and fourth-card rejection became ordinary one card, forged-cap rejection, authoritative capability up to three, opening sequences 0-2, and three phase-local ready transitions.
- `tests/main_runtime_composition_test.gd`: production cadence now asserts 30/20/5/5 and opening 45/35/5/5; legacy auction-only restore expects the normalized public-bid remainder.
- `tests/card_resolution_controller_consolidation_test.gd`: reads the Controller debug boundary directly, removes the deleted main debug wrapper, and no longer restores a retired city owner.
- `scripts/tools/region_infrastructure_runtime_characterization_bench.gd`: v0.6 cases now assert 30/20/5/5, opening 45/35/5/5, ordinary one, and explicit cap three.
- `scripts/tools/player_mana_card_window_runtime_bench.gd` and its scene: default-three cases/copy became ordinary-one plus forged request rejection; result is 32/32.
- `scripts/tools/runtime_card_resolution_track_flow_fixtures.gd`: live payloads use planning/public-bid/lock, 20/5/5 copy, and ordinary one-card examples. The historical machine case ID `runtime_group_organize_window` remains stable, but its payload phase is `planning` and it never displays old rules.
- `docs/shared_card_window_cadence_v06.md`: records production-consumer and historical-evidence boundaries.

## Stable production contract

- Standard sequence 3+: 30 total, 20 planning, 5 public bid, 5 lock.
- Opening sequences 0, 1, 2: 45 total, 35 planning, 5 public bid, 5 lock.
- One ordinary card per player/window by default.
- A request's `group_card_limit`/`max_cards` cannot self-authorize. Only an authoritative actor/player/window/revision/activation/expiry-bound capability can raise the limit, with hard cap three.
- Ready advances one phase only. Lock-ready is the only early batch-lock command.
- Reactive counter submissions keep their existing separate count path.
- Queue still reports `cash_authority=false` and `priority_bid_authority=false`; main's existing public-wager receipt consumer remains present.

## Focused evidence

All commands used isolated `APPDATA` and `LOCALAPPDATA`.

- `tests/shared_card_window_production_cutover_v06_test.gd`: PASS, 23/23.
- `tests/shared_card_group_runtime_test.gd`: PASS, 17/17.
- `tests/shared_card_group_window_test.gd`: PASS, 24/24.
- `tests/card_resolution_runtime_controller_test.gd`: PASS, 26/26.
- `tests/card_resolution_queue_cadence_v06_test.gd`: PASS, 23/23.
- `tests/card_resolution_controller_consolidation_test.gd`: PASS, 12 assertions.
- `tests/main_runtime_composition_test.gd`: PASS.
- `PlayerManaCardWindowRuntimeBench.tscn`: PASS, 32/32.
- `RuntimeCardResolutionTrackFlowBench.tscn` and `RegionInfrastructureRuntimeCharacterizationBench.tscn`: Godot 4.7 isolated parse/load exit 0.
- Production player-text scan: no 8-second shared-window, 6-second planning, final-2-second lock, or default-three copy outside tests/historical v0.4/v0.5 evidence.
- `git diff --check` for the A12 file set: PASS.

Per coordination policy, this agent did not run full smoke, MCP/headed acceptance, or the complete vertical slice.

## Remaining integration risks

- Main intentionally retains its existing headless/forced-window zero-duration shortcut. Focused tests validate the authoritative cadence snapshot; the coordinator should verify actual visible timers in the unified headed pass.
- `organize_seconds` and legacy auction fields remain read-only migration aliases. They are not player text or v0.6 phase ownership.
- Historical v0.4/v0.5 fixtures and conformance evidence may still contain their authored old values; they must not be used as production v0.6 configuration.
- The stable `runtime_group_organize_window` fixture ID is retained for manifest compatibility even though its runtime payload is `planning`.
- The coordinator should run the unified vertical slice to confirm BidBoard/CardTrack visual timing and unchanged wager-pool cash receipts under a visible 45-second opening window.

## Lessons for other agents

- **Invariant:** Controller owns cadence/ready; Queue owns monotonic window sequence; neither owns cash, cards, bids, or effects.
- **Failed approach:** Updating only Profile/Controller left main and ViewModel interpreting `organize` and presenting 8/6/2, so source-of-truth cutover was incomplete.
- **Stable API:** `card_group_runtime_rules()`, `cadence_snapshot(sequence)`, `begin_group_window(reference_player, sequence)`, `current_phase(facts)`, and Queue's validated capability facts.
- **Test oracle:** Assert sequences 0/1/2 as 45/35/5/5, sequence 3 as 30/20/5/5, then independently assert one-step ready and ordinary-one/capability-three security.
- **Integration trap:** `auction_open` is a compatibility flag during `public_bid`; treating it as lock shows the wrong phase and enables the wrong player copy.
- **Reusable pattern:** Pass a pure-data cadence/remaining-time snapshot to presentation; never duplicate timing literals in a ViewModel.
- **Stale evidence:** v0.4/v0.5 fixtures, `organize_seconds`, and legacy auction-only saves can remain for migration evidence but must be clearly excluded from production v0.6 assertions.
- **Next dependency:** Unified headed/vertical-slice validation should check visible opening/standard clocks, three-step ready, capability-provided extra submissions, and unchanged public-wager cash settlement.
