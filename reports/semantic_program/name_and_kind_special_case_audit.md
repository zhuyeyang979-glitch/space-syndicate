# Name And Kind Special-Case Audit

## Audit identity

- Baseline: `29dac1dd47b04afa60c1d867a0bbe5c5c4d94d0c`
- Branch: `codex/semantic-program-wave1-name-kind-29dac1d`
- Scope: production GDScript under `scripts/`, excluding `scripts/tools/`; tests, catalogs, scenes, rules, and prior reports were read-only corroborating sources.
- Production changes: none.
- Owned outputs: this report and `reports/semantic_program/name_and_kind_special_case_audit.json` only.
- Method: `rg` lexical sweeps first, followed by symbol-level source tracing and comparison with the already integrated card/AI/presentation audits.

## Verdict

The repository has a sound typed-owner foundation, but content meaning is still reconstructed in several parallel places. The highest-risk defects are not ordinary domain state machines. They are:

1. the active v0.4 card catalog beside the v0.6 machine catalog;
2. the legacy/v0.6 split in card submission;
3. localized names or visible text used as identity, behavior, routing, or scoring inputs;
4. repeated `kind -> route/category/color/use-case` maps in AI, presentation, and diagnostics;
5. rank/family inference from a name suffix;
6. 22 live UI alias-chain lines that conflate acquisition cost, activation cost, effect copy, type, and rank;
7. role and monster identities that still fall back to localized names.

The audit records **57 grouped findings**: **16 REMOVE**, **33 MOVE**, and **8 KEEP**. `KEEP` means the branch is a legitimate state machine, migration guard, privacy guard, or display-only use; it does not authorize localized text as future semantic identity.

## Scan totals

| Measure | Result |
| --- | ---: |
| Production `.gd` files scanned | 522 |
| Production `.gd` files containing Han text | 219 |
| Localized control-predicate candidate lines | 213 |
| Localized predicate matches | 347 |
| Files containing those candidate lines | 35 |
| Broad `kind/category/effect_kind/target_kind` control-flow candidate lines | 824 |
| Files containing broad kind candidates | 132 |
| Canonical card alias-chain lines | 22 in 7 files |
| Name-suffix rank/family inference lines | 7 in 5 files |
| Exact active `ruleset_id ==/!= "v0.4"` gates | 10 |
| Previously verified direct AI card-field reads | 225 in 33 functions, 71 keys |

The 824 kind candidates intentionally include valid domain state machines. They were not treated as defects merely because they use `match` or `if`.

## Authority map

| Domain | Current authority | Required stable semantic owner | Rule for migration |
| --- | --- | --- | --- |
| Cards | v0.4 `CardRuntimeCatalogService` plus v0.6 machine JSON and supplemental sources | `CardSemanticSpec` compiled once by `SemanticCompiler` | v0.6 `machine` is compiler input; no name parsing or alternate runtime definition source |
| Card execution | Several kind switches and owner calls | `OperationHandlerRegistry` + existing domain handlers | Move dispatch registration; keep transactions and state machines |
| Player card view | `CardPresentationRuntimeService`, `CardUI`, `RightInspector`, Codex adapters | `PlayerPresentationDTO` | UI formats DTO only; missing semantics fail closed |
| AI | `AiRuntimeController` plus diagnostic/definition bridges | `AiObservationSnapshot` + `AiActionCandidate` | Static semantics are compiled; live facts are viewer-authorized before projection |
| Diagnostics | `GameplayBalanceDiagnosticsRuntimeService` and `RuntimeBalanceModel` | standard semantic diagnostic projection | Diagnostics do not reinterpret raw card fields |
| Roles | `RoleCatalogRuntimeService` indexed by order/name with flat passive fields | `RoleSemanticSpec` + `PassiveTriggerExecutionPlan` | Preserve current save shape during a versioned identity migration |
| Monsters | localized roster/name tables plus live `MonsterRuntimeController` | `MonsterSemanticSpec` + `MonsterBehaviorSpec` | Keep live owner; migrate content identity, behavior, weights, and visual cues |
| Products | `ProductMarketRuntimeController.PRODUCT_CATALOG` and profiles | `ProductSemanticSpec` | Preserve localized product IDs as a compatibility bridge until save/RNG-safe migration |
| Military | live `MilitaryRuntimeController` with local presentation maps | `MilitaryUnitSemanticSpec` | Keep command transaction; project labels, glyphs, colors, and AI features from spec |
| Weather | `WeatherDefinitionCatalog` plus duplicate `WEATHER_TYPES` | `WeatherSemanticSpec` backed by the existing definition catalog | Delete duplicate constant; keep stable source/state IDs |

## REMOVE findings

| ID | Category | Exact evidence | Current authority | Risk | Replacement owner |
| --- | --- | --- | --- | --- | --- |
| NK-001 | Catalog duality | `scripts/runtime/card_runtime_catalog_service.gd:5`, `:15`; `scripts/cards/card_runtime_authoring_service.gd:5` | v0.4 Resource graph | The global service still declares v0.4 authoritative while v0.6 is the compiler target. | `CardSemanticSpec` catalog compiled from v0.6 machine data; retire v0.4 runtime authority after parity. |
| NK-002 | Catalog duality | `scripts/runtime/card_runtime_definition_world_bridge.gd:37`, `:40`, `:43`, `:77`, `:80`, `:83`, `:89`, `:91`, `:97` | Catalog bridge, Main monster helpers, finance controllers | Source precedence can return catalog, finance-enriched, monster-generated, or derived definitions for one ID. | One compiled semantic catalog; external terms become validated compiler inputs or owner subplans. |
| NK-003 | Version dual path | `scripts/runtime/card_play_submission_runtime_controller.gd:68`, `:75`, `:96`, `:103`, `:782` | Card submission controller | Shape detection selects v0.6 or legacy execution, so one action has two rule paths. | `CardSemanticSpec.operation_id -> OperationHandlerRegistry`; one submission path. |
| NK-004 | Version dual path | `scripts/runtime/game_session_runtime_controller.gd:57`, `:546`; `scripts/runtime/session_start_plan_builder.gd:116`; `scripts/runtime/game_runtime_coordinator.gd:515` | Session/coordinator ruleset gates | Runtime composition emits/requires v0.4 while session accepts v0.4 and v0.6. | One current ruleset identity; keep legacy inspection only in save migration. |
| NK-005 | Suffix rank inference | `scripts/cards/card_runtime_catalog_resource.gd:59`, `:66`; `scripts/cards/card_play_requirement_policy.gd:94`, `:101`; `scripts/cards/card_runtime_change_review_service.gd:229`; `scripts/balance/runtime_balance_model.gd:1010`, `:1017`; `scripts/runtime/card_codex_public_source_service.gd:115`, `:117`, `:119` | Catalog, policy, diagnostics, Codex | Localized/display names ending in digits silently become family/rank identity. | `SemanticIdentity.card_id/family_id/rank`; explicit legacy migration map only. |
| NK-006 | Alias fallback chain | `scripts/CardUI.gd:67`, `:69`, `:70`, `:71`; `scripts/GameScreen.gd:181`, `:182`; `scripts/viewmodels/card_view_snapshot.gd:19`, `:20`, `:21`, `:23`; `scripts/ui/card_face.gd:17`; `scripts/ui/game_screen.gd:1439`, `:1440`, `:1676`, `:1677`; `scripts/ui/hand_rack.gd:137`, `:138`, `:139`; `scripts/ui/right_inspector.gd:197`, `:266`, `:267`, `:307` | UI/viewmodel compatibility dictionaries | Cost meanings collide and malformed producers remain invisible. | One temporary migration adapter, then strict `PlayerPresentationDTO` fields. |
| NK-007 | Localized identity parser | `scripts/main.gd:4261`, `:4266`, `:4267`, `:4270` | Main monster-technique compatibility helpers | `兽技·` and delimiter parsing define family identity and behavior. | Stable monster behavior/card IDs in `MonsterBehaviorSpec` and `CardSemanticSpec`. |
| NK-008 | One-off content ID | `scripts/main.gd:4094`; `scripts/runtime/ai_runtime_controller.gd:1667` | Main and AI | Both synthesize `相位否决%d`, coupling a role passive and AI to a concrete localized card family. | Role passive op `convert_owned_monster_card_to_counter` resolves a stable counter semantic ID. |
| NK-009 | One-off content ID | `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:7`, `:8`, `:9`, `:10`, `:11`; `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:83`, `:307` | Balance diagnostics | Four localized family IDs and fourteen hand-picked card IDs are a second semantic catalog. | Standard diagnostic projection queried by stable family/category/operation IDs. |
| NK-010 | Localized name rule branch | `scripts/runtime/monster_runtime_controller.gd:3651`, `:3785`, `:3809`, `:3832`, `:3838`, `:4313`, `:4861` | Monster live owner | Seven actor/template name checks control revive, energy threshold, armor, reflection, and path effects. | `MonsterBehaviorSpec` feature/trigger operation IDs consumed by the same live owner. |
| NK-011 | Localized name rule branch | `scripts/runtime/monster_runtime_controller.gd:24`, `:3102` | Monster live owner | Missing family identity falls back through a Chinese-name map. | Required `monster_family_id`; versioned state/save migration, then fail closed. |
| NK-012 | Localized text/kind branch | `scripts/runtime/ai_runtime_controller.gd:2898`, `:2904`, `:2925`, `:3173`, `:3177`, `:3179`, `:3181`, `:3183`, `:3185`, `:3187`, `:3189`, `:3191` | AI planner | Chinese action labels and substring policy guesses alter route and score. | `AiActionCandidate` with typed semantic tags and `AiOutcomeVector`. |
| NK-013 | Localized UI control branch | `scripts/main.gd:1763`, `:1765`, `:1767`, `:1769`, `:1771`, `:1773`, `:1775`, `:3753`; `scripts/ui/action_dock.gd:237`, `:239`, `:241`, `:243`; `scripts/runtime/menu_lifecycle_application_flow_controller.gd:167`, `:355`, `:357`, `:363`, `:365` | Main/UI/menu flow | Visible labels and body prose choose commands, accents, and navigation state. | Stable action/page IDs in application-flow and presentation DTOs. |
| NK-014 | Localized identity parser | `scripts/runtime/card_codex_public_source_service.gd:115`, `:117`, `:119`, `:130`, `:133` | Card Codex source | A display string, optional Roman text, or `怪兽·<name><rank>` can resolve a card identity. | Request by stable `card_id`; localization is output only. |
| NK-015 | Duplicate catalog | `scripts/runtime/weather_runtime_controller.gd:16`, `:17`, `:18`, `:19`, `:20`, `:21`, `:22`; authoritative catalog access at `:989` | Weather controller and `WeatherDefinitionCatalog` | Six labels exist in a dead/duplicate map beside the real definition resources; AI exposes the duplicate at `scripts/runtime/ai_runtime_controller.gd:1169`. | Existing definition catalog projected as `WeatherSemanticSpec`; remove `WEATHER_TYPES`. |
| NK-016 | Localized name rule branch | `scripts/balance/combat_balance_model.gd:67`, `:69`, `:71`, `:73` | Combat diagnostics | Action names/tags such as `冲锋`, `光线`, `投掷`, and `爆` change balance classification. | Standard `MonsterBehaviorSpec` diagnostic features; no localized fallback. |

## MOVE findings

| ID | Category | Exact evidence | Current authority | Risk | Stable destination |
| --- | --- | --- | --- | --- | --- |
| NK-017 | Localized text classifier | `scripts/main.gd:3494`, `:3496`, `:3498`, `:3500`; duplicate logic at `scripts/runtime/ai_region_knowledge_query_port.gd:422`, `:424`, `:426`, `:428` and `scripts/runtime/ai_runtime_controller.gd:1560`, `:1562`, `:1564`, `:1566`, `:9213` | Public-clue producers plus Main/AI consumers | Three consumers independently infer clue meaning from Chinese prose. | Producer emits stable `clue_kind_id`, public product IDs, and visibility; AI reads authorized observation. |
| NK-018 | Localized text classifier | `scripts/main.gd:1417`, `:1418`, `:1420`, `:1422`, `:1424`, `:1426` | Main presentation | Public log prose selects event color. | Public event DTO carries `event_kind_id` and presentation token. |
| NK-019 | Localized text classifier | `scripts/main.gd:4558`, `:4560`, `:4562`, `:4564`, `:4566`, `:4579`, `:4583`, `:4585`, `:4589`, `:4591`, `:4593`, `:4604`, `:4606`, `:4608`, `:4610`, `:4612`, `:4614`, `:4616`, `:4618`, `:4620`, `:4622` | Main monster visual profile | Action names and optional payload fields choose animation family and pose. | `MonsterBehaviorSpec.presentation_cue_id`; Main consumes no monster semantics. |
| NK-020 | Localized text classifier | `scripts/runtime/visual_cue_runtime_owner.gd:337`, `:342`, `:347`, `:349`, `:351` | Visual cue owner | Public prose selects impact/weather/card effects and can drift under localization. | Typed `presentation_cue_id` from rule/player projection; visual owner only renders it. |
| NK-021 | Localized presentation inference | `scripts/card_art_view.gd:261`, `:305`, `:417`, `:448`, `:472`, `:486`, `:488`, `:490`, `:492`, `:936`, `:998`, `:1137`, `:1158`, `:1172`, `:1179`, `:1187`, `:1196`, `:1201`, `:1299` | Card art renderer | Names, tags, type substrings, and concrete card identities choose motifs and icons. | `PlayerPresentationDTO.art_profile` compiled from stable presentation tokens. |
| NK-022 | Localized presentation inference | `scripts/CardUI.gd:613`, `:615`, `:617`, `:730`, `:732`, `:734`, `:736`, `:738`, `:740`, `:742`, `:744`, `:746`, `:748`, `:757` | CardUI | UI infers target/type/use-case from Chinese/English text. | Strict `PlayerPresentationDTO`; UI only formats supplied sections/tokens. |
| NK-023 | Localized presentation inference | `scripts/ui/right_inspector.gd:266`, `:267`, `:268`, `:270`, `:272`, `:274`, `:276`, `:278`, `:280`, `:282`, `:307` | RightInspector | Inspector independently infers route/use case from type and effect prose. | Same `PlayerPresentationDTO` used by hand, market, detail, and Codex. |
| NK-024 | Kind projection duplication | `scripts/runtime/card_presentation_runtime_service.gd:451`, `:460`, `:461`, `:462`, `:463`, `:464`, `:465`, `:466`, `:467`, `:468`, `:469`, `:470`, `:471`, `:472`, `:473`, `:474` | Card presentation service | A local `kind/tags/field -> strategy route` oracle duplicates AI and diagnostics. | `CardSemanticSpec.taxonomy` projected once into `PlayerPresentationDTO`. |
| NK-025 | Kind projection duplication | `scripts/runtime/card_presentation_runtime_service.gd:478`, `:487`, `:501`, `:502`, `:505`, `:507`, `:511`, `:668`, `:674`, `:675`, `:676`, `:690`, `:695`, `:696`, `:871`, `:890` | Card presentation service | Use-case, category, type, effect style, and labels are separately maintained maps. | Stable keyword/type/route/effect-style IDs in the player projection/localization catalog. |
| NK-026 | Raw field interpretation | `scripts/runtime/card_presentation_runtime_service.gd:551`, `:553`, `:554`, `:555`, `:562`, `:563`, `:564`, `:565`, `:567`, `:568`, `:569`, `:570`, `:571`, `:572`, `:577`, `:579`, `:580`, `:582`, `:897`, `:899` | Card presentation service | Presentation reconstructs rules and duration from raw fields and legacy turns. | `CardSemanticSpec -> PlayerPresentationDTO`; timing conversion belongs to compiler/rules projection. |
| NK-027 | Kind projection duplication | `scripts/runtime/card_codex_public_snapshot_service.gd:220`, `:221`, `:232`, `:233`, `:234`, `:235`, `:236`, `:237` | Card Codex snapshot | Localized route labels and `kind.contains` create tactical advice. | Card player projection supplies stable timing/combo message references. |
| NK-028 | Localized UI state branch | `scripts/ui/card_resolution_track.gd:143`, `:534`, `:536`, `:538`, `:629`; `scripts/runtime/game_table_viewmodel_runtime_service.gd:264`, `:315`, `:316`, `:317`, `:318`, `:402`, `:403`, `:404`, `:407`, `:420`, `:421`, `:422`, `:423`, `:424`; `scripts/viewmodels/public_track_snapshot.gd:162` | Resolution/table presentation | Lane/state/color behavior is recovered from localized display state. | Typed `CardResolutionViewState` and stable lane/status IDs. |
| NK-029 | Localized UI state branch | `scripts/ui/menu_overlay.gd:61`; `scripts/ui/intel_dossier_board.gd:270`; `scripts/ui/game_screen.gd:1736`; `scripts/ui/final_settlement_board.gd:223`; `scripts/ui/overlay_layer.gd:518`; `scripts/ui/player_seat/player_seat_portrait_skin.gd:112`; `scripts/runtime/district_supply_snapshot_service.gd:337`, `:470`, `:717` | UI surfaces | Titles, labels, and visible status strings are used as state identity. | Stable page/context/availability/local-player IDs in view DTOs. |
| NK-030 | Localized identity | `scripts/runtime/role_catalog_runtime_service.gd:287`; `scripts/runtime/world_session_state.gd:588`; `scripts/runtime/world_session_envelope_codec.gd:184`, `:467`; `scripts/runtime/ai_actor_state_port.gd:696`; `scripts/presentation/role_portrait_catalog.gd:42`, `:54` | Role catalog, world/save identity, AI, portrait manifest | Role order and Chinese name jointly identify saved/runtime content. | `RoleSemanticSpec.role_id`; preserve existing envelope fields through explicit migration. |
| NK-031 | Raw field interpretation | Authored fields at `scripts/runtime/role_catalog_runtime_service.gd:72`, `:101`, `:118`, `:126`, `:142`, `:239`, `:248`, `:257`; consumers at `scripts/main.gd:1858`, `scripts/runtime/ai_runtime_controller.gd:5251`, `scripts/runtime/codex_public_snapshot_service.gd:214`, `scripts/runtime/military_runtime_controller.gd:485`, `scripts/runtime/monster_runtime_controller.gd:4102`, `:6461` | Role catalog and multiple domain consumers | Flat passive fields are separately interpreted by rules, AI, Codex, and owners. | `RoleSemanticSpec.passive_operations -> PassiveTriggerExecutionPlan / PlayerRoleCardDTO / AiRoleFeatureProjection`. |
| NK-032 | Localized content identity | `scripts/runtime/monster_catalog_v06.gd:122`, `:123`, `:213`, `:214`, `:320`, `:323`; `scripts/runtime/monster_codex_public_source_service.gd:186`, `:187` | Monster catalog | Art/action tables and catalog lookup are keyed by localized monster names. | Stable monster IDs in `MonsterSemanticSpec`; names are localization refs. |
| NK-033 | Localized content identity | `scripts/runtime/monster_runtime_controller.gd:259`, `:260`, `:994`, `:4320`; helper consumption at `scripts/runtime/monster_catalog_v06.gd:375`, `:379` | Monster controller | AI/action weights are a name-keyed behavior table duplicated at runtime. | `MonsterBehaviorSpec.action_weights` keyed by stable behavior ID and phase. |
| NK-034 | One-off content ID | `scripts/runtime/monster_catalog_v06.gd:24`, `:38`, `:53`, `:66`, `:79`, `:92`, `:105`, `:118` | Monster catalog | Localized card lists tie monster rows to concrete legacy card names. | Stable `card_id` references or semantic query tags validated during catalog compilation. |
| NK-035 | Localized content identity | `scripts/runtime/session_start_world_plan_builder.gd:13`, `:186`, `:188`, `:189` | Session world-plan builder | Ocean eligibility is a second list of localized product IDs. | `ProductSemanticSpec.terrain_tags`; plan builder queries detached semantic facts without changing RNG order. |
| NK-036 | Mixed semantic/presentation catalog | `scripts/runtime/product_market_runtime_controller.gd:98`, `:99`, `:108`, `:113`, `:125`, `:136` | Product market live owner | Profiles combine rule-adjacent category/route/terrain/use/hook with localized display and art. | Immutable `ProductSemanticSpec`; market owner keeps only live price/state. |
| NK-037 | Localized category rule branch | `scripts/balance/environment_balance_model.gd:83`, `:96`, `:102`, `:103`, `:107`, `:108` | Environment diagnostics | Chinese category labels change production, demand, and transport multipliers. | Stable Product/Weather semantic tags in standard diagnostics projection. |
| NK-038 | Kind projection duplication | `scripts/runtime/military_runtime_controller.gd:182`, `:193`, `:204`, `:215`, `:226`, `:234`, `:510`, `:790` | Military live owner | Unit type/domain controls labels, glyphs, motif, color, command copy, and AI role in one controller. | `MilitaryUnitSemanticSpec` plus player/AI projections; live command transaction remains here. |
| NK-039 | Kind/field policy | `scripts/cards/card_play_requirement_policy.gd:25`, `:30`, `:39`, `:94`, `:117`, `:119`, `:122`, `:128`, `:130`, `:135`, `:138` | Card requirement policy | Hard-coded kind bands and raw damage/economy fields derive conditions and scope. | Compiled `SemanticCondition[]` and `SemanticTargetSpec`; policy evaluates typed plans. |
| NK-040 | Kind/field policy | `scripts/runtime/card_play_eligibility_runtime_service.gd:6`, `:14`, `:15`, `:16`, `:54`, `:56`, `:58`, `:62`, `:114`, `:148`, `:149`, `:150`, `:151`, `:538` | Eligibility service | Several kind allowlists independently define target, retired, financial, and counter semantics. | `CardSemanticSpec` target/timing/response contract; service evaluates world legality only. |
| NK-041 | Operation dispatch | `scripts/runtime/card_effect_runtime_router.gd:51`, `:84`, `:94`, `:99`, `:121`, `:123`, `:136`, `:143`, `:145`, `:147`, `:149`, `:153` | Card effect router | Stable IDs exist, but registration and dispatch are a central switch that must change for every new op. | `OperationHandlerRegistry`; preserve existing owner methods and transaction ordering. |
| NK-042 | AI raw/kind interpretation | `scripts/runtime/ai_runtime_controller.gd:5551`, `:5556`, `:5577`, `:5578`, plus representative scoring reads at `:7398`, `:7841`, `:8536`, `:9336` | AI planner | AI maps kind and 71 raw definition keys itself; merged audit verifies 225 reads. | `AiObservationSnapshot + CardSemanticSpec -> AiActionCandidate/AiOutcomeVector`; cache by catalog revision. |
| NK-043 | Diagnostics raw/kind interpretation | `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:112`, `:117`, `:174`, `:208`, `:217`, `:219`, `:223`, `:225`, `:318`, `:688`, `:787`, `:904`, `:1023` | Gameplay diagnostics | Diagnostics re-score and reclassify raw cards independently of execution. | Standard semantic diagnostic projection generated beside rule/player/AI projections. |
| NK-044 | Diagnostics raw/kind interpretation | `scripts/balance/runtime_balance_model.gd:268`, `:270`, `:273`, `:277`, `:280`, `:282`, `:632`, `:639`, `:640`, `:641`, `:792`, `:843`, `:1024` | Runtime balance model | A second kind/field map and name-derived identity can drift from rules and AI. | Same standard semantic diagnostic projection; no direct card dictionaries. |
| NK-045 | Localized tag rule branch | `scripts/cards/card_runtime_family_resource.gd:93` | v0.4 authoring resource | Chinese tag `升级` decides whether family rank copy is augmented. | Stable family capability/operation ID validated by compiler. |
| NK-046 | Catalog duality | `scripts/runtime/card_runtime_definition_world_bridge.gd:89`, `:91`, `:97`; `scripts/runtime/card_play_eligibility_runtime_service.gd:58`, `:62` | Finance controllers and eligibility | Missing financial semantics are loaded dynamically by kind during play/query. | Compile validated finance sub-specs once at catalog initialization. |
| NK-047 | Operation dispatch | `scripts/runtime/game_runtime_coordinator.gd:2647`, `:2656`, `:2906`, `:2923`, `:2950`, `:2963`, `:2978`, `:3050`, `:3066`, `:3082`, `:3100`, `:3113` | Game runtime coordinator | Coordinator duplicates prepare/commit/rollback/finalize effect-kind routing. | Registry entries expose typed lifecycle handlers; coordinator keeps orchestration only. |
| NK-048 | Localized content identity | `scripts/runtime/monster_catalog_v06.gd:340`, `:341`, `:347`; parser counterpart `scripts/main.gd:4264` | Monster catalog/Main | Generated technique IDs embed localized monster and action names. | Stable behavior/card identity with localized display generated separately. |
| NK-049 | Raw payload introspection | `scripts/runtime/product_codex_public_source_service.gd:291`, `:297`, `:308`, `:313`, `:317`, `:324`, `:327` | Product Codex source | Codex recursively scans arbitrary payload values to infer product relationships. | `ProductSemanticSpec.related_card_ids` or standard product diagnostic/player projection. |

## KEEP findings

| ID | Category | Exact evidence | Why it is legitimate | Constraint |
| --- | --- | --- | --- | --- |
| NK-050 | Authoritative owner | `scripts/runtime/product_market_runtime_controller.gd:80`, `:148`, `:1686`; consumers explicitly name this authority at `scripts/presentation/table_selection_catalog_query_port.gd:76` | `ProductMarketRuntimeController` is the existing live market owner and its localized product IDs are current compatibility authority. | Do not create a second product/state owner or invent ASCII aliases; migrate identity with save/RNG evidence later. |
| NK-051 | Stable domain invariant | `scripts/runtime/player_organization_runtime_controller.gd:25`, `:26`, `:27`, `:28`, `:29`, `:554`, `:682` | Stable ASCII axis/family IDs validate an owner invariant, not localized display text. | It may move into a semantic spec, but the validation and owner remain. |
| NK-052 | Stable domain state machine | `scripts/runtime/military_runtime_controller.gd:698`, `:699`, `:714`, `:726`, `:740`, `:775`; `scripts/runtime/monster_runtime_controller.gd:6740`, `:6742`, `:6761`, `:6850` | These switches execute real command/action states using stable IDs. | Register operations; do not delete the state machines or change formulas/order/RNG. |
| NK-053 | Authoritative owner | `scripts/runtime/weather_runtime_controller.gd:24`, `:25`, `:26`, `:27`, `:257`, `:989`; `scripts/runtime/weather_definition_catalog.gd:8`, `:54` | Weather source/state IDs and the definition catalog are stable, typed domain authority. | Delete only the duplicate label map; keep live weather state and resolver. |
| NK-054 | Compatibility guard | `scripts/runtime/ruleset_save_handshake_service.gd:144`, `:145` | Legacy v0.4 saves are identified and rejected fail closed, not executed through a second rules engine. | Preserve save shape and rejection semantics until an explicit migration exists. |
| NK-055 | Compatibility guard | `scripts/runtime/legacy_contract_payload_guard_v06.gd:50`, `:51`, `:52`, `:53`, `:54`, `:55`, `:56`, `:58`, `:59` | Exact retired payload IDs form a denylist that prevents retired mechanics from re-entering v0.6. | Keep as a migration/status guard; never treat these names as active rules. |
| NK-056 | Privacy guard | `scripts/runtime/region_codex_public_source_adapter.gd:181`; `scripts/runtime/final_settlement_public_source_adapter.gd:156` | These reject/scrub suspicious private-text tokens at public boundaries as defense in depth. | Primary privacy must remain typed and viewer-scoped; text guards cannot authorize disclosure. |
| NK-057 | Display/localization | `scripts/presentation/card_history_public_query_port.gd:92`; `scripts/runtime/new_game_setup_viewer_query_port.gd:94`; punctuation normalization at `scripts/runtime/action_result_v1.gd:490` | Literal Chinese copy is output-only here; it does not select rules or handlers. | Keep localization/display behavior, but move strings behind stable message refs when projection DTOs land. |

## Migration order

1. Freeze `SemanticIdentity`, condition/target/operation/randomness/visibility contracts and `OperationHandlerRegistry`.
2. Compile v0.6 machine definitions once and prove rule-result parity before removing v0.4 authority or the submission split.
3. Cut over Player, AI, and diagnostics projections from the same immutable spec; add ratchet scans for raw fields, aliases, localized branches, and in-loop compilation.
4. Migrate role and monster stable identities with explicit save compatibility. Do not rename localized product IDs in place.
5. Move military/weather/product/monster presentation metadata into their domain specs while retaining the existing live state owners.
6. Remove old aliases and text/name fallbacks only after every production consumer is on the typed projection.

## Blockers

1. **Card executable coverage:** v0.6 military, interaction/counter, and organization readiness is not yet universal. Removing the legacy route before handler parity would change playable behavior.
2. **Role save identity:** current envelopes validate the 24-role order and localized role name. Stable `role_id` needs a versioned compatibility migration without changing the current envelope shape in this audit.
3. **Monster live-state identity:** old actors can lack `monster_family_id`, which triggers the localized fallback. Migration requires checkpoint/save normalization and exact behavior parity.
4. **Product identity:** localized product IDs are current authoritative keys across market, world generation, routes, cards, and saves. Ad-hoc renaming would alter references and can alter deterministic plan inputs.
5. **AI authorization:** static semantic cutover does not by itself solve hidden city/monster owner access. `AiObservationSnapshot` must enforce viewer scope before candidate projection.
6. **UI atomicity:** removing the 22 alias lines before every hand/market/detail producer emits one DTO would make existing surfaces blank or semantically ambiguous.

These are migration blockers, not blockers to merging this read-only audit.

## Preservation guarantees

- No rule, balance value, RNG draw, save shape, privacy boundary, catalog, production script, test, or scene was modified.
- No second state owner or content catalog was proposed.
- Existing domain transactions and state machines are explicitly retained behind stable operation registration.
- Localized display text is not treated as a defect unless it influences identity, rules, scoring, routing, state, or semantic presentation.
- Legacy save/content deny guards remain fail closed.

## Conclusion

The removal target is not every `if` or `match`. It is every place where a localized name, display string, arbitrary payload field, or duplicated kind table stands in for executable semantics. The safe destination is one immutable domain spec per content type, three authorized projections, and stable operation IDs registered to the existing owners.
