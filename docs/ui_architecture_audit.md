# UI Architecture Audit

This note records the current UI architecture state for the Space Syndicate prototype. It is intentionally product-facing and implementation-facing: future Codex work should use it to avoid sliding back into a giant `main.gd` UI generator.

## Current authoritative scene tree

- `project.godot` still launches `res://scenes/main.tscn`.
- `scenes/main.tscn` is a full-rect `Control` shell with `res://scripts/main.gd` attached.
- Runtime gameplay now mounts `scenes/ui/GameScreen.tscn` as the visible product-layer table from `scripts/main.gd`.
- The older generated table is not built in the default runtime path. `LegacyRuntimeTable` stays in-tree as an empty, disabled rollback shell; `BUILD_LEGACY_RUNTIME_TABLE` can be flipped locally if the split table needs emergency comparison.
- Greybox/editor-visible UI scenes now exist under `scenes/ui/` and at the root scene level:
  - `scenes/ui/GameScreen.tscn`
  - `scenes/ui/TopBar.tscn`
  - `scenes/ui/PublicTrack.tscn`
  - `scenes/ui/CardTrack.tscn` (implementation scene for the public track rail)
  - `scenes/ui/PlanetBoard.tscn`
  - `scenes/ui/RightInspector.tscn`
  - `scenes/ui/PlayerBoard.tscn`
  - `scenes/ui/HandRack.tscn`
  - `scenes/ui/CardFace.tscn`
  - `scenes/ui/OverlayLayer.tscn`
  - `scenes/ui/CardResolutionBanner.tscn`
  - `scenes/ui/BottomCountdownBar.tscn`
  - `scenes/ui/DistrictSupplyDrawer.tscn`
  - `scenes/ui/DistrictSupplyMarketCard.tscn`
  - `scenes/ui/DistrictSupplyPreviewCard.tscn`
  - `scenes/ui/FullscreenMapOverlay.tscn`
  - `scenes/ui/MenuOverlay.tscn`
  - `scenes/ui/TutorialQuickStartBoard.tscn`
  - `scenes/ui/RulesQuickReferenceBoard.tscn`
  - `scenes/ui/RoleCodexIdentityBoard.tscn`
  - `scenes/ui/CompendiumHubBoard.tscn`
  - `scenes/ui/CardCodexBrowser.tscn`
  - `scenes/ui/CardCodexDetail.tscn`
  - `scenes/ui/RegionCodexDetail.tscn`
  - `scenes/ui/ProductCodexDetail.tscn`
  - `scenes/ui/BestiaryDetail.tscn`
  - `scenes/ui/EconomyDashboard.tscn`
  - `scenes/ui/IntelDossierBoard.tscn`
  - `scenes/ui/StandingsScoreboard.tscn`
  - `scenes/ui/FinalSettlementBoard.tscn`
  - `scenes/ui/MenuRootLobby.tscn`
  - `scenes/ui/NewGameSetupLobby.tscn`
  - `scenes/ui/NewGameSetupOptionBoard.tscn`
  - `scenes/ui/NewGameSetupSeatCard.tscn`
  - `scenes/ui/NewGameSetupSeatIdentityBoard.tscn`
  - `scenes/GameScreen.tscn`
  - `scenes/CardUI.tscn`
  - `scenes/LayoutDemo.tscn`

## Wrong architecture still present

The main remaining product/UI debt is not Node2D-based UI. The debt is that `main.gd` still owns too much UI construction:

- Several non-table surfaces such as Codex page internals, menu subpage internals, and fullscreen map dynamic wiring are still created through script code behind the split table.
- Those runtime transient surfaces are now hosted under `GameScreen/OverlayLayer`, but most of their internal controls still need to become editor-visible `scenes/ui/` components.
- Human designers cannot yet adjust the live main table primarily through Godot Editor scenes.
- The visible main runtime table now starts at `scenes/ui/GameScreen.tscn`, but the migration is still incomplete because several controls are bridged back into `main.gd`.
- The old generated main table remains as source-level fallback code, but it no longer competes for default first-screen attention.
- Scene-owned player pages should not call `main.gd` fallback renderers. The old tutorial, rules-summary, compendium-hub, standings-scoreboard, economy-dashboard, final-settlement, intel-dossier, and role-identity page generators have been physically deleted from `scripts/main.gd`; their data-source helpers remain only where the scene-owned snapshot path still needs source data.

## Architecture fixed in this pass

- Periodic full refresh no longer forces the visible bottom player board to destroy/recreate every refresh tick. The default split runtime reports `_uses_split_runtime_table() == true`, so `_refresh_ui()` skips the legacy `_refresh_player_panel(false)` path entirely; the signature-gated legacy refresh remains only for fallback comparison.
- `RightInspector` is now a first-class editor-visible UI component, so the right side has a single "why / detail / action" destination.
- `HandRack` is a custom `Control` responsible for child-card layout and hover lift.
- `HandRack` now owns hand-card rendering stability as well as layout. `PlayerBoard` delegates `hand_cards` snapshots to `HandRack.set_cards()`; the rack reuses same-identity `CardFace` nodes and only updates their data, so live resource refreshes do not interrupt hover, drag preview, or card focus.
- `HandLayout` now ports the permissive open-source card-table skeleton into Godot terms: a CardHouse-style position/rotation/scale seeker plus Balatro Feel-style hover lift and neighbor spacing. It stores card motion targets on UI controls, exposes `get_card_target_snapshot()` for tests, and stays entirely in the UI/animation layer without touching rules.
- `HandRack` now also ports the CardHouse drag-detector boundary as a UI-only preview chain: `HandRack` detects drag intent, `PlayerBoard` forwards card data, `GameScreen` tells `OverlayLayer` to show a clamped `DragPreviewPanel`, and no gameplay move is invoked.
- `CardFace/CardUI` are editor-visible card components instead of anonymous labels/buttons.
- ViewModel snapshot scripts now exist under `scripts/viewmodels/` to define the bridge between domain state and UI scenes.
- Layout tests instantiate key UI scenes at 1280x720, 1366x768, 1600x960, 1920x1080, and 2560x1440.

## Product layer contract added in the split UI

The editor-visible `scenes/ui/GameScreen.tscn` now carries the product information layers described in the continuation brief:

- `TopBar` owns realtime table-state and clock labels plus a `FirstGlanceRail` with identity, cash, GDP, goal, selected-district, and next-action chips. Player-facing text should read as `桌态 / 计时`, not turn-cycle `阶段 / 回合 / 席位` language.
- `TopBar` also owns the first-screen menu entry. Its `MenuButton` emits through `GameScreen.action_requested("menu")` and `scripts/main.gd` opens the existing pause/menu overlay.
- Optional end-turn/top-bar resolution controls stay hidden by default; the always-visible primary command remains in `PlayerBoard`, preserving the "one main action dock" rule.
- `PublicTrack` owns the thin anonymous/public card rail. `PublicTrackSnapshot` normalizes raw track entries into slot, state, price/cost, accent, and anonymous ownership hints, while `CardTrack` renders only compact `PublicTrackSlot` cells with state pips. Complete card faces stay out of the always-visible main table.
- `PlanetBoard` owns the square planet stage. It keeps `MapHost` uncut inside `PlanetStageViewport`, uses left/right space rails to absorb spare horizontal width, renders those rails from snapshot-backed `地表情报` and `外围压力` entries instead of static filler labels, draws starfield/orbit-lane/edge-tick context behind the board, and lets `MapView` keep visible outer space outside the flat projection edge instead of filling the whole surface with table felt. Runtime layout tests enforce that `MapHost` remains square and the rails stay data-driven.
- `RightInspector` owns the 10-second table-side detail layer with `InspectorReasonPanel`, requirement chips, action buttons, public log, and deeper Codex/detail links. Its empty state should read as `桌边详情 / 看用途、条件和下一步`, not as a rule manual or debug explanation panel.
- `RightInspectorSnapshot` separates `summary/detail` from `full_detail`. The always-visible inspector and `DistrictInfoPanel` render the short summary; `OverlayLayerSnapshot` builds sectioned 30-second side-drawer data from the current RightInspector snapshot. Do not put long card, region, economy, contract, or monster prose directly into the always-visible inspector.
- `PlayerBoard` owns the bottom table layer as a three-tableau player board: `PlayerResourceTableau` on the left for identity/cash/GDP/goal/selected district/next step, `PlayerHandTableau` in the center for hand count, short table/readiness chips, and the custom `HandRack`, and `PlayerCommandTableau` on the right for the single compact `PlayerMainActionDock`. Bottom hand cards are MiniCards by default (`mini_hand` plus `right_inspector` detail policy): the rack may show cost/name/type/rank/one-line use/status, while full rules belong in `RightInspector`, drawer, or Codex. Quick actions and current primary actions render through the same `ActionDock` component, and runtime layout tests keep the hand rack wider than the action dock.
- `OverlayLayer` owns non-constant surfaces through explicit child layers: `TooltipLayer`, `SideDrawerLayer`, `ModalLayer`, and `DragPreviewLayer`. The concrete panels (`TooltipPanel`, `SideDrawerPanel`, `ConfirmPanel`, `DragPreviewPanel`) live under those layers, so transient UI has a stable z-order and ownership boundary. `SideDrawerPanel` contains `SideDrawerBodyScroll` and `SideDrawerSectionList`; `OverlayLayerSnapshot.sections` renders 30-second detail as readable cards (`对象 / 原因 / 桌面摘要 / 完整详情 / 最近公开日志`) before the drawer offers Codex follow-up actions. `GameScreen` only routes the open request and forwards drawer actions to the runtime Codex/menu bridge.
- `TopBarSnapshot`, `PublicTrackSnapshot`, `RightInspectorSnapshot`, `ActionDockSnapshot`, `OverlayLayerSnapshot`, and `PlayerBoardSnapshot` now carry the 3-second, 10-second, and 30-second product layers: identity, cash/GDP/goal text, selected district, anonymous public-track slots, goal progress, current why/requirements, normalized Build/Rack/Buy/Play quick actions, primary actions, detail drawer copy, links, logs, and hand cards.
- `ActionDockSnapshot` normalizes action ids, labels, disabled state, and short player-facing status text before `ActionDock` renders buttons. `PlayerBoardSnapshot` and `RightInspectorSnapshot` route their action arrays through it, so UI button components do not need to interpret raw controller action states.
- `PlanetBoardSnapshot` now carries the central planet board's data-only product layer: title/hint plus snapshot-backed `地表情报` and `外围压力` rails. `TableSnapshot` routes `planet` through this ViewModel instead of passing `main.gd` dictionaries straight into the scene renderer.
- `PlayerBoardSnapshot` also carries table-state lamps and action-readiness chips. `PlayerBoard.tscn` renders them through `PlayerStatusLampRow` and `PlayerReadinessChipRow`, preserving the old dynamic board's "table / seat / queue / rack" scan value without rebuilding controls in `main.gd`.
- `PlayerBoard` signature-gates identical hand-card identities, quick actions, table-state lamps, readiness chips, and primary action buttons, and `HandRack` exposes its active hovered card so tests verify live value refreshes preserve the hovered hand-card lift instead of destroying the rack. Same-id hand-card data updates must reuse the existing `CardFace` node and refresh its displayed data.
- `RightInspector`, `ActionDock`, and `DistrictInfoPanel` signature-gate identical requirement chips, deep links, current-action buttons, and district chips, so the 10-second explanation layer also stays stable during live value refreshes. `DistrictInfoPanel` can expose the full text as tooltip context, but its visible label stays summary-length.
- `RightInspector` keeps the public log as a short recent summary. Long rule text, replay text, and development/debug text should remain in Drawer, Codex, or backstage reports.
- Layout tests now enforce the code-layer boundary: ViewModel scripts cannot create UI nodes or bind UI signals, split UI scripts cannot call gameplay rule functions or read domain collections directly, and runtime snapshots must stay data-only without `Callable` rule handles.
- `TableSnapshot` is the split-scene bridge. It derives top-bar state from player-board state when explicit top-bar data is absent, and it normalizes right-inspector data before `scenes/ui/GameScreen.tscn` renders.
- `scripts/main.gd` exposes a read-only `_runtime_table_snapshot()` adapter. It translates the live prototype state into data-only `TableSnapshot` output without leaking UI nodes or action `Callable`s, and `_sync_runtime_game_screen()` passes that normalized UI dictionary into the split `GameScreen`.
- `scripts/main.gd` now creates `RuntimeGameScreen`, attaches the interactive `MapView` into `PlanetBoard/MapHost`, syncs runtime snapshots into the split scene, and forwards split action signals back to the existing gameplay controller.
- `GameScreen` exposes `get_overlay_host()`, and `scripts/main.gd` mounts the menu modal, fullscreen map, card-resolution banner, bottom countdown, and district supply drawer under the split `OverlayLayer` instead of scattering them as root-level runtime controls.
- Runtime RightInspector deep links now open the split `OverlayLayer` side drawer first (`detail_region`, `detail_cards`, `detail_intel`) instead of jumping straight to Codex; the drawer renders section cards plus Codex follow-up actions as buttons and emits `side_drawer_action_requested`, and `tests/ui_snapshot_capture.gd` records `play_table_drawer_*` screenshots so the 30-second layer is visually verified.
- Runtime hand-card selection follows the same product ladder: selected hand cards expose `detail_cards` / `detail_region` in `RightInspector`, so full card/region context opens the drawer first and only the drawer's follow-up buttons jump into Codex.
- The card-resolution reveal banner is now `scenes/ui/CardResolutionBanner.tscn`; `main.gd` instantiates it and updates existing label/art references while the banner's node structure is editor-visible.
- The bottom countdown sandglass is now `scenes/ui/BottomCountdownBar.tscn` plus `scripts/ui/bottom_countdown_bar.gd`; `main.gd` only instantiates it and passes timer state.
- The district supply market drawer shell is now `scenes/ui/DistrictSupplyDrawer.tscn`; `main.gd` instantiates the right-side 30-second layer and caches its fixed containers.
- The district supply market cell is now `scenes/ui/DistrictSupplyMarketCard.tscn` plus `scripts/ui/district_supply_market_card.gd`; `main.gd` passes a data snapshot into `set_card()` and listens to hover/preview/activate signals.
- The district supply selected-card preview is now `scenes/ui/DistrictSupplyPreviewCard.tscn` plus `scripts/ui/district_supply_preview_card.gd`; `main.gd` passes title/chip/verdict/card-face snapshots into `set_preview()`, listens for `buy_requested`, and the component renders the selected `CardFace` scene internally.
- The fullscreen map shell is now `scenes/ui/FullscreenMapOverlay.tscn`; `main.gd` instantiates it, inserts the existing `MapView`, connects the close button, and refreshes the compact layer/product/district HUD labels.
- The menu/Codex modal shell is now `scenes/ui/MenuOverlay.tscn` plus `scripts/ui/menu_overlay.gd`; the shell owns title/context/hint/body reset, global/catalog navigation visibility, responsive sizing, and button-to-signal dispatch. `main.gd` delegates `present_menu_shell()`, `hide_global_navigation()`, and shell navigation signals while still filling most menu subpages, Codex, rule, economy, standings, and intel page internals through existing runtime functions.
- The tutorial quick-start board is now `scenes/ui/TutorialQuickStartBoard.tscn` plus `scripts/ui/tutorial_quick_start_board.gd`; `main.gd` only prepares first-run step, common-trap, and chip snapshots while the component renders the 3-minute onboarding task board.
- The rules quick-reference board is now `scenes/ui/RulesQuickReferenceBoard.tscn` plus `scripts/ui/rules_quick_reference_board.gd`; `main.gd` only prepares objective, privacy, card-keyword legend, module, and footer snapshots while the component renders the 3-minute rules scan board before the full rules text.
- The Role Codex public identity board is now `scenes/ui/RoleCodexIdentityBoard.tscn` plus `scripts/ui/role_codex_identity_board.gd`; `main.gd` prepares role face, public chip, KPI, route, privacy, and opening-hint snapshots while the component renders the public identity board and embedded `CardFace` scene.
- The Compendium hub is now `scenes/ui/CompendiumHubBoard.tscn` plus `scripts/ui/compendium_hub_board.gd`; `main.gd` prepares the catalogue branch cards and receives branch action ids while the component renders the 3-minute Codex entry board.
- The Card Codex thumbnail browser is now `scenes/ui/CardCodexBrowser.tscn` plus `scripts/ui/card_codex_browser.gd`; `CardCodexBrowserSnapshot` normalizes filter/page/card/preview data while `main.gd` only supplies source card/filter context and receives filter, page, preview, and detail signals.
- The Card Codex detail page is now `scenes/ui/CardCodexDetail.tscn` plus `scripts/ui/card_codex_detail.gd`; `CardCodexDetailSnapshot` normalizes the public card-face, scan order, tactical-use, fact, upgrade, and resolution data while `main.gd` only supplies source card/rule context and the component renders the TCG-style detail page plus embedded `CardFace` scene.
- The Region Codex detail page is now `scenes/ui/RegionCodexDetail.tscn` plus `scripts/ui/region_codex_detail.gd`; `main.gd` prepares public tile, HP/heat/route/rack, KPI, and clue snapshots while the component renders the board-game region tile without reading map state directly.
- The Product Codex detail page is now `scenes/ui/ProductCodexDetail.tscn` plus `scripts/ui/product_codex_detail.gd`; `main.gd` prepares product profile, market price, supply/demand, KPI, strategy, futures/warehouse, monster-focus, map-entry, and clue snapshots while the component renders the commodity market board without reading economy state directly.
- The monster Bestiary detail page is now `scenes/ui/BestiaryDetail.tscn` plus `scripts/ui/bestiary_detail.gd`; `main.gd` prepares monster art, HP/armor/movement, ecology, resource/economy, fixed-skill, and action-probability snapshots while the component renders the unit board without reading monster catalogs or action weights directly.
- The Economy Overview dashboard is now `scenes/ui/EconomyDashboard.tscn` plus `scripts/ui/economy_dashboard.gd`; `main.gd` prepares refresh/weather, GDP, product heat, city cashflow, public clue, risk, and next-read snapshots while the component renders the board-game dashboard without reading player, map, or market state directly.
- The Intel Dossier detective board is now `scenes/ui/IntelDossierBoard.tscn` plus `scripts/ui/intel_dossier_board.gd`; `main.gd` prepares city-suspicion, anonymous-card, monster-cash, warehouse-risk, public-city-clue, and next-check snapshots while the component renders the 30-second detective board without reading hidden economy or hand state directly.
- The Standings scoreboard is now `scenes/ui/StandingsScoreboard.tscn` plus `scripts/ui/standings_scoreboard.gd`; `main.gd` prepares goal, countdown, visible settlement, public-shift, and privacy-filtered seat snapshots while the component renders the race board without reading player arrays or end-state flags directly.
- The Final Settlement board is now `scenes/ui/FinalSettlementBoard.tscn` plus `scripts/ui/final_settlement_board.gd`; `main.gd` prepares winner, money-source, starting-cash, public-event, rank-track, and after-action snapshots while the component renders the postgame board and emits follow-up action ids without reading hidden route state directly.
- The root table lobby inside the menu is now `scenes/ui/MenuRootLobby.tscn` plus `scripts/ui/menu_root_lobby.gd`; `main.gd` only passes a compact snapshot and receives action ids for new game, continue, rules, load, quit, and Codex entry. When `MenuOverlay` receives `root_table_menu`, it uses a full-screen lobby surface rather than the modal shell used by Codex/rules pages.
- The root lobby uses `MainMenuPlanetBackdrop` as the primary visual layer. It now reads as a commercial game entry screen first: large brand title, richer procedural planet backdrop with land/cloud/city-light/orbit detail, one numbered vertical primary-command stack, and small bottom utility buttons rather than a settings-panel list.
- Scene-owned menu/Codex/dashboard pages are now hard dependencies rather than soft fallbacks. Tutorial, rules, standings, economy, settlement, intel, compendium, and role identity bridge functions instantiate the relevant `scenes/ui/*` component and report `_report_required_ui_scene_missing()` if the scene contract is broken instead of rebuilding a legacy `main.gd` UI tree.
- The tutorial quick-start, rules quick-reference, and compendium hub old dynamic renderers have been removed from `main.gd`; their player-facing surfaces must stay in `scenes/ui/`.
- The new-game setup flow lobby is now `scenes/ui/NewGameSetupLobby.tscn` plus `scripts/ui/new_game_setup_lobby.gd`; `main.gd` passes table-size/challenge/readiness snapshots while the seat cards and start/back buttons remain temporary controller-generated subpage content.
- The new-game setup option board is now `scenes/ui/NewGameSetupOptionBoard.tscn` plus `scripts/ui/new_game_setup_option_board.gd`; `main.gd` passes player-count, AI-count, and challenge-depth option snapshots and receives `option_selected` signals instead of binding controller methods inside the UI renderer.
- The new-game setup seat card shell is now `scenes/ui/NewGameSetupSeatCard.tscn` plus `scripts/ui/new_game_setup_seat_card.gd`; it renders seat chips, role/monster selection controls, the embedded public identity board, and scene-driven `CardFace` role/starter previews while emitting role/monster cycle signals back to `main.gd`.
- The new-game setup seat identity board remains `scenes/ui/NewGameSetupSeatIdentityBoard.tscn` plus `scripts/ui/new_game_setup_seat_identity_board.gd`; `main.gd` passes per-seat public role, starter-monster, privacy-boundary, and role/starter card-face snapshots through the seat-card snapshot.
- `tests/ui_snapshot_capture.gd` now captures both the top of the setup page and a scrolled `new_game_setup_seats_*` view so the seat-card lower content and scene-rendered `CardFace` previews stay visible in visual QA.
- When `RuntimeGameScreen` is active, `LegacyRuntimeTable` stays in-tree only as an empty rollback shell: it is hidden, process-disabled, mouse-ignored, and its old child tree is skipped by default so it cannot compete with the split product table for input, layout, player-panel refreshes, or runtime updates.
- Runtime hand-card selection is now snapshot-owned: selecting `hand_N` sets the right inspector to card detail, preserves requirements, and exposes the matching `play_N` action through the existing controller bridge.
- Split hand-card hover now follows the same 10-second layer contract: `HandRack` previews card detail in `RightInspector`, `card_unhovered` restores the current table context from the last `apply_state()`, and the hand rack is not rebuilt for temporary hover reads.
- Persistent weather forecasts stay in top/status/overview context rather than the bottom short-window countdown. `BottomCountdownBar` should be reserved for timed decisions or urgent public windows so it does not cover the table-edge hand rack.
- Split-table fallback copy and runtime snapshot labels are now localized and player-facing: `RightInspector`, `OverlayLayer` side drawer, `PlayerBoard`, `TopBar`, `PublicTrack`, `PlanetBoard`, `ActionDock`, and the legacy `CardUI` card face use Chinese table-language defaults for empty states, detail links, why text, public logs, quick actions, card-track/planet labels, and card art/type hints instead of exposing English debug placeholders such as "Why", "Public log", "Open Codex", "Track idle", "ACTION", or "Build/Rack/Buy/Play".

The live runtime still launches `scenes/main.tscn`; this is a deliberate controller shell while the visible table moves into split scenes. New player-facing work should strengthen the split scenes first, then pass runtime data or signals through small adapters.

## Next migration rule

Before copying or porting from the listed open-source references, check `docs/open_source_reference_notes.md`. Prefer direct pattern ports from MIT or CC0 references with attribution, and use GPL/AGPL/LGPL references for product structure and behavior study unless this project explicitly accepts their license obligations.

Do not add new player-facing UI branches directly inside `scripts/main.gd` unless the change is a small compatibility adapter. New UI should land as:

1. a `scripts/viewmodels/*_snapshot.gd` shape if game state must be translated,
2. a `scenes/ui/*.tscn` component if the player sees it,
3. a `scripts/ui/*.gd` renderer that only consumes snapshots and emits signals,
4. a small bridge in `main.gd` that passes runtime data into the component.

The target product frame remains:

```text
Main table = board-game table
RightInspector = explanation and current context
Codex = encyclopedia
Debug/test reports = backstage only
```
