# Agent C — VS06-C10 Legacy Path Retirement Audit

Audit snapshot: 2026-07-14, HEAD `c9c1b33`, shared dirty worktree. This was a read-only production audit; only this report and `docs/legacy_runtime_retirement_v06.md` were added.

## Executive result

Current player composition does **not** instantiate CityDevelopment, CityTradeNetwork, EconomyCashflow, GdpFormula, or IndustryCapacity. Those files are retirement candidates, but none is physically deletable yet because the enabled design-QA add-on, historical tool scenes, registries, and stale tests still reference them.

Four legacy production paths remain genuinely reachable and block broader retirement:

1. v0.4 `monster_card` still directly calls `_summon_monster_from_card`.
2. v0.4 `public_facility` still uses a compatibility wrapper into RegionInfrastructure.
3. v0.4 hand/queue/counter paths still have direct world-record mutations alongside active CardInventory services.
4. multiple legacy cash domains still write shared player cash directly; the v0.6 state adapter is not yet a universal cash owner.

No standalone legacy city-builder call remains in `main.gd`. The `build_city` occurrences are coach-stage text/actions that open the real card rack; they do not mutate a city.

## Composition evidence and file retirement candidates

Static scan of `scenes/runtime/GameRuntimeCoordinator.tscn`, `scripts/runtime/game_runtime_coordinator.gd`, and `scripts/main.gd` returns zero references to the five retired owner groups below.

| Candidate cluster | Player-runtime status | Replacement production owner/API | Remaining non-player references | Deletion prerequisite |
| --- | --- | --- | --- | --- |
| `city_development_runtime_controller.gd`, `city_development_world_bridge.gd`, their two runtime scenes | Uncomposed; controller logic unreachable from current main/Coordinator | `play_v06_runtime_card` → CardFlow → `CoreEconomicCardRuntimeAdapterV06` → `RegionInfrastructureRuntimeController` | enabled QA dock, Ruleset/CityDevelopment benches, layout smoke, registries | migrate QA buttons/registries; facility success/failure/rollback/finalize/replay + real main/AI dispatch; then zero-reference gate |
| `city_product_project_state.gd`, `city_product_project_bridge.gd`, v0.4→v0.5 project migration | Reachable only through the uncomposed CityDevelopment cluster and historical QA | CommodityFlow installations/Sale Receipts; no project-share owner in v0.6 | project/CityDevelopment characterization tests and historical docs | delete only in the same call-graph-closed CityDevelopment batch after save policy explicitly rejects old project envelopes |
| `city_trade_network_runtime_controller.gd`, `city_trade_network_world_bridge.gd`, two scenes | Retired stubs; uncomposed | `RouteNetworkRuntimeController` for routes; `CommodityFlowRuntimeController` for flow/GDP/save | enabled QA dock, old characterization bench, layout smoke, registries | RouteNetwork + CommodityFlow composition/save/route tests; rewrite stale 108-case owner assertions; zero add-on/tool refs |
| `economy_cashflow_runtime_controller.gd` + scene | Retired shell (`replacement_owner=CommodityFlowRuntimeController`); uncomposed | `CommodityFlowRuntimeController.advance_world` + `CommodityFlowWorldBridge.apply_sale_receipt_batch` | enabled QA dock, old benches, product-market characterization | Sale Receipt cadence/remainder/cash atomicity/save gate; remove historical dock/bench entry |
| `gdp_formula_runtime_controller.gd` + scene | Retired shell; uncomposed | `CommodityFlowRuntimeController.sale_receipts` and `region_gdp_snapshot` | enabled QA dock, old benches, formula/ownership assertions | receipt GDP lineage/Victory observation gate; update stale delegated-owner strings and layout smoke |
| `industry_capacity_runtime_service.gd`, `industry_capacity_world_bridge.gd`, two scenes | Uncomposed v0.5 implementation | `PlayerManaRuntimeController` + v0.6 CardFlow asset reservation | enabled QA dock, Industry bench, `layout_scene_smoke_test`, `shared_card_group_runtime_test` | six-color reserve/commit/release/save tests and Queue group-limit tests; replace stale static-composition assertions |
| `visual_event_queue.gd` | Zero production references; test-only | main/scenario event array → `GameScreen._sync_visual_events` → `VisualEventLayer.set_visual_events` | `visual_event_smoke_test.gd` and historical docs only | migrate the queue test to the active layer/snapshot path, then zero-reference delete |

The QA add-on is enabled in `project.godot`; its dock has explicit scene constants and buttons for all five historical owner groups. Deleting runtime files before changing the add-on would leave editor-facing broken resources even though the player scene does not use them.

## City / facility callsites

| Callsite | Real production call? | Current owner | Replacement / retirement action | Required test before removal |
| --- | ---: | --- | --- | --- |
| `main.gd:13832,13953` coach stage `build_city` | UI only | Coach/rack presentation | keep or rename after UI copy migration; no builder exists | coach action must still open a visible supply rack and never direct-build |
| `main.gd:19575` → `GameRuntimeCoordinator.submit_public_facility_card` | Yes, v0.4 `public_facility` | RegionInfrastructure via compatibility wrapper | migrate the whole card family to `play_v06_runtime_card`; do not fall back on failure | every catalog facility: canonical target/price, CardFlow exact-once, owner rollback/finalize, replay, save/load |
| `game_runtime_coordinator.gd:965` → `RegionInfrastructureWorldBridge.submit_legacy_index_facility_action` | Yes | compatibility index adapter; no second facility truth | remove only when no production v0.4 caller and all callers use stable `region_id` | static dynamic-call scan plus real human/AI facility dispatch |
| `region_infrastructure_world_bridge.gd:43` → `submit_facility_action` → `apply_facility_action` | Yes | `RegionInfrastructureRuntimeController` | keep `submit_facility_action`; retire only the legacy-index adapter | region ID/index parity and invalid index fail-closed |
| `main.gd:9733-9859` terrain/product/demand assignment and C9 policy patch | Yes | generated-map owner | map generation is not legacy, but C9's forced full-map direct-demand normalization is now an acknowledged overconstraint pending C11 replacement | until C11: preserve parse; after C11: one legal production/one legal demand plus optional remote-route coverage audit and RegionInfrastructure fact equality |

## Monster callsites

| Callsite | Real production call? | Current owner | Replacement / retirement action | Required test before removal |
| --- | ---: | --- | --- | --- |
| `main.gd:18809` `_is_v06_runtime_card` interception | Yes | Coordinator/CardFlow v0.6 route | keep | human + AI first summon must both hit the same transaction journal |
| `main.gd:19572` direct `_summon_monster_from_card` | Yes, for v0.4 cards | legacy writer inside `MonsterRuntimeController` | route/reject the entire old family before player resource commit, then delete this dispatch | first summon, duplicate replay, commit failure rollback, finalize, save/load, privacy |
| `monster_runtime_controller.gd:2009,2061,1653` legacy upgrade/summon/make helpers | Only through the previous branch plus QA fixtures | legacy roster/UID writer | delete as one call-graph closure after branch and fixtures migrate | zero production/fixture reflection refs; preserve duration/removal helpers |
| `main.gd:2043-2052` dynamic roster/UID setter | No static production caller found | bypasses owner revision/journal | remove setter branch after fixtures use validated save API | save fixture restore and zero `.set("auto_monsters")` scan |
| `ai_runtime_controller.gd:347-352` `auto_monsters` property setter | No static assignment caller found; getter is heavily used | bypasses Monster owner | remove setter only; retain getter/snapshots until AI migration | AI policy read behavior unchanged; zero assignment scan |

The authoritative replacement APIs are `prepare_unit_card_intent_v06`, `commit_unit_card_intent_v06`, `rollback_unit_card_intent_v06`, and `finalize_unit_card_intent_v06`, consumed through `GameRuntimeCoordinator.play_v06_runtime_card`.

## Hand and card-state callsites

| Callsite | Real production call? | Owner status | Replacement / retirement action | Required test |
| --- | ---: | --- | --- | --- |
| `main.gd:18433-18498` district purchase | Yes | `DistrictPurchaseSettlementRuntimeService` + `CardInventoryRuntimeService`; compatibility-active | retain until legacy market/catalog is retired; v0.6 first-table uses `purchase_v06_first_table_facility_card` | legal/illegal purchase, exact cash, discard privacy, stale revision, save |
| `main.gd:18226-18253` player hand disrupt/steal | Yes | `PlayerHandInteractionRuntimeService`; compatibility-active | retain until SS06-08 owner port has a real atomic production owner | target auth, rollback/finalize, duplicate, public privacy |
| `main.gd:18925-18945` normal v0.4 queue submission | Yes | CardInventory queue commit + CardResolutionQueue | retain | one card leaves hand, queue exact-once, queue failure compensation |
| `card_resolution_execution_world_bridge.gd:82-89` requirement revalidation restores a slot directly | Yes during resolution | legacy world-record bypass | replace with an explicit CardInventory receipt or remove the restore need | failed requirement with reusable/consumed cards, replay, slot revision |
| `main.gd:15732-15760` counter queues/clears `queued_for_resolution` directly | Yes for human and AI counter paths | legacy hand flag writer | move to CardInventory/response-window transaction; no UI-only masking | authorized responder, duplicate respond/pass, timeout, rollback, save checkpoint |
| `main.gd:19512-19525` `_clear_queued_card_flag` | Yes on skipped entries | legacy hand flag writer | same CardInventory queue lifecycle | skipped/invalid queue entry restores exactly once |
| `CommodityCardInventoryRuntimeController` + `CardPlayerStateProductionAdapterV06` | Yes for v0.6 purchase/play | authoritative v0.6 state boundary | keep; never create another transaction service | current CardFlow policy/transaction/production integration suites |

Therefore `CardInventoryRuntimeService`, `DistrictPurchaseSettlementRuntimeService`, and `PlayerHandInteractionRuntimeService` are **not retirement candidates today**. `GameRuntimeCoordinator._composition_ready` still requires them for the v0.4 runtime.

## Cash callsites

There is no single production API that can replace every row below today. “Use CardPlayerStateProductionAdapterV06” is valid only inside the shared v0.6 CardFlow lifecycle.

| Writer / caller | Reachability | Current domain | Retirement action / replacement |
| --- | ---: | --- | --- |
| `main._pay_skill_play_cost` (`8685`; called at `18561,18951,19347`) | active | v0.4 card queue/counter cost | migrate card family to `play_v06_runtime_card`; cost must commit inside CardFlow, not before/after it |
| `main._set_card_bid_for_player` (`17569`, cash at `17603`) and counter refund (`19351`) | active human + AI | v0.4 bid/counter escrow | no atomic replacement yet; add a revisioned cash/escrow participant before deletion |
| `main._guess_card_resolution_owner_for_player` (`2916`, transfers at `2943-2958`) | active AI and player inference | clue wager | no atomic replacement yet; needs exact-once transfer receipt |
| ProductMarket cash adapter `main:1686` called by ProductMarket WorldBridge | active | product futures | retain until futures settlement becomes an atomic player-state participant |
| CityGdpDerivative cash adapter `main:1727` called by derivative WorldBridge | active | derivative positions | retain until derivative settlement becomes an atomic player-state participant |
| role upgrade reward `main:10886` | active only through legacy monster upgrade | monster/role reward | remove with legacy upgrade unless a v0.6 profile declares a real atomic cash participant |
| rival-business cost `main:12574` | active AI path | AI world action | no replacement API; cannot retire cash truth |
| Monster owner damage/wager writes (`monster_runtime_controller.gd:1919,3257,3423,3433`) | active | Monster/wager domain | keep until Monster cash side effects gain cross-owner prepare/rollback/finalize |
| Contract bridge grants/penalties (`contract_runtime_world_bridge.gd:489,504`) | active composed surface | Contract domain | keep/fail closed until Contract economic participant is proven atomic |
| `CommodityFlowWorldBridge:103-157` batch cash apply | active v0.6 | authoritative Sale Receipt cash boundary | keep; this is the correct realtime-economy replacement |
| `CardPlayerStateProductionAdapterV06:391-393` state commit | active v0.6 CardFlow | authoritative card/cash/hand adapter | keep |
| bankruptcy clamp `main:6608` | active postcondition | session invariant, not an income formula | retain until shared PlayerState/session owner absorbs the invariant |

## World-event and manual-settlement audit

| Surface | Static caller result | Decision |
| --- | --- | --- |
| `VisualEventQueue` | no production references; only `visual_event_smoke_test` | retire after test migrates to active `VisualEventLayer` |
| `CityDevelopmentWorldBridge.apply_post_commit_intents` | only inside the uncomposed CityDevelopment cluster/QA | retire with the CityDevelopment batch |
| military/monster/product-market WorldBridge event forwarding | real `main._on_*_runtime_event` receivers | keep |
| weather/contract WorldBridge optional `_on_*_runtime_event` forwarding | no receiver in `main.gd`; currently guarded no-op | method-level candidate after weather/contract presentation tests prove no consumer; do not delete the owners |
| ProductMarket `settle_futures_position` | real internal expiry caller; destroyed-warehouse settlement also enters from `main:1398→1646` | keep; owner-controlled settlement, not an obsolete manual button |
| CityGdpDerivative `settle_district` | real internal expiry caller and `main:19899` Sale Receipt observation | keep while v0.4 derivatives exist |
| CityGdpDerivative `settle_destroyed_city` | definition has no production caller | method-level candidate after destruction/expiry/save tests |
| Monster `_settle_monster_wager` | real calls from all-bets, timeout, and monster-exit paths | keep; default text “手动结算” does not make the function dead |
| DistrictPurchaseSettlement service | real purchase plan/commit callers | keep |
| FinalSettlement snapshot/UI | real presentation only; does not settle economy | keep and do not confuse with cash settlement |

No separate legacy “world event mutation owner” is composed. Active world events are domain-owner receipts or scenario visual data. Removing visual/event presentation must never remove the underlying authoritative receipt.

## Stale evidence that must be migrated, not restored

- `layout_scene_smoke_test.gd` still expects GdpFormula, CityTradeNetwork, CityDevelopment, and IndustryCapacity composition/APIs.
- `shared_card_group_runtime_test.gd` still expects IndustryCapacity under the real Coordinator.
- old CityDevelopment/CityTrade/GDP/Economy/Industry tool benches and QA dock buttons describe v0.4/v0.5 ownership as current.
- `card_economy_product_route_formula_runtime_service_test.gd` and tool copy still name `GdpFormulaRuntimeController` as a delegated active owner.
- historical ownership docs conflict with `installed_commodity_continuous_economy_runtime_contract.md`; archive labels must win over restoration pressure.
- C9's “every source has a direct-neighbor exact demand” production invariant is stale under the latest product ruling. C11 must replace normalization with a non-mutating remote-coverage audit while retaining legal single production/demand slots and optional long-route trade. C10 does not alter that code.

## Recommended retirement order

1. Migrate QA dock/registries/tests, then delete the uncomposed EconomyCashflow/GdpFormula/CityTrade/Industry shells and scenes as separate call-graph-closed commits.
2. Migrate `visual_event_smoke_test`, then delete `VisualEventQueue`.
3. Cut v0.4 facility cards over to the shared v0.6 CardFlow facility lifecycle; remove only the legacy-index facility wrapper afterward.
4. Cut v0.4 monster cards over or fail them closed; remove direct summon helpers and roster setters afterward.
5. Migrate queue counter flags and requirement restoration to CardInventory transactions.
6. Introduce/consume atomic cash participants per remaining domain before deleting any direct cash adapter. Do not create a second cash truth.
7. In C11, retire the C9 forced direct-demand invariant as an overconstraint; do not conflate that policy correction with deletion of the map owner.

## Reproducible static evidence

Primary scans used path-filtered `rg` over `scripts/main.gd`, `scripts/runtime`, `scripts/cards`, `scenes/runtime`, enabled add-ons, tests, and tools. Key checks:

```powershell
rg -n "CityDevelopment|CityTradeNetwork|EconomyCashflow|GdpFormula|IndustryCapacity" scenes/runtime/GameRuntimeCoordinator.tscn scripts/runtime/game_runtime_coordinator.gd scripts/main.gd
rg -n --glob '*.gd' --glob '!tests/**' --glob '!scripts/tools/**' "_summon_monster_from_card|submit_public_facility_card|submit_legacy_index_facility_action|play_v06_runtime_card" scripts
rg -n --glob '*.gd' --glob '!tests/**' --glob '!scripts/tools/**' "plan_card_inventory|commit_card_inventory|plan_player_hand_interaction|commit_player_hand_interaction|queued_for_resolution" scripts
rg -n "VisualEventQueue|visual_event_queue.gd" scripts scenes project.godot addons
```

Godot `4.7.stable.official` isolated parse/editor load exited `0`. The only terminal diagnostic was the expected `Scan thread aborted` warning caused by `--quit-after 1`. No full smoke, gameplay run, headed/MCP acceptance, or default player save was used.

## Lessons for other agents

- **invariant:** absence from player composition is not sufficient for deletion; enabled add-ons, dynamic calls, reflection, and save consumers count.
- **failed approach:** treating a green v0.6 facade as proof that all v0.4 cards/cash/hand paths migrated would delete live production behavior.
- **stable API:** new facility/monster cards enter `GameRuntimeCoordinator.play_v06_runtime_card` and one CardFlow transaction.
- **test oracle:** replacement must be a real human+AI caller with exact-once state, rollback/finalize, save/load, and privacy evidence.
- **integration trap:** historical layout/characterization tests currently demand retired owners; update the oracle instead of restoring shells.
- **reusable pattern:** classify each surface as production-active, compatibility-active, historical-QA-only, or orphaned before deletion.
- **stale evidence:** v0.4/v0.5 GDP/project/Industry ownership documents and benches no longer describe production composition; C9 full-map forced direct coverage is also superseded by the C11 product ruling.
- **next dependency:** C11 replaces the C9 normalizer with remote-coverage audit semantics; separately, coordinated QA/test migration can retire uncomposed shells while active v0.4 facility, monster, hand, and cash paths need owner-by-owner cutovers.
