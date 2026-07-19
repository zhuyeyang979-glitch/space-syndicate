# Intel Query / Command Audit

## Scope and baseline

- Audit mode: analysis only. No production, scene, test, registry, or save-schema files were changed.
- Worktree: `space-syndicate-intel-query-command-split-657f517`
- Branch: `codex/intel-query-command-split-657f517`
- Baseline: `657f5172e7afa8c31658f90af5f81d076430bf5c`
- Main budget: 10,971 physical lines, 9,481 nonblank lines, 702 methods, 103 constants, 10 top-level preloads, 66 top-level variables.

## Findings first

### [P0] Opening the dossier mutates route state

`Main._intel_dossier_public_source_snapshot()` calls `_refresh_route_network()` before composing any data (`scripts/main.gd:2629-2633`). This makes a nominal read path rebuild runtime route state. It violates the required zero-mutation query boundary and means opening Intel can change route revisions or derived route facts.

Required cutover: the viewer query must consume an already-owned public route projection. It must not initialize or refresh any gameplay owner.

### [P0] Private Intel writes bypass a typed command boundary

The Intel surface emits a raw string (`scripts/ui/intel_dossier_board.gd:4,227-247,327-353`). Main parses that string in one dispatcher and either submits arbitrary annotation patches or writes dictionaries inside `WorldSessionState.players` directly (`scripts/main.gd:2526-2614,6532-6631`). The current path has no command ID, expected revision, typed payload, viewer authorization, or idempotency receipt.

Card-history annotation calls similarly accept a free-form patch through Coordinator (`scripts/main.gd:2531-2561`; `scripts/runtime/game_runtime_coordinator.gd:1276-1297`). The authoritative service validates fields, but the application boundary itself is not typed.

Required cutover: typed city-inference commands must target `WorldSessionState`; card-history commands must delegate to `CardHistoryPrivateAnnotationService`. Neither port may own a second copy.

### [P1] Intel is still a generic ApplicationFlow-to-Main route

`ApplicationFlowPort` has no `intel_requested` signal. `intel` is accepted but falls through to generic `action_requested` (`scripts/runtime/application_flow_port.gd:8-15,24-42`). `scenes/main.tscn:147` connects that generic signal to `Main._on_menu_quick_nav_action_requested`, whose Intel branch opens the dossier (`scripts/main.gd:2281-2286`).

Compendium return target `intel` also submits through this same generic route (`scripts/runtime/compendium_application_flow_controller.gd:195-206`). There is no Intel controller, viewer query port, or private command port in `scenes/main.tscn:74-133`.

### [P1] The current source is not a public snapshot and is not viewer-authorized

The source accepts any in-range player index and reads raw mutable player/district dictionaries (`scripts/main.gd:2629-2679`). It combines:

- public facts;
- the selected viewer's private city guesses, confidence, and reasons;
- the selected viewer's private card-history annotations;
- hidden monster-owner source data before presentation filtering;
- rule values and settlement projections;
- UI width-derived column counts.

The city source reads true `city.owner` to omit own cities and to show correctness after game over (`scripts/main.gd:2773-2816`). Monster clue assembly reads raw `auto_monsters`, including owner-related fields and owner damage cash facts (`scripts/main.gd:3097-3127`). The UI renders snapshot strings and tooltips without an independent privacy sanitizer (`scripts/ui/intel_dossier_board.gd:24-43,139-222,294-340`).

Required cutover: explicitly authorize the local viewer, combine only public owner projections plus that viewer's own private projections, and recursively reject runtime objects and opponent-private state.

### [P1] Read-only Intel navigation mutates table selection

`track_select_*` clears `selected_hand_slot`, focuses a card-resolution entry, and closes the menu (`scripts/main.gd:2562-2567`). Runtime `track_intel_*` also clears the hand slot and changes card-resolution focus before opening Intel (`scripts/main.gd:1526-1531`). The Intel wrappers for city mark/confidence/reason jump the table camera/selection after writes (`scripts/main.gd:2682-2698`).

These are presentation/game-table mutations hidden inside Intel actions. Typed deep links should carry stable IDs and return targets without changing `TableSelectionState`.

### [P1] Four Intel helpers remain shared by AI through Main

`AiRuntimeController` dynamically calls Main for:

- `_intel_city_guess_entries` (`scripts/runtime/ai_runtime_controller.gd:791-792,8167-8186`);
- `_city_intel_priority_score` (`scripts/runtime/ai_runtime_controller.gd:794-795,6823`);
- `_normalized_city_guess_confidence` (`scripts/runtime/ai_runtime_controller.gd:797-798,8081-8103`);
- `_mark_city_guess_for_player` (`scripts/runtime/ai_runtime_controller.gd:1011-1012,8187-8207`).

The dynamic bridge invokes `Main.callv` (`scripts/runtime/ai_runtime_world_bridge.gd:93-97`), and Main binds itself as the AI world (`scripts/main.gd:1320-1321`; `scripts/runtime/game_runtime_coordinator.gd:482`). Confidence/reason constants are also exported from Main (`scripts/main.gd:1106-1125`).

These helpers cannot be blindly deleted in the Intel UI cutover without changing AI behavior. Under the current allowed scope they are retained shared debt. If moved later, AI must receive the same candidate facts and typed command receipt with scoring and random behavior unchanged.

### [P1] The discovered city-guess settlement formula has no production caller

`_player_intel_stats` computes correct/wrong city-guess cash and role bonus (`scripts/main.gd:3205-3241`), but its only discovered callers are `_player_intel_summary` and a smoke fixture; `_player_intel_display_summary` has no production caller (`scripts/main.gd:3244-3297`; `tests/smoke_test.gd:6499`). No separate runtime final-settlement city-guess calculation was found by symbol search.

This audit therefore does not claim settlement is currently wired or unwired by design. The implementer must preserve the constants and formula until a formal settlement parity test identifies the authoritative production consumer. This is a rule-authority gap, not permission to invent or delete rewards.

### [P2] The surface and deep links are stringly typed

The formatter creates action IDs by concatenating district indexes, player indexes, card names, and history IDs (`scripts/runtime/intel_dossier_public_snapshot_service.gd:155-165,192-240`). Main parses them with prefix/split logic and invokes `CompendiumNavigationPort` through `Node.call` (`scripts/main.gd:2526-2607`). The dossier surface only knows a string signal.

Required cutover: typed action/request objects with explicit action kind, stable target ID, viewer, revision, and allowlisted payload. UI layout data may be added after query composition, not stored in the source snapshot.

### [P2] Several Intel helpers are dead or test-only

No production caller was found for `_product_public_status_tags`, `_city_public_status_tags`, `_player_intel_display_summary`, or `_apply_intel_city_reveal` (`scripts/main.gd:2982-3047,3296-3297,6652-6675`). `_ensure_player_role_cards` and `_ensure_player_private_intel_state` only call each other and have no production entry (`scripts/main.gd:5424-5448`); new-game already initializes the city inference dictionaries (`scripts/main.gd:5062-5065`).

The active Intel card-effect path is instead `CardEffectRuntimeRouter -> CardIntelRuntimeService` (`scripts/runtime/card_effect_runtime_router.gd:145-146`; `scripts/runtime/card_intel_runtime_service.gd:26-40`). Dead compatibility must not be restored for fixtures.

## Authority map

| State/fact | Current authority | Audit classification | Cutover rule |
|---|---|---|---|
| Players, districts, game time, city guesses/confidence/reasons | `WorldSessionState` (`scripts/runtime/world_session_state.gd:18-29,162-187`) | Save-owned viewer-private state | Remains sole state owner; add/use narrow typed projection and mutation API. |
| World-session serialization | `WorldSessionEnvelopeCodec` (`scripts/runtime/world_session_envelope_codec.gd:39-42,377-459`) | Save-owned state | Existing city inference fields already round-trip; do not add a second section. |
| Public card history | `CardResolutionHistoryRuntimeService -> CardHistoryPublicQueryPort` (`scripts/presentation/card_history_public_query_port.gd:17-103`) | Read-only public query | Reuse; public actor remains empty unless formally revealed by owner. |
| Private card annotations, subscriptions, role usage | `CardHistoryPrivateAnnotationService` (`scripts/runtime/card_history_private_annotation_service.gd:44-49,73-181,213-359`) | Viewer-private save-owned state | Delegate commands; do not mirror in Intel port. |
| Intel card gameplay effects | `CardIntelRuntimeService` (`scripts/runtime/card_intel_runtime_service.gd:26-40,96-128`) | Gameplay mutation / role-card effect | Retain as gameplay owner. It currently writes city reveal records directly and is not a dossier UI command. |
| Contract trace | `ContractRuntimeController` and `ContractRuntimeWorldBridge` (`scripts/runtime/contract_runtime_controller.gd:734-755`; `scripts/runtime/contract_runtime_world_bridge.gd:138-166`) | Legal card effect / viewer-private state | Retain; it writes `known_contract_parties`, which session save already persists. |
| Dossier formatting | `IntelDossierPublicSnapshotService` (`scripts/runtime/intel_dossier_public_snapshot_service.gd:17-51`) | Presentation | Retain formatter, but feed a viewer-authorized source and typed actions. |
| Dossier UI | `IntelDossierBoard` (`scripts/ui/intel_dossier_board.gd:4,24-43`) | Presentation surface | Must remain stateless and emit typed intents. |

## Production entry and signal map

### 1. Menu quick navigation

`MenuQuickNavigation` includes `intel` and emits it (`scripts/ui/menu_quick_navigation.gd:4,11,20,35,117`) -> `MenuOverlay.quick_nav_action_requested` (`scripts/ui/menu_overlay.gd:266-269,373-374`) -> `ApplicationFlowPort.submit_action("intel")` (`scenes/main.tscn:153`) -> generic `action_requested` -> Main (`scenes/main.tscn:147`) -> `_open_intel_dossier_menu` (`scripts/main.gd:2281-2286,2500-2503`).

`MenuRootLobby` has action/rules/compendium signals but no direct Intel signal or Intel root action (`scripts/ui/menu_root_lobby.gd:4-6,234`; `scripts/main.gd:2403-2419,2453-2457`). Intel is available only after entering the menu shell's quick navigation.

### 2. Compendium return

`CompendiumApplicationFlowController` handles return target `intel` by submitting to `ApplicationFlowPort` (`scripts/runtime/compendium_application_flow_controller.gd:195-206`) -> generic Main path above.

### 3. Runtime GameScreen and RightInspector

Main binds `GameScreen.action_requested` to `_on_runtime_game_screen_action_requested` (`scripts/main.gd:1402-1419`). Intel entries are:

- `codex_intel` -> open dossier (`scripts/main.gd:1461-1473`);
- `track_intel_<resolution>` -> clear hand selection, focus history, open dossier (`scripts/main.gd:1526-1531`);
- `strategy_pressure_competition` -> open dossier (`scripts/main.gd:1679-1684`).

`GameScreen` forwards RightInspector and side-drawer actions (`scripts/ui/game_screen.gd:41,91-92,495-505,561-566`) and creates `track_intel_*` actions/deep links (`scripts/ui/game_screen.gd:775-845`). `GameTableViewModelRuntimeService` also emits those action IDs (`scripts/runtime/game_table_viewmodel_runtime_service.gd:253-254`). Overlay detail actions expose `codex_intel` (`scripts/viewmodels/overlay_layer_snapshot.gd:87-135`; `scripts/presentation/table_presentation_viewmodel_query.gd:122-126`).

### 4. District inspector action

`_selected_district_action_entries` embeds `Callable(self, "_open_intel_dossier_menu")` in `district_open_intel` (`scripts/main.gd:6926-6967`). `_activate_runtime_district_action` invokes it (`scripts/main.gd:1638-1653`). This is a direct UI-to-Main method reference and must become an application intent.

### 5. Keyboard inference shortcuts

Main handles `G` and `M` directly, calling `_cycle_guess_player` and `_mark_selected_city_guess` (`scripts/main.gd:321-377,6455-6462,6527-6529`). These mutate Main presentation state and raw WorldSession dictionaries rather than submitting typed commands.

### 6. Dossier actions

| Action family | Current classification | Current destination |
|---|---|---|
| `history_return_*` | Application navigation | Main closes menu. |
| `history_subscribe_*` | Viewer-private mutation | Raw patch to annotation owner through Coordinator. |
| `history_suspect_*` | Viewer-private mutation | Raw suspect/confidence/tag patch. |
| `history_clear_*` | Viewer-private mutation | Raw full clear patch. |
| `track_select_*` | Presentation/selection mutation | Main changes table selection and closes menu. |
| `track_open_*` | Read-only deep link | Dynamic Compendium port call. |
| `intel_city_mark_*` | Viewer-private mutation | Main writes WorldSession player dictionaries. |
| `intel_city_clear_*` | Viewer-private mutation | Main clears WorldSession player dictionaries. |
| `intel_city_confidence_*` | Viewer-private mutation | Main writes confidence dictionary. |
| `intel_city_reason_*` | Viewer-private mutation | Main writes reason dictionary. |
| `intel_open_region/card/monster/product_*` | Read-only deep link | Dynamic Compendium port call, return target Intel. |
| `intel_open_economy` | Application navigation | Dedicated economy signal. |

### 7. Role/card Intel abilities

Active card effects route through `CardEffectRuntimeRouter` to `CardIntelRuntimeService` for city owner reveal, public history review, subscription, and contract trace (`scripts/runtime/card_intel_runtime_service.gd:26-40`). Contract trace writes the current viewer's `known_contract_parties` (`scripts/runtime/contract_runtime_world_bridge.gd:138-166`). These are gameplay mutations, not dossier queries.

Role definitions expose city-guess reward and card-history role charges (`scripts/runtime/role_catalog_runtime_service.gd:25-29,119-145,185,225`). `CardHistoryPrivateAnnotationService` implements residual catalog and public exclusion (`scripts/runtime/card_history_private_annotation_service.gd:143-181`), but no production UI caller was found at this baseline. The audit does not claim these abilities are currently reachable.

### 8. Save/load refresh

On successful load Main records feedback and opens the main menu; on failure it requests a table refresh (`scripts/main.gd:4430-4442`). No dedicated Intel refresh or open-page restoration path was found. Saved city inference is owned by the world-session envelope; saved annotations are owned by the annotation service. A future Intel page must query fresh owner state when opened rather than maintain a cache across load.

## Current Main inventory and disposition

### Remove in the Intel application cutover

| Main symbol | Location | Reason |
|---|---|---|
| `IntelDossierBoardScene` | `scripts/main.gd:10` | Scene ownership moves to Intel flow/controller composition. |
| `_intel_dossier_public_snapshot_service_node` | `scripts/main.gd:1303-1305` | Main service lookup. |
| `_open_intel_dossier_menu` | `scripts/main.gd:2500-2503` | Application flow responsibility. |
| `_populate_intel_dossier_snapshot` | `scripts/main.gd:2506-2512` | UI apply responsibility. |
| `_add_intel_dossier_board_panel` | `scripts/main.gd:2515-2523` | UI construction/signal wiring. |
| `_on_intel_dossier_board_action_requested` | `scripts/main.gd:2526-2614` | Untyped mixed dispatcher. |
| `_intel_dossier_public_snapshot` | `scripts/main.gd:2617-2626` | Main query plus fallback compose path. |
| `_intel_dossier_public_source_snapshot` | `scripts/main.gd:2629-2679` | Mixed public/private source with route mutation. |
| `_mark_city_guess_from_intel` | `scripts/main.gd:2682-2686` | UI mutation wrapper plus table jump. |
| `_set_city_guess_confidence_from_intel` | `scripts/main.gd:2689-2692` | UI mutation wrapper plus table jump. |
| `_set_city_guess_reason_from_intel` | `scripts/main.gd:2695-2698` | UI mutation wrapper plus table jump. |
| `_first_entries` | `scripts/main.gd:2701-2705` | Only used by Main Intel source helpers. |
| `_city_owner_view_text_for_player` | `scripts/main.gd:2708-2722` | Only used by dossier warehouse source. |
| `_economy_warehouse_risk_entries` + sorter | `scripts/main.gd:2725-2770` | Dossier-only source despite legacy name. |
| `_latest_city_public_clue_text` | `scripts/main.gd:2907-2915` | Dossier-only source helper. |
| `_intel_card_guess_entries` + sorter | `scripts/main.gd:2918-2979` | Dossier-only public-history/private-annotation composition. |
| `_economy_city_public_clue_entries` + sorter | `scripts/main.gd:3050-3094` | Dossier-only source. |
| `_economy_monster_cash_clue_entries` + sorter | `scripts/main.gd:3097-3139` | Dossier-only raw monster source. |
| `_player_intel_exposure_stats` | `scripts/main.gd:3257-3283` | Used only by dossier source and dead summary chain. |
| `_player_intel_pending_summary`, `_player_intel_display_summary` | `scripts/main.gd:3286-3297` | No external production caller found. |
| `_cycle_guess_player`, `_mark_selected_city_guess` | `scripts/main.gd:6455-6462,6527-6529` | Legacy keyboard/direct mutation path. |
| `_set_city_guess_confidence_for_player` | `scripts/main.gd:6592-6610` | UI-only direct mutation. |
| `_set_city_guess_reason_for_player` | `scripts/main.gd:6613-6631` | UI-only direct mutation. |
| `_reveal_city_owner_by_intel_card`, `_apply_intel_city_reveal` | `scripts/main.gd:6634-6675` | No active production caller; active card path is CardIntelRuntimeService. |
| `district_open_intel` Callable | `scripts/main.gd:6941-6947` | Replace direct Main callable with typed application intent. |

### Dead/test-only candidates requiring negative gates

- `_product_public_status_tags` (`scripts/main.gd:2982-3018`): definition only.
- `_city_public_status_tags` (`scripts/main.gd:3021-3047`): definition only.
- `_player_intel_stats`, `_player_intel_summary`, `_player_intel_display_summary` (`scripts/main.gd:3205-3297`): self-contained/dead in production; smoke calls `_player_intel_stats` directly.
- `_ensure_player_role_cards`, `_ensure_player_private_intel_state` (`scripts/main.gd:5424-5448`): isolated compatibility pair; setup already creates the fields.

Do not delete the settlement formula until an authoritative final-settlement parity test replaces the direct smoke oracle.

### Shared helpers that must remain or move with exact consumers

| Helper/state | Exact non-dossier consumer | Required handling |
|---|---|---|
| `_intel_city_guess_entries` + sorter | AI (`scripts/runtime/ai_runtime_controller.gd:791-792,8167-8186`) | Retain until AI receives equivalent typed facts; do not change scoring. |
| `_city_intel_priority_score` | AI scoring (`scripts/runtime/ai_runtime_controller.gd:6823,794-795`) | Retain/move as exact formula owner. |
| `_normalized_city_guess_confidence` | AI (`scripts/runtime/ai_runtime_controller.gd:797-798,8081-8103`) and mutation | Retain/move with command validation. |
| `_mark_city_guess_for_player` | AI apply (`scripts/runtime/ai_runtime_controller.gd:1011-1012,8187-8207`) | Must ultimately call typed WorldSession command, but AI algorithm is out of scope. |
| confidence/reason constants | Main world constant snapshot -> AI (`scripts/main.gd:1106-1125`) | Retain until AI dependency is typed. |
| `_city_intel_hint_for_player` | Indirectly used by AI through `_intel_city_guess_entries` (`scripts/main.gd:2773-2816,3300-3324`) | Same AI boundary. |
| `_load_selected_district_guess` | District/player selection (`scripts/main.gd:7208,7625,7633,7878`) | Remove only together with `selected_guess_player`; it is presentation cache, not owner state. |
| `_selected_city_owner_view_text` | District status (`scripts/main.gd:6678-6689,6854-6872`) | Preserve map/district presentation through a viewer projection. |
| `_player_visible_city_text` | Opponent tableau (`scripts/main.gd:6970-6982,9618-9630`) | Preserve public/private projection semantics. |
| `_refresh_route_network` | Shared route gameplay owner | Keep globally, remove only its Intel-query call at `scripts/main.gd:2632`. |
| `CardIntelRuntimeService` | Active card effect router | Retain. |
| contract trace owners | Active card effect | Retain. |

## Tests and fixtures that must migrate

- User-supplied baseline evidence: `IntelDossierPublicSnapshotCutoverBench` is `19/20`; the sole red is `real_main_route_and_render`. That oracle explicitly requires Main to render the dossier and route the legacy string `mark` action. It is a stale Main-contract migration target, not evidence that the old production route should be restored. The other 19 checks are green.
- `tests/smoke_test.gd:680,696,701,706,712,718` calls Main Intel open/source/mutation APIs; `tests/smoke_test.gd:526,2489,6499` calls legacy guess/stat helpers.
- `scripts/tools/intel_dossier_public_snapshot_cutover_bench.gd:123-126` directly calls Main source/snapshot/open.
- `tests/layout_scene_smoke_test.gd:9516` requires the Main Intel source/snapshot contract.
- `tests/ui_snapshot_capture.gd:133` opens Intel through Main.
- `scripts/tools/bestiary_formal_product_path_driver.gd:224-266` already exercises ApplicationFlow Intel and Compendium return; migrate it to the dedicated boundary.
- `scripts/tools/global_ui_navigation_characterization_registry.gd:44` records the legacy route name.

Replacement tests must prove the same current rules through owners/ports; no Main wrapper may be restored for these fixtures.

## Source-negative gates

After cutover, enforce all of the following:

1. `ApplicationFlowPort.submit_action("intel")` emits dedicated Intel exactly once and generic `action_requested` zero times.
2. `scenes/main.tscn` has one `intel_requested -> IntelApplicationFlowController` connection and zero Intel signal connections to Main.
3. Executable production definitions/calls for the removable Main symbols above are zero.
4. Main contains no `IntelDossierBoardScene` preload and no Intel panel construction.
5. Query source contains zero `_refresh_route_network`, `auto_monsters`, mutable `players`, mutable `districts`, `TableSelectionState`, `_menu_available_content_width`, `Callable`, `Node.call`, `current_scene`, or `/root/Main` access.
6. Query results recursively contain no `Object`, `Node`, `Callable`, `RID`, raw player dictionaries, hidden owner, hidden actor, opponent guess, private cash/hand, or AI plan/score.
7. Intel UI has no direct runtime owner lookup and no arbitrary string-prefix dispatcher for mutation.
8. Private commands require typed kind, command ID, expected revision, authorized viewer, stable subject ID, and allowlisted payload; stale/replay/unauthorized paths mutate zero state.
9. Card annotation commands delegate to `CardHistoryPrivateAnnotationService`; city inference commands delegate to `WorldSessionState`; second owner count is zero.
10. Opening, refreshing, and deep-linking Intel changes zero gameplay, RNG, route, selection, public-log, or save-dirty state.
11. Card-history role APIs are not claimed reachable until a real production action is identified.
12. Main AI helper debt is counted separately from the Intel application route; no test may hide a live Main application call by string concatenation.

## Audit limits / no unsupported claims

- No distinct facility-guess data model or facility stable-ID mutation path was found. Current city inference keys are district indexes. This audit does not claim facility inference is implemented.
- No dedicated MenuRootLobby Intel button exists at this baseline.
- No production dossier action for editing arbitrary `note_text` or `private_tags` exists; the service supports them, but current UI exposes preset suspect/subscribe/clear patches only.
- No production caller for card-history residual-catalog/public-exclusion role APIs was found.
- No dedicated Intel refresh after load was found; the next open composes again.
- No authoritative production consumer for Main's city-guess settlement calculation was found. Settlement parity remains a mandatory implementation gate.
- No Godot runtime or tests were executed for this analysis-only audit.
