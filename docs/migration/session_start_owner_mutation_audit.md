# Session Start Owner Mutation Audit

Baseline: `2575fb4ac3192f8030c1719401531c582c9121c1`

Scope: analysis of the current production `Main._new_game()` / setup-start path. This document does not propose a second world owner and does not treat save restore APIs as proof of a new-session transaction.

## Findings First

### P0: the current start path destroys the active run before validation

`_confirm_start_new_run_from_setup()` records a public message, calls `_new_game()`, and unconditionally closes the menu afterward (`scripts/main.gd:3811-3819`). `_new_game()` immediately resets card resolution and the coordinator fan-out, then directly replaces world players and districts (`scripts/main.gd:4373-4383`). Only afterward does it validate starter cards, production bindings, and regional supply; each of those checks can return early (`scripts/main.gd:4428-4432`, `scripts/main.gd:4472-4479`, `scripts/main.gd:4484-4493`). There is no outer preflight, checkpoint set, rollback loop, or operation receipt. A failed replacement therefore cannot preserve the old active session.

### P0: live RNG is consumed before commit and has no fork/commit contract

The product-market reset consumes the shared `RunRngService` while generating prices and its timer (`scripts/runtime/product_market_runtime_controller.gd:159-168`, `scripts/runtime/product_market_runtime_controller.gd:216-228`, `scripts/runtime/product_market_runtime_world_bridge.gd:115-117`, `scripts/main.gd:8139-8142`). Random role resolution then consumes the same live RNG (`scripts/main.gd:7280-7312`), followed by world geometry, terrain, names, products, and demands (`scripts/main.gd:3931-3973`, `scripts/main.gd:3976-3998`, `scripts/main.gd:4050-4100`, `scripts/main.gd:4181-4209`, `scripts/main.gd:4236-4249`). Initial weather scheduling consumes it again (`scripts/runtime/weather_runtime_controller.gd:568-590`). `RunRngService` has direct draw methods and save/apply state (`scripts/runtime/run_rng_service.gd:37-60`, `scripts/runtime/run_rng_service.gd:96-116`), but no detached fork, staged state, or commit API. Restoring also emits `state_restored` and increments a restore counter (`scripts/runtime/run_rng_service.gd:37-40`), so ad hoc rewind is observably different from a failed plan that never touched live RNG.

### P0: the coordinator reset is a non-transactional fan-out

`GameRuntimeCoordinator.reset_state()` synchronously clears presentation queries, forced decisions, target choice, clock, pricing quotes, AI, monsters, military, weather, contracts, routes, commodity flow, mana, commodity inventory, sushi projection state, organization state, economic adapters, bankruptcy, victory, session lifecycle, purchase windows, card inventory planning, card queues, execution, effects, hand interaction, and purchase settlement (`scripts/runtime/game_runtime_coordinator.gd:3804-3897`). Most of these owners expose only `reset_state()` or a save-oriented `to_save_data()/apply_save_data()` pair; they do not expose `preflight_new_session`, a runtime checkpoint, or rollback. `CardResolutionQueueRuntimeService` and several presentation/operational owners have no save checkpoint at all (`scripts/runtime/card_resolution_queue_runtime_service.gd:41-51`).

### P0: public-demand bootstrap contains a finalized partial-state failure edge

Production binding creates neutral market facilities and commodity-demand installations (`scripts/runtime/game_runtime_coordinator.gd:724-799`, `scripts/runtime/game_runtime_coordinator.gd:802-860`). It preflights both finalizers, then finalizes infrastructure before commodity flow (`scripts/runtime/game_runtime_coordinator.gd:861-876`). If the flow finalizer still fails after the market finalizes, the code returns a failure without rolling the finalized market back (`scripts/runtime/game_runtime_coordinator.gd:877-884`). The local compensation helper only rolls back open receipts (`scripts/runtime/game_runtime_coordinator.gd:895-910`). This is an explicit cross-owner partial-state gap for session-start atomicity.

### P1: `GameSessionRuntimeController` is reset early, not committed last

The coordinator resets `GameSessionRuntimeController` during the destructive fan-out (`scripts/runtime/game_runtime_coordinator.gd:3874-3876`; implementation at `scripts/runtime/game_session_runtime_controller.gd:340-352`). `Main` invokes `begin_session()` only near the end (`scripts/main.gd:4519-4529`), but by then the old lifecycle is already gone. `begin_session()` itself changes the lifecycle to `error` on invalid input and marks successful starts dirty (`scripts/runtime/game_session_runtime_controller.gd:60-76`). The future transaction must checkpoint the old lifecycle before any mutation and make successful `begin_session` the final business commit.

### P1: observable side effects happen before commit

World replacement and selection writes emit signals immediately (`scripts/runtime/world_session_state.gd:32-48`, `scripts/runtime/world_session_state.gd:76-115`, `scripts/runtime/table_selection_state.gd:16-56`, `scripts/runtime/table_selection_state.gd:80-105`). Public log reset emits a revision signal (`scripts/presentation/public_log_presentation_owner.gd:84-92`), and it is reset once through the coordinator presentation reset and again explicitly by `Main` (`scripts/presentation/table_presentation_query_ports.gd:50-54`, `scripts/runtime/game_runtime_coordinator.gd:1139-1142`, `scripts/main.gd:4399`). Before `begin_session`, the path schedules weather, emits a card-ingress visual callout and log, and appends several start messages (`scripts/main.gd:4499-4518`). Presentation refresh is requested only after `begin_session`, but earlier owner signals can expose partial state; commit-only logging and presentation are not isolated.

### P1: production rebinding still takes `Main` as a mutable world dependency

The start path calls `refresh_v06_production_player_bindings(self)` (`scripts/main.gd:4472-4476`). The coordinator stores that `Main` node as `_bound_world` and rebinds several adapters (`scripts/runtime/game_runtime_coordinator.gd:629-643`). Product market also reaches `Main._roll_timer` through its world bridge (`scripts/runtime/product_market_runtime_world_bridge.gd:115-117`). A scene-owned transaction cannot be Main-free while these new-session operations require the root node rather than narrow typed world/session dependencies.

### P1: `Main` itself owns mutable start state without a checkpoint

`Main` mutates card-resolution timers, selected card strings, district-supply overlay indices, coordinator readiness flags, `time_scale`, and setup settings during the operation (`scripts/main.gd:4384-4393`, `scripts/main.gd:4404-4411`, `scripts/main.gd:4480-4483`, `scripts/main.gd:4501-4505`, `scripts/main.gd:4530`). These fields are outside owner checkpoints. They must either move to their existing scoped owners or become commit-only presentation state; copying them into a new transaction coordinator would create another monolith.

## Current Production Call Chain

1. Setup surface emits a string action; `Main._on_new_game_setup_action_requested()` dispatches `setup_start` (`scripts/main.gd:3563-3586`).
2. `Main._confirm_start_new_run_from_setup()` writes a public message, calls `_new_game()`, sets menu speed, and closes the menu regardless of success (`scripts/main.gd:3811-3819`).
3. `CardResolutionRuntimeController.reset_state()` is called first (`scripts/main.gd:4373-4378`; owner reset at `scripts/runtime/card_resolution_runtime_controller.gd:81-103`).
4. `GameRuntimeCoordinator.reset_state()` executes its fixed destructive fan-out (`scripts/main.gd:4379-4381`, `scripts/runtime/game_runtime_coordinator.gd:3804-3897`).
5. `WorldSessionState.players` and `.districts` are replaced with empty arrays; immediate signals fire (`scripts/main.gd:4382-4383`, `scripts/runtime/world_session_state.gd:76-85`).
6. Main-owned card-window fields are cleared (`scripts/main.gd:4384-4393`).
7. Public history and private annotations are reset together, then card-resolution selection is cleared (`scripts/main.gd:4394-4395`, `scripts/runtime/game_runtime_coordinator.gd:1321-1332`).
8. Product market and city-GDP derivatives reset; product market consumes live RNG (`scripts/main.gd:4396-4398`).
9. Public log, visual cues, clock, world game time, table selections, victory state, and monster timers reset (`scripts/main.gd:4399-4414`). Several are duplicate resets already performed inside coordinator reset.
10. Setup arrays are normalized, random roles are resolved with live RNG, and players are appended directly into `WorldSessionState` (`scripts/main.gd:4416-4467`). AI profiles and memory are inserted into those player dictionaries.
11. AI player state is normalized in place (`scripts/main.gd:4468`; `scripts/runtime/ai_runtime_controller.gd:155-157`).
12. Districts are generated directly into `WorldSessionState`, consuming live RNG for count, geometry, terrain, goods, names, and viability patches (`scripts/main.gd:4470`, `scripts/main.gd:3931-4249`).
13. `RegionInfrastructureRuntimeController.initialize_regions()` validates a prepared map, then resets and replaces its state (`scripts/main.gd:4471`, `scripts/main.gd:542-563`, `scripts/runtime/region_infrastructure_runtime_controller.gd:159-198`).
14. Production bindings are refreshed. This binds WorldSessionState, bootstraps the commodity belt, configures player organizations, creates public demand facilities/installations, refreshes routes, configures economic adapters, and refreshes monster/AI ports (`scripts/main.gd:4472-4482`, `scripts/runtime/game_runtime_coordinator.gd:629-694`).
15. Region supply is configured from the current world and a seed derived from live RNG state (`scripts/main.gd:4483-4493`, `scripts/runtime/game_runtime_coordinator.gd:1711-1739`, `scripts/runtime/region_supply_runtime_controller.gd:45-108`).
16. Product prices refresh, initial district selection is chosen, weather forecast is scheduled, supply presentation fields synchronize, and prices refresh a second time (`scripts/main.gd:4494-4505`).
17. Visual callout and public start messages are emitted before session commit (`scripts/main.gd:4505-4518`, `scripts/main.gd:4534-4552`).
18. `GameSessionRuntimeController.begin_session()` is invoked, settings are written to `user://`, and one full table refresh is requested (`scripts/main.gd:4519-4531`, `scripts/main.gd:3852-3869`).

## Owner Capability Matrix

`Save round-trip` below means an existing persistence API, not a proven start-transaction API. Unless explicitly stated, there is no new-session preflight/checkpoint/rollback contract.

| Owner | Current start mutation/read | Existing transaction capability | Observable effects / risk | Required session-start boundary |
|---|---|---|---|---|
| RunRngService | Product market, random roles, map generation, and weather consume live draws | `to_save_data/apply_save_data`; no fork or staged commit (`scripts/runtime/run_rng_service.gd:96-116`) | Restore emits signal and changes restore metrics; failed starts advance live RNG | Add detached fork/checkpoint plus commit-on-success; no live draw during plan |
| WorldSessionState | Direct clear, player append, geometry and district generation, time reset | Explicit runtime checkpoint and restore exist (`scripts/runtime/world_session_state.gd:438-448`) | Setters emit immediately; direct array append bypasses a typed apply boundary | Reuse checkpoint; add pure plan preflight and one atomic world apply |
| GameSessionRuntimeController | Reset inside coordinator; `begin_session` at end | Save preflight/apply exists, no named runtime checkpoint (`scripts/runtime/game_session_runtime_controller.gd:129-188`) | Invalid begin sets lifecycle error; success marks dirty and resets clock | Capture old session state; preflight before mutation; commit last |
| TableSelectionState | Direct field writes and resolution/district selection | Save round-trip only (`scripts/runtime/table_selection_state.gd:122-145`) | Every changed setter emits `selection_changed` | Add checkpoint/restore or defer one selection apply until commit |
| RoleCatalogRuntimeService | Read-only role count/definitions (`scripts/main.gd:4702-4721`) | Read-only owner; no rollback needed | No mutation | Use during plan preflight; freeze role index/name parity |
| Monster catalogs / runtime card catalog | Read monster definitions and starter rank-I cards (`scripts/main.gd:4965-4983`, `scripts/main.gd:7333-7338`, `scripts/runtime/game_runtime_coordinator.gd:2149-2163`) | Read-only catalogs | No mutation during lookup | Build detached starter-card rows in plan; fail before apply |
| MonsterRuntimeController | Coordinator reset; timer prime | Save round-trip only (`scripts/runtime/monster_runtime_controller.gd:1226-1265`) | Clears monsters, wagers, starter state, journals; timer mutation | Add preflight/checkpoint/apply/rollback for empty new-session state and timer plan |
| MilitaryRuntimeController | Coordinator reset | Save round-trip only (`scripts/runtime/military_runtime_controller.gd:902-920`) | Clears live units and bankruptcy journal | Add checkpoint/apply/rollback |
| AIRuntimeController | Coordinator reset; profile/memory read; ensure player state mutates WSS rows | Save round-trip only (`scripts/runtime/ai_runtime_controller.gd:243-282`) | Old AI timers/receipts are lost; normalization mutates player dictionaries | Keep algorithms unchanged; plan profiles, checkpoint controller, apply after world roster |
| PlayerManaRuntimeController | Coordinator calls `reset_state()` with default zero players | Save round-trip only (`scripts/runtime/player_mana_runtime_controller.gd:289-320`) | Clears pools/reservations and increments revision | Add player-count preflight and checkpoint/apply/rollback |
| CardInventoryRuntimeService | Coordinator reset of planner/receipt metrics; actual starter slot is written to WSS | No save/checkpoint API (`scripts/runtime/card_inventory_runtime_service.gd:38-50`) | Operational counters from old run are lost | Add narrow runtime checkpoint or make reset commit-only |
| CommodityCardInventoryRuntimeController | Coordinator reset; resets its state adapter; later initializes default belt | Save round-trip only (`scripts/runtime/commodity_card_inventory_runtime_controller.gd:649-690`) | Clears operation journals and adapter reservations; belt bootstrap mutates inventory | Add preflight/checkpoint/apply/rollback; belt result belongs in plan/subplan |
| CommoditySushiTrackRuntimeService | Projection-only reset | No save/checkpoint (`scripts/runtime/commodity_sushi_track_runtime_service.gd:36-44`) | Clears revisions/terminal UI request results | Do not apply until commit; rebuild projection after authoritative owners succeed |
| PlayerOrganizationRuntimeController | Reset preserves old actor IDs, then production binding may reconfigure new actor IDs | Save round-trip only (`scripts/runtime/player_organization_runtime_controller.gd:471-506`) | Reconfiguration clears players/journal and generates a new capability secret (`scripts/runtime/player_organization_runtime_controller.gd:73-95`) | Preflight actor list; checkpoint secret/state; apply after roster; rollback on failure |
| RegionInfrastructureRuntimeController | `initialize_regions`; then neutral market facilities are created | Save round-trip only; facility actions have local prepare/rollback/finalize | `initialize_regions` validates before reset, but finalized public-demand market may outlive a flow failure | Add whole-owner checkpoint and cross-owner batch commit; do not rely only on per-facility compensation |
| RegionSupplyRuntimeController | `configure` replaces racks/bags and deterministic per-region RNG | Save round-trip only (`scripts/runtime/region_supply_runtime_controller.gd:335-375`) | Configure clears old supply before later steps; no preflight API | Build/validate supply subplan, checkpoint, then apply |
| RouteNetworkRuntimeController | Coordinator reset; public-demand bootstrap forces refresh | Save round-trip only (`scripts/runtime/route_network_runtime_controller.gd:187-214`) | Clears caches/counters; forced rebuild happens before session commit | Make route refresh post-domain-apply and rollback-safe or commit-only cache rebuild |
| ProductMarketRuntimeController | Main reset, then two `refresh_prices` calls | Save round-trip only (`scripts/runtime/product_market_runtime_controller.gd:723-748`) | Reset consumes RNG and destroys futures; world bridge calls Main | Build market subplan with staged RNG; add checkpoint/apply/rollback; remove Main timer dependency |
| CommodityFlowRuntimeController | Coordinator reset; public-demand installs/finalizes | Save round-trip only plus local installation rollback (`scripts/runtime/commodity_flow_runtime_controller.gd:1237-1325`) | Large economic state cleared; cross-owner finalize gap can leave partial state | Whole-owner checkpoint plus atomic infrastructure/flow batch |
| WeatherRuntimeController | Coordinator reset; schedule initial forecast | Save round-trip only (`scripts/runtime/weather_runtime_controller.gd:485-525`) | Reset clears events/history/telemetry; scheduling consumes live RNG and adds callout | Put initial forecast in plan using staged RNG; checkpoint/apply/rollback; emit callout after commit |
| CardResolutionRuntimeController | Main resets first | Save round-trip only (`scripts/runtime/card_resolution_runtime_controller.gd:358-489`) | Clears active window and transition lineage | Add checkpoint/restore or reset only after all preflight/checkpoints |
| CardResolutionQueueRuntimeService | Coordinator reset | No save/checkpoint API | Clears current/next/active queues and increments revision | Blocking gap: add explicit checkpoint/apply/rollback |
| CardResolutionExecutionRuntimeService | Coordinator reset | Save preflight/apply exists (`scripts/runtime/card_resolution_execution_runtime_service.gd:419-460`) | Clears inflight and settlement journals | Reuse normalized save/checkpoint shape, but add named runtime checkpoint/rollback contract |
| CardResolutionHistoryRuntimeService | Main resets after coordinator | Save preflight/apply exists (`scripts/runtime/card_resolution_history_runtime_service.gd:173-203`) | Public history is destroyed before starter validation | Reuse preflight/apply as checkpoint contract; rollback before exposing new session |
| CardHistoryPrivateAnnotationService | Reset together with public history | Explicit save validation and runtime checkpoint/restore (`scripts/runtime/card_history_private_annotation_service.gd:336-463`) | Private annotations and role use are lost on current failed start | Reuse checkpoint; apply empty state only inside transaction; preserve old state on failure |
| VictoryControlRuntimeController | Reset in coordinator and again from Main | Save round-trip only (`scripts/runtime/victory_control_runtime_controller.gd:368-405`) | Duplicate reset loses audit/outcome state before validation | One checkpoint and one new-session apply; no duplicate reset |
| BankruptcyNeutralEstateRuntimeController | Coordinator reset | Save round-trip only (`scripts/runtime/bankruptcy_neutral_estate_runtime_controller.gd:52-70`) | Clears estate and neutral-rent journals | Add checkpoint/apply/rollback |
| PublicLogPresentationOwner | Reset through presentation-query reset and again from Main; start messages appended | Save round-trip only (`scripts/presentation/public_log_presentation_owner.gd:95-124`) | Reset emits revision; messages appear before session commit | Preserve old log through failure; queue new-run messages as commit-only receipts |
| VisualCueRuntimeOwner | Main reset; ingress callout added before commit | No save/checkpoint API (`scripts/runtime/visual_cue_runtime_owner.gd:40-45`) | Old cues are destroyed; new cue can describe a run not yet active | Reset and publish cues only after successful business commit |
| Presentation query/scheduler/refresh ports | Query state and forced-decision candidates reset; final full refresh requested | No gameplay checkpoint; presentation-only | Can expose partial state through signals; duplicate refresh risk | Freeze/suspend during transaction; exactly one refresh after success, none on failure |
| ContractRuntimeController | Coordinator reset | Save round-trip only (`scripts/runtime/contract_runtime_controller.gd:758-789`) | Clears active contracts/history before validation | Add checkpoint/apply/rollback |
| DistrictPurchaseRuntimeController | Coordinator reset | Save round-trip only (`scripts/runtime/district_purchase_runtime_controller.gd:282-310`) | Clears active purchase windows | Add checkpoint/apply/rollback or close only at commit |
| CardTargetChoiceRuntimeController | Coordinator reset | Save round-trip only (`scripts/runtime/card_target_choice_runtime_controller.gd:96-126`) | Clears pending target decisions | Add checkpoint/apply/rollback |
| CityGdpDerivativeRuntimeController | Main reset | Save round-trip only (`scripts/runtime/city_gdp_derivative_runtime_controller.gd:223-238`) | Clears positions/receipts before validation | Add checkpoint/apply/rollback |
| Core economic / hand / effect / settlement adapters | Coordinator resets operational journals and caches (`scripts/runtime/game_runtime_coordinator.gd:3859-3897`) | Mostly reset-only; some state is subordinate to authoritative owners | Old transaction journals and pending UI interactions are lost | Inventory each subordinate state; checkpoint mutable journals or defer reset to commit |

## Exact Current Mutation Order

The following order is the observed synchronous order, not a recommended order:

1. Public setup-start feedback.
2. CardResolutionRuntimeController reset.
3. Coordinator readiness flags reset.
4. TablePresentationQueryPorts reset: public log, public-log port, victory presentation, viewer-private feedback.
5. ForcedDecisionRuntimeScheduler candidates cleared.
6. CardTargetChoice reset.
7. WorldEffectiveClock reset.
8. CardMarketPricing quotes reset.
9. AI reset.
10. Monster reset.
11. Military reset.
12. Weather reset.
13. Contract reset.
14. RouteNetwork reset.
15. CommodityFlow reset.
16. PlayerMana reset with zero players.
17. CommodityCardInventory reset, including CardPlayerState adapter transaction state.
18. CommoditySushiTrack projection reset.
19. Region-supply source port rebound.
20. PlayerOrganization reset with its previous actor IDs.
21. CoreEconomicCard adapter reset.
22. CommodityFlow bridge reset.
23. BankruptcyNeutralEstate reset.
24. VictoryControl and Victory bridge reset.
25. GameSession reset to idle.
26. DistrictPurchase reset.
27. CardInventory planner reset.
28. CardResolutionQueue reset.
29. CardResolutionExecution reset.
30. Card economy/product/route effect reset.
31. Player hand interaction reset.
32. District purchase settlement reset.
33. WorldSession players and districts cleared.
34. Main card-window fields cleared.
35. CardResolutionHistory and CardHistoryPrivateAnnotation reset.
36. Card-resolution selection cleared.
37. ProductMarket reset, consuming shared RNG.
38. CityGdpDerivative reset.
39. Public log reset a second time.
40. Visual cues reset.
41. World clock restored to zero a second time; WSS game time set to zero.
42. Main time scale and table selection fields reset.
43. VictoryControl reset a second time.
44. Monster action timers primed.
45. Setup normalized; random roles resolved from live RNG.
46. Players appended directly to WorldSessionState; AI state normalized.
47. District/world plan generated directly into WorldSessionState from live RNG.
48. RegionInfrastructure initialized.
49. Production player bindings refreshed: belt, organization, public demand, routes, adapters.
50. RegionSupply configured.
51. ProductMarket prices refreshed.
52. Initial district selected.
53. Initial Weather forecast scheduled from live RNG.
54. Main supply/card presentation fields synchronized; prices refreshed again.
55. Card-ingress cue and public start logs emitted.
56. GameSession `begin_session` called.
57. Setup settings written to user config.
58. One full presentation refresh requested.

## Blocking Transaction Gaps

1. **Active-session isolation:** destructive reset precedes every meaningful preflight. There is no way to guarantee old-run preservation with the present call order.
2. **RNG staging:** no detached RNG fork/commit means plan construction and failed starts necessarily alter live deterministic state.
3. **Queue and operational checkpoints:** card-resolution queue, visual cues, sushi projection, forced-decision scheduler, card inventory planner, and several adapters have no runtime checkpoint.
4. **Cross-owner public demand:** infrastructure can be finalized before commodity flow reports its final result, leaving a partial market installation.
5. **Main world dependency:** production binding and market timing still call through `Main`; a scene-owned coordinator cannot own a typed transaction while these calls remain.
6. **Signal suppression/commit-only receipts:** WSS, selection, public log, weather callouts, and presentation ports publish before commit.
7. **Duplicate resets:** public log, world clock, and victory are reset twice, making exact-once and rollback accounting ambiguous.
8. **Main-private state:** card timers, market selection strings, overlay indices, readiness flags, and time scale are outside owner checkpoints.

## Safe Handoff Constraints

- Build a detached `SessionStartPlan` before any reset, using read-only catalogs and a staged RNG state.
- Require all owner preflights before capturing checkpoints, then capture every mutable owner before the first apply.
- Use a documented dependency order: foundational world/roster, domain state, operational state, selection, then `GameSessionRuntimeController` last.
- Roll back in exact reverse apply order. Treat rollback failure as a first-class failed receipt.
- Hold logs, callouts, settings writes, menu close, signals, and presentation refresh until commit. Failed starts must emit only an operation failure to Setup UI.
- Do not use the 19-section save registry as a substitute for the new-session transaction; add narrow runtime checkpoint APIs where current save contracts are absent or observably unsuitable.
- Replace `refresh_v06_production_player_bindings(self)` and Main timer callbacks with narrow typed dependencies rather than moving Main into the new coordinator.
