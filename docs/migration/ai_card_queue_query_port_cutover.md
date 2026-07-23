# AI Card Queue Query and Submission Cutover

## Boundary

This atomic boundary removes AI access to raw card-resolution queues and removes
the AI-only monster-counter conversion helper from `Main`. It does not claim the
full P0 AI world typed-port program is complete.

Base commit: `0f40e1d909a10a35569141cc0b4aa4657b15c75a`.

## Query contract

`AiCardQueueQueryPort` owns no gameplay state. Its public projection contains
detached public card identity, public target facts, public card facts needed for
counter evaluation, queue counts, and stable resolution IDs. Queue-entry and
card-definition fields both use explicit allowlists; a recursive guard then
rejects source player identity, slot identity, AI score, AI reason, target owner,
and other actor-private diagnostics as a second line of defense.

Actor-private queue state requires an opaque `AiCardQueueCapability`. A
capability can read only whether its own AI seat has an active, current, or next
submission and the corresponding resolution ID. Human, rival, forged, and stale
capabilities fail closed. An unavailable capability blocks candidate generation
before RNG, and legacy queue entries without a resolution ID still count as an
existing submission. Roster replacement revokes and reissues capabilities.

## Command contract

AI card play uses the existing `CardPlaySubmissionRuntimeController` receipt.
The AI no longer rereads a raw queue entry or overwrites a whole entry after
submission. AI score, reason, and counter diagnostics remain in the existing
AI-owned memory only.

Monster-card counter conversion is now a typed submission operation. The
submission controller:

1. validates the formal role passive and counter window;
2. builds the same ranked phase-counter card;
3. preflights the derived counter without mutating live world state;
4. submits the derived counter through the shared card queue transaction while
   consuming the original owned monster-card slot;
5. commits inventory and queue state only after the shared transaction accepts;
6. leaves hand, cash, queue, and world state unchanged on rejection.

Explicit AI target context no longer eagerly reads the human
`TableSelectionState.selected_district`.

## Removed routes

The following generic Main routes are zero in `AiRuntimeController` production
code; shared Main helpers used by human or diagnostic consumers are not claimed
as globally deleted:

- `_card_resolution_current_queue`
- `_card_resolution_next_queue`
- `_store_card_resolution_entry`
- `_queued_card_entry_index_for_player`
- `_next_batch_card_entry_index_for_player`
- `_call_world("_queue_monster_card_as_counter")`
- `Main._queue_monster_card_as_counter`

The active-entry label and counterability checks now use the public queue
projection rather than Main method-name calls.

`Main._queue_monster_card_as_counter` is physically deleted because it had no
remaining non-AI production consumer.

## Evidence

- Godot MCP production script compile: 720 checked, 0 errors.
- AI card queue query port: PASS.
- AI card phase/counter owner, including conversion and rollback: PASS.
- Rejected conversion preserves world, queue, and Mana reservation checkpoints.
- Stable target envelope: PASS.
- Card execution typed ports: PASS.
- Counter response window: PASS.
- AI private hand query: PASS.
- Formal `main.tscn` MCP play: Runtime Bridge ready, 819 nodes, 120 FPS.
- Main budget: PASS, 6419 physical lines and 472 methods.
- `git diff --check`: PASS.

`CardPlayEligibilityRuntimeBench` reports 41/44 both on this worktree and on
the clean `0f40e1d` baseline. Its stale city-development expectations and old
Coordinator-route assertion are therefore recorded as inherited fixture debt,
not as evidence for or against this cutover. The obsolete
`card_play_requirement_policy_test.gd` also calls deleted
`Main._new_game`; it is not used as a product gate for this boundary.

## Remaining P0 scope

Card eligibility/definition helpers, market-derived strategy helpers, monster,
military, weather, victory, public log, and visual-cue routes still have generic
bridge consumers. The full P0 status remains active.
