# `scripts/main.gd` responsibility inventory

Baseline: `fa7ca46`; the pre-removal file had **17,761 physical lines**,
**15,570 nonblank lines** and **1,028 methods**. After onboarding removal it
has **15,488 physical lines**, **13,528 nonblank lines**, **916 methods**, 102
top-level variables and 121 constants. It remains a transitional monolith.

This inventory uses ordered ownership rules. Every baseline method is assigned
by the first matching rule; therefore the classification is exhaustive without
copying 1,028 method names into prose. Exact exceptions are listed below.

| Priority | Method/field selector | Responsibility | Disposition | Owner |
| ---: | --- | --- | --- | --- |
| 1 | names/text containing `campaign`, `first_run`, `first_mission`, `tutorial`, `scenario`, `coach`, `recommended_start` | legacy onboarding/campaign | delete | none |
| 2 | `_ready`, `_process`, `_unhandled_input`, scene lookup and top-level signal binding | app startup/composition | blocked, then bootstrap only | future `scripts/app/game_application_root.gd` |
| 3 | new-game setup/configuration, `_new_game*`, role/seat/monster selection | new game setup | new small owner | scene-owned new-game/session coordinator |
| 4 | `_save*`, `_load*`, settings and v0.6 owner transaction glue | save/load | existing owner where available; otherwise blocked | v0.6 save coordinator/owner registry |
| 5 | runtime snapshot and `GameScreen` binding/presentation methods | GameScreen binding | new small owner | table presentation coordinator |
| 6 | map/district/planet methods | PlanetBoard binding | existing/new small owner | PlanetBoard + map presentation bridge |
| 7 | player/hand/strategy methods | PlayerBoard binding | existing/new small owner | PlayerBoard + hand interaction owner |
| 8 | `_open_*menu`, menu routing and overlay methods | menu navigation | new small owner | menu router/composition |
| 9 | role/card/product/region/monster codex methods | compendium | existing owner | codex navigation/public snapshot services |
| 10 | economy/intel/standings/final-settlement pages | dashboards/settlement | existing owner | public snapshot services + final settlement composition |
| 11 | audio methods/fields | audio | new small owner | scene-owned table audio controller |
| 12 | card resolution/queue/track/counter methods | card runtime | existing owner plus blocked facade glue | CardResolutionRuntimeController/services |
| 13 | monster methods | monster runtime | existing owner plus blocked facade glue | MonsterRuntimeController |
| 14 | military methods | military runtime | existing owner plus blocked facade glue | MilitaryRuntimeController |
| 15 | weather methods | weather runtime | existing owner plus blocked facade glue | WeatherRuntimeController |
| 16 | AI methods | AI runtime | existing owner plus blocked world port | AI runtime controller |
| 17 | economy/city/product/route methods | economy runtime | existing owners plus blocked world port | product, flow, route, infrastructure owners |
| 18 | victory/audit/game-over methods | final settlement | existing owner | VictoryControl + FinalSettlement composition |
| 19 | `_get`, `_set`, fallback/missing/legacy helpers | compatibility surface | delete after consumers migrate | none |
| 20 | all remaining private helpers | mixed gameplay/presentation | blocked | must be assigned by call graph before main removal |

## Major field assignment

- Delete: all campaign, scenario and first-run progress/focus/reward fields.
- Existing owner: runtime domain controller references and their authoritative
  state.
- New small owner: menu state, table presentation refresh, audio state,
  new-game setup state.
- Bootstrap only: explicit scene-owned node references needed for startup and a
  small number of top-level signals.
- Blocked: `players`, `districts`, runtime clocks/selections, card queues,
  presentation caches and numerous world-port helpers are still read by normal
  gameplay across the file.

## Removal risk

Deleting onboarding removes one large contiguous branch, but does not make the
remaining file a safe bootstrap. Normal new-game, save/load, map, card,
economy, AI, monster, military, weather and settlement consumers still call
hundreds of methods on the root. Renaming or copying this remainder is
forbidden. `main.gd` can be removed only after those ports are moved to their
real owners and the root scene references a bootstrap of roughly 120 lines or
less.

## Exact removal blockers after onboarding purge

| Blocker | Root methods/fields | Current consumers | Required owner/API | Why unsafe in this change |
| --- | --- | --- | --- | --- |
| World/session state | `players`, `districts`, `rng`, `game_time`, selection fields; `_new_game`, load adapter | domain world bridges, UI snapshots, save restore | `RunWorldState` plus topology/selection APIs | normal new game and restored sessions still mutate the root-owned arrays directly |
| Runtime loop | `_process`, timer/update sequencing | AI, weather, card queue, monster, military, economy controllers | bounded `RuntimeLoop`/session orchestrator | controllers currently depend on the root’s exact ordering and clock inputs |
| Card execution | `_queue_skill_resolution`, `_complete_active_card_resolution`, `_apply_card_resolution_effect_request`, `_use_skill` | GameScreen/HandRack actions and CardResolution services | complete CardExecution world port | queue lifecycle is scene-owned only in part; concrete world mutation still returns through Main |
| Runtime world bridges | root method/value callbacks bound by `GameRuntimeCoordinator.bind_ai_world(self)` and sibling bridges | AI, monster, military, product/route/economy controllers | typed read/write world ports | replacing hundreds of dynamic root callbacks atomically exceeds the safe onboarding deletion boundary |
| Setup/catalog | `_new_game`, setup snapshots, role/starter catalogs and configured arrays | NewGameSetupPage and session start | normal-game setup/session coordinator | catalogs and world construction remain coupled to root state |
| Save/load | `_load_run`, `_apply_run_domain_state_compatibility_adapter`, root fields | GameSession/Save coordinator and current-run menu | v0.6 owner-registry restore transaction | transport is scene-owned, but applying a complete normal world still targets Main |
| Presentation/action routing | `_runtime_table_snapshot_source`, `_on_runtime_game_screen_action_requested`, map/hand/menu routes | GameScreen, PlanetBoard, PlayerBoard, MenuOverlay | table presentation coordinator and action router | current UI components emit stable IDs but Main still resolves many IDs to world mutations |

No new replacement monolith or root bootstrap was created. `scenes/main.tscn`
still references `res://scripts/main.gd`, so the truthful final status is
`LEGACY_ONBOARDING_PURGED_MAIN_GD_REMOVAL_BLOCKED`.
