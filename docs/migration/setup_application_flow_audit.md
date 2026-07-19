# Setup Application Flow Audit

## Audit Metadata

- Role: `setup_flow_mapper` (analysis only)
- Repository baseline: `2575fb4ac3192f8030c1719401531c582c9121c1`
- Branch: `codex/setup-session-start-transaction-2575fb4`
- Scope: current production Setup page, Main call graph, setup draft ownership, new-game start behavior, and known test contracts
- Production changes: none

## Findings First

### [P0] Starting a new run is destructive before validation and has no rollback

`Main._confirm_start_new_run_from_setup()` records a public start message, invokes the void `_new_game()` method, and then closes Setup unconditionally (`scripts/main.gd:3811-3819`). `_new_game()` resets card resolution, coordinator state, `WorldSessionState.players`, districts, history, selection, market, GDP, public log, clocks, victory state, and timers before completing setup validation or proving all downstream owners can initialize (`scripts/main.gd:4373-4414`). It can subsequently return on a missing starter card or failed runtime binding (`scripts/main.gd:4428-4432`, `scripts/main.gd:4472-4493`).

There is no preflight-all phase, checkpoint set, reverse rollback, typed failure receipt, or active-session isolation. A failed attempt can therefore destroy an existing live run, advance live RNG, and still dismiss the Setup page. This is the principal transaction boundary that the cutover must replace without changing game rules.

### [P0] Setup and new-game production authority remains in Main

Main owns the draft fields (`scripts/main.gd:165-169`), setup page composition (`scripts/main.gd:3495-3808`), settings persistence (`scripts/main.gd:3852-3892`), role and starter selection mutation (`scripts/main.gd:7081-7330`), world generation (`scripts/main.gd:3931-4329`), and the live start sequence (`scripts/main.gd:4373-4531`). There is no scene-owned Setup application controller, unique draft owner, pure plan builder, or transaction coordinator.

The current ownership boundary combines UI flow, local preferences, random resolution, world-plan construction, live owner mutation, session lifecycle, public logging, and presentation refresh. Copying this block into a new manager would preserve the monolith rather than establish the requested owner boundaries.

### [P1] ApplicationFlowPort still sends Setup through the generic Main route

`ApplicationFlowPort` allowlists `setup` but has no dedicated signal (`scripts/runtime/application_flow_port.gd:8-17`). `submit_action()` handles rules, standings, economy, compendium, and intel explicitly, then emits generic `action_requested` for Setup (`scripts/runtime/application_flow_port.gd:33-49`). The scene connects that signal to Main (`scenes/main.tscn:177`), where `_on_menu_quick_nav_action_requested()` matches `setup` and calls `_start_new_run_from_menu()` (`scripts/main.gd:2258-2262`).

The main-menu `new_run` entry bypasses `ApplicationFlowPort` entirely: `MenuRootLobby` emits a generic action (`scripts/ui/menu_root_lobby.gd:194-210`, `scripts/ui/menu_root_lobby.gd:233-234`), Main connects the signal directly (`scripts/main.gd:2422-2435`), and Main dispatches `new_run` to Setup (`scripts/main.gd:2410-2419`).

### [P1] Typed child controls are collapsed into an untyped string protocol

`NewGameSetupSeatCard` and `NewGameSetupOptionBoard` expose typed argument signals (`scripts/ui/new_game_setup_seat_card.gd:6-8`, `scripts/ui/new_game_setup_option_board.gd:4`, `scripts/ui/new_game_setup_option_board.gd:89-97`). `NewGameSetupPage` connects them (`scripts/ui/new_game_setup_page.gd:95-108`) but re-encodes every intent as a string through `action_requested(action_id: String)` (`scripts/ui/new_game_setup_page.gd:6`, `scripts/ui/new_game_setup_page.gd:111-131`). Main then parses prefixes and integer suffixes (`scripts/main.gd:3563-3586`).

The production protocol includes `setup_start`, `setup_back`, `setup_return_table`, player/AI/depth setters, role stepping/randomization, and starter-monster stepping. It cannot represent schema versions, expected draft revisions, stable command IDs, or typed failure receipts.

### [P1] Failed starts consume live RNG and may publish false success context

Run RNG is randomized during Main readiness (`scripts/main.gd:268-271`). Random AI roles are resolved from the live RNG only when starting (`scripts/main.gd:7280-7313`), while region count, site placement, terrain, ocean selection, district goods, and product allocation also consume that live owner during generation (`scripts/main.gd:3939`, `scripts/main.gd:3981-3997`, `scripts/main.gd:4027-4029`, `scripts/main.gd:4054-4098`, `scripts/main.gd:4181-4209`, `scripts/main.gd:4236-4249`). There is no fork/checkpoint commit boundary.

Main emits the start log before it knows the operation will succeed (`scripts/main.gd:3811-3816`) and mutates public logs and visual state before `GameSessionRuntimeController.begin_session()` (`scripts/main.gd:4507-4529`). A rejected start can therefore consume randomness or expose commit-like side effects.

### [P1] Setup rendering reads and mutates state outside a detached draft

Opening Setup normalizes Main-owned AI configuration before rendering (`scripts/main.gd:3499-3509`). The page snapshot is assembled in Main (`scripts/main.gd:3524-3548`) and uses live victory/world queries for threshold summaries (`scripts/main.gd:3557`, `scripts/main.gd:3599`, `scripts/main.gd:3670`; implementations at `scripts/main.gd:2736-2792`). When opened over an active table, the future-run page can therefore depend on current-run state.

Every draft edit writes `ConfigFile`, emits legacy public feedback, and requests a full table refresh (`scripts/main.gd:7081-7122`, `scripts/main.gd:7249-7259`, `scripts/main.gd:7316-7326`). Setup rendering itself does not consume RNG, but opening/editing is not a zero-side-effect application flow.

### [P1] Setup failure has no safe UI receipt

`_new_game()` is void. Its early returns cannot propagate structured failure to `_confirm_start_new_run_from_setup()`, which always restores game speed and closes the menu (`scripts/main.gd:3811-3819`). Setup has no actionable failure title, consequence, suggested action, preserved draft receipt, or guarantee that the old table remains available.

### [P2] AI runtime dynamically depends on Main-owned Setup fields and helpers

`AIRuntimeController` proxies `configured_ai_player_count` and `configured_player_count` through dynamic world access (`scripts/runtime/ai_runtime_controller.gd:396-406`). It calls Main's `_ensure_configured_ai_player_count()` and `_configured_human_player_count()` (`scripts/runtime/ai_runtime_controller.gd:1154-1158`), and AI profile selection reads configured human count (`scripts/runtime/ai_runtime_controller.gd:2952-2960`). `_ensure_player_ai_state()` also writes Main configuration during runtime normalization (`scripts/runtime/ai_runtime_controller.gd:3001-3006`).

These are real production consumers. Removing Main's draft fields requires an explicit read boundary that preserves the current AI algorithm; source deletion alone would break runtime behavior.

### [P2] Existing Setup tests freeze the legacy Main/string contract

`scripts/tools/new_game_setup_page_cutover_bench.gd` connects `NewGameSetupPage.action_requested`, calls Main's setup page/snapshot methods, asserts string action IDs, and invokes Main's action handler directly (`scripts/tools/new_game_setup_page_cutover_bench.gd:132`, `scripts/tools/new_game_setup_page_cutover_bench.gd:146-156`, `scripts/tools/new_game_setup_page_cutover_bench.gd:212-265`, `scripts/tools/new_game_setup_page_cutover_bench.gd:376-384`). Repository scans also found broad fixture use of `_new_game`, `_open_new_game_setup_menu`, `_on_new_game_setup_action_requested`, and Main's configured fields.

These tests must migrate to the active draft/query/command/transaction contracts while retaining equivalent behavioral assertions. Restoring wrappers would preserve the obsolete owner graph.

### [P3] Adjacent dead state increases migration ambiguity

Source scans found definition-only constants at `scripts/main.gd:23-27`, `scripts/main.gd:38`, and a definition-only palette at `scripts/main.gd:132`. `district_lookup` is declared at `scripts/main.gd:170` and only cleared during generation (`scripts/main.gd:3933`). `_roguelike_economic_viability_dev_audit` is written during generation but has no production reader (`scripts/main.gd:159`, `scripts/main.gd:4119-4170`). These are candidates for a separate verified deletion within the setup extraction only if dynamic-reference scans remain clean.

## Current Production Call Graph

### Quick Navigation and Final Settlement

```text
MenuQuickNavigation
  -> MenuOverlay.quick_nav_action_requested
  -> ApplicationFlowPort.submit_action("setup")
  -> ApplicationFlowPort.action_requested (generic)
  -> Main._on_menu_quick_nav_action_requested
  -> Main._start_new_run_from_menu
  -> Main._open_new_game_setup_menu
```

The quick-navigation action list and forwarding live at `scripts/ui/menu_quick_navigation.gd:6-14`, `scripts/ui/menu_quick_navigation.gd:29-47`, `scripts/ui/menu_quick_navigation.gd:113-117`, and `scripts/ui/menu_overlay.gd:374-378`; scene wiring is at `scenes/main.tscn:177` and `scenes/main.tscn:185`. Final settlement translates `new_run` to `setup` (`scripts/runtime/final_settlement_runtime_composition.gd:230-235`) and is connected to ApplicationFlow at `scenes/main.tscn:175`.

### Main Menu

```text
Main._add_main_menu_planet_lobby_panel
  -> MenuRootLobby.action_requested("new_run")
  -> Main._on_menu_root_lobby_action_requested
  -> Main._start_new_run_from_menu
  -> Main._open_new_game_setup_menu
```

The lobby snapshot and direct signal connection are owned by Main (`scripts/main.gd:2357-2407`, `scripts/main.gd:2422-2435`). Dispatch is at `scripts/main.gd:2410-2419`.

### Setup Editing

```text
Main._open_new_game_setup_menu
  -> Main._show_menu (pause live session)
  -> Main._new_game_setup_page_snapshot
  -> NewGameSetupPage.set_page

NewGameSetupOptionBoard / NewGameSetupSeatCard typed signal
  -> NewGameSetupPage.action_requested(encoded String)
  -> Main._on_new_game_setup_action_requested
  -> Main configured_* mutation helper
  -> Main._save_settings
  -> Main._legacy_show_public_action_feedback
  -> Main._request_full_table_presentation_refresh
  -> Main._open_new_game_setup_menu
```

`_show_menu()` pauses an active session (`scripts/main.gd:2925-2962`). `setup_return_table` invokes `_close_menu()`, which resumes it (`scripts/main.gd:3568-3569`, `scripts/main.gd:3474-3492`). `setup_back` opens the main menu instead (`scripts/main.gd:3566-3567`).

### Start

```text
NewGameSetupPage.start_requested as "setup_start"
  -> Main._on_new_game_setup_action_requested
  -> Main._confirm_start_new_run_from_setup
  -> Main._new_game
     -> destructive resets
     -> resolve random roles with live RNG
     -> append WorldSession players
     -> generate districts and initialize domains
     -> seed inventories/history/market/monster/weather/victory state
     -> GameRuntimeCoordinator.begin_session
     -> settings save and full presentation refresh
  -> Main._close_menu
```

## UI Surface Inventory

| Component | Current responsibility | State behavior | Classification |
| --- | --- | --- | --- |
| `NewGameSetupPage` | Renders detached dictionaries and coordinates child widgets (`scripts/ui/new_game_setup_page.gd:33-51`) | Retains only node/input state, but emits untyped action strings (`scripts/ui/new_game_setup_page.gd:6`, `scripts/ui/new_game_setup_page.gd:111-131`) | UI rendering; legacy string adapter |
| `NewGameSetupSeatCard` | Renders one seat, role, and starter choice; exposes typed role/starter signals (`scripts/ui/new_game_setup_seat_card.gd:6-8`) | No world or RNG ownership | UI rendering |
| `NewGameSetupOptionBoard` | Renders integer options and emits `(option_id, value)` (`scripts/ui/new_game_setup_option_board.gd:4`, `scripts/ui/new_game_setup_option_board.gd:89-97`) | No world ownership | UI rendering |
| `NewGameSetupLobby` | Renders setup title/summary | No mutation | UI rendering |
| `NewGameSetupSeatIdentityBoard` | Renders public seat identity | No mutation | UI rendering |
| `MenuRootLobby` | Emits generic `new_run` action (`scripts/ui/menu_root_lobby.gd:194-210`, `scripts/ui/menu_root_lobby.gd:233-234`) | Directly wired to Main | Application navigation; legacy route |
| `MenuOverlay` / `MenuQuickNavigation` | Emits/forwards `setup` quick-nav | No setup owner; routes through ApplicationFlow generic signal | Application navigation; legacy route |

`scenes/ui/NewGameSetupPage.tscn` explicitly composes the lobby, option board, seat grid, and Start/Back/Return controls (`scenes/ui/NewGameSetupPage.tscn:4-8`, `scenes/ui/NewGameSetupPage.tscn:33-37`, `scenes/ui/NewGameSetupPage.tscn:57`, `scenes/ui/NewGameSetupPage.tscn:74-90`). The visual components are reusable after replacing the page-level string protocol.

## Current Action String Contract

| Action | Producer | Consumer | Current effect |
| --- | --- | --- | --- |
| `setup_start` | `NewGameSetupPage` static button (`scripts/ui/new_game_setup_page.gd:24`) | Main (`scripts/main.gd:3563-3565`) | Calls destructive new-game path |
| `setup_back` | Page static button (`scripts/ui/new_game_setup_page.gd:25`) | Main (`scripts/main.gd:3566-3567`) | Opens main menu |
| `setup_return_table` | Page static button (`scripts/ui/new_game_setup_page.gd:26`) | Main (`scripts/main.gd:3568-3569`) | Closes menu and resumes active table |
| `setup_player_count_<n>` | Page option adapter (`scripts/ui/new_game_setup_page.gd:111-116`) | Main (`scripts/main.gd:3570-3572`) | Mutates player count |
| `setup_ai_count_<n>` | Page option adapter | Main (`scripts/main.gd:3573-3575`) | Mutates AI count |
| `setup_challenge_depth_<n>` | Page option adapter | Main (`scripts/main.gd:3576-3578`) | Mutates depth |
| `setup_role_step_<seat>_<step>` | Seat adapter (`scripts/ui/new_game_setup_page.gd:118-122`) | Main (`scripts/main.gd:3579-3580`) | Steps explicit role |
| `setup_role_random_<seat>` | Seat adapter (`scripts/ui/new_game_setup_page.gd:124-126`) | Main (`scripts/main.gd:3581-3582`) | Sets AI role placeholder |
| `setup_monster_step_<seat>_<step>` | Seat adapter (`scripts/ui/new_game_setup_page.gd:128-131`) | Main (`scripts/main.gd:3583-3584`) | Steps starter monster |

Unknown strings fall through without a typed rejection receipt (`scripts/main.gd:3563-3586`).

## Main Ownership Inventory

### Preloads and Constants

| Symbol | Location | Classification | Migration note |
| --- | --- | --- | --- |
| `NewGameSetupPageScene` | `scripts/main.gd:10` | UI composition | Remove from Main when scene-owned Setup flow composes the page |
| `MIN/MAX/DEFAULT_PLAYER_COUNT` | `scripts/main.gd:13-15` | Draft validation/ruleset bounds | Move to one setup contract owner without changing 3-8 semantics |
| `MIN/MAX/DEFAULT_AI_PLAYER_COUNT` | `scripts/main.gd:16-18` | Draft validation | Preserve current clamps and human-count relation |
| `ROLE_RANDOM_INDEX` | `scripts/main.gd:19` | Draft sentinel/randomness | Preserve placeholder semantics; resolve once in the plan |
| `ROGUELIKE_DEPTH_MIN/MAX`, `DEFAULT_ROGUELIKE_DEPTH` | `scripts/main.gd:20-22` | Draft validation | Preserve current range/default |
| `SETTINGS_PATH` | `scripts/main.gd:95` | Local preference persistence | Setup preference debt; not a Save Registry section |
| world-generation constants | `scripts/main.gd:28-32`, `scripts/main.gd:82-92`, `scripts/main.gd:109-130` | Plan construction | Belong with the deterministic plan/world generation owner |
| `STARTING_CASH` | `scripts/main.gd:43` | Session-start rule input | Preserve value and apply through the appropriate player owner |
| `PLAYER_COLORS` | `scripts/main.gd:97-106` | Shared presentation/game identity | Shared; do not delete blindly |
| `MonsterCatalogV06` | `scripts/main.gd:4` | Shared catalog preload | Shared; Setup query should use the formal catalog boundary |
| `RoguelikeEconomicViabilityPolicyScript` | `scripts/main.gd:8` | World-plan validation | Move only with its real generation consumer |

### Fields

| Field | Location | Classification | Current owner behavior |
| --- | --- | --- | --- |
| `configured_player_count` | `scripts/main.gd:165` | Setup draft state | Main-owned; persisted to `ConfigFile` |
| `configured_ai_player_count` | `scripts/main.gd:166` | Setup draft state | Main-owned and dynamically read/written by AI runtime |
| `configured_roguelike_depth` | `scripts/main.gd:167` | Setup draft state | Main-owned |
| `configured_role_indices` | `scripts/main.gd:168` | Setup draft state | Main-owned array; random sentinel supported for AI |
| `configured_starter_monster_indices` | `scripts/main.gd:169` | Setup draft state | Main-owned array independent from roles |
| `district_lookup` | `scripts/main.gd:170` | Dead/legacy candidate | Source scan found declaration and clear only |
| `_roguelike_economic_viability_dev_audit` | `scripts/main.gd:159` | Generation diagnostics | Written during generation; no production reader found |
| `skill_market` | `scripts/main.gd:160` | New-game/live card state | Reset and populated by `_new_game`; must move to its real card owner, not DraftService |

### Methods by Responsibility

#### Application navigation and menu lifecycle

- `_menu_quick_nav_entries` (`scripts/main.gd:2226-2234`): application navigation presentation.
- `_menu_quick_nav_active_key` (`scripts/main.gd:2237-2251`): application navigation presentation.
- `_on_menu_quick_nav_action_requested` (`scripts/main.gd:2258-2262`): generic Setup-to-Main route.
- `_main_menu_root_lobby_snapshot` (`scripts/main.gd:2357-2407`): menu UI snapshot containing `new_run`.
- `_on_menu_root_lobby_action_requested` (`scripts/main.gd:2410-2419`): direct Main setup entry.
- `_add_main_menu_planet_lobby_panel` (`scripts/main.gd:2422-2439`): scene instantiation and signal wiring.
- `_show_menu` (`scripts/main.gd:2925-2962`): shared menu pause lifecycle; retain as shared until its owner is extracted.
- `_close_menu` (`scripts/main.gd:3474-3492`): shared menu resume lifecycle; retain as shared until its owner is extracted.

#### Setup rendering and action routing

- `_start_new_run_from_menu` (`scripts/main.gd:3495-3496`): Setup entry wrapper.
- `_open_new_game_setup_menu` (`scripts/main.gd:3499-3509`): Setup flow and active-table return state.
- `_add_new_game_setup_controls` (`scripts/main.gd:3512-3521`): UI creation/wiring.
- `_new_game_setup_page_snapshot` (`scripts/main.gd:3524-3548`): presentation assembly.
- `_new_game_setup_summary_chip_snapshots` (`scripts/main.gd:3551-3560`): presentation assembly.
- `_on_new_game_setup_action_requested` (`scripts/main.gd:3563-3586`): legacy string dispatcher.
- `_new_game_setup_lobby_snapshot` (`scripts/main.gd:3589-3615`): presentation assembly.
- `_new_game_setup_option_board_snapshot` (`scripts/main.gd:3618-3675`): draft query/presentation assembly.
- `_new_game_setup_seat_card_snapshot` (`scripts/main.gd:3678-3708`): draft query/presentation assembly with AI privacy.
- `_new_game_setup_role_card_face_snapshot` (`scripts/main.gd:3711-3723`): public role presentation.
- `_new_game_setup_starter_card_face_snapshot` (`scripts/main.gd:3726-3739`): public starter presentation.
- `_new_game_setup_seat_identity_snapshot` (`scripts/main.gd:3742-3772`): public seat presentation.
- Setup option/menu wrappers (`scripts/main.gd:3775-3797`): draft mutation navigation.
- `_starter_monster_setup_summary` (`scripts/main.gd:3800-3808`): setup presentation.
- `_confirm_start_new_run_from_setup` (`scripts/main.gd:3811-3819`): start application flow and unsafe lifecycle handling.

#### Draft persistence and validation

- `_save_settings` (`scripts/main.gd:3852-3870`): local preference write.
- `_load_settings` (`scripts/main.gd:3873-3892`): local preference read, invoked at readiness (`scripts/main.gd:268-276`).
- Player/AI/depth setters and normalizers (`scripts/main.gd:7081-7122`): draft mutation, validation, feedback, and presentation refresh.
- Role array/uniqueness/step/random helpers (`scripts/main.gd:7125-7313`): draft validation plus start-time random resolution.
- Starter array/step helpers (`scripts/main.gd:7316-7330`): draft validation/mutation.

#### Plan construction and randomness

- `_roguelike_depth_label`, `_roguelike_planet_profile`, `_roguelike_planet_profile_text` (`scripts/main.gd:3895-3928`): ruleset/plan description.
- `_generate_roguelike_districts` (`scripts/main.gd:3931-3973`): live world construction and RNG.
- `_generate_region_sites` (`scripts/main.gd:3976-3998`): live world construction and RNG.
- `_assign_district_neighbors` (`scripts/main.gd:4001-4024`): topology construction.
- `_land_economic_focus` (`scripts/main.gd:4027-4029`): randomized economy plan input.
- `_assign_district_terrain_and_goods` (`scripts/main.gd:4050-4178`): live topology/economy construction.
- `_roll_ocean_district_indices` (`scripts/main.gd:4181-4209`): RNG plan input.
- product and district geometry helpers (`scripts/main.gd:4212-4329`): plan construction.
- `_resolve_configured_role_indices_for_run` (`scripts/main.gd:7280-7313`): start-time live RNG consumption.

`_district_economy_focus_label`, `_transport_score_from_level`, and `_product_catalog_names` are also dynamically consumed by `ContractRuntimeWorldBridge`; they are shared and cannot be treated as Setup-only (`scripts/runtime/contract_runtime_world_bridge.gd:519`, `scripts/runtime/contract_runtime_world_bridge.gd:521`, `scripts/runtime/contract_runtime_world_bridge.gd:635`). `_nearest_district_to` (`scripts/main.gd:4361-4370`) has broad non-Setup consumers and is also shared.

#### Live owner mutation and session lifecycle

- `_initialize_region_infrastructure_runtime` (`scripts/main.gd:542-563`): domain initialization receipt; called by `_new_game` at `scripts/main.gd:4471` without checking the receipt.
- `_new_game` (`scripts/main.gd:4373-4531`): destructive reset, roster construction, world generation, domain initialization, logging, session begin, settings save, and presentation refresh.
- `_start_card_ingress_animation` (`scripts/main.gd:4534-4552`): commit-time presentation effect.
- Role catalog/runtime card helpers (`scripts/main.gd:4702-4791`): public role query plus runtime role card construction.
- `_make_starting_monster_card` (`scripts/main.gd:4965-4983`): starter entitlement construction.
- `_prime_timers_for_new_game` (`scripts/main.gd:8238-8242`): monster runtime timer mutation.

## Draft Semantics to Preserve

- Player count is bounded by Main's current 3-8 constants (`scripts/main.gd:13-15`).
- AI count is normalized against player count (`scripts/main.gd:16-18`, `scripts/main.gd:7081-7104`).
- Challenge depth retains current bounds/default (`scripts/main.gd:20-22`, `scripts/main.gd:7111-7122`).
- Role order and public definitions come from `RoleCatalogRuntimeService` (`scripts/main.gd:4702-4721`; catalog contract at `scripts/runtime/role_catalog_runtime_service.gd:5-37`).
- Explicit role selection avoids duplicates through Main's current helpers (`scripts/main.gd:7191-7212`).
- The random-role sentinel is accepted only where current normalization permits it, principally AI seats (`scripts/main.gd:7174-7188`, `scripts/main.gd:7249-7257`). It is displayed as a placeholder and resolved once at start (`scripts/main.gd:4769-4791`, `scripts/main.gd:7280-7313`).
- Starter-monster selections use a separate array and catalog path (`scripts/main.gd:7316-7330`, `scripts/main.gd:4965-4983`). Role and starter choices are independent.
- AI starter identity is hidden in Setup presentation (`scripts/main.gd:3678-3708`, `scripts/main.gd:3742-3772`; UI hiding at `scripts/ui/new_game_setup_seat_card.gd:55-61`).
- The page's `can_return_table` is derived from an active WorldSession/GameSession (`scripts/main.gd:3499-3509`). A failed replacement must preserve that active table.

## Classification Summary

| Category | Current authority/location | Cutover implication |
| --- | --- | --- |
| UI rendering | NewGameSetup UI scripts plus Main snapshot builders | Keep UI scripts view-only; move snapshot composition to query port |
| Draft state | Main `configured_*` fields | Replace with one scene-owned draft service; no second copy |
| Validation | Main setter/normalizer cluster | Move unchanged bounds and uniqueness semantics into typed draft commands/preflight |
| Randomness | Live `RunRngService` called from Main plan/start helpers | Use deterministic checkpoint/fork; query and failed plan/start must not advance live RNG |
| Plan construction | Main world-generation helpers | Produce detached data before any owner mutation; shared helpers require real-owner placement |
| Live owner mutation | `_new_game` | Split into owner-specific preflight/checkpoint/apply/rollback contracts |
| Session lifecycle | Main plus GameRuntimeCoordinator/GameSessionRuntimeController | Commit GameSession last; old session must survive failure |
| Presentation refresh | Main public log, card ingress animation, full refresh | Delay until commit and apply once |
| Legacy compatibility | String actions, generic ApplicationFlow, Main fixture APIs, ConfigFile coupling | Remove production route; migrate tests to current owner contracts |
| Dead code | Definition-only constants and fields identified above | Delete only after dynamic-reference verification; do not mix speculative cleanup |

## External Consumers and Protected Boundaries

- `AIRuntimeController` dynamically reads/writes Main setup configuration and invokes Main normalization helpers (`scripts/runtime/ai_runtime_controller.gd:396-406`, `scripts/runtime/ai_runtime_controller.gd:1154-1158`, `scripts/runtime/ai_runtime_controller.gd:2952-2960`, `scripts/runtime/ai_runtime_controller.gd:3001-3006`). Its selection algorithm must remain unchanged.
- `GameplayBalanceDiagnosticsWorldBridge` dynamically queries Main's monster catalog/profile helpers (`scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:167-209`, `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:274-279`). These shared diagnostics consumers require an explicit owner before Main helper deletion.
- `ContractRuntimeWorldBridge` consumes economy/transport/product helpers as noted above. They are not exclusive Setup glue.
- `WorldSessionState` remains the only live players/districts owner; a draft or plan must not mirror live state.
- Existing Save Registry/session envelope contracts are outside this extraction. Setup preferences currently use `ConfigFile`; the setup draft must not become a new save section.
- Existing RoleCatalog, starter monster rules, AI algorithms, gameplay formulas, RuntimeLoop order, PlayerSeat projection, Intel, Compendium, and commodity track behavior are protected parity boundaries.

## Test and Fixture Migration Debt

Repository source scans found the legacy `_new_game` entry in 62 test/tool/report GDScript files, `_open_new_game_setup_menu` in 10, `_on_new_game_setup_action_requested` in 8, and the Main-owned configured fields across 9-30 fixture/tool files depending on the field. Representative consumers include `tests/smoke_test.gd:598-634`, `tests/human_normal_table_playability_v06_test.gd:42-59`, `scripts/tools/full_run_quality_driver.gd:325-337`, and `scripts/tools/new_game_setup_page_cutover_bench.gd`.

Migration must preserve the tested semantics by redirecting fixtures to:

1. DraftService and typed draft commands for setup configuration.
2. ViewerQueryPort for page assertions.
3. SessionStartPlanBuilder for deterministic roster/world plan assertions.
4. SessionStartTransactionCoordinator for successful starts, fault injection, exact-once, and old-session isolation.
5. Formal scene composition for application signal and page lifecycle tests.

Tests must not retain Main wrappers or string action IDs merely to remain green.

## Cutover Handoff

The minimum behavior-preserving extraction is:

1. Add a dedicated `ApplicationFlowPort.setup_requested` route and remove the generic Setup emission.
2. Establish one `NewGameSetupDraftService` for the current `configured_*` values and current normalization semantics.
3. Replace page-level encoded strings with typed signals and typed draft commands carrying revision and command identity.
4. Compose detached Setup snapshots through a read-only query port using RoleCatalog and the public monster catalog.
5. Resolve random roles and all world-generation randomness into one detached deterministic plan without changing live RNG.
6. Add owner-level preflight/checkpoint/apply/rollback, with all preflights and checkpoints complete before the first live mutation.
7. Commit `GameSessionRuntimeController` last and defer logs, audio, UI close, card ingress animation, and table refresh until success.
8. On failure, return a typed receipt, keep Setup and its draft visible, and restore the complete pre-existing active run.
9. Migrate AI and bridge consumers to explicit owners before deleting Main fields/helpers.
10. Delete the Main Setup route, draft fields, page preload, string dispatcher, and `_new_game` glue only after production caller count is zero.

This audit does not authorize changes to game rules, RNG outcomes, AI policy, role/starter semantics, save envelopes, or non-Setup domains.
