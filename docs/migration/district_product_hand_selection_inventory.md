# District, Product, And Hand Selection Cutover

## Boundary

This atomic cutover migrates player-facing district, trade-product, and hand-slot
focus changes to `TableSelectionIntentPort`. It does not redefine gameplay actor
authority and it does not replace domain-owned target contexts used while AI,
contracts, military, monsters, or card resolution execute a command.

The authoritative presentation/gameplay target state remains
`TableSelectionState`. `PlayerIdentityAuthorizationBoundary` authorizes the
viewer and active session before the port applies a target change.

## Typed Requests

| Intent | Stable target | Allowed production surfaces | Refresh |
| --- | --- | --- | --- |
| `select_district` | district index in the public world projection | planet map, fullscreen map, keyboard | full |
| `select_trade_product` | public `ProductMarketRuntimeController` catalog ID, or empty to clear | table toolbar, PlayerBoard, keyboard | map |
| `select_hand_slot` | local authorized viewer slot index, or `-1` to clear | HandRack, PlayerBoard, GameScreen | full |

All three requests carry the viewer authorization revision, active session ID
and revision, expected selection revision, stable request ID, and request
revision. Stale, forged, duplicate, colliding, and forced-decision-blocked
requests fail closed.

## Production Consumers

### Migrated UI writes

- Embedded and fullscreen map `district_selected` signals now enter
  `GameScreen.request_district_selection`.
- Q/E district cycling and R/T product focus use the typed request path.
- Hand select, unselect, public-track focus, and valid drag release use
  `GameScreen.request_hand_selection`.
- Main no longer connects the map single-click signal, receives hand selection,
  or assigns the three target fields directly.

### Retained reads

Main and domain controllers may still read these fields as the explicit target
of an already authorized command. Those reads do not determine the acting
player. Card play continues to carry its actor and hand slot explicitly.

### Retained domain-owned writes

- Product-market and contract settlement may focus the product that their
  completed gameplay operation changed.
- AI temporarily stores its own candidate district/product context while
  constructing a card-resolution request, then restores it.
- Session start and save restore initialize `TableSelectionState` through their
  existing owner transaction.
- Tests and characterization benches may seed the owner directly as fixtures.

These are not viewer UI authorization routes and are outside this atomic
cutover. They must not be used to infer actor identity.

## Presentation Preservation

Changing district previously caused Main to reconcile the selected and
previewed district-supply card. The behavior now lives behind
`TableCardSupplyPresentationState.reconcile_district_card_choices`, invoked by
the scene-owned `GameRuntimeCoordinator` when the typed receipt emits
`selected_district_changed`.

`OptionalRoutePresentationRuntimeService.selected_trade_product_id` remains a
separate presentation-only route filter. It is not an alias for
`TableSelectionState.selected_trade_product` and was deliberately not merged.

## Privacy And Mutation

- District existence comes from the public world projection.
- Product validation uses the public product catalog.
- Hand validation exposes only whether a slot exists for the authorized local
  viewer; no card content enters an intent or receipt.
- Target changes do not alter authorized actor, inspected player, world state,
  game-session state, RNG, cash, or private hand contents.

## Gate

`tests/district_product_hand_selection_cutover_test.gd` freezes the typed
contract, exact-once behavior, viewer isolation, forced-decision blocking,
detached snapshot allowlist, UI adapters, card-supply reconciliation, and Main
negative source gate.
