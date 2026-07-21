# Card Target-Choice Response Cutover

Monster- and player-target responses now use one typed, scene-owned production
path:

`GameScreen -> ForcedDecisionResponsePort -> CardTargetChoiceResponseSink -> CardPlaySubmissionRuntimeController`

`CardTargetChoiceRuntimeController` remains the sole owner of pending choices.
The response sink validates the live choice binding, the authorized viewer, the
current public target facts and exact-once request identity before delegating to
the existing card-submission owner. It does not own hand, queue, monster,
player, cash or presentation state.

Successful target selection queues the card once and clears the matching
choice. The target owner holds a synchronous reservation while submission is
committed, so another clear/begin operation cannot split queue and choice
lifecycle. Rejected submission releases that reservation and keeps the choice.
Cancellation clears the choice without consuming or publishing a card.
A down monster, self target, eliminated player or rejected card submission
leaves the choice open so the player can choose again. Stale choice bindings
fail closed and request a fresh forced-decision projection.

The full response receipt is viewer-private. Its public projection is
publishable only after a card has actually entered the public queue, and then
contains only the public target kind/index. It omits the actor, source card,
owner truth, hand, cash and private selection context.

Target buttons carry the decision identity that rendered them; a stale window
cannot bind its click to a newer choice of the same kind. Monster options use
the public stable monster UID rather than a mutable roster index. The stable
target envelope fingerprints that UID, and execution resolves the current slot
from the UID so roster removal/reordering cannot redirect the card.

Removed from `scripts/main.gd`:

- both temporary target-choice constants;
- pending target-choice query wrappers;
- begin/clear/cancel target-choice wrappers;
- monster/player target dispatch wrappers;
- target-option branches in the generic Main action router.

The coordinator's five legacy mutation/query facades were also removed. The
local objective now consumes the already-composed viewer-scoped presentation
projection. The zero-consumer manual submission entry and obsolete legacy-state
import helper were deleted rather than retained as a second path.

Focused evidence:

- `res://tests/card_target_choice_response_cutover_test.gd` — 34/34
- `res://tests/forced_decision_response_boundary_test.gd` — 49/49
- `res://tests/card_resolution_stable_target_envelope_test.gd` — 39/39
- `res://scenes/tools/CardTargetChoiceResponseSinkBench.tscn` — Godot 4.7 MCP 11/11

Broad historical characterization fixtures that still call deleted Main
helpers are test debt, not a reason to restore a compatibility path. They must
be migrated to the typed forced-decision boundary independently.
