# Public Card Resolution Focus Authority Cutover

## Boundary

This atomic cutover migrates public card-resolution focus from the generic
`track_select_* -> Main` action route to `TableSelectionIntentPort`. The
existing `TableSelectionState` remains the sole selection owner. This does not
migrate card play, auction responses, group ordering, or Compendium deep-link
navigation.

## Typed Contract

`select_card_resolution` carries only a stable public `resolution_id`, viewer
authorization, active-session identity, expected selection revision, source
surface, and exact-once request identity. Allowed production sources are the
card-resolution track, public bid board, and RightInspector.

The port validates the ID against:

- `CardResolutionQueueRuntimeService.public_snapshot()`; or
- `CardResolutionHistoryRuntimeService.public_history_snapshot()`.

It never calls the authoritative queue `entry_by_id`, reads raw history, or
uses private target slots. A public `selected_district` or public contract
source/target may update the map focus in the same owner revision. When no
public district exists, the resolution is still selectable and the current map
focus is preserved.

## Authority Correction

The old route also exposed a hidden coupling: `CardIntelRuntimeService` and AI
contract tracing could read `TableSelectionState.selected_card_resolution_id`
while resolving gameplay. The focus selected by a human is presentation state,
not a durable gameplay target.

Card submission now freezes an explicit `selected_card_resolution_id` in the
resolution entry. Intel effects consume that frozen context only. AI selects a
public history or contract entry explicitly and submits its stable ID; it does
not read or write the human table focus.

## Removed Main Surface

- `_select_card_resolution_track_entry`
- `_focus_card_resolution_track_entry`
- `_focus_card_resolution_target_region`
- `_card_resolution_public_target_district`
- generic `track_select_*` branch
- dead `track_return_*` branch
- `GameRuntimeCoordinator.select_card_resolution`

`_card_resolution_entry_by_id` remains because card rules and contract flows
still have real authoritative consumers. `track_open_*` remains a distinct
Compendium navigation route for a later typed-navigation boundary.

## Privacy And Mutation

Focusing a public resolution changes only `TableSelectionState` and requests
one presentation refresh. It does not mutate the world session, card queue,
history, RNG, cash, hand, public log, or card execution. Receipts expose no raw
entry, actor, target slot, hidden owner, or private player state.

## Gate

`tests/public_card_track_focus_selection_cutover_test.gd` verifies public
queue/history authorization, atomic map focus, hidden-target invariance,
viewer and revision rejection, exact-once behavior, GameScreen adapters,
explicit card-effect context, and physical removal of the Main route.
