# Menu Lifecycle Application-Flow Cutover

Status: `CUT_OVER`

The shared root, pause, requested-menu, close, resume, load and quit lifecycle is
now owned by `MenuLifecycleApplicationFlowController`, composed once in the
production `main.tscn`. It coordinates existing scene-owned services and owns
no gameplay state, world clock, page snapshot, RNG or save payload.

Rules, economy and standings were not reimplemented. Their existing dedicated
application-flow controllers and viewer-authorized query ports remain the only
page owners. `ApplicationFlowPort.application_page_opening` gives every
allow-listed page the same pause/catalog-reset lifecycle before its dedicated
page signal is emitted.

The table menu button now travels through:

`GameScreen -> TableNavigationActionIntent -> TableNavigationActionRouter -> ApplicationFlowPort -> MenuLifecycleApplicationFlowController`

The router journal preserves exact-once delivery and rejects replayed request
IDs. Escape uses the same `GameScreen` request path, so forced-decision surfaces
continue to block ordinary menu opening.

`PauseMenuSummaryBoard.tscn` replaces the four pause cards that Main previously
constructed programmatically. `SetupApplicationFlowController` delegates
successful start/return closure to the lifecycle owner, leaving one production
menu close path.

Removed from Main:

- root and pause menu builders;
- generic requested-menu presentation;
- menu close/resume, load and quit handlers;
- menu overlay, preview, load-button and pacing mirror fields;
- root-lobby preload and dynamic menu signal wiring;
- menu summary card construction and quick-navigation helpers;
- legacy `time_scale` toggle ownership.

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Physical lines | 8,683 | 8,199 | -484 |
| Nonblank lines | 7,442 | 7,012 | -430 |
| Methods | 583 | 556 | -27 |
| Top-level variables | 54 | 48 | -6 |
| Constants | 68 | 67 | -1 |
| Top-level preloads | 8 | 7 | -1 |

Focused evidence:

- `menu_lifecycle_application_flow_cutover_test.gd`
- `table_navigation_action_router_test.gd`
- `main_application_flow_handler_extraction_test.gd`
- rules/economy/standings/setup application-flow tests
- `main_runtime_composition_test.gd`
- `main_gd_architecture_gate_test.gd`

Godot 4.7 validation:

- focused menu lifecycle, navigation, application-flow, composition, UI text,
  and architecture gates: pass;
- `smoke_test.gd --check-only`: pass;
- production `main.tscn` through Godot MCP: loads and runs without a new script
  or runtime error (the repository's existing warning inventory remains);
- the menu-specific assertion in `layout_scene_smoke_test.gd`: pass. The broad
  layout suite remains red on pre-existing retired CityDevelopment/PublicTrack
  fixtures and a `RuntimePhaseCoordinator.bind_ports` nil fixture;
- full smoke remains blocked by its pre-existing retired `_new_game` Main
  fixture and reaches the isolated 900-second timeout. No Main compatibility
  path was restored.

Legacy capture and smoke helpers now resolve the production lifecycle,
`ApplicationFlowPort`, and `MenuModalOverlay` by explicit scene paths instead
of reading deleted Main fields or calling deleted Main menu methods.

The broad `presentation_action_routing` domain remains pending because gameplay
actions still enter Main. This cutover claims only the application-menu and
read-only-page lifecycle boundary.
