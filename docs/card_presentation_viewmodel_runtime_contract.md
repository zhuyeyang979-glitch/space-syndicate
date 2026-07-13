# Card Presentation and Game Table ViewModel Runtime Contract

## Ownership

`CardPresentationRuntimeService` is the sole runtime owner of card-facing presentation facts:

- accent color and category icon
- strategy route and use-case copy
- card-face labels, chips, rules copy, quick-effect copy, and tooltips
- hand-card ViewModels, including enabled/disabled presentation and existing `play_<slot>` action ids
- card-resolution cinematic stages, target copy, effect style/radius, visual cues, and aftermath clues

`GameTableViewModelRuntimeService` is the sole runtime owner of table-facing composition:

- hand-card list composition
- public Card Track and Card Resolution Track ViewModels
- RightInspector selection precedence and card/track detail assembly
- final `TableSnapshot` normalization consumed by `GameScreen`

Both services are static children of `GameRuntimeCoordinator` and can be opened directly in the Godot editor.

## Domain Boundary

The services do not calculate card price, play legality, target legality, effects, cash, inventory mutation, queue mutation, or world state. `main.gd` and existing domain services supply those values as facts. Presentation output does not feed back into settlement.

The narrow `main.gd` boundary may:

- collect a real card definition and public display facts
- evaluate existing price and play-requirement owners
- collect selected hand, queue, district, log, and action facts
- call the Coordinator's presentation/ViewModel APIs
- route existing action ids and signals

It must not retain a second color, icon, route, use-case, rules-copy, resolution-cinematic, hand snapshot, track snapshot, RightInspector, or `TableSnapshot` algorithm.

## Privacy

The public Card Track output may expose public card text, public target descriptions, public bids, revealed owner labels, and aftermath clues. It must not expose hidden owner indices, private targets, private discard state, private hands, or AI private plans.

RightInspector may show a viewer's own selected hand card. A public track selection remains sanitized before it enters the table snapshot.

## Compatibility

- Existing card action ids remain unchanged.
- Existing `GameScreen` signals remain unchanged.
- Existing `TableSnapshot` keys remain unchanged.
- Card Resolution timing, queue, execution, effects, pricing, and save ownership remain unchanged.
- No fallback presentation owner remains in `main.gd`.

## Deletion Gate

`LegacyPlayerSurfaceRetirementBench` is the long-lived gate. Sprint 42 requires 27/27 cases and all 164 retired player/card presentation and snapshot functions to remain absent from `main.gd`.
