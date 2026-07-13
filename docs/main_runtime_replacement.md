# Main Runtime Replacement

## Freeze rule

`scripts/main.gd` is now a compatibility composition root, not a destination for new gameplay systems. New runtime ownership must live in scene-owned controllers. Changes to `main.gd` are limited to thin data adapters, delegation, and deletion of replaced code.

The Sprint 1 baseline was 47,146 non-empty source lines, 2,246 functions, 261 top-level variables, 349 constants, and 18 scene/script/test files with direct `main.gd` references. Non-empty source lines are used so normal spacing changes cannot distort the deletion metric.

## Sprint 1 result

After the forced-decision cutover, `main.gd` has 46,716 non-empty source lines, 2,231 functions, 265 top-level variables, 349 constants, and the same 18 direct scene/script/test references. The compatibility binding added four coordinator references, while deletion of the superseded runtime-built decision panels and duplicate arbitration branches removed 430 non-empty lines and 15 functions overall.

The next extraction must keep the same rule: add one scene-owned runtime owner, route through a narrow pure-data adapter, prove parity, and delete the replaced `main.gd` branch in the same sprint.

## Sprint 2 result

Game-session lifecycle and current-run save ownership now live under `GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator`. The project was characterized before cutover: the current-run file is save version 1, uses Godot Variant-binary `store_var/get_var`, has the player default path `user://space_syndicate_current_run.save`, and stores one flat Dictionary. Campaign progress remains a separate JSON concern and was not changed.

After the cutover, `main.gd` has 46,677 non-empty source lines, 2,224 functions, 264 top-level variables, 347 constants, and the same 18 direct scene/script/test references. Sprint 2 removed 39 non-empty lines, seven functions, one variable, and two duplicate constants from the previous baseline.

## Sprint 3 result: District Purchase Window Runtime Cutover

District purchase-window ownership now lives under `GameRuntimeCoordinator/DistrictPurchaseRuntimeController`. The controller owns the v0.4 12-second qualification timer, one-window-per-player state, view-only/active/suspended/pending-discard/expired/closed transitions, locked access and price context, supply-revision reselection, purchase authorization, privacy-safe UI/debug snapshots, and the legacy v1 save adapter. `RulesetRuntimeBridge.timing_rules().purchase_window_seconds` is the only runtime duration source.

`main.gd` retains a pure-data world qualification adapter and the existing payment, card acquisition/upgrade, economy ledger, hand-limit, and private-discard settlement functions. Player, AI, coach, and test purchase routes all pass through `authorize_district_purchase`; the controller never owns players, districts, cards, cash, monsters, or hands.

After the cutover, `main.gd` has 46,676 non-empty source lines, 2,221 functions, 263 top-level variables, 347 constants, and the same 18 direct scene/script/test references. Sprint 3 removed one non-empty line, three functions, and one top-level variable net. The removed authority includes `district_card_purchase_snapshot`, `_card_purchase_snapshot_matches`, the duplicate player access-multiplier helpers, and the in-root monster graph-distance implementation; one compatibility adapter now delegates qualification to the controller.

## Sprint 4 result: Economy Cashflow Cadence and Payout Planning Cutover

Realtime cashflow cadence and payout planning now live under `GameRuntimeCoordinator/EconomyCashflowRuntimeController`. The controller owns the one-second active-time accumulator, the 60-second GDP basis, pause/block behavior, explicit floor and fractional-remainder arithmetic, pure payout events, privacy-safe aggregate snapshots, and the legacy v1 `economy_cashflow_timer` adapter.

`main.gd` still computes the existing city GDP/min breakdown, transit and route effects, product-market effects, project-share allocations, and role-bonus inputs. It also remains the sole mutator for player cash, city remainder fields, income totals, cash history, and the economic ledger. The controller retains no players, districts, cities, projects, Nodes, Callables, Resources, or rule functions.

After the cutover, `main.gd` has 46,673 non-empty source lines, 2,220 functions, 262 top-level variables, and 345 constants. Against the Sprint 3 baseline, the cutover removes three non-empty lines net, one function, one top-level variable, and two constants. The removed authority includes `economy_cashflow_timer`, `ECONOMY_CASHFLOW_TICK_SECONDS`, `ECONOMY_CASHFLOW_BASIS_SECONDS`, and `_settle_city_project_cashflow_seconds`; `_update_realtime_economy_cashflow` and `_settle_city_cashflow_seconds` remain compatibility wrappers around pure controller calls.

## Sprint 5 result: Scenario Runtime Glue and Progress Ownership Cutover

Scenario runtime state now lives under `GameRuntimeCoordinator/ScenarioRuntimeController`. The controller owns the active scenario id, replay snapshot key, ordered completion signals, failed-attempt counts, phase start time, coach collapse state, completion edge, and the real `ScenarioActionLog`. It continues to use the existing `ScenarioLoader`, `ScenarioProgress`, `ScenarioActionLog`, and `ScenarioFixtureFactory`; no parallel mission system or duplicate scenario definition was introduced.

`main.gd` keeps first_table authored gameplay execution, map/rack/Inspector focus, Coach and menu presentation, Campaign chapter selection and rewards, and real card/economy/AI/monster actions. Its compatibility entry points delegate progress mutations and then apply the controller's pure visual-event request. Out-of-order signals are rejected against the current phase's unchanged `success_signal`, accepted signals are idempotent, player logs merge only the matching viewer's private text, and developer text remains opt-in.

After the cutover, `main.gd` has 46,661 non-empty source lines, 2,219 functions, 255 top-level variables, and 342 constants. Against the Sprint 4 baseline, this removes 12 non-empty lines net, one function, seven top-level variables, and three constants. The removed authority includes `active_scenario_id`, `active_scenario_snapshot_key`, `scenario_completed_signals`, `scenario_phase_failed_attempts`, `scenario_phase_started_at`, `scenario_coach_closed`, `scenario_action_log_entries`, direct `ScenarioLoaderScript` / `ScenarioProgressScript` ownership, and the three in-root visual-event privacy helpers.

## Sprint 6 result: GDP Formula Characterization and Runtime Ownership Cutover

City GDP arithmetic now lives under `GameRuntimeCoordinator/GdpFormulaRuntimeController`, with its characterized parameters in the Inspector-editable `space_syndicate_gdp_formula_v04.tres` Resource. The controller owns production, supplied-demand, transit, competition, disrupted-route, district-damage, temporary control/military pressure, rounding, minimum-floor, breakdown-summary, and change-reason semantics. Its API consumes and returns pure data only.

`main.gd` retains one world-snapshot adapter because district, product-market, route, role, and timer facts still belong to their current runtime domains. It no longer performs GDP arithmetic. `CityProductProjectBridge` remains responsible for allocating the calculated city total to active product projects and private player shares, while `EconomyCashflowRuntimeController` remains responsible for per-second accrual and payout planning. No card gate, project-share, cash mutation, derivative, AI, or ledger algorithm changed.

After the cutover, `main.gd` has 46,578 non-empty source lines, 2,219 functions, 255 top-level variables, and 329 constants. Against the Sprint 5 baseline, this removes 83 non-empty lines and 13 constants while keeping function and state counts flat. The deleted authority includes `_district_transit_gdp`, all in-root production/demand/transit arithmetic, pressure aggregation, GDP summary/reason formatting, and the thirteen `CITY_*` / disruption formula constants.

## Sprint 7 result: First Table Authored Runtime Ownership Cutover

`first_table` authored-content interpretation now lives under `GameRuntimeCoordinator/FirstTableAuthoredRuntimeService`. It consumes the existing `first_table.json` fixture through `ScenarioRuntimeController`, filters authored card/product/monster ids against a pure runtime catalog, selects the teaching product chain, composes current-player-safe mission content, writes phase context and completion copy, and applies the characterized authored district recommendation weights. It does not load a second mission definition or execute gameplay.

`main.gd` remains the world-fact adapter and concrete gameplay executor. It still owns district/city/project lookup, GDP and clue collection, card-supply mutation, AI city actions, monster state, scenario-step action dispatch, map/rack/Inspector focus, and Campaign reward/UI navigation. Public project data is sanitized by the service before entering authored coach content; own project shares remain visible only in the current player's snapshot.

After the cutover, `main.gd` has 46,490 non-empty source lines, 2,212 functions, 255 top-level variables, and 329 constants. Against the Sprint 6 baseline, this removes 88 non-empty lines net and seven functions while keeping top-level state and constants flat. The deleted authority includes the fixture/string-array helpers, four runtime-id interpretation helpers, phase-context formatter, and completion-summary formatter. `FirstTableAuthoredRuntimeCutoverBench` proves the boundary with 16 fixed cases and keeps `legacy_authored_fallback_used=false`.

## Sprint 8 result: Legacy Runtime Surface Retirement

`RuntimeGameScreen` is now a hard composition dependency. `scenes/main.tscn` no longer contains `LegacyRuntimeTable`, and `scripts/main.gd` no longer has a build flag, generated-table shell, split compatibility player host, or a path that can reconstruct the old player-facing table. If `GameScreen` is missing, runtime composition reports an explicit error instead of silently creating a second UI authority.

The duplicate runtime-built Card Resolution Track was deleted with its dedicated geometry constants, scroll/drag state, signature cache, slot construction, badge drawing, event handling, and refresh path. Public card state still comes from the same pure snapshot source, but `GameScreen/PublicTrack/CardResolutionTrack` is now the only renderer. PlayerBoard/HandRack, PlanetBoard, RightInspector, and OverlayLayer remain the corresponding scene-owned surfaces; action ids and existing signal bridges are unchanged.

After the cutover, `main.gd` has 45,073 non-empty source lines, 2,153 functions, 229 top-level variables, and 319 constants. Against the Sprint 7 baseline, this removes 1,417 non-empty lines, 59 functions, 26 top-level variables, and 10 constants. `LegacyRuntimeSurfaceRetirementBench` proves the hard boundary with 14/14 cases: the shell and renderer stay absent, `RuntimeGameScreen` remains primary, track selection still reaches the sceneized screen, snapshots remain pure data, and composition reports zero missing or duplicate runtime surfaces.

## Sprint 9 result: Legacy Player Surface Helper Closure

The hard `GameScreen` cutover left one source-only island: generated player-seat cards, hand/rack controls, resource cubes, action trays, bid controls, selected-district panels, first-summon cards, role-card faces, and the old bottom tableau. A current `main.gd` call graph proved that this island had no runtime caller after `_refresh_player_panel` and the compatibility host were retired. Cross-repository references existed only in obsolete source-text tests and historical notes.

Seventy-eight closed helper functions are now deleted. `PlayerBoard`, `HandRack`, `ActionDock`, `BidBoard`, `RightInspector`, `ScenarioCoach`, and their ViewModel snapshots are the only player-facing owners. The live card-selection, quick-action, selected-district action, contract-response, privacy, and first-mission bridges remain in `main.gd`; no gameplay function was moved merely because its name mentioned a player or card.

After the cutover, `main.gd` has 42,963 non-empty source lines, 2,075 functions, 229 top-level variables, and 319 constants. Against Sprint 8, this removes 2,110 non-empty lines and 78 functions with no new compatibility state. `LegacyPlayerSurfaceRetirementBench` proves the boundary with 18 fixed cases and requires the full retired-function set to remain absent.

## Sprint 10 result: Menu Shell Runtime Cutover

The real runtime menu now requires the embedded `MenuOverlay` from `OverlayLayer`. `MenuOverlay` owns title, context, hint, body, preview host, scroll state, global and catalog navigation, responsive layout, and shell styling. Its new `MenuQuickNavigation` child owns seven explicit editor-visible Buttons for setup, scenario, standings, economy, intel, rules, and compendium. It consumes pure descriptors and emits the existing string action ids; no Callable or runtime Node crosses that boundary.

The fallback `MenuOverlayScene` preload and `_build_menu_overlay()` branch are deleted. `main.gd` no longer mirrors twenty scene-owned shell nodes, constructs quick-navigation Buttons, stores Button references, computes duplicate shell geometry, or retains the unused legacy menu action-card helpers. It now binds the required scene, supplies pure shell/page descriptors, and routes emitted ids into the existing menu commands. Page-specific Codex and setup composition remains in `main.gd` and is the next ownership target.

After the cutover, `main.gd` has 42,670 non-empty source lines, 2,070 functions, 209 top-level variables, and 318 constants. Against Sprint 9, this removes 293 non-empty lines, five functions, twenty top-level variables, and one constant. `MenuShellRuntimeCutoverBench` proves the boundary with 18/18 cases, including the embedded real overlay, seven editable buttons, root/subpage behavior, active-page disabling, real action routing, scene-owned responsive layout, catalog navigation, pure snapshots, and absence of all fallback builders.

## Sprint 11 result: Codex Scene Hard Cutover

The card atlas and the Card, Monster, Product, Region, and Role detail surfaces are now required scene contracts. `CardCodexBrowser.tscn`, `CardCodexDetail.tscn`, `BestiaryDetail.tscn`, `ProductCodexDetail.tscn`, `RegionCodexDetail.tscn`, and `RoleCodexIdentityBoard.tscn` own their rendering. `main.gd` still supplies the existing pure source snapshots and routes the existing filter, page, preview, detail, and catalog action ids, but it cannot rebuild these pages with generated Controls.

Twenty-four fallback functions are deleted: the generated card thumbnail atlas, filter chips, hover preview, card detail layout, tactical cards, level-gradient cards, monster detail board, product market board, region tile board, and their chip/KPI/action helpers. A broken scene or missing `set_*` method now reaches `_report_required_ui_scene_missing()` and stops that page instead of silently creating a parallel renderer.

After the cutover, `main.gd` has 41,691 non-empty source lines, 2,046 functions, 209 top-level variables, and 318 constants. Against Sprint 10, this removes 979 non-empty lines and 24 functions without new compatibility state. `CodexSceneHardCutoverBench` proves the boundary with 20/20 cases, including real-main scene usage, browser-to-detail signal routing, all six scene contracts, pure snapshots, privacy filtering, and absence of the full retired-function set.

## Sprint 12 result: Codex Atlas Scene Cutover

The Monster and Product atlas surfaces now live in `BestiaryCodexBrowser.tscn` and `ProductCodexBrowser.tscn`. Both browsers own their paging controls, overview summaries, thumbnail grids, selected-state presentation, embedded real detail preview, and preview/detail input signals. Repeated entries are real `BestiaryCodexThumbnailCard`, `ProductCodexThumbnailCard`, and `CodexBrowserSummaryCard` scene instances; product entries reuse the existing `ProductCodexMarketBadge` component, and monster entries keep their `MonsterArtView` inside the thumbnail scene.

`main.gd` remains the temporary source adapter for public catalog snapshots and the compatibility router for catalog indices. It no longer constructs either atlas with raw Controls, owns thumbnail mouse handlers, builds ecology/market summary cards, or creates a duplicate monster-art preview. The browser boundary accepts pure dictionaries and emits only integer catalog indices, so hidden owner, private target, private discard, private plan, and AI plan data cannot cross through a Node or Callable reference.

After the cutover, `main.gd` has 41,301 non-empty source lines, 2,040 functions, 209 top-level variables, and 320 constants. Against Sprint 11, this removes 390 non-empty lines and six functions net; the two added constants are required scene preloads. Fourteen generated atlas helpers are absent. `CodexAtlasSceneCutoverBench` proves the boundary with 20/20 cases, including editable repeated scenes, real-main browser usage, paging and preview/detail signal routing, pure snapshots, privacy filtering, and the deletion metric gate.

The next closed extraction is catalog navigation and snapshot-source ownership. It should move selected index, page, detail/preview mode, return target, and pure catalog-source composition into a scene-owned controller without moving gameplay catalog lookup, product-market formulas, monster actions, card effects, or Scenario/Campaign rules.

## Sprint 13 result: Codex Navigation Runtime Ownership Cutover

`GameRuntimeCoordinator/CodexNavigationRuntimeController` is now the single owner for the active catalog branch, return target, Monster/Card/Product selected and preview state, page indices, detail modes, card filter, Region index, and Role index. It also owns the shared page-count/page-for-index/first-index arithmetic used by all three thumbnail atlases. The controller is an editable scene, exposes pure-data domain/navigation/debug snapshots, and accepts no player, district, card, product-market, monster, Scenario, Campaign, Node, Resource, or Callable payload.

The current-run save remains version 1 at the same path. `main.gd` merges `to_legacy_save_snapshot()` under the twelve historical keys and delegates restore through `apply_legacy_save_snapshot()`. The pre-existing omission of transient Card Codex page/detail/preview state is preserved deliberately; this sprint does not broaden the v1 save envelope. Existing open/back/cycle/filter/preview routes and scene signals keep their action semantics while reading or mutating the required controller node.

After the cutover, `main.gd` has 41,263 non-empty source lines, 2,036 functions, 192 top-level variables, and 320 constants. Against Sprint 12, this removes 38 non-empty lines net, four functions net, and seventeen top-level variables. Nine domain-duplicated pagination helpers are deleted; three thin generic adapters delegate to controller pagination. `CodexNavigationRuntimeCutoverBench` proves the boundary with 20/20 cases, exact v1 key parity, real-main route delegation, pure snapshots, privacy checks, and absence of all retired state variables and helpers.

The next safe boundary is the public catalog source-adapter layer. It should characterize and extract pure Card/Monster/Product/Region/Role source snapshots before moving page routing. Gameplay catalog functions such as monster actions and probabilities, product-market formulas, card effects, district facts, role rules, and Scenario/Campaign behavior must remain with their current runtime owners until separate characterization gates exist.

## Target composition

`GameRuntimeCoordinator` is the transition point toward a future thin `GameRuntimeRoot`. It only composes services and exposes pure-data snapshots. It must not own economy formulas, card effects, monster simulation, AI scoring, UI rendering, or a duplicate global state dictionary.

The first complete cutover is `ForcedDecisionRuntimeScheduler`. It owns only:

- v0.4 priority arbitration;
- deterministic same-priority ordering;
- viewer-safe active-decision metadata;
- global-time, player-action, and card-resolution blocking decisions.

Existing handlers continue to own wager settlement, counter-card effects, contract outcomes, target selection, and private discard effects. Existing action ids and signals are unchanged.

`GameSessionRuntimeController` owns lifecycle (`idle`, `starting`, `running`, `paused`, `loading`, `finished`, `error`), safe session identity, dirty state, and save-operation state. It deliberately does not retain players, districts, cards, economy, monsters, or AI state.

`GameSaveRuntimeCoordinator` is the single owner for current-run save version, default path, Variant-binary envelope composition, validation, legacy `charge/control` normalization, file I/O, and saved-run menu metadata. Its debug snapshot never contains the full save payload.

`DistrictPurchaseRuntimeController` is the single owner for district-rack purchase-window state. Opening an ineligible district creates a view-only record with no timer. Eligible opening locks the access type and final channel multiplier for 12 seconds; later monster movement, removal, or binding changes do not mutate that window. Switching district, closing the drawer, or timeout invalidates authorization. Rack inventory is never reserved, and a changed supply revision keeps the window open while requiring card reselection. Private snapshots may say `channel discount`, but never identify the source monster or its owner.

`EconomyCashflowRuntimeController` is the single owner for realtime cadence and payout planning. Session pause, SceneTree/time pause, game over, and forced-decision global blocking preserve accumulated active time; ordinary overlays do not stop it. Inputs are pure income-source facts, outputs are pure payout events, and neither side carries runtime objects.

`ScenarioRuntimeController` is the single owner for transient scenario selection and progress glue. `GameRuntimeCoordinator.reset_state()` deliberately does not clear it because scenario activation precedes `_new_game`; free runs use explicit `clear_runtime_scenario()`. Controller snapshots contain data only and never retain main, GameScreen, players, districts, cards, monsters, or other runtime Nodes.

`GdpFormulaRuntimeController` is the single owner for city GDP arithmetic. The editable profile is the only runtime source for the characterized formula constants. The controller never reads players, districts, product-market state, routes, game time, or project owners directly; those facts cross the boundary as a pure snapshot. The controller also does not allocate project shares or mutate cash.

`FirstTableAuthoredRuntimeService` is the single owner for interpreting `first_table` authored content. It never holds players, districts, cards, monsters, GameScreen, Coach nodes, or runtime Resources. World facts enter as pure data, and the service returns only pure catalog, content, copy, score, and debug snapshots.

## Ownership map

| Domain | Current owner | Target state |
| --- | --- | --- |
| Ruleset parameters | RulesetRuntimeBridge | Complete |
| Shared card-window timing | CardResolutionRuntimeController | Complete |
| City-development legality | CityDevelopmentRuntimeController | Complete |
| Forced-decision priority | ForcedDecisionRuntimeScheduler | Complete |
| Session lifecycle | GameSessionRuntimeController | Complete |
| Current-run save envelope and file I/O | GameSaveRuntimeCoordinator | Complete |
| Domain save collection/application | Explicit main.gd compatibility adapters | Replace as each domain gains a runtime owner |
| District purchase qualification, timer, and locked price context | DistrictPurchaseRuntimeController | Complete |
| District purchase payment, acquisition, upgrade, and private discard settlement | Existing main.gd rule functions behind controller authorization | Preserve until their own domain cutover |
| Realtime cashflow cadence, remainder arithmetic, and payout planning | EconomyCashflowRuntimeController | Complete |
| City GDP arithmetic, formula parameters, rounding, pressure, and floor | GdpFormulaRuntimeController + GDP Formula Resource | Complete |
| GDP world-state snapshot, products, routes, project shares, cash and ledger mutation | main.gd adapter plus existing economy modules | Replace as each domain gains a runtime owner |
| Monster world simulation | main.gd | Domain runtime owner |
| AI action execution | main.gd | AI runtime coordinator using existing policy logic |
| Scenario progress, phase timing, replay key, coach state, and action log | ScenarioRuntimeController using existing scenario services | Complete |
| first_table fixture interpretation, content ids, coach context, completion copy, and authored district score | FirstTableAuthoredRuntimeService | Complete |
| first_table world facts, gameplay actions, Campaign rewards, and UI navigation | Existing main.gd compatibility adapters | Preserve until the corresponding domain runtime owners exist |
| Player-facing runtime table, public track, player board, map, inspector, and overlays | GameScreen and scene-owned child components | Complete; legacy generated surface deleted |
| Player seats, hand/rack/card face, district supply, action dock, bid board, selected-district actions, first-summon feedback, and resource tableau rendering | PlayerBoard, HandRack, CardFace, DistrictSupply components, ActionDock, BidBoard, RightInspector, ScenarioCoach, and ViewModel snapshots | Complete; 96 closed main.gd helpers deleted |
| Menu shell layout, styles, responsive sizing, scroll, global/catalog navigation, and branch shortcut Buttons | MenuOverlay + MenuQuickNavigation | Complete; generated fallback and mirrored shell state deleted |
| New-game setup composition, summary, options, seat cards, hint, and setup action intents | NewGameSetupPage plus existing setup child scenes | Complete; generated page builders and child preloads deleted |
| Card browser plus Card/Monster/Product/Region/Role detail rendering | Six scene-owned Codex components | Complete; 24 generated fallback renderers deleted |
| Product public summary, thumbnail, market detail, KPI, and strategy-card presentation | ProductCodexPublicSnapshotService | Complete; market/futures/warehouse facts remain domain-owned |
| Card browser, preview, detail, tactical, fact, upgrade, and resolution presentation | CardCodexPublicSnapshotService using existing browser/detail ViewModels | Complete; prices, effects, targets, upgrades, and legality remain domain-owned |
| Economy Overview summary, overview cards, chips, KPIs, decisions, and six dashboard lanes | EconomyDashboardPublicSnapshotService + EconomyDashboard scene | Complete; product prices, GDP, city income, cashflow, clues, and private truth remain domain-owned |
| Standings summary, overview cards, chips, KPIs, and viewer-safe seat cards | StandingsPublicSnapshotService + StandingsScoreboard scene | Complete; cash, GDP, settlement score, final ordering, and private truth remain domain-owned |
| Final Settlement summary, chips, KPIs, money cards, public events, rank track, and after-actions | FinalSettlementPublicSnapshotService + FinalSettlementBoard scene | Complete; final score, ordering, city clearance, intel cash, and income facts remain domain-owned |
| Intel Dossier summary, evidence cards, private-mark controls, public links, and action intents | IntelDossierPublicSnapshotService + IntelDossierBoard scene | Complete; city-guess mutation, hidden truth, wagers, settlement, and Codex navigation remain domain-owned |
| Monster public summary, thumbnail, detail board, chips, KPIs, action cards, and tooltips | MonsterCodexPublicSnapshotService | Complete; 14 duplicated main.gd formatters deleted |
| Role/Region public summaries, boards, chips, KPIs, clues, and role route labels | CodexPublicSnapshotService | Complete; 23 duplicated main.gd formatters deleted |
| UI snapshots and action routing | main.gd adapters | Thin snapshot/action bridge |

## Sprint 14: Codex Public Snapshot Ownership Cutover

`GameRuntimeCoordinator/CodexPublicSnapshotService` is now the single presentation owner for Role and Region Codex summaries, identity/detail boards, chips, KPI rows, clue rows, card-face adaptation, route labels, and public privacy copy. The service is an editable `Node` scene and accepts only pure-data world-fact snapshots. It does not read players, districts, cards, monsters, markets, Scenario state, runtime Nodes, Resources, or Callables.

`main.gd` retains two narrow world-fact adapters: `_role_codex_public_source_snapshot()` gathers public role facts and `_region_codex_public_source_snapshot()` gathers viewer-safe district, city, route, weather, card-pool, monster-pressure, and public-clue facts. Existing gameplay and economy helpers remain authoritative for those facts. The Coordinator duplicates service outputs before returning them to the menu UI, and `RoleCodexIdentityBoard` / `RegionCodexDetail` continue rendering the same snapshot shapes.

The cutover deletes 23 Role/Region presentation functions. `main.gd` now has 40,986 non-empty source lines, 2,019 functions, 192 top-level variables, and 320 constants, down from Sprint 13's 41,263 / 2,036 / 192 / 320. `CodexPublicSnapshotCutoverBench` proves the boundary with 20/20 cases covering source purity, Role/Region parity, real-main routing, Coordinator composition, injected-private-key rejection, and deletion metrics. Monster and Product public snapshots remain out of this sprint because their current closures mix presentation with probability and market facts; they require characterization before cutover.

## Sprint 15: Monster Codex Public Snapshot Ownership Cutover

`GameRuntimeCoordinator/MonsterCodexPublicSnapshotService` now owns monster Codex summary copy, atlas-entry payloads, detail-board payloads, HP/armor/speed/resource chips, ecology/action KPIs, action-card presentation, bound-monster-card preview copy, and hover/detail tooltips. It is a separate editable scene rather than another branch inside the Role/Region service.

The remaining `_monster_codex_public_source_snapshot()` adapter in `main.gd` gathers existing domain facts: catalog identity, ecology profile, artwork profile, movement/range text, real bound-card identity and price, action numeric facts, and the current I/IV open/destroyed probabilities. `_monster_codex_action_probability_facts()` still calls the existing action-weight algorithms; the scene service only formats supplied percentages and explicitly reports `calculates_action_weights=false`.

Fourteen monster presentation formatters are deleted. `main.gd` now has 40,859 non-empty source lines, 2,010 functions, 192 top-level variables, and 320 constants, down from Sprint 14's 40,986 / 2,019 / 192 / 320. `MonsterCodexPublicSnapshotCutoverBench` proves 20/20 source-purity, probability-display, ecology, card-preview, real-atlas/detail routing, privacy, composition, and deletion cases. Product presentation remains separate because its current source mixes market price, futures, warehouse, clues, weather, and strategy-score facts.

## Sprint 16: Product Codex Public Snapshot Ownership Cutover

`GameRuntimeCoordinator/ProductCodexPublicSnapshotService` now owns Product Codex summary copy, atlas-entry payloads, market-board detail payloads, price/supply/demand/disruption/volatility chips, market/strategy/weather/card-route KPIs, six public strategy cards, previews, and tooltips. The service is an editable scene and explicitly reports `calculates_market_price=false`, `calculates_strategy_scores=false`, and `reads_runtime_nodes=false`.

`main.gd` retains a narrow `_product_codex_public_source_snapshot()` adapter. It asks the existing domain owners for current/base prices, trend, price history, strategy rankings, anonymous futures counts, public warehouse locations, monster resource preferences, related cards, supply/demand districts, and sanitized city-clue lines. It never sends player cash, hands, hidden owner ids, private plans, private targets, or private discards to the presentation service.

The cutover retires 20 Product presentation functions and one already-unreferenced Product city-name helper. `main.gd` now has 40,584 non-empty source lines, 1,997 functions, 192 top-level variables, and 320 constants, down from Sprint 15's 40,859 / 2,010 / 192 / 320. `ProductCodexPublicSnapshotCutoverBench` proves the boundary with 20/20 cases covering supplied market/strategy parity, real atlas/detail routing, Coordinator composition, privacy rejection, and formatter deletion.

## Sprint 17: Card Codex Public Snapshot Ownership Cutover

`GameRuntimeCoordinator/CardCodexPublicSnapshotService` now owns Card Codex browser summaries, filter and thumbnail payloads, hover previews, detail summaries, CardFace payloads, tactical cards, public fact cards, upgrade rows, resolution copy, and tooltips. The service deliberately reuses the existing browser/detail ViewModels, `CardCodexBrowserSnapshot` and `CardCodexDetailSnapshot`, instead of replacing their normalized UI contracts.

`main.gd` retains narrow public-fact adapters. They gather existing card identity, price, category, route, subtype, supply layer, effect text, target flags, play requirement, public read chips, rule facts, upgrade facts, and resolution-animation labels. The service explicitly reports `calculates_card_price=false`, `calculates_card_effects=false`, `calculates_play_requirements=false`, and `reads_runtime_nodes=false`; all card rules and legality remain in their current domain owners.

The cutover retires 19 Card presentation formatters and removes the two direct ViewModel preloads from `main.gd`. `main.gd` now has 40,366 non-empty source lines, 1,984 functions, 192 top-level variables, and 318 constants, down from Sprint 16's 40,584 / 1,997 / 192 / 320. `CardCodexPublicSnapshotCutoverBench` proves the boundary with 20/20 cases covering both ViewModels, browser/detail parity, real-main routing, Coordinator composition, private-input rejection, pure-data output, rule ownership, and formatter deletion.

## Sprint 18: Economy Dashboard Public Snapshot Ownership Cutover

`GameRuntimeCoordinator/EconomyDashboardPublicSnapshotService` now owns the public Economy Overview body, four overview cards, refresh/monster/weather chips, GDP/product/city/clue KPIs, three next-decision routes, and the hot-product, cold-opportunity, city-cashflow, anonymous-aftermath, monster/warehouse-risk, and next-read lanes. `EconomyDashboard.tscn` now includes an editable `EconomyDashboardOverviewGrid`, so `main.gd` no longer creates the four overview cards as temporary Controls.

`main.gd` retains one bounded `_economy_dashboard_public_source_snapshot()` adapter. It evaluates existing domain owners once, sanitizes opponent money into privacy-only entries, and supplies product/city/public-clue facts without Nodes, Resources, Callables, hidden owner ids, hands, private plans, private targets, or private discards. The service explicitly reports `calculates_product_prices=false`, `calculates_city_income=false`, `calculates_cashflow=false`, `evaluates_private_truth=false`, and `reads_runtime_nodes=false`.

The cutover retires 16 Economy Dashboard formatting and cold-sort helpers. `main.gd` now has 40,063 non-empty source lines, 1,971 functions, 192 top-level variables, and 318 constants, down from Sprint 17's 40,366 / 1,984 / 192 / 318. `EconomyDashboardPublicSnapshotCutoverBench` proves 20/20 ownership, parity, privacy, bounded-source, real-main rendering, and deletion cases; the real Economy Overview opens in 92ms under its five-second performance gate.

## Sprint 19: Standings Public Snapshot Ownership Cutover

`GameRuntimeCoordinator/StandingsPublicSnapshotService` now owns the public Standings body, three overview cards, goal/countdown/city/privacy chips, four race KPIs, and viewer-safe seat cards. `StandingsScoreboard.tscn` now includes an editable `StandingsOverviewGrid`, so `main.gd` no longer creates the three overview cards as temporary Controls.

`main.gd` retains one bounded `_standings_public_source_snapshot()` adapter. Existing domain owners still calculate cash, city count, GDP/min, settlement estimates, intelligence settlement, bankruptcy, and final ordering. The adapter only includes private numeric fields for the selected player or after the domain declares game-over visibility; ordinary opponent entries contain name, seat, bankruptcy, and a privacy flag only. The service explicitly reports `calculates_settlement_score=false`, `calculates_city_income=false`, `sorts_final_rankings=false`, `evaluates_private_truth=false`, and `reads_runtime_nodes=false`.

The cutover retires four Standings presentation formatters and the runtime-created overview grid. `main.gd` now has 39,997 non-empty source lines, 1,970 functions, 192 top-level variables, and 318 constants, down from Sprint 18's 40,063 / 1,971 / 192 / 318. `StandingsPublicSnapshotCutoverBench` proves 20/20 ownership, privacy, final-visibility, eight-seat bounds, real-main rendering, performance, and deletion cases; the real Standings menu opens in 43ms under its five-second performance gate.

## Sprint 20: Final Settlement Public Snapshot Ownership Cutover

`GameRuntimeCoordinator/FinalSettlementPublicSnapshotService` now owns the postgame summary, winner/goal/city chips, four KPI cards, money-source cards, public card/monster/map/track events, final rank cards, and the existing `standings`, `economy`, and `new_run` after-action descriptors. `FinalSettlementBoard.tscn` remains the sole renderer and emits the same action ids.

`main.gd` retains one bounded `_final_settlement_public_source_snapshot()` adapter plus the existing `_final_settlement_money_source_entries()` fact adapter. Existing domain owners still calculate final scores, ordering, city clearance, intelligence cash, accumulated income/spend, map facts, and public impact summaries. The service explicitly reports `calculates_final_score=false`, `sorts_final_rankings=false`, `calculates_city_clearance=false`, `calculates_intel_cash=false`, `reads_private_hands=false`, and `reads_runtime_nodes=false`.

The cutover retires four Final Settlement presentation formatters. `main.gd` now has 39,882 non-empty source lines, 1,969 functions, 192 top-level variables, and 318 constants, down from Sprint 19's 39,997 / 1,970 / 192 / 318. `FinalSettlementPublicSnapshotCutoverBench` proves 20/20 ownership, supplied-score/order parity, public event coverage, stable after-action ids, eight-seat bounds, real-main rendering, performance, private-input rejection, and deletion cases; the real postgame board opens in 48ms under its five-second performance gate.

## Sprint 21: Intel Dossier Public Snapshot and Action-ID Controls Cutover

`GameRuntimeCoordinator/IntelDossierPublicSnapshotService` now owns the viewer-safe Intel Dossier summary, header chips, KPIs, focused public-track evidence chain, city/card/monster/warehouse/public-city clue cards, city inference control groups, public Codex/economy links, and their stable action-intent ids. `IntelDossierBoard.tscn` exposes editable `IntelDossierControlGrid` and `IntelDossierLinkGrid` sections and is the only component that creates their runtime Buttons.

`main.gd` retains one bounded `_intel_dossier_public_source_snapshot()` adapter and one action-id router. Existing owners still calculate city investigation priority, read only the current viewer's guesses, mutate city marks/confidence/reasons, settle intelligence cash, resolve card-owner wagers, protect hidden owner truth, focus the public track, and navigate Codex pages. The service explicitly reports that it mutates no guesses, settles no cash, reveals no hidden truth, reads no private hands, and navigates no runtime Nodes.

The cutover retires 22 Intel presentation formatters, summary helpers, and runtime `Button.new()`/`Callable` builders from `main.gd`. Existing `track_return_*`, `track_guess_*`, and `track_open_*` ids remain unchanged; new city and public-link controls use `intel_city_*` and `intel_open_*` ids. `main.gd` now has 39,527 non-empty source lines, 1,951 functions, 192 top-level variables, and 318 constants, down from Sprint 20's 39,882 / 1,969 / 192 / 318. `IntelDossierPublicSnapshotCutoverBench` proves 20/20 ownership, action-id, privacy, Coordinator composition, real-main rendering, performance, private-input rejection, and deletion cases; the final editor-MCP run opens the real dossier in 47ms under its five-second gate.

## Sprint 22: New Game Setup Page Scene Cutover

`NewGameSetupPage.tscn` now owns the complete player-facing setup page: the compact summary rail, real `NewGameSetupLobby` and `NewGameSetupOptionBoard` instances, the stable seat-card scroll/grid, real `NewGameSetupSeatCard` instances, the privacy hint, and the recommended/start/back/return-table command row. It accepts one pure page snapshot and translates child signals into stable `setup_*` action ids; it never creates a run, assigns roles, chooses monsters, or navigates the menu by itself.

`main.gd` retains one bounded `_new_game_setup_page_snapshot()` adapter and one `_on_new_game_setup_action_requested()` router. Existing configuration helpers still own player/AI counts, challenge depth, role and starter-monster selection, recommended setup, run creation, and menu navigation. The cutover removes six generated page builders, one unreferenced menu wrapper, and three direct child-scene preloads. `main.gd` now has 39,482 non-empty source lines, 1,947 functions, 192 top-level variables, and 316 constants, down from Sprint 21's 39,527 / 1,951 / 192 / 318.

`NewGameSetupPageCutoverBench` proves 20/20 editable composition, scroll stability, all option/seat/primary action ids, pure-data and privacy boundaries, real-main rendering and routing, opening performance, and deletion metrics. The setup page opens through the real menu route in roughly 0.1 seconds under the five-second gate.

## Sprint 23: Extended Legacy Player and Card Surface Retirement

A fresh call-graph audit found a second closed island left behind by the original player-surface migration: the generated table-goal prompt, direct `CardArtViewScript` card renderer, private hover tween, hand play-state lamp/rail, card-face chip rail, and generated district card list/buttons. None had a live runtime caller. Real cards already render through `HandRack` and `CardFace`; district purchasing already renders through `DistrictSupplyDrawer`, `DistrictSupplyMarketCard`, and `DistrictSupplyPreviewCard`; the current primary action already crosses the pure runtime snapshot into `PlayerBoard` and `ActionDock`.

Eighteen additional dead functions, the direct CardArt preload, and four obsolete hover constants are deleted. Rule/data helpers that remain live, including `_table_goal_primary_action`, `_hand_card_play_state`, `_hand_card_action_text`, `_card_face_chip_entries`, `_card_face_route_text`, prices, purchase authorization, card effects, and target rules, are unchanged. The existing `LegacyPlayerSurfaceRetirementBench` is expanded rather than duplicated: it now guards a 96-function retired set and requires all real card/supply scenes.

After the cutover, `main.gd` has 38,884 non-empty source lines, 1,929 functions, 192 top-level variables, and 311 constants, down from Sprint 22's 39,482 / 1,947 / 192 / 316. Main composition and layout gates remain green before the broader runtime regressions.

## Sprint 24: Campaign / Scenario Presentation Settings and Pause Actions Scene Cutover

`PresentationSettingsPanel.tscn` now owns the campaign and scenario presentation-setting hierarchy, summary/privacy copy surfaces, and twelve static editor-visible command buttons. `ScenarioPauseActionsPanel.tscn` owns the five active-scenario pause commands. Both components accept pure dictionaries, expose pure debug snapshots, and emit stable string action ids; neither component changes settings, persists data, restarts a scenario, or navigates the menu by itself.

`main.gd` keeps the existing presentation-setting variables, persistence functions, campaign/scenario navigation, restart/replay behavior, and one bounded action-id router. The cutover deletes the generated campaign settings button factory, the generated scenario settings row, the generated pause-action row, the old scenario settings summary helper, and the menu-section builder pair that had no remaining caller. No gameplay rule, scenario progression, campaign reward, save version, or privacy behavior moves in this sprint.

The existing `MenuShellRuntimeCutoverBench` is expanded instead of duplicated. Its 24/24 gate now proves the two new scene contracts, eight campaign setting ids, four scenario setting ids, five pause ids, real-main back/settings routes, pure snapshots, and permanent absence of the retired builders. QA output remains under `user://space_syndicate_design_qa/menu_shell_runtime_cutover/`.

## Sprint 25: Planet Map Control Toolbar Scene Cutover

`PlanetMapControlToolbar.tscn` now owns the fullscreen map reading hints, seven existing layer-focus buttons, current layer/district/trade/contract status, the trade-product selector, and the two contract endpoint commands. The scene includes the six required public reading layers plus the pre-existing city layer so the cutover does not silently remove an available map mode. It accepts one pure snapshot and emits `control_action_requested(action_id, payload)` using only strings and dictionaries.

`FullscreenMapOverlay.tscn` embeds the toolbar under `FullscreenMapActionHost`. `main.gd` keeps `_map_control_toolbar_snapshot()`, `_on_map_control_toolbar_action_requested()`, the existing layer/trade state, and the existing contract validation/execution functions. Three generated-control builders, the old OptionButton callback, thirteen mirrored Node arrays, and all their refresh loops are deleted. The map projection, district input, route calculation, contract qualification, selected-district behavior, save data, and privacy rules are unchanged.

`PlanetMapInteractionBench` now proves 15/15 cases: the original seven district/focus/projection checks plus editable toolbar composition, layer and product payloads, disabled/enabled contract endpoint guards, real-main routing, pure snapshots, and the permanent deletion gate. `main.gd` moves from 38,881 non-empty lines / 1,927 functions / 192 top-level variables / 313 constants to 38,757 / 1,925 / 179 / 313.

## Sprint 26: District Supply Drawer Scene Ownership Cutover

`DistrictSupplyDrawer.tscn` now owns the complete district-rack presentation lifecycle: title and rule copy, the existing `DistrictPurchaseWindowStatus`, reusable status chips, repeated `DistrictSupplyMarketCard` scenes, the selected `DistrictSupplyPreviewCard`, static empty states, privacy copy, keyboard focus links, and aggregate preview/purchase/close action intents. Its `set_supply()` and `debug_snapshot()` contracts contain only dictionaries, arrays, strings, numbers, and booleans; display colors cross the bridge as hexadecimal strings.

At the Sprint 26 boundary, `main.gd` retained `_district_supply_drawer_snapshot()`, `_on_district_supply_action_requested()`, open/close state, card/world fact adapters, and all existing purchase rules. It no longer preloaded the two repeated child scenes, mirrored six Drawer child nodes, created status chips or market/preview controls, or traversed market-card Nodes to build focus links. Sprint 27 below supersedes the temporary full-snapshot ownership while preserving the same action and purchase-rule boundary.

`DistrictPurchaseRuntimeController` remains the only authority for the 12-second qualification window, locked access and price context, expiry, reselection, private discard continuation, and v1 save compatibility. Existing payment, acquisition, upgrade, hand-limit, card-effect, and temporary-decision settlement functions are unchanged. The expanded `DistrictPurchaseRuntimeCutoverBench` proves 33/33 controller and Drawer cases, including real-main open/render/close routing, disabled Buy behavior, focus, empty states, pure data, privacy, and permanent deletion. `main.gd` moves from 38,757 non-empty lines / 1,925 functions / 179 top-level variables / 313 constants to 38,726 / 1,924 / 173 / 311.

## Sprint 27: District Supply Snapshot Service Cutover

`GameRuntimeCoordinator/DistrictSupplySnapshotService` is now the single presentation formatter between district-supply facts and `DistrictSupplyDrawer.set_supply()`. `main.gd` evaluates each card's existing eligibility, locked price, play requirement, targeting, and public card facts once in `_district_supply_snapshot_source()`. The service receives only dictionaries, arrays, strings, numbers, and booleans, rejects runtime objects and private owner/hand-card/channel/plan/target/discard fields, and emits hexadecimal display colors.

The service owns title/rule copy, header chips, market-state summary, market-card snapshots, selected preview, verdict and decision chips, scan sections, CardFace presentation, empty states, and privacy copy. It explicitly owns no purchase eligibility, price, cash, inventory, upgrade, hand-limit, private discard, or settlement behavior. `DistrictPurchaseRuntimeController` remains the sole 12-second qualification/window authority, while `DistrictSupplyDrawer` remains the sole node, focus, empty-state, and aggregate-action owner.

Nineteen legacy snapshot/formatting functions are permanently removed from `main.gd`; no formatter fallback remains there. The expanded `DistrictPurchaseRuntimeCutoverBench` proves 45/45 controller, service, source-contract, format-parity, privacy, real-main route, Drawer-interaction, and deletion cases. `main.gd` moves from 38,726 non-empty lines / 1,924 functions / 173 top-level variables / 311 constants to 38,282 / 1,908 / 173 / 311.

## Sprint 28: District Purchase Settlement Characterization

The existing `DistrictPurchaseRuntimeCutoverBench` now preserves its 45 controller, Snapshot Service, and Drawer ownership gates and adds 17 real-main settlement observations. Each observation records pure-data before/after cash, counted-hand, anonymized family/rank slots, purchase counters, private-ledger deltas, window state, pending-discard state, and public/private event counts. Harness completion (`observed`) is separate from rules and atomicity conformance (`contract_aligned`), so a future mismatch cannot be reported as aligned.

The 17 cases prove new-card commit, duplicate-family in-place upgrade, rank-IV rejection, exact debit and one-time private spend ledger, insufficient-cash rollback, non-reserved supply, five-card private-discard suspension, fixed-skill hand-limit exemption, discard cancel/confirm/invalid-slot behavior, queued/locked discard guards, pending-state cash drift revalidation, shared AI authorization, public/private feedback separation, and one-time post-commit hooks. Sprint 28 records 45/45 ownership, 17/17 observed, 17/17 aligned, and 62/62 harness cases.

Full-project call-graph, reflected-call, signal, scene, test, and save searches found no producer for `_upgrade_skill_slot()`, `_replace_skill_slot()`, `_can_upgrade_skill_slot()`, or `_can_replace_skill_slot()`. Those obsolete direct-settlement branches are removed; all purchases continue through `_buy_card_for_player_from_district()` and `_acquire_card_for_player()`. The actual settlement mutation remains in `main.gd` until Sprint 29 introduces one scene-owned transaction service against this contract. `main.gd` moves from 38,282 non-empty lines / 1,908 functions / 173 top-level variables / 311 constants to 38,195 / 1,904 / 173 / 311.

## Sprint 29: District Purchase Settlement Runtime Service Cutover

`GameRuntimeCoordinator/DistrictPurchaseSettlementRuntimeService` is now the single atomic owner for district-purchase planning, same-family upgrade priority, ordinary five-card limit evaluation, private discard validation, temporary-copy mutation, exact cash debit, card add/upgrade/replacement, purchase count, total card spend, private ledger intents, and cash-history update. It exposes pure `plan_purchase`, `commit_purchase`, `validate_discard`, inventory-receive compatibility, and privacy-safe debug APIs. It owns no purchase timer, locked context, presentation Node, scenario rule, role bonus, or bankruptcy algorithm.

`_buy_card_for_player_from_district()` remains as a compatibility adapter: it collects current world facts, asks `DistrictPurchaseRuntimeController` for authorization, calls the settlement service, orchestrates the existing private discard Overlay, writes the committed player Dictionary back, and forwards existing public/scenario/role-bonus/bankruptcy hooks. Human, AI, Coach, and resumed-discard routes all use this path. `_acquire_card_for_player()` and receive/hand-limit helpers remain thin service delegates because non-purchase card effects still call them; purchase-only record/discard/slot-search helpers are removed.

The existing Bench is expanded rather than duplicated. It passes 45/45 ownership, 17/17 observed, 17/17 aligned, and 18/18 service cutover cases, for 80/80 total. The service rejects cash, inventory, supply, authorization, and discard drift without partial mutation; a second commit of a stale plan cannot duplicate counters, ledger entries, or event intents. `main.gd` moves from 38,195 non-empty lines / 1,904 functions / 173 top-level variables / 311 constants to 38,197 / 1,900 / 173 / 311: the transaction formulas leave main, while explicit pure world-fact and compatibility adapters make the boundary slightly more verbose.

## Sprint 30: Card Inventory and Private Hand Mutation Characterization

The new `CardInventoryRuntimeCharacterizationBench` locks the shared inventory boundary before a dedicated runtime owner is introduced. It instantiates real `main.tscn`, uses real cards, role templates, district facts, fixed military commands, player dictionaries, save composition, and the current Settlement Service generic inventory API. No production path in `main.gd` changes during this sprint.

Twenty cases prove the current add, upgrade, rank-IV rejection, ordinary five-card limit, fixed-skill exemption, queued/locked discardability, role bonus, extra supply, successful steal, failed-steal conversion, disrupt removal, private lock, human/AI policy parity, fingerprint drift, save shape, public/private boundary, call graph, and duplicate-formula status. Results are 20/20 observed, 20/20 aligned, zero mismatches, and zero unresolved design decisions.

The key ownership finding is intentionally mixed. Generic receive/upgrade has one temporary implementation in `DistrictPurchaseSettlementRuntimeService`; fixed-skill grant, private remove, private lock, and steal/disrupt orchestration remain direct compatibility paths. An unreceivable steal is deliberately converted to target removal plus card-defined compensation, not rolled back. Sprint 31 may introduce one `CardInventoryRuntimeService`, but the current receive formula must move rather than be copied, and the purchase service must retain cash/ledger/counter atomicity. `main.gd` remains exactly 38,197 non-empty lines / 1,900 functions / 173 top-level variables / 311 constants in Sprint 30.

## Sprint 31: Card Inventory Runtime Service Cutover

`GameRuntimeCoordinator/CardInventoryRuntimeService` is now the single scene-owned slot-mutation authority. The generic implementation was moved out of `DistrictPurchaseSettlementRuntimeService`, not copied. It owns receive/add, same-family upgrade, rank-IV rejection, ordinary five-card counting, fixed-skill exemption, discardability, fingerprint drift, private remove, private lock, and two-player transfer mutation. Ruleset values come from the v0.4 profile through `RulesetRuntimeBridge`.

`DistrictPurchaseSettlementRuntimeService` keeps price, cash, purchase count, total spend, private purchase ledger, cash history, and complete purchase atomicity. It receives the inventory service as internal Coordinator wiring and delegates slot planning/application on its temporary player copy. `main.gd` retains real card/player fact construction, RNG/AI target selection, card-effect order, compensation, private-ledger detail, and public-event forwarding; its receive/remove/lock/transfer functions are thin service adapters.

Failed steal reception remains the characterized `converted_to_remove` outcome: the target card is not restored and the existing card-defined compensation is applied by effect orchestration. This is not a generic transaction rollback.

The existing Bench is expanded to 20/20 observed, 20/20 aligned, and 20/20 cutover, for 40/40 total. It verifies the static scene owner, ruleset source, pure payloads, all mutation families, purchase/role/extra-supply delegation, human/AI parity, drift rejection, save/privacy boundaries, exact-once mutation, and permanent removal of the legacy formula from the purchase service and `main.gd`.

The explicit fact, generic receive, and two-player transfer adapters move `main.gd` from 38,197 non-empty lines / 1,900 functions / 173 top-level variables / 311 constants to 38,261 / 1,903 / 173 / 311. The increase is compatibility wiring, not duplicated inventory policy. Sprint 31 SHA-256 after cutover is `EAC951C7FF094C1B17041AB2B490A3F2D853BBC9CB7EF819F1317A47BAE1B604`.

## Sprint 32: Player Hand Interaction Runtime Characterization

`PlayerHandInteractionRuntimeCharacterizationBench` now instantiates real `main.tscn` and observes all four ranks of `星链拆解` and `影仓牵引`. Its twenty cases lock the live call graph, eight-card catalog, repeated remove/transfer order, post-operation lock, cash cap, duplicate-family receiver upgrade, rank-IV `converted_to_remove`, partial success, one-time compensation, queued dispatch, human/AI route parity, private/public event split, and existing save/action/signal contract. `observed` and `contract_aligned` are reported separately so an authored-rule mismatch cannot be hidden by a green harness.

The ownership boundary does not move in this sprint. `CardInventoryRuntimeService` remains the only slot-mutation owner. `main.gd` remains the higher-level interaction owner for seeded target choice, repeat ordering, penalties, compensation, private ledgers, public logs/callouts, and `_resolve_queued_skill()` kind dispatch. The new Bench and contract are QA artifacts, not a second settlement implementation.

Public output retains the played card, target seat, and aggregate effect while hiding the acting player and exact affected private cards. Exact lost, locked, or received card details remain in the appropriate private ledgers. QA manifest/report output contains aggregate deltas only. Sprint 33 may introduce one `PlayerHandInteractionRuntimeService` only if these observations remain stable and the corresponding `main.gd` orchestration is deleted in the same cutover.

Sprint 32 does not modify production `main.gd`; it remains 38,261 non-empty lines / 1,903 functions / 173 top-level variables / 311 constants with SHA-256 `EAC951C7FF094C1B17041AB2B490A3F2D853BBC9CB7EF819F1317A47BAE1B604`.

## Sprint 33: Player Hand Interaction Runtime Cutover

`PlayerHandInteractionRuntimeService.tscn` is now statically composed under
`GameRuntimeCoordinator`. It owns disrupt/steal operation counts and order,
the post-operation lock, cash-cap penalty, one-time compensation, aggregate
resolution result, and private/public/action-callout intents. It performs all
card changes on temporary player copies by delegating every remove, lock,
receive/upgrade, transfer, and `converted_to_remove` mutation to the existing
`CardInventoryRuntimeService`, then commits actor and target state once.

`main.gd` retains only real player/card fact composition, the existing seeded
RNG slot draws, private-ledger/public-log/visual forwarding, and the two thin
`_apply_player_hand_*` compatibility entry points used by queued resolution.
The old take, lock, and two-player transfer helpers were deleted; penalty and
compensation formulas no longer exist in `main.gd`. Human and AI cards still
converge on the same queued resolver and stable action/signal/save contract.

The upgraded long-lived Bench passes **20/20 observed**, **20/20 aligned**, and
**20/20 cutover**, total **40/40**. Public QA records remain aggregate-only and
all output stays under `user://space_syndicate_design_qa/`.

Production `main.gd` moves from 38,261 non-empty lines / 1,903 functions / 173
top-level variables / 311 constants to **38,200 / 1,906 / 173 / 311**. The
three additional function boundaries are thin request, RNG, and event-forward
adapters; the file loses 61 non-empty lines and all three legacy card-mutation
helpers. Sprint 33 SHA-256 is
`CF4DE493ECEEFF6C88D5F4CB919DB477B6CDDA5104D2AFA8BBC9D946FD044050`.

## Sprint 34: Card Resolution Queue Runtime Characterization

`CardResolutionQueueRuntimeCharacterizationBench` now instantiates real
`main.tscn` and records twenty-eight queue-lifecycle observations. The gate is
**28/28 observed** and **28/28 contract aligned**, with alignment reported
separately from observation. It covers commitment atomicity, persistent versus
one-use cards, exact-once play cost, 0-3 groups, bid normalization and order,
lock annotations, current-to-active pop, invalid-entry skip, response routing,
next-batch promotion, v1 save parity, and public privacy.

The ownership result is intentionally partial. `CardResolutionRuntimeController`
continues to own 30/25/5 timing, while `main.gd` still owns
`card_resolution_queue`, `active_card_resolution`,
`next_card_resolution_queue`, construction, sorting, lock, pop, and promotion.
No `CardResolutionQueueRuntimeService` exists in Sprint 34. The next sprint must
introduce one service and delete the characterized main-owned lifecycle in the
same change; it may not copy `_resolve_queued_skill` or card effects.

Production `main.gd` remains byte-identical at **38,200 non-empty lines / 1,906
functions / 173 top-level variables / 311 constants**, SHA-256
`CF4DE493ECEEFF6C88D5F4CB919DB477B6CDDA5104D2AFA8BBC9D946FD044050`.

## Sprint 35: Card Resolution Queue Runtime Cutover

`CardResolutionQueueRuntimeService.tscn` is now statically composed under
`GameRuntimeCoordinator` and is the only owner of current, active, and next
queue containers, resolution sequence, group construction/order/sort, bid
normalization, lock metadata, active pop/invalid skip, counter removal,
next-batch promotion, legacy queue save fields, and privacy-safe debug state.

`main.gd` no longer stores any of the four queue fields or the old priority
reference. Its remaining queue-named functions are stateless compatibility or
world/event adapters: they collect real player/card/cash facts, coordinate the
queue and `CardInventoryRuntimeService` plans, apply existing cash/ledger and
scenario/public feedback, and invoke the unchanged `_resolve_queued_skill()`.
`CardResolutionRuntimeController` remains the sole 30/25/5 timer, and
`CardInventoryRuntimeService` remains the sole card-slot mutation owner.

The upgraded long-lived Bench passes **28/28 characterization** and **28/28
cutover**, total **56/56**. The v1 flat save envelope and action/signal/privacy
contracts remain unchanged. Production `main.gd` moves from 38,200 non-empty
lines / 1,906 functions / 173 top-level variables / 311 constants to
**38,144 / 1,909 / 168 / 311**. The three net function additions are thin
service access/compatibility boundaries; the file loses 56 non-empty lines and
all five queue state variables. Sprint 35 SHA-256 is
`8F7DDDB5F987E9D0269B558966CBA8CFDBC6DFD4A4248632D13861ABFBBA86F6`.

## Sprint 36: Card Resolution Execution Runtime Characterization

`CardResolutionExecutionRuntimeCharacterizationBench` now instantiates real
`main.tscn` and observes twenty-eight cases from active-entry lookup through
counter handling, target/requirement drift, concrete effect dispatch,
commitment finalization, public/private feedback, resolved history, next-card
start, and v1 save parity. It uses real cash, product, district, monster,
player-interaction, contract, intel, counter, generated city-development, and
runtime-bound persistent cards. The gate is **28/28 observed** and **28/28
contract aligned**, with those counts reported separately.

The main architectural finding is that only the fixed five-second counter
window retains the active card. Target choices complete before submission;
area-trade contracts deliberately copy their response context into
`pending_contract_offers`, clear active, allow later cards to continue, and
patch the same `resolution_id` in history after accept/reject/timeout. Monster
wager remains a separate Forced Decision owner that freezes planet simulation
without becoming a second card queue owner.

No production ownership moves in Sprint 36. Queue lifecycle stays in
`CardResolutionQueueRuntimeService`, timing stays in
`CardResolutionRuntimeController`, inventory shape stays in
`CardInventoryRuntimeService`, hand interaction stays in its runtime service,
and concrete economy/city/route/monster/contract rules remain unchanged.
`main.gd` still owns `_complete_active_card_resolution()` orchestration and the
`_resolve_queued_skill()` dispatch shell. Sprint 37 may move that shell only if
it deletes the old implementation in the same cutover and keeps concrete rule
owners outside the new service.

Production `main.gd` remains byte-identical at **38,144 non-empty lines / 1,909
functions / 168 top-level variables / 311 constants**, SHA-256
`8F7DDDB5F987E9D0269B558966CBA8CFDBC6DFD4A4248632D13861ABFBBA86F6`.

## Sprint 37: Card Resolution Execution Runtime Cutover

`CardResolutionExecutionRuntimeService.tscn` is now statically composed under
`GameRuntimeCoordinator` and owns active-card execution transactions, ordered
intents, requirement/target result envelopes, continuation classification, and
exactly-once finalization. `CardResolutionExecutionWorldBridge.tscn` is a
stateless intent executor; it chooses no phase and owns no queue, timer,
inventory, or concrete card rule.

`_complete_active_card_resolution()` is now a thin plan/advance/finalize loop.
The old `_resolve_queued_skill()` shell is absent. `main.gd` retains pure fact
construction, the concrete `_apply_card_resolution_effect_request()` world
adapter, commitment/history hooks, and the existing card-effect algorithms.
Queue lifecycle remains solely in `CardResolutionQueueRuntimeService`; timing
remains solely in `CardResolutionRuntimeController`.

The long-lived Bench now passes **28/28 observed**, **28/28 aligned**, and
**28/28 cutover**, total **56/56**. Counter, no-refund drift, persistent and
consumable commitment, paid-cost markers, selection restoration, contract
continuation, Forced Decision handoff, history, next-start, promotion, save,
and privacy boundaries remain compatible.

Production `main.gd` moves from 38,144 non-empty lines / 1,909 functions / 168
top-level variables / 311 constants to **38,140 / 1,915 / 168 / 311**. The six
net functions are narrow request/effect/receipt/bridge boundaries; the legacy
execution shell and lifecycle branches are deleted. Sprint 37 SHA-256 is
`434908251C2118E1A4064E4FED51AE2194C494C95D4146FAB32B9C5785421585`.

## Sprint 38: Economy / Product / Route Card Effect Family Modularization

`CardEconomyProductRouteEffectRuntimeService.tscn` is now a static child of `GameRuntimeCoordinator`. It owns the pure handler registry, family classification, effect plans, and result envelopes for seventeen economy, product, and route handlers. `CardEconomyProductRouteEffectWorldBridge.tscn` owns the stateless route to the existing concrete `_apply_*` world functions.

`main.gd::_apply_card_resolution_effect_request()` no longer contains those seventeen family branches. It asks the Coordinator for a pure family plan, sends that plan through the scene bridge, and returns the finalized result to the unchanged Execution Service lifecycle. The old family dispatch is not retained as a fallback.

Execution Service did not grow: it still owns only lifecycle intents and exactly-once completion. Queue, 30/25/5 timing, inventory, interaction, prices, futures, GDP, contracts, routes, ledgers, AI, and privacy rules keep their existing owners.

Sprint 38 production metrics:

- Before: 38,140 non-empty lines, 1,915 functions, 168 top-level variables, 311 constants; SHA-256 `434908251C2118E1A4064E4FED51AE2194C494C95D4146FAB32B9C5785421585`.
- After: 38,130 non-empty lines, 1,917 functions, 168 top-level variables, 311 constants; SHA-256 `897F54E40788EC43D051BE059BB2059A5559B596E2650C8AB53CC46F31C1CBFA`.

The two additional functions are narrow scene lookup and cash-effect world adapters. The monolithic execution match lost seventeen concrete family branches.

## Sprint 39: Product Market, Futures, GDP Derivative, and Route Formula Cutover

`CardEconomyProductRouteFormulaRuntimeService.tscn` is now a static sibling of the Effect Family Service under `GameRuntimeCoordinator`. It owns eleven deterministic operations for product-market boons, speculation pressure, futures duration/payout/projection, GDP-derivative duration/expiry/destruction payout, route base flow, route-flow multiplier composition, and boon-source merging.

Already modular formulas were not copied. Product price and flow-speed models remain in `RuntimeBalanceModel`; production/consumption/transit city GDP and its penalties/floor remain in `GdpFormulaRuntimeController`. The Effect Family Service still owns the seventeen handler plans, the WorldBridge still commits existing world mutations, and Execution Service remains unchanged and formula-agnostic.

The compatible `main.gd` function names remain for tests, saves, and reflective callers, but their arithmetic bodies now collect pure facts, call `GameRuntimeCoordinator.calculate_card_economy_product_route_formula()`, and apply the returned scalar or market entry. `PRODUCT_FUTURES_PAYOUT_UNIT` and the characterized boon/futures/derivative/route formulas are absent from `main.gd`; no fallback copy remains.

The long-lived execution Bench now passes **28/28 observed**, **28/28 aligned**, and **40/40 cutover**, total **68/68**. Its twelve new gates separately prove formula scene composition, pure API ownership, existing price/GDP owners, parity for boon/speculation/futures/GDP-derivative/route arithmetic, main formula deletion, Effect Family routing, and Execution Service isolation.

Sprint 39 production metrics:

- Before: 38,130 non-empty lines, 1,917 functions, 168 top-level variables, 311 constants; SHA-256 `897F54E40788EC43D051BE059BB2059A5559B596E2650C8AB53CC46F31C1CBFA`.
- After: 38,130 non-empty lines, 1,918 functions, 168 top-level variables, 310 constants; SHA-256 `F4BFF02505F95676AA1DDA37F89C485A302752056182C8F729A9CF285B7EFD39`.

The one net function is the generic pure-formula Coordinator adapter. Formula implementations moved without adding another execution, queue, timing, inventory, AI, save, or world-state authority.

## Sprint 40: Contract, City Product, Demand, and Route Insurance Formula Cutover

The existing `CardEconomyProductRouteFormulaRuntimeService` now owns nineteen deterministic formulas. The second cluster adds product-contract pressure/volatility, city-contract income and route-flow boons, accepted-contract flow, route insurance, first-lowest city product upgrade/replacement, modulo demand replacement, and shared permanent-revenue/zero-floor route-repair adjustment.

No second service or Bench was added. The long-lived real-main execution gate expands from **68/68** to **80/80**: **28/28 observed**, **28/28 aligned**, and **52/52 cutover**. Its new gates separately prove formula parity, deletion of the corresponding `main.gd` arithmetic bodies, candidate RNG ownership, exact world commit ownership, and continued Execution Service isolation.

`main.gd` remains the narrow world adapter for this cluster. It checks city/owner eligibility, chooses real catalog candidates through `_economy_candidate_product()` in the original order, applies returned pure snapshots exactly once, and emits existing panic, cash, ledger, route refresh, callout, and log effects. The Formula Service never reads Nodes, districts, players, RNG, private plans, or runtime objects.

Sprint 40 production metrics:

- Before: 38,130 non-empty lines, 1,918 functions, 168 top-level variables, 310 constants; SHA-256 `F4BFF02505F95676AA1DDA37F89C485A302752056182C8F729A9CF285B7EFD39`.
- After: 38,141 non-empty lines, 1,917 functions, 168 top-level variables, 310 constants; SHA-256 `0D46E013D8EA2BA131C61D6E6F183B2E99BF7E929A245FF31FBA4B22D5DE1C0A`.

The line count grows slightly because six world-facing handlers now validate structured formula results explicitly; the duplicated first-lowest helper is removed and the function count decreases by one. No gameplay, queue, timing, AI, save, action-id, signal, or privacy ownership moved into the generic Execution Service.

## Save compatibility boundary

`main.gd` temporarily retains two explicit adapters:

- `_capture_run_domain_state_compatibility_adapter()` collects existing flat domain fields. Delete portions only when the owning domain controller exposes stable save data.
- `_apply_run_domain_state_compatibility_adapter()` applies those existing fields and invokes the same normalization and migration helpers. Delete portions only when the owning domain controller accepts its section directly.

The public `_capture_run_state()` and `_apply_run_state()` names remain thin wrappers for existing tests and tools. They no longer own versioning, paths, normalization, validation, or file I/O. The adapters must shrink in every later ownership sprint; they must not become a second save system.

For save version 1 compatibility, the flat key `district_card_purchase_snapshot` remains in the file envelope, but its value is now composed by `DistrictPurchaseRuntimeController.to_legacy_save_snapshot()`. Loading delegates to `apply_legacy_save_snapshot()`: a missing field means no active window, and a legacy `opened_at` whose 12-second qualification has elapsed restores safely as expired. The save version and default path are unchanged.

The flat v1 key `economy_cashflow_timer` also remains unchanged. Capture reads it from `EconomyCashflowRuntimeController.to_legacy_save_snapshot()`, and load restores it through `apply_legacy_save_snapshot()`. City `cashflow_remainder` and `project_cashflow_remainder_by_player` remain in their existing city save data; the controller calculates their next values but does not become a second persisted domain-state owner.

Detailed scenario progress remains intentionally transient in save version 1. The save envelope does not gain active scenario, completed-signal, failed-attempt, coach, replay-key, or action-log fields in Sprint 5; save version `1` and `user://space_syndicate_current_run.save` remain unchanged.

## Deletion gates

`scripts/main.gd` can be deleted only when:

1. `main.tscn` uses a thin scene-owned runtime root.
2. Persisted state is composed from domain `to_save_data` / `apply_save_data` APIs without a save-version regression.
3. No scene, tool, or test loads or calls `scripts/main.gd` directly.
4. Existing action ids, public signals, privacy boundaries, and first-mission behavior remain compatible.
5. Runtime card flow, first mission, city project, layout smoke, and editor diagnostics are green.
6. Obsolete v0.3 tests are migrated or removed instead of keeping compatibility gameplay alive.

Every replacement sprint must add one real owner and delete the corresponding `main.gd` branches in the same change. Parallel legacy and new runtime authorities are not allowed.
# Sprint 41 - AI Runtime Hard Cutover

- Added scene-owned `AiRuntimeController` and stateless `AiRuntimeWorldBridge` under `GameRuntimeCoordinator`.
- Enabled `ai_policy_profile_v1.tres` as the real runtime policy source and removed the duplicated AI timing, threshold, learning, route, phase, and personality constants from `main.gd`.
- Moved AI state, candidate generation, scoring, response planning, route/product/city/monster strategy, learning, audits, and automatic decision cadence out of `main.gd`.
- Kept existing card, economy, city, route, monster, military, weather, contract, queue, execution, and shared RNG owners unchanged.
- Save version 1 keeps its legacy timer keys while also carrying the controller-owned `ai_runtime_state` section.
- Expanded the existing AI Policy QA gate to 44 cases; old tests now call the Controller API instead of private `main.gd` AI methods.
- `main.gd` moved from 38,141 to 31,017 nonblank lines and from 1,917 to 1,706 functions: a net deletion of 7,124 nonblank lines and 211 functions. The retained AI adapter surface is 90 lines.
- Post-cutover `main.gd` SHA-256: `BB89CABE7E7D04B2CDC5EC9E9E7AAF780DC8660C46FA669829C1EBCD901FEE5F`.

## Sprint 42: Card Presentation and Game Table ViewModel Hard Cutover

`CardPresentationRuntimeService.tscn` now owns card accents, icons, category and route labels, use-case copy, card-face rules/chips/tooltips, hand-card ViewModels, and card-resolution cinematic copy, targets, stages, styles, radii, and aftermath clues. `GameTableViewModelRuntimeService.tscn` now owns public track composition, Card Resolution Track summary data, RightInspector selection precedence, and final `TableSnapshot` normalization. Both services are static children of `GameRuntimeCoordinator` and are directly inspectable in Godot.

`main.gd` supplies domain facts only: real card definitions, prices from the existing price owner, play state from the existing legality owner, selected district/player facts, queue/target/animation facts, and existing actions/logs. It no longer preloads `TableSnapshot`, builds hand/track snapshots, selects the RightInspector payload, or owns parallel card color/icon/route/use-case/rules-copy/resolution-cinematic algorithms.

The existing `LegacyPlayerSurfaceRetirementBench` expands from 18 to 27 cases and from 96 to 164 retired functions. No duplicate Bench was introduced. Resolution-overlay badge and resolution-cinematic formatting are service-owned; `main.gd` supplies only public contract, requirement, bid, queue, target, and world-animation facts. The hard-cutover contract is recorded in `docs/card_presentation_viewmodel_runtime_contract.md`.

Sprint 42 production metrics after final validation:

- Before: 31,017 non-empty lines, 1,706 functions, 164 top-level variables, 277 constants; SHA-256 `BB89CABE7E7D04B2CDC5EC9E9E7AAF780DC8660C46FA669829C1EBCD901FEE5F`.
- After: 29,225 non-empty lines, 1,656 functions, 164 top-level variables, 276 constants; SHA-256 `036BA70993A66E1FBD1598330B5E0DC65FB5C1D2693DD383F47A64A437AF3FDE`.

The hard cutover removes 1,792 non-empty lines and 50 functions from the Sprint 41 baseline. The final deletion closure includes stale public-track and resolution-overlay badge/tooltip formatting plus thirteen resolution-cinematic target, stage, style, radius, and aftermath helpers. The live Overlay and world-animation adapter now consume ViewModels from the two scene-owned services.

Card price, play legality, target legality, queue, execution, effect, settlement, save, action-id, signal, and privacy semantics remain with their existing owners.

## Sprint 43: Card Play Eligibility and Targeting Hard Cutover

`CardPlayEligibilityRuntimeService.tscn` is now the single legality owner for card requirements, cash gates, target traits/readiness, response-window eligibility, city/contract/military requirements, and stable rejection precedence. `CardPlayEligibilityWorldBridge.tscn` collects pure world facts without deciding or mutating. Both are static children of `GameRuntimeCoordinator`.

UI/Coach, AI, Queue submission, and Execution revalidation consume the same eligibility envelope. `CardPresentationRuntimeService` maps its `reason_code` to player-facing labels and disabled reasons. Queue, Execution, effects, inventory, settlement, action ids, signals, save version, and privacy semantics remain unchanged.

The cutover deletes nineteen legacy legality/target functions and sixty call-graph-closed card, balance, and UI helpers that had no remaining producer after prior service migrations. No compatibility wrapper or fallback legality algorithm remains.

- Before: 29,225 non-empty lines, 1,656 functions, 164 top-level variables, 276 constants; SHA-256 `036BA70993A66E1FBD1598330B5E0DC65FB5C1D2693DD383F47A64A437AF3FDE`.
- After implementation: 28,518 non-empty lines, 1,583 functions, 164 top-level variables, 276 constants; SHA-256 `46EB1F21E1D8182D78D16AF4858EB3B90081DA2C9644B50F81594469A667CC99` before final documentation/tooling-only edits.

The production `main.gd` reduction is 707 non-empty lines and 73 functions. The authoritative 46-case gate is `CardPlayEligibilityRuntimeBench.tscn`; the ownership contract is `docs/card_play_eligibility_runtime_contract.md`.

## Sprint 44: Monster Runtime Characterization

`MonsterRuntimeCharacterizationBench.tscn` now instantiates the real
`main.tscn` and locks 37 observations covering catalog/actor shape, starter
summon, binding limits, same-family upgrade and rank-IV refresh, lifetime and
slot repair, action weights, target factors, shared RNG order, lure handling,
linear movement, flight/trample rules, range/armor/HP ordering, defeat and
owner-cash clues, wager open/freeze/timing/public-pool/refund behavior, current
save shape, legacy defaults, and public marker privacy.

The gate reports **37/37 observed** and **37/37 contract-aligned**. It records
`observed`, `contract_aligned`, and `needs_design_decision` independently, and
its manifest/report contain only pure data. Production `main.gd` is unchanged
at 28,518 non-empty lines, 1,583 functions, 164 top-level variables, and 276
constants with SHA-256
`46EB1F21E1D8182D78D16AF4858EB3B90081DA2C9644B50F81594469A667CC99`.

The ownership and deletion contract is
`docs/monster_runtime_ownership_contract.md`. Sprint 45 must migrate monster
state, summon/upgrade, lifecycle, target/shared-RNG, movement, combat, wager,
and save ownership as one hard cutover, then delete the mapped `main.gd`
families. Sprint 44 intentionally creates no Monster Runtime Service and no
parallel fallback.

## Sprint 45: Monster Runtime Hard Cutover

`MonsterRuntimeController.tscn` and `MonsterRuntimeWorldBridge.tscn` are now
static children of `GameRuntimeCoordinator.tscn`. The controller is the only
owner of monster roster/UID/selection state, action timers, summon and upgrade,
lifetime/revival, weighted targeting and shared-RNG consumption order, linear
movement, combat/passives/ownership clues, monster card commands, wager
lifecycle, and the legacy-compatible monster save envelope. The bridge owns no
monster formulas or state.

The original 37 real-main characterization cases remain intact. Thirteen
hard-cutover checks now verify scene composition, public APIs, state ownership,
main deletion, AI and card bridge routing, save ownership, pure public debug,
and the absence of a parallel engine. The combined gate passes **50/50**.

Production `main.gd` no longer declares monster runtime state or defines the
retired summon, lifecycle, targeting, movement, combat, card-command, wager,
or save algorithms. Relative to the Sprint 44 baseline it removes **2,445
non-empty lines** and **111 functions** before final documentation/tooling-only
edits. The runtime keeps the existing shared RNG object, action ids, signals,
temporary-decision flow, v1 save keys, and public/private boundaries.

## Sprint 46: Military Runtime Characterization

`MilitaryRuntimeCharacterizationBench.tscn` now instantiates the real
`main.tscn` and locks 37 observations over the seven real I-IV military
families, roster/UID shape, role control cap, deployment terrain, realtime
movement, duration, command cooldown, bound command inventory, guard, GDP
pressure, explicit district/route strikes, Monster Controller damage handoff,
save compatibility, public privacy, and Sprint 47 deletion candidates.

Sprint 46 creates no controller and changes no production military algorithm.
`main.gd` remains at 26,073 non-empty lines, 1,472 functions, 155 top-level
variables, and 242 constants with SHA-256
`22B6579F07EEA66A8905AD2EC075B68DE1C6D4AD2150A933D44C059164DB7C25`.

The characterization records `observed`, `contract_aligned`, and
`needs_design_decision` separately. Current runtime replaces the
shortest-remaining owned unit when deployment reaches the control cap, while
the requested rejection case expects atomic rejection; production is not
changed to force alignment. The full order and ownership boundary are recorded
in `docs/military_runtime_ownership_contract.md`.

Sprint 47 must migrate roster, UID, deployment/refresh, realtime lifecycle,
movement, commands, GDP/district/route intents, save state, and visibility as
one hard cutover, then delete the mapped `main.gd` owner without creating a
parallel military engine.

## Sprint 47: Military Runtime Hard Cutover

`MilitaryRuntimeController.tscn` and `MilitaryRuntimeWorldBridge.tscn` are now
static children of `GameRuntimeCoordinator.tscn`. The Controller is the sole
owner of military roster/UID, deployment and cap replacement, realtime
lifecycle, terrain-aware linear movement, bound command definitions and
execution, GDP pressure orchestration, public visibility, and the existing v1
save keys. The bridge owns no military state or decision rules.

The original 37 real-main behavior cases remain and 13 hard-cutover ownership
cases verify scene composition, Coordinator wiring, Inventory invalidation,
Monster damage handoff, AI binding, pure debug data, save ownership, and legacy
main deletion. The combined gate passes **50/50 observed and 50/50 aligned**.

Production `main.gd` changed from 26,073 to **25,380 non-empty lines**, from
1,472 to **1,436 functions**, from 155 to **154 top-level variables**, and from
242 to **238 constants**. Its SHA-256 is
`F75B217E85DA2E4F5300B900290457D41E4C031EC3C6B7CEFE996E6A354A103A`.
The old roster, UID, four timing constants, presentation metadata, deployment,
movement, lifecycle, command, GDP-pressure, balance-report, visibility, and
save algorithms are absent from `main.gd`; no parallel military fallback was
retained.

`AiRuntimeController` remains the military intent decision owner only.
`CardInventoryRuntimeService` invalidates bound command slots, and
`MonsterRuntimeController` remains the only monster HP/armor/down owner.

## Sprint 48: Weather Runtime Characterization

`WeatherRuntimeCharacterizationBench.tscn` now instantiates the real `main.tscn` and locks forty observations over the four production weather types, eight authored weather cards, public 60-180 second forecast, 75-135 second natural duration, one-to-five neighbor-first zones, destroyed-district exclusion, shared RNG order, card-authored forecast replacement, activation, overlapping multipliers, expiration, world refresh order, realtime/pause/wager timing, AI/Card Resolution routing, v1 save compatibility, privacy, and Sprint 49 deletion candidates.

Sprint 48 creates no `WeatherRuntimeController` and changes no production weather algorithm. `EnvironmentBalanceModel.weather_state_effect_model()` remains an Inspector/QA sampler rather than a runtime source. The rulebook's optional monster-movement and financial-risk weather effects are recorded as absent from the four current templates; no new behavior is invented.

The gate passes **40/40 observed** and **40/40 contract-aligned** with zero design decisions. Production `main.gd` remains exactly 25,380 non-empty lines, 1,436 functions, 154 top-level variables, and 238 constants with SHA-256 `F75B217E85DA2E4F5300B900290457D41E4C031EC3C6B7CEFE996E6A354A103A`.

Sprint 49 must migrate forecast/active/sequence state, timing and templates, shared-RNG scheduling, zone selection, activation/expiry, multiplier queries, weather-card rewrite, public-safe weather data, and save ownership as one hard cutover, then delete the mapped `main.gd` owner without retaining a fallback.
# Sprint 49: Weather Runtime Hard Cutover

- Added scene-owned `WeatherRuntimeController` and non-owning `WeatherRuntimeWorldBridge` under `GameRuntimeCoordinator`.
- Moved forecast, active zones, sequence, templates, shared-RNG selection, lifecycle, multipliers, weather-card rewrites, public snapshots, and v1 save data out of `main.gd`.
- Updated AI weather planning to read Controller templates and deterministic preview zones; AI remains decision-only.
- Deleted the legacy main weather engine in the same change: 341 nonblank lines, 21 functions, 6 top-level variables, and 6 constants from the Sprint 48 baseline.
- Expanded the existing Weather Runtime gate from 40 behavior observations to 53/53 behavior and ownership checks.
- `EnvironmentBalanceModel` remains QA-only; no parallel weather owner or fallback exists.

## Sprint 50: Contract Runtime Characterization

`ContractRuntimeCharacterizationBench.tscn` now instantiates the real
`main.tscn` and locks 47 observations over the five production contract
families, ranks I-IV, endpoint/product context, independent offer creation,
Card Resolution release/continuation, human and AI response routing,
accept/reject/timeout atomicity, Formula Service boundaries, multiple offers,
v1 save parity, public result clues, intel trace sanitization, and privacy.

The gate reports **47/47 observed** and **44/47 contract-aligned**. Three
mismatched records surface four v0.4 decisions: target city owner versus target product-project
controller authority, the missing self-sign permission gate, hidden contract
timer aging during a higher-priority counter, and card-resolution blocking
metadata on a response window that v0.4 defines as non-blocking. Production
rules are not changed to force alignment.

Sprint 50 creates no `ContractRuntimeController` and no parallel engine.
`main.gd` remains exactly 25,039 non-empty lines, 1,415 functions, 148 top-level
variables, and 232 constants with SHA-256
`214AEB804860D2DFFB8833EFF0BC0A4098B355178C07FB8E8BD1D80E6221777F`.

The ownership, observed order, privacy contract, and 37-function deletion map
are recorded in `docs/contract_runtime_ownership_contract.md`. Sprint 51 should
resolve the four decisions, then migrate pending offers, visible-time response
lifecycle, settlement orchestration, save data, and sanitized receipts in one
hard cutover while deleting the mapped `main.gd` owner.

## Sprint 51: Contract Runtime v0.4 Decision Lock and Hard Cutover

`ContractRuntimeController.tscn` and the non-owning
`ContractRuntimeWorldBridge.tscn` are now static children of
`GameRuntimeCoordinator.tscn`. The Controller is the sole owner of selected
endpoints, product context, target-project response authority, explicit
self-sign permission, pending offers, exact visible-time countdown, response
planning and exact-once commit, sanitized public/private snapshots, intel
receipts, and the existing v1 save keys. The bridge only collects pure world
facts and applies Controller-authored transactions.

The four v0.4 decisions are locked: the unique product-project controller is
the responder, ambiguous controllers reject atomically, self-sign requires the
card flag, only the exact visible offer consumes its five seconds, and contract
forced candidates do not block later card resolution. The combined gate passes
**47/47 behavior revalidation, 15/15 ownership cutover, and 62/62 total**.

Production `main.gd` changed from 25,039 to **24,323 non-empty lines**, from
1,415 to **1,379 functions**, from 148 to **145 top-level variables**, and from
232 to **228 constants**. Its SHA-256 is
`3191405C4F34A002A658AB179020E01BEBDE67B1148EF1DCE3AF9F70DBBDB201`.
All 37 mapped legacy contract functions, three state variables, and four
response constants are absent; no compatibility wrapper or parallel engine was
retained.

## Sprint 52 - Product Market & Futures Runtime Characterization

`ProductMarketRuntimeCharacterizationBench.tscn` now instantiates the real `main.tscn` and records fifty observations covering market generation, shared RNG order, tier-bounded prices, supply/demand/disrupted-route weights, temporary and contract pressure, price clamps and history, realtime market cadence, boon aging, speculation, product growth, route flow, futures creation/expiry, warehouse requirements, v1 save compatibility, privacy, cross-controller requests, and the Sprint 53 deletion map.

The gate reports 50/50 observed and 48/50 aligned. The two explicit v0.4 decisions are financial margin/max-gain/max-loss fields and warehouse-destruction loss settlement by card/remaining HP. Production `main.gd` remains byte-identical at SHA-256 `3191405C4F34A002A658AB179020E01BEBDE67B1148EF1DCE3AF9F70DBBDB201`; this sprint creates no ProductMarketRuntimeController and no parallel fallback.

The next hard cutover must migrate `product_market`, `business_cycle_count`, `market_timer`, generation/refresh, boon/futures lifecycle, shared RNG requests, and save ownership into one scene-owned Controller, then delete the mapped `main.gd` owner in the same change. Formula, Cashflow, GDP, AI, Weather, Monster, Military, Contract, Execution, and Product Codex boundaries remain independent.

## Sprint 53 - Product Market Runtime Hard Cutover

`ProductMarketRuntimeController.tscn` and `ProductMarketRuntimeWorldBridge.tscn` are static children of `GameRuntimeCoordinator.tscn`. The Controller is the sole owner of `product_market`, `business_cycle_count`, `market_timer`, the thirteen market constants, catalog generation/backfill, supply-demand-disruption refresh, boon and futures lifecycle, market cadence, sanitized snapshots, and v1 save compatibility. The bridge owns no state, formulas, or RNG; it reuses the existing world RNG and routes narrow world facts and mutations.

All twenty-three mapped market functions and three state declarations were deleted from `main.gd`. AI, Monster, Military, Weather, Contract, and card-effect dispatch now hold the same Controller reference. RuntimeBalanceModel remains the price formula owner, while `CardEconomyProductRouteFormulaRuntimeService` remains the deterministic boon/futures arithmetic owner.

The migrated Product Market gate passes **50/50** with the existing **48/50 v0.4 alignment** and two explicit futures design decisions unchanged. Production `main.gd` moved from 24,323 to **23,659 nonblank lines**, from 1,379 to **1,377 functions**, from 145 to **142 top-level variables**, and from 228 to **215 constants**. Its SHA-256 is `58D1C52957A80ADC022AA9F3B1DB34B7F8841EA1F138C011E4E9D0352D942006`.

## Sprint 54 - Product Futures v0.4 Terms Characterization

The existing Product Market Bench expands from 50 to **74 cases** without adding a second Bench or runtime owner. The original market gate remains **50/50 observed**, while twenty-four new cases characterize the twelve real long, short, and warehouse cards, distinguish purchase price from the currently zero action fee, and record locked reference/duration/direction/multiplier, payout, expiry, save/privacy, and warehouse-destruction behavior.

This is a production-frozen rules/content pass. `main.gd` remains **23,659 nonblank lines / 1,377 functions / 142 top-level variables / 215 constants** at SHA-256 `58D1C52957A80ADC022AA9F3B1DB34B7F8841EA1F138C011E4E9D0352D942006`. `ProductMarketRuntimeController` also remains unchanged. Margin, gain/loss caps, adverse settlement, and warehouse HP settlement are documented decisions for Sprint 55 rather than guessed runtime values.

## Sprint 55 - Product Futures v0.4 Authored Terms Hard Alignment

Twelve Inspector-editable `.tres` assets and one catalog now provide the only financial terms source. Queue preflights fee + bid + margin without locking funds; `ProductMarketRuntimeController` rechecks and locks margin at effect open, stores the complete terms/version, and settles capped gain/loss exactly once. Warehouse destruction now uses max/pre/post HP and proportional maximum loss, while partial damage remains a public risk signal only.

AI risk scoring and Card Presentation consume the same pure terms snapshot. Old saves normalize once with zero retroactive margin/loss. The positive-only payout formula, clear-only warehouse path, copied card-definition finance fields, and six main.gd futures balance-report functions are absent. The existing Product Market Bench now reports **100/100**, with **76/76 live aligned**, **24/24 historical integrity**, and zero design decisions.
# Sprint 56 - City GDP Derivative v0.4 Terms Alignment

- Added `CityGdpDerivativeRuntimeController` and `CityGdpDerivativeRuntimeWorldBridge` as static `GameRuntimeCoordinator` services.
- Authored twelve Inspector-editable city long, city short, and disaster-insurance terms Resources under `resources/finance/city_gdp_derivatives/`.
- Queue now authorizes authored margin while effect open performs the atomic margin lock and position creation.
- Expiry and city destruction use two-way capped P&L, margin refund, and exact-once removal through the Formula Service.
- Current saves use `city_gdp_derivative_runtime`; old city-embedded positions normalize once without retroactive margin.
- Removed all `gdp_bet_*` card fields and the old main-owned open, payout, timer, expiry, and destruction engine.
- Added `CityGdpDerivativeRuntimeBench` as a 40/40 terms, funding, settlement, save, privacy, and deletion gate.

## Sprint 57 - Runtime Card Catalog Characterization and Schema Lock

`RuntimeCardCatalogCharacterizationBench.tscn` instantiates the real
`main.tscn` and locks the current gameplay catalog before any Resource cutover.
The forty-case gate records **239 explicit card definitions**, **120 ordered
families**, **76 upgradeable families**, **125 ordered unique common-pool
entries**, **49 effect kinds**, fourteen consumers, external Product Futures
and City GDP terms, save-name compatibility, and the public/private boundary.
It reports **40/40 observed** and **40/40 aligned**.

This is intentionally a production-frozen characterization sprint.
This was the pre-cutover baseline. Sprint 58 consumed it as a locked integrity
fixture; it is no longer the runtime ownership state.

## Sprint 58 - Runtime Card Catalog Resource Hard Cutover

`CardRuntimeCatalogService.tscn` now owns the Inspector-authored v0.4 catalog.
The Resource graph contains 120 family files, 239 embedded authored ranks, ten
ordered packs, and one root catalog. `CardRuntimeDefinitionWorldBridge.tscn`
composes city-development cards, exact catalog definitions, external Product
Futures/City GDP terms, Monster-owned dynamic definitions, and catalog-derived
ranks in the locked precedence order.

All 239 authored Dictionaries match the Sprint 57 canonical hashes. Catalog,
upgradeable-family, and public-pool orders retain their locked hashes; missing
ranks retain nearest-lower lookup and the 35% growth policy. AI receives the
DefinitionWorldBridge directly, Military receives the Catalog Service directly,
and normal runtime callers use `GameRuntimeCoordinator` card APIs.

The old `SKILL_CATALOG`, `UPGRADEABLE_SKILL_FAMILIES`, `COMMON_CARD_POOL`, and
five catalog lookup/derivation helpers were deleted from `main.gd` in the same
change. There is no Resource/Dictionary dual source and no silent fallback.
`RuntimeCardCatalogResourceBench` replaces the Sprint 57 bench and gates forty
historical-integrity plus forty live-cutover cases (80/80).

## Sprint 59 - Runtime Card Authoring Workflow

Runtime card content can now be created and modified through real Godot
Resources with a custom Inspector panel. `RuntimeCardAuthoringWorkspace.tscn`
provides pack/family/rank navigation, selected Resource paths, validation, a
working-baseline action, and a deterministic change-review action.

`CardRuntimeAuthoringValidator` enforces identity, rank order, kind schemas,
authored shape, external-term boundaries, pure data, catalog order, pool, and
upgrade membership. `CardRuntimeChangeReviewService` compares canonical card
hashes against the Sprint 58 integrity fixture and adds field-level diffs when
a user-scoped working baseline exists. All generated artifacts live under
`user://space_syndicate_design_qa/runtime_card_authoring/`.

`RuntimeCardAuthoringWorkflowBench` passes 36/36. This sprint changes no
runtime owner and adds nothing to `main.gd` or `GameRuntimeCoordinator`;
`CardRuntimeCatalogService` remains the single authoritative runtime source.

## Sprint 60 - First Playable Core Card Set

The existing Inspector-authored catalog now supplies the first-table core set
without adding a parallel card database. `first_table.json` stores only real
runtime IDs, while the authored runtime service resolves the local-product
city-development card, follow-up sequence, starter monsters, and featured
families from the authoritative catalog. The expanded real-main mission gate
covered 27 card-content and playability cases before pacing instrumentation.

## Sprint 61 - First Playable Balance and Pacing

`first_table.json` now authors a single 15-30 minute pacing profile with a
20-minute target. Milestone targets are four minutes for the first development
card, eight for first positive income, twelve for the second card, sixteen for
the first public clue, eighteen for first monster pressure, and twenty for the
mission summary. Warning ceilings remain data, not new gameplay timers.

`ScenarioRuntimeController` records accepted scenario-signal timestamps using
the existing scenario game clock. `FirstTableAuthoredRuntimeService` owns the
pure-data pacing evaluator and supply plan. The real-main bench reports both
automated observations and the authored human window; automated duration is
not treated as human playtest evidence.

The pre-change real-main baseline reproduced a 26/27 failure: a valid local
product development card could be filtered out when its product was outside
the scenario's preferred-product list. Preferred products now guide the
recommendation only. Every real local-product development card remains in the
resolved runtime catalog, and the authored follow-up card is inserted into the
project district's real supply when city development resolves. The Coach no
longer needs to create that second card at purchase time.

This sprint changes no GDP, monster, purchase, card-resolution, 30/25/5 window,
action ID, signal, save, or privacy rule. `main.gd` remains a world adapter for
the scene-owned telemetry, pacing, and supply-plan services.
# Sprint 62: Gameplay Balance Diagnostics Hard Cutover

- Added scene-owned `GameplayBalanceDiagnosticsRuntimeService` and a read-only
  `GameplayBalanceDiagnosticsWorldBridge` under `GameRuntimeCoordinator`.
- Moved seven development-route profiles to Inspector-editable `.tres`
  Resources under `resources/balance/development_routes/`.
- Migrated card budgets, route and pressure audits, role/direct-interaction
  reports, monster/product ecology, supply audits, one-glance checks, resolution
  coverage, and Developer Balance snapshots out of `main.gd`.
- Updated AI, DeveloperBalancePanel, Card Codex, Product Codex, Bestiary, and
  reflection tests to consume the Service/Coordinator API.
- Deleted the corresponding `main.gd` report and metadata implementation; no
  compatibility wrapper or parallel fallback remains.
- `RuntimeBalanceModel` remains the formula owner. The new service is read-only
  and its snapshots are pure data.
- Extended the existing `BalanceRuntimeBridgeBench` instead of adding a second
  balance bench. Sprint output lives under
  `user://space_syndicate_design_qa/gameplay_balance_diagnostics/`.

## Sprint 63: City / Trade Network Runtime Characterization

Sprint 63 adds `CityTradeNetworkRuntimeCharacterizationBench.tscn` and a 48-case real-main contract without changing production `main.gd`. The gate records product-project identity and shares, competition, supply discovery, shortest paths, route cost/disruption/flow, GDP fact assembly, refresh order, project-share and legacy-owner payout routing, save compatibility, and public/private boundaries.

The observed order is competition -> trade routes -> GDP formula delegation -> project GDP/share allocation -> city-development supply guarantee. Product-market refresh remains a separate request. `CityProductProjectState/Bridge`, `GdpFormulaRuntimeController`, `EconomyCashflowRuntimeController`, and `ProductMarketRuntimeController` retain their existing narrow ownership.

Recommended Sprint 64: create one `CityTradeNetworkRuntimeController` plus a non-owning `CityTradeNetworkWorldBridge`, migrate the project sequence, derived route graph, refresh orchestration, payout-source composition, and city-network save data together, then delete the mapped `main.gd` implementation in the same change. Do not absorb GDP formulas, cashflow cadence, market prices, contracts, military, weather, monsters, or AI.

## Sprint 64: City / Trade Network Runtime Hard Cutover

Sprint 64 installs `CityTradeNetworkRuntimeController.tscn` and the non-owning `CityTradeNetworkWorldBridge.tscn` as static children of `GameRuntimeCoordinator`. The Controller is now the single owner of the project sequence, project snapshot orchestration, active-city/competition derivation, supply discovery, shortest paths, route cost/disruption/flow, refresh order, payout-source composition, city cashflow remainder state, and city-network save/load normalization.

`main.gd` now keeps only narrow world-facing adapters and no longer contains the route/path engine, competition/route rebuild algorithms, network refresh implementation, payout-source assembly, project sequence state, or a fallback city-network owner. GDP arithmetic remains in `GdpFormulaRuntimeController`, cashflow cadence and payout arithmetic remain in `EconomyCashflowRuntimeController`, project-share arithmetic remains in `CityProductProjectState` / `CityProductProjectBridge`, and market prices remain in `ProductMarketRuntimeController`.

The existing `CityTradeNetworkRuntimeCharacterizationBench` is retained as the long-lived ownership gate and expanded from 48 historical cases to 68 total cases. Sprint 64 passes 68/68 observed and 68/68 aligned with zero design decisions. Relative to the Sprint 63 production baseline, final `main.gd` removes 439 nonblank lines, 13 functions, and one top-level variable. The final compatibility pass also updates First Table's public-AI evidence to recognize v0.4 project shares and real resolved anonymous AI cards without exposing owner identity.

## Sprint 65: City Development & Product Project Settlement Characterization

`CityDevelopmentSettlementRuntimeCharacterizationBench.tscn` now instantiates real `main.tscn`, discovers real rank-I production, demand, and commerce development cards from `CoreCityDevelopmentPack`, and records forty observations over v0.4 legality, atomic rejection, city-shell creation, project contribution/share behavior, commerce transport mutation, refresh order, lifecycle evidence, events, save compatibility, and privacy.

The gate reports **40/40 observed**, **39/40 aligned**, and one explicit design decision. The current implementation writes the city/project mutation before downstream network, market, and GDP refresh and has no explicit rollback envelope. Sprint 66 must introduce pure plan plus atomic commit when extending the existing `CityDevelopmentRuntimeController`; it must not create a parallel city engine. The detailed order and deletion map are recorded in `docs/city_development_settlement_runtime_contract.md`.

This is a characterization-only sprint. Production `main.gd` remains exactly 20,494 nonblank lines, 1,296 functions, 141 top-level variables, and 211 constants at SHA-256 `B8174D78AA08BE2883E7EA5C7A5568CB8C5ED902D1945BCE0EAE8F7D3AD3CC67`.

## Sprint 66: City Development Settlement Runtime Hard Cutover

`CityDevelopmentRuntimeController` now owns v0.4 legality, stable rejection codes, pure settlement planning, city/project/commerce staging, validation precedence, and project lifecycle. The non-owning `CityDevelopmentWorldBridge` captures pure facts, performs fingerprint and sequence preflight, atomically commits owned deltas, calls Network -> Market -> GDP -> project allocation in order, rolls back world/downstream/RNG state on failure, and applies event intents exactly once.

Both nodes are static children of `GameRuntimeCoordinator`. Player card resolution and the authored First Table AI route call `execute_city_development()`; test fixtures use the same real authored-card transaction through `CityWorldFixtureFactory`. `main.gd` no longer contains the settlement body, city-shell creation, target/normalization formulas, direct creation helper, duplicate product/demand builders, or lifecycle forwarding implementation. Direct-build action IDs remain rejection-only v0.4 compatibility surfaces.

The existing real-main gate is expanded to **64/64 observed**, **64/64 aligned**, and zero design decisions. Public receipts omit player, owner/controller, contribution, and share data. `CityProductProjectState/Bridge`, CityTradeNetwork, ProductMarket, and GDP Formula retain their independent ownership; no parallel city engine or fallback exists.

## Sprint 66.5: Repository Safety And Test Isolation

The legacy smoke script defined a QA save path but wrote it into a retired
`main.gd` property. Its no-argument save/load calls and startup menu queries
therefore still resolved to the player's real
`user://space_syndicate_current_run.save`. `GameSaveRuntimeCoordinator` now
accepts a bounded pre-configuration override only below
`user://space_syndicate_design_qa/test_runs/`; production still defaults to the
same v1 player path, and attempts to use that player path as a QA override are
rejected.

The smoke script installs the override before Main enters the tree. The existing
Game Session & Save Ownership gate is expanded from 20 to 24 cases to prove the
production default, accepted QA root, rejected player path, isolated real Main,
and source-level smoke contract. No gameplay state, save payload, action ID, or
domain algorithm changes in this safety sprint.

`tools/repository_safety_baseline.ps1` creates a read-only Git/file hash,
`main.gd`, player-save metadata, and third-party release-blocker manifest under
Godot user data. It does not stage, commit, reset, delete, or move workspace
files. The clean-clone gate remains blocked until the large dirty workspace has
an intentional source-control snapshot. Night Patrol is explicitly recorded as
a CC BY-NC prototype-only runtime dependency pending commercial replacement.

## Sprint 67: Global UI Navigation Characterization

Sprint 67 extends the existing `MenuShellRuntimeCutoverBench` instead of adding a third navigation bench. The original menu ownership gate remains 24/24 and `CodexNavigationRuntimeCutoverBench` remains 20/20. A separate pure-data manifest records 32/32 real-main global navigation observations and 19/32 target-contract alignments.

The current Esc route only owns fullscreen-map close, generic MenuOverlay close, and pause open. It does not own confirmation or forced-decision precedence, side/district drawer dismissal, root exit confirmation, exact parent focus, freed-focus fallback, or controller `ui_cancel`. Scenario action log/replay generic Back also returns to the root menu rather than the pause opener.

`scripts/tools/global_ui_navigation_characterization_registry.gd` records the surface schema, current/expected action pairs, and Sprint 68 deletion candidates. `docs/global_ui_navigation_runtime_contract.md` is the hard-cutover contract. Production `main.gd` is intentionally unchanged at 20,209 nonblank lines, 1,285 functions, 141 top-level variables, 204 constants, and SHA-256 `6BD3F293EC2E92AEB81A39C80266314BE6A308D2C03ECD58FD8DB22958CAE699`.

## SS05-02: Five Project Slots And Stable Identity

SS05-02 reuses the existing scene-owned `CityTradeNetworkRuntimeController` instead of creating a parallel project engine. It now uniquely owns five canonical project slots per buildable region (production 2, demand 2, commerce 1), stable ASCII region/slot/project IDs, rank I-IV, project shares, monotonic generations, tombstones, and the domain save envelope. `CityProductProjectState` and `CityProductProjectBridge` remain pure-data helpers; `CityDevelopmentRuntimeController` consumes the same slot transaction.

The legacy product-derived project ID, exact-tie seat/order tiebreak, owner-derived synthetic project, owner-only no-project payout, duplicate flat save writer, and runtime `migrate_legacy_city`/`apply_development` paths are absent. A one-time `CityProjectStateMigrationV04ToV05` boundary may normalize explicit old projects, but it never invents projects from `city.owner`, products, or demands.

The long-lived City/Trade gate expands from 68 to **88/88 observed and aligned**, while City Development remains **64/64**. `main.gd` is byte-identical to its SS05-01A baseline because this cutover replaces already-module-owned project semantics rather than moving a new `main.gd` block. SS05-03 should next replace whole-city GDP splitting with structured, project-keyed GDP rows and conservation receipts.

## SS05-03: Structured Project GDP Hard Cutover

`GdpFormulaRuntimeController` now references the Inspector-editable v0.5 GDP Profile and the unique product-industry catalog. It emits deterministic public receipt rows keyed by stable region/project/slot/generation identity for production, demand, and commerce GDP. Unassigned legacy bonuses are explicit neutral rows; unknown products or missing project identities fail closed. The v0.4 Profile remains historical evidence and is not an active fallback.

`CityTradeNetworkRuntimeController` composes project facts and owns the refresh order: competition -> routes -> structured GDP rows -> project/player/neutral attribution -> supply guarantee. `CityProductProjectState` performs the pure per-project share transform, floors each player allocation, and records the neutral remainder. `EconomyCashflowRuntimeController` receives only `project_share` sources keyed by receipt plus player. The active path no longer contains whole-city `assign_city_gdp`, player aggregate GDP maps, owner-only payout, same-owner competition exemption, or the minimum-40 floor.

The existing GDP gate is expanded to **40/40** and the long-lived City/Trade gate to **108/108 observed and aligned**, while City Development remains **64/64**. Public snapshots expose aggregate economic evidence but not controllers, contribution/share tables, hidden owners, private targets, or AI plans. The detailed row schema and conservation identities are frozen in `docs/structured_project_gdp_v05_contract.md`.
