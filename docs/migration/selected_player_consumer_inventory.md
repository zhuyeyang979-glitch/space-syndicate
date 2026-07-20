# Selected Player Consumer Inventory

## Scope

- Baseline: `origin/main@f0d5a8c71b882dd8667772fc5ce135d7fd39c9e8`
- Previous selection commit: `c4bfba7c39ca7afdd5f63bae05d3b6fd465062f6`
- Inventory command: `rg -n --no-heading "selected_player" scripts --glob '*.gd'`
- Raw lexical hits after the cutover: 78
- Production actor-source reads: 0
- Unknown classifications: 0

The lexical count includes compatibility keys, privacy sentinels, and old test benches. It is not a count of live gameplay consumers.

## Frozen Semantics

`TableSelectionState.selected_player` is retained only as the existing save-compatible name for the presentation inspection target. New code uses `inspected_player_index()`, `select_inspected_player()`, and `inspected_player_snapshot()`.

The authorized actor is independent of table selection:

```text
LocalViewerAuthorization
+ GameSessionRuntimeController
+ WorldSessionState public player membership
-> PlayerIdentityAuthorizationBoundary.current_actor_context()
-> GameplayActorAuthorizationContext.authorized_actor_player_index
```

The existing `PlayerIdentityAuthorizationBoundary` is the one scene-owned identity boundary and now supplies the actor context. No second actor authority port, selection owner, state mirror, or save section was added.

## Classification Summary

| Classification | Hits | Meaning |
| --- | ---: | --- |
| `PRESENTATION_INSPECTION_TARGET` | 30 | UI inspection state, detached presentation metadata, or developer diagnostics scoped to the inspected public player |
| `GAMEPLAY_TARGET_PLAYER` | 0 | No remaining raw `selected_player` hit is a live gameplay target input |
| `AUTHORIZED_ACTOR_SOURCE` | 0 | No gameplay command derives its actor from table selection |
| `VIEWER_IDENTITY` | 0 | Viewer identity comes from `LocalViewerAuthorization` |
| `PUBLIC_PLAYER_LOOKUP` | 0 | Public target validation uses the identity boundary and public projection without this field |
| `LEGACY_OR_DEAD` | 48 | Characterization benches or non-consuming privacy/schema sentinels |
| `UNKNOWN` | 0 | Every hit is classified |

## Production Consumers

### Presentation Inspection Target: 30 hits

- `scripts/runtime/table_selection_state.gd` (18): sole selection owner and save-compatible `selected_player` key; mirrors the explicit inspected-player API.
- `scripts/runtime/game_runtime_coordinator.gd` (1): initializes both compatibility and explicit inspected-player fields to seat 0 for a new session.
- `scripts/presentation/table_presentation_viewmodel_query.gd` (1): detached presentation metadata initialized from the authorized viewer.
- `scripts/runtime/product_market_runtime_world_bridge.gd` (1): legacy presentation metadata in a world snapshot; the ProductMarket controller does not consume it as an actor.
- `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd` (9): developer-only diagnostic sample subject. It evaluates cards and districts for the inspected player but does not submit gameplay commands.

### Legacy, Fixture, Or Non-Consumer Sentinel: 48 hits

- `scripts/runtime/action_result_v1.gd` (1): forbidden-field/schema sentinel.
- `scripts/runtime/card_codex_public_source_adapter.gd` (1): privacy forbidden-key sentinel.
- `scripts/runtime/monster_codex_public_source_adapter.gd` (1): privacy forbidden-key sentinel.
- `scripts/runtime/product_codex_public_source_adapter.gd` (1): privacy forbidden-key sentinel.
- `scripts/runtime/region_codex_public_source_adapter.gd` (1): privacy forbidden-key sentinel.
- `scripts/runtime/standings_public_query_port.gd` (1): privacy-safe debug declaration that selection is not authorization.
- `scripts/tools/*.gd` (42): legacy characterization fixtures and source-negative privacy benches. They are not production routes. See the machine-readable inventory for every file and count.

## Removed Actor Inference

- Main no longer defines `_select_player`, number-key player wrappers, or reads `table_selection_state().selected_player`.
- Card submission requires an explicit request actor.
- Military commands require an explicit acting player.
- Monster takeover and wager APIs fail closed without an explicit actor.
- AI card eligibility, cost, and queueing use the AI's explicit `player_index`; AI no longer swaps table selection to impersonate itself.
- The obsolete writable `selected_player` proxy properties were removed from AI and Monster runtime controllers.

## UI Inputs

PlayerSeat click/gamepad, PlayerBoard identity, toolbar identity, fullscreen HUD, and keyboard 1-8 all emit `TableSelectionIntent.KIND_INSPECT_PLAYER` through the existing `TableSelectionIntentPort`. Text-input focus suppresses the hotkeys. The authoritative receipt refreshes PlayerSeat, PlayerBoard, toolbar, fullscreen metadata, and the public-only RightInspector.

## Compatibility Debt

The stored field name `selected_player` remains for save and broad presentation compatibility. It must not be renamed until the later save-schema boundary. Its debug contract explicitly reports `selected_player_semantics = presentation_inspection_target` and `authorized_actor_source = external_identity_authority`.

## Result

- `SELECTED_PLAYER_ACTOR_SOURCE_COUNT=0`
- `SELECTED_PLAYER_TO_MAIN_ROUTE_COUNT=0`
- `SELECTED_PLAYER_MAIN_FALLBACK_COUNT=0`
- `SECOND_SELECTION_OWNER_COUNT=0`
- `SECOND_ACTOR_AUTHORITY_OWNER_COUNT=0`
- `UNKNOWN_COUNT=0`
