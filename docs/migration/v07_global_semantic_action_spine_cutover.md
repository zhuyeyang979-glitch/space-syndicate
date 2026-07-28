# V0.7 Global Semantic Action Spine Cutover

This delivery establishes V0.7 as the highest target development constitution
while keeping V0.6 as the only production runtime ruleset. It does not activate
the V0.7 commodity runtime, add a Save section, add an RNG owner, or create a
second gameplay authority.

## Terminal-progression repair status

The Action Spine architecture remains ready, but its descendant terminal
product gate is currently `PARTIAL`. The controlled repair branch is
`codex/action-spine-v07-terminal-progression-repair-02d1719`, based on
`02d1719b83ce614b63627245641d3744f6f56c19`.

The same repair Driver artifact (SHA-256
`6A2F26270F42E275E50A932421763D164E906DAC7AA8134312D4094164684868`)
was applied to the direct parent and current descendant. Parent `5cf30c6`
could not start the 360-step comparison: its second action failed with
`game_action_intent_authorization_session_id_invalid`, after zero authoritative
steps. The current descendant performed 147 actions, progressed 138, and
reported zero invalid actions. This evidence excludes a current Action Spine
rejection regression, but does not manufacture strict parent/child pacing
parity from a parent that cannot consume the same Driver contract.

The repaired Driver now owns a bounded `360` base / `480` maximum progress
lease, a 90-step no-progress boundary, a 420-second world-effective hard cap,
and a 180-second wall cap. Only monotonic public progress renews the lease. It
also emits viewer-safe 30-step checkpoints, observes a bounded facility
maturation window, freezes scripted facility growth across
`eligible/qualification/audit/resolved`, and requires zero post-Victory
facility growth at terminal acceptance. No gameplay value, RNG owner or draw,
Save owner or schema, Main route, RuntimeLoop, Victory duration, or
FinalSettlement path changed.

The one final controlled FullRun was
`20260728-093544-814-full_run_quality_driver-5752ad04`. It reached three real
production installations, five public Sale Receipts, Top-K GDP `59/108`, five
privacy-safe checkpoints, and 150 one-second authoritative steps. It ended at
`observation_window_elapsed_before_settlement` with Victory still `idle`.
FinalSettlement and eight-frame quiescence were therefore not observed, and
terminal world/RNG deltas remain unavailable rather than being reported as
zero.

The failure is classified as `FULL_RUN_DRIVER_ORACLE_STALE`, not
`ACTION_SPINE_BEHAVIOR_REGRESSION`: the stale fixed-budget/three-facility oracle
has been replaced and the repaired path sustains valid typed actions, but its
legal rack/economy progression is still too slow for the product wall gate.
Consequently:

```text
STATUS=ACTION_SPINE_V07_TERMINAL_PROGRESSION_REPAIR_PARTIAL
MERGE_TO_MAIN_ALLOWED=false
NEXT_MAJOR_TASK_ALLOWED=false
AI_WORLD_PRODUCTION_MODIFIED=false
```

## Reconciled production baseline

`origin/main` at `b5763bbfb96994aa55ab36ae4335db332d9818a8`
(PR #68) already proves one real production run from new-game setup through
three facility installations, 31 Sale Receipts, positive GDP, Victory
qualification/audit, FinalSettlement, and eight terminal-quiescent frames.
That evidence remains authoritative in
`reports/playability/full_run/sample_full_run_vertical_slice_to_settlement_validation.md`.

Production Save capture, application close, cold restore, continued play after
restore, and a second complete run are not proven. Therefore
`SAVE_RESUME_READY=false`, `CLOSED_ALPHA_READY=false`, and
`FULL_V0_7_RUNTIME_CUTOVER=false` remain mandatory.

## One global semantic control plane

`docs/semantic/global_three_layer_semantic_registry.json` is the single
machine-readable registry. Its Markdown companion is explanatory only. The
registry inventories 24 required domains, with 18 core-ready domains and one
genuinely three-layer-ready domain: `player_action_routing`. Coverage is not a
readiness claim; global three-layer completion remains false.

The completed production slice is:

```text
authorized GameActionOfferV1
        ↓
GameActionIntentV1
  human_click / human_drag / human_quick_action / ai_decision
        ↓
TablePlayerActionApplicationFlowController
        ↓
existing typed domain owner or command port
        ↓
GameActionReceiptV1
        ↓
human-only private feedback + exact-once presentation refresh
```

The flow validates closed data, actor authorization, trusted session identity,
source revision, stable target bindings, and bounded request identity. It owns
no card rule, world state, hand, AI policy, UI copy, Save state, or RNG. Human
and AI card play reach the same `CardPlaySubmissionRuntimeController` entry.
An AI receipt never enters the GameScreen private-feedback signal.

The closed V1 action vocabulary contains exactly six actions:

- `card.play`
- `card.group.ready`
- `card.group.reorder`
- `district.supply.open`
- `player.strategy.open-supply`
- `session.end-turn`

Authorization is checked before the request journal. An unauthorized request
cannot reserve an ID, evict the active session journal, or turn a later valid
request into a replay/collision. A valid duplicate returns its detached prior
receipt with zero second domain mutation and zero second refresh. A same-ID,
different-fingerprint request is rejected as a collision. The journal is
session-scoped and bounded to 128 entries; it is idempotency metadata, not a
second Save or gameplay-state owner.

GameScreen keeps pointer hit testing and `Vector2` locally. Drag submission
crosses the boundary as a stable public `region_id`; the flow resolves it to an
authoritative district and `CardPlaySubmissionRuntimeController` freezes that
explicit override without changing presentation selection. Card-group ready
and reorder authorize only actor-owned entries in the current queue lane.

## Main physical deletion

The complete player-action family removed from `scripts/main.gd` is:

- `_on_runtime_game_screen_action_requested`
- `_activate_runtime_temporary_decision_action`
- `_on_runtime_game_screen_end_turn_requested`
- `_on_runtime_game_screen_card_drop_requested`
- `_runtime_hand_slot_from_card_data`
- `_runtime_drop_position_targets_map`
- `_activate_runtime_district_action`
- `_activate_runtime_player_board_action`
- `_activate_runtime_quick_action`
- `_runtime_quick_action_entry`
- `_activate_runtime_snapshot_action`
- `_play_v06_runtime_card_for_player`
- `_runtime_player_board_action_entries`
- `_runtime_player_board_quick_actions`
- `_runtime_quick_action_snapshot`
- `_runtime_player_board_table_state_lamps`
- `_runtime_player_board_readiness_chips`
- `_runtime_player_board_bid_board`
- `_runtime_bid_board_track_links`
- `_runtime_bid_board_track_link`
- `_runtime_bid_board_status_line`
- `_runtime_bid_board_actions`
- `_runtime_public_player_board_action`
- `_runtime_primary_action_entry`
- `_runtime_primary_action_label`
- `_table_goal_primary_action`
- `_selected_district_action_entries`
- `_move_card_within_group`
- `_set_authorized_player_card_group_ready`

`PlayerBoardStrategyActionSnapshotScript` was also removed. No forwarding
wrapper, prefix parser, Callable payload executor, screen-position core router,
or fallback to Main remains.

| Main metric | `origin/main` before | Action Spine after |
| --- | ---: | ---: |
| Physical lines | 6,438 | 5,664 |
| Nonblank lines | 5,420 | 4,671 |
| Methods | 469 | 440 |
| Top-level variables | 46 | 46 |
| Constants | 45 | 44 |
| Preloads | 7 | 6 |
| External caller files | 111 | 111 |
| External call occurrences | 1,252 | 1,249 |

The task-relative ratchet is monotonic and adds no Main caller or fallback. The
historical absolute caller budget remains inherited red at `111 > 102`; this
cutover does not relabel that debt as green. The V0.7 source-negative semantic
test is classified with the existing architecture-oracle exclusions because it
reads Main as text and is not a runtime caller.

## Visibility, Save, and RNG

- Action wire types reject Object, Node, Resource, Callable, NodePath, Vector2,
  floats, unknown fields, open payload bags, and localized text as identity.
- Stable private card references disclose neither runtime instance IDs nor card
  identities and are revalidated by the authoritative source.
- Public refreshes remain presentation requests; player-private receipt refs
  are emitted only for a human actor.
- New Save owners: 0. New Save sections: 0. Save schema changes: 0.
- New RNG owners: 0. New RNG draw points: 0.
- New gameplay state owners: 0. New runtime loops: 0.

## Verification

The final evidence matrix is recorded in the JSON companion. The final focused
rerun passed the closed action protocol (`110/110`), application flow (`48/48`),
production composition Bench (`12/12`), Main architecture (`219` checks), Main
runtime composition, FullRun driver contract (`181/181`), observation-window
policy (`8/8`), terminal Victory exact-once (`81/81`), FinalSettlement
composition (`24/24`), UI text, visual snapshot, and smoke `--check-only`.

Production validation found and closed two real adapter defects before the
bounded run: runtime session identities such as
`session:full-run:900626424` now use a dedicated narrow validator, while actor,
proof, and surface IDs retain the stricter stable-ID grammar; and authored JSON
rank `1.0` now normalizes to the same closed integer private-card binding as
rank `1`, while fractional ranks remain invalid. Neither change modifies Save
identity, card rules, or gameplay order.

The controlled candidate run used
`--seed-index 0 --observation-seconds 150 --max-wall-seconds 180`. It performed
74 actions, confirmed 71, recorded zero invalid actions, installed three real
production facilities, emitted eight public Sale Receipts, and observed
positive GDP. It then exited honestly at
`observation_window_elapsed_before_settlement` before Victory or
FinalSettlement. Consequently this report does not relabel the candidate run
as a terminal pass. The merged PR #68 A13/A14 terminal evidence remains the
current complete-match baseline, and the focused terminal owner gates remain
green; the candidate result is recorded as bounded incomplete rather than a
new Action Spine rejection.

Godot MCP identified the correct Godot 4.7 worktree, started the production
`main.tscn`, exposed no new script or runtime error, returned the existing
warning/NUL baseline, and stopped the scene cleanly. The production Bench also
passed through Godot with no Main dependency.

Broad `smoke_test.gd` still reaches retired Main fixture debt. No old Main
wrapper was restored; this remains a separate P4 fixture-migration boundary.

## Remaining boundary

Global three-layer semantics are not complete. `bind_ai_world(self)` and broad
AI world reads remain outside this slice, as do the seven unsupported Save
owners and all production V0.7 commodity-track rules.

`P0_AI_WORLD_TYPED_PORTS_MAIN_HOST_DETACHMENT` is paused. The next minimum
atomic task is to improve the Driver's legal rack facility acquisition and
economic-progress selection so the same V0.6 production owners can reach
Victory and FinalSettlement inside the 180-second wall boundary. It may not
increase the wall cap, inject GDP, force Victory, skip qualification/audit, or
restore a Main action route. AI World typed ports may resume only after one
fresh controlled run proves Victory, FinalSettlement exact-once, eight quiet
frames, zero terminal world delta, zero terminal RNG delta, and zero invalid
actions.
